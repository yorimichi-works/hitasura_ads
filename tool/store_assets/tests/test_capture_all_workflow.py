"""Static guards for the explicitly requested same-run multilingual media batch."""
from pathlib import Path
import re
import json
import unittest


class CaptureAllWorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workflow = (Path(__file__).parents[3] / '.github/workflows/ios-check.yml').read_text()
        cls.job = cls.workflow.split('  native-all-media:\n', 1)[1]
        cls.job = re.split(r'\n  [a-z][a-z0-9-]*:\n', cls.job, maxsplit=1)[0]

    def test_twenty_locales_both_devices_in_two_locale_chunks(self):
        choices = re.findall(r"'(\[\{[^']+\}\])'", self.job)
        self.assertEqual(len(choices), 2)
        pairs = [item['locales'] for item in json.loads(choices[1])]
        self.assertEqual(len(pairs), 10)
        self.assertTrue(all(len(pair.split(',')) == 2 for pair in pairs))
        locales = [locale for pair in pairs for locale in pair.split(',')]
        self.assertEqual(len(locales), len(set(locales)))
        self.assertEqual(set(locales), {
            'en', 'ja', 'zh', 'zh_TW', 'ko', 'es', 'fr', 'de', 'pt', 'ru',
            'it', 'hi', 'bn', 'ar', 'ur', 'fa', 'id', 'tr', 'vi', 'th',
        })
        self.assertIn('device: [iphone_6_9, ipad_13]', self.job)

    def test_media_proof_expands_only_ja_ar_for_both_devices(self):
        choices = re.findall(r"'(\[\{[^']+\}\])'", self.job)
        self.assertEqual(json.loads(choices[0]), [{'id': 'ja-ar', 'locales': 'ja,ar'}])
        self.assertIn("contains(github.event.head_commit.message, '[capture-media-proof]') &&", self.job)
        self.assertIn("|| contains(github.event.head_commit.message, '[capture-media-proof]')", self.job)
        ios_if = next(line for line in self.workflow.splitlines() if "if: github.ref !=" in line)
        self.assertNotIn('[capture-media-proof]', ios_if)
        self.assertIn('--session-loop --videos', self.job)

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
        for required in ('runs-on: macos-26', 'timeout-minutes: 20',
                         'max-parallel: 4', 'fail-fast: false',
                         'timeout-minutes: 10', '--work-deadline-seconds 480',
                         '--runtime-version 26.2', '--session-loop --videos',
                         'if: always()', 'retention-days: 7',
                         'hitasura-native-media-${{ matrix.chunk.id }}-${{ matrix.device }}'):
            self.assertIn(required, self.job)
        self.assertNotIn('--scenes', self.job)
        self.assertIn('contents: read\n      actions: read', self.job)

    def test_full_media_matches_standard_probe_environment(self):
        smoke = self.workflow.split('  native-smoke:\n', 1)[1].split('  native-probe:\n', 1)[0]
        for text in (smoke, self.job):
            self.assertIn('runs-on: macos-26', text)
            self.assertIn('--runtime-version 26.2', text)
            self.assertNotIn('runs-on: macos-26-large', text)
            self.assertNotIn('runs-on: macos-26-xlarge', text)
        self.assertIn('--scenes home,fruit', smoke)
        self.assertNotIn('--scenes', self.job)
        self.assertIn('--session-loop --videos --work-deadline-seconds 480', self.job)

    def test_review_artifact_excludes_media_inventory_and_keeps_upload_reserve(self):
        job = self.workflow.split('  native-media-candidates:\n', 1)[1].split('  rewarded-qa-build:\n', 1)[0]
        review = job.split('      - name: Retain compact review sheets and provenance separately\n', 1)[1]
        review = review.split('      - name: Retain candidate media', 1)[0]
        paths = re.findall(r'^            (build/[^\n]+)$', review, re.M)
        self.assertEqual(paths, ['build/media_candidates/attempt.json',
            'build/media_candidates/**/results.json', 'build/media_candidates/**/preview.manifest.json',
            'build/media_candidates/**/screenshots-review-only.png',
            'build/media_candidates/**/preview-review-only.png'])
        self.assertNotIn('.mp4', review)
        self.assertNotIn('**/*.png', review)
        self.assertIn('if: always()', review)
        self.assertIn('timeout-minutes: 1', review)
        self.assertIn('retention-days: 7', review)
        step_caps = [int(value) for value in re.findall(r'^        timeout-minutes: (\d+)$', job, re.M)]
        self.assertEqual(step_caps, [1, 1, 3, 11, 1, 2])
        self.assertEqual(sum(step_caps), 19)
        self.assertIn('    timeout-minutes: 20', job)


if __name__ == '__main__':
    unittest.main()
