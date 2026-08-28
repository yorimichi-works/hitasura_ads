import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

class GoogleAccountSignInButton extends StatelessWidget {
  const GoogleAccountSignInButton({
    super.key,
    required this.onPressed,
    required this.busy,
  });

  final VoidCallback? onPressed;
  final bool busy;

  static final web.GSIButtonConfiguration _configuration =
      web.GSIButtonConfiguration(
        type: web.GSIButtonType.standard,
        theme: web.GSIButtonTheme.outline,
        size: web.GSIButtonSize.large,
        text: web.GSIButtonText.signinWith,
        shape: web.GSIButtonShape.rectangular,
        logoAlignment: web.GSIButtonLogoAlignment.left,
        minimumWidth: 260,
        locale: 'ja',
      );

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        height: 44,
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: Center(
        key: const Key('google-sign-in-button'),
        child: SizedBox(
          width: 260,
          height: 44,
          child: ClipRect(
            child: web.renderButton(configuration: _configuration),
          ),
        ),
      ),
    );
  }
}
