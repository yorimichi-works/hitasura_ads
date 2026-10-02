#!/usr/bin/env python3
"""Verify and unpack one exact existing simulator harness; never compile or sign."""
import argparse
import hashlib
import json
import pathlib
import plistlib
import re
import subprocess
import tarfile
import zipfile

SOURCE_SHA = '17321d1e8ef249da30fe24173130ab3ace7b062f'
RUN_ID = 37042725105
ARTIFACT_ID = 11243670913
DIGEST = 'bc61661d3e65df2618bf5794dc749df5a9e1a7edf9cf80762de3891b68e432d4'
ALLOWED_DELTA = {
    'tool/ump_qa/README.md',
    'tool/ump_qa/UmpQaUITests.swift',
    'tool/ump_qa/UmpQaUITests.xcodeproj/project.pbxproj',
    'tool/ump_qa/UmpQaUITests.xcodeproj/xcshareddata/xcschemes/UmpQaUITests.xcscheme',
    'tool/ump_qa/archive_qa_build.py',
    'tool/ump_qa/prepare_simulator_app.py',
    'tool/ump_qa/run_native_qa.py',
    'tool/ump_qa/test_ump_qa_guards.py',
    'tool/ump_qa/ump_qa_gateway.dart',
    'tool/ump_qa/ump_qa_main.dart',
    'test/ump_qa_test.dart',
    'codemagic.yaml', 'tool/release/README.md', 'tool/release/tests/test_preflight.py',
    '.github/workflows/ios-check.yml', 'docs/app_store_readiness_20261002.md',
    'tool/store_assets/README.md', 'tool/store_assets/capture_ios_simulator.py',
    'tool/store_assets/reuse_capture_harness.py',
    'tool/store_assets/tests/test_capture_readiness.py',
    'tool/store_assets/tests/test_reuse_capture_harness.py',
    'tool/store_assets/capture_session.py',
    'tool/store_assets/tests/test_capture_session.py',
    'tool/store_assets/encode_native_preview.py',
    'tool/store_assets/tests/test_encode_native_preview.py',
    'tool/store_assets/native_capture_artifact.json',
    'tool/store_assets/native_capture_batches.json',
}


def descriptor(value=None):
    if value is None:
        value = {'repository': 'yorimichi-works/hitasura_ads', 'source_sha': SOURCE_SHA,
                 'run_id': RUN_ID, 'artifact_id': ARTIFACT_ID, 'zip_sha256': DIGEST}
    if set(value) != {'repository', 'source_sha', 'run_id', 'artifact_id', 'zip_sha256'}:
        raise ValueError('Unexpected artifact descriptor fields')
    if value['repository'] != 'yorimichi-works/hitasura_ads':
        raise ValueError('Only this repository capture artifacts are authorized')
    if not isinstance(value['source_sha'], str) or not re.fullmatch(r'[0-9a-f]{40}', value['source_sha']):
        raise ValueError('Invalid source SHA')
    if not isinstance(value['zip_sha256'], str) or not re.fullmatch(r'[0-9a-f]{64}', value['zip_sha256']):
        raise ValueError('Invalid artifact ZIP digest')
    if any(type(value[key]) is not int or value[key] <= 0 for key in ('run_id', 'artifact_id')):
        raise ValueError('Invalid run/artifact ID')
    return value


def verify_metadata(value, approved=None):
    approved = descriptor(approved)
    expected = {'id': approved['artifact_id'], 'name': 'hitasura-native-capture-harness',
                'digest': f"sha256:{approved['zip_sha256']}"}
    if any(value.get(key) != item for key, item in expected.items()):
        raise ValueError('Artifact identity or digest differs from the approved harness')
    if value.get('expired') is not False:
        raise ValueError('Artifact is expired or expiry status is unknown')
    run = value.get('workflow_run', {})
    if run.get('id') != approved['run_id'] or run.get('head_sha') != approved['source_sha']:
        raise ValueError('Artifact belongs to a different source revision or workflow run')


def verify_provenance(value, approved=None):
    approved = descriptor(approved)
    expected = {'source_sha': approved['source_sha'],
                'target': 'tool/store_assets/native_capture_main.dart',
                'mode': 'debug_ios_simulator', 'admob_mode': 'disabled',
                'app_store_archive': False}
    if value != expected:
        raise ValueError('Embedded harness provenance differs from the approved source/mode')


def verify_source_delta(paths):
    unexpected = sorted(set(paths) - ALLOWED_DELTA)
    if unexpected:
        raise ValueError(f'Compiled app source changed; a fresh build is required: {unexpected}')


def verify_zip(path, approved=None):
    approved = descriptor(approved)
    with path.open('rb') as source:
        digest = hashlib.file_digest(source, 'sha256').hexdigest()
    if digest != approved['zip_sha256']:
        raise ValueError('Downloaded artifact ZIP hash does not match the approved digest')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--metadata', required=True)
    parser.add_argument('--zip', dest='archive', required=True)
    parser.add_argument('--descriptor', help='Reviewed exact artifact descriptor, or same-run build outputs')
    parser.add_argument('--output', default='build/reused_native_harness')
    parser.add_argument('--report', default='build/store_assets/native_ios/reuse_provenance.json')
    args = parser.parse_args()
    approved = descriptor(json.loads(pathlib.Path(args.descriptor).read_text())) if args.descriptor else descriptor()
    metadata = json.loads(pathlib.Path(args.metadata).read_text())
    verify_metadata(metadata, approved)
    changes = subprocess.check_output(['git', 'diff', '--name-only', approved['source_sha'], 'HEAD'],
                                      text=True, timeout=30).splitlines()
    verify_source_delta(changes)
    archive = pathlib.Path(args.archive)
    verify_zip(archive, approved)
    output = pathlib.Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as bundle:
        expected = {'hitasura-native-capture-harness.tar.gz', 'native-capture-provenance.json'}
        if set(bundle.namelist()) != expected:
            raise ValueError('Unexpected files in retained harness artifact')
        provenance = json.loads(bundle.read('native-capture-provenance.json'))
        verify_provenance(provenance, approved)
        with bundle.open('hitasura-native-capture-harness.tar.gz') as stream, \
                tarfile.open(fileobj=stream, mode='r|gz') as app_archive:
            app_archive.extractall(output, filter='data')
    app = output / 'Runner.app'
    with (app / 'Info.plist').open('rb') as source:
        info = plistlib.load(source)
    if info.get('CFBundleIdentifier') != 'com.syamo.hitasuraads':
        raise ValueError('Reused app bundle identifier mismatch')
    current_sha = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True,
                                          timeout=10).strip()
    report = {'artifact_id': approved['artifact_id'], 'artifact_run_id': approved['run_id'],
              'artifact_zip_sha256': approved['zip_sha256'], 'app_source_sha': approved['source_sha'],
              'capture_script_sha': current_sha, 'compiled_source_delta_verified': True,
              'embedded_provenance': provenance, 'native': True,
              'runtime_proof': 'pending'}
    path = pathlib.Path(args.report)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
