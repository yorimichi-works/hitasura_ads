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

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Center(
      key: const Key('google-sign-in-button'),
      child: web.renderButton(
        configuration: web.GSIButtonConfiguration(
          type: web.GSIButtonType.standard,
          theme: web.GSIButtonTheme.outline,
          size: web.GSIButtonSize.large,
          text: web.GSIButtonText.signinWith,
          shape: web.GSIButtonShape.rectangular,
          logoAlignment: web.GSIButtonLogoAlignment.left,
          minimumWidth: 240,
          locale: 'ja',
        ),
      ),
    );
  }
}
