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
  static const _clientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  bool _initialized = false;
  bool _initFailed = false;
  GoogleSignInAccount? _account;

  bool get isConfigured => _clientId.isNotEmpty;
  bool get isSignedIn => _account != null;
  GoogleSignInAccount? get account => _account;
  bool get initFailed => _initFailed;

  Future<void> initialize() async {
    if (!isConfigured || _initialized) return;
    _initialized = true;
    try {
      await GoogleSignIn.instance.initialize(clientId: _clientId);
      GoogleSignIn.instance.authenticationEvents.listen((event) {
        switch (event) {
          case GoogleSignInAuthenticationEventSignIn():
            _account = event.user;
          case GoogleSignInAuthenticationEventSignOut():
            _account = null;
        }
        notifyListeners();
      });
      _account = await GoogleSignIn.instance.attemptLightweightAuthentication();
      notifyListeners();
    } on Exception {
      _initFailed = true;
      notifyListeners();
    }
  }

  Future<void> signIn() async {
    if (!isConfigured) return;
    try {
      _account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException {
      // User cancelled or the flow failed; leave state unchanged.
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    if (!isConfigured) return;
    await GoogleSignIn.instance.signOut();
    _account = null;
    notifyListeners();
  }
}
