#!/usr/bin/env python3
"""Fail before simulator boot if the debug capture bridge was compiled out."""
import argparse
import hashlib
import json
import pathlib

CHANNEL = b'hitasura_ads/simulator_capture'
MACHO_MAGIC = {b'\xcf\xfa\xed\xfe', b'\xfe\xed\xfa\xcf',
               b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca',
               b'\xca\xfe\xba\xbf', b'\xbf\xba\xfe\xca'}


def verify(app):
    records = []
    for name in ('Runner', 'Runner.debug.dylib'):
        path = app / name
        if not path.is_file():
            continue
        data = path.read_bytes()
        if data[:4] not in MACHO_MAGIC:
            raise RuntimeError(f'Expected a native Mach-O image: {name}')
        records.append({'native_image': name, 'sha256': hashlib.sha256(data).hexdigest(),
                        'capture_channel_present': CHANNEL in data})
    if not any(record['capture_channel_present'] for record in records):
        raise RuntimeError('Capture bridge absent from native Runner images; verify Runner Debug Swift compilation conditions before launching.')
    return {'status': 'native_bridge_present_runtime_proof_pending', 'images': records}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', default='build/ios/iphonesimulator/Runner.app')
    args = parser.parse_args()
    print(json.dumps(verify(pathlib.Path(args.app)), indent=2))


if __name__ == '__main__':
    main()
