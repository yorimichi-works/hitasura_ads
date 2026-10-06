import copy
import importlib.util
import json
import pathlib
import struct
import subprocess
import tempfile
import unittest
import uuid
from unittest import mock

spec = importlib.util.spec_from_file_location('session', pathlib.Path(__file__).parents[1] / 'capture_session.py')
session = importlib.util.module_from_spec(spec)
spec.loader.exec_module(session)


class SessionTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        self.host = mock.Mock(work_deadline=None)
        self.capture = session.CaptureSession(self.host, 'device', self.root, 'ja', self.root / 'ja', self.root)

    def test_schema_two_request_is_atomic_and_fixed_path(self):
        value = session.write_request(self.root, str(uuid.uuid4()), str(uuid.uuid4()), 'ja', 'home', 'show')
        path = self.root / 'Documents/HitasuraCapture/request.json'
        self.assertEqual(json.loads(path.read_text()), value)
        self.assertEqual(value['schema_version'], 2)
        self.assertFalse(path.with_name('request.pending').exists())
        self.assertNotIn('path', value)

    def test_wrong_scene_action_or_id_is_rejected(self):
        valid = str(uuid.uuid4())
        for scene, action, identifier in [('other', 'show', valid), ('home', 'buy', valid), ('home', 'show', 'bad')]:
            with self.subTest(scene=scene, action=action), self.assertRaises(ValueError):
                session.write_request(self.root, valid, identifier, 'ja', scene, action)

    def test_full_identity_is_required(self):
        request = session.write_request(self.root, str(uuid.uuid4()), str(uuid.uuid4()), 'ja', 'home', 'show')
        state = {**request, 'launch_id': request['session_id'], 'requested_scene': 'home'}
        self.assertTrue(session.state_matches(state, request))
        for key in ('session_id', 'request_id', 'launch_id', 'locale', 'requested_scene', 'action'):
            with self.subTest(key=key):
                self.assertFalse(session.state_matches({**state, key: 'different'}, request))

    def test_work_deadline_stops_before_another_command(self):
        self.host.work_deadline = 1
        with mock.patch.object(session.time, 'monotonic', return_value=2):
            with self.assertRaisesRegex(TimeoutError, 'deadline'):
                self.capture.command('home', 'show')
        self.host.run.assert_not_called()

    def test_native_ready_state_must_match_active_scene(self):
        request = self.capture.command('home', 'show')
        state = {**request, 'launch_id': self.capture.session_id, 'requested_scene': 'home',
                 'stage': 'ready', 'active_scene': 'collection', 'native_simulator_attested': True,
                 'debug_mode': True, 'is_ios': True}
        with mock.patch.object(self.capture, 'states', return_value=[state]):
            with self.assertRaisesRegex(RuntimeError, 'active scene'):
                self.capture.wait(request, 'ready')

    def test_missing_native_attestation_stops(self):
        request = self.capture.command('home', 'show')
        state = {**request, 'launch_id': self.capture.session_id, 'requested_scene': 'home',
                 'stage': 'ready', 'active_scene': 'home', 'native_simulator_attested': False}
        with mock.patch.object(self.capture, 'states', return_value=[state]):
            with self.assertRaisesRegex(RuntimeError, 'native debug'):
                self.capture.wait(request, 'ready')

    def test_no_video_before_same_session_screenshot(self):
        with self.assertRaisesRegex(RuntimeError, 'same-session native screenshot'):
            self.capture.gameplay('liquid', 6)
        self.host.run.assert_not_called()

    def test_screenshot_needs_full_forty_five_second_reserve(self):
        self.host.work_deadline = 44
        with mock.patch.object(session.time, 'monotonic', return_value=0), \
                mock.patch.object(self.capture, 'show') as show:
            with self.assertRaisesRegex(TimeoutError, '45-second'):
                self.capture.screenshot('home', 1, 'iphone_6_9')
        show.assert_not_called()

    def test_gameplay_needs_full_seventy_five_second_reserve(self):
        self.capture.dimensions = [1320, 2868]
        self.host.work_deadline = 74
        with mock.patch.object(session.time, 'monotonic', return_value=0), \
                mock.patch.object(self.capture, 'show') as show:
            with self.assertRaisesRegex(TimeoutError, 'budget'):
                self.capture.gameplay('liquid', 6)
        show.assert_not_called()

    def test_missing_recorder_ack_never_starts_pointer_inputs(self):
        self.capture.dimensions = [1320, 2868]
        process = mock.Mock(returncode=0)
        process.poll.return_value = None
        with mock.patch.object(self.capture, 'show', return_value={'phase': 'play', 'time_left': 20}), \
                mock.patch.object(self.capture, 'command') as command, \
                mock.patch.object(session.subprocess, 'Popen', return_value=process), \
                mock.patch.object(session.time, 'monotonic', side_effect=[0, 0, 0, 20]), \
                mock.patch.object(session.time, 'sleep'):
            with self.assertRaisesRegex(TimeoutError, 'acknowledge'):
                self.capture.gameplay('liquid', 6)
        command.assert_not_called()
        process.send_signal.assert_called_once()

    def test_screenshot_timeout_retries_a_fresh_scene_using_another_file(self):
        paths = []
        def run(*args, **kwargs):
            path = pathlib.Path(args[-1]); paths.append(path)
            if len(paths) == 1:
                path.write_bytes(b'unaccepted partial output')
                raise subprocess.TimeoutExpired('simctl', 30)
            path.write_bytes(b'\x89PNG\r\n\x1a\n' + b'\x00\x00\x00\rIHDR' + struct.pack('>II', 2064, 2752))
        self.host.run.side_effect = run
        fresh = {'request_id': 'second'}
        with mock.patch.object(self.capture, 'show', return_value=fresh) as show, mock.patch.object(session.time, 'sleep'):
            result = self.capture.screenshot('home', 1, 'ipad_13', {'request_id': 'first'})
        show.assert_called_once_with('home')
        self.assertEqual(result['app_evidence'], fresh)
        self.assertEqual(result['screenshot_attempt'], 2)
        self.assertEqual(result['dimensions'], [2064, 2752])
        self.assertNotEqual(paths[0], paths[1])
        self.assertEqual(paths[0].read_bytes(), b'unaccepted partial output')

    def test_screenshot_explicit_error_is_not_retried(self):
        self.host.run.side_effect = subprocess.CalledProcessError(2, 'simctl')
        with mock.patch.object(self.capture, 'show') as show, mock.patch.object(session.time, 'sleep'):
            with self.assertRaises(subprocess.CalledProcessError):
                self.capture.screenshot('home', 1, 'ipad_13', {'request_id': 'first'})
        self.assertEqual(self.host.run.call_count, 1)
        show.assert_not_called()

    def test_second_screenshot_timeout_stops_without_accepting_partial_files(self):
        self.host.run.side_effect = subprocess.TimeoutExpired('simctl', 30)
        with mock.patch.object(self.capture, 'show', return_value={'request_id': 'second'}), mock.patch.object(session.time, 'sleep'):
            with self.assertRaises(subprocess.TimeoutExpired):
                self.capture.screenshot('home', 1, 'ipad_13', {'request_id': 'first'})
        self.assertEqual(self.host.run.call_count, 2)
        self.assertFalse((self.capture.dest / '01_home.png').exists())


class GameplayEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.ready = {'game_no': 3, 'phase': 'play', 'native_simulator_attested': True}
        self.started = {**self.ready, 'started_at': '2026-10-02T10:00:00Z',
                        'input_method': 'flutter_gesture_binding_pointer_events',
                        'random_seed': 'shipping_time_seed_unmodified'}
        self.complete = {**self.started, 'completed_at': '2026-10-02T10:00:10Z',
                         'elapsed_seconds': 10, 'game_time_start': 1, 'game_time_end': 11,
                         'input_events': [{'kind': 'down'}]}

    def test_real_active_ten_second_interval_passes(self):
        session.validate_gameplay(self.ready, self.started, self.complete, 'liquid')

    def test_short_ended_or_idle_clip_is_rejected(self):
        for key, value in [('elapsed_seconds', 9.99), ('game_time_end', 8), ('phase', 'result'),
                           ('input_events', []), ('native_simulator_attested', False),
                           ('completed_at', '2026-10-02T10:00:09Z')]:
            with self.subTest(key=key), self.assertRaises(RuntimeError):
                session.validate_gameplay(self.ready, self.started, {**self.complete, key: value}, 'liquid')

    def test_wrong_game_or_changed_seed_is_rejected(self):
        for key, value in [('game_no', 8), ('random_seed', 'forced')]:
            with self.subTest(key=key), self.assertRaises(RuntimeError):
                session.validate_gameplay(self.ready, self.started, {**self.complete, key: value}, 'liquid')

    def test_non_utc_timestamp_is_rejected(self):
        with self.assertRaises(ValueError):
            session.utc_parse('2026-10-02T10:00:00+09:00')




class GameplayScreenshotTests(unittest.TestCase):
    def setUp(self):
        SessionTests.setUp(self)
        self.ready = self.observation(stage='ready', action='show', request_id='show')

    def observation(self, **changes):
        value = {'session_id': self.capture.session_id, 'launch_id': self.capture.session_id,
                 'request_id': 'inspection', 'requested_scene': 'runner', 'active_scene': 'runner',
                 'locale': 'ja', 'action': 'inspect', 'stage': 'inspected',
                 'at': session.utc_now(), 'native_simulator_attested': True,
                 'debug_mode': True, 'is_ios': True,
                 'scene_request_id': 'show', 'game_view_mounted': True,
                 'same_game_session': True, 'game_no': 18, 'phase': 'play',
                 'game_time': .1, 'time_left': 20}
        return {**value, **changes}

    def png(self, *args, **kwargs):
        pathlib.Path(args[-1]).write_bytes(b'\x89PNG\r\n\x1a\n' + b'\x00\x00\x00\rIHDR'
                                         + struct.pack('>II', 2064, 2752))

    def test_absent_or_terminal_observations_are_recoverable_but_not_accepted(self):
        for change in ({'phase': 'intro'}, {'phase': 'ending'}, {'phase': 'done'},
                       {'phase': 'absent', 'game_view_mounted': False,
                        'same_game_session': False, 'game_no': None, 'active_scene': None}):
            with self.subTest(change=change), self.assertRaises(session.InactiveGameplay):
                session.validate_game_observation(self.observation(**change), 'runner', 'show')

    def test_invalid_dimensions_never_promote_candidate(self):
        def invalid(*args, **kwargs):
            pathlib.Path(args[-1]).write_bytes(b'\x89PNG\r\n\x1a\n' + b'\x00\x00\x00\rIHDR'
                                             + struct.pack('>II', 1, 1))
        self.host.run.side_effect = invalid
        with mock.patch.object(self.capture, 'inspect_game', return_value=self.ready), \
             mock.patch.object(session.time, 'sleep'):
            with self.assertRaisesRegex(RuntimeError, 'dimensions'):
                self.capture.screenshot('runner', 2, 'ipad_13', self.ready)
        self.assertFalse((self.capture.dest / '02_runner.png').exists())

    def test_actual_play_is_bracketed_without_four_second_delay(self):
        before = self.observation(game_time=.2)
        after = self.observation(game_time=.5)
        self.host.run.side_effect = self.png
        with mock.patch.object(self.capture, 'inspect_game', side_effect=[before, after]) as inspect, \
             mock.patch.object(session.time, 'sleep') as sleep:
            record = self.capture.screenshot('runner', 2, 'ipad_13', self.ready)
        self.assertEqual(inspect.call_count, 2)
        self.assertEqual(record['app_evidence_before_screenshot'], before)
        self.assertEqual(record['app_evidence_after_screenshot'], after)
        self.assertNotIn(mock.call(4), sleep.call_args_list)
        self.assertTrue(pathlib.Path(record['path']).exists())

    def test_pre_inspection_terminal_never_calls_screenshot_for_rejected_attempt(self):
        self.host.run.side_effect = self.png
        ended = self.observation(phase='ending')
        with mock.patch.object(self.capture, 'inspect_game', side_effect=[session.InactiveGameplay(ended), self.ready, self.ready]), \
             mock.patch.object(self.capture, 'show', return_value=self.ready) as show, \
             mock.patch.object(session.time, 'sleep'):
            record = self.capture.screenshot('runner', 2, 'ipad_13', self.ready)
        self.host.run.assert_called_once()
        show.assert_called_once_with('runner')
        self.assertEqual(record['screenshot_attempt'], 2)
        self.assertEqual(record['failed_screenshot_attempts'][0]['app_evidence'], ended)

    def test_post_inspection_terminal_retains_only_rejected_candidate_then_recovers(self):
        self.host.run.side_effect = self.png
        absent = self.observation(phase='absent', game_view_mounted=False, same_game_session=False,
                                  game_no=None, active_scene=None)
        with mock.patch.object(self.capture, 'inspect_game', side_effect=[self.ready, session.InactiveGameplay(absent), self.ready, self.ready]), \
             mock.patch.object(self.capture, 'show', return_value=self.ready), \
             mock.patch.object(session.time, 'sleep'):
            record = self.capture.screenshot('runner', 2, 'ipad_13', self.ready)
        self.assertEqual(self.host.run.call_count, 2)
        self.assertEqual(record['screenshot_attempt'], 2)
        rejected = self.root / record['failed_screenshot_attempts'][0]['path']
        self.assertTrue(rejected.exists())
        self.assertNotEqual(rejected, pathlib.Path(record['path']))

    def test_two_ended_captures_never_create_accepted_image(self):
        self.host.run.side_effect = self.png
        ended = session.InactiveGameplay(self.observation(phase='done'))
        with mock.patch.object(self.capture, 'inspect_game', side_effect=[self.ready, ended, self.ready, ended]), \
             mock.patch.object(self.capture, 'show', return_value=self.ready) as show, \
             mock.patch.object(session.time, 'sleep'):
            with self.assertRaises(session.InactiveGameplay):
                self.capture.screenshot('runner', 2, 'ipad_13', self.ready)
        self.assertEqual(self.host.run.call_count, 2)
        show.assert_called_once_with('runner')
        self.assertFalse((self.capture.dest / '02_runner.png').exists())

    def test_identity_failure_is_not_an_ordinary_game_retry(self):
        with mock.patch.object(self.capture, 'inspect_game', side_effect=RuntimeError('identity')), \
             mock.patch.object(self.capture, 'show') as show, mock.patch.object(session.time, 'sleep'):
            with self.assertRaisesRegex(RuntimeError, 'identity'):
                self.capture.screenshot('runner', 2, 'ipad_13', self.ready)
        self.host.run.assert_not_called()
        show.assert_not_called()

    def test_fresh_inspection_nonce_show_identity_and_time_are_required(self):
        def wait(request, stage, maximum):
            self.assertEqual(stage, 'inspected')
            self.assertEqual(maximum, 6)
            return self.observation(**request, requested_scene='runner', stage=stage,
                                    at=session.utc_now(), game_time=.2)
        with mock.patch.object(self.capture, 'wait', side_effect=wait):
            one = self.capture.inspect_game('runner', self.ready)
            two = self.capture.inspect_game('runner', self.ready)
        self.assertNotEqual(one['request_id'], two['request_id'])
        self.assertEqual(one['scene_request_id'], 'show')
        for change in ({'scene_request_id': 'old'}, {'same_game_session': False},
                       {'game_no': 1}, {'phase': 'unknown'}, {'game_time': float('nan')},
                       {'game_time': -.1}, {'game_time': 0}, {'time_left': True},
                       {'at': '2020-01-01T00:00:00Z'}):
            with self.subTest(change=change), mock.patch.object(self.capture, 'wait', return_value=self.observation(**change)):
                with self.assertRaises(RuntimeError) as error:
                    self.capture.inspect_game('runner', self.ready)
                self.assertNotIsInstance(error.exception, session.InactiveGameplay)

    def test_wait_requires_full_fresh_inspection_identity(self):
        request = self.capture.command('runner', 'inspect')
        valid = self.observation(**request, requested_scene='runner')
        for key in ('request_id', 'session_id', 'launch_id', 'locale', 'requested_scene', 'action'):
            invalid = {**valid, key: 'old'}
            with self.subTest(key=key), mock.patch.object(self.capture, 'states', return_value=[invalid]), \
                 mock.patch.object(session.time, 'monotonic', side_effect=[0, 0, 7]), \
                 mock.patch.object(session.time, 'sleep'):
                with self.assertRaises(TimeoutError):
                    self.capture.wait(request, 'inspected', maximum=6)

    def test_all_gameplay_ready_states_require_live_game_evidence(self):
        for scene, number in session.GAME_NUMBERS.items():
            request = self.capture.command(scene, 'show')
            ready = self.observation(**request, requested_scene=scene, active_scene=scene,
                                     stage='ready', scene_request_id=request['request_id'], game_no=number)
            with self.subTest(scene=scene), mock.patch.object(self.capture, 'states', return_value=[ready]):
                self.assertEqual(self.capture.wait(request, 'ready'), ready)
            for phase in ('intro', 'ending', 'done', None):
                with self.subTest(scene=scene, phase=phase), \
                     mock.patch.object(self.capture, 'states', return_value=[{**ready, 'phase': phase}]):
                    with self.assertRaises(RuntimeError):
                        self.capture.wait(request, 'ready')

    def test_no_budget_for_retry_leaves_no_accepted_image(self):
        self.host.run.side_effect = self.png
        ended = session.InactiveGameplay(self.observation(phase='ending'))
        with mock.patch.object(self.capture, 'inspect_game', side_effect=[self.ready, ended]), \
             mock.patch.object(self.capture, 'budget', side_effect=[45, 45, 47]), \
             mock.patch.object(self.capture, 'show') as show, mock.patch.object(session.time, 'sleep'):
            with self.assertRaises(session.InactiveGameplay):
                self.capture.screenshot('runner', 2, 'ipad_13', self.ready)
        show.assert_not_called()
        self.assertFalse((self.capture.dest / '02_runner.png').exists())


if __name__ == '__main__':
    unittest.main()
