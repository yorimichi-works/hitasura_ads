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
