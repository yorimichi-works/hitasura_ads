import pathlib
import plistlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[3]


class PriceDiagnosticTests(unittest.TestCase):
    def test_native_gate_is_off_by_default(self):
        with (ROOT / 'ios/Runner/Info.plist').open('rb') as handle:
            self.assertIs(plistlib.load(handle)['HitasuraPriceDiagnostics'], False)

    def test_native_is_read_only_and_bounded(self):
        native = (ROOT / 'ios/Runner/AppDelegate.swift').read_text()
        method = native.split('private func readStorePriceDiagnostic')[1].split('private static func entitlementResult')[0]
        for forbidden in ['.purchase(', 'AppStore.sync', 'Transaction.', 'appStoreReceiptURL',
                          'URLSession', 'localizedDescription', 'UserDefaults']:
            self.assertNotIn(forbidden, method)
        for required in ['Product.products(for: ["ad_free_unlimited"])',
                         'product.priceFormatStyle.currencyCode', 'product.displayPrice',
                         'storefront.countryCode', 'storefront.id',
                         '15_000_000_000', 'self.priceDiagnosticID == identifier',
                         'priceDiagnosticTask?.cancel()', 'HitasuraPriceDiagnostics']:
            self.assertIn(required, method)

    def test_dart_gate_and_no_currency_fallback(self):
        service = (ROOT / 'lib/services/store_price_diagnostic.dart').read_text()
        panel = (ROOT / 'lib/ui/premium.dart').read_text()
        self.assertIn("bool.fromEnvironment('IAP_PRICE_DIAGNOSTICS')", service)
        self.assertIn('if (priceDiagnosticsEnabled)', panel)
        self.assertIn('Text(purchases.product!.price)', panel)
        for forbidden in ['Locale(', 'JPY', '¥300', 'buyNonConsumable', 'restorePurchases']:
            self.assertNotIn(forbidden, service)

    def test_production_workflow_does_not_enable_diagnostics(self):
        workflow = (ROOT / 'codemagic.yaml').read_text().split('  ios-app-store-ipa:', 1)[1]
        self.assertNotIn('IAP_PRICE_DIAGNOSTICS=true', workflow)
        self.assertNotIn('Set :HitasuraPriceDiagnostics true', workflow)

    def test_owner_workflow_enables_both_gates_without_review_submission(self):
        workflow = (ROOT / 'codemagic.yaml').read_text()
        owner = workflow.split('  ios-owner-price-diagnostic:', 1)[1].split('  ios-app-store-ipa:', 1)[0]
        for required in ['--dart-define=IAP_PRICE_DIAGNOSTICS=true',
                         'Set :HitasuraPriceDiagnostics true', 'submit_to_testflight: false',
                         'submit_to_app_store: false', 'profile: hitasura-app-store-profile',
                         'ADMOB_MODE: production', 'HitasuraPriceDiagnostics', 'PYVERIFY']:
            self.assertIn(required, owner)
        for forbidden in ['triggering:', 'beta_groups:', '--create', 'fetch-signing-files']:
            self.assertNotIn(forbidden, owner)
