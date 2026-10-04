import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/services/store_price_diagnostic.dart';
import 'package:hitasura_ads/ui/store_price_diagnostic.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

ProductDetails product(String display, String currency, double amount) =>
    ProductDetails(
      id: 'ad_free_unlimited',
      title: 'Premium',
      description: '',
      price: display,
      rawPrice: amount,
      currencyCode: currency,
    );

ProductDetailsResponse response(ProductDetails p) =>
    ProductDetailsResponse(productDetails: [p], notFoundIDs: []);

Map<String, dynamic> nativeSample() => {
  'status': 'ok',
  'rawProductCount': 1,
  'storefrontBefore': {'countryCode': 'USA', 'identifier': '143462'},
  'storefrontAfter': {'countryCode': 'USA', 'identifier': '143462'},
  'products': [
    {
      'id': 'ad_free_unlimited',
      'rawPrice': '2.99',
      'currencyCode': 'USD',
      'displayPrice': r'$2.99',
      'priceLocale': 'en_US',
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final font = FontLoader('KosugiMaru')
      ..addFont(rootBundle.load('assets/fonts/KosugiMaru-Regular.ttf'));
    await font.load();
  });

  test('diagnostic UI defaults off for ordinary builds', () {
    expect(priceDiagnosticsEnabled, isFalse);
  });

  test(
    'preserves inconsistent raw storefront and USD without forcing JPY',
    () async {
      final displayed = product(r'$2.99', 'USD', 2.99);
      final reader = StorePriceDiagnostic(
        nativeRead: () async => nativeSample(),
        queryProducts: (ids) async {
          expect(ids, {'ad_free_unlimited'});
          return response(product(r'$2.99', 'USD', 2.99));
        },
      );
      final report = await reader.read(displayedProduct: displayed);
      expect(report['displayedAtTap']['displayPrice'], r'$2.99');
      expect(report['native']['storefrontBefore'], {
        'countryCode': 'USA',
        'identifier': '143462',
      });
      expect(report['native']['products'][0]['currencyCode'], 'USD');
      expect(
        report['flutterFreshQuery']['products'][0]['displayPrice'],
        r'$2.99',
      );
      expect(jsonEncode(report), isNot(contains('JPY')));
      expect(displayed.price, r'$2.99');
    },
  );

  test(
    'keeps displayed, fresh Flutter and direct native prices separate',
    () async {
      final reader = StorePriceDiagnostic(
        nativeRead: () async => nativeSample(),
        queryProducts: (_) async => response(product('¥300', 'JPY', 300)),
      );
      final report = await reader.read(
        displayedProduct: product(r'$2.99', 'USD', 2.99),
      );
      expect(report['displayedAtTap']['displayPrice'], r'$2.99');
      expect(report['native']['products'][0]['displayPrice'], r'$2.99');
      expect(
        report['flutterFreshQuery']['products'][0]['displayPrice'],
        '¥300',
      );
    },
  );

  test('drops unapproved native fields and non-target products', () async {
    final raw = nativeSample();
    raw['receipt'] = 'secret';
    raw['products'][0]['account'] = 'private';
    raw['products'].add({'id': 'another_product', 'displayPrice': 'private'});
    raw['storefrontBefore']['account'] = 'private';
    final reader = StorePriceDiagnostic(
      nativeRead: () async => raw,
      queryProducts: (_) async => ProductDetailsResponse(
        productDetails: [],
        notFoundIDs: ['ad_free_unlimited'],
      ),
    );
    final report = await reader.read(displayedProduct: null);
    expect(jsonEncode(report), isNot(contains('secret')));
    expect(jsonEncode(report), isNot(contains('private')));
    expect(report['native']['products'], hasLength(1));
    expect(report['flutterFreshQuery']['status'], 'empty');
  });

  test(
    'coalesces duplicate reads and allows another observation afterward',
    () async {
      final completer = Completer<Map<String, dynamic>?>();
      var nativeCalls = 0;
      var flutterCalls = 0;
      final reader = StorePriceDiagnostic(
        nativeRead: () {
          nativeCalls++;
          return completer.future;
        },
        queryProducts: (_) async {
          flutterCalls++;
          return response(product(r'$2.99', 'USD', 2.99));
        },
      );
      final first = reader.read(displayedProduct: null);
      expect(identical(first, reader.read(displayedProduct: null)), isTrue);
      completer.complete(nativeSample());
      await first;
      expect(nativeCalls, 1);
      expect(flutterCalls, 1);
      await reader.read(displayedProduct: null);
      expect(nativeCalls, 2);
    },
  );

  test('sanitizes platform and store errors', () async {
    final reader = StorePriceDiagnostic(
      nativeRead: () async => throw PlatformException(
        code: 'unavailable',
        message: 'private account',
        details: 'private receipt',
      ),
      queryProducts: (_) async => ProductDetailsResponse(
        productDetails: [],
        notFoundIDs: [],
        error: IAPError(
          source: 'store',
          code: 'error',
          message: 'private account',
        ),
      ),
    );
    final report = await reader.read(displayedProduct: null);
    expect(report['native'], {'status': 'error', 'errorCode': 'unavailable'});
    expect(report['flutterFreshQuery']['errorCode'], 'error');
    expect(jsonEncode(report), isNot(contains('private')));
  });

  testWidgets('both stalled reads time out without a permanent busy state', (
    tester,
  ) async {
    final reader = StorePriceDiagnostic(
      nativeRead: () => Completer<Map<String, dynamic>?>().future,
      queryProducts: (_) => Completer<ProductDetailsResponse>().future,
      timeout: const Duration(milliseconds: 20),
    );
    final first = reader.read(displayedProduct: null);
    await tester.pump(const Duration(milliseconds: 21));
    final result = await first;
    expect(result['native']['status'], 'timeout');
    expect(result['flutterFreshQuery']['status'], 'timeout');
    final second = reader.read(displayedProduct: null);
    expect(identical(first, second), isFalse);
    await tester.pump(const Duration(milliseconds: 21));
    await second;
  });

  testWidgets(
    'manual diagnostic prevents repeated taps and displays raw values',
    (tester) async {
      final completer = Completer<Map<String, dynamic>?>();
      var count = 0;
      final reader = StorePriceDiagnostic(
        nativeRead: () {
          count++;
          return completer.future;
        },
        queryProducts: (_) async => response(product(r'$2.99', 'USD', 2.99)),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StorePriceDiagnosticPanel(
                displayedProduct: () => product(r'$2.99', 'USD', 2.99),
                reader: reader,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('read-price-diagnostic')));
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('read-price-diagnostic')),
            )
            .onPressed,
        isNull,
      );
      expect(count, 1);
      completer.complete(nativeSample());
      await tester.pumpAndSettle();
      final text = tester
          .widget<SelectableText>(
            find.byKey(const ValueKey('price-diagnostic-result')),
          )
          .data!;
      expect(text, contains('143462'));
      expect(text, contains(r'$2.99'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('narrow diagnostic supports large text and scrolling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final scale in [1.0, 2.0]) {
      final reader = StorePriceDiagnostic(
        nativeRead: () async => nativeSample(),
        queryProducts: (_) async => response(product(r'$2.99', 'USD', 2.99)),
      );
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: boundary,
            child: Scaffold(
              backgroundColor: const Color(0xFFFFF6E6),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: StorePriceDiagnosticPanel(
                  key: ValueKey(scale),
                  displayedProduct: () => product(r'$2.99', 'USD', 2.99),
                  reader: reader,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('read-price-diagnostic')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final output = Platform.environment['PRICE_DIAGNOSTIC_PREVIEW_DIR'];
      if (output != null && scale == 1) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory(output).createSync(recursive: true);
          File('$output/owner-price-diagnostic.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('leaving the panel during a query never updates disposed state', (
    tester,
  ) async {
    final completer = Completer<Map<String, dynamic>?>();
    final reader = StorePriceDiagnostic(
      nativeRead: () => completer.future,
      queryProducts: (_) async => response(product(r'$2.99', 'USD', 2.99)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StorePriceDiagnosticPanel(
            displayedProduct: () => null,
            reader: reader,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('read-price-diagnostic')));
    await tester.pumpWidget(const SizedBox());
    completer.complete(nativeSample());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
