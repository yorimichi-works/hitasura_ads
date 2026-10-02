"""Minimal Google-only privacy-preserving iOS attribution configuration."""
import pathlib
import plistlib
import re
import unittest
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[3]


class GoogleAttributionTests(unittest.TestCase):
    def test_exact_google_only_identifier_with_valid_syntax(self):
        info = plistlib.loads((ROOT / 'ios/Runner/Info.plist').read_bytes())
        expected = [{'SKAdNetworkIdentifier': 'cstr6suwn9.skadnetwork'}]
        self.assertEqual(info['SKAdNetworkItems'], expected)
        identifiers = [item['SKAdNetworkIdentifier'] for item in info['SKAdNetworkItems']]
        self.assertEqual(len(identifiers), len(set(identifiers)))
        self.assertTrue(all(re.fullmatch(r'[a-z0-9]{10}\.skadnetwork', value) for value in identifiers))
        self.assertEqual(info['GADApplicationIdentifier'], '$(ADMOB_APP_ID)')
        self.assertNotIn('NSUserTrackingUsageDescription', info)

    def test_no_duplicate_plist_declarations_hide_attribution_values(self):
        root = ET.parse(ROOT / 'ios/Runner/Info.plist').getroot()
        for dictionary in root.iter('dict'):
            keys = [element.text for element in dictionary if element.tag == 'key']
            self.assertEqual(len(keys), len(set(keys)))
        declarations = [element for element in root.iter('key') if element.text == 'SKAdNetworkItems']
        self.assertEqual(len(declarations), 1)


if __name__ == '__main__':
    unittest.main()
