#!/usr/bin/env python3
"""Capture unchanged production UI on native iOS simulators, with startup evidence.
No signing, credentials, or App Store upload. Raw screenshots/video require QA.
"""
import argparse
import hashlib
import json
import os
import pathlib
import plistlib
import re
import shutil
import signal
import struct
import subprocess
import sys
import time
import uuid

LOCALES = ['en','ja','zh','zh_TW','ko','es','fr','de','pt','ru','it','hi','bn','ar','ur','fa','id','tr','vi','th']
SCENES = ['home','collection','pin','runner','rush']
BUNDLE = 'com.syamo.hitasuraads'

class HostLog:
    """Persist intent before each bounded command so a killed job is diagnosable."""
    def __init__(self, output):
        self.output = output
        self.commands = output / 'host_commands'
        self.commands.mkdir(parents=True, exist_ok=True)
        self.sequence = 0

    def stage(self, name, **details):
        event = {'time_utc': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
                 'stage': name, **details}
        encoded = json.dumps(event)
        with (self.output / 'host_events.jsonl').open('a') as stream:
            stream.write(encoded + '\n')
            stream.flush()
            os.fsync(stream.fileno())
        pending = self.output / 'host_state.pending'
        pending.write_text(json.dumps(event, indent=2))
        pending.replace(self.output / 'host_state.json')
        print(encoded, flush=True)

    def run(self, *args, timeout=30, check=True, env=None):
        self.sequence += 1
        prefix = self.commands / f'{self.sequence:04}'
        self.stage('command_start', command=list(args), timeout_seconds=timeout,
                   log_prefix=str(prefix))
        try:
            with pathlib.Path(str(prefix) + '.stdout').open('w') as stdout, \
                    pathlib.Path(str(prefix) + '.stderr').open('w') as stderr:
                result = subprocess.run(args, text=True, stdout=stdout, stderr=stderr,
                                        timeout=timeout, check=False, env=env)
            output = pathlib.Path(str(prefix) + '.stdout').read_text()
            error = pathlib.Path(str(prefix) + '.stderr').read_text()
            self.stage('command_done', command=list(args), returncode=result.returncode)
            if check and result.returncode:
                raise subprocess.CalledProcessError(result.returncode, args, output, error)
            return output
        except Exception as error:
            self.stage('command_failed', command=list(args), error=str(error))
            raise

    def best_effort(self, *args, timeout=10):
        try:
            return self.run(*args, timeout=timeout, check=False)
        except Exception as error:
            self.stage('diagnostic_or_cleanup_failed', command=list(args), error=str(error))
            return ''


def select_devices(inventory, runtimes, sdk_version, groups):
    """Only use an available iOS runtime matching the selected Xcode SDK major/minor."""
    if not re.fullmatch(r'\d+\.\d+(?:\.\d+)?', sdk_version):
        raise RuntimeError(f'Unexpected iPhoneSimulator SDK version: {sdk_version!r}')
    target = tuple(int(part) for part in sdk_version.split('.')[:2])
    eligible = [runtime for runtime in runtimes['runtimes']
                if runtime.get('isAvailable') and runtime.get('identifier', '').startswith('com.apple.CoreSimulator.SimRuntime.iOS-')
                and tuple(int(part) for part in runtime['version'].split('.')[:2]) == target]
    eligible.sort(key=lambda runtime: tuple(int(p) for p in runtime['version'].split('.')), reverse=True)
    choices = {
        'iphone_6_9': ['iPhone 17 Pro Max', 'iPhone 16 Pro Max', 'iPhone 15 Pro Max', 'iPhone 14 Pro Max'],
        'ipad_13': ['iPad Pro 13-inch (M4)', 'iPad Pro 13-inch (M5)', 'iPad Pro (12.9-inch) (6th generation)'],
    }
    selected = []
    for group in groups:
        if group not in choices:
            raise RuntimeError(f'Unknown device group: {group}')
        chosen = next(((runtime['identifier'], device)
                       for runtime in eligible for name in choices[group]
                       for device in inventory['devices'].get(runtime['identifier'], [])
                       if device.get('isAvailable') and device['name'] == name), None)
        if chosen is None:
            raise RuntimeError(f'No eligible {group} on an available iOS {sdk_version} SDK-matched runtime; refusing a different runtime or stretched image.')
        selected.append((group, *chosen))
    return selected


def process_alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False


def record_host_resources(host):
    """Read-only host evidence; omit environment variables and process arguments."""
    host.best_effort('ps', '-Ao', 'pid,ppid,%cpu,rss,comm', timeout=5)
    host.best_effort('vm_stat', timeout=5)


def lookup_app_container(host, udid):
    """Retry only a timed-out read, never installation, launch or an explicit error."""
    for attempt in range(1, 4):
        host.stage('container_lookup', udid=udid, attempt=attempt, maximum_attempts=3)
        try:
            output = host.run('xcrun', 'simctl', 'get_app_container', udid,
                              BUNDLE, 'data', timeout=30).strip()
        except subprocess.TimeoutExpired:
            if attempt == 3:
                raise
            host.stage('container_lookup_retry_wait', seconds=5)
            time.sleep(5)
            continue
        container = pathlib.Path(output)
        if not container.is_absolute() or not container.is_dir():
            raise RuntimeError(f'Invalid app data container: {output!r}')
        return container
    raise AssertionError('Container lookup must return or raise within three attempts')


def wait_for_capture(path, locale, scene, launch_id, timeout=90, poll=.25, alive=None):
    """Reject stale or failed startup evidence; report the last stage on timeout."""
    deadline = time.monotonic() + timeout
    last = None
    while time.monotonic() < deadline:
        if alive is not None and not alive():
            raise RuntimeError(f'Capture app exited before readiness; last_stage={last}')
        try:
            state = json.loads(path.read_text())
            if state.get('launch_id') == launch_id:
                last = state
                if state.get('stage') == 'error':
                    raise RuntimeError(f'Capture app error: {state}')
                if state.get('stage') == 'ready':
                    if state.get('locale') != locale or state.get('requested_scene') != scene:
                        raise RuntimeError(f'Launch environment mismatch: {state}')
                    return state
        except (FileNotFoundError, json.JSONDecodeError):
            pass
        time.sleep(poll)
    raise TimeoutError(f'Capture not ready after {timeout}s; state_path={path}; last_stage={last}')


def collect_diagnostics(host, udid, state_path, dest):
    """All diagnostics are best-effort and independently bounded, including setup failures."""
    dest.mkdir(parents=True, exist_ok=True)
    if state_path is not None:
        for suffix in ['', '.events.jsonl']:
            source = pathlib.Path(str(state_path) + suffix)
            if source.exists():
                shutil.copyfile(source, dest / ('startup_state.json' if not suffix else 'startup_events.jsonl'))
    commands = {'simulator_devices.json': ['xcrun', 'simctl', 'list', 'devices', '--json']}
    if udid:
        commands.update({
            'runner_system_log.txt': ['xcrun','simctl','spawn',udid,'log','show','--style','compact','--last','3m','--predicate','process == "Runner"'],
            'launchctl_jobs.txt': ['xcrun','simctl','spawn',udid,'launchctl','list'],
            'screenshot_command.txt': ['xcrun','simctl','io',udid,'screenshot','--type=png',str(dest/'startup_failure.png')],
        })
    for name, command in commands.items():
        (dest / name).write_text(host.best_effort(*command, timeout=10))
    crash_root = pathlib.Path.home() / 'Library/Logs/DiagnosticReports'
    for source in sorted(crash_root.glob('Runner*'), key=lambda p: p.stat().st_mtime, reverse=True)[:5]:
        if source.is_file():
            shutil.copyfile(source, dest / source.name)


def launch_capture(host, udid, locale, scene, container, dest, timeout):
    state_path = container / 'Documents/HitasuraCapture/state.json'
    state_path.parent.mkdir(parents=True, exist_ok=True)
    launch_id = str(uuid.uuid4())
    env = dict(os.environ,
        SIMCTL_CHILD_HITASURA_CAPTURE_LOCALE=locale,
        SIMCTL_CHILD_HITASURA_CAPTURE_SCENE=scene,
        SIMCTL_CHILD_HITASURA_CAPTURE_STATE_PATH=str(state_path),
        SIMCTL_CHILD_HITASURA_CAPTURE_ID=launch_id)
    stdout = (dest / f'{scene}_stdout.log').resolve()
    stderr = (dest / f'{scene}_stderr.log').resolve()
    # --console blocks for the entire app lifetime. These verified flags return
    # immediately with the app PID while preserving separate app output files.
    host.stage('app_launch', udid=udid, locale=locale, scene=scene, launch_id=launch_id)
    output = host.run('xcrun','simctl','launch',f'--stdout={stdout}',f'--stderr={stderr}',
                      '--terminate-running-process',udid,BUNDLE, timeout=30, env=env)
    match = re.search(re.escape(BUNDLE) + r':\s*(\d+)', output)
    if not match:
        raise RuntimeError(f'Launch succeeded but returned no app PID: {output!r}')
    pid = int(match.group(1))
    host.stage('awaiting_app_readiness', pid=pid, state_path=str(state_path), timeout_seconds=timeout)
    evidence = wait_for_capture(state_path, locale, scene, launch_id, timeout=timeout,
                                alive=lambda: process_alive(pid))
    for suffix in ['', '.events.jsonl']:
        source = pathlib.Path(str(state_path) + suffix)
        if source.exists():
            shutil.copyfile(source, dest / f'{scene}_state{suffix or ".json"}')
    host.stage('app_ready', pid=pid, locale=locale, scene=scene)
    return evidence


def record_video(host, udid, path):
    command = ['xcrun','simctl','io',udid,'recordVideo','--codec=h264','--force',str(path)]
    host.stage('recording_start', command=command, duration_seconds=20, finalize_timeout_seconds=30)
    with path.with_suffix('.recording.log').open('w') as output:
        video = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT, text=True)
        try:
            time.sleep(20)
            if video.poll() is None:
                video.send_signal(signal.SIGINT)
            video.wait(timeout=30)
        finally:
            if video.poll() is None:
                video.kill()
                video.wait(timeout=5)
    if video.returncode not in [0, -signal.SIGINT, 130] or not path.exists() or path.stat().st_size == 0:
        raise RuntimeError(f'Native recording failed: {path}')
    host.stage('recording_done', path=str(path), bytes=path.stat().st_size)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', default='build/ios/iphonesimulator/Runner.app')
    parser.add_argument('--output', default='build/store_assets/native_ios')
    parser.add_argument('--locales', default=','.join(LOCALES))
    parser.add_argument('--devices', default='iphone_6_9,ipad_13')
    parser.add_argument('--videos', action='store_true')
    parser.add_argument('--startup-timeout', type=float, default=90)
    args = parser.parse_args()
    if sys.platform != 'darwin':
        parser.error('Native captures require macOS/Xcode; Flutter previews are not native captures.')
    locales = args.locales.split(',')
    if any(locale not in LOCALES for locale in locales):
        parser.error('Unknown locale')
    if not 0 < args.startup_timeout <= 120:
        parser.error('Startup timeout must be between 0 and 120 seconds.')
    out = pathlib.Path(args.output).resolve()
    out.mkdir(parents=True, exist_ok=True)
    host = HostLog(out)
    manifest = {'origin':'native_ios_simulator','app_target':'tool/store_assets/native_capture_main.dart','production_ui_unchanged':True,
        'fixture':'40 discovered games, 1234 coins, 900 XP, 5 tickets; notifications/audio/external ads disabled; production purchase initialization preserved',
        'status':'in_progress','records':[]}
    def save():
        pending = out / 'manifest.pending'
        pending.write_text(json.dumps(manifest, indent=2))
        pending.replace(out / 'manifest.json')
    save()
    udid = None
    state_path = None
    try:
        host.stage('inventory_start')
        inventory = json.loads(host.run('xcrun','simctl','list','devices','available','--json', timeout=30))
        runtimes = json.loads(host.run('xcrun','simctl','list','runtimes','--json', timeout=30))
        sdk_version = host.run('xcrun','--sdk','iphonesimulator','--show-sdk-version', timeout=30).strip()
        (out/'simulator_inventory.json').write_text(json.dumps(inventory, indent=2))
        (out/'simulator_runtimes.json').write_text(json.dumps(runtimes, indent=2))
        (out/'simctl_launch_help.txt').write_text(host.run('xcrun','simctl','help','launch', timeout=30))
        selected = select_devices(inventory, runtimes, sdk_version, args.devices.split(','))
        manifest.update({'simulator_sdk_version':sdk_version, 'selected_devices':selected})
        save()
        host.stage('runtime_selected', sdk_version=sdk_version, devices=selected)
        app = pathlib.Path(args.app).resolve()
        privacy = [{'path':str(file.relative_to(app)), 'contents':plistlib.loads(file.read_bytes())} for file in app.rglob('PrivacyInfo.xcprivacy')]
        packages = [{'path':str(file), 'contents':json.loads(file.read_text())} for file in pathlib.Path('ios').rglob('Package.resolved')]
        (out/'bundled_privacy_and_packages.json').write_text(json.dumps({'privacy_manifests':privacy,'resolved_packages':packages}, indent=2))
        for group, runtime, device in selected:
            udid = device['udid']
            state_path = None
            host.stage('device_setup', group=group, runtime=runtime, udid=udid, device_name=device['name'])
            if device['state'] != 'Booted':
                host.run('xcrun','simctl','boot',udid, timeout=120)
            host.run('xcrun','simctl','bootstatus',udid,'-b', timeout=120)
            record_host_resources(host)
            host.run('xcrun','simctl','status_bar',udid,'override','--time','9:41','--dataNetwork','wifi','--wifiMode','active','--wifiBars','3','--batteryState','charged','--batteryLevel','100', timeout=30)
            host.run('xcrun','simctl','install',udid,str(app), timeout=60)
            container = lookup_app_container(host, udid)
            state_path = container / 'Documents/HitasuraCapture/state.json'
            for locale in locales:
                dest = out/locale/group
                dest.mkdir(parents=True, exist_ok=True)
                for index, scene in enumerate(SCENES + (['preview'] if args.videos else []), 1):
                    try:
                        evidence = launch_capture(host, udid, locale, scene, container, dest, args.startup_timeout)
                        record = {'locale':locale,'device_group':group,'device_name':device['name'],'runtime':runtime,'scene':scene,'app_evidence':evidence}
                        if scene == 'preview':
                            path = dest/'preview_native.mov'
                            record_video(host, udid, path)
                            record.update({'audio':'not captured; silent','native_unencoded':True})
                        else:
                            time.sleep(4 if scene in ['pin','runner'] else 2)
                            path = dest/f'{index:02}_{scene}.png'
                            host.run('xcrun','simctl','io',udid,'screenshot','--type=png',str(path), timeout=30)
                            with path.open('rb') as image:
                                image.seek(16)
                                width, height = struct.unpack('>II', image.read(8))
                            allowed = {(1290,2796),(1320,2868),(1260,2736)} if group == 'iphone_6_9' else {(2048,2732),(2064,2752)}
                            if (width,height) not in allowed:
                                raise RuntimeError(f'Unexpected dimensions {width}x{height}')
                            record['dimensions'] = [width,height]
                        record.update({'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'status':'raw_native_capture_requires_pixel_review_and_normalization'})
                        manifest['records'].append(record)
                        save()
                    except Exception:
                        collect_diagnostics(host, udid, state_path, dest / f'{scene}_failure')
                        raise
                    finally:
                        host.best_effort('xcrun','simctl','terminate',udid,BUNDLE, timeout=10)
            host.run('xcrun','simctl','shutdown',udid, timeout=30)
            udid = None
        manifest['status'] = 'captured_pending_pixel_review'
        save()
        host.stage('capture_complete', records=len(manifest['records']))
    except Exception as error:
        manifest.update({'status':'failed','error':str(error)})
        save()
        host.stage('capture_failed', error=str(error), udid=udid)
        record_host_resources(host)
        collect_diagnostics(host, udid, state_path, out / 'setup_or_capture_failure')
        raise
    finally:
        if udid:
            host.best_effort('xcrun','simctl','terminate',udid,BUNDLE, timeout=10)
            host.best_effort('xcrun','simctl','shutdown',udid, timeout=30)
    print(f'Native source captures saved in {out}; review pixels and encoding before upload.')

if __name__ == '__main__':
    main()
