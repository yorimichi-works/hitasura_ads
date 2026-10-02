"""Keep native language declarations aligned with manually localized Flutter UI."""
import pathlib
import plistlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[3]


class IOSLocalizationTests(unittest.TestCase):
    def test_bundle_declares_each_actual_flutter_language(self):
        dart = (ROOT / 'lib/l10n/l10n.dart').read_text()
        codes = re.findall(r"^  Lang\('([^']+)'", dart, re.MULTILINE)
        self.assertEqual(len(codes), 20)
        apple_codes = {'zh': 'zh-Hans', 'zh_TW': 'zh-Hant'}
        expected = [apple_codes.get(code, code) for code in codes]
        with (ROOT / 'ios/Runner/Info.plist').open('rb') as stream:
            bundle = plistlib.load(stream)
        self.assertEqual(bundle['CFBundleLocalizations'], expected)
        self.assertEqual(len(set(bundle['CFBundleLocalizations'])), 20)
        for code in codes:
            self.assertTrue((ROOT / f'lib/l10n/ui/{code.lower()}.dart').is_file())


if __name__ == '__main__':
    unittest.main()
