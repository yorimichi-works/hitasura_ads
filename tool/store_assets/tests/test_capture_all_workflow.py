"""Static guards for the explicitly requested same-run multilingual media batch."""
from pathlib import Path
import re
import unittest


class CaptureAllWorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workflow = (Path(__file__).parents[3] / '.github/workflows/ios-check.yml').read_text()
        cls.job = cls.workflow.split('  native-all-media:\n', 1)[1]
        cls.job = re.split(r'\n  [a-z][a-z0-9-]*:\n', cls.job, maxsplit=1)[0]

    def test_twenty_locales_both_devices_in_two_locale_chunks(self):
        pairs = re.findall(r'- \{id: [a-z_-]+, locales: "([a-zA-Z_,]+)"\}', self.job)
        self.assertEqual(len(pairs), 10)
        self.assertTrue(all(len(pair.split(',')) == 2 for pair in pairs))
        locales = [locale for pair in pairs for locale in pair.split(',')]
        self.assertEqual(len(locales), len(set(locales)))
        self.assertEqual(set(locales), {
            'en', 'ja', 'zh', 'zh_TW', 'ko', 'es', 'fr', 'de', 'pt', 'ru',
            'it', 'hi', 'bn', 'ar', 'ur', 'fa', 'id', 'tr', 'vi', 'th',
        })
        self.assertIn('device: [iphone_6_9, ipad_13]', self.job)

    def test_opt_in_same_run_source_waits_for_both_smoke_devices(self):
        self.assertIn('needs: [ios, native-smoke]', self.job)
        self.assertIn("github.event_name == 'push'", self.job)
        self.assertIn("github.ref == 'refs/heads/codex/app-store-readiness-20261002'", self.job)
        self.assertIn("'[capture-all]'", self.job)
        self.assertIn('needs.ios.outputs.capture_artifact_id', self.job)
        self.assertIn('needs.ios.outputs.capture_artifact_digest', self.job)
        self.assertIn("'source_sha': os.environ['GITHUB_SHA']", self.job)
        self.assertIn('--app-source-sha "$GITHUB_SHA"', self.job)
        self.assertNotIn('--descriptor tool/store_assets/native_capture_artifact.json', self.job)
        ios_if = next(line for line in self.workflow.splitlines() if "if: github.ref !=" in line)
        self.assertNotIn('[capture-all]', ios_if)

    def test_bounded_standard_runners_and_checkpoint_retention(self):
        for required in ('runs-on: macos-15', 'timeout-minutes: 20',
                         'max-parallel: 4', 'fail-fast: false',
                         'timeout-minutes: 10', '--work-deadline-seconds 480',
                         '--runtime-version 18.6', '--session-loop --videos',
                         'if: always()', 'retention-days: 7',
                         'hitasura-native-media-${{ matrix.chunk.id }}-${{ matrix.device }}'):
            self.assertIn(required, self.job)
        self.assertNotIn('--scenes', self.job)
        self.assertIn('contents: read\n      actions: read', self.job)


if __name__ == '__main__':
    unittest.main()
