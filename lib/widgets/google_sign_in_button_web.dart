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
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    width: double.infinity,
    child: OutlinedButton.icon(
      key: const Key('google-sign-in-button'),
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.login),
      label: Text(busy ? 'ログイン中…' : 'Googleでログイン'),
    ),
  );
}
