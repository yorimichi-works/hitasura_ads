"""Source-resource wiring and compiled-bundle short-label verification."""
import importlib.util
import plistlib
import re
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('display_names', ROOT / 'tool/release/verify_localized_display_names.py')
names = importlib.util.module_from_spec(spec)
spec.loader.exec_module(names)


class DisplayNameTests(unittest.TestCase):
    def test_twenty_explicit_short_labels_preserve_other_locale_names(self):
        root = ROOT / 'ios/Runner'
        locales = plistlib.loads((root / 'Info.plist').read_bytes())['CFBundleLocalizations']
        self.assertEqual(tuple(locales), names.LOCALES)
        self.assertEqual(set(p.parent.stem for p in root.glob('*.lproj/InfoPlist.strings')), set(locales))
        for locale in locales:
            expected = {'ja': 'ひたすら広告', 'en': 'Nothing But Ads'}.get(locale, 'Hitasura Ads')
            self.assertEqual(names.read_strings((root / f'{locale}.lproj/InfoPlist.strings').read_bytes()),
                             {'CFBundleDisplayName': expected})
        self.assertEqual(plistlib.loads((root / 'Info.plist').read_bytes())['CFBundleDisplayName'], 'Hitasura Ads')

    def test_xcode_variant_resource_and_every_locale_reference_are_wired(self):
        project = (ROOT / 'ios/Runner.xcodeproj/project.pbxproj').read_text()
        group = re.search(r'([0-9A-F]{24}) /\* InfoPlist.strings \*/ = \{\s*isa = PBXVariantGroup;\s*children = \((.*?)\);', project, re.S)
        self.assertIsNotNone(group)
        refs = re.findall(r'([0-9A-F]{24}) /\* ([^*]+) \*/', group[2])
        self.assertEqual([locale for _, locale in refs], list(names.LOCALES))
        for uid, locale in refs:
            entry = re.search(rf'{uid} /\* {re.escape(locale)} \*/ = \{{([^}}]+)\}};', project)
            self.assertIsNotNone(entry)
            self.assertIn('isa = PBXFileReference', entry[1])
            self.assertIn(f'path = "{locale}.lproj/InfoPlist.strings"', entry[1])
            self.assertIn('lastKnownFileType = text.plist.strings', entry[1])
        build = re.search(r'([0-9A-F]{24}) /\* InfoPlist.strings in Resources \*/ = \{isa = PBXBuildFile; fileRef = ([0-9A-F]{24})', project)
        self.assertIsNotNone(build)
        self.assertEqual(build[2], group[1])
        resources = re.search(r'97C146EC1CF9000F007C117D /\* Resources \*/ = \{(.*?)\n\t\t\};', project, re.S)[1]
        self.assertIn(build[1] + ' /* InfoPlist.strings in Resources */', resources)
        runner = re.search(r'97C146F01CF9000F007C117D /\* Runner \*/ = \{(.*?)\n\t\t\};', project, re.S)[1]
        self.assertIn(group[1] + ' /* InfoPlist.strings */', runner)
        regions = re.search(r'knownRegions = \((.*?)\);', project, re.S)[1]
        self.assertEqual(re.findall(r'"([^"]+)"', regions), [*names.LOCALES, 'Base'])
        definitions = re.findall(r'^\t\t([0-9A-F]{24}) (?:/\*.*?\*/ )?= \{', project, re.M)
        self.assertEqual(len(definitions), len(set(definitions)))

    def fixture(self, directory):
        app = Path(directory) / 'Runner.app'
        app.mkdir()
        (app / 'Runner').write_bytes(b'test fixture executable')
        (app / 'Info.plist').write_bytes(plistlib.dumps({'CFBundleLocalizations': list(names.LOCALES),
            'CFBundleDisplayName': 'Hitasura Ads', 'CFBundleExecutable': 'Runner'}))
        for locale, name in names.EXPECTED.items():
            path = app / f'{locale}.lproj/InfoPlist.strings'; path.parent.mkdir()
            path.write_bytes(plistlib.dumps({'CFBundleDisplayName': name}, fmt=plistlib.FMT_BINARY))
        return app

    def test_compiled_binary_strings_validate_all_twenty_labels(self):
        with tempfile.TemporaryDirectory() as directory:
            result = names.verify(self.fixture(directory))
        self.assertEqual(result['localizations_verified'], 20)
        self.assertEqual(result['status'], 'passed')

    def test_missing_or_wrong_nonenglish_override_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            app = self.fixture(directory); path = app / 'ar.lproj/InfoPlist.strings'
            path.write_bytes(plistlib.dumps({'CFBundleDisplayName': 'Nothing But Ads'}))
            with self.assertRaisesRegex(ValueError, 'ar'):
                names.verify(app)
            path.unlink()
            with self.assertRaises(FileNotFoundError):
                names.verify(app)

    def test_utf16_strings_and_extra_unapproved_keys(self):
        raw = '"CFBundleDisplayName" = "ひたすら広告";'.encode('utf-16')
        self.assertEqual(names.read_strings(raw), {'CFBundleDisplayName': 'ひたすら広告'})
        with self.assertRaises(ValueError):
            names.read_strings(b'"CFBundleDisplayName"="A";"CFBundleName"="B";')

    def test_source_directory_is_not_claimed_as_a_compiled_bundle(self):
        with self.assertRaisesRegex(ValueError, 'built .app'):
            names.verify(ROOT / 'ios/Runner')
        with tempfile.TemporaryDirectory() as directory:
            app = self.fixture(directory); (app / 'Runner').unlink()
            with self.assertRaisesRegex(ValueError, 'executable'):
                names.verify(app)


if __name__ == '__main__':
    unittest.main()
