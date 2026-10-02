import copy
import hashlib
import importlib.util
import json
import pathlib
import tempfile
import unittest
from unittest import mock

spec = importlib.util.spec_from_file_location('reuse', pathlib.Path(__file__).parents[1] / 'reuse_capture_harness.py')
reuse = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reuse)


class ReuseHarnessTests(unittest.TestCase):
    def test_reviewed_recovery_uses_retained_dc10_and_prioritizes_real_settings(self):
        root = pathlib.Path(__file__).parents[3]
        approved = reuse.descriptor(json.loads((root / 'tool/store_assets/native_capture_artifact.json').read_text()))
        self.assertEqual(approved['source_sha'], 'dc10fbe5f05f12ecfaa2edea9eb3dabcac786f91')
        self.assertEqual(approved['artifact_id'], 11247365869)
        source = (root / '.github/workflows/ios-check.yml').read_text()
        settings = source.split('  native-probe:', 1)[1].split('  native-media-recovery:', 1)[0]
        media = source.split('  native-media-recovery:', 1)[1]
        self.assertIn('--locales en --devices ipad_13 --scenes home', settings)
        self.assertIn('--include-settings', settings)
        self.assertNotIn('--videos', settings)
        self.assertIn('needs: native-probe', media)
        self.assertIn('--locales ja,ar --devices ipad_13', media)
        self.assertIn('--session-loop --videos', media)
        for job in (settings, media):
            self.assertIn('runs-on: macos-15', job)
            self.assertIn('timeout-minutes: 10', job)
            self.assertIn('--work-deadline-seconds 480', job)
            self.assertIn('--descriptor tool/store_assets/native_capture_artifact.json', job)
            self.assertNotIn('flutter build', job)
            self.assertIn("contains(github.event.head_commit.message, '[capture-reuse]')", job)

    def test_noncompiled_upload_schema_changes_do_not_require_app_rebuild(self):
        reuse.verify_source_delta(['codemagic.yaml', 'tool/release/README.md',
                                   'tool/release/tests/test_preflight.py'])

    def test_descriptor_requires_exact_repository_and_full_identities(self):
        baseline = reuse.descriptor()
        self.assertEqual(reuse.descriptor(baseline), baseline)
        for change in ({}, {**baseline, 'repository': 'other/repo'},
                       {**baseline, 'source_sha': 'short'}, {**baseline, 'zip_sha256': 'wrong'},
                       {**baseline, 'artifact_id': True}, {**baseline, 'extra': 'ignored'}):
            with self.subTest(change=change), self.assertRaises(ValueError):
                reuse.descriptor(change)

    def test_fresh_same_run_descriptor_is_bound_to_metadata_and_provenance(self):
        approved = {**reuse.descriptor(), 'source_sha': 'a' * 40, 'run_id': 99, 'artifact_id': 100}
        metadata = {**self.metadata, 'id': 100, 'workflow_run': {'id': 99, 'head_sha': 'a' * 40}}
        provenance = {**self.provenance, 'source_sha': 'a' * 40}
        reuse.verify_metadata(metadata, approved)
        reuse.verify_provenance(provenance, approved)
        with self.assertRaises(ValueError):
            reuse.verify_metadata(metadata)

    def setUp(self):
        self.metadata = {'id': reuse.ARTIFACT_ID, 'name': 'hitasura-native-capture-harness',
                         'digest': f'sha256:{reuse.DIGEST}', 'expired': False,
                         'workflow_run': {'id': reuse.RUN_ID, 'head_sha': reuse.SOURCE_SHA}}
        self.provenance = {'source_sha': reuse.SOURCE_SHA,
                           'target': 'tool/store_assets/native_capture_main.dart',
                           'mode': 'debug_ios_simulator', 'admob_mode': 'disabled',
                           'app_store_archive': False}

    def test_exact_unexpired_artifact_and_mode_pass(self):
        reuse.verify_metadata(self.metadata)
        reuse.verify_provenance(self.provenance)

    def test_expired_or_unknown_artifact_stops(self):
        for value in (True, None, 'false'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                reuse.verify_metadata({**self.metadata, 'expired': value})

    def test_wrong_artifact_identity_or_hash_stops(self):
        for key, value in (('id', 1), ('name', 'other'), ('digest', 'sha256:wrong')):
            with self.subTest(key=key), self.assertRaises(ValueError):
                reuse.verify_metadata({**self.metadata, key: value})

    def test_wrong_source_revision_or_run_stops(self):
        for key, value in (('head_sha', '0' * 40), ('id', 1)):
            changed = copy.deepcopy(self.metadata)
            changed['workflow_run'][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                reuse.verify_metadata(changed)

    def test_wrong_embedded_mode_or_source_stops(self):
        for key, value in (('source_sha', '0' * 40), ('mode', 'release'),
                           ('admob_mode', 'production'), ('app_store_archive', True)):
            with self.subTest(key=key), self.assertRaises(ValueError):
                reuse.verify_provenance({**self.provenance, key: value})

    def test_only_noncompiled_probe_changes_can_reuse(self):
        reuse.verify_source_delta(list(reuse.ALLOWED_DELTA))
        for path in ('lib/main.dart', 'ios/Runner/AppDelegate.swift', 'pubspec.lock',
                     'assets/fonts/KosugiMaru-Regular.ttf', 'tool/store_assets/native_capture_main.dart'):
            with self.subTest(path=path), self.assertRaisesRegex(ValueError, 'fresh build'):
                reuse.verify_source_delta([path])

    def test_zip_hash_is_verified_before_unpack(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / 'artifact.zip'
            path.write_bytes(b'example artifact bytes')
            with self.assertRaisesRegex(ValueError, 'ZIP hash'):
                reuse.verify_zip(path)
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            with mock.patch.object(reuse, 'DIGEST', digest):
                reuse.verify_zip(path)


if __name__ == '__main__':
    unittest.main()
