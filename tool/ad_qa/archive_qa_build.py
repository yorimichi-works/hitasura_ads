#!/usr/bin/env python3
"""Retain and verify the exact same-run unsigned rewarded QA app/UI-test products."""
import argparse
import hashlib
import json
import pathlib
import re
import tarfile


def sha256(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def expected(source_sha):
    if not re.fullmatch(r'[0-9a-f]{40}', source_sha):
        raise ValueError('An exact source SHA is required')
    return {'source_sha': source_sha, 'target': 'tool/ad_qa/rewarded_ad_qa_main.dart',
            'mode': 'debug_ios_simulator', 'app_store_archive': False,
            'native_ui_driver': 'RewardedQaUITests', 'ad_mode': 'test',
            'demo_unit': 'ca-app-pub-3940256099942544/1712485313'}


def pack(archive, source_sha, app_root, products):
    descriptor = expected(source_sha)
    if archive.exists():
        raise ValueError('Refusing to overwrite a retained QA build')
    if not (app_root / 'Runner.app').is_dir() or not (app_root / 'provenance.json').is_file():
        raise ValueError('Prepared simulator QA app/provenance is missing')
    provenance = json.loads((app_root / 'provenance.json').read_text())
    for key in ('source_sha', 'target', 'ad_mode', 'demo_unit', 'app_store_archive'):
        if provenance.get(key) != descriptor[key]:
            raise ValueError('Prepared QA provenance differs from retained descriptor')
    runs = list(products.glob('*.xctestrun'))
    if len(runs) != 1:
        raise ValueError('Exactly one compiled XCTest run configuration is required')
    archive.parent.mkdir(parents=True, exist_ok=True)
    descriptor_path = archive.with_suffix('.json')
    descriptor_path.write_text(json.dumps(descriptor, indent=2))
    with tarfile.open(archive, 'w:gz') as tar:
        tar.add(app_root, arcname='qa_app')
        tar.add(products, arcname='Products')
        tar.add(descriptor_path, arcname='qa-build.json')
    return sha256(archive)


def unpack(archive, output, source_sha, digest):
    if not re.fullmatch(r'[0-9a-f]{64}', digest) or sha256(archive) != digest:
        raise ValueError('QA archive differs from same-run builder digest')
    if output.exists():
        raise ValueError('Refusing to overwrite an unpacked QA build')
    with tarfile.open(archive, 'r:gz') as tar:
        names = [member.name for member in tar.getmembers()]
        if any(pathlib.PurePosixPath(name).parts[0] not in {'qa_app', 'Products', 'qa-build.json'} for name in names):
            raise ValueError('Unexpected QA archive member')
        descriptor = json.load(tar.extractfile('qa-build.json'))
        if descriptor != expected(source_sha):
            raise ValueError('QA archive source/target differs from current run')
        output.mkdir(parents=True)
        tar.extractall(output, filter='data')
    runs = list((output / 'Products').glob('*.xctestrun'))
    if len(runs) != 1:
        raise ValueError('Unpacked UI-test run configuration missing/ambiguous')
    return runs[0]


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['pack', 'unpack'])
    parser.add_argument('--source-sha', required=True)
    parser.add_argument('--archive', default='build/rewarded-qa-build.tar.gz')
    parser.add_argument('--app-root', default='build/rewarded_qa_app')
    parser.add_argument('--products', default='build/rewarded_qa_ui/Build/Products')
    parser.add_argument('--output', default='build/rewarded_qa_reused')
    parser.add_argument('--sha256')
    args = parser.parse_args()
    if args.action == 'pack':
        print(pack(pathlib.Path(args.archive), args.source_sha,
                   pathlib.Path(args.app_root), pathlib.Path(args.products)))
    else:
        print(unpack(pathlib.Path(args.archive), pathlib.Path(args.output),
                     args.source_sha, args.sha256 or ''))
