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


class ContainerLookupTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = pathlib.Path(self.directory.name)
        self.host = mock.Mock()

    def test_success_does_not_retry(self):
        self.host.run.return_value = str(self.path) + '\n'
        self.assertEqual(capture.lookup_app_container(self.host, 'device'), self.path)
        self.assertEqual(self.host.run.call_count, 1)

    def test_transient_timeout_retries_only_the_read(self):
        self.host.run.side_effect = [subprocess.TimeoutExpired('simctl', 30), str(self.path)]
        with mock.patch.object(capture.time, 'sleep') as sleep:
            self.assertEqual(capture.lookup_app_container(self.host, 'device'), self.path)
        sleep.assert_called_once_with(5)
        for call in self.host.run.call_args_list:
            self.assertEqual(call.args, ('xcrun', 'simctl', 'get_app_container', 'device', capture.BUNDLE, 'data'))
            self.assertEqual(call.kwargs['timeout'], 30)

    def test_third_timeout_stops_without_further_attempts(self):
        self.host.run.side_effect = subprocess.TimeoutExpired('simctl', 30)
        with mock.patch.object(capture.time, 'sleep') as sleep:
            with self.assertRaises(subprocess.TimeoutExpired):
                capture.lookup_app_container(self.host, 'device')
        self.assertEqual(self.host.run.call_count, 3)
        self.assertEqual(sleep.call_count, 2)

    def test_explicit_error_is_not_retried(self):
        self.host.run.side_effect = subprocess.CalledProcessError(2, 'simctl')
        with mock.patch.object(capture.time, 'sleep') as sleep:
            with self.assertRaises(subprocess.CalledProcessError):
                capture.lookup_app_container(self.host, 'device')
        self.assertEqual(self.host.run.call_count, 1)
        sleep.assert_not_called()

    def test_invalid_container_is_not_retried(self):
        self.host.run.return_value = 'relative/path'
        with self.assertRaisesRegex(RuntimeError, 'Invalid app data container'):
            capture.lookup_app_container(self.host, 'device')
        self.assertEqual(self.host.run.call_count, 1)

    def test_resource_snapshots_are_bounded_and_omit_arguments(self):
        capture.record_host_resources(self.host)
        calls = self.host.best_effort.call_args_list
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[0].args, ('ps', '-Ao', 'pid,ppid,%cpu,rss,comm'))
        self.assertTrue(all(call.kwargs['timeout'] == 5 for call in calls))


class RequestTransportTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = pathlib.Path(self.directory.name)
        self.launch_id = 'c1a9a9ab-3fb1-4300-a6f6-1ca22950679d'

    def test_request_is_atomic_and_contains_only_protocol_fields(self):
        value = capture.write_capture_request(self.root, 'en', 'home', self.launch_id)
        path = self.root / 'Documents/HitasuraCapture/request.json'
        self.assertEqual(json.loads(path.read_text()), value)
        self.assertFalse(path.with_name('request.pending').exists())
        self.assertEqual(set(value), {'schema_version', 'launch_id', 'locale', 'scene', 'created_at'})
        self.assertEqual(value['launch_id'], self.launch_id)
        self.assertEqual(value['schema_version'], 1)

    def test_second_request_replaces_old_identity(self):
        capture.write_capture_request(self.root, 'en', 'home', self.launch_id)
        fresh = 'a1234567-1234-4123-a123-123456789012'
        capture.write_capture_request(self.root, 'ja', 'collection', fresh)
        value = json.loads((self.root / 'Documents/HitasuraCapture/request.json').read_text())
        self.assertEqual(value['launch_id'], fresh)
        self.assertEqual(value['locale'], 'ja')

    def test_invalid_locale_scene_and_uuid_rejected_before_write(self):
        for locale, scene, launch_id in [('xx', 'home', self.launch_id), ('en', '../home', self.launch_id), ('en', 'home', 'bad')]:
            with self.assertRaises(ValueError):
                capture.write_capture_request(self.root, locale, scene, launch_id)
        self.assertFalse((self.root / 'Documents').exists())

    def test_launch_no_longer_transmits_capture_environment(self):
        host = capture.HostLog(self.root)
        with mock.patch.object(host, 'run', return_value=capture.BUNDLE + ': 123\n') as run, \
                mock.patch.object(capture, 'wait_for_capture', return_value={'stage': 'ready'}):
            capture.launch_capture(host, 'device', 'en', 'home', self.root, self.root, 90)
        self.assertNotIn('env', run.call_args.kwargs)
        self.assertTrue((self.root / 'home_request.json').exists())


class SceneSelectionTests(unittest.TestCase):
    def test_minimal_proof_selects_only_home(self):
        self.assertEqual(capture.select_capture_scenes('home'), ['home'])

    def test_video_requires_explicit_flag(self):
        self.assertEqual(capture.select_capture_scenes('home', True), ['home', 'preview'])
        self.assertNotIn('preview', capture.select_capture_scenes(','.join(capture.SCENES)))

    def test_empty_unknown_and_duplicate_scenes_rejected(self):
        for value in ['', 'home,', '../home', 'home,home', 'preview']:
            with self.assertRaises(ValueError):
                capture.select_capture_scenes(value)


class CosmeticStatusTests(unittest.TestCase):
    def test_success_is_reported(self):
        host = mock.Mock()
        self.assertTrue(capture.override_status_bar(host, 'device'))
        self.assertEqual(host.run.call_args.kwargs['timeout'], 30)

    def test_timeout_does_not_block_capture(self):
        host = mock.Mock()
        host.run.side_effect = subprocess.TimeoutExpired('simctl', 30)
        self.assertFalse(capture.override_status_bar(host, 'device'))
        self.assertTrue(host.stage.call_args.kwargs['capture_may_continue'])

    def test_command_failure_is_reported_nonfatally(self):
        host = mock.Mock()
        host.run.side_effect = subprocess.CalledProcessError(1, 'simctl')
        self.assertFalse(capture.override_status_bar(host, 'device'))


class BatchDeadlineTests(unittest.TestCase):
    def test_session_video_mode_does_not_append_legacy_preview(self):
        scenes = capture.select_capture_scenes('home,collection,pin,runner,rush', True, session_loop=True)
        self.assertEqual(scenes, ['home', 'collection', 'pin', 'runner', 'rush'])
        self.assertEqual(capture.select_capture_scenes('home', True), ['home', 'preview'])

    def test_cleanup_uses_one_shared_reserve_and_stops_commands_when_spent(self):
        with tempfile.TemporaryDirectory() as directory:
            host = capture.HostLog(pathlib.Path(directory))
            host.work_deadline = 100
            with mock.patch.object(capture.time, 'monotonic', return_value=105):
                host.begin_cleanup()
            self.assertEqual(host.cleanup_deadline, 190)
            with mock.patch.object(capture.time, 'monotonic', return_value=150):
                host.begin_cleanup()
            self.assertEqual(host.cleanup_deadline, 190)
            with mock.patch.object(capture.time, 'monotonic', return_value=195), \
                    mock.patch.object(capture.subprocess, 'run') as run:
                host.best_effort('xcrun', 'simctl', 'shutdown', 'device', timeout=30)
            run.assert_not_called()


if __name__ == '__main__':
    unittest.main()
