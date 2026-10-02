"""Source guard against shipping the debug capture bridge in release/device builds."""
import pathlib
import importlib.util
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[3]


class SimulatorCaptureBridgeTests(unittest.TestCase):
    def test_native_capture_channel_is_inside_debug_simulator_guard(self):
        source = (ROOT / 'ios/Runner/AppDelegate.swift').read_text()
        marker = '#if DEBUG && targetEnvironment(simulator)'
        start = source.index(marker)
        end = source.index('#endif', start)
        guarded = source[start:end]
        self.assertIn('name: "hitasura_ads/simulator_capture"', guarded)
        self.assertIn('call.method == "documentsDirectory"', guarded)
        self.assertIn('for: .documentDirectory, in: .userDomainMask', guarded)
        self.assertIn('"isSimulator": true', guarded)
        self.assertEqual(source.count('hitasura_ads/simulator_capture'), 1)
        self.assertNotIn('ProcessInfo', guarded)
        self.assertNotIn('environment[', guarded)
        self.assertNotIn('native_capture', (ROOT / 'lib/main.dart').read_text())


class EffectiveCaptureBridgeTests(unittest.TestCase):
    def test_runner_debug_defines_swift_debug_not_just_runner_tests(self):
        source = (ROOT / 'ios/Runner.xcodeproj/project.pbxproj').read_text()
        start = source.index('97C147061CF9000F007C117D /* Debug */ = {')
        end = source.index('\n\t\t};', start)
        self.assertIn('SWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited) DEBUG";', source[start:end])
        for marker in ('97C147071CF9000F007C117D /* Release */ = {', '249021D4217E4FDB00AE95B9 /* Profile */ = {'):
            start = source.index(marker)
            end = source.index('\n\t\t};', start)
            self.assertNotIn('SWIFT_ACTIVE_COMPILATION_CONDITIONS', source[start:end])

    def setUp(self):
        spec = importlib.util.spec_from_file_location('verify_bridge', ROOT / 'tool/store_assets/verify_native_bridge.py')
        self.checker = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.checker)
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.app = pathlib.Path(self.directory.name)

    def test_native_bridge_marker_passes(self):
        (self.app / 'Runner.debug.dylib').write_bytes(b'\xcf\xfa\xed\xfe' + self.checker.CHANNEL)
        self.assertIn('runtime_proof_pending', self.checker.verify(self.app)['status'])

    def test_missing_bridge_fails(self):
        (self.app / 'Runner').write_bytes(b'\xcf\xfa\xed\xfe' + b'hitasura_ads/purchases')
        with self.assertRaisesRegex(RuntimeError, 'bridge absent'):
            self.checker.verify(self.app)

    def test_dart_kernel_marker_cannot_fake_native_bridge(self):
        (self.app / 'Runner').write_bytes(b'\xcf\xfa\xed\xfe')
        assets = self.app / 'Frameworks/App.framework/flutter_assets'
        assets.mkdir(parents=True)
        (assets / 'kernel_blob.bin').write_bytes(self.checker.CHANNEL)
        with self.assertRaisesRegex(RuntimeError, 'bridge absent'):
            self.checker.verify(self.app)

    def test_non_native_file_rejected(self):
        (self.app / 'Runner').write_bytes(self.checker.CHANNEL)
        with self.assertRaisesRegex(RuntimeError, 'Mach-O'):
            self.checker.verify(self.app)


if __name__ == '__main__':
    unittest.main()
