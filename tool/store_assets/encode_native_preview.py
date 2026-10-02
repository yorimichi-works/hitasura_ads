#!/usr/bin/env python3
"""Plan/encode ONE native preview; never batch, animate screenshots, or upload.

The capture manifest and the raw sources are mandatory. The default command is
read-only planning; --execute runs one bounded ffmpeg encode, then verifies it.
Technical verification never substitutes for native-pixel review or ASC review.
"""
import argparse
import copy
import datetime
from fractions import Fraction
import hashlib
import json
import math
import pathlib
import re
import struct
import subprocess
import uuid
import zlib


SCENES = (('liquid', 'G003'), ('fruit', 'G008'))
LOCALES = {'en', 'ja', 'zh', 'zh_TW', 'ko', 'es', 'fr', 'de', 'pt', 'ru',
           'it', 'hi', 'bn', 'ar', 'ur', 'fa', 'id', 'tr', 'vi', 'th'}
AUDIO_SHA256 = 'a246dec1d7b1bb9a2982f79d8ebd49c804ef157217b003d6a94d2f0209435ca0'
AUDIO_GIT_BLOB = '40ad593e5210e0d14209870846f82e3a260842e7'
SECONDS_PER_SEGMENT = 10
FPS = 30
FRAMES = 600


class PreviewError(ValueError):
    """An evidence or technical acceptance gate failed."""


def require(condition, message):
    if not condition:
        raise PreviewError(message)


def number(value, label):
    try:
        result = float(value)
    except (TypeError, ValueError):
        raise PreviewError(f'Missing or invalid {label}') from None
    require(math.isfinite(result), f'Non-finite {label}')
    return result


def ratio(value, label):
    try:
        return Fraction(str(value).replace(':', '/'))
    except (ValueError, ZeroDivisionError):
        raise PreviewError(f'Missing or invalid {label}') from None


def sha256_file(path):
    digest = hashlib.sha256()
    with pathlib.Path(path).open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def geometry_for(device_group, width, height):
    """Only the three reviewed, exactly proportional mappings are accepted."""
    mappings = {
        ('iphone_6_9', 1320, 2868): ((4, 5, 6, 6), (886, 1920), Fraction(2, 3)),
        ('ipad_13', 2064, 2752): ((0, 0, 0, 0), (1200, 1600), Fraction(25, 43)),
        ('ipad_13', 2048, 2732): ((0, 1, 0, 0), (1200, 1600), Fraction(400, 683)),
    }
    try:
        padding, target, scale = mappings[(device_group, width, height)]
    except (KeyError, TypeError):
        raise PreviewError(f'Unreviewed geometry: {device_group} {width}x{height}') from None
    left, right, top, bottom = padding
    padded = (width + left + right, height + top + bottom)
    require(padded[0] * scale == target[0] and padded[1] * scale == target[1],
            'Geometry must preserve the exact aspect ratio')
    return {'source_dimensions': [width, height], 'padded_dimensions': list(padded),
            'padding_pixels': dict(zip(('left', 'right', 'top', 'bottom'), padding)),
            'padding_color': 'black', 'padding_pixel_format': 'gbrp',
            'uniform_scale': f'{scale.numerator}/{scale.denominator}',
            'output_dimensions': list(target), 'sample_aspect_ratio': '1:1',
            'crop': None}


def geometry_filter(geometry):
    """RGB before padding is essential: YUV420 would round the odd width."""
    width, height = geometry['padded_dimensions']
    output_width, output_height = geometry['output_dimensions']
    padding = geometry['padding_pixels']
    return (f"format=gbrp,pad={width}:{height}:{padding['left']}:{padding['top']}:black,"
            f'scale={output_width}:{output_height}:flags=lanczos,setsar=1,format=yuv420p')


def only_stream(probe, kind):
    streams = [stream for stream in probe.get('streams', []) if stream.get('codec_type') == kind]
    require(len(streams) == 1, f'Exactly one {kind} stream is required')
    return streams[0]


def validate_source_probe(probe, device_group, trim_start, native_witness=None):
    video = only_stream(probe, 'video')
    sar = video.get('sample_aspect_ratio')
    if sar is None:
        require(native_witness is not None and native_witness.get('dimensions') ==
                [video.get('width'), video.get('height')],
                'Missing source SAR requires a verified same-session native PNG witness')
        if video.get('display_aspect_ratio') is not None:
            require(ratio(video['display_aspect_ratio'], 'source DAR') == Fraction(video['width'], video['height']),
                    'Native display aspect ratio is inconsistent')
    else:
        require(ratio(sar, 'source SAR') == 1, 'Source pixels must be square')
    require(number(video.get('start_time', 0), 'source start time') == 0,
            'Source video must start at timestamp zero for acknowledged trims')
    for side in video.get('side_data_list', []):
        require(number(side.get('rotation', 0), 'source rotation') == 0,
                'Rotated native sources require explicit geometry review')
    require(number(video.get('tags', {}).get('rotate', 0), 'source rotation') == 0,
            'Rotated native sources require explicit geometry review')
    duration = number(video.get('duration'), 'source video duration')
    require(trim_start >= 0 and duration >= trim_start + SECONDS_PER_SEGMENT,
            'Source is shorter than its selected ten-second gameplay interval')
    require(ratio(video.get('avg_frame_rate'), 'source frame rate') > 0,
            'Source frame rate must be positive')
    geometry = geometry_for(device_group, video.get('width'), video.get('height'))
    geometry['source_pixel_aspect_ratio'] = {'reported': sar, 'resolved': '1:1',
        'basis': 'reported_source_metadata' if sar is not None else 'verified_native_screen_png_same_session'}
    return geometry


def build_ffmpeg_command(segments, audio_path, output_path, *, threads=2, ffmpeg='ffmpeg'):
    """Return argv, never shell text. Exactly two reviewed ten-second segments."""
    require(threads in (1, 2), 'Only one or two codec threads are allowed')
    require(len(segments) == 2, 'Exactly two native gameplay segments are required')
    require(tuple((s['scene'], s['game_id']) for s in segments) == SCENES,
            'Preview order must be G003 LiquidSort then G008 FruitMergeDrop')
    require(segments[0]['geometry']['output_dimensions'] == segments[1]['geometry']['output_dimensions'],
            'Both segments must use the same output dimensions')
    require(pathlib.Path(output_path).suffix.lower() == '.mp4', 'Output must be an MP4')
    command = [ffmpeg, '-hide_banner', '-nostdin', '-n', '-threads', str(threads),
               '-filter_complex_threads', '1']
    for segment in segments:
        command += ['-threads', str(threads), '-noautorotate', '-i', str(segment['path'])]
    command += ['-threads', str(threads), '-i', str(audio_path)]
    filters = []
    for index, segment in enumerate(segments):
        start = number(segment['trim_start_seconds'], 'trim start')
        require(start >= 0, 'Trim start cannot be negative')
        filters.append(
            f'[{index}:v:0]trim=start={start:.9f}:duration=10,setpts=PTS-STARTPTS,'
            f'fps=fps=30:start_time=0:round=near,trim=end_frame=300,setpts=N/(30*TB),'
            f"{geometry_filter(segment['geometry'])}[v{index}]")
    filters += ['[v0][v1]concat=n=2:v=1:a=0[video]',
                '[2:a:0]atrim=start=0:duration=20,asetpts=PTS-STARTPTS,'
                'aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo,'
                'afade=t=out:st=19.9:d=0.1[audio]']
    command += ['-filter_complex', ';'.join(filters), '-map', '[video]', '-map', '[audio]',
                '-map_metadata', '-1', '-map_chapters', '-1', '-c:v', 'libx264',
                '-preset', 'medium', '-profile:v', 'high', '-level:v', '4.0',
                '-pix_fmt', 'yuv420p', '-b:v', '11M', '-minrate:v', '11M', '-maxrate:v', '11M', '-bufsize:v', '22M',
                '-x264-params', 'nal-hrd=vbr:filler=1:force-cfr=1', '-threads:v', str(threads),
                '-fps_mode:v', 'cfr', '-r:v', '30', '-frames:v', '600',
                '-c:a', 'aac', '-b:a', '256k', '-ar', '48000', '-ac', '2',
                '-disposition:a:0', 'default', '-t', '20', '-video_track_timescale', '30000',
                '-movflags', '+faststart', '-metadata',
                'comment=Native iOS gameplay; postproduction app music bed, not live-recorded audio',
                str(output_path)]
    return command


def probe_media(path, *, ffprobe='ffprobe', full=False):
    command = [ffprobe, '-v', 'error', '-threads', '2', '-show_streams', '-show_format']
    if full:
        command += ['-count_frames', '-show_packets', '-show_entries',
                    'stream:format:packet=stream_index,pts_time,dts_time,duration_time,flags']
    command += ['-of', 'json', str(path)]
    result = subprocess.run(command, check=True, capture_output=True, text=True, timeout=180)
    return json.loads(result.stdout)


def validate_output_probe(probe, expected_dimensions, file_size):
    """Technical delivery gate; actual stream rates, frames and DTS are checked."""
    video = only_stream(probe, 'video')
    audio = only_stream(probe, 'audio')
    require(len(probe['streams']) == 2, 'Unexpected extra output streams')
    require(video.get('codec_name') == 'h264' and video.get('profile') == 'High',
            'Output must be H.264 High Profile')
    level = number(video.get('level'), 'H.264 level')
    require(0 < level <= 40, 'H.264 level must be at most 4.0')
    require([video.get('width'), video.get('height')] == list(expected_dimensions),
            'Incorrect output dimensions')
    require(video.get('pix_fmt') == 'yuv420p', 'Output must use yuv420p')
    require(video.get('field_order') == 'progressive', 'Output must be progressive')
    require(ratio(video.get('sample_aspect_ratio'), 'output SAR') == 1, 'Output SAR must be 1:1')
    for key in ('avg_frame_rate', 'r_frame_rate'):
        require(ratio(video.get(key), key) == FPS, 'Output frame rate must be exactly 30 fps')
    require(number(video.get('nb_read_frames'), 'decoded frame count') == FRAMES,
            'Output must have exactly 600 decoded video frames')
    require(number(video.get('nb_frames'), 'container frame count') == FRAMES,
            'Container must report exactly 600 video frames')
    require(abs(number(video.get('duration'), 'video duration') - 20) <= 1 / 60,
            'Video duration must be twenty seconds')
    require(abs(number(video.get('start_time'), 'video start time')) <= 1 / 30000,
            'Video timestamp must start at zero')
    require(10_000_000 <= number(video.get('bit_rate'), 'video bitrate') <= 12_000_000,
            'Measured video bitrate must be between 10 and 12 Mbps')
    require(audio.get('codec_name') == 'aac', 'Audio must be AAC')
    require(number(audio.get('sample_rate'), 'audio sample rate') == 48000 and
            audio.get('channels') == 2 and audio.get('channel_layout') == 'stereo',
            'Audio must be stereo at 48 kHz')
    require(audio.get('disposition', {}).get('default') == 1, 'Audio track must be enabled by default')
    require(240_000 <= number(audio.get('bit_rate'), 'audio bitrate') <= 272_000,
            'Measured AAC bitrate is outside the 256 kbps target tolerance')
    require(abs(number(audio.get('duration'), 'audio duration') - 20) <= .05,
            'Audio must cover the twenty-second preview')
    require(abs(number(audio.get('start_time'), 'audio start time')) <= 1 / 48000,
            'Audio timestamp must start at zero')
    require(19.98 <= number(probe.get('format', {}).get('duration'), 'container duration') <= 20.05,
            'Incorrect MP4 duration')
    require('mp4' in probe.get('format', {}).get('format_name', '').split(','), 'Output is not MP4')
    require(0 < file_size < 500_000_000, 'Output must be nonempty and below 500 MB')
    packets = probe.get('packets')
    require(isinstance(packets, list) and packets, 'Packet timestamps are required')
    previous = {}
    counts = {}
    video_pts = []
    for packet in packets:
        index = packet.get('stream_index')
        require(index in (video.get('index'), audio.get('index')), 'Unexpected packet stream')
        dts = number(packet.get('dts_time'), 'packet DTS')
        number(packet.get('pts_time'), 'packet PTS')
        require(number(packet.get('duration_time'), 'packet duration') > 0,
                'Packet duration must be positive')
        require(index not in previous or dts > previous[index], 'Packet DTS must strictly increase')
        if index == video['index']:
            require(index not in previous or abs(dts - previous[index] - 1 / FPS) <= .00001,
                    'Video packet timestamps have a gap or incorrect frame cadence')
            video_pts.append(number(packet['pts_time'], 'video PTS'))
        previous[index] = dts
        counts[index] = counts.get(index, 0) + 1
    require(counts.get(video['index']) == FRAMES, 'Video packet count must be 600')
    require(all(abs(pts - index / FPS) <= .00001 for index, pts in enumerate(sorted(video_pts))),
            'Video presentation timestamps must cover exactly 600 continuous frames')
    require(counts.get(audio['index'], 0) > 0, 'Audio packets are missing')
    return {'status': 'passed', 'frames': FRAMES, 'duration_seconds': 20,
            'video_bitrate': int(video['bit_rate']), 'audio_bitrate': int(audio['bit_rate']),
            'human_pixel_review': 'pending', 'asc_processing': 'not_tested'}


def build_decode_command(path, *, ffmpeg='ffmpeg', threads=2):
    require(threads in (1, 2), 'Only one or two codec threads are allowed')
    return [ffmpeg, '-hide_banner', '-nostdin', '-v', 'info', '-xerror',
            '-threads', str(threads), '-filter_threads', '1', '-i', str(path),
            '-map', '0:v:0', '-map', '0:a:0', '-vf',
            'blackdetect=d=0.5:pix_th=0.05,freezedetect=n=-50dB:d=2', '-f', 'null', '-']


def visual_diagnostics(stderr):
    """Keep freeze/black detections as review cues, never as visual approval."""
    return {'status': 'requires_human_review', 'events': [line.strip() for line in stderr.splitlines()
            if re.search(r'(freeze_(start|duration|end)|black_start):', line)]}


def utc(value, label):
    try:
        result = datetime.datetime.fromisoformat(value.replace('Z', '+00:00'))
    except (AttributeError, TypeError, ValueError):
        raise PreviewError(f'Missing or invalid {label}') from None
    require(result.utcoffset() == datetime.timedelta(0), f'{label} must be UTC')
    return result


def validate_record_evidence(record, locale, device_group, scene, game_id):
    """Validate schema-2 host/app evidence before touching video or constructing argv."""
    require(record.get('id') == f'{locale}/{device_group}/{scene}', 'Capture record ID mismatch')
    require(record.get('record_key') == record['id'] and record.get('game_no') == int(game_id[1:]),
            'Capture record key/game mismatch')
    require(record.get('media_type') == 'video', 'Capture record must be native video')
    require(record.get('locale') == locale and record.get('device_group') == device_group and
            record.get('scene') == scene, 'Capture locale/device/scene mismatch')
    ready, started, complete = (record.get(key, {}) for key in
                                ('scene_ready', 'gameplay_started', 'gameplay_complete'))
    session_id = ready.get('session_id')
    require(isinstance(session_id, str) and session_id, 'Native session ID is missing')
    require(ready.get('request_id') and started.get('request_id') and
            ready['request_id'] != started['request_id'] and
            started['request_id'] == complete.get('request_id'), 'Stale or mismatched recording request ID')
    game_no = int(game_id[1:])
    for state, stage, action in ((ready, 'ready', 'show'), (started, 'gameplay_started', 'record_start'),
                                 (complete, 'gameplay_complete', 'record_start')):
        require(state.get('stage') == stage and state.get('action') == action,
                f'Missing native {stage} evidence')
        require(state.get('session_id') == session_id and state.get('launch_id') == session_id,
                'Native evidence session mismatch')
        require(state.get('locale') == locale and state.get('requested_scene') == scene and
                state.get('active_scene') == scene and state.get('game_no') == game_no,
                'Native evidence locale/scene/game mismatch')
        require(all(state.get(key) is True for key in ('native_simulator_attested', 'debug_mode', 'is_ios')),
                'Native simulator attestation is missing')
        require(state.get('phase') == 'play', 'Gameplay left the active play phase')
    require(number(started.get('duration_seconds'), 'requested gameplay duration') == 10,
            'Gameplay request must be ten seconds')
    elapsed = number(complete.get('elapsed_seconds'), 'active gameplay elapsed time')
    require(elapsed >= 10, 'Gameplay ended before ten seconds')
    game_start = number(started.get('game_time'), 'starting game time')
    game_end = number(complete.get('game_time_end'), 'ending game time')
    require(number(complete.get('game_time_start'), 'completion starting game time') == game_start,
            'Gameplay start/end evidence mismatch')
    require(game_end - game_start >= 8, 'Gameplay clock did not advance sufficiently')
    require(number(ready.get('game_time'), 'ready game time') <= game_start,
            'Ready game clock follows the recorded start')
    for state in (started, complete):
        require(state.get('input_method') == 'flutter_gesture_binding_pointer_events',
                'Inputs did not use the ordinary Flutter pointer event pipeline')
        require(state.get('random_seed') == 'shipping_time_seed_unmodified',
                'Unreviewed gameplay seed or world-state mutation')
    recorder = record.get('recorder', {})
    require(recorder.get('recording_acknowledged') is True, 'Native recorder acknowledgment is missing')
    ready_at = utc(ready.get('ready_at'), 'scene ready time')
    process_at = utc(recorder.get('process_started_utc'), 'recorder process start')
    ack_at = utc(recorder.get('ack_observed_utc'), 'recorder acknowledgment')
    command_at = utc(recorder.get('command_sent_utc'), 'record-start command time')
    start_at = utc(started.get('started_at'), 'gameplay start')
    end_at = utc(complete.get('completed_at'), 'gameplay completion')
    stop_at = utc(recorder.get('stopped_utc'), 'recorder stop')
    require(ready_at <= process_at <= ack_at <= command_at <= start_at < end_at <= stop_at,
            'Native recording timeline is inconsistent')
    require(utc(complete.get('started_at'), 'completion start') == start_at,
            'Completion belongs to a different gameplay start')
    require((end_at - start_at).total_seconds() >= 10 and
            abs((end_at - start_at).total_seconds() - elapsed) <= .25,
            'Wall-clock and monotonic gameplay intervals disagree')
    uncertainty = (number(recorder.get('ack_observed_monotonic'), 'recorder acknowledgment monotonic time') -
                   number(recorder.get('process_started_monotonic'), 'recorder process monotonic time'))
    require(uncertainty >= 0 and abs(uncertainty - number(record.get('recording_start_uncertainty_seconds'),
            'recording start uncertainty')) <= .01, 'Recording start uncertainty is inconsistent')
    require(abs((ack_at - process_at).total_seconds() - uncertainty) <= .25,
            'Recorder wall-clock and monotonic timing disagree')
    trim = number(record.get('trim_start_seconds'), 'native trim start')
    require(trim > 0 and abs(trim - (start_at - ack_at).total_seconds()) <= .001,
            'Native trim must use the positive acknowledged timing offset')
    require(record.get('trim_basis') == 'conservative_ack_anchored_play_window' and
            number(record.get('trim_duration_seconds'), 'native trim duration') == 10,
            'Unreviewed native trim basis or length')
    events = complete.get('input_events')
    require(isinstance(events, list) and len(events) > 0, 'Native pointer input journal is missing')
    down = set()
    last_elapsed, last_game_time = -1, game_start
    for event in events:
        kind, pointer = event.get('kind'), event.get('pointer')
        require(kind in ('down', 'move', 'up') and isinstance(pointer, int), 'Invalid native pointer event')
        for key in ('virtual_xy', 'global_logical_xy'):
            point = event.get(key)
            require(isinstance(point, list) and len(point) == 2, f'Missing native input {key}')
            for coordinate in point:
                number(coordinate, f'input {key}')
        x, y = (number(value, 'virtual input coordinate') for value in event['virtual_xy'])
        require(0 <= x <= 360 and 0 <= y <= 640, 'Pointer input lies outside the actual game viewport')
        actual = number(event.get('actual_elapsed_seconds'), 'input elapsed time')
        game_time = number(event.get('game_time'), 'input game time')
        require(last_elapsed <= actual < elapsed and game_start <= game_time <= game_end and
                game_time >= last_game_time, 'Native input timestamps are out of order or outside gameplay')
        require(0 <= number(event.get('scheduled_seconds'), 'scheduled input time') <= actual,
                'Native input occurred before it was scheduled')
        if kind == 'down':
            require(pointer not in down, 'Duplicate pointer down')
            down.add(pointer)
        else:
            require(pointer in down, 'Pointer move/up has no corresponding down')
            if kind == 'up':
                down.remove(pointer)
        last_elapsed, last_game_time = actual, game_time
    require(not down, 'Native pointer input was left pressed')
    return trim


def source_path(root, relative_path):
    require(isinstance(relative_path, str) and relative_path, 'Native relative_path is missing')
    relative = pathlib.Path(relative_path)
    require(not relative.is_absolute() and '..' not in relative.parts, 'Source must stay inside its capture artifact')
    result = (root / relative).resolve()
    require(result.is_relative_to(root.resolve()) and result.is_file(), 'Source missing or outside capture artifact')
    return result


def native_png_witness(manifest, record, root):
    """simctl MOV may omit SAR; prove its raster against the same native screen."""
    session_id = record['scene_ready']['session_id']
    for candidate in manifest.get('records', []):
        evidence = candidate.get('app_evidence', {})
        if not (candidate.get('media_type') == 'image' and
                candidate.get('locale') == record['locale'] and
                candidate.get('device_group') == record['device_group'] and
                candidate.get('device_udid') == record['device_udid'] and
                evidence.get('session_id') == session_id and evidence.get('stage') == 'ready' and
                evidence.get('launch_id') == session_id and evidence.get('locale') == candidate['locale'] and
                evidence.get('active_scene') == evidence.get('requested_scene') == candidate.get('scene') and
                all(evidence.get(k) is True for k in ('native_simulator_attested', 'debug_mode', 'is_ios'))):
            continue
        path = source_path(root, candidate.get('relative_path'))
        require(sha256_file(path) == candidate.get('sha256'), 'Native PNG witness hash mismatch')
        data = path.read_bytes()
        require(data[:8] == b'\x89PNG\r\n\x1a\n', 'Native PNG witness signature is invalid')
        offset, dimensions, image_data, ended = 8, None, False, False
        while offset + 12 <= len(data):
            size = struct.unpack('>I', data[offset:offset + 4])[0]
            kind = data[offset + 4:offset + 8]
            payload = data[offset + 8:offset + 8 + size]
            end = offset + 12 + size
            require(end <= len(data), 'Native PNG witness is truncated')
            crc = struct.unpack('>I', data[offset + 8 + size:end])[0]
            require(zlib.crc32(kind + payload) & 0xffffffff == crc, 'Native PNG witness CRC mismatch')
            if kind == b'IHDR':
                require(offset == 8 and size == 13, 'Native PNG witness header is invalid')
                dimensions = list(struct.unpack('>II', payload[:8]))
            if kind == b'IDAT': image_data = True
            if kind == b'IEND':
                require(size == 0 and end == len(data), 'Native PNG witness ending is invalid')
                ended = True
                break
            offset = end
        require(ended and image_data and dimensions == record['dimensions'] == candidate.get('dimensions'),
                'Native PNG witness is incomplete or has mismatched dimensions')
        return {'record_id': candidate['id'], 'path': str(path), 'sha256': candidate['sha256'],
                'dimensions': dimensions, 'session_id': session_id,
                'basis': 'Same-session native simulator screen raster, verified PNG bytes and source hash'}
    raise PreviewError('Missing source SAR requires a verified same-session native PNG witness')


def build_plan(manifest_path, record_ids, output_path, audio_path, *, threads=2, ffmpeg='ffmpeg',
               ffprobe='ffprobe', probe=probe_media):
    manifest_path = pathlib.Path(manifest_path).resolve()
    output_path = pathlib.Path(output_path).resolve()
    audio_path = pathlib.Path(audio_path).resolve()
    manifest = json.loads(manifest_path.read_text())
    require(manifest.get('origin') == 'native_ios_simulator' and
            manifest.get('production_ui_unchanged') is True, 'Only unchanged native iOS captures are accepted')
    for key in ('app_source_sha', 'capture_script_sha'):
        require(isinstance(manifest.get(key), str) and re.fullmatch('[0-9a-f]{40}', manifest[key]),
                f'Missing source provenance: {key}')
    require(len(record_ids) == 2 and len(set(record_ids)) == 2, 'Select exactly two distinct native record IDs')
    selected = []
    for record_id in record_ids:
        matches = [r for r in manifest.get('records', []) if r.get('id') == record_id]
        require(len(matches) == 1, f'Native record ID missing or duplicated: {record_id}')
        selected.append(matches[0])
    locale, device_group = selected[0].get('locale'), selected[0].get('device_group')
    require(locale in LOCALES, 'Unknown app locale')
    for key in ('device_udid', 'runtime', 'device_name'):
        require(selected[0].get(key) and selected[0][key] == selected[1].get(key),
                f'Native sources have missing or different {key}')
    segments = []
    for record, (scene, game_id) in zip(selected, SCENES):
        trim = validate_record_evidence(record, locale, device_group, scene, game_id)
        path = source_path(manifest_path.parent, record.get('relative_path'))
        source_hash = sha256_file(path)
        require(source_hash == record.get('sha256'), f'Native source hash mismatch: {record["id"]}')
        source_probe = probe(path, ffprobe=ffprobe)
        witness = native_png_witness(manifest, record, manifest_path.parent) if only_stream(source_probe, 'video').get('sample_aspect_ratio') is None else None
        geometry = validate_source_probe(source_probe, device_group, trim, witness)
        require(record.get('dimensions') == geometry['source_dimensions'] and
                record.get('dimension_source') == 'native_screenshot_same_session',
                'Probed native dimensions disagree with same-session capture evidence')
        ack_path = source_path(manifest_path.parent, record['recorder'].get('ack_log'))
        require('recording started' in ack_path.read_text(errors='replace').lower(),
                'Native recording acknowledgment log contains no start acknowledgment')
        recorder = record['recorder']
        earliest = utc(recorder['process_started_utc'], 'recorder start') + datetime.timedelta(seconds=trim)
        latest = utc(recorder['ack_observed_utc'], 'recorder acknowledgment') + datetime.timedelta(seconds=trim)
        segments.append({'record_id': record['id'], 'scene': scene, 'game_id': game_id,
                         'path': str(path), 'sha256': source_hash, 'trim_start_seconds': trim,
                         'trim_duration_seconds': 10, 'geometry': geometry,
                         'source_probe': source_probe, 'capture_evidence': copy.deepcopy(record),
                         'native_pixel_witness': witness,
                         'acknowledgment_log': {'path': str(ack_path), 'sha256': sha256_file(ack_path)},
                         'trim_interval_utc_bounds': {
                             'start_earliest': earliest.isoformat(), 'start_latest': latest.isoformat(),
                             'end_earliest': (earliest + datetime.timedelta(seconds=10)).isoformat(),
                             'end_latest': (latest + datetime.timedelta(seconds=10)).isoformat(),
                             'note': 'Recorder acknowledgment bounds, not frame-exact input synchronization; pixel review required'}})
    require(segments[0]['path'] != segments[1]['path'], 'Each game needs its own native source')
    require(selected[0]['gameplay_started']['request_id'] != selected[1]['gameplay_started']['request_id'],
            'The two recordings reused a recording-start request ID')
    require(audio_path.is_file() and sha256_file(audio_path) == AUDIO_SHA256,
            'Postproduction music must match the approved bundled cute.mp3 source')
    audio_probe = probe(audio_path, ffprobe=ffprobe)
    audio = only_stream(audio_probe, 'audio')
    require(number(audio.get('duration'), 'music duration') >= 20 and audio.get('channels') == 2,
            'Approved music source is too short or not stereo')
    command = build_ffmpeg_command(segments, audio_path, output_path, threads=threads, ffmpeg=ffmpeg)
    input_paths = {manifest_path, audio_path, *(pathlib.Path(segment['path']) for segment in segments),
                   *(pathlib.Path(segment['acknowledgment_log']['path']) for segment in segments)}
    input_paths.update(pathlib.Path(segment['native_pixel_witness']['path']) for segment in segments if segment['native_pixel_witness'])
    require(all(path not in input_paths for path in
                (output_path, output_path.with_suffix('.manifest.json'), output_path.with_suffix('.encode.log'),
                 output_path.with_suffix('.decode.log'))), 'Output or evidence would overwrite an input')
    return {'schema_version': 1, 'status': 'planned_not_encoded', 'locale': locale,
            'device_group': device_group, 'manifest_path': str(manifest_path),
            'capture_manifest_sha256': sha256_file(manifest_path),
            'capture_provenance': {key: copy.deepcopy(value) for key, value in manifest.items() if key != 'records'},
            'segments': segments, 'edit': {'duration_seconds': 20, 'frames': 600, 'fps': 30,
                'cut_seconds': 10, 'transition': 'hard_cut', 'speed': 1,
                'frame_interpolation': False, 'overlays': False},
            'audio': {'origin': 'postproduction_app_music_bed', 'live_recorded': False,
                'source_path': str(audio_path), 'source_sha256': AUDIO_SHA256, 'source_git_blob': AUDIO_GIT_BLOB,
                'source_probe': audio_probe, 'excerpt_start_seconds': 0, 'excerpt_duration_seconds': 20,
                'gain_db': 0, 'fade_out': {'start_seconds': 19.9, 'duration_seconds': .1},
                'encoding': {'codec': 'aac', 'sample_rate': 48000, 'channels': 2, 'target_bps': 256000}},
            'output_path': str(output_path), 'encoder_command': command, 'threads': threads,
            'human_pixel_review': 'pending', 'asc_processing': 'not_tested'}


def assert_inputs_unchanged(plan):
    require(sha256_file(plan['manifest_path']) == plan['capture_manifest_sha256'], 'Capture manifest changed')
    for segment in plan['segments']:
        require(sha256_file(segment['path']) == segment['sha256'], 'Native source changed after planning')
        ack = segment['acknowledgment_log']
        require(sha256_file(ack['path']) == ack['sha256'], 'Recorder acknowledgment evidence changed')
        witness = segment.get('native_pixel_witness')
        if witness:
            require(sha256_file(witness['path']) == witness['sha256'], 'Native PNG witness changed after planning')
    require(sha256_file(plan['audio']['source_path']) == plan['audio']['source_sha256'],
            'Music source changed after planning')


def write_json(path, value):
    pending = path.with_name(path.name + '.pending')
    pending.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')
    pending.replace(path)


def execute_plan(plan, *, ffmpeg='ffmpeg', ffprobe='ffprobe', resume=False):
    """Run one encode, followed by sequential probe/decode QA; retain failed evidence."""
    assert_inputs_unchanged(plan)
    output = pathlib.Path(plan['output_path'])
    sidecar = output.with_suffix('.manifest.json')
    if output.exists():
        require(resume and sidecar.is_file(), 'Output already exists; refusing to overwrite')
        previous = json.loads(sidecar.read_text())
        require(previous.get('status') == 'technical_passed_pending_human_review' and
                previous.get('capture_manifest_sha256') == plan['capture_manifest_sha256'] and
                previous.get('encoder_command') == plan['encoder_command'] and
                previous.get('output_sha256') == sha256_file(output), 'Existing output cannot be safely resumed')
        # A hash-identical file with the identical sources/command retains its verified QA.
        return previous
    output.parent.mkdir(parents=True, exist_ok=True)
    require(not sidecar.exists() or resume, 'Prior attempt exists; use --resume to retain it and retry')
    if sidecar.exists():
        previous_attempt = sidecar.with_name(sidecar.name + f'.previous-{uuid.uuid4().hex}.json')
        previous_attempt.write_bytes(sidecar.read_bytes())
    temporary = output.with_name(f'{output.stem}.partial-{uuid.uuid4().hex}.mp4')
    encode_log = temporary.with_suffix('.encode.log')
    decode_log = temporary.with_suffix('.decode.log')
    report = copy.deepcopy(plan)
    command = list(plan['encoder_command'])
    command[-1] = str(temporary)
    report.update(status='encoding_in_progress', executed_encoder_command=command, partial_output_path=str(temporary),
                  encode_log=str(encode_log), decode_log=str(decode_log))
    write_json(sidecar, report)
    try:
        version = subprocess.run([ffmpeg, '-version'], check=True, capture_output=True, text=True, timeout=10)
        report['encoder_version'] = version.stdout.splitlines()[0]
        with encode_log.open('w') as log:
            subprocess.run(command, check=True, stdout=log, stderr=subprocess.STDOUT, timeout=1800)
        assert_inputs_unchanged(plan)
        encoded_probe = probe_media(temporary, ffprobe=ffprobe, full=True)
        report['output_probe'] = encoded_probe
        report['technical_qa'] = validate_output_probe(encoded_probe,
            plan['segments'][0]['geometry']['output_dimensions'], temporary.stat().st_size)
        decode_command = build_decode_command(temporary, ffmpeg=ffmpeg, threads=plan['threads'])
        decoded = subprocess.run(decode_command, check=False, capture_output=True, text=True, timeout=180)
        decode_log.write_text(decoded.stderr)
        decoded.check_returncode()
        report.update(decode_command=decode_command, decode_status='passed',
                      visual_diagnostics=visual_diagnostics(decoded.stderr),
                      output_sha256=sha256_file(temporary), output_bytes=temporary.stat().st_size,
                      status='technical_passed_pending_human_review',
                      completed_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
        require(not output.exists(), 'Output appeared during encode; refusing to overwrite')
        temporary.replace(output)
        report.pop('partial_output_path')
        write_json(sidecar, report)
        return report
    except Exception as error:
        report.update(status='failed', error=str(error))
        if temporary.is_file():
            report.update(partial_output_sha256=sha256_file(temporary), partial_output_bytes=temporary.stat().st_size)
        write_json(sidecar, report)
        raise


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', required=True, type=pathlib.Path)
    parser.add_argument('--records', required=True, nargs=2, metavar=('LIQUID_ID', 'FRUIT_ID'))
    parser.add_argument('--output', required=True, type=pathlib.Path)
    parser.add_argument('--audio', type=pathlib.Path,
                        default=pathlib.Path(__file__).resolve().parents[2] / 'assets/audio/bgm/cute.mp3')
    parser.add_argument('--threads', choices=(1, 2), type=int, default=2)
    parser.add_argument('--ffmpeg', default='ffmpeg')
    parser.add_argument('--ffprobe', default='ffprobe')
    parser.add_argument('--execute', action='store_true', help='Encode this one validated pair only')
    parser.add_argument('--resume', action='store_true', help='Reuse exact verified output or retry with retained partials')
    args = parser.parse_args(argv)
    if args.resume and not args.execute:
        parser.error('--resume requires --execute')
    try:
        plan = build_plan(args.manifest, args.records, args.output, args.audio,
                          threads=args.threads, ffmpeg=args.ffmpeg, ffprobe=args.ffprobe)
        result = execute_plan(plan, ffmpeg=args.ffmpeg, ffprobe=args.ffprobe, resume=args.resume) if args.execute else plan
    except (PreviewError, OSError, subprocess.SubprocessError, json.JSONDecodeError) as error:
        parser.exit(1, f'Native preview gate failed: {error}\n')
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
