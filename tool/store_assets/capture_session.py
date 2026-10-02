"""Native-only schema-2 scene sessions. One fresh app process per locale."""
import datetime
import hashlib
import json
import os
import pathlib
import re
import signal
import struct
import subprocess
import time
import uuid

BUNDLE = 'com.syamo.hitasuraads'
SCENES = {'home', 'collection', 'pin', 'runner', 'rush', 'settings', 'liquid', 'fruit'}
GAME_NUMBERS = {'liquid': 3, 'fruit': 8}


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def utc_parse(value):
    parsed = datetime.datetime.fromisoformat(value.replace('Z', '+00:00'))
    if parsed.utcoffset() != datetime.timedelta(0):
        raise ValueError('Expected a UTC capture timestamp')
    return parsed


def sha256(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def write_request(container, session_id, request_id, locale, scene, action):
    if scene not in SCENES or action not in {'show', 'record_start', 'stop'}:
        raise ValueError('Unsupported capture scene/action')
    for identifier in (session_id, request_id):
        if str(uuid.UUID(identifier, version=4)) != identifier:
            raise ValueError('Session and request IDs must be canonical UUID4 values')
    request = {'schema_version': 2, 'session_id': session_id, 'request_id': request_id,
               'locale': locale, 'scene': scene, 'action': action, 'created_at': utc_now()}
    folder = container / 'Documents/HitasuraCapture'
    folder.mkdir(parents=True, exist_ok=True)
    pending = folder / 'request.pending'
    with pending.open('w') as output:
        json.dump(request, output)
        output.flush()
        os.fsync(output.fileno())
    pending.replace(folder / 'request.json')
    return request


def state_matches(state, request):
    return (state.get('session_id') == request['session_id']
            and state.get('request_id') == request['request_id']
            and state.get('launch_id') == request['session_id']
            and state.get('locale') == request['locale']
            and state.get('requested_scene') == request['scene']
            and state.get('action') == request['action'])


def validate_gameplay(ready, started, complete, scene):
    number = GAME_NUMBERS[scene]
    for state in (ready, started, complete):
        if state.get('game_no') != number or state.get('phase') != 'play':
            raise RuntimeError('Native game identity/active-play evidence mismatch')
        if state.get('native_simulator_attested') is not True:
            raise RuntimeError('Missing native simulator attestation')
    if started.get('input_method') != 'flutter_gesture_binding_pointer_events':
        raise RuntimeError('Gameplay did not use the approved actual pointer input path')
    if complete.get('input_method') != started['input_method']:
        raise RuntimeError('Gameplay input method changed')
    if complete.get('elapsed_seconds', 0) < 10:
        raise RuntimeError('Recorded gameplay ended before ten seconds')
    if complete.get('game_time_end', 0) - complete.get('game_time_start', 0) < 8:
        raise RuntimeError('Insufficient actual game-time progression')
    events = complete.get('input_events')
    if not isinstance(events, list) or not events:
        raise RuntimeError('Missing actual gameplay pointer journal')
    if started.get('random_seed') != 'shipping_time_seed_unmodified' or complete.get('random_seed') != started['random_seed']:
        raise RuntimeError('Gameplay seed evidence differs from the shipping behavior')
    if complete.get('started_at') != started.get('started_at'):
        raise RuntimeError('Gameplay start timestamp changed')
    if (utc_parse(complete['completed_at']) - utc_parse(started['started_at'])).total_seconds() < 10:
        raise RuntimeError('Gameplay UTC interval is shorter than ten seconds')


class CaptureSession:
    def __init__(self, host, udid, container, locale, dest, output_root, timeout=90):
        self.host, self.udid, self.container = host, udid, container
        self.locale, self.dest, self.output_root = locale, dest, output_root
        self.timeout = timeout
        self.session_id = str(uuid.uuid4())
        self.state_path = container / 'Documents/HitasuraCapture/state.json'
        self.pid = None
        self.sequence = 0
        self.active_scene = 'home'
        self.dimensions = None
        self.dest.mkdir(parents=True, exist_ok=True)

    def budget(self, maximum):
        deadline = getattr(self.host, 'work_deadline', None)
        remaining = maximum if deadline is None else min(maximum, deadline - time.monotonic())
        cleanup = getattr(self.host, 'cleanup_deadline', None)
        if isinstance(cleanup, (int, float)):
            remaining = min(remaining, cleanup - time.monotonic())
        if remaining <= 0:
            raise TimeoutError('Capture work deadline reached; checkpoints retained')
        return remaining

    def cleanup_budget(self, maximum):
        deadline = getattr(self.host, 'cleanup_deadline', None)
        return maximum if not isinstance(deadline, (int, float)) else max(.01, min(maximum, deadline - time.monotonic()))

    def command(self, scene, action):
        self.budget(1)
        self.sequence += 1
        request = write_request(self.container, self.session_id, str(uuid.uuid4()),
                                self.locale, scene, action)
        folder = self.dest / 'requests'
        folder.mkdir(exist_ok=True)
        (folder / f'{self.sequence:03}_{scene}_{action}.json').write_text(json.dumps(request, indent=2))
        self.host.stage('session_request', **request)
        return request

    def states(self):
        states = []
        try:
            states.append(json.loads(self.state_path.read_text()))
        except (FileNotFoundError, json.JSONDecodeError):
            pass
        events = pathlib.Path(str(self.state_path) + '.events.jsonl')
        if events.exists():
            with events.open('rb') as stream:
                size = events.stat().st_size
                start = max(0, size - 262144)
                stream.seek(start)
                lines = stream.read().decode(errors='replace').splitlines()
            for line in lines[1:] if start else lines:
                try:
                    states.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
        return states

    def wait(self, request, stage, maximum=None):
        end = time.monotonic() + self.budget(maximum or self.timeout)
        last = None
        while time.monotonic() < end:
            if self.pid is not None:
                try:
                    os.kill(self.pid, 0)
                except ProcessLookupError as error:
                    raise RuntimeError('Native session exited before requested state') from error
            for state in self.states():
                if state.get('session_id') != self.session_id:
                    continue
                if state.get('stage') == 'error':
                    raise RuntimeError(f'Native session error: {state}')
                if state_matches(state, request):
                    last = state
                    if state.get('stage') == stage:
                        if state.get('native_simulator_attested') is not True or state.get('debug_mode') is not True or state.get('is_ios') is not True:
                            raise RuntimeError('Invalid native debug simulator state')
                        if stage in {'ready', 'gameplay_started', 'gameplay_complete'} and state.get('active_scene') != request['scene']:
                            raise RuntimeError('Native active scene differs from requested scene')
                        return state
            time.sleep(.1)
        raise TimeoutError(f'Native session did not reach {stage}; last_state={last}')

    def start(self, scene='home'):
        request = self.command(scene, 'show')
        stdout = (self.dest / 'session_stdout.log').resolve()
        stderr = (self.dest / 'session_stderr.log').resolve()
        result = self.host.run('xcrun', 'simctl', 'launch', f'--stdout={stdout}',
                               f'--stderr={stderr}', '--terminate-running-process',
                               self.udid, BUNDLE, timeout=30)
        match = re.search(re.escape(BUNDLE) + r':\s*(\d+)', result)
        if match is None:
            raise RuntimeError('Native session launch returned no PID')
        self.pid = int(match.group(1))
        self.active_scene = scene
        return self.wait(request, 'ready')

    def show(self, scene):
        request = self.command(scene, 'show')
        state = self.wait(request, 'ready')
        self.active_scene = scene
        return state

    def screenshot(self, scene, index, group, ready=None):
        if self.budget(45) < 45:
            raise TimeoutError('Capture work deadline leaves less than the 45-second screenshot reserve')
        ready = ready or self.show(scene)
        pause = 4 if scene in {'pin', 'runner'} else 2
        path = self.dest / f'{index:02}_{scene}.png'
        failed_attempts = []
        for attempt in (1, 2):
            if self.budget(45) < 45:
                raise TimeoutError('Capture work deadline leaves less than the 45-second screenshot reserve')
            time.sleep(pause)
            candidate = self.dest / f'{index:02}_{scene}.attempt{attempt}.png'
            self.host.stage('screenshot_attempt', locale=self.locale, scene=scene,
                            attempt=attempt, maximum_attempts=2, path=str(candidate))
            try:
                self.host.run('xcrun', 'simctl', 'io', self.udid, 'screenshot', '--type=png',
                              str(candidate), timeout=30)
            except subprocess.TimeoutExpired:
                failed_attempts.append({'attempt': attempt, 'path': str(candidate.relative_to(self.output_root)),
                                        'status': 'command_timeout_not_accepted'})
                if attempt == 2 or self.budget(48) < 48:
                    raise
                self.host.stage('screenshot_retry_scene_reset', locale=self.locale, scene=scene,
                                wait_seconds=3, reason='timeout_only')
                time.sleep(3)
                # A timed-out game may have reached its result page. Request the
                # real scene afresh before taking a second independent image.
                ready = self.show(scene)
                continue
            candidate.replace(path)
            break
        with path.open('rb') as source:
            source.seek(16)
            dimensions = struct.unpack('>II', source.read(8))
        allowed = {(1290, 2796), (1320, 2868), (1260, 2736)} if group == 'iphone_6_9' else {(2048, 2732), (2064, 2752)}
        if dimensions not in allowed:
            raise RuntimeError(f'Unexpected native screenshot dimensions: {dimensions}')
        self.dimensions = list(dimensions)
        return {'media_type': 'image', 'scene': scene, 'app_evidence': ready,
                'path': str(path), 'relative_path': str(path.relative_to(self.output_root)),
                'sha256': sha256(path), 'dimensions': list(dimensions),
                'screenshot_attempt': attempt, 'failed_screenshot_attempts': failed_attempts}

    def gameplay(self, scene, index):
        if self.dimensions is None:
            raise RuntimeError('A same-session native screenshot must establish dimensions before recording')
        if self.budget(75) < 75:
            raise TimeoutError('Capture work deadline leaves insufficient gameplay/finalization budget')
        ready = self.show(scene)
        if self.budget(75) < 75:
            raise TimeoutError('Capture work deadline leaves insufficient gameplay/finalization budget')
        if ready.get('phase') != 'play' or ready.get('time_left', 0) < 10.5:
            raise RuntimeError('Game is not ready for a ten-second active-play clip')
        path = self.dest / f'{index:02}_{scene}_native.mov'
        log = self.dest / f'{scene}_recording.log'
        recorder = {'process_started_utc': utc_now(), 'process_started_monotonic': time.monotonic(),
                    'recording_acknowledged': False, 'ack_log': str(log.relative_to(self.output_root))}
        with log.open('w') as output:
            process = subprocess.Popen(['xcrun', 'simctl', 'io', self.udid, 'recordVideo',
                                        '--codec=h264', '--force', str(path)],
                                       stdout=output, stderr=subprocess.STDOUT, text=True)
            try:
                end = time.monotonic() + self.budget(15)
                while time.monotonic() < end:
                    if process.poll() is not None:
                        raise RuntimeError('Native recorder exited before recording acknowledgment')
                    if 'recording started' in log.read_text(errors='replace').lower():
                        recorder.update(recording_acknowledged=True, ack_observed_utc=utc_now(),
                                        ack_observed_monotonic=time.monotonic())
                        break
                    time.sleep(.1)
                if not recorder['recording_acknowledged']:
                    raise TimeoutError('Native recorder did not acknowledge recording within fifteen seconds')
                recorder['command_sent_utc'] = utc_now()
                request = self.command(scene, 'record_start')
                started = self.wait(request, 'gameplay_started', 15)
                complete = self.wait(request, 'gameplay_complete', 20)
                validate_gameplay(ready, started, complete, scene)
            except Exception:
                self.host.begin_cleanup()
                raise
            finally:
                if process.poll() is None:
                    process.send_signal(signal.SIGINT)
                try:
                    process.wait(timeout=self.cleanup_budget(30))
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=self.cleanup_budget(5))
                    raise
                recorder['stopped_utc'] = utc_now()
        if process.returncode not in {0, -signal.SIGINT, 130} or not path.exists() or path.stat().st_size == 0:
            raise RuntimeError('Native recording did not finalize successfully')
        trim_start = (utc_parse(started['started_at']) - utc_parse(recorder['ack_observed_utc'])).total_seconds()
        if trim_start < 0:
            raise RuntimeError('Gameplay timestamp precedes recorder acknowledgment')
        return {'media_type': 'video', 'scene': scene, 'game_no': GAME_NUMBERS[scene],
                'dimensions': self.dimensions, 'dimension_source': 'native_screenshot_same_session', 'path': str(path),
                'relative_path': str(path.relative_to(self.output_root)), 'sha256': sha256(path),
                'scene_ready': ready, 'gameplay_started': started, 'gameplay_complete': complete,
                'app_evidence': complete, 'recorder': recorder, 'trim_start_seconds': trim_start,
                'trim_duration_seconds': 10, 'trim_basis': 'conservative_ack_anchored_play_window',
                'recording_start_uncertainty_seconds': recorder['ack_observed_monotonic'] - recorder['process_started_monotonic'],
                'audio': 'not captured; silent native source', 'native_unencoded': True}

    def close(self):
        try:
            if self.pid is not None and self.budget(5) >= 1:
                request = self.command(self.active_scene, 'stop')
                self.wait(request, 'stopped', 5)
        except Exception as error:
            self.host.stage('session_stop_unconfirmed', error=str(error), session_id=self.session_id)
        finally:
            self.host.best_effort('xcrun', 'simctl', 'terminate', self.udid, BUNDLE, timeout=10)
            for suffix, name in (('', 'session_last_state.json'), ('.events.jsonl', 'session_events.jsonl')):
                source = pathlib.Path(str(self.state_path) + suffix)
                if source.exists():
                    (self.dest / name).write_bytes(source.read_bytes())
