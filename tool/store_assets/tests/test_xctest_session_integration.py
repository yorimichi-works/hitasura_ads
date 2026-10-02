"""Prepared native identity must survive a different screenshot transport."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock
import uuid

spec = importlib.util.spec_from_file_location('session_xctest', Path(__file__).parents[1] / 'capture_session.py')
session = importlib.util.module_from_spec(spec)
spec.loader.exec_module(session)


class XCTestSessionIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.host = mock.Mock(work_deadline=None)
        self.capture = session.CaptureSession(self.host, 'device', self.root, 'ja', self.root / 'ja', self.root,
            screenshot_xctestrun=self.root / 'driver.xctestrun', screenshot_driver_sha='a' * 40)
        self.capture.pid = 123
        self.ready = {'session_id': self.capture.session_id, 'launch_id': self.capture.session_id,
                      'request_id': str(uuid.uuid4()), 'stage': 'ready', 'action': 'show',
                      'locale': 'ja', 'requested_scene': 'home', 'active_scene': 'home',
                      'native_simulator_attested': True, 'debug_mode': True, 'is_ios': True}
        self.capture.state_path.parent.mkdir(parents=True)
        self.capture.state_path.write_text(json.dumps(self.ready))

    def fake_capture(self, host, udid, xctestrun, path, pid, sha):
        path.write_bytes(b'unit fixture native bytes' * 2)
        return {'capture_method': 'xctest_existing_foreground_app', 'original_pid': pid,
                'driver_source_sha': sha}

    def test_xctest_transport_keeps_original_pid_and_ready_identity(self):
        with mock.patch.object(self.capture, 'wait', return_value=self.ready), \
             mock.patch.object(session, 'xctest_capture', side_effect=self.fake_capture) as screenshot, \
             mock.patch.object(session.struct, 'unpack', return_value=(1320, 2868)):
            record = self.capture.screenshot('home', 1, 'iphone_6_9', self.ready)
        self.assertEqual(screenshot.call_args.args[4:], (123, 'a' * 40))
        self.assertEqual(record['app_evidence_after_screenshot'], self.ready)
        self.assertEqual(record['screenshot_method'], 'xctest_existing_foreground_app')
        self.assertEqual(record['dimensions'], [1320, 2868])
        self.host.run.assert_not_called()

    def test_changed_session_is_rejected_before_delivery(self):
        def changed(*args):
            result = self.fake_capture(*args)
            self.capture.state_path.write_text(json.dumps({**self.ready, 'request_id': str(uuid.uuid4())}))
            return result
        with mock.patch.object(self.capture, 'wait', return_value=self.ready), \
             mock.patch.object(session, 'xctest_capture', side_effect=changed):
            with self.assertRaisesRegex(RuntimeError, 'session changed'):
                self.capture.screenshot('home', 1, 'iphone_6_9', self.ready)
        self.assertFalse((self.capture.dest / '01_home.png').exists())

    def test_full_xctest_reserve_required_before_any_driver_action(self):
        self.host.work_deadline = 164
        with mock.patch.object(session.time, 'monotonic', return_value=0), \
             mock.patch.object(session, 'xctest_capture') as screenshot:
            with self.assertRaisesRegex(TimeoutError, '165-second'):
                self.capture.screenshot('home', 1, 'iphone_6_9', self.ready)
        screenshot.assert_not_called()

    def test_original_pid_is_required(self):
        self.capture.pid = None
        with mock.patch.object(self.capture, 'wait', return_value=self.ready), \
             mock.patch.object(session, 'xctest_capture') as screenshot:
            with self.assertRaisesRegex(RuntimeError, 'original running native PID'):
                self.capture.screenshot('home', 1, 'iphone_6_9', self.ready)
        screenshot.assert_not_called()


if __name__ == '__main__':
    unittest.main()
