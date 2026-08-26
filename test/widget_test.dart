import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hitasura_ads/main.dart';

void main() {
  testWidgets('first launch leads into the app shell', (tester) async {
    await tester.pumpWidget(const HitasuraAdsApp());

    expect(find.text('ひたすら広告'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '広告王');
    await tester.enterText(find.byType(TextField).at(1), '24');
    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('RANKING'), findsOneWidget);
    expect(find.text('EXPLORATION'), findsOneWidget);
    expect(find.text('CATALOG'), findsOneWidget);
  });
}
