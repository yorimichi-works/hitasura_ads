#!/usr/bin/env python3
"""Verify and unpack one exact existing simulator harness; never compile or sign."""
import argparse
import hashlib
import json
import pathlib
import plistlib
import subprocess
import tarfile
import zipfile

SOURCE_SHA = '17321d1e8ef249da30fe24173130ab3ace7b062f'
RUN_ID = 37042725105
ARTIFACT_ID = 11243670913
DIGEST = 'bc61661d3e65df2618bf5794dc749df5a9e1a7edf9cf80762de3891b68e432d4'
ALLOWED_DELTA = {
    '.github/workflows/ios-check.yml', 'docs/app_store_readiness_20261002.md',
    'tool/store_assets/README.md', 'tool/store_assets/capture_ios_simulator.py',
    'tool/store_assets/reuse_capture_harness.py',
    'tool/store_assets/tests/test_capture_readiness.py',
    'tool/store_assets/tests/test_reuse_capture_harness.py',
}


def verify_metadata(value):
    expected = {'id': ARTIFACT_ID, 'name': 'hitasura-native-capture-harness',
                'digest': f'sha256:{DIGEST}'}
    if any(value.get(key) != item for key, item in expected.items()):
        raise ValueError('Artifact identity or digest differs from the approved harness')
    if value.get('expired') is not False:
        raise ValueError('Artifact is expired or expiry status is unknown')
    run = value.get('workflow_run', {})
    if run.get('id') != RUN_ID or run.get('head_sha') != SOURCE_SHA:
        raise ValueError('Artifact belongs to a different source revision or workflow run')


def verify_provenance(value):
    expected = {'source_sha': SOURCE_SHA,
                'target': 'tool/store_assets/native_capture_main.dart',
                'mode': 'debug_ios_simulator', 'admob_mode': 'disabled',
                'app_store_archive': False}
    if value != expected:
        raise ValueError('Embedded harness provenance differs from the approved source/mode')


def verify_source_delta(paths):
    unexpected = sorted(set(paths) - ALLOWED_DELTA)
    if unexpected:
        raise ValueError(f'Compiled app source changed; a fresh build is required: {unexpected}')


def verify_zip(path):
    with path.open('rb') as source:
        digest = hashlib.file_digest(source, 'sha256').hexdigest()
    if digest != DIGEST:
        raise ValueError('Downloaded artifact ZIP hash does not match the approved digest')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--metadata', required=True)
    parser.add_argument('--zip', dest='archive', required=True)
    parser.add_argument('--output', default='build/reused_native_harness')
    parser.add_argument('--report', default='build/store_assets/native_ios/reuse_provenance.json')
    args = parser.parse_args()
    metadata = json.loads(pathlib.Path(args.metadata).read_text())
    verify_metadata(metadata)
    changes = subprocess.check_output(['git', 'diff', '--name-only', SOURCE_SHA, 'HEAD'],
                                      text=True, timeout=30).splitlines()
    verify_source_delta(changes)
    archive = pathlib.Path(args.archive)
    verify_zip(archive)
    output = pathlib.Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as bundle:
        expected = {'hitasura-native-capture-harness.tar.gz', 'native-capture-provenance.json'}
        if set(bundle.namelist()) != expected:
            raise ValueError('Unexpected files in retained harness artifact')
        provenance = json.loads(bundle.read('native-capture-provenance.json'))
        verify_provenance(provenance)
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
    report = {'artifact_id': ARTIFACT_ID, 'artifact_run_id': RUN_ID,
              'artifact_zip_sha256': DIGEST, 'app_source_sha': SOURCE_SHA,
              'capture_script_sha': current_sha, 'compiled_source_delta_verified': True,
              'embedded_provenance': provenance, 'native': True,
              'runtime_proof': 'pending'}
    path = pathlib.Path(args.report)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
