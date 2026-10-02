import importlib.util
import json
import pathlib
import plistlib
import tempfile
import unittest
from unittest import mock
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('qa', pathlib.Path(__file__).with_name('prepare_simulator_app.py'))
QA = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(QA)
ARCHIVE_SPEC = importlib.util.spec_from_file_location('qa_archive', pathlib.Path(__file__).with_name('archive_qa_build.py'))
ARCHIVE = importlib.util.module_from_spec(ARCHIVE_SPEC)
ARCHIVE_SPEC.loader.exec_module(ARCHIVE)
RUN_SPEC = importlib.util.spec_from_file_location('qa_run', pathlib.Path(__file__).with_name('run_native_qa.py'))
RUN = importlib.util.module_from_spec(RUN_SPEC)
RUN_SPEC.loader.exec_module(RUN)
REUSE_SPEC = importlib.util.spec_from_file_location('qa_reuse', pathlib.Path(__file__).with_name('reuse_qa_build.py'))
REUSE = importlib.util.module_from_spec(REUSE_SPEC)
REUSE_SPEC.loader.exec_module(REUSE)


class QaGuardTests(unittest.TestCase):
    def make_app(self, directory):
        app = pathlib.Path(directory) / 'Original.app'
        app.mkdir()
        (app / 'Info.plist').write_bytes(plistlib.dumps({
            'CFBundleIdentifier': 'com.syamo.hitasuraads',
            'CFBundleSupportedPlatforms': ['iPhoneSimulator'],
            'GADApplicationIdentifier': 'google-sample-id'}))
        kernel = app / 'Frameworks/App.framework/flutter_assets/kernel_blob.bin'
        kernel.parent.mkdir(parents=True)
        kernel.write_bytes(b'fixture tool/ump_qa/ump_qa_main.dart')
        (app / 'Runner').write_bytes(b'\xcf\xfa\xed\xfehitasura_ads/simulator_capture')
        return app

    def test_only_separate_simulator_copy_receives_actual_app_id(self):
        with tempfile.TemporaryDirectory() as directory:
            app = self.make_app(directory)
            original = (app / 'Info.plist').read_bytes()
            target = pathlib.Path(directory) / 'Qa.app'
            report = QA.prepare(app, target)
            self.assertEqual((app / 'Info.plist').read_bytes(), original)
            self.assertEqual(plistlib.loads((target / 'Info.plist').read_bytes())['GADApplicationIdentifier'], QA.HITASURA_APP_ID)
            self.assertFalse(report['app_store_archive'])
            self.assertFalse(report['ad_requests'])

    def test_device_bundle_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            app = self.make_app(directory)
            info = plistlib.loads((app / 'Info.plist').read_bytes())
            info['CFBundleSupportedPlatforms'] = ['iPhoneOS']
            (app / 'Info.plist').write_bytes(plistlib.dumps(info))
            with self.assertRaises(ValueError):
                QA.prepare(app, pathlib.Path(directory) / 'Qa.app')

    def test_shipping_or_media_debug_target_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            app = self.make_app(directory)
            (app / 'Frameworks/App.framework/flutter_assets/kernel_blob.bin').write_bytes(b'lib/main.dart')
            with self.assertRaises(ValueError):
                QA.prepare(app, pathlib.Path(directory) / 'Qa.app')

    def test_compiled_out_simulator_guard_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            app = self.make_app(directory)
            (app / 'Runner').write_bytes(b'\xcf\xfa\xed\xfeNoDebugBridge')
            with self.assertRaises(RuntimeError):
                QA.prepare(app, pathlib.Path(directory) / 'Qa.app')

    def test_existing_destination_cannot_be_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            app = self.make_app(directory)
            with self.assertRaises(ValueError):
                QA.prepare(app, app)

    def test_shipping_sources_do_not_import_qa(self):
        for file in (ROOT / 'lib').rglob('*.dart'):
            self.assertNotIn('ump_qa', file.read_text(), file)
        release = (ROOT / 'codemagic.yaml').read_text().split('  ios-app-store-ipa:', 1)[1]
        self.assertNotIn('HITASURA_UMP_QA', release)
        self.assertNotIn('ump_qa_main.dart', release)
        self.assertNotIn('UmpQaUITests', (ROOT / 'ios/Runner.xcodeproj/project.pbxproj').read_text())

    def test_qa_has_no_ad_or_tracking_call(self):
        for path in (ROOT / 'tool/ump_qa').glob('*.dart'):
            source = path.read_text()
            for prohibited in ['MobileAds.instance', 'RewardedAd.load', 'BannerAd(', 'AdRequest(', 'AppTrackingTransparency', 'GoogleRewardedAdService']:
                self.assertNotIn(prohibited, source)
        main = (ROOT / 'tool/ump_qa/ump_qa_main.dart').read_text()
        self.assertLess(main.index("response?['isSimulator'] == true"), main.index('runApp('))
        self.assertIn("bool.fromEnvironment('HITASURA_UMP_QA')", main)

    def test_ui_test_project_cannot_archive_or_target_devices(self):
        project = (ROOT / 'tool/ump_qa/UmpQaUITests.xcodeproj/project.pbxproj').read_text()
        self.assertNotIn('name = Release', project)
        self.assertIn('SUPPORTED_PLATFORMS = iphonesimulator', project)
        self.assertIn('CODE_SIGNING_ALLOWED = NO', project)
        scheme = ET.parse(ROOT / 'tool/ump_qa/UmpQaUITests.xcodeproj/xcshareddata/xcschemes/UmpQaUITests.xcscheme')
        self.assertIsNone(scheme.find('ArchiveAction'))
        self.assertTrue(all(x.attrib['buildForArchiving'] == 'NO' for x in scheme.findall('.//BuildActionEntry')))

    def test_tagged_qa_pipeline_is_unsigned_and_separate_from_media(self):
        workflow = (ROOT / '.github/workflows/ios-check.yml').read_text()
        regular = workflow.split('  ios:', 1)[1].split('  native-smoke:', 1)[0]
        qa = workflow.split('  ump-qa-build:', 1)[1]
        self.assertIn("!contains(github.event.head_commit.message, '[ump-qa]')", regular)
        self.assertIn("contains(github.event.head_commit.message, '[ump-qa]')", qa)
        self.assertIn('--simulator --debug --no-codesign', qa)
        self.assertIn('CODE_SIGNING_ALLOWED=NO', qa)
        self.assertIn('--dart-define=ADMOB_MODE=disabled', qa)
        self.assertIn('needs: ump-qa-build', qa)
        self.assertIn('EXPECTED_TAR_SHA256', qa)
        self.assertNotIn('flutter build ipa', qa)
        self.assertNotIn('codemagic', qa)

    def test_exact_same_run_archive_round_trip_and_mismatches(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            app_root = root / 'qa_app'
            (app_root / 'Runner.app').mkdir(parents=True)
            (app_root / 'provenance.json').write_text('{}')
            products = root / 'Products'
            products.mkdir()
            (products / 'UmpQa.xctestrun').write_bytes(plistlib.dumps({'TestConfigurations': []}))
            archive = root / 'qa.tar.gz'
            sha = 'a' * 40
            digest = ARCHIVE.pack(archive, sha, app_root, products)
            with self.assertRaises(ValueError):
                ARCHIVE.unpack(archive, root / 'wrong_source', 'b' * 40, digest)
            with self.assertRaises(ValueError):
                ARCHIVE.unpack(archive, root / 'wrong_digest', sha, '0' * 64)
            xctestrun = ARCHIVE.unpack(archive, root / 'verified', sha, digest)
            self.assertEqual(xctestrun.name, 'UmpQa.xctestrun')
            self.assertTrue(xctestrun.is_file())
            with self.assertRaises(ValueError):
                ARCHIVE.unpack(archive, root / 'verified', sha, digest)

    def test_archive_requires_exact_sha_and_compiled_ui_runner(self):
        with self.assertRaises(ValueError):
            ARCHIVE.expected('main')
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            with self.assertRaises(ValueError):
                ARCHIVE.pack(root / 'qa.tar.gz', 'a' * 40, root / 'app', root / 'products')

    def test_sdk_event_gate_rejects_missing_stale_or_error_results(self):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / 'events.jsonl'
            event = {'at': '2026-10-02T19:00:01Z', 'native_simulator_attested': True,
                     'debug_mode': True, 'service_has_error': False,
                     'sdk_privacy_options_status': 'required', 'sdk_consent_status': 'obtained',
                     'ad_initialization_requested': False, 'ad_load_requested': False}
            events = [{**event, 'stage': stage} for _ in range(2) for stage in (
                'consent_update_complete', 'consent_complete', 'privacy_options_complete')]
            def write(values):
                path.write_text('\n'.join(json.dumps(value) for value in values))
            write(events)
            self.assertEqual(len(RUN.verify_sdk_events(path, '2026-10-02T19:00:00Z')), 6)
            with self.assertRaises(ValueError):
                RUN.verify_sdk_events(path, '2026-10-02T20:00:00Z')
            write(events[:-1])
            with self.assertRaises(ValueError):
                RUN.verify_sdk_events(path, '2026-10-02T19:00:00Z')
            write(events + [{**event, 'stage': 'qa_error'}])
            with self.assertRaises(ValueError):
                RUN.verify_sdk_events(path, '2026-10-02T19:00:00Z')

    def test_retained_qa_artifact_identity_and_expiry(self):
        descriptor = json.loads((ROOT / 'tool/ump_qa/retained_build.json').read_text())
        meta = {'id': descriptor['artifact_id'], 'name': 'hitasura-ump-qa-harness',
                'digest': 'sha256:' + descriptor['zip_sha256'], 'expired': False,
                'workflow_run': {'id': descriptor['run_id'], 'head_sha': descriptor['source_sha']}}
        REUSE.verify_metadata(meta, descriptor)
        for change in [{'expired': True}, {'id': 1}, {'digest': 'sha256:' + '0' * 64},
                       {'workflow_run': {'id': descriptor['run_id'], 'head_sha': 'a' * 40}}]:
            with self.assertRaises(ValueError):
                REUSE.verify_metadata({**meta, **change}, descriptor)

    def test_reuse_job_only_rebuilds_native_test_driver_without_app_or_release(self):
        workflow = (ROOT / '.github/workflows/ios-check.yml').read_text()
        job = workflow.split('  ump-qa-reuse:', 1)[1].split('  native-phone-batches:', 1)[0]
        self.assertIn("contains(github.event.head_commit.message, '[ump-reuse]')", job)
        self.assertIn('--runtime-version 18.6', job)
        self.assertIn('runs-on: macos-15', job)
        self.assertIn('actions: read', job)
        self.assertNotIn('flutter build', job)
        self.assertIn('--rebuild-ui-driver', job)
        self.assertIn('xcodebuild build-for-testing -project tool/ump_qa/UmpQaUITests.xcodeproj', job)
        self.assertIn('--ui-driver-source-sha "$GITHUB_SHA"', job)
        self.assertNotIn('flutter build ipa', job)

    def test_only_explicit_driver_rebuild_can_change_ui_test_source(self):
        native = (ROOT / 'ios/Runner/AppDelegate.swift').read_text()
        changed = {'tool/ump_qa/UmpQaUITests.swift'}
        def read(command, **kwargs):
            ref, path = command[-1].split(':', 1)
            if path == 'ios/Runner/AppDelegate.swift':
                return native
            return b'new' if ref == 'HEAD' and path in changed else b'old'
        with mock.patch.object(REUSE.subprocess, 'check_output', side_effect=read):
            with self.assertRaises(ValueError):
                REUSE.verify_dependencies('a' * 40)
            REUSE.verify_dependencies('a' * 40, rebuild_ui_driver=True)
            changed.add('lib/services/ads_privacy_service.dart')
            with self.assertRaises(ValueError):
                REUSE.verify_dependencies('a' * 40, rebuild_ui_driver=True)

    def test_native_buttons_are_scoped_away_from_observed_prefetched_webview(self):
        source = (ROOT / 'tool/ump_qa/UmpQaUITests.swift').read_text()
        self.assertIn('app.webViews.allElementsBoundByIndex.reversed()', source)
        self.assertIn('frame.minX >= 0 && frame.minY >= 0', source)
        self.assertNotIn('.firstMatch', source)
        self.assertNotIn('coordinate(withNormalizedOffset:', source)

    def test_older_runtime_selection_requires_actual_compatible_inventory(self):
        capture = RUN.module('capture_test', ROOT / 'tool/store_assets/capture_ios_simulator.py')
        rid = 'com.apple.CoreSimulator.SimRuntime.iOS-18-6'
        inventory = {'devices': {rid: [{'udid': 'listed-device', 'name': 'iPhone 16 Pro Max', 'isAvailable': True}]}}
        runtimes = {'runtimes': [{'identifier': rid, 'version': '18.6', 'isAvailable': True}]}
        selected = RUN.select_compatible_device(capture, inventory, runtimes, '26.2', '18.6', '15.0')
        self.assertEqual(selected[2]['udid'], 'listed-device')
        for runtime, minimum in [('18.5', '15.0'), ('18.6', '19.0'), ('27.0', '15.0')]:
            with self.assertRaises((ValueError, RuntimeError)):
                RUN.select_compatible_device(capture, inventory, runtimes, '26.2', runtime, minimum)


if __name__ == '__main__':
    unittest.main()
