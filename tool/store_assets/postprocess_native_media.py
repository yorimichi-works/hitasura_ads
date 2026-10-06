#!/usr/bin/env python3
"""Bounded same-run native candidates; raw captures are never rewritten.

Only opaque 8-bit non-interlaced RGB/RGBA PNGs are accepted. Preview conversion
is delegated unchanged to encode_native_preview.py. All outputs await review.
"""
import argparse
from contextlib import contextmanager
import hashlib
import json
import os
import pathlib
import re
import signal
import struct
import subprocess
import sys
import time
import zlib

import capture_session
import encode_native_preview as encoder
import xctest_screenshot

REPOSITORY = 'yorimichi-works/hitasura_ads'
DIMENSIONS = {'iphone_6_9': {(1290, 2796), (1320, 2868), (1260, 2736)},
              'ipad_13': {(2048, 2732), (2064, 2752)}}
PNG_LIMIT = 32 * 1024 * 1024
PRODUCTION_BASE = '5969bac7aab8589fb3a7ad92990c92cc059c05fe'
PROTECTED_OBJECTS = {
    'lib': '90c4830f6585ad61ebf3e45267bc258b25531536',
    'assets': 'b90c149b82841bd64dc3eadf4644b4e492780f05',
    'ios': '9f4863db7730f29ceceb2a73d615bdfbe0598951',
    'android': 'd351b34b3d48f3aca9c52ab5cf8e62b4d01b8a3f',
    'pubspec.yaml': '38bad1a6a19f2105814ad791fdcd0b6680b11ffd',
    'pubspec.lock': 'f6f8783321fc5f5a0ac5874510b7059f8b2afe26',
}


def verify_protected_objects(capture_source_sha):
    values = subprocess.run(['git', 'rev-parse', *[capture_source_sha + ':' + path
                            for path in PROTECTED_OBJECTS]], check=True, capture_output=True,
                            text=True, timeout=10).stdout.splitlines()
    require(values == list(PROTECTED_OBJECTS.values()), 'Protected production tree differs from reviewed base')
    return PROTECTED_OBJECTS.copy()


class ProcessingInterrupted(BaseException):
    def __init__(self, signum):
        self.signum = signum
        super().__init__('Postprocessing interrupted by signal ' + str(signum))


@contextmanager
def cancellation_handlers():
    previous = {sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)}
    def interrupted(signum, frame):
        # Ignore escalation while bounded cleanup and the final report are written.
        for sig in previous:
            signal.signal(sig, signal.SIG_IGN)
        raise ProcessingInterrupted(signum)
    try:
        for sig in previous:
            signal.signal(sig, interrupted)
        yield
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)


def require(value, message):
    if not value:
        raise ValueError(message)


def unique_keys(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, 'Duplicate JSON key')
        result[key] = value
    return result


def load_json(path):
    return json.loads(path.read_text(), object_pairs_hook=unique_keys)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def chunk(kind, data):
    return (struct.pack('>I', len(data)) + kind + data +
            struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff))


def png_chunks(data):
    xctest_screenshot._png_dimensions(data)  # Existing full-envelope/CRC guard.
    offset = 8
    while offset < len(data):
        size = struct.unpack_from('>I', data, offset)[0]
        yield data[offset + 4:offset + 8], data[offset + 8:offset + 8 + size]
        offset += size + 12


def decode_rgb(data, tick=lambda: None):
    """No colour transform, resampling, transparency flattening, or screenshot fixes."""
    require(len(data) <= PNG_LIMIT, 'PNG is too large')
    chunks = list(png_chunks(data))
    width, height, depth, colour, compression, filtering, interlace = struct.unpack('>IIBBBBB', chunks[0][1])
    require(depth == 8 and colour in (2, 6) and not interlace,
            'Only 8-bit non-interlaced RGB/RGBA PNGs are supported')
    require(width * height <= 8_000_000, 'PNG raster is too large')
    require(not any(kind in (b'acTL', b'fcTL', b'fdAT', b'tRNS') for kind, _ in chunks),
            'Animated or transparency-key PNGs are not accepted')
    require(all(not kind[2] & 32 for kind, _ in chunks), 'Reserved PNG chunk bit is invalid')
    require(all(kind in (b'IHDR', b'PLTE', b'IDAT', b'IEND') or kind[0] & 32
                for kind, _ in chunks), 'Unknown critical PNG chunk')
    # PNG editors may retain unknown chunks only when their safe-to-copy bit is set.
    # These known colour/palette chunks retain their meaning after opaque alpha removal;
    # sBIT is explicitly changed from four channels to three below.
    known_unsafe = {b'cHRM', b'gAMA', b'iCCP', b'sBIT', b'sRGB', b'bKGD', b'hIST'}
    if colour == 6:
        require(all(not kind[0] & 32 or kind[3] & 32 or kind in known_unsafe
                    for kind, _ in chunks), 'Unknown unsafe-to-copy PNG metadata')
    bpp = 4 if colour == 6 else 3
    stride = width * bpp
    expected = (stride + 1) * height
    inflater = zlib.decompressobj()
    pixels = inflater.decompress(b''.join(payload for kind, payload in chunks if kind == b'IDAT'), expected + 1)
    require(len(pixels) == expected and inflater.eof and not inflater.unused_data and not inflater.unconsumed_tail,
            'PNG raster length or compressed stream is invalid')
    rgb = bytearray(width * height * 3)
    previous = bytearray(stride)
    for y in range(height):
        tick()
        start = y * (stride + 1)
        method = pixels[start]
        require(method in range(5), 'Unsupported PNG row filter')
        row = bytearray(pixels[start + 1:start + 1 + stride])
        for x in range(stride) if method else ():
            left = row[x - bpp] if x >= bpp else 0
            up = previous[x]
            corner = previous[x - bpp] if x >= bpp else 0
            if method == 1:
                predictor = left
            elif method == 2:
                predictor = up
            elif method == 3:
                predictor = (left + up) // 2
            else:
                p = left + up - corner
                a, b, c = abs(p - left), abs(p - up), abs(p - corner)
                predictor = left if a <= b and a <= c else up if b <= c else corner
            row[x] = (row[x] + predictor) & 255
        if bpp == 4:
            require(all(alpha == 255 for alpha in row[3::4]), 'Non-opaque PNG alpha; no flattening allowed')
            target = y * width * 3
            rgb[target:target + width * 3:3] = row[0::4]
            rgb[target + 1:target + width * 3:3] = row[1::4]
            rgb[target + 2:target + width * 3:3] = row[2::4]
        else:
            rgb[y * width * 3:(y + 1) * width * 3] = row
        previous = row
    return width, height, bytes(rgb), colour, chunks


def encode_rgb(width, height, rgb, original_chunks=None):
    header = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    raster = b''.join(b'\0' + rgb[y * width * 3:(y + 1) * width * 3] for y in range(height))
    if original_chunks is None:
        original_chunks = [(b'IHDR', header), (b'IDAT', b''), (b'IEND', b'')]
    output = bytearray(b'\x89PNG\r\n\x1a\n')
    wrote_idat = False
    for kind, payload in original_chunks:
        if kind == b'IHDR':
            payload = header
        elif kind == b'IDAT':
            if wrote_idat:
                continue
            payload, wrote_idat = zlib.compress(raster, 6), True
        elif kind == b'sBIT':
            require(len(payload) == 4, 'Invalid RGBA significant-bits metadata')
            payload = payload[:3]
        output += chunk(kind, payload)
    return bytes(output)


def normalize_png(data, tick=lambda: None):
    width, height, rgb, colour, chunks = decode_rgb(data, tick)
    output = encode_rgb(width, height, rgb, chunks) if colour == 6 else data
    check = decode_rgb(output, tick)
    relevant = {b'gAMA', b'cHRM', b'iCCP', b'sRGB', b'pHYs'}
    metadata = [(kind, payload) for kind, payload in chunks if kind in relevant]
    require(metadata == [(kind, payload) for kind, payload in check[4] if kind in relevant],
            'PNG colour/profile/gamma metadata changed')
    require(check[:3] == (width, height, rgb) and check[3] == 2, 'RGB pixels changed')
    return output, {'dimensions': [width, height], 'input_colour_type': colour,
                    'output_colour_type': 2, 'all_alpha_255': colour == 6,
                    'rgb_pixel_sha256': sha(rgb), 'rgb_pixels_identical': True,
                    'colour_profile_gamma_metadata_identical': True,
                    'operation': 'remove_opaque_alpha' if colour == 6 else 'byte_identical_copy'}, (width, height, rgb)


def thumbnail(width, height, rgb):
    target_width = 150
    target_height = round(height * target_width / width)
    result = bytearray(target_width * target_height * 3)
    for y in range(target_height):
        for x in range(target_width):
            source = ((y * height // target_height) * width + x * width // target_width) * 3
            target = (y * target_width + x) * 3
            result[target:target + 3] = rgb[source:source + 3]
    return target_width, target_height, bytes(result)


def contact_sheet(tiles):
    width = sum(tile[0] for _, tile in tiles)
    height = max(tile[1] for _, tile in tiles)
    canvas = bytearray(width * height * 3)
    offset = 0
    for _, (w, h, pixels) in tiles:
        for y in range(h):
            start = (y * width + offset) * 3
            canvas[start:start + w * 3] = pixels[y * w * 3:(y + 1) * w * 3]
        offset += w
    result = encode_rgb(width, height, bytes(canvas))
    require(len(result) <= 2 * 1024 * 1024, 'Review contact sheet exceeds size budget')
    return result


def capture_key(locale, device, scene, media_type):
    suffix = '_screenshot' if media_type == 'image' and scene in ('liquid', 'fruit') else ''
    return f'{locale}/{device}/{scene}{suffix}'


def validate_manifest(manifest, args):
    require(manifest.get('origin') == 'native_ios_simulator' and
            manifest.get('production_ui_unchanged') is True and manifest.get('session_loop') is True,
            'Expected unchanged native session-loop capture')
    require(manifest.get('app_target') == 'tool/store_assets/native_capture_main.dart', 'Wrong native target')
    for key, expected in [('app_source_sha', args.app_source_sha), ('capture_script_sha', args.capture_source_sha)]:
        require(re.fullmatch('[0-9a-f]{40}', expected or '') and manifest.get(key) == expected,
                'Stale or mismatched ' + key)
    ci = manifest.get('ci', {})
    require(str(ci.get('run_id')) == args.run_id and str(ci.get('run_attempt')) == args.run_attempt,
            'Stale or mismatched run/attempt')
    require(manifest.get('status') in ('captured_pending_pixel_review', 'partial_deadline', 'failed'),
            'Capture is not finalized')
    require(manifest.get('requested_locales') == args.locales, 'Locale chunk mismatch')
    require(1 <= len(args.locales) <= 2 and len(set(args.locales)) == len(args.locales)
            and set(args.locales) <= encoder.LOCALES, 'Expected at most two known distinct locales')
    require(args.device in DIMENSIONS, 'Unknown device')
    scenes = manifest.get('requested_scenes')
    require(isinstance(scenes, list) and scenes and len(scenes) <= 5 and len(set(scenes)) == len(scenes)
            and set(scenes) <= capture_session.SCENES - {'settings'}, 'Invalid screenshot scene list')
    keys = [key for locale in args.locales for key in
            ([capture_key(locale, args.device, scene, 'image') for scene in scenes] +
             [capture_key(locale, args.device, scene, 'video') for scene in ('liquid', 'fruit')])]
    require(manifest.get('required_record_keys') == keys, 'Capture target keys mismatch')
    records = manifest.get('records')
    require(isinstance(records, list) and len(records) <= len(keys), 'Invalid or extra records')
    seen = set()
    sessions = {}
    devices = {}
    for record in records:
        key = record.get('id')
        require(key in keys and key not in seen and record.get('record_key') == key, 'Duplicate/unexpected record')
        require(record.get('media_type') in ('image', 'video'), 'Unsupported media type')
        require(key == capture_key(record.get('locale'), record.get('device_group'), record.get('scene'), record['media_type']),
                'Record identity mismatch')
        require(record.get('device_udid') and record.get('runtime') and record.get('device_name'), 'Missing native device identity')
        require(record['scene'] in (scenes if record['media_type'] == 'image' else ('liquid', 'fruit')),
                'Record media type differs from scene')
        evidence = record.get('app_evidence', {})
        session = evidence.get('session_id')
        pair = record['locale'], record['device_group']
        require(session and sessions.setdefault(pair, session) == session, 'Mixed native sessions')
        identity = tuple(record[key] for key in ('device_udid', 'runtime', 'device_name'))
        require(devices.setdefault(pair, identity) == identity, 'Mixed native device identity')
        states = [evidence]
        if record['media_type'] == 'video':
            require(evidence == record.get('gameplay_complete'), 'Video app evidence differs from completion')
            states += [record.get(key, {}) for key in ('scene_ready', 'gameplay_started', 'gameplay_complete')]
        require(all(state.get('session_id') == session and state.get('launch_id') == session for state in states),
                'Nested native evidence session mismatch')
        seen.add(key)
    require(manifest.get('remaining_required_scene_keys') == [key for key in keys if key not in seen],
            'Remaining checkpoint mismatch')
    return records, scenes


def validate_screenshot(record):
    locale, scene = record['locale'], record['scene']
    state = record.get('app_evidence', {})
    require(record.get('media_type') == 'image', 'Not a native screenshot')
    require(state.get('request_transport') == 'app_documents_json_v2' and state.get('stage') == 'ready' and state.get('action') == 'show',
            'Missing native screenshot readiness')
    require(state.get('request_id') and state.get('session_id') and state.get('launch_id') == state['session_id'],
            'Missing or stale native screenshot session')
    require(state.get('locale') == locale and state.get('active_scene') == state.get('requested_scene') == scene,
            'Screenshot scene/locale mismatch')
    require(all(state.get(key) is True for key in ('native_simulator_attested', 'debug_mode', 'is_ios')),
            'Missing native screenshot attestation')
    encoder.utc(state.get('ready_at'), 'screenshot ready time')
    require(tuple(record.get('dimensions', [])) in DIMENSIONS[record['device_group']], 'Unexpected native dimensions')
    if scene in capture_session.GAME_NUMBERS:
        capture_session.validate_game_observation(state, scene, state['request_id'])
        previous_time = state['game_time']
        previous_at = encoder.utc(state['ready_at'], 'scene ready time')
        request_ids = {state['request_id']}
        for key in ('app_evidence_before_screenshot', 'app_evidence_after_screenshot'):
            observed = record.get(key, {})
            request = {'session_id': state['session_id'], 'request_id': observed.get('request_id'),
                       'locale': locale, 'scene': scene, 'action': 'inspect'}
            require(observed.get('request_id') and capture_session.state_matches(observed, request)
                    and observed.get('stage') == 'inspected'
                    and all(observed.get(k) is True for k in ('native_simulator_attested', 'debug_mode', 'is_ios')),
                    'Missing or stale native gameplay observation')
            require(observed['request_id'] not in request_ids, 'Reused screenshot observation request')
            request_ids.add(observed['request_id'])
            observed_at = encoder.utc(observed.get('at'), 'screenshot inspection time')
            require(observed_at >= previous_at, 'Screenshot inspection timestamp moved backwards')
            previous_at = observed_at
            capture_session.validate_game_observation(observed, scene, state['request_id'])
            require(observed['game_time'] >= previous_time, 'Screenshot gameplay clock moved backwards')
            previous_time = observed['game_time']


def stop_process_group(process):
    """Bounded cleanup cannot be interrupted before SIGKILL reaches descendants."""
    previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGINT, signal.SIGTERM})
    try:
        try:
            os.killpg(process.pid, signal.SIGTERM)
        except ProcessLookupError:
            return
        try:
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                pass
        finally:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=2)
    finally:
        # A pending cancellation is delivered here, after the group is cleaned.
        signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)


def run_bounded(argv, log, seconds):
    """Every exit cleans the process group; cancellation propagates to the report."""
    require(seconds > 5, 'Insufficient process budget')
    with log.open('xb') as stream:
        process = subprocess.Popen(argv, stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            try:
                code = process.wait(timeout=seconds - 5)
            except subprocess.TimeoutExpired:
                raise TimeoutError('Postprocess process-group budget exhausted') from None
            require(code == 0, 'Encoder rejected source or failed; see retained log')
        finally:
            stop_process_group(process)


def process(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', required=True, type=pathlib.Path)
    parser.add_argument('--output-root', required=True, type=pathlib.Path)
    parser.add_argument('--app-source-sha', required=True)
    parser.add_argument('--capture-source-sha', required=True)
    parser.add_argument('--production-base-sha', required=True, choices=[PRODUCTION_BASE])
    parser.add_argument('--run-id', required=True)
    parser.add_argument('--run-attempt', required=True)
    parser.add_argument('--locales', required=True, type=lambda value: value.split(','))
    parser.add_argument('--device', required=True, choices=DIMENSIONS)
    parser.add_argument('--raw-artifact-name', required=True)
    parser.add_argument('--work-seconds', type=int, default=600, choices=range(30, 601))
    parser.add_argument('--audio', type=pathlib.Path, default=pathlib.Path(__file__).resolve().parents[2] / 'assets/audio/bgm/cute.mp3')
    parser.add_argument('--execute-previews', action='store_true')
    args = parser.parse_args(argv)
    deadline = time.monotonic() + args.work_seconds
    def tick():
        if time.monotonic() >= deadline - 10:
            raise TimeoutError('Postprocess work deadline reached; summary reserve retained')
    root = args.manifest.resolve().parent
    output = args.output_root.resolve()
    require(not output.is_relative_to(root) and not root.is_relative_to(output), 'Outputs must be separate from raw inputs')
    output.mkdir(parents=True, exist_ok=False)
    report = {'schema_version': 1, 'status': 'in_progress', 'repository': REPOSITORY,
              'source': {'compiled_capture_app_source_sha': args.app_source_sha, 'capture_source_sha': args.capture_source_sha,
                         'production_base_sha': args.production_base_sha, 'run_id': args.run_id, 'run_attempt': args.run_attempt,
                         'raw_artifact_name': args.raw_artifact_name},
              'human_pixel_review': 'pending', 'asc_processing': 'not_tested', 'records': [], 'locales': {}}
    def save():
        encoder.write_json(output / 'results.json', report)
    save()
    try:
        manifest = load_json(args.manifest)
        report['source']['capture_status'] = manifest.get('status')
        report['source']['manifest_sha256'] = encoder.sha256_file(args.manifest)
        records, scenes = validate_manifest(manifest, args)
        report['source']['protected_git_objects'] = verify_protected_objects(args.capture_source_sha)
        contact_tiles = {locale: [] for locale in args.locales}
        report['source']['requested_scenes'] = scenes
        report['source']['remaining_required_scene_keys'] = manifest['remaining_required_scene_keys']
        for locale in args.locales:
            report['locales'][locale] = {'device': args.device, 'expected_screenshots': len(scenes),
                'accepted_screenshots': 0, 'rejected_screenshots': 0, 'missing_screenshots': 0,
                'preview_status': 'not_processed', 'visual_approval': 'pending'}
        for record in records:
            if record.get('media_type') != 'image':
                continue
            item = {'id': record['id'], 'kind': 'screenshot', 'original_sha256': record.get('sha256'),
                    'original_relative_path': record.get('relative_path'), 'human_pixel_review': 'pending',
                    'status': 'processing'}
            report['records'].append(item)
            save()
            try:
                tick()
                validate_screenshot(record)
                source = encoder.source_path(root, record.get('relative_path'))
                data = xctest_screenshot._read_regular_file(source, PNG_LIMIT)
                require(sha(data) == record.get('sha256'), 'Original screenshot hash mismatch')
                normalized, qa, raster = normalize_png(data, tick)
                require(qa['dimensions'] == record['dimensions'], 'PNG dimensions disagree with capture')
                destination = output / record['locale'] / args.device / (record['scene'] + '.png')
                destination.parent.mkdir(parents=True, exist_ok=True)
                with destination.open('xb') as stream:
                    stream.write(normalized)
                require(encoder.sha256_file(source) == record['sha256'], 'Original screenshot changed')
                require(encoder.sha256_file(destination) == sha(normalized), 'Written screenshot hash mismatch')
                item.update(status='technical_passed_pending_human_review',
                            output_relative_path=str(destination.relative_to(output)),
                            output_sha256=sha(normalized), output_bytes=len(normalized), qa=qa)
                contact_tiles[record['locale']].append((record['scene'], thumbnail(*raster)))
                report['locales'][record['locale']]['accepted_screenshots'] += 1
            except (ValueError, RuntimeError, OSError, TimeoutError, zlib.error) as error:
                item.update(status='rejected_or_deferred', reason=str(error))
                report['locales'][record['locale']]['rejected_screenshots'] += 1
            save()
        for locale, tiles in contact_tiles.items():
            if tiles:
                path = output / locale / args.device / 'screenshots-review-only.png'
                path.write_bytes(contact_sheet(tiles))
                report['locales'][locale]['review_sheet'] = {'path': str(path.relative_to(output)),
                    'left_to_right_scenes': [name for name, _ in tiles], 'review_only_not_store_asset': True}
        for locale in args.locales:
            counts = report['locales'][locale]
            counts['missing_screenshots'] = len(scenes) - counts['accepted_screenshots'] - counts['rejected_screenshots']
            ids = [f'{locale}/{args.device}/{scene}' for scene, _ in encoder.SCENES]
            selected = [record for record in records if record['id'] in ids]
            item = {'id': f'{locale}/{args.device}/preview', 'kind': 'preview', 'input_record_ids': ids,
                    'original_sources': [{'id': r['id'], 'relative_path': r.get('relative_path'), 'sha256': r.get('sha256')} for r in selected],
                    'human_pixel_review': 'pending'}
            destination = output / locale / args.device / 'preview.mp4'
            item.update(status='processing',
                candidate_output_relative_path=str(destination.relative_to(output)),
                encoder_sidecar_relative_path=str(destination.with_suffix('.manifest.json').relative_to(output)),
                worker_log_relative_path=str(destination.with_suffix('.worker.log').relative_to(output)))
            counts['preview_status'] = 'processing'
            report['records'].append(item)
            save()
            try:
                tick()
                require(len(selected) == 2, 'Matching liquid/fruit native records are incomplete')
                require(encoder.sha256_file(args.manifest) == report['source']['manifest_sha256'], 'Capture manifest changed')
                command = [sys.executable, str(pathlib.Path(__file__).with_name('encode_native_preview.py')),
                           '--manifest', str(args.manifest.resolve()), '--records', *ids, '--output', str(destination),
                           '--audio', str(args.audio.resolve()), '--threads', '2']
                destination.parent.mkdir(parents=True, exist_ok=True)
                if args.execute_previews:
                    command += ['--execute']
                run_bounded(command, destination.with_suffix('.worker.log'), min(270, deadline - time.monotonic() - 10))
                if args.execute_previews:
                    sidecar = load_json(destination.with_suffix('.manifest.json'))
                    require(sidecar.get('status') == 'technical_passed_pending_human_review'
                            and sidecar.get('capture_manifest_sha256') == report['source']['manifest_sha256']
                            and sidecar.get('output_sha256') == encoder.sha256_file(destination), 'Preview completion evidence mismatch')
                    item.update(status=sidecar['status'], output_relative_path=str(destination.relative_to(output)),
                                output_sha256=sidecar['output_sha256'], output_bytes=destination.stat().st_size,
                                technical_qa=sidecar['technical_qa'], decode_status=sidecar['decode_status'],
                                visual_diagnostics=sidecar['visual_diagnostics'])
                    # Small unlabelled sample strip; the manifest supplies exact frame indices.
                    sample = destination.with_name('preview-review-only.png')
                    try:
                        run_bounded(['ffmpeg', '-hide_banner', '-nostdin', '-v', 'error', '-n',
                            '-threads', '2', '-i', str(destination), '-vf',
                            'select=eq(n\\,30)+eq(n\\,180)+eq(n\\,330)+eq(n\\,480),scale=180:-2,tile=4x1',
                            '-frames:v', '1', str(sample)], destination.with_suffix('.samples.log'),
                            min(25, deadline - time.monotonic() - 10))
                        require(sample.stat().st_size <= 2 * 1024 * 1024, 'Sample strip exceeds review budget')
                        item['review_samples'] = {'path': str(sample.relative_to(output)),
                            'frame_indices': [30, 180, 330, 480], 'seconds': [1, 6, 11, 16],
                            'review_only_not_store_asset': True}
                    except (ValueError, OSError, TimeoutError, subprocess.SubprocessError) as error:
                        item['review_samples'] = {'status': 'unavailable', 'reason': str(error)}
                else:
                    item.update(status='validated_plan_only_not_encoded')
            except (ValueError, OSError, TimeoutError, subprocess.SubprocessError) as error:
                item.update(status='rejected_or_deferred', reason=str(error))
            counts['preview_status'] = item['status']
            save()
        require(encoder.sha256_file(args.manifest) == report['source']['manifest_sha256'], 'Capture manifest changed')
        report['status'] = ('technical_candidates_pending_human_review' if all(
            c['accepted_screenshots'] == c['expected_screenshots'] and
            c['preview_status'] == 'technical_passed_pending_human_review' for c in report['locales'].values()) else 'incomplete_requires_attention')
    except (ProcessingInterrupted, KeyboardInterrupt) as error:
        report.update(status='interrupted', reason=str(error),
                      interrupted_signal=getattr(error, 'signum', int(signal.SIGINT)))
    except (ValueError, RuntimeError, OSError, TimeoutError, subprocess.SubprocessError) as error:
        report.update(status='rejected', reason=str(error))
    finally:
        for item in report['records']:
            if item.get('status') == 'processing':
                item.update(status='interrupted' if report['status'] == 'interrupted' else 'rejected_or_deferred',
                            reason='Processing did not finish; retained evidence is not approved')
        for locale, counts in report['locales'].items():
            images = [item for item in report['records'] if item['kind'] == 'screenshot' and item['id'].startswith(locale + '/')]
            accepted = {item['id'] for item in images if item['status'] == 'technical_passed_pending_human_review'}
            expected = [capture_key(locale, args.device, scene, 'image') for scene in report['source']['requested_scenes']]
            counts.update(accepted_screenshots=len(accepted), rejected_screenshots=len(images) - len(accepted),
                          missing_screenshots=len(expected) - len(images),
                          remaining_screenshot_ids=[key for key in expected if key not in accepted])
            previews = [item for item in report['records'] if item['kind'] == 'preview' and item['id'].startswith(locale + '/')]
            if previews:
                counts['preview_status'] = previews[0]['status']
        report['elapsed_seconds'] = round(time.monotonic() - deadline + args.work_seconds, 2)
        report['files'] = [{'path': str(path.relative_to(output)), 'sha256': encoder.sha256_file(path), 'bytes': path.stat().st_size}
                           for path in sorted(output.rglob('*')) if path.is_file() and path.name != 'results.json']
        save()
    print(json.dumps({'status': report['status'], 'locales': report['locales']}, ensure_ascii=False))
    if report['status'] == 'interrupted':
        return 128 + report['interrupted_signal']
    return 0 if report['status'] == 'technical_candidates_pending_human_review' else 1


def main(argv=None):
    with cancellation_handlers():
        return process(argv)


if __name__ == '__main__':
    raise SystemExit(main())
