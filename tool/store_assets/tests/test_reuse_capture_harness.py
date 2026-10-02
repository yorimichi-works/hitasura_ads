import copy
import hashlib
import importlib.util
import pathlib
import tempfile
import unittest
from unittest import mock

spec = importlib.util.spec_from_file_location('reuse', pathlib.Path(__file__).parents[1] / 'reuse_capture_harness.py')
reuse = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reuse)


class ReuseHarnessTests(unittest.TestCase):
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
