import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';

abstract interface class AuthSession implements Listenable {
  bool get isSignedIn;
  String? get uid;
  GoogleAccountInfo? get account;
}

class GoogleAccountInfo {
  const GoogleAccountInfo({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
  });

  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
}

/// Firebase Auth on Web, Google Sign-In on native platforms.
///
/// Web progress is keyed by the Firebase Auth uid. OAuth client secrets are
/// never used by or embedded in this client.
class GoogleAuthService extends ChangeNotifier implements AuthSession {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();

  factory GoogleAuthService() => instance;

  static const _androidServerClientId = String.fromEnvironment(
    'GOOGLE_ANDROID_SERVER_CLIENT_ID',
  );
  static const _iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  bool _initialized = false;
  bool _initFailed = false;
  bool _busy = false;
  String? _errorMessage;
  GoogleAccountInfo? _account;
  StreamSubscription<User?>? _firebaseSubscription;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _nativeSubscription;

  bool get isConfigured {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _androidServerClientId.isNotEmpty,
      TargetPlatform.iOS || TargetPlatform.macOS => _iosClientId.isNotEmpty,
      _ => false,
    };
  }

  bool get isInitialized => _initialized && !_initFailed;
  @override
  bool get isSignedIn => _account != null;
  @override
  String? get uid => _account?.uid;
  @override
  GoogleAccountInfo? get account => _account;
  bool get initFailed => _initFailed;
  bool get isBusy => _busy;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    if (!isConfigured || _initialized || _busy) return;
    _busy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (kIsWeb) {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
        }
        final auth = FirebaseAuth.instance;
        _firebaseSubscription = auth.authStateChanges().listen(
          _handleFirebaseUser,
          onError: _handleAuthenticationError,
        );
        _handleFirebaseUser(auth.currentUser);
      } else {
        await GoogleSignIn.instance.initialize(
          clientId: switch (defaultTargetPlatform) {
            TargetPlatform.iOS || TargetPlatform.macOS => _iosClientId,
            _ => null,
          },
          serverClientId: defaultTargetPlatform == TargetPlatform.android
              ? _androidServerClientId
              : null,
        );
        _nativeSubscription = GoogleSignIn.instance.authenticationEvents.listen(
          _handleNativeAuthenticationEvent,
          onError: _handleAuthenticationError,
        );
        _setNativeAccount(
          await GoogleSignIn.instance.attemptLightweightAuthentication(),
        );
      }
      _initialized = true;
      _initFailed = false;
    } on Exception catch (error) {
      _initFailed = true;
      _errorMessage = 'Googleログインを初期化できませんでした。Firebase設定を確認してください。';
      debugPrint('Google/Firebase initialization failed: $error');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signIn() async {
    if (!isConfigured || _busy) return;
    if (!_initialized) await initialize();
    if (!isInitialized) return;
    _busy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..setCustomParameters({'prompt': 'select_account'});
        final credential = await FirebaseAuth.instance.signInWithPopup(
          provider,
        );
        _handleFirebaseUser(credential.user);
      } else if (GoogleSignIn.instance.supportsAuthenticate()) {
        _setNativeAccount(await GoogleSignIn.instance.authenticate());
      }
    } on FirebaseAuthException catch (error) {
      if (error.code != 'popup-closed-by-user' &&
          error.code != 'cancelled-popup-request') {
        _errorMessage = _firebaseErrorMessage(error);
        debugPrint('Firebase Google Sign-In failed: ${error.code} $error');
      }
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled) {
        _errorMessage = 'Googleログインに失敗しました。もう一度お試しください。';
        debugPrint('Native Google Sign-In failed: $error');
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
      if (kIsWeb) {
        await FirebaseAuth.instance.signOut();
      } else {
        await GoogleSignIn.instance.signOut();
      }
      _account = null;
    } on Exception catch (error) {
      _errorMessage = 'ログアウトに失敗しました。もう一度お試しください。';
      debugPrint('Google Sign-Out failed: $error');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void _handleFirebaseUser(User? user) {
    _account = user == null
        ? null
        : GoogleAccountInfo(
            uid: user.uid,
            email: user.email ?? '',
            displayName: user.displayName,
            photoUrl: user.photoURL,
          );
    _errorMessage = null;
    notifyListeners();
  }

  void _handleNativeAuthenticationEvent(GoogleSignInAuthenticationEvent event) {
    switch (event) {
      case GoogleSignInAuthenticationEventSignIn():
        _setNativeAccount(event.user);
      case GoogleSignInAuthenticationEventSignOut():
        _account = null;
    }
    _errorMessage = null;
    notifyListeners();
  }

  void _setNativeAccount(GoogleSignInAccount? account) {
    _account = account == null
        ? null
        : GoogleAccountInfo(
            uid: account.id,
            email: account.email,
            displayName: account.displayName,
            photoUrl: account.photoUrl,
          );
  }

  void _handleAuthenticationError(Object error) {
    _errorMessage = 'Googleログインの状態を確認できませんでした。';
    debugPrint('Google Sign-In event error: $error');
    notifyListeners();
  }

  String _firebaseErrorMessage(FirebaseAuthException error) =>
      switch (error.code) {
        'operation-not-allowed' => 'Firebase ConsoleでGoogleログインを有効にしてください。',
        'unauthorized-domain' => 'この公開ドメインがFirebase Authで許可されていません。',
        'popup-blocked' => 'ブラウザがログイン画面をブロックしました。ポップアップを許可してください。',
        _ => 'Googleログインに失敗しました（${error.code}）。',
      };

  @override
  void dispose() {
    unawaited(_firebaseSubscription?.cancel());
    unawaited(_nativeSubscription?.cancel());
    super.dispose();
  }
}
