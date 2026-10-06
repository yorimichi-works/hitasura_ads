import argparse
import copy
import importlib.util
import json
import pathlib
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib
from unittest import mock

ROOT = pathlib.Path(__file__).parents[1]
sys.path.insert(0, str(ROOT))
import postprocess_native_media as post


def png(rows, method=0, colour=6, extras=(), split=False):
    bpp = 4 if colour == 6 else 3
    width = len(rows[0]) // bpp
    filtered = bytearray()
    previous = bytes(len(rows[0]))
    for row in rows:
        filtered.append(method)
        for x, value in enumerate(row):
            left = row[x - bpp] if x >= bpp else 0
            up = previous[x]
            corner = previous[x - bpp] if x >= bpp else 0
            if method == 0: predictor = 0
            elif method == 1: predictor = left
            elif method == 2: predictor = up
            elif method == 3: predictor = (left + up) // 2
            else:
                p = left + up - corner
                choices = [(abs(p - left), left), (abs(p - up), up), (abs(p - corner), corner)]
                predictor = min(enumerate(choices), key=lambda item: (item[1][0], item[0]))[1][1]
            filtered.append((value - predictor) & 255)
        previous = row
    compressed = zlib.compress(filtered)
    idats = [compressed[:len(compressed)//2], compressed[len(compressed)//2:]] if split else [compressed]
    return (b'\x89PNG\r\n\x1a\n' + post.chunk(b'IHDR', struct.pack('>IIBBBBB', width, len(rows), 8, colour, 0, 0, 0))
            + b''.join(post.chunk(k, v) for k, v in extras)
            + b''.join(post.chunk(b'IDAT', data) for data in idats) + post.chunk(b'IEND', b''))


def image_record(scene='home'):
    ready = {'request_transport': 'app_documents_json_v2', 'stage': 'ready', 'action': 'show',
             'session_id': 'same-session', 'launch_id': 'same-session', 'request_id': 'show-' + scene,
             'locale': 'ja', 'active_scene': scene, 'requested_scene': scene,
             'native_simulator_attested': True, 'debug_mode': True, 'is_ios': True,
             'ready_at': '2026-10-06T01:00:00Z'}
    record = {'id': 'ja/iphone_6_9/' + scene, 'record_key': 'ja/iphone_6_9/' + scene,
              'locale': 'ja', 'device_group': 'iphone_6_9', 'scene': scene, 'media_type': 'image',
              'device_udid': 'native-device', 'runtime': 'iOS-18-6', 'device_name': 'iPhone 17 Pro Max',
              'dimensions': [1320, 2868], 'relative_path': scene + '.png', 'sha256': '0' * 64,
              'app_evidence': ready}
    if scene == 'pin':
        ready.update(scene_request_id=ready['request_id'], game_no=1, game_view_mounted=True,
                     same_game_session=True, phase='play', game_time=1, time_left=19)
        for key, index in [('app_evidence_before_screenshot', 2), ('app_evidence_after_screenshot', 3)]:
            record[key] = dict(ready, stage='inspected', action='inspect', request_id='inspect-' + str(index), game_time=index, at=f'2026-10-06T01:00:0{index}Z')
    return record


def fixture():
    args = argparse.Namespace(app_source_sha='a' * 40, capture_source_sha='b' * 40,
                              run_id='123', run_attempt='1', locales=['ja'], device='iphone_6_9')
    record = image_record()
    keys = [f'ja/iphone_6_9/{scene}' for scene in ('home', 'liquid', 'fruit')]
    manifest = {'origin': 'native_ios_simulator', 'production_ui_unchanged': True, 'session_loop': True,
                'app_target': 'tool/store_assets/native_capture_main.dart', 'status': 'partial_deadline',
                'app_source_sha': args.app_source_sha, 'capture_script_sha': args.capture_source_sha,
                'ci': {'run_id': args.run_id, 'run_attempt': args.run_attempt}, 'requested_locales': ['ja'],
                'requested_scenes': ['home'], 'required_record_keys': keys,
                'remaining_required_scene_keys': keys[1:], 'records': [record]}
    return args, manifest


class PNGTests(unittest.TestCase):
    def setUp(self):
        self.rows = [bytes([3, 79, 250, 255, 255, 33, 0, 255, 1, 2, 3, 255]),
                     bytes([200, 0, 60, 255, 5, 170, 30, 255, 5, 6, 7, 255])]
        self.rgb = b''.join(bytes(v for i, v in enumerate(row) if i % 4 != 3) for row in self.rows)

    def test_all_filters_multiple_idat_and_rgb_samples(self):
        for method in range(5):
            with self.subTest(filter=method):
                source = png(self.rows, method, split=True)
                output, qa, raster = post.normalize_png(source)
                self.assertEqual(raster, (3, 2, self.rgb))
                self.assertEqual(post.decode_rgb(output)[:4], (3, 2, self.rgb, 2))
                self.assertEqual(qa['rgb_pixel_sha256'], post.sha(self.rgb))
                self.assertTrue(qa['rgb_pixels_identical'])
                self.assertNotEqual(source, output)

    def test_existing_rgb_is_byte_identical(self):
        source = png([self.rgb[:9], self.rgb[9:]], 4, colour=2)
        output, qa, _ = post.normalize_png(source)
        self.assertEqual(output, source)
        self.assertEqual(qa['operation'], 'byte_identical_copy')

    def test_color_profile_gamma_physical_and_text_chunks_preserved(self):
        extras = [(b'gAMA', struct.pack('>I', 45455)),
                  (b'cHRM', struct.pack('>8I', 31270, 32900, 64000, 33000, 30000, 60000, 15000, 6000)),
                  (b'iCCP', b'Display P3\0\0' + zlib.compress(b'opaque retained profile bytes')),
                  (b'pHYs', struct.pack('>IIB', 72, 72, 1)),
                  (b'tEXt', b'capture\0native'), (b'sBIT', bytes([8, 8, 8, 8]))]
        output, _, _ = post.normalize_png(png(self.rows, extras=extras))
        chunks = list(post.png_chunks(output))
        for kind, payload in extras[:-1]:
            self.assertIn((kind, payload), chunks)
        self.assertIn((b'sBIT', b'\x08\x08\x08'), chunks)
        output, _, _ = post.normalize_png(png(self.rows, extras=[(b'sRGB', b'\0')]))
        self.assertIn((b'sRGB', b'\0'), list(post.png_chunks(output)))

    def test_unknown_unsafe_metadata_and_reserved_bit_fail_closed(self):
        with self.assertRaisesRegex(ValueError, 'unsafe-to-copy'):
            post.normalize_png(png(self.rows, extras=[(b'vpAG', b'opaque')]))
        output, _, _ = post.normalize_png(png(self.rows, extras=[(b'vpAg', b'opaque')]))
        self.assertIn((b'vpAg', b'opaque'), list(post.png_chunks(output)))
        with self.assertRaisesRegex(ValueError, 'Reserved'):
            post.normalize_png(png(self.rows, extras=[(b'vpag', b'opaque')]))
        source = png([self.rgb[:9], self.rgb[9:]], colour=2, extras=[(b'vpAG', b'opaque')])
        self.assertEqual(post.normalize_png(source)[0], source)

    def test_nonopaque_alpha_fails_instead_of_flattening(self):
        for alpha in [0, 1, 254]:
            rows = list(self.rows)
            row = bytearray(rows[1]); row[-1] = alpha; rows[1] = bytes(row)
            with self.assertRaisesRegex(ValueError, 'Non-opaque'):
                post.normalize_png(png(rows))

    def test_invalid_crc_truncation_chunks_filters_and_deflate_fail(self):
        source = png(self.rows)
        corrupt = bytearray(source); corrupt[-1] ^= 1
        cases = [source[:-1], source + b'x', bytes(corrupt), b'bad',
                 source[:8] + post.chunk(b'ABCD', b'x') + source[8:],
                 png(self.rows, extras=[(b'acTL', b'12345678')]),
                 png(self.rows, extras=[(b'tRNS', b'123456')])]
        header = list(post.png_chunks(source))[0][1]
        for raster in (b'\5' + b'\0' * 12 + b'\0' * 13, b'\0' * 100, b'\0'):
            cases.append(source[:8] + post.chunk(b'IHDR', header) + post.chunk(b'IDAT', zlib.compress(raster)) + post.chunk(b'IEND', b''))
        for invalid in cases:
            with self.subTest(length=len(invalid)), self.assertRaises((ValueError, zlib.error)):
                post.normalize_png(invalid)

    def test_interlacing_and_bit_depth_are_not_guessed(self):
        source = png(self.rows)
        chunks = list(post.png_chunks(source))
        for index, value in [(8, 16), (12, 1)]:
            header = bytearray(chunks[0][1]); header[index] = value
            bad = source[:8] + post.chunk(b'IHDR', header) + b''.join(post.chunk(k, v) for k, v in chunks[1:])
            with self.assertRaisesRegex(ValueError, '8-bit non-interlaced'):
                post.normalize_png(bad)

    def test_deadline_interrupts_pixel_decode(self):
        with self.assertRaises(TimeoutError):
            post.normalize_png(png(self.rows), mock.Mock(side_effect=TimeoutError('deadline')))

    def test_review_sheet_is_small_and_separate(self):
        tile = post.thumbnail(3, 2, self.rgb)
        sheet = post.contact_sheet([('a', tile), ('b', tile)])
        self.assertEqual(post.decode_rgb(sheet)[:2], (300, 100))
        self.assertLess(len(sheet), 2 * 1024 * 1024)


class EvidenceTests(unittest.TestCase):
    def test_fruit_screenshot_identity_matches_capture_recovery(self):
        import capture_ios_simulator as capture
        for media_type in ('image', 'video'):
            for scene in ('home', 'pin', 'fruit', 'liquid'):
                self.assertEqual(post.capture_key('ja', 'ipad_13', scene, media_type),
                                 capture.capture_record_key('ja', 'ipad_13', scene, media_type))
        args, manifest = fixture()
        image = image_record('fruit')
        image['id'] = image['record_key'] = 'ja/iphone_6_9/fruit_screenshot'
        video = dict(image, id='ja/iphone_6_9/fruit', record_key='ja/iphone_6_9/fruit', media_type='video')
        video['scene_ready'] = dict(image['app_evidence'])
        video['gameplay_started'] = dict(image['app_evidence'])
        video['gameplay_complete'] = dict(image['app_evidence'])
        manifest.update(requested_scenes=['fruit'], records=[image, video],
                        required_record_keys=['ja/iphone_6_9/fruit_screenshot', 'ja/iphone_6_9/liquid', 'ja/iphone_6_9/fruit'],
                        remaining_required_scene_keys=['ja/iphone_6_9/liquid'])
        records, _ = post.validate_manifest(manifest, args)
        self.assertEqual(len(records), 2)
        self.assertEqual(len({record['id'] for record in records}), 2)

    def test_matching_partial_capture_is_allowed_but_incomplete(self):
        args, manifest = fixture()
        records, scenes = post.validate_manifest(manifest, args)
        self.assertEqual(len(records), 1)
        self.assertEqual(scenes, ['home'])
        post.validate_screenshot(records[0])

    def test_stale_mismatched_source_run_attempt_and_nonnative_fail(self):
        for key, value in [('origin', 'flutter_preview'), ('app_source_sha', 'c' * 40),
                           ('capture_script_sha', 'c' * 40), ('production_ui_unchanged', False),
                           ('session_loop', False), ('status', 'in_progress'), ('requested_locales', ['ar'])]:
            args, manifest = fixture(); manifest[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                post.validate_manifest(manifest, args)
        for key in ('run_id', 'run_attempt'):
            args, manifest = fixture(); manifest['ci'][key] = '99'
            with self.assertRaisesRegex(ValueError, 'run/attempt'):
                post.validate_manifest(manifest, args)

    def test_duplicate_or_mixed_session_records_fail(self):
        args, manifest = fixture(); manifest['records'] *= 2
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            post.validate_manifest(manifest, args)
        args, manifest = fixture()
        record = dict(manifest['records'][0], id='ja/iphone_6_9/liquid', record_key='ja/iphone_6_9/liquid', scene='liquid',
                      media_type='video', app_evidence={'session_id': 'stale-session'})
        manifest['records'].append(record)
        with self.assertRaisesRegex(ValueError, 'Mixed native sessions'):
            post.validate_manifest(manifest, args)

    def test_nested_video_sessions_cannot_hide_behind_redundant_evidence(self):
        args, manifest = fixture()
        video = dict(manifest['records'][0], id='ja/iphone_6_9/liquid', record_key='ja/iphone_6_9/liquid',
                     scene='liquid', media_type='video')
        video['app_evidence'] = {'session_id': 'same-session', 'launch_id': 'same-session'}
        video['gameplay_complete'] = dict(video['app_evidence'])
        video['scene_ready'] = {'session_id': 'different', 'launch_id': 'different'}
        video['gameplay_started'] = dict(video['scene_ready'])
        manifest['records'].append(video)
        with self.assertRaisesRegex(ValueError, 'Nested native evidence'):
            post.validate_manifest(manifest, args)
        video['scene_ready'] = dict(video['app_evidence'])
        video['gameplay_started'] = dict(video['app_evidence'])
        video['gameplay_complete']['phase'] = 'play'
        with self.assertRaisesRegex(ValueError, 'differs from completion'):
            post.validate_manifest(manifest, args)

    def test_native_device_tuple_cannot_mix(self):
        for field in ('device_udid', 'runtime', 'device_name'):
            args, manifest = fixture()
            video = dict(manifest['records'][0], id='ja/iphone_6_9/liquid', record_key='ja/iphone_6_9/liquid',
                         scene='liquid', media_type='video')
            video[field] = 'another-device'
            manifest['records'].append(video)
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, 'device identity'):
                post.validate_manifest(manifest, args)

    def test_gameplay_before_and_after_guards_reused(self):
        record = image_record('pin'); post.validate_screenshot(record)
        for key, value in [('phase', 'done'), ('scene_request_id', 'old'), ('session_id', 'old'),
                           ('native_simulator_attested', False), ('game_time', 0), ('request_id', 'inspect-2'), ('at', '2026-10-06T00:00:00Z')]:
            bad = copy.deepcopy(record); bad['app_evidence_after_screenshot'][key] = value
            with self.subTest(key=key), self.assertRaises((ValueError, RuntimeError)):
                post.validate_screenshot(bad)

    def test_protected_git_object_guard(self):
        completed = mock.Mock(stdout='\n'.join(post.PROTECTED_OBJECTS.values()))
        with mock.patch.object(post.subprocess, 'run', return_value=completed):
            self.assertEqual(post.verify_protected_objects('a' * 40), post.PROTECTED_OBJECTS)
        with mock.patch.object(post.subprocess, 'run', return_value=mock.Mock(stdout='wrong')):
            with self.assertRaisesRegex(ValueError, 'production tree'):
                post.verify_protected_objects('a' * 40)

    def test_process_group_timeout_kills_even_if_leader_exits(self):
        process = mock.Mock(pid=1234)
        process.wait.side_effect = [subprocess.TimeoutExpired('encoder', 5), 0, 0]
        with tempfile.TemporaryDirectory() as folder, mock.patch.object(post.subprocess, 'Popen', return_value=process), \
                mock.patch.object(post.os, 'killpg') as kill:
            with self.assertRaises(TimeoutError):
                post.run_bounded(['encoder'], pathlib.Path(folder) / 'log', 10)
        self.assertEqual([call.args[1] for call in kill.call_args_list], [post.signal.SIGTERM, post.signal.SIGKILL])

    def test_early_failure_success_and_cancellation_always_clean_group(self):
        for outcome in (7, 0, post.ProcessingInterrupted(post.signal.SIGTERM)):
            process = mock.Mock(pid=1234)
            process.wait.side_effect = [outcome, 0, 0]
            with tempfile.TemporaryDirectory() as folder, \
                    mock.patch.object(post.subprocess, 'Popen', return_value=process), \
                    mock.patch.object(post.os, 'killpg') as kill:
                if outcome == 0:
                    post.run_bounded(['encoder'], pathlib.Path(folder) / 'log', 10)
                else:
                    with self.assertRaises((ValueError, post.ProcessingInterrupted)):
                        post.run_bounded(['encoder'], pathlib.Path(folder) / 'log', 10)
            self.assertEqual([call.args[1] for call in kill.call_args_list], [post.signal.SIGTERM, post.signal.SIGKILL])

    def test_cancellation_during_cleanup_still_kills_and_reaps(self):
        process = mock.Mock(pid=1234)
        process.wait.side_effect = [post.ProcessingInterrupted(post.signal.SIGTERM), 0]
        with mock.patch.object(post.os, 'killpg') as kill:
            with self.assertRaises(post.ProcessingInterrupted):
                post.stop_process_group(process)
        self.assertEqual([call.args[1] for call in kill.call_args_list], [post.signal.SIGTERM, post.signal.SIGKILL])
        self.assertEqual(process.wait.call_count, 2)

    def test_real_early_leader_exit_leaves_no_live_descendant(self):
        for returncode in (0, 7):
            child = 'import subprocess,sys; p=subprocess.Popen([sys.executable,"-c","import time; time.sleep(30)"]); print(p.pid,flush=True); sys.exit(' + str(returncode) + ')'
            with tempfile.TemporaryDirectory() as folder:
                log = pathlib.Path(folder) / 'process.log'
                if returncode:
                    with self.assertRaises(ValueError):
                        post.run_bounded([sys.executable, '-c', child], log, 10)
                else:
                    post.run_bounded([sys.executable, '-c', child], log, 10)
                pid = int(log.read_text().strip())
                state = subprocess.run(['ps', '-o', 'stat=', '-p', str(pid)], capture_output=True, text=True, timeout=5).stdout.strip()
                self.assertTrue(not state or state.startswith('Z'), state)

    def test_result_counts_hashes_and_original_retention(self):
        args, manifest = fixture()
        data = png([b'\x10\x20\x30\xff'])
        record = manifest['records'][0]
        record.update(sha256=post.sha(data), dimensions=[1, 1])
        with tempfile.TemporaryDirectory() as folder:
            folder = pathlib.Path(folder); raw = folder / 'raw'; raw.mkdir()
            (raw / 'home.png').write_bytes(data)
            source = raw / 'manifest.json'; source.write_text(json.dumps(manifest))
            argv = ['--manifest', str(source), '--output-root', str(folder / 'derived'), '--locales', 'ja',
                    '--device', 'iphone_6_9', '--app-source-sha', args.app_source_sha,
                    '--capture-source-sha', args.capture_source_sha, '--production-base-sha', post.PRODUCTION_BASE,
                    '--run-id', '123', '--run-attempt', '1', '--raw-artifact-name', 'same-run-raw']
            with mock.patch.dict(post.DIMENSIONS, {'iphone_6_9': {(1, 1)}}), \
                    mock.patch.object(post, 'verify_protected_objects', return_value=post.PROTECTED_OBJECTS):
                self.assertEqual(post.main(argv), 1)  # No video; never claim completion.
            result = json.loads((folder / 'derived/results.json').read_text())
            self.assertEqual(result['locales']['ja']['accepted_screenshots'], 1)
            self.assertEqual(result['locales']['ja']['preview_status'], 'rejected_or_deferred')
            item = result['records'][0]
            self.assertEqual(item['original_sha256'], post.sha(data))
            self.assertEqual(item['output_sha256'], post.sha((folder / 'derived' / item['output_relative_path']).read_bytes()))
            self.assertEqual((raw / 'home.png').read_bytes(), data)
            self.assertEqual(source.read_text(), json.dumps(manifest))
            self.assertEqual(result['human_pixel_review'], 'pending')
            self.assertEqual(result['source']['capture_status'], 'partial_deadline')
            self.assertNotEqual(result['source']['production_base_sha'], result['source']['capture_source_sha'])
            with self.assertRaises(FileExistsError):
                post.main(argv)
            argv[argv.index('--output-root') + 1] = str(folder / 'canceled')
            old = post.signal.getsignal(post.signal.SIGTERM)
            def cancel(_):
                post.os.kill(post.os.getpid(), post.signal.SIGTERM)
            with mock.patch.object(post, 'verify_protected_objects', side_effect=cancel):
                self.assertEqual(post.main(argv), 128 + post.signal.SIGTERM)
            canceled = json.loads((folder / 'canceled/results.json').read_text())
            self.assertEqual(canceled['status'], 'interrupted')
            self.assertEqual(post.signal.getsignal(post.signal.SIGTERM), old)
            argv[argv.index('--output-root') + 1] = str(folder / 'canceled-during-image')
            with mock.patch.object(post, 'verify_protected_objects', return_value=post.PROTECTED_OBJECTS), \
                    mock.patch.object(post, 'validate_screenshot', side_effect=cancel):
                self.assertEqual(post.main(argv), 128 + post.signal.SIGTERM)
            canceled = json.loads((folder / 'canceled-during-image/results.json').read_text())
            self.assertEqual(canceled['status'], 'interrupted')
            self.assertEqual(canceled['records'][0]['status'], 'interrupted')
            self.assertEqual(canceled['locales']['ja']['remaining_screenshot_ids'], ['ja/iphone_6_9/home'])
            self.assertEqual(canceled['locales']['ja']['accepted_screenshots'], 0)
            self.assertEqual(canceled['locales']['ja']['rejected_screenshots'], 1)


class WorkflowTests(unittest.TestCase):
    def test_separate_standard_same_run_job_has_upload_reserve(self):
        workflow = (ROOT.parents[1] / '.github/workflows/ios-check.yml').read_text()
        job = workflow.split('  native-media-candidates:\n', 1)[1].split('  rewarded-qa-build:\n', 1)[0]
        for expected in ('needs: native-all-media', 'runs-on: ubuntu-24.04', 'max-parallel: 4',
                         'timeout-minutes: 20', 'timeout-minutes: 11', '--work-seconds 600',
                         'retention-days: 7', 'contents: read', 'actions: read',
                         'github.event.repository.private == false', 'if: always()',
                         'actions/download-artifact@v4', 'hitasura-native-media-${{ matrix.chunk.id }}-${{ matrix.device }}'):
            self.assertIn(expected, job)
        import re
        choices = re.findall(r"'(\[\{[^']+\}\])'", job)
        self.assertEqual(json.loads(choices[0]), [{'id': 'ja-ar', 'locales': 'ja,ar'}])
        self.assertEqual(len(json.loads(choices[1])), 10)
        capture = workflow.split('  native-all-media:\n', 1)[1].split('  native-media-candidates:\n', 1)[0]
        self.assertEqual(choices, re.findall(r"'(\[\{[^']+\}\])'", capture))
        self.assertNotIn('run-id:', job)  # download-artifact defaults to this run, never arbitrary old run.
        self.assertNotIn('contents: write', job)
        self.assertNotIn('secrets.', job)
        self.assertNotIn('brew install', job)
        self.assertNotIn('pip install', job)
        self.assertIn('timeout-minutes: 2', job.split('Retain candidate media', 1)[1])

    def test_source_traversal_and_duplicate_json_are_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            folder = pathlib.Path(folder)
            for path in ('../outside.mov', '/outside.mov'):
                with self.assertRaises(ValueError):
                    post.encoder.source_path(folder, path)
            source = folder / 'manifest.json'; source.write_text('{"origin": 1, "origin": 2}')
            with self.assertRaisesRegex(ValueError, 'Duplicate JSON'):
                post.load_json(source)


if __name__ == '__main__':
    unittest.main()
