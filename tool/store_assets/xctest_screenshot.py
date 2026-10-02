"""Export an unmodified XCTest image of an already-running native app.

This is capture provenance, not visual QA or approval for store submission.
The caller owns foreground/readiness evidence and the overall work deadline.
"""
import datetime
import hashlib
import json
import os
import pathlib
import re
import stat
import struct
import tempfile
import zlib


TEST_IDENTIFIER = 'NativeScreenshotUITests/testCaptureExistingForegroundApp()'
TEST_IDENTIFIER_URL = ('test://com.apple.xcode/NativeScreenshotUITests/'
                       'NativeScreenshotUITests/NativeScreenshotUITests/'
                       'testCaptureExistingForegroundApp')
ONLY_TEST = ('NativeScreenshotUITests/NativeScreenshotUITests/'
             'testCaptureExistingForegroundApp')
ATTACHMENT_NAME = 'hitasura-existing-native-frame'
UUID_PATTERN = r'[0-9A-Fa-f]{8}-(?:[0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}'
PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'


def _utc_now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def _require_original_pid(pid):
    if type(pid) is not int or pid <= 0:
        raise ValueError('Capture requires a positive original app PID')
    try:
        os.kill(pid, 0)
    except OSError as error:
        raise RuntimeError(f'Original app PID {pid} is not verifiably alive') from error


def _read_regular_file(path, maximum):
    """Do not follow attachment/manifest symlinks, including during open."""
    if path.is_symlink():
        raise ValueError(f'Symlink is not an acceptable capture source: {path}')
    with os.fdopen(os.open(path, os.O_RDONLY | os.O_NOFOLLOW), 'rb') as source:
        info = os.fstat(source.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_size > maximum:
            raise ValueError('Capture source must be a bounded regular file')
        data = source.read(maximum + 1)
    if len(data) > maximum:
        raise ValueError('Capture source exceeds its size bound')
    return data


def _unique_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f'Duplicate attachment manifest key: {key}')
        result[key] = value
    return result


def _select_attachment(export_path, udid):
    # xcresulttool exports a list of test records with testIdentifier,
    # testIdentifierURL and attachments, not a dictionary keyed by image names.
    # The checked native QA exports establish the name_<index>_<UUID>.png form.
    if export_path.is_symlink() or not export_path.is_dir():
        raise ValueError('Attachment export must be a real directory')
    manifest = json.loads(_read_regular_file(export_path / 'manifest.json', 1024 * 1024),
                          object_pairs_hook=_unique_keys)
    if not isinstance(manifest, list):
        raise ValueError('Unexpected attachment manifest structure')
    matches = []
    for record in manifest:
        if not isinstance(record, dict) or not isinstance(record.get('attachments'), list):
            raise ValueError('Malformed attachment test record')
        for attachment in record['attachments']:
            if not isinstance(attachment, dict):
                raise ValueError('Malformed attachment record')
            name = attachment.get('suggestedHumanReadableName')
            if not isinstance(name, str):
                raise ValueError('Attachment has no human-readable identity')
            if name != ATTACHMENT_NAME and not name.startswith(ATTACHMENT_NAME + '_'):
                continue
            if (record.get('testIdentifier') != TEST_IDENTIFIER or
                    record.get('testIdentifierURL') != TEST_IDENTIFIER_URL):
                raise ValueError('Named attachment belongs to the wrong test')
            if re.fullmatch(re.escape(ATTACHMENT_NAME) + r'_\d+_' + UUID_PATTERN + r'\.png', name) is None:
                raise ValueError('Named attachment must have the exact exported PNG identity')
            if attachment.get('deviceId') != udid or attachment.get('isAssociatedWithFailure') is not False:
                raise ValueError('Named attachment has wrong device or failure association')
            filename = attachment.get('exportedFileName')
            if (not isinstance(filename, str) or not filename.endswith('.png') or
                    filename in {'.png', '..png'} or
                    any(character in filename for character in ('/', '\\', '\x00', ':'))):
                raise ValueError('Unsafe or non-PNG exported attachment path')
            matches.append((export_path / filename, attachment))
    if len(matches) != 1:
        raise ValueError(f'Expected exactly one named PNG attachment, found {len(matches)}')
    return matches[0]


def _png_dimensions(data):
    """Check the entire PNG envelope without decoding or rewriting pixels."""
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError('Invalid PNG signature')
    offset, dimensions, has_idat, idat_finished = 8, None, False, False
    while offset < len(data):
        if len(data) - offset < 12:
            raise ValueError('Truncated PNG chunk')
        length = struct.unpack_from('>I', data, offset)[0]
        kind = data[offset + 4:offset + 8]
        end = offset + 12 + length
        if end > len(data) or re.fullmatch(b'[A-Za-z]{4}', kind) is None:
            raise ValueError('Invalid PNG chunk length/type')
        payload = data[offset + 8:end - 4]
        crc = struct.unpack_from('>I', data, end - 4)[0]
        if zlib.crc32(kind + payload) & 0xffffffff != crc:
            raise ValueError('Invalid PNG chunk CRC')
        if dimensions is None and kind != b'IHDR':
            raise ValueError('PNG must start with IHDR')
        if kind == b'IHDR':
            if dimensions is not None or length != 13:
                raise ValueError('Invalid or duplicate PNG IHDR')
            width, height, depth, colour, compression, filtering, interlace = struct.unpack('>IIBBBBB', payload)
            depths = {0: {1, 2, 4, 8, 16}, 2: {8, 16}, 3: {1, 2, 4, 8}, 4: {8, 16}, 6: {8, 16}}
            if not (0 < width <= 0x7fffffff and 0 < height <= 0x7fffffff):
                raise ValueError('Invalid PNG dimensions')
            if depth not in depths.get(colour, set()) or compression or filtering or interlace not in {0, 1}:
                raise ValueError('Invalid PNG IHDR encoding fields')
            dimensions = [width, height]
        elif kind == b'IDAT':
            if idat_finished:
                raise ValueError('Nonconsecutive PNG IDAT chunks')
            has_idat = True
        elif kind == b'IEND':
            if length or not has_idat or end != len(data):
                raise ValueError('Invalid PNG IEND or trailing bytes')
            return dimensions
        elif has_idat:
            idat_finished = True
        offset = end
    raise ValueError('PNG is missing IEND')


def capture(host, udid, xctestrun, output_path, original_pid, driver_source_sha):
    """Run one bounded read-only native test and return raw-image provenance.

    host.run must log commands and enforce the caller's overall deadline. Failed
    result bundles/exports stay in a unique sibling diagnostic directory. The
    output path must be new; existing files and symlinks are never overwritten.
    """
    if not isinstance(udid, str) or re.fullmatch(UUID_PATTERN, udid) is None:
        raise ValueError('Capture requires an exact simulator UDID')
    if not isinstance(driver_source_sha, str) or re.fullmatch(r'[0-9a-fA-F]{40}', driver_source_sha) is None:
        raise ValueError('Capture requires the full 40-hex driver source SHA')
    xctestrun = pathlib.Path(xctestrun).resolve(strict=True)
    if not xctestrun.is_file():
        raise ValueError('Capture requires an existing xctestrun file')
    output_path = pathlib.Path(output_path).absolute()
    if output_path.exists() or output_path.is_symlink():
        raise ValueError('Capture output must be a new file')
    _require_original_pid(original_pid)
    started = _utc_now()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    diagnostic_path = pathlib.Path(tempfile.mkdtemp(prefix=output_path.stem + '.xctest-', dir=output_path.parent))
    xcresult_path = diagnostic_path / 'capture.xcresult'
    export_path = diagnostic_path / 'attachments'
    try:
        host.run('xcodebuild', 'test-without-building', '-xctestrun', str(xctestrun),
                 '-destination', f'platform=iOS Simulator,id={udid}', '-destination-timeout', '30',
                 '-parallel-testing-enabled', 'NO', '-maximum-concurrent-test-simulator-destinations', '1',
                 '-only-testing:' + ONLY_TEST, '-test-timeouts-enabled', 'YES',
                 '-default-test-execution-time-allowance', '90',
                 '-maximum-test-execution-time-allowance', '90',
                 '-resultBundlePath', str(xcresult_path), timeout=120)
    finally:
        # Never accept a replacement launch merely because the bundle is alive.
        _require_original_pid(original_pid)
    host.run('xcrun', 'xcresulttool', 'export', 'attachments', '--path', str(xcresult_path),
             '--output-path', str(export_path), timeout=30)
    source_path, attachment = _select_attachment(export_path, udid)
    png = _read_regular_file(source_path, 128 * 1024 * 1024)
    dimensions = _png_dimensions(png)
    _require_original_pid(original_pid)
    with output_path.open('xb') as output:
        output.write(png)
    return {'capture_method': 'xctest_existing_foreground_app', 'original_pid': original_pid,
            'driver_source_sha': driver_source_sha, 'simulator_udid': udid,
            'test_identifier': TEST_IDENTIFIER, 'test_identifier_url': TEST_IDENTIFIER_URL,
            'attachment_name': ATTACHMENT_NAME,
            'suggested_human_readable_name': attachment['suggestedHumanReadableName'],
            'exported_file_name': attachment['exportedFileName'],
            'xcresult_path': str(xcresult_path), 'attachment_export_path': str(export_path),
            'raw_png_sha256': hashlib.sha256(png).hexdigest(), 'dimensions': dimensions,
            'capture_started_utc': started, 'capture_finished_utc': _utc_now()}
