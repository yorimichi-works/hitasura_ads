#!/usr/bin/env python3
"""Copy the guarded unsigned UMP QA simulator build; never modify shipping files."""
import argparse
import hashlib
import importlib.util
import json
import pathlib
import plistlib
import shutil

ROOT = pathlib.Path(__file__).resolve().parents[2]
HITASURA_APP_ID = 'ca-app-pub-3186852093801241~9948289508'


def validate_simulator_qa_app(app):
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    if info.get('CFBundleIdentifier') != 'com.syamo.hitasuraads':
        raise ValueError('Unexpected app bundle identifier')
    if info.get('CFBundleSupportedPlatforms') != ['iPhoneSimulator']:
        raise ValueError('Only simulator bundles may receive the QA app-ID override')
    kernel = app / 'Frameworks/App.framework/flutter_assets/kernel_blob.bin'
    if not kernel.is_file() or b'tool/ump_qa/ump_qa_main.dart' not in kernel.read_bytes():
        raise ValueError('The separate Debug UMP QA Dart target was not built')
    spec = importlib.util.spec_from_file_location(
        'native_bridge', ROOT / 'tool/store_assets/verify_native_bridge.py')
    bridge = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(bridge)
    native = bridge.verify(app)
    return info, native


def prepare(source, output):
    source, output = source.resolve(), output.resolve()
    if output.exists() or output == source or source in output.parents:
        raise ValueError('QA copy destination must be separate and absent')
    info, native = validate_simulator_qa_app(source)
    before = hashlib.sha256((source / 'Info.plist').read_bytes()).hexdigest()
    shutil.copytree(source, output, symlinks=True)
    info['GADApplicationIdentifier'] = HITASURA_APP_ID
    (output / 'Info.plist').write_bytes(plistlib.dumps(info))
    if hashlib.sha256((source / 'Info.plist').read_bytes()).hexdigest() != before:
        raise RuntimeError('Original simulator bundle was unexpectedly modified')
    return {'target': 'tool/ump_qa/ump_qa_main.dart', 'mode': 'debug_ios_simulator',
            'app_id': HITASURA_APP_ID, 'ad_requests': False,
            'app_store_archive': False, 'source_info_plist_sha256': before,
            'qa_info_plist_sha256': hashlib.sha256((output / 'Info.plist').read_bytes()).hexdigest(),
            'native_bridge': native}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', default='build/ios/iphonesimulator/Runner.app')
    parser.add_argument('--output', default='build/ump_qa_app/Runner.app')
    args = parser.parse_args()
    result = prepare(pathlib.Path(args.source), pathlib.Path(args.output))
    destination = pathlib.Path(args.output).parent / 'provenance.json'
    destination.write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))
