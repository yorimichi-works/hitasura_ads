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

    def test_explicit_older_installed_runtime_retains_real_device_identity(self):
        value = capture.select_devices(self.inventory, self.runtimes, '26.2', ['iphone_6_9'], '18.5', '15.0')
        self.assertEqual(value[0][1], self.old)
        self.assertEqual(value[0][2]['name'], 'iPhone 16 Pro Max')

    def test_compatibility_override_requires_minimum_os_and_real_availability(self):
        for runtime, minimum in [('18.5', None), ('18.5', '19.0'), ('18.6', '15.0'), ('27.0', '15.0')]:
            with self.subTest(runtime=runtime, minimum=minimum), self.assertRaises(RuntimeError):
                capture.select_devices(self.inventory, self.runtimes, '26.2', ['iphone_6_9'], runtime, minimum)


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


class InventoryReadTests(unittest.TestCase):
    def setUp(self):
        self.host = mock.Mock()
        self.host.work_deadline = None

    def test_successful_later_read_retries_only_inventory(self):
        self.host.run.side_effect = [subprocess.TimeoutExpired('simctl', 30), '{"devices": {}}']
        with mock.patch.object(capture.time, 'sleep') as sleep:
            self.assertEqual(capture.read_simulator_inventory(self.host, 'devices'), {'devices': {}})
        sleep.assert_called_once_with(5)
        for call in self.host.run.call_args_list:
            self.assertEqual(call.args, ('xcrun', 'simctl', 'list', 'devices', 'available', '--json'))
            self.assertEqual(call.kwargs['timeout'], 30)

    def test_exhaustion_stops_after_three_reads(self):
        self.host.run.side_effect = subprocess.TimeoutExpired('simctl', 30)
        with mock.patch.object(capture.time, 'sleep') as sleep:
            with self.assertRaises(subprocess.TimeoutExpired):
                capture.read_simulator_inventory(self.host, 'runtimes')
        self.assertEqual(self.host.run.call_count, 3)
        self.assertEqual(sleep.call_count, 2)

    def test_explicit_failure_and_invalid_json_are_not_retried(self):
        for failure in (subprocess.CalledProcessError(2, 'simctl'), ValueError('invalid JSON')):
            host = mock.Mock(work_deadline=None)
            host.run.side_effect = failure
            with self.subTest(failure=failure), mock.patch.object(capture.time, 'sleep') as sleep:
                with self.assertRaises(type(failure)):
                    capture.read_simulator_inventory(host, 'devices')
                self.assertEqual(host.run.call_count, 1)
                sleep.assert_not_called()
        for value in ('not JSON', '{}', '{"runtimes":{}}', '[]'):
            host = mock.Mock(work_deadline=None)
            host.run.return_value = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                capture.read_simulator_inventory(host, 'runtimes')
            self.assertEqual(host.run.call_count, 1)

    def test_retry_wait_does_not_cross_work_deadline(self):
        self.host.work_deadline = 105
        self.host.run.side_effect = subprocess.TimeoutExpired('simctl', 30)
        with mock.patch.object(capture.time, 'monotonic', return_value=100), mock.patch.object(capture.time, 'sleep') as sleep:
            with self.assertRaises(subprocess.TimeoutExpired):
                capture.read_simulator_inventory(self.host, 'devices')
        self.assertEqual(self.host.run.call_count, 1)
        sleep.assert_not_called()

    def test_runtime_shape_and_kind_are_strict(self):
        self.host.run.return_value = '{"runtimes": []}'
        self.assertEqual(capture.read_simulator_inventory(self.host, 'runtimes'), {'runtimes': []})
        self.assertEqual(self.host.run.call_args.args, ('xcrun', 'simctl', 'list', 'runtimes', '--json'))
        with self.assertRaises(ValueError):
            capture.read_simulator_inventory(self.host, 'boot')


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
        with self.assertRaisesRegex(ValueError, '--session-loop'):
            capture.select_capture_scenes('home', True)
        self.assertNotIn('preview', capture.select_capture_scenes(','.join(capture.SCENES), session_loop=True))

    def test_legacy_gameplay_screenshots_fail_closed(self):
        for scene in ('pin', 'runner', 'fruit', 'home,pin,runner', 'home,fruit'):
            with self.subTest(scene=scene), self.assertRaisesRegex(ValueError, '--session-loop'):
                capture.select_capture_scenes(scene)

    def test_default_fruit_slot_and_explicit_runner_are_truthfully_named(self):
        self.assertEqual(capture.SCENES, ['home', 'collection', 'pin', 'fruit', 'rush'])
        self.assertEqual(capture.select_capture_scenes(','.join(capture.SCENES), session_loop=True), capture.SCENES)
        self.assertEqual(capture.select_capture_scenes('home,fruit', session_loop=True), ['home', 'fruit'])
        self.assertEqual(capture.select_capture_scenes('runner', session_loop=True), ['runner'])

    def test_screenshot_and_video_record_ids_never_collide(self):
        image = capture.capture_record_key('ja', 'ipad_13', 'fruit', 'image')
        video = capture.capture_record_key('ja', 'ipad_13', 'fruit', 'video')
        self.assertEqual(image, 'ja/ipad_13/fruit_screenshot')
        self.assertEqual(video, 'ja/ipad_13/fruit')
        self.assertNotEqual(image, video)
        self.assertEqual(capture.capture_record_key('ja', 'ipad_13', 'home', 'image'), 'ja/ipad_13/home')
        self.assertEqual(capture.capture_record_key('ja', 'ipad_13', 'liquid', 'video'), 'ja/ipad_13/liquid')

    def test_full_requirements_need_both_fruit_image_and_video(self):
        keys = capture.required_record_keys(capture.LOCALES, ['iphone_6_9', 'ipad_13'], capture.SCENES, True)
        self.assertEqual(len(keys), 280)
        self.assertEqual(len(set(keys)), 280)
        image = 'ja/ipad_13/fruit_screenshot'
        video = 'ja/ipad_13/fruit'
        self.assertIn(image, keys)
        self.assertIn(video, keys)
        self.assertIn(video, [key for key in keys if key not in {image}])
        self.assertEqual(capture.required_record_keys(['ja'], ['ipad_13'], ['home', 'fruit']),
                         ['ja/ipad_13/home', image])

    def test_smoke_uses_actual_fruit_with_unchanged_native_bounds(self):
        workflow = (pathlib.Path(__file__).parents[3] / '.github/workflows/ios-check.yml').read_text()
        smoke = workflow.split('  native-smoke:', 1)[1].split('  native-probe:', 1)[0]
        for value in ('--locales ja,ar', '--scenes home,fruit', '--session-loop',
                      '--work-deadline-seconds 480', 'runs-on: macos-26', '--runtime-version 26.2',
                      'device: [iphone_6_9, ipad_13]', 'timeout-minutes: 20'):
            self.assertIn(value, smoke)
        self.assertNotIn('--scenes home,runner', smoke)
        self.assertNotIn('runs-on: macos-26-large', smoke)
        self.assertNotIn('runs-on: macos-26-xlarge', smoke)

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
        with self.assertRaisesRegex(ValueError, '--session-loop'):
            capture.select_capture_scenes('home', True)

    def test_install_uses_one_120_second_attempt_and_respects_work_deadline(self):
        source = pathlib.Path(capture.__file__).read_text()
        self.assertEqual(source.count("host.run('xcrun','simctl','install',udid,str(app), timeout=120)"), 1)
        with tempfile.TemporaryDirectory() as directory:
            host = capture.HostLog(pathlib.Path(directory))
            host.work_deadline = 145
            with mock.patch.object(capture.time, 'monotonic', return_value=100), \
                 mock.patch.object(capture.subprocess, 'run', return_value=mock.Mock(returncode=0)) as run:
                host.run('xcrun', 'simctl', 'install', 'device', 'app', timeout=120)
            run.assert_called_once()
            self.assertEqual(run.call_args.kwargs['timeout'], 45)

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


class ScreenshotStartupProbeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.host = mock.Mock(work_deadline=None)

    @staticmethod
    def png(width=2064, height=2752):
        import struct, zlib
        def chunk(kind, data):
            return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
        return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
                + chunk(b'IDAT', zlib.compress(b'\0' * ((width * 3 + 1) * height))) + chunk(b'IEND', b''))

    def test_one_bounded_prelaunch_command_cannot_count_as_app_evidence(self):
        self.host.run.side_effect = lambda *a, **kw: pathlib.Path(a[-1]).write_bytes(self.png())
        result = capture.probe_screenshot_startup(self.host, 'exact-device', 'ipad_13', self.root)
        self.host.run.assert_called_once_with('xcrun', 'simctl', 'io', 'exact-device', 'screenshot',
            '--type=png', str(self.root / 'screenshot_startup_probe/ipad_13.png'), timeout=60)
        self.assertEqual(result['dimensions'], [2064, 2752])
        self.assertIs(result['counts_as_app_evidence'], False)
        self.assertNotIn('app_evidence', result)
        self.assertNotIn('scene', result)
        self.assertEqual(result['status'], 'diagnostic_only_command_completed')

    def test_timeout_is_not_retried_or_accepted_even_with_complete_output(self):
        def timeout(*a, **kw):
            pathlib.Path(a[-1]).write_bytes(self.png())
            raise subprocess.TimeoutExpired('simctl', 60)
        self.host.run.side_effect = timeout
        with self.assertRaises(subprocess.TimeoutExpired):
            capture.probe_screenshot_startup(self.host, 'device', 'ipad_13', self.root)
        self.assertEqual(self.host.run.call_count, 1)
        self.assertFalse(any(c.args[0] == 'screenshot_startup_probe_complete' for c in self.host.stage.call_args_list))

    def test_native_dimensions_are_required(self):
        self.host.run.side_effect = lambda *a, **kw: pathlib.Path(a[-1]).write_bytes(self.png(1320, 2868))
        with self.assertRaisesRegex(ValueError, 'dimensions'):
            capture.probe_screenshot_startup(self.host, 'device', 'ipad_13', self.root)

    def test_corrupt_png_is_rejected(self):
        self.host.run.side_effect = lambda *a, **kw: pathlib.Path(a[-1]).write_bytes(b'partial')
        with self.assertRaisesRegex(ValueError, 'PNG'):
            capture.probe_screenshot_startup(self.host, 'device', 'ipad_13', self.root)

    def test_reserve_is_checked_before_command(self):
        self.host.work_deadline = 64
        with mock.patch.object(capture.time, 'monotonic', return_value=0):
            with self.assertRaisesRegex(TimeoutError, '65-second'):
                capture.probe_screenshot_startup(self.host, 'device', 'ipad_13', self.root)
        self.host.run.assert_not_called()

    def test_existing_output_is_not_reused(self):
        folder = self.root / 'screenshot_startup_probe'
        folder.mkdir(); (folder / 'ipad_13.png').write_bytes(b'old')
        with self.assertRaisesRegex(ValueError, 'existing'):
            capture.probe_screenshot_startup(self.host, 'device', 'ipad_13', self.root)
        self.host.run.assert_not_called()

    def test_probe_precedes_install_and_regular_capture_is_unchanged(self):
        text = pathlib.Path(capture.__file__).read_text()
        main = text.split('def main():', 1)[1]
        self.assertLess(main.index('= probe_screenshot_startup('), main.index("host.run('xcrun','simctl','install'"))
        session_text = pathlib.Path(capture.__file__).with_name('capture_session.py').read_text()
        self.assertIn('str(candidate), timeout=30)', session_text)
        workflow = pathlib.Path(capture.__file__).parents[2] / '.github/workflows/ios-check.yml'
        job = workflow.read_text().split('  native-ipad-startup-probe:', 1)[1]
        for required in ['38ef419d3970e53ed18de605df50453faeaacf30', '11272226107',
                         'dc0da045e9e2e01cedcda6c4c667f61a6c6c5292b725619cff83b1ba78d6383e',
                         '--locales ja,ar --devices ipad_13 --scenes home,runner',
                         '--work-deadline-seconds 480', 'reuse_capture_harness.py',
                         'unittest discover -s tool/store_assets/tests', 'unittest discover -s tool/release/tests']:
            self.assertIn(required, job)
        self.assertNotIn('continue-on-error', job)
        self.assertNotIn('secrets.', job)


if __name__ == '__main__':
    unittest.main()
