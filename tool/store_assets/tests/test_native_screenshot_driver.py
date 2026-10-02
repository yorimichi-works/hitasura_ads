"""Source guards for the standalone, foreground-only screenshot fallback."""
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).parents[1]


class NativeScreenshotDriverTests(unittest.TestCase):
    def test_only_existing_foreground_process_is_observed(self):
        source = (ROOT / 'NativeScreenshotUITests.swift').read_text()
        self.assertIn('XCUIApplication(bundleIdentifier: "com.syamo.hitasuraads")', source)
        self.assertIn('continueAfterFailure = false', source)
        self.assertEqual(source.count('XCTAssertEqual(app.state, .runningForeground'), 2)
        self.assertLess(source.index('XCTAssertEqual(app.state, .runningForeground'), source.index('app.screenshot()'))
        for forbidden in ('app.launch(', 'app.activate(', 'app.terminate(', '.tap(', '.swipe', 'coordinate('):
            self.assertNotIn(forbidden, source)

    def test_native_attachment_has_exact_unambiguous_name(self):
        source = (ROOT / 'NativeScreenshotUITests.swift').read_text()
        self.assertIn('XCTAttachment(screenshot: app.screenshot())', source)
        self.assertIn('attachment.name = "hitasura-existing-native-frame"', source)
        self.assertIn('attachment.lifetime = .keepAlways', source)
        self.assertEqual(source.count('add(attachment)'), 1)

    def test_driver_is_standalone_unsigned_simulator_only(self):
        project = ROOT / 'NativeScreenshotUITests.xcodeproj'
        data = (project / 'project.pbxproj').read_text()
        for expected in ('SUPPORTED_PLATFORMS = iphonesimulator;', 'CODE_SIGNING_ALLOWED = NO;',
                         'SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;', 'NativeScreenshotUITests.swift',
                         'com.syamo.hitasuraads.captureproof.tests'):
            self.assertIn(expected, data)
        self.assertNotIn('RewardedQa', data)
        ET.parse(project / 'xcshareddata/xcschemes/NativeScreenshotUITests.xcscheme')
        shipping = (ROOT.parents[1] / 'ios/Runner.xcodeproj/project.pbxproj').read_text()
        self.assertNotIn('NativeScreenshotUITests', shipping)


if __name__ == '__main__':
    unittest.main()
