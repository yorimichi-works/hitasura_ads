import base64
import copy
import hashlib
import importlib.util
import json
import pathlib
import struct
import subprocess
import tempfile
import unittest
import zlib
from unittest import mock


spec = importlib.util.spec_from_file_location('xctest_screenshot', pathlib.Path(__file__).parents[1] / 'xctest_screenshot.py')
capture_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture_module)
UDID = 'BAE7F30B-6707-4BF4-8375-FE75C94DD2FA'
SHA = 'a' * 40
PNG = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=')
# Shape/fields copied from the two existing native xcresulttool QA exports.
ATTACHMENT = {
    'configurationName': 'Test Scheme Action', 'deviceId': UDID,
    'deviceName': 'iPhone 16 Pro Max',
    'exportedFileName': 'D8339F91-8EC8-4F37-A987-C6CF1A614F43.png',
    'isAssociatedWithFailure': False,
    'suggestedHumanReadableName': 'hitasura-existing-native-frame_0_BC7C5D1E-FF39-42C3-AE62-72FA0B5FF767.png',
    'timestamp': 1790975546.387,
}
MANIFEST = [{'testIdentifier': capture_module.TEST_IDENTIFIER,
             'testIdentifierURL': capture_module.TEST_IDENTIFIER_URL,
             'attachments': [ATTACHMENT]}]


class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = pathlib.Path(self.temporary.name)
        self.xctestrun = self.root / 'driver.xctestrun'
        self.xctestrun.write_bytes(b'mocked existing test runner')
        self.output = self.root / 'candidate.png'
        self.manifest = copy.deepcopy(MANIFEST)
        self.png = PNG
        self.host = mock.Mock()
        self.host.run.side_effect = self.command
        self.kill = mock.patch.object(capture_module.os, 'kill').start()
        self.addCleanup(mock.patch.stopall)

    def command(self, *args, **kwargs):
        if args[0] == 'xcodebuild':
            self.bundle = pathlib.Path(args[args.index('-resultBundlePath') + 1])
            self.bundle.mkdir()
            (self.bundle / 'diagnostic.txt').write_text('retained diagnostic')
        else:
            self.export = pathlib.Path(args[args.index('--output-path') + 1])
            self.export.mkdir()
            (self.export / 'manifest.json').write_text(json.dumps(self.manifest))
            (self.export / ATTACHMENT['exportedFileName']).write_bytes(self.png)
        return ''

    def capture(self, **changes):
        arguments = {'host': self.host, 'udid': UDID, 'xctestrun': self.xctestrun,
                     'output_path': self.output, 'original_pid': 1234, 'driver_source_sha': SHA}
        return capture_module.capture(**(arguments | changes))

    def test_exact_bounded_commands_and_unchanged_bytes_and_provenance(self):
        times = ['2026-10-02T22:00:00+00:00', '2026-10-02T22:00:02+00:00']
        with mock.patch.object(capture_module, '_utc_now', side_effect=times):
            result = self.capture()
        self.assertEqual(self.output.read_bytes(), PNG)
        self.assertEqual(result['raw_png_sha256'], hashlib.sha256(PNG).hexdigest())
        self.assertEqual(result['driver_source_sha'], SHA)
        self.assertEqual(result['original_pid'], 1234)
        self.assertEqual(result['dimensions'], [1, 1])
        self.assertEqual(result['test_identifier'], capture_module.TEST_IDENTIFIER)
        self.assertEqual(result['test_identifier_url'], capture_module.TEST_IDENTIFIER_URL)
        self.assertEqual(result['attachment_name'], capture_module.ATTACHMENT_NAME)
        self.assertEqual(result['capture_started_utc'], times[0])
        self.assertEqual(result['capture_finished_utc'], times[1])
        self.assertEqual(result['capture_method'], 'xctest_existing_foreground_app')
        expected = mock.call('xcodebuild', 'test-without-building', '-xctestrun', str(self.xctestrun.resolve()),
                             '-destination', f'platform=iOS Simulator,id={UDID}', '-destination-timeout', '30',
                             '-parallel-testing-enabled', 'NO', '-maximum-concurrent-test-simulator-destinations', '1',
                             '-only-testing:' + capture_module.ONLY_TEST, '-test-timeouts-enabled', 'YES',
                             '-default-test-execution-time-allowance', '90',
                             '-maximum-test-execution-time-allowance', '90',
                             '-resultBundlePath', result['xcresult_path'], timeout=120)
        self.assertEqual(self.host.run.call_args_list, [expected,
            mock.call('xcrun', 'xcresulttool', 'export', 'attachments', '--path', result['xcresult_path'],
                      '--output-path', result['attachment_export_path'], timeout=30)])
        self.assertEqual(self.kill.call_args_list, [mock.call(1234, 0)] * 3)
        self.assertNotIn('visual_qa', result)

    def test_each_capture_has_unique_result_and_export_paths(self):
        first = self.capture()
        second = self.capture(output_path=self.root / 'second.png')
        self.assertNotEqual(first['xcresult_path'], second['xcresult_path'])
        self.assertNotEqual(first['attachment_export_path'], second['attachment_export_path'])

    def test_invalid_pid_sha_udid_or_missing_runner_stops_before_command(self):
        cases = [{'original_pid': value} for value in (None, 0, -2, True, '1234')]
        cases += [{'driver_source_sha': 'a' * 39}, {'driver_source_sha': 'g' * 40},
                  {'udid': UDID + ',name=other'}, {'xctestrun': self.root / 'missing'}]
        for changes in cases:
            with self.subTest(changes=changes), self.assertRaises((ValueError, FileNotFoundError)):
                self.capture(**changes)
        self.host.run.assert_not_called()

    def test_dead_original_pid_blocks_capture_even_if_replacement_exists(self):
        def alive(pid, signal):
            if pid == 1234:
                raise ProcessLookupError('old app exited; replacement has PID 5678')
        self.kill.side_effect = alive
        with self.assertRaisesRegex(RuntimeError, 'Original app PID 1234'):
            self.capture()
        self.host.run.assert_not_called()
        self.assertFalse(self.output.exists())

    def test_exit_during_test_or_export_is_rejected_and_evidence_retained(self):
        for checks in ([None, ProcessLookupError()], [None, None, ProcessLookupError()]):
            self.kill.side_effect = checks
            with self.subTest(checks=len(checks)), self.assertRaises(RuntimeError):
                self.capture()
            self.assertFalse(self.output.exists())
            self.assertTrue((self.bundle / 'diagnostic.txt').is_file())

    def test_timeout_is_not_retried_and_checks_original_pid_afterward(self):
        def timeout(*args, **kwargs):
            self.command(*args, **kwargs)
            raise subprocess.TimeoutExpired(args, 120)
        self.host.run.side_effect = timeout
        with self.assertRaises(subprocess.TimeoutExpired):
            self.capture()
        self.assertEqual(self.host.run.call_count, 1)
        self.assertEqual(self.kill.call_args_list, [mock.call(1234, 0)] * 2)
        self.assertTrue((self.bundle / 'diagnostic.txt').is_file())

    def test_malformed_missing_duplicate_wrong_test_device_and_type_are_rejected(self):
        cases = [{}, [], [{'attachments': {}}], [{'attachments': [None]}]]
        duplicate = copy.deepcopy(MANIFEST)
        duplicate[0]['attachments'] *= 2
        cases.append(duplicate)
        for field, value in [('testIdentifier', 'OtherTests/testOther()'), ('testIdentifierURL', 'test://wrong')]:
            record = copy.deepcopy(MANIFEST)
            record[0][field] = value
            cases.append(record)
        for field, value in [('deviceId', 'other'), ('isAssociatedWithFailure', True),
                             ('suggestedHumanReadableName', ATTACHMENT['suggestedHumanReadableName'][:-4] + '.jpg'),
                             ('exportedFileName', 'frame.jpg'), ('exportedFileName', '../frame.png'),
                             ('exportedFileName', '/frame.png'), ('exportedFileName', 'folder/frame.png'),
                             ('exportedFileName', 'folder\\frame.png')]:
            record = copy.deepcopy(MANIFEST)
            record[0]['attachments'][0][field] = value
            cases.append(record)
        for manifest in cases:
            self.manifest = manifest
            with self.subTest(manifest=manifest), self.assertRaises(ValueError):
                self.capture()
            self.assertFalse(self.output.exists())
            self.assertTrue((self.export / 'manifest.json').exists())

    def test_export_source_and_manifest_symlinks_are_rejected(self):
        original_command = self.command
        for filename in (ATTACHMENT['exportedFileName'], 'manifest.json'):
            def symlink(*args, **kwargs):
                original_command(*args, **kwargs)
                if args[0] != 'xcodebuild':
                    source = self.export / filename
                    target = self.export / 'real-source'
                    source.rename(target)
                    source.symlink_to(target)
            self.host.run.side_effect = symlink
            with self.subTest(filename=filename), self.assertRaisesRegex(ValueError, 'Symlink'):
                self.capture()
            self.assertFalse(self.output.exists())

    def test_existing_output_is_never_overwritten(self):
        self.output.write_bytes(b'preserve me')
        with self.assertRaisesRegex(ValueError, 'new file'):
            self.capture()
        self.assertEqual(self.output.read_bytes(), b'preserve me')
        self.host.run.assert_not_called()

    def test_invalid_png_signature_crc_iend_and_dimensions_are_rejected(self):
        zero_width = bytearray(PNG)
        zero_width[16:20] = struct.pack('>I', 0)
        zero_width[29:33] = struct.pack('>I', zlib.crc32(zero_width[12:29]) & 0xffffffff)
        bad_crc = bytearray(PNG)
        bad_crc[29] ^= 1
        for png in (b'not a png', PNG[:20], PNG[:-12], PNG + b'trailing', bytes(bad_crc), bytes(zero_width)):
            self.png = png
            with self.subTest(png=png), self.assertRaises(ValueError):
                self.capture()
            self.assertFalse(self.output.exists())
            self.assertEqual((self.export / ATTACHMENT['exportedFileName']).read_bytes(), png)


if __name__ == '__main__':
    unittest.main()
