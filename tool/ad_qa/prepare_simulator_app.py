#!/usr/bin/env python3
"""Prepare a separate guarded simulator demo-ad bundle, never a shipping archive."""
import argparse
import hashlib
import importlib.util
import json
import pathlib
import plistlib
import re
import shutil

ROOT = pathlib.Path(__file__).resolve().parents[2]
TARGET = 'tool/ad_qa/rewarded_ad_qa_main.dart'
BUNDLE = 'com.syamo.hitasuraads'
HITASURA_APP_ID = 'ca-app-pub-3186852093801241~9948289508'
GOOGLE_SAMPLE_APP_ID = 'ca-app-pub-3940256099942544~1458002511'
DEMO_UNIT = 'ca-app-pub-3940256099942544/1712485313'


def validate(app):
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    if info.get('CFBundleIdentifier') != BUNDLE:
        raise ValueError('Unexpected bundle identifier')
    if info.get('CFBundleSupportedPlatforms') != ['iPhoneSimulator']:
        raise ValueError('Only Debug simulator bundles are allowed')
    if info.get('GADApplicationIdentifier') not in (GOOGLE_SAMPLE_APP_ID, HITASURA_APP_ID):
        raise ValueError('Unexpected consent app identifier')
    kernel = app / 'Frameworks/App.framework/flutter_assets/kernel_blob.bin'
    if not kernel.is_file():
        raise ValueError('Missing Debug Dart kernel')
    data = kernel.read_bytes()
    if TARGET.encode() not in data or DEMO_UNIT.encode() not in data:
        raise ValueError('Separate rewarded QA target or Google demo unit absent')
    spec = importlib.util.spec_from_file_location(
        'native_bridge', ROOT / 'tool/store_assets/verify_native_bridge.py')
    bridge = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(bridge)
    return info, bridge.verify(app)


def prepare(source, output, source_sha):
    if not re.fullmatch(r'[0-9a-f]{40}', source_sha):
        raise ValueError('Exact built source SHA required')
    source, output = source.resolve(), output.resolve()
    if output.exists() or output == source or source in output.parents:
        raise ValueError('Copy destination must be separate and absent')
    info, native = validate(source)
    before = hashlib.sha256((source / 'Info.plist').read_bytes()).hexdigest()
    shutil.copytree(source, output, symlinks=True)
    # The same approved AppID as the isolated UMP QA copy is necessary for its
    # real published consent form. Ad units are still Google's demo unit only.
    info['GADApplicationIdentifier'] = HITASURA_APP_ID
    (output / 'Info.plist').write_bytes(plistlib.dumps(info))
    if hashlib.sha256((source / 'Info.plist').read_bytes()).hexdigest() != before:
        raise RuntimeError('Original simulator bundle unexpectedly changed')
    result = {
        'source_sha': source_sha, 'target': TARGET, 'ad_mode': 'test',
        'demo_unit': DEMO_UNIT, 'app_id': HITASURA_APP_ID,
        'app_store_archive': False, 'native_bridge': native,
        'source_info_plist_sha256': before,
        'qa_info_plist_sha256': hashlib.sha256((output / 'Info.plist').read_bytes()).hexdigest(),
    }
    (output.parent / 'provenance.json').write_text(json.dumps(result, indent=2))
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', default='build/ios/iphonesimulator/Runner.app')
    parser.add_argument('--output', default='build/rewarded_qa_app/Runner.app')
    parser.add_argument('--source-sha', required=True)
    args = parser.parse_args()
    print(json.dumps(prepare(pathlib.Path(args.source), pathlib.Path(args.output), args.source_sha), indent=2))
