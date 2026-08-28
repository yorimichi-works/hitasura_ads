import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thin wrapper around `package:google_sign_in` shared by the Web and app
/// builds, so both use the same account/session model.
///
/// The OAuth Web Client ID is not something this codebase can generate on
/// its own — it must be created in Google Cloud Console for this project's
/// domain and supplied at build time:
///
/// ```powershell
/// flutter build web --dart-define=GOOGLE_WEB_CLIENT_ID=xxxxx.apps.googleusercontent.com
/// ```
///
/// Until a client ID is supplied, [isConfigured] is false and the UI shows
/// an explanatory state instead of a non-functional button.
class GoogleAuthService extends ChangeNotifier {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();

  factory GoogleAuthService() => instance;

  static const _webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const _androidServerClientId = String.fromEnvironment(
    'GOOGLE_ANDROID_SERVER_CLIENT_ID',
  );
  static const _iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  bool _initialized = false;
  bool _initFailed = false;
  bool _busy = false;
  String? _errorMessage;
  GoogleSignInAccount? _account;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;

  bool get isConfigured {
    if (kIsWeb) return _webClientId.isNotEmpty;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _androidServerClientId.isNotEmpty,
      TargetPlatform.iOS || TargetPlatform.macOS => _iosClientId.isNotEmpty,
      _ => false,
    };
  }

  bool get isInitialized => _initialized && !_initFailed;
  bool get isSignedIn => _account != null;
  GoogleSignInAccount? get account => _account;
  bool get initFailed => _initFailed;
  bool get isBusy => _busy;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    if (!isConfigured || _initialized) return;
    _busy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await GoogleSignIn.instance.initialize(
        clientId: kIsWeb
            ? _webClientId
            : switch (defaultTargetPlatform) {
                TargetPlatform.iOS || TargetPlatform.macOS => _iosClientId,
                _ => null,
              },
        serverClientId:
            !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? _androidServerClientId
            : null,
      );
      _authSubscription = GoogleSignIn.instance.authenticationEvents.listen(
        _handleAuthenticationEvent,
        onError: _handleAuthenticationError,
      );
      _account = await GoogleSignIn.instance.attemptLightweightAuthentication();
      _initialized = true;
    } on Exception catch (error) {
      _initFailed = true;
      _errorMessage = 'Googleログインを初期化できませんでした。設定を確認してください。';
      debugPrint('Google Sign-In initialization failed: $error');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signIn() async {
    if (!isConfigured ||
        _busy ||
        !GoogleSignIn.instance.supportsAuthenticate()) {
      return;
    }
    _busy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled) {
        _errorMessage = 'Googleログインに失敗しました。もう一度お試しください。';
        debugPrint('Google Sign-In failed: $error');
      }
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (!isConfigured || _busy) return;
    _busy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await GoogleSignIn.instance.signOut();
      _account = null;
    } on Exception catch (error) {
      _errorMessage = 'ログアウトに失敗しました。もう一度お試しください。';
      debugPrint('Google Sign-Out failed: $error');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void _handleAuthenticationEvent(GoogleSignInAuthenticationEvent event) {
    switch (event) {
      case GoogleSignInAuthenticationEventSignIn():
        _account = event.user;
        _errorMessage = null;
      case GoogleSignInAuthenticationEventSignOut():
        _account = null;
    }
    notifyListeners();
  }

  void _handleAuthenticationError(Object error) {
    _errorMessage = 'Googleログインの状態を確認できませんでした。';
    debugPrint('Google Sign-In event error: $error');
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }
}
