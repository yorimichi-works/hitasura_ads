import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/widgets/google_sign_in_button.dart';

void main() {
  testWidgets('Google login button invokes the supplied callback', (
    tester,
  ) async {
    var presses = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoogleAccountSignInButton(
            onPressed: () => presses++,
            busy: false,
          ),
        ),
      ),
    );

    expect(find.text('Googleでログイン'), findsOneWidget);
    await tester.tap(find.byKey(const Key('google-sign-in-button')));
    expect(presses, 1);
  });

  testWidgets('Google login button is disabled while authentication is busy', (
    tester,
  ) async {
    var presses = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoogleAccountSignInButton(
            onPressed: () => presses++,
            busy: true,
          ),
        ),
      ),
    );

    expect(find.text('ログイン中…'), findsOneWidget);
    await tester.tap(find.byKey(const Key('google-sign-in-button')));
    expect(presses, 0);
  });
}
