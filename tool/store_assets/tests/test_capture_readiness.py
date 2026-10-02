import importlib.util
import json
import pathlib
import tempfile
import subprocess
from unittest import mock
import unittest

spec = importlib.util.spec_from_file_location('capture', pathlib.Path(__file__).parents[1] / 'capture_ios_simulator.py')
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)

class ReadinessTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = pathlib.Path(self.directory.name) / 'state.json'

    def write(self, **updates):
        value = {'launch_id':'fresh','stage':'ready','locale':'ja','requested_scene':'home'}
        value.update(updates)
        self.path.write_text(json.dumps(value))

    def poll(self):
        return capture.wait_for_capture(self.path, 'ja', 'home', 'fresh', timeout=.025, poll=.002)

    def test_ready(self):
        self.write()
        self.assertEqual(self.poll()['stage'], 'ready')

    def test_missing_file_is_bounded(self):
        with self.assertRaisesRegex(TimeoutError, 'last_stage=None'):
            self.poll()

    def test_stale_launch_is_rejected(self):
        self.write(launch_id='stale')
        with self.assertRaises(TimeoutError):
            self.poll()

    def test_startup_stage_is_reported(self):
        self.write(stage='controller_start')
        with self.assertRaisesRegex(TimeoutError, 'controller_start'):
            self.poll()

    def test_explicit_error_is_reported(self):
        self.write(stage='error', error='Missing simulator environment')
        with self.assertRaisesRegex(RuntimeError, 'Missing simulator environment'):
            self.poll()

    def test_wrong_locale_is_rejected(self):
        self.write(locale='en')
        with self.assertRaisesRegex(RuntimeError, 'mismatch'):
            self.poll()

    def test_partial_json_is_bounded(self):
        self.path.write_text('{')
        with self.assertRaises(TimeoutError):
            self.poll()

class RuntimeSelectionTests(unittest.TestCase):
    def setUp(self):
        self.old = 'com.apple.CoreSimulator.SimRuntime.iOS-18-5'
        self.new = 'com.apple.CoreSimulator.SimRuntime.iOS-26-2'
        self.runtimes = {'runtimes': [
            {'identifier': self.old, 'version': '18.5', 'isAvailable': True},
            {'identifier': self.new, 'version': '26.2', 'isAvailable': True},
        ]}
        self.inventory = {'devices': {
            self.old: [{'name': 'iPhone 16 Pro Max', 'udid': 'old', 'isAvailable': True}],
            self.new: [{'name': 'iPhone 17 Pro Max', 'udid': 'new', 'isAvailable': True}],
        }}

    def test_sdk_match_precedes_device_name_preference(self):
        value = capture.select_devices(self.inventory, self.runtimes, '18.5', ['iphone_6_9'])
        self.assertEqual(value[0][2]['udid'], 'old')

    def test_new_sdk_selects_new_runtime(self):
        value = capture.select_devices(self.inventory, self.runtimes, '26.2', ['iphone_6_9'])
        self.assertEqual(value[0][2]['udid'], 'new')

    def test_missing_exact_runtime_does_not_fall_back(self):
        with self.assertRaisesRegex(RuntimeError, 'SDK-matched'):
            capture.select_devices(self.inventory, self.runtimes, '26.3', ['iphone_6_9'])

    def test_unavailable_runtime_rejected(self):
        self.runtimes['runtimes'][1]['isAvailable'] = False
        with self.assertRaises(RuntimeError):
            capture.select_devices(self.inventory, self.runtimes, '26.2', ['iphone_6_9'])

    def test_bad_sdk_output_rejected(self):
        with self.assertRaisesRegex(RuntimeError, 'Unexpected'):
            capture.select_devices(self.inventory, self.runtimes, 'unknown', ['iphone_6_9'])


class HostCommandTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = pathlib.Path(self.directory.name)
        self.host = capture.HostLog(self.root)

    def test_timeout_is_logged_and_propagated(self):
        with mock.patch.object(capture.subprocess, 'run', side_effect=subprocess.TimeoutExpired('simctl', 60)) as run:
            with self.assertRaises(subprocess.TimeoutExpired):
                self.host.run('xcrun', 'simctl', 'install', 'device', 'app', timeout=60)
        self.assertEqual(run.call_args.kwargs['timeout'], 60)
        events = [json.loads(line) for line in (self.root / 'host_events.jsonl').read_text().splitlines()]
        self.assertEqual(events[0]['stage'], 'command_start')
        self.assertEqual(events[0]['timeout_seconds'], 60)
        self.assertEqual(events[-1]['stage'], 'command_failed')
        self.assertEqual(json.loads((self.root / 'host_state.json').read_text())['stage'], 'command_failed')

    def test_default_command_has_finite_timeout(self):
        with mock.patch.object(capture.subprocess, 'run', return_value=mock.Mock(returncode=0)) as run:
            self.host.run('xcrun', 'simctl', 'list')
        self.assertEqual(run.call_args.kwargs['timeout'], 30)

    def test_cleanup_timeout_does_not_mask_original_failure(self):
        with mock.patch.object(self.host, 'run', side_effect=subprocess.TimeoutExpired('simctl', 10)):
            self.assertEqual(self.host.best_effort('xcrun', 'simctl', 'terminate', timeout=10), '')

    def test_app_exit_before_readiness_is_detected(self):
        with self.assertRaisesRegex(RuntimeError, 'exited before readiness'):
            capture.wait_for_capture(self.root / 'missing.json', 'en', 'home', 'id', alive=lambda: False)

    def test_launch_uses_nonblocking_output_and_finite_timeout(self):
        evidence = {'stage': 'ready'}
        with mock.patch.object(self.host, 'run', return_value=capture.BUNDLE + ': 123\n') as run, \
                mock.patch.object(capture, 'wait_for_capture', return_value=evidence) as wait:
            result = capture.launch_capture(self.host, 'device', 'ja', 'home', self.root, self.root, 90)
        command = run.call_args.args
        self.assertNotIn('--console', command)
        self.assertTrue(any(arg.startswith('--stdout=/') for arg in command))
        self.assertTrue(any(arg.startswith('--stderr=/') for arg in command))
        self.assertEqual(run.call_args.kwargs['timeout'], 30)
        self.assertTrue(callable(wait.call_args.kwargs['alive']))
        self.assertEqual(result, evidence)

    def test_setup_diagnostics_are_bounded_without_app_container(self):
        with mock.patch.object(self.host, 'best_effort', return_value='') as run:
            capture.collect_diagnostics(self.host, 'device', None, self.root / 'failure')
        self.assertEqual(run.call_count, 4)
        self.assertTrue(all(call.kwargs['timeout'] == 10 for call in run.call_args_list))


if __name__ == '__main__':
    unittest.main()
