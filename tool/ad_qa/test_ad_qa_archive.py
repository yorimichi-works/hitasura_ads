import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('ad_archive', HERE / 'archive_qa_build.py')
ARCHIVE = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ARCHIVE)


class AdQaArchiveTests(unittest.TestCase):
    def fixtures(self, root):
        app = root / 'app'
        (app / 'Runner.app').mkdir(parents=True)
        (app / 'Runner.app' / 'Runner').write_text('synthetic unit fixture')
        (app / 'provenance.json').write_text(json.dumps(ARCHIVE.expected('a' * 40)))
        products = root / 'Products'
        products.mkdir()
        (products / 'RewardedQa.xctestrun').write_text('synthetic unit fixture')
        return app, products

    def test_exact_source_and_digest_roundtrip(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            app, products = self.fixtures(root)
            archive = root / 'qa.tar.gz'
            digest = ARCHIVE.pack(archive, 'a' * 40, app, products)
            run = ARCHIVE.unpack(archive, root / 'out', 'a' * 40, digest)
            self.assertTrue(run.is_file())
            self.assertEqual(json.loads((root / 'out/qa-build.json').read_text()), ARCHIVE.expected('a' * 40))
            for sha, checksum in [('b' * 40, digest), ('a' * 40, '0' * 64)]:
                with self.assertRaises(ValueError):
                    ARCHIVE.unpack(archive, root / 'rejected', sha, checksum)

    def test_wrong_prepared_source_or_live_unit_is_rejected(self):
        for field, value in [('source_sha', 'b' * 40), ('ad_mode', 'production'), ('demo_unit', 'live'), ('app_store_archive', True)]:
            with self.subTest(field=field), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                app, products = self.fixtures(root)
                provenance = json.loads((app / 'provenance.json').read_text())
                provenance[field] = value
                (app / 'provenance.json').write_text(json.dumps(provenance))
                with self.assertRaises(ValueError):
                    ARCHIVE.pack(root / 'rejected.tar.gz', 'a' * 40, app, products)

    def test_workflow_is_opt_in_bounded_and_separate(self):
        workflow = (HERE.parents[1] / '.github/workflows/ios-check.yml').read_text()
        builder = workflow.split('  rewarded-qa-build:\n', 1)[1].split('  rewarded-qa-native:\n', 1)[0]
        native = workflow.split('  rewarded-qa-native:\n', 1)[1]
        self.assertIn("'[ad-qa]'", builder)
        self.assertIn('github.repository == \'yorimichi-works/hitasura_ads\'', builder)
        self.assertIn('refs/heads/codex/app-store-readiness-20261002', builder)
        self.assertIn('--dart-define=HITASURA_REWARDED_AD_QA=true --dart-define=ADMOB_MODE=test', builder)
        self.assertIn('tool/ad_qa/rewarded_ad_qa_main.dart', builder)
        for block in (builder, native):
            self.assertIn('runs-on: macos-15', block)
            self.assertNotIn('contents: write', block)
            self.assertNotIn('secrets.', block)
        self.assertIn('timeout-minutes: 35', builder)
        self.assertIn('timeout-minutes: 20', native)
        self.assertIn('timeout-minutes: 14', native)
        self.assertIn('needs.rewarded-qa-build.outputs.artifact_id', native)
        self.assertIn('needs.rewarded-qa-build.outputs.tar_sha256', native)
        self.assertIn('--source-sha "$GITHUB_SHA"', native)
        self.assertIn('--runtime-version 18.6', native)
        self.assertIn('if: always()', native)
        self.assertIn('hitasura-rewarded-native-evidence', native)
        self.assertNotIn('needs: native-all-media', native)


if __name__ == '__main__':
    unittest.main()
