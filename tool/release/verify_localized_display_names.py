#!/usr/bin/env python3
"""Verify every approved Home-screen label in a built iOS application bundle."""
import argparse
import hashlib
import json
import plistlib
import re
from pathlib import Path

LOCALES = ('en', 'ja', 'zh-Hans', 'zh-Hant', 'ko', 'es', 'fr', 'de', 'pt', 'ru',
           'it', 'hi', 'bn', 'ar', 'ur', 'fa', 'id', 'tr', 'vi', 'th')
EXPECTED = {locale: {'en': 'Nothing But Ads', 'ja': 'ひたすら広告'}.get(locale, 'Hitasura Ads')
            for locale in LOCALES}


def read_strings(raw):
    try:
        value = plistlib.loads(raw)
    except plistlib.InvalidFileException:
        encoding = 'utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig'
        text = raw.decode(encoding)
        match = re.fullmatch(r'\s*("(?:[^"\\]|\\.)*")\s*=\s*("(?:[^"\\]|\\.)*")\s*;\s*', text)
        if not match:
            raise ValueError('Expected exactly one CFBundleDisplayName strings entry')
        value = {json.loads(match[1]): json.loads(match[2])}
    if not isinstance(value, dict):
        raise ValueError('Expected a strings dictionary')
    return value


def verify(app):
    app = Path(app)
    if app.suffix != '.app':
        raise ValueError('Expected a built .app bundle')
    bundle = plistlib.loads((app / 'Info.plist').read_bytes())
    executable = bundle.get('CFBundleExecutable', '')
    if not executable or '$(' in executable or Path(executable).name != executable or not (app / executable).is_file():
        raise ValueError('Built bundle executable is missing or unexpanded')
    if tuple(bundle.get('CFBundleLocalizations', ())) != LOCALES:
        raise ValueError('Built bundle must declare exactly the 20 supported locales')
    if bundle.get('CFBundleDisplayName') != 'Hitasura Ads':
        raise ValueError('Unlocalized fallback display name changed')
    records = []
    for locale, expected in EXPECTED.items():
        path = app / f'{locale}.lproj/InfoPlist.strings'
        raw = path.read_bytes()
        if read_strings(raw) != {'CFBundleDisplayName': expected}:
            raise ValueError(f'Wrong localized display name: {locale}')
        records.append({'locale': locale, 'display_name': expected,
                        'path': str(path), 'sha256': hashlib.sha256(raw).hexdigest()})
    return {'status': 'passed', 'app_path': str(app), 'base_display_name': 'Hitasura Ads',
            'localizations_verified': len(records), 'records': records,
            'note': 'Verifies compiled bundle resources; does not claim a SpringBoard pixel review.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(verify(args.app), ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
