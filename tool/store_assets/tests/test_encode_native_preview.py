import copy
import importlib.util
import json
import pathlib
import struct
import subprocess
import tempfile
import unittest
import zlib
from unittest import mock


spec = importlib.util.spec_from_file_location(
    'encoder', pathlib.Path(__file__).parents[1] / 'encode_native_preview.py')
encoder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(encoder)


def output_probe():
    return {
        'streams': [
            {'index': 0, 'codec_type': 'video', 'codec_name': 'h264', 'profile': 'High',
             'level': 40, 'width': 886, 'height': 1920, 'pix_fmt': 'yuv420p',
             'field_order': 'progressive', 'sample_aspect_ratio': '1:1',
             'avg_frame_rate': '30/1', 'r_frame_rate': '30/1', 'nb_read_frames': '600',
             'nb_frames': '600', 'duration': '20.000000', 'start_time': '0.000000',
             'bit_rate': '11000000'},
            {'index': 1, 'codec_type': 'audio', 'codec_name': 'aac',
             'sample_rate': '48000', 'channels': 2, 'channel_layout': 'stereo',
             'disposition': {'default': 1}, 'bit_rate': '256000',
             'duration': '20.000000', 'start_time': '0.000000'},
        ],
        'format': {'duration': '20.000000', 'format_name': 'mov,mp4,m4a,3gp,3g2,mj2'},
        'packets': [{'stream_index': 0, 'dts_time': str((i - 2) / 30),
                     'pts_time': str(i / 30), 'duration_time': str(1 / 30)} for i in range(600)] +
                   [{'stream_index': 1, 'dts_time': str((i - 1) * 1024 / 48000),
                     'pts_time': str((i - 1) * 1024 / 48000),
                     'duration_time': str(1024 / 48000)} for i in range(939)],
    }


class GeometryTests(unittest.TestCase):
    def test_phone_padding_preserves_every_pixel_and_uniform_scale(self):
        geometry = encoder.geometry_for('iphone_6_9', 1320, 2868)
        self.assertEqual(geometry['padding_pixels'], {'left': 4, 'right': 5, 'top': 6, 'bottom': 6})
        self.assertEqual(geometry['padded_dimensions'], [1329, 2880])
        self.assertEqual(geometry['uniform_scale'], '2/3')
        self.assertEqual(geometry['output_dimensions'], [886, 1920])
        self.assertEqual(encoder.geometry_filter(geometry),
                         'format=gbrp,pad=1329:2880:4:6:black,scale=886:1920:flags=lanczos,setsar=1,format=yuv420p')

    def test_both_ipad_mappings_are_exact(self):
        ordinary = encoder.geometry_for('ipad_13', 2064, 2752)
        fallback = encoder.geometry_for('ipad_13', 2048, 2732)
        self.assertEqual(ordinary['uniform_scale'], '25/43')
        self.assertEqual(fallback['uniform_scale'], '400/683')
        self.assertEqual(fallback['padding_pixels']['right'], 1)
        self.assertEqual(fallback['padded_dimensions'], [2049, 2732])

    def test_other_geometry_or_device_group_fails_closed(self):
        for device, width, height in [('iphone_6_9', 1290, 2796), ('ipad_13', 1320, 2868),
                                      ('other', 1320, 2868), ('iphone_6_9', 2868, 1320)]:
            with self.subTest(device=device, width=width, height=height):
                with self.assertRaisesRegex(encoder.PreviewError, 'Unreviewed geometry'):
                    encoder.geometry_for(device, width, height)


class CommandTests(unittest.TestCase):
    def segments(self):
        return [{'scene': scene, 'game_id': game, 'path': f'/raw media/{scene}.mov',
                 'trim_start_seconds': 1.25,
                 'geometry': encoder.geometry_for('iphone_6_9', 1320, 2868)}
                for scene, game in encoder.SCENES]

    def command(self, **kwargs):
        return encoder.build_ffmpeg_command(self.segments(), '/music/cute.mp3', '/output/test.mp4', **kwargs)

    def test_one_process_with_two_sources_one_bed_and_plain_cut(self):
        command = self.command()
        self.assertEqual(command.count('-i'), 3)
        self.assertIn('/raw media/liquid.mov', command)
        filters = command[command.index('-filter_complex') + 1]
        self.assertIn('trim=start=1.250000000:duration=10', filters)
        self.assertEqual(filters.count('trim=end_frame=300'), 2)
        self.assertIn('[v0][v1]concat=n=2:v=1:a=0[video]', filters)
        self.assertNotIn('xfade', filters)
        self.assertNotIn('minterpolate', filters)
        self.assertNotIn('crop', filters)
        self.assertIn('not live-recorded audio', command[-2])
        self.assertNotIn('-y', command)

    def test_exact_codec_and_thread_limits(self):
        command = self.command(threads=1)
        for key, value in {'-profile:v': 'high', '-level:v': '4.0', '-b:v': '11M',
                           '-minrate:v': '11M', '-maxrate:v': '11M', '-frames:v': '600', '-ar': '48000',
                           '-b:a': '256k', '-threads:v': '1', '-filter_complex_threads': '1'}.items():
            self.assertEqual(command[command.index(key) + 1], value)
        self.assertIn('nal-hrd=vbr:filler=1:force-cfr=1', command)
        self.assertNotIn('nal-hrd=cbr', ' '.join(command))
        for threads in (0, 3, 8):
            with self.assertRaises(encoder.PreviewError):
                self.command(threads=threads)

    def test_wrong_scene_order_count_and_container_rejected(self):
        segments = self.segments()
        for bad in (segments[::-1], segments[:1], segments + segments):
            with self.assertRaises(encoder.PreviewError):
                encoder.build_ffmpeg_command(bad, 'cute.mp3', 'output.mp4')
        with self.assertRaises(encoder.PreviewError):
            encoder.build_ffmpeg_command(segments, 'cute.mp3', 'output.mov')

    def test_probe_is_bounded_and_collects_decoded_frames_and_packet_timestamps(self):
        with mock.patch.object(encoder.subprocess, 'run', return_value=mock.Mock(stdout='{}')) as run:
            encoder.probe_media('sample.mp4', full=True)
        self.assertEqual(run.call_args.kwargs['timeout'], 180)
        command = run.call_args.args[0]
        self.assertIn('-count_frames', command)
        self.assertIn('-show_packets', command)


class ProbeTests(unittest.TestCase):
    def validate(self, probe):
        return encoder.validate_output_probe(probe, [886, 1920], 28_000_000)

    def test_success_keeps_visual_review_and_asc_pending(self):
        result = self.validate(output_probe())
        self.assertEqual(result['status'], 'passed')
        self.assertEqual(result['human_pixel_review'], 'pending')
        self.assertEqual(result['asc_processing'], 'not_tested')

    def test_output_failures_are_not_silently_normalized(self):
        changes = {'codec_name': 'hevc', 'profile': 'Main', 'level': 41, 'width': 888,
                   'height': 1918, 'pix_fmt': 'yuv444p', 'field_order': 'tt',
                   'sample_aspect_ratio': '4:3', 'avg_frame_rate': '30000/1001',
                   'r_frame_rate': '60/1', 'nb_read_frames': '599', 'nb_frames': '601',
                   'duration': '19.9', 'start_time': '0.1', 'bit_rate': '12000001'}
        for field, value in changes.items():
            with self.subTest(field=field):
                probe = output_probe()
                probe['streams'][0][field] = value
                with self.assertRaises(encoder.PreviewError):
                    self.validate(probe)

    def test_unproven_or_out_of_range_audio_fails(self):
        for field, value in {'codec_name': 'mp3', 'channels': 1, 'sample_rate': '44100',
                             'channel_layout': 'mono', 'bit_rate': '9000', 'duration': '18',
                             'disposition': {'default': 0}}.items():
            with self.subTest(field=field):
                probe = output_probe()
                probe['streams'][1][field] = value
                with self.assertRaises(encoder.PreviewError):
                    self.validate(probe)

    def test_missing_or_nonmonotonic_timestamps_fail(self):
        probe = output_probe()
        probe['packets'][1]['dts_time'] = probe['packets'][0]['dts_time']
        with self.assertRaisesRegex(encoder.PreviewError, 'strictly increase'):
            self.validate(probe)
        probe = output_probe()
        probe['packets'][1]['pts_time'] = 'nan'
        with self.assertRaisesRegex(encoder.PreviewError, 'Non-finite'):
            self.validate(probe)
        probe = output_probe()
        del probe['packets']
        with self.assertRaisesRegex(encoder.PreviewError, 'timestamps are required'):
            self.validate(probe)

    def test_source_interval_and_geometry_are_verified(self):
        probe = output_probe()
        probe['streams'][0].update(width=1320, height=2868, duration='11.3')
        self.assertEqual(encoder.validate_source_probe(probe, 'iphone_6_9', 1.25)['uniform_scale'], '2/3')
        for field, value in [('duration', '11.24'), ('sample_aspect_ratio', '0:1'),
                              ('width', 1290), ('start_time', '0.25'),
                              ('side_data_list', [{'rotation': 90}])]:
            with self.subTest(field=field):
                bad = copy.deepcopy(probe)
                bad['streams'][0][field] = value
                with self.assertRaises(encoder.PreviewError):
                    encoder.validate_source_probe(bad, 'iphone_6_9', 1.25)

    def test_freeze_and_black_diagnostics_do_not_claim_visual_approval(self):
        result = encoder.visual_diagnostics('[freezedetect] freeze_start: 1\n'
                                            '[blackdetect] black_start: 3 black_end: 5\nnormal log')
        self.assertEqual(len(result['events']), 2)
        self.assertEqual(result['status'], 'requires_human_review')


def capture_record(scene, game_no):
    base = {'session_id': 'native-session', 'launch_id': 'native-session', 'locale': 'en',
            'requested_scene': scene, 'active_scene': scene, 'game_no': game_no,
            'phase': 'play', 'native_simulator_attested': True, 'debug_mode': True, 'is_ios': True}
    ready = dict(base, stage='ready', action='show', request_id=f'show-{scene}',
                 ready_at='2026-10-02T12:00:00Z', game_time=1, time_left=19)
    started = dict(base, stage='gameplay_started', action='record_start', request_id=f'record-{scene}',
                   started_at='2026-10-02T12:00:01.5Z', game_time=2, duration_seconds=10,
                   input_method='flutter_gesture_binding_pointer_events', random_seed='shipping_time_seed_unmodified')
    complete = dict(started, stage='gameplay_complete', completed_at='2026-10-02T12:00:11.52Z',
                    elapsed_seconds=10.02, game_time_start=2, game_time_end=12.02,
                    score_observed=0, input_events=[
                        {'kind': kind, 'pointer': 7, 'virtual_xy': [60, 200], 'global_logical_xy': [50, 180],
                         'scheduled_seconds': elapsed - .01, 'actual_elapsed_seconds': elapsed, 'game_time': 2 + elapsed}
                        for kind, elapsed in [('down', .2), ('up', .3)]])
    return {'id': f'en/iphone_6_9/{scene}', 'record_key': f'en/iphone_6_9/{scene}',
            'locale': 'en', 'device_group': 'iphone_6_9', 'scene': scene, 'media_type': 'video',
            'game_no': game_no, 'device_udid': 'native-udid', 'device_name': 'iPhone 17 Pro Max',
            'runtime': 'com.apple.CoreSimulator.SimRuntime.iOS-26-2',
            'relative_path': f'{scene}.mov', 'sha256': None, 'dimensions': [1320, 2868],
            'dimension_source': 'native_screenshot_same_session',
            'scene_ready': ready, 'gameplay_started': started, 'gameplay_complete': complete,
            'recorder': {'process_started_utc': '2026-10-02T12:00:01Z',
                         'ack_observed_utc': '2026-10-02T12:00:01.2Z',
                         'command_sent_utc': '2026-10-02T12:00:01.3Z',
                         'stopped_utc': '2026-10-02T12:00:12Z', 'recording_acknowledged': True,
                         'process_started_monotonic': 100, 'ack_observed_monotonic': 100.2,
                         'ack_log': f'{scene}.log'},
            'trim_start_seconds': .3, 'trim_duration_seconds': 10,
            'trim_basis': 'conservative_ack_anchored_play_window', 'recording_start_uncertainty_seconds': .2}


class EvidenceTests(unittest.TestCase):
    def validate(self, record):
        return encoder.validate_record_evidence(record, 'en', 'iphone_6_9', 'liquid', 'G003')

    def test_acknowledged_active_interval_is_accepted(self):
        self.assertEqual(self.validate(capture_record('liquid', 3)), .3)

    def test_stale_mismatched_early_or_nonnative_evidence_fails(self):
        mutations = [
            ('scene_ready', 'locale', 'ja'), ('gameplay_started', 'request_id', 'show-liquid'),
            ('gameplay_complete', 'request_id', 'stale'), ('gameplay_complete', 'session_id', 'stale'),
            ('gameplay_complete', 'phase', 'result'), ('gameplay_complete', 'elapsed_seconds', 9.9),
            ('gameplay_complete', 'game_time_end', 2.1), ('gameplay_complete', 'input_events', []),
            ('gameplay_started', 'native_simulator_attested', False),
            ('gameplay_started', 'random_seed', 'chosen-winning-seed'),
            ('recorder', 'recording_acknowledged', False),
            ('recorder', 'command_sent_utc', '2026-10-02T12:00:00.5Z'),
        ]
        for section, key, value in mutations:
            with self.subTest(section=section, key=key):
                record = capture_record('liquid', 3)
                record[section][key] = value
                with self.assertRaises(encoder.PreviewError):
                    self.validate(record)

    def test_forged_trim_and_wrong_geometry_evidence_fail(self):
        for key, value in [('trim_start_seconds', 0), ('trim_start_seconds', 1),
                           ('trim_duration_seconds', 9), ('recording_start_uncertainty_seconds', 0),
                           ('game_no', 8), ('record_key', 'en/iphone_6_9/fruit')]:
            with self.subTest(key=key, value=value):
                record = capture_record('liquid', 3)
                record[key] = value
                with self.assertRaises(encoder.PreviewError):
                    self.validate(record)

    def test_incomplete_outside_or_unordered_pointer_journal_fails(self):
        for key, value in [('kind', 'move'), ('virtual_xy', [361, 100]),
                           ('actual_elapsed_seconds', 20), ('game_time', 1),
                           ('scheduled_seconds', 4)]:
            with self.subTest(key=key):
                record = capture_record('liquid', 3)
                record['gameplay_complete']['input_events'][0][key] = value
                with self.assertRaises(encoder.PreviewError):
                    self.validate(record)
        record = capture_record('liquid', 3)
        record['gameplay_complete']['input_events'].pop()
        with self.assertRaisesRegex(encoder.PreviewError, 'left pressed'):
            self.validate(record)


class PlanAndExecutionTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = pathlib.Path(self.directory.name)
        self.records = [capture_record('liquid', 3), capture_record('fruit', 8)]
        for record in self.records:
            raw = self.root / record['relative_path']
            raw.write_bytes(f"mock native source {record['scene']}".encode())
            record['sha256'] = encoder.sha256_file(raw)
            (self.root / record['recorder']['ack_log']).write_text('Recording started\n')
        self.manifest = {'origin': 'native_ios_simulator', 'production_ui_unchanged': True,
                         'app_source_sha': 'a' * 40, 'capture_script_sha': 'b' * 40,
                         'fixture': 'declared seeded local progress', 'ci': {'run_id': '123', 'job': 'native'},
                         'status': 'checkpointed_incomplete', 'records': self.records}
        self.manifest_path = self.root / 'capture.json'
        self.write_manifest()
        self.audio_path = pathlib.Path(__file__).parents[3] / 'assets/audio/bgm/cute.mp3'
        self.output = self.root / 'final.mp4'

    def write_manifest(self):
        self.manifest_path.write_text(json.dumps(self.manifest))

    def source_probe(self, path, **kwargs):
        probe = output_probe()
        if pathlib.Path(path).suffix == '.mp3':
            return {'streams': [dict(probe['streams'][1], duration='30.040816')]}
        return {'streams': [dict(probe['streams'][0], width=1320, height=2868, duration='12')]}

    def plan(self):
        return encoder.build_plan(self.manifest_path, [r['id'] for r in self.records], self.output,
                                  self.audio_path, probe=self.source_probe)

    def add_native_png_witness(self):
        record = self.records[0]
        def chunk(kind, payload):
            return struct.pack('>I', len(payload)) + kind + payload + struct.pack('>I', zlib.crc32(kind + payload) & 0xffffffff)
        data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 1320, 2868, 8, 2, 0, 0, 0))
        data += chunk(b'IDAT', zlib.compress((b'\x00' + b'\x00' * 3960) * 2868)) + chunk(b'IEND', b'')
        path = self.root / 'native_home.png'; path.write_bytes(data)
        witness = {**record, 'id': 'ja/iphone_6_9/home', 'scene': 'home', 'media_type': 'image',
            'relative_path': 'native_home.png', 'sha256': encoder.sha256_file(path),
            'app_evidence': {**record['scene_ready'], 'active_scene': 'home', 'requested_scene': 'home'}}
        self.manifest['records'] = [*self.records, witness]; self.write_manifest()
        return witness

    def missing_sar_plan(self):
        def probe(path, **kwargs):
            value = self.source_probe(path, **kwargs)
            if pathlib.Path(path).suffix != '.mp3': value['streams'][0].pop('sample_aspect_ratio')
            return value
        return encoder.build_plan(self.manifest_path, [r['id'] for r in self.records], self.output,
                                  self.audio_path, probe=probe)

    def test_missing_native_sar_requires_verified_same_session_png(self):
        with self.assertRaisesRegex(encoder.PreviewError, 'PNG witness'):
            self.missing_sar_plan()
        witness = self.add_native_png_witness()
        plan = self.missing_sar_plan()
        self.assertEqual(plan['segments'][0]['native_pixel_witness']['sha256'], witness['sha256'])
        self.assertIsNone(plan['segments'][0]['geometry']['source_pixel_aspect_ratio']['reported'])
        self.assertEqual(plan['segments'][0]['geometry']['source_pixel_aspect_ratio']['resolved'], '1:1')

    def test_missing_sar_rejects_wrong_session_and_corrupt_witness(self):
        witness = self.add_native_png_witness()
        witness['app_evidence']['session_id'] = 'other'; self.write_manifest()
        with self.assertRaisesRegex(encoder.PreviewError, 'PNG witness'):
            self.missing_sar_plan()
        witness = self.add_native_png_witness()
        path = self.root / witness['relative_path']; path.write_bytes(path.read_bytes()[:-1])
        witness['sha256'] = encoder.sha256_file(path); self.write_manifest()
        with self.assertRaisesRegex(encoder.PreviewError, 'PNG witness'):
            self.missing_sar_plan()

    def test_explicit_anamorphic_sar_is_never_overridden_by_native_witness(self):
        self.add_native_png_witness()
        witness = encoder.native_png_witness(self.manifest, self.records[0], self.root)
        probe = self.source_probe(self.root / self.records[0]['relative_path'])
        probe['streams'][0]['sample_aspect_ratio'] = '2:1'
        with self.assertRaisesRegex(encoder.PreviewError, 'square'):
            encoder.validate_source_probe(probe, 'iphone_6_9', 1.3, witness)

    def test_plan_preserves_complete_provenance_and_audio_separation(self):
        plan = self.plan()
        self.assertEqual(plan['status'], 'planned_not_encoded')
        self.assertEqual(plan['capture_provenance']['ci'], self.manifest['ci'])
        self.assertEqual(plan['segments'][0]['capture_evidence'], self.records[0])
        self.assertEqual(plan['segments'][0]['sha256'], self.records[0]['sha256'])
        self.assertFalse(plan['audio']['live_recorded'])
        self.assertEqual(plan['audio']['source_sha256'], encoder.AUDIO_SHA256)
        bounds = plan['segments'][0]['trim_interval_utc_bounds']
        self.assertIn('12:00:01.300000', bounds['start_earliest'])
        self.assertIn('12:00:01.500000', bounds['start_latest'])
        self.assertFalse(self.output.exists())

    def test_wrong_hash_missing_record_and_non_native_manifest_fail(self):
        for change in ('hash', 'duplicate', 'origin', 'dimensions'):
            with self.subTest(change=change):
                manifest = copy.deepcopy(self.manifest)
                if change == 'hash':
                    manifest['records'][0]['sha256'] = '0' * 64
                elif change == 'duplicate':
                    manifest['records'].append(manifest['records'][0])
                elif change == 'origin':
                    manifest['origin'] = 'flutter_test_production_widgets'
                else:
                    manifest['records'][0]['dimensions'] = [1290, 2796]
                self.manifest_path.write_text(json.dumps(manifest))
                with self.assertRaises(encoder.PreviewError):
                    self.plan()

    def test_sources_cannot_escape_capture_artifact(self):
        self.records[0]['relative_path'] = '../outside.mov'
        self.write_manifest()
        with self.assertRaisesRegex(encoder.PreviewError, 'inside its capture artifact'):
            self.plan()

    def test_output_and_log_paths_cannot_overwrite_acknowledgment_evidence(self):
        for relative_path in ('final.mp4', 'final.manifest.json', 'final.encode.log', 'final.decode.log'):
            with self.subTest(relative_path=relative_path):
                self.records[0]['recorder']['ack_log'] = relative_path
                (self.root / relative_path).write_text('Recording started\n')
                self.write_manifest()
                with self.assertRaisesRegex(encoder.PreviewError, 'would overwrite an input'):
                    self.plan()

    def test_source_mutation_after_plan_is_detected_before_encode(self):
        plan = self.plan()
        (self.root / 'liquid.mov').write_bytes(b'changed')
        with mock.patch.object(encoder.subprocess, 'run') as run:
            with self.assertRaisesRegex(encoder.PreviewError, 'changed after planning'):
                encoder.execute_plan(plan)
        run.assert_not_called()

    def run_process(self, command, **kwargs):
        if '-version' in command:
            return subprocess.CompletedProcess(command, 0, stdout='ffmpeg test version\n')
        if '-filter_complex' in command:
            pathlib.Path(command[-1]).write_bytes(b'encoded fixture, not real media')
        return subprocess.CompletedProcess(command, 0, stdout='', stderr='decode complete\n')

    def test_successful_single_encode_and_hash_verified_resume(self):
        plan = self.plan()
        with mock.patch.object(encoder.subprocess, 'run', side_effect=self.run_process) as run, \
                mock.patch.object(encoder, 'probe_media', return_value=output_probe()):
            result = encoder.execute_plan(plan)
        self.assertEqual(sum('-filter_complex' in call.args[0] for call in run.call_args_list), 1)
        self.assertEqual(result['status'], 'technical_passed_pending_human_review')
        self.assertEqual(result['output_sha256'], encoder.sha256_file(self.output))
        self.assertEqual(result['decode_status'], 'passed')
        with mock.patch.object(encoder.subprocess, 'run') as run:
            self.assertEqual(encoder.execute_plan(plan, resume=True), result)
            run.assert_not_called()
        self.output.write_bytes(b'tampered')
        with self.assertRaisesRegex(encoder.PreviewError, 'safely resumed'):
            encoder.execute_plan(plan, resume=True)

    def test_failed_encode_keeps_partial_evidence_and_can_resume_without_overwrite(self):
        plan = self.plan()
        def fail(command, **kwargs):
            result = self.run_process(command, **kwargs)
            if '-filter_complex' in command:
                raise subprocess.CalledProcessError(1, command)
            return result
        with mock.patch.object(encoder.subprocess, 'run', side_effect=fail):
            with self.assertRaises(subprocess.CalledProcessError):
                encoder.execute_plan(plan)
        failed = json.loads(self.output.with_suffix('.manifest.json').read_text())
        self.assertEqual(failed['status'], 'failed')
        self.assertTrue(pathlib.Path(failed['partial_output_path']).is_file())
        self.assertFalse(self.output.exists())
        with mock.patch.object(encoder.subprocess, 'run', side_effect=self.run_process), \
                mock.patch.object(encoder, 'probe_media', return_value=output_probe()):
            result = encoder.execute_plan(plan, resume=True)
        self.assertTrue(pathlib.Path(failed['partial_output_path']).is_file())
        self.assertTrue(list(self.root.glob('*.previous-*.json')))
        self.assertEqual(result['status'], 'technical_passed_pending_human_review')

    def test_bad_probe_never_promotes_partial_to_final(self):
        probe = output_probe()
        probe['streams'][0]['nb_read_frames'] = '599'
        with mock.patch.object(encoder.subprocess, 'run', side_effect=self.run_process), \
                mock.patch.object(encoder, 'probe_media', return_value=probe):
            with self.assertRaisesRegex(encoder.PreviewError, '600 decoded'):
                encoder.execute_plan(self.plan())
        self.assertFalse(self.output.exists())

    def test_decode_failure_never_promotes_partial_to_final(self):
        def fail(command, **kwargs):
            result = self.run_process(command, **kwargs)
            if '-xerror' in command:
                return subprocess.CompletedProcess(command, 1, stdout='', stderr='decode error')
            return result
        with mock.patch.object(encoder.subprocess, 'run', side_effect=fail), \
                mock.patch.object(encoder, 'probe_media', return_value=output_probe()):
            with self.assertRaises(subprocess.CalledProcessError):
                encoder.execute_plan(self.plan())
        self.assertFalse(self.output.exists())
        self.assertEqual(next(self.root.glob('*.decode.log')).read_text(), 'decode error')


if __name__ == '__main__':
    unittest.main()
