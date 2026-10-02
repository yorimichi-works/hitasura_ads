import 'package:flutter_test/flutter_test.dart';

import '../tool/store_assets/capture_request.dart';

void main() {
  final now = DateTime.utc(2026, 10, 2, 17);
  Map<String, dynamic> request() => {
    'schema_version': 1,
    'launch_id': 'c1a9a9ab-3fb1-4300-a6f6-1ca22950679d',
    'locale': 'en',
    'scene': 'home',
    'created_at': now.toIso8601String(),
  };

  test('valid fixed-path request preserves identity and locale', () {
    final parsed = CaptureRequest.parse(request(), now: now);
    expect(parsed.launchId, request()['launch_id']);
    expect(parsed.locale, 'en');
    expect(parsed.scene, 'home');
    expect(parsed.createdAt, now);
  });

  test('all supported locales and scenes are accepted', () {
    for (final locale in CaptureRequest.locales) {
      for (final scene in CaptureRequest.scenes) {
        final value = request()..addAll({'locale': locale, 'scene': scene});
        expect(CaptureRequest.parse(value, now: now).locale, locale);
      }
    }
  });

  test('missing keys, arbitrary paths and simulator claims are rejected', () {
    for (final key in request().keys) {
      expect(
        () => CaptureRequest.parse(request()..remove(key), now: now),
        throwsFormatException,
      );
    }
    for (final key in ['state_path', 'documentsPath', 'isSimulator']) {
      expect(
        () => CaptureRequest.parse(request()..[key] = true, now: now),
        throwsFormatException,
      );
    }
  });

  test('unsupported schema, locale, scene and UUID fail closed', () {
    for (final change in [
      {'schema_version': 2},
      {'schema_version': 1.0},
      {'locale': 'unknown'},
      {'scene': '../home'},
      {'launch_id': 'stale'},
      {'launch_id': 'c1a9a9ab-3fb1-1300-a6f6-1ca22950679d'},
    ]) {
      expect(
        () => CaptureRequest.parse(request()..addAll(change), now: now),
        throwsFormatException,
      );
    }
  });

  test('expired, future and non-UTC requests fail closed', () {
    for (final timestamp in [
      now.subtract(const Duration(minutes: 6)).toIso8601String(),
      now.add(const Duration(seconds: 31)).toIso8601String(),
      '2026-10-02T17:00:00',
      'not a timestamp',
    ]) {
      expect(
        () => CaptureRequest.parse(
          request()..['created_at'] = timestamp,
          now: now,
        ),
        throwsFormatException,
      );
    }
  });

  test('native attestation and absolute Documents path are required', () {
    expect(
      captureDocumentsPath({
        'isSimulator': true,
        'documentsPath': '/sandbox/Documents',
      }),
      '/sandbox/Documents',
    );
    for (final response in [
      null,
      {'isSimulator': false, 'documentsPath': '/sandbox/Documents'},
      {'isSimulator': 'true', 'documentsPath': '/sandbox/Documents'},
      {'documentsPath': '/sandbox/Documents'},
      {'isSimulator': true, 'documentsPath': '../Documents'},
      {'isSimulator': true, 'documentsPath': '/sandbox/\u0000/Documents'},
    ]) {
      expect(() => captureDocumentsPath(response), throwsStateError);
    }
  });
}
