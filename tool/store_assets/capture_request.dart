// Strict request parsing for the separate debug simulator capture entry point.
// No filesystem path or simulator attestation is accepted from this request.
class CaptureRequest {
  const CaptureRequest({
    required this.launchId,
    required this.locale,
    required this.scene,
    required this.createdAt,
  });

  final String launchId;
  final String locale;
  final String scene;
  final DateTime createdAt;

  static const locales = {
    'en',
    'ja',
    'zh',
    'zh_TW',
    'ko',
    'es',
    'fr',
    'de',
    'pt',
    'ru',
    'it',
    'hi',
    'bn',
    'ar',
    'ur',
    'fa',
    'id',
    'tr',
    'vi',
    'th',
  };
  static const scenes = {
    'home',
    'collection',
    'pin',
    'runner',
    'rush',
    'preview',
    'settings',
    'liquid',
    'fruit',
  };

  factory CaptureRequest.parse(Object? value, {DateTime? now}) {
    if (value is! Map<String, dynamic> ||
        value['schema_version'] is! int ||
        value['schema_version'] != 1) {
      throw const FormatException('Unsupported capture request schema');
    }
    const keys = {
      'schema_version',
      'launch_id',
      'locale',
      'scene',
      'created_at',
    };
    if (value.keys.toSet().difference(keys).isNotEmpty ||
        !value.keys.toSet().containsAll(keys)) {
      throw const FormatException('Unexpected or missing capture request keys');
    }
    final id = value['launch_id'];
    final locale = value['locale'];
    final scene = value['scene'];
    final created = value['created_at'];
    if (id is! String ||
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(id)) {
      throw const FormatException('Invalid capture launch UUID');
    }
    if (locale is! String || !locales.contains(locale)) {
      throw const FormatException('Unsupported capture locale');
    }
    if (scene is! String || !scenes.contains(scene)) {
      throw const FormatException('Unsupported capture scene');
    }
    final timestamp = created is String ? DateTime.tryParse(created) : null;
    if (timestamp == null || !timestamp.isUtc) {
      throw const FormatException('Capture request needs a UTC timestamp');
    }
    final age = (now ?? DateTime.now().toUtc()).difference(timestamp);
    if (age > const Duration(minutes: 5) ||
        age < const Duration(seconds: -30)) {
      throw const FormatException('Capture request expired or from the future');
    }
    return CaptureRequest(
      launchId: id,
      locale: locale,
      scene: scene,
      createdAt: timestamp,
    );
  }
}

/// Commands are capture navigation/input only, never arbitrary paths or state.
class CaptureCommand {
  const CaptureCommand({
    required this.sessionId,
    required this.requestId,
    required this.locale,
    required this.scene,
    required this.action,
    required this.createdAt,
  });
  final String sessionId;
  final String requestId;
  final String locale;
  final String scene;
  final String action;
  final DateTime createdAt;

  factory CaptureCommand.parse(Object? value, {DateTime? now}) {
    const keys = {
      'schema_version',
      'session_id',
      'request_id',
      'locale',
      'scene',
      'action',
      'created_at',
    };
    if (value is! Map<String, dynamic> ||
        value['schema_version'] is! int ||
        value['schema_version'] != 2 ||
        value.keys.length != keys.length ||
        !value.keys.toSet().containsAll(keys)) {
      throw const FormatException('Invalid capture command schema');
    }
    final base = CaptureRequest.parse({
      'schema_version': 1,
      'launch_id': value['session_id'],
      'locale': value['locale'],
      'scene': value['scene'],
      'created_at': value['created_at'],
    }, now: now);
    CaptureRequest.parse({
      'schema_version': 1,
      'launch_id': value['request_id'],
      'locale': value['locale'],
      'scene': value['scene'],
      'created_at': value['created_at'],
    }, now: now);
    final action = value['action'];
    if (action is! String ||
        !{'show', 'inspect', 'record_start', 'stop'}.contains(action)) {
      throw const FormatException('Unsupported capture action');
    }
    if (action == 'inspect' &&
        !{'pin', 'runner', 'liquid', 'fruit'}.contains(base.scene)) {
      throw const FormatException('Only gameplay scenes may be inspected');
    }
    if (action == 'record_start' && !{'liquid', 'fruit'}.contains(base.scene)) {
      throw const FormatException('Only approved gameplay scenes may record');
    }
    return CaptureCommand(
      sessionId: base.launchId,
      requestId: value['request_id'] as String,
      locale: base.locale,
      scene: base.scene,
      action: action,
      createdAt: base.createdAt,
    );
  }
}

/// Each process is permanently bound to one locale to keep thumbnails correct.
class CaptureSessionGuard {
  CaptureSessionGuard(this.sessionId, this.locale);
  final String sessionId;
  final String locale;
  final Set<String> _seen = {};
  String? _scene;
  bool _recorded = false;
  bool _stopped = false;

  void accept(CaptureCommand command) {
    if (_stopped ||
        command.sessionId != sessionId ||
        command.locale != locale ||
        _seen.contains(command.requestId)) {
      throw StateError('Stale, stopped, or cross-session capture command');
    }
    if (_scene == null && command.action != 'show') {
      throw StateError('First capture command must show a scene');
    }
    if (command.action == 'inspect' && command.scene != _scene) {
      throw StateError('Inspection requires the current game scene');
    }
    if (command.action == 'record_start' &&
        (command.scene != _scene || _recorded)) {
      throw StateError('Recording requires the current, unrecorded game scene');
    }
    _seen.add(command.requestId);
    if (command.action == 'show') {
      _scene = command.scene;
      _recorded = false;
    } else if (command.action == 'record_start') {
      _recorded = true;
    } else if (command.action == 'stop') {
      _stopped = true;
    }
  }
}

String captureDocumentsPath(Object? response) {
  if (response is! Map || response['isSimulator'] != true) {
    throw StateError('Native debug simulator attestation required');
  }
  final path = response['documentsPath'];
  if (path is! String || !path.startsWith('/') || path.contains('\u0000')) {
    throw StateError('Native Documents directory is invalid');
  }
  return path;
}
