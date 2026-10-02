#!/usr/bin/env python3
"""Verify exact retained UMP binaries and unchanged consent/test dependencies."""
import argparse
import hashlib
import importlib.util
import json
import pathlib
import subprocess
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
REVIEWED_APP_DELEGATES = {
    'f18a0a811dc3e8c6a0005b26d897d24f6cc1d8beca74fedcac3d532b5f0c9422',
    '3c9c9aa113ec21886b07d5176ef6cef6bf5eaff48e2a1606ccea45033fbde3bb',
}
COMPILED_PATHS = [
    'tool/ump_qa/ump_qa_main.dart', 'tool/ump_qa/ump_qa_gateway.dart',
    'tool/ump_qa/UmpQaUITests.swift', 'tool/ump_qa/UmpQaUITests.xcodeproj/project.pbxproj',
    'tool/ump_qa/UmpQaUITests.xcodeproj/xcshareddata/xcschemes/UmpQaUITests.xcscheme',
    'lib/services/ads_privacy_service.dart', 'pubspec.yaml', 'pubspec.lock',
    'ios/Runner/Info.plist', 'ios/Flutter/Debug.xcconfig',
    'ios/Runner.xcodeproj/project.pbxproj',
]


def bridge_block(source):
    marker = '#if DEBUG && targetEnvironment(simulator)'
    if source.count(marker) != 1:
        raise ValueError('Expected one guarded native simulator bridge')
    return source.split(marker, 1)[1].split('#endif', 1)[0]


def verify_dependencies(source_sha):
    for path in COMPILED_PATHS:
        original = subprocess.check_output(['git', 'show', f'{source_sha}:{path}'], timeout=10)
        current = subprocess.check_output(['git', 'show', f'HEAD:{path}'], timeout=10)
        if original != current:
            raise ValueError(f'Compiled UMP dependency changed: {path}')
    path = 'ios/Runner/AppDelegate.swift'
    original = subprocess.check_output(['git', 'show', f'{source_sha}:{path}'], text=True, timeout=10)
    current = subprocess.check_output(['git', 'show', f'HEAD:{path}'], text=True, timeout=10)
    if hashlib.sha256(current.encode()).hexdigest() not in REVIEWED_APP_DELEGATES:
        raise ValueError('Native AppDelegate differs from both reviewed revisions')
    if bridge_block(original) != bridge_block(current):
        raise ValueError('Native simulator attestation bridge changed')
    # The shipping purchase bridge changed after this build, but this QA Dart
    # target never imports/calls it. UMP service, SDK locks and native simulator
    # bridge above must remain byte-identical; media reuse has a separate guard.


def verify_metadata(meta, descriptor):
    if descriptor['repository'] != 'yorimichi-works/hitasura_ads':
        raise ValueError('Unexpected artifact repository')
    run = meta.get('workflow_run', {})
    expected = {'id': descriptor['artifact_id'], 'name': 'hitasura-ump-qa-harness',
                'digest': 'sha256:' + descriptor['zip_sha256'], 'expired': False}
    if any(meta.get(key) != value for key, value in expected.items()) or \
            run.get('id') != descriptor['run_id'] or run.get('head_sha') != descriptor['source_sha']:
        raise ValueError('Retained UMP artifact identity/expiry differs from reviewed evidence')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--metadata', required=True)
    parser.add_argument('--zip', dest='archive', required=True)
    parser.add_argument('--output', default='build/ump_qa_retained')
    args = parser.parse_args()
    descriptor = json.loads((ROOT / 'tool/ump_qa/retained_build.json').read_text())
    verify_metadata(json.loads(pathlib.Path(args.metadata).read_text()), descriptor)
    verify_dependencies(descriptor['source_sha'])
    archive = pathlib.Path(args.archive)
    with archive.open('rb') as stream:
        if hashlib.file_digest(stream, 'sha256').hexdigest() != descriptor['zip_sha256']:
            raise ValueError('Retained UMP ZIP digest mismatch')
    out = pathlib.Path(args.output)
    out.mkdir(parents=True, exist_ok=False)
    with zipfile.ZipFile(archive) as zip:
        if zip.namelist() != ['ump-qa-build.tar.gz']:
            raise ValueError('Unexpected retained UMP ZIP entries')
        zip.extract('ump-qa-build.tar.gz', out)
    spec = importlib.util.spec_from_file_location('qa_archive', ROOT / 'tool/ump_qa/archive_qa_build.py')
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    xctestrun = helper.unpack(out / 'ump-qa-build.tar.gz', out / 'verified',
                             descriptor['source_sha'], descriptor['tar_sha256'])
    (out / 'verified_reuse.json').write_text(json.dumps({**descriptor,
        'ump_dependencies_unchanged': True, 'native_bridge_unchanged': True,
        'purchase_bridge_used_by_qa': False, 'xctestrun': str(xctestrun)}, indent=2))
    print(xctestrun)


if __name__ == '__main__':
    main()
