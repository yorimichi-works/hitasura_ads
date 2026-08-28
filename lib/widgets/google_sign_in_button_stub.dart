import 'package:flutter/material.dart';

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
    return OutlinedButton.icon(
      key: const Key('google-sign-in-button'),
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.login),
      label: Text(busy ? 'ログイン中…' : 'Googleでログイン'),
    );
  }
}
