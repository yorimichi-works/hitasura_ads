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

  Map<String, dynamic> command({
    String id = 'c1a9a9ab-3fb1-4300-a6f6-1ca229506790',
    String action = 'show',
    String scene = 'home',
  }) => {
    'schema_version': 2,
    'session_id': request()['launch_id'],
    'request_id': id,
    'locale': 'en',
    'scene': scene,
    'action': action,
    'created_at': now.toIso8601String(),
  };

  test(
    'v2 commands preserve strict identities and disallow arbitrary actions',
    () {
      final parsed = CaptureCommand.parse(command(), now: now);
      expect(parsed.sessionId, request()['launch_id']);
      for (final change in [
        {'action': 'set_score'},
        {'action': 'record_start'},
        {'isSimulator': true},
        {'path': '/tmp/output'},
        {'request_id': 'bad'},
        {'schema_version': 2.0},
        {
          'created_at': now
              .subtract(const Duration(minutes: 6))
              .toIso8601String(),
        },
      ]) {
        expect(
          () => CaptureCommand.parse(command()..addAll(change), now: now),
          throwsFormatException,
        );
      }
    },
  );

  test('v2 session rejects cross-locale, stale and out-of-order commands', () {
    final initial = CaptureCommand.parse(command(scene: 'liquid'), now: now);
    final guard = CaptureSessionGuard(initial.sessionId, initial.locale);
    final record = CaptureCommand.parse(
      command(
        action: 'record_start',
        scene: 'liquid',
        id: 'c1a9a9ab-3fb1-4300-a6f6-1ca229506791',
      ),
      now: now,
    );
    expect(() => guard.accept(record), throwsStateError);
    guard.accept(initial);
    expect(() => guard.accept(initial), throwsStateError);
    for (final change in [
      {'locale': 'ja'},
      {'session_id': 'c1a9a9ab-3fb1-4300-a6f6-1ca229506792'},
      {'scene': 'fruit'},
    ]) {
      final invalid = CaptureCommand.parse(
        command(
          action: 'record_start',
          scene: 'liquid',
          id: 'c1a9a9ab-3fb1-4300-a6f6-1ca229506791',
        )..addAll(change),
        now: now,
      );
      expect(() => guard.accept(invalid), throwsStateError);
    }
    guard.accept(record);
    final duplicateRecording = CaptureCommand.parse(
      command(
        action: 'record_start',
        scene: 'liquid',
        id: 'c1a9a9ab-3fb1-4300-a6f6-1ca229506793',
      ),
      now: now,
    );
    expect(() => guard.accept(duplicateRecording), throwsStateError);
    final stop = CaptureCommand.parse(
      command(action: 'stop', id: 'c1a9a9ab-3fb1-4300-a6f6-1ca229506794'),
      now: now,
    );
    guard.accept(stop);
    expect(() => guard.accept(initial), throwsStateError);
  });

  test('inspection is read-only, current-scene-only and replay protected', () {
    final initial = CaptureCommand.parse(command(scene: 'runner'), now: now);
    final guard = CaptureSessionGuard(initial.sessionId, initial.locale);
    final inspect = CaptureCommand.parse(
      command(
        action: 'inspect',
        scene: 'runner',
        id: 'c1a9a9ab-3fb1-4300-a6f6-1ca229506795',
      ),
      now: now,
    );
    expect(() => guard.accept(inspect), throwsStateError);
    guard.accept(initial);
    guard.accept(inspect);
    expect(() => guard.accept(inspect), throwsStateError);
    final wrong = CaptureCommand.parse(
      command(
        action: 'inspect',
        scene: 'pin',
        id: 'c1a9a9ab-3fb1-4300-a6f6-1ca229506796',
      ),
      now: now,
    );
    expect(() => guard.accept(wrong), throwsStateError);
    final second = CaptureCommand.parse(
      command(
        action: 'inspect',
        scene: 'runner',
        id: 'c1a9a9ab-3fb1-4300-a6f6-1ca229506797',
      ),
      now: now,
    );
    guard.accept(second); // An inspection must not stop or navigate the session.
    for (final scene in ['home', 'collection', 'rush', 'settings', 'preview']) {
      expect(
        () => CaptureCommand.parse(
          command(action: 'inspect', scene: scene),
          now: now,
        ),
        throwsFormatException,
      );
    }
  });

}
