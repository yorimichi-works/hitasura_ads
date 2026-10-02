"""Source guard against shipping the debug capture bridge in release/device builds."""
import pathlib
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


if __name__ == '__main__':
    unittest.main()
