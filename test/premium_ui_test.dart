import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/data/app_store.dart';
import 'package:hitasura_ads/arcade/engine/draw.dart';
import 'package:hitasura_ads/l10n/l10n.dart';
import 'package:hitasura_ads/models/app_models.dart';
import 'package:hitasura_ads/services/premium_purchase_service.dart';
import 'package:hitasura_ads/services/rewarded_ad_service.dart';
import 'package:hitasura_ads/state/app_controller.dart';
import 'package:hitasura_ads/ui/home.dart';
import 'package:hitasura_ads/ui/premium.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'premium_catalogue_test.dart' show catalogue, catalogueProduct;

class UiNoAds extends DebugRewardedAdService {
  @override
  Future<void> preparePrivacy() async {}
}

Future<AppController> controllerFor(String code, {bool owned = false}) =>
    AppController.create(
      store: MemoryAppStore(
        AppSnapshot(
          soundEffectsEnabled: false,
          premiumNoAds: owned,
          arcade: ArcadeState(language: code),
        ),
      ),
    );

Widget app(Widget child, {double textScale = 1}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'KosugiMaru',
    fontFamilyFallback: D.fontFallback,
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: TextScaler.linear(textScale)),
    child: Directionality(textDirection: L10n.direction, child: child!),
  ),
  home: child,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('KosugiMaru')
      ..addFont(rootBundle.load('assets/fonts/KosugiMaru-Regular.ttf'));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    // Native apps use platform fallback fonts. Load equivalent installed fonts
    // for optional Linux previews; the app does not bundle or depend on these.
    if (const bool.fromEnvironment('CAPTURE_PREMIUM_UI')) {
      for (final entry in {
        'Noto Sans': '/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf',
        'Noto Sans Arabic':
            '/usr/share/fonts/truetype/noto/NotoSansArabic-Regular.ttf',
        'Noto Sans JP':
            '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
      }.entries) {
        final file = File(entry.value);
        if (!file.existsSync()) continue;
        final bytes = file.readAsBytesSync();
        final fallback = FontLoader(entry.key)
          ..addFont(Future.value(ByteData.sublistView(bytes)));
        await fallback.load();
      }
    }
  });
  for (final language in languages) {
    testWidgets(
      '${language.code}: purchase screen fits narrow display and large text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final previousCode = L10n.code;
        addTearDown(() => L10n.code = previousCode);
        final c = await controllerFor(language.code);
        final service = PremiumPurchaseService(
          onUnlocked: () async {},
          supportedPlatform: true,
          purchaseUpdates: const Stream.empty(),
          isStoreAvailable: () async => true,
          queryProducts: (_) async =>
              catalogue(catalogueProduct('¥300', 'JPY')),
        );
        await service.initialize();
        await tester.pumpWidget(
          app(
            PremiumScreen(controller: c, purchaseService: service),
            textScale: 1.6,
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('premium-restore')),
          160,
        );
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('¥300'), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.text('¥300'))),
          TextDirection.ltr,
        );
        expect(find.text(L10n.ui('restore_purchases')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        service.dispose();
        c.dispose();
      },
    );
  }

  testWidgets(
    'home bottom entry opens once, returns, and reflects owned state',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await controllerFor('ja');
      await tester.pumpWidget(
        app(HomeScreen(controller: c, rewardedAdService: UiNoAds())),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final entry = find.byKey(const ValueKey('home-premium-entry'));
      await tester.scrollUntilVisible(entry, 250);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(entry);
      await tester.tap(entry, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PremiumScreen), findsOneWidget);
      expect(find.text(L10n.ui('premium_desc')), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PremiumScreen), findsNothing);
      await c.grantPremium();
      await tester.pump();
      expect(find.text(L10n.ui('premium_active')), findsOneWidget);
      await tester.tap(entry);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('premium-buy')), findsNothing);
      expect(find.text(L10n.ui('premium_active')), findsOneWidget);
      expect(find.text(L10n.ui('restore_purchases')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets(
    'opening panel refreshes cached USD, exposes loading, then displays store yen',
    (tester) async {
      final c = await controllerFor('ja');
      final next = Completer<ProductDetailsResponse>();
      var queries = 0;
      var restores = 0;
      final service = PremiumPurchaseService(
        onUnlocked: () async {},
        supportedPlatform: true,
        purchaseUpdates: const Stream.empty(),
        isStoreAvailable: () async => true,
        queryProducts: (_) async => ++queries == 1
            ? catalogue(catalogueProduct(r'$2.99', 'USD'))
            : next.future,
        restorePurchases: () async {
          restores++;
        },
      );
      await service.initialize();
      await tester.pump();
      await tester.pumpWidget(
        app(
          Scaffold(
            body: PremiumPurchasePanel(controller: c, purchaseService: service),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining(r'$2.99'), findsNothing);
      expect(find.text(L10n.ui('premium_loading')), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const ValueKey('premium-buy')))
            .onPressed,
        isNull,
      );
      next.complete(catalogue(catalogueProduct('¥300', 'JPY')));
      await tester.pump();
      await tester.pump();
      expect(find.text('¥300'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const ValueKey('premium-buy')))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const ValueKey('premium-restore')));
      await tester.pump();
      expect(restores, 1);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
      c.dispose();
    },
  );

  testWidgets('unavailable price can be retried without guessing a currency', (
    tester,
  ) async {
    final c = await controllerFor('en');
    var available = false;
    final service = PremiumPurchaseService(
      onUnlocked: () async {},
      supportedPlatform: true,
      purchaseUpdates: const Stream.empty(),
      isStoreAvailable: () async => available,
      queryProducts: (_) async => catalogue(catalogueProduct(r'$2.99', 'USD')),
    );
    await service.initialize();
    await tester.pumpWidget(
      app(
        Scaffold(
          body: PremiumPurchasePanel(controller: c, purchaseService: service),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(L10n.ui('premium_unavailable')), findsOneWidget);
    expect(find.textContaining(r'$'), findsNothing);
    available = true;
    await tester.tap(find.text(L10n.ui('premium_retry')));
    await tester.pump();
    expect(find.text(r'$2.99'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    service.dispose();
    c.dispose();
  });

  if (const bool.fromEnvironment('CAPTURE_PREMIUM_UI')) {
    for (final code in ['ja', 'en', 'ar']) {
      testWidgets('capture $code premium preview', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final c = await controllerFor(code);
        final service = PremiumPurchaseService(
          onUnlocked: () async {},
          supportedPlatform: true,
          purchaseUpdates: const Stream.empty(),
          isStoreAvailable: () async => true,
          queryProducts: (_) async =>
              catalogue(catalogueProduct('¥300', 'JPY')),
        );
        await service.initialize();
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: app(PremiumScreen(controller: c, purchaseService: service)),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('build/premium-previews/$code.png')
            ..createSync(recursive: true)
            ..writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox());
        service.dispose();
        c.dispose();
      });
    }
  }
}
