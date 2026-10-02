import copy
import importlib.util
import json
import pathlib
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


if __name__ == '__main__':
    unittest.main()
