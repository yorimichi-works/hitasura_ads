import copy
import importlib.util
import json
import pathlib
import plistlib
import tempfile
import unittest
import xml.etree.ElementTree as ET

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


PREPARE = module('prepare_rewarded', HERE / 'prepare_simulator_app.py')
RUN = module('run_rewarded', HERE / 'run_native_qa.py')


class RewardedQaGuards(unittest.TestCase):
    def make_app(self, directory):
        app = pathlib.Path(directory) / 'Original.app'
        app.mkdir()
        (app / 'Info.plist').write_bytes(plistlib.dumps({
            'CFBundleIdentifier': PREPARE.BUNDLE,
            'CFBundleSupportedPlatforms': ['iPhoneSimulator'],
            'GADApplicationIdentifier': PREPARE.GOOGLE_SAMPLE_APP_ID,
        }))
        kernel = app / 'Frameworks/App.framework/flutter_assets/kernel_blob.bin'
        kernel.parent.mkdir(parents=True)
        kernel.write_bytes(f'unit fixture {PREPARE.TARGET} {PREPARE.DEMO_UNIT}'.encode())
        (app / 'Runner').write_bytes(b'\xcf\xfa\xed\xfehitasura_ads/simulator_capture')
        return app

    def test_qa_copy_preserves_original_and_records_exact_source(self):
        with tempfile.TemporaryDirectory() as directory:
            app = self.make_app(directory)
            original = (app / 'Info.plist').read_bytes()
            target = pathlib.Path(directory) / 'Qa.app'
            report = PREPARE.prepare(app, target, 'a' * 40)
            self.assertEqual((app / 'Info.plist').read_bytes(), original)
            self.assertEqual(plistlib.loads((target / 'Info.plist').read_bytes())['GADApplicationIdentifier'], PREPARE.HITASURA_APP_ID)
            self.assertEqual(report['demo_unit'], PREPARE.DEMO_UNIT)
            self.assertEqual(report['source_sha'], 'a' * 40)
            self.assertFalse(report['app_store_archive'])

    def test_device_unknown_appid_and_shipping_targets_are_rejected(self):
        for field, value in [('CFBundleSupportedPlatforms', ['iPhoneOS']),
                             ('CFBundleIdentifier', 'other.app'),
                             ('GADApplicationIdentifier', 'unknown')]:
            with self.subTest(field=field), tempfile.TemporaryDirectory() as directory:
                app = self.make_app(directory)
                info = plistlib.loads((app / 'Info.plist').read_bytes())
                info[field] = value
                (app / 'Info.plist').write_bytes(plistlib.dumps(info))
                with self.assertRaises(ValueError):
                    PREPARE.validate(app)
        with tempfile.TemporaryDirectory() as directory:
            app = self.make_app(directory)
            (app / 'Frameworks/App.framework/flutter_assets/kernel_blob.bin').write_bytes(b'lib/main.dart')
            with self.assertRaises(ValueError):
                PREPARE.validate(app)

    def test_absent_native_bridge_or_demo_unit_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            app = self.make_app(directory)
            (app / 'Runner').write_bytes(b'\xcf\xfa\xed\xfeMissing')
            with self.assertRaises(RuntimeError):
                PREPARE.validate(app)
        with tempfile.TemporaryDirectory() as directory:
            app = self.make_app(directory)
            (app / 'Frameworks/App.framework/flutter_assets/kernel_blob.bin').write_bytes(PREPARE.TARGET.encode())
            with self.assertRaises(ValueError):
                PREPARE.validate(app)

    def test_sources_keep_shipping_and_no_ad_ump_targets_isolated(self):
        main = (HERE / 'rewarded_ad_qa_main.dart').read_text()
        ump = (ROOT / 'tool/ump_qa/ump_qa_main.dart').read_text()
        self.assertNotIn('GoogleRewardedAdService', ump)
        self.assertNotIn('AdNetworkMode.production', main)
        self.assertNotIn('DebugRewardedAdService', main)
        self.assertNotIn('setMockMethodCallHandler', main)
        self.assertIn('adNetworkMode: AdNetworkMode.test', main)
        self.assertIn('AdsPrivacyService(gateway: EeaQaConsentGateway())', main)
        self.assertIn('if (!_ads!.usesTestAds || !_ads!.isSupported)', main)
        for path in (ROOT / 'lib').rglob('*.dart'):
            self.assertNotIn('tool/ad_qa', path.read_text())
        self.assertNotIn('HITASURA_REWARDED_AD_QA', (ROOT / 'codemagic.yaml').read_text())

    def test_native_driver_requires_visible_test_mode_before_close_only(self):
        driver = (HERE / 'RewardedQaUITests.swift').read_text()
        self.assertLess(driver.index('try observeNativeTestMode()'), driver.index('close.tap()'))
        self.assertIn('label.isHittable', driver)
        self.assertIn('sdk-test-mode-visible', driver)
        self.assertNotIn('coordinate(', driver)
        self.assertNotIn('.swipe', driver)
        self.assertEqual(driver.count('.tap()'), 4)
        ET.parse(HERE / 'RewardedQaUITests.xcodeproj/xcshareddata/xcschemes/RewardedQaUITests.xcscheme')

    def fixture_events(self):
        # Synthetic verifier unit fixtures, never accepted as native evidence.
        base = {'at': '2026-10-02T20:00:01Z', 'target': RUN.TARGET,
                'ad_mode': 'test', 'expected_demo_unit': RUN.DEMO_UNIT,
                'service_uses_test_ads': True, 'native_simulator_attested': True,
                'debug_mode': True, 'source': 'shipping_service_sdk_log'}
        stages = ('sdk_initialized', 'sdk_load_callback', 'ad_qa_loaded', 'sdk_show_requested',
                  'sdk_reward_callback', 'sdk_dismiss_callback', 'ad_qa_complete')
        events = [dict(base, stage=stage) for stage in stages]
        events[2].update(sdk_can_request_ads=True, sdk_consent_status='obtained')
        events[-1]['result'] = 'rewarded'
        return events

    def verify(self, events):
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / 'events.jsonl'
            path.write_text('\n'.join(map(json.dumps, events)))
            return RUN.verify_events(path, '2026-10-02T20:00:00Z')

    def test_verifier_requires_real_ordered_callbacks_and_gate(self):
        self.assertEqual(len(self.verify(self.fixture_events())), 7)
        mutations = []
        for field, value in [('ad_mode', 'production'), ('expected_demo_unit', 'live'),
                             ('service_uses_test_ads', False), ('native_simulator_attested', False),
                             ('debug_mode', False), ('source', 'mock')]:
            changed = self.fixture_events()
            changed[0][field] = value
            mutations.append(changed)
        changed = self.fixture_events()
        changed[2]['sdk_can_request_ads'] = False
        mutations.append(changed)
        changed = self.fixture_events()
        changed[-1]['result'] = 'notRewarded'
        mutations.append(changed)
        mutations.append(self.fixture_events()[:-1])
        mutations.append(list(reversed(self.fixture_events())))
        mutations.append(self.fixture_events() + [copy.copy(self.fixture_events()[4])])
        mutations.append(self.fixture_events() + [dict(self.fixture_events()[0], stage='ad_qa_error')])
        for events in mutations:
            with self.subTest(events=events), self.assertRaises(ValueError):
                self.verify(events)


if __name__ == '__main__':
    unittest.main()
