"""The first alternate screenshot run is one bounded proof with a frozen app."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[3]


class XCTestProofWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.text = (ROOT / '.github/workflows/native-xctest-proof.yml').read_text()

    def test_exact_existing_app_artifact_and_separate_driver(self):
        for value in ('09d43a790390251c93ee76564c6ce800bdf5f93f', '37068852657', '11253354721',
                      '51e27abec176bc6caadfab5521b9b061aff0b16283bb1f096123182bd253c104',
                      'reuse_capture_harness.py --descriptor build/reuse_download/descriptor.json',
                      'NativeScreenshotUITests.xcodeproj', '--screenshot-driver-sha "$GITHUB_SHA"'):
            self.assertIn(value, self.text)
        self.assertNotIn('flutter build', self.text)
        self.assertNotIn('ios/Runner.xcodeproj', self.text)

    def test_one_home_only_and_existing_free_runner_bounds(self):
        for value in ('runs-on: macos-15', 'timeout-minutes: 20', 'timeout-minutes: 3',
                      'timeout-minutes: 10', '--locales ja --devices iphone_6_9 --scenes home',
                      '--work-deadline-seconds 480', '--runtime-version 18.6',
                      'contents: read\n      actions: read', 'if: always()',
                      'retention-days: 7', '[capture-xctest]'):
            self.assertIn(value, self.text)
        self.assertNotIn('--videos', self.text)
        self.assertNotIn('actions: write', self.text)

    def test_marker_does_not_compile_the_shipping_app(self):
        ios = (ROOT / '.github/workflows/ios-check.yml').read_text()
        condition = next(line for line in ios.splitlines() if 'if: github.ref !=' in line)
        self.assertIn("!contains(github.event.head_commit.message, '[capture-xctest]')", condition)


if __name__ == '__main__':
    unittest.main()
