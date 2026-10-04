import 'dart:async';

import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'premium_purchase_service.dart';

const priceDiagnosticsEnabled = bool.fromEnvironment('IAP_PRICE_DIAGNOSTICS');

/// One manual observation starts both read-only queries. They are not an atomic
/// StoreKit snapshot; native storefront values bracket the native product read.
class StorePriceDiagnostic {
  StorePriceDiagnostic({
    Future<Map<String, dynamic>?> Function()? nativeRead,
    Future<ProductDetailsResponse> Function(Set<String>)? queryProducts,
    this.timeout = const Duration(seconds: 18),
  }) : _nativeRead = nativeRead ?? _readNative,
       _queryProducts =
           queryProducts ?? InAppPurchase.instance.queryProductDetails;

  final Future<Map<String, dynamic>?> Function() _nativeRead;
  final Future<ProductDetailsResponse> Function(Set<String>) _queryProducts;
  final Duration timeout;
  Future<Map<String, dynamic>>? _pending;

  static Future<Map<String, dynamic>?> _readNative() =>
      const MethodChannel('hitasura_ads/purchases')
          .invokeMapMethod<String, dynamic>('readStorePriceDiagnostic');

  static Map<String, Object?> priceSnapshot(ProductDetails? product) => {
    'id': product?.id,
    'rawPrice': product?.rawPrice,
    'currencyCode': product?.currencyCode,
    'displayPrice': product?.price,
  };

  Future<Map<String, dynamic>> read({
    required ProductDetails? displayedProduct,
  }) {
    if (_pending != null) return _pending!;
    final visible = priceSnapshot(displayedProduct);
    final operation = _read(visible);
    final tracked = operation.whenComplete(() => _pending = null);
    _pending = tracked;
    return tracked;
  }

  Future<Map<String, dynamic>> _read(Map<String, Object?> visible) async {
    final parts = await Future.wait([_bounded(_native), _bounded(_flutter)]);
    return {
      'displayedAtTap': visible,
      'native': parts[0],
      'flutterFreshQuery': parts[1],
    };
  }

  Future<Map<String, dynamic>> _bounded(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    try {
      return await action().timeout(timeout);
    } on TimeoutException {
      return {'status': 'timeout'};
    } on PlatformException catch (e) {
      // Never expose localized errors, account identifiers, or error details.
      return {'status': 'error', 'errorCode': e.code};
    } catch (_) {
      return {'status': 'error'};
    }
  }

  Future<Map<String, dynamic>> _native() async {
    final raw = await _nativeRead();
    if (raw == null) return {'status': 'unavailable'};
    final output = <String, dynamic>{};
    for (final key in [
      'status',
      'rawProductCount',
      'startedAt',
      'elapsedMs',
      'version',
      'build',
      'os',
      'bundleMatches',
      'errorDomain',
      'errorCode',
    ]) {
      final value = raw[key];
      if (value is String || value is num || value is bool) output[key] = value;
    }
    for (final key in ['storefrontBefore', 'storefrontAfter']) {
      if (raw[key] case final Map value) {
        output[key] = _strings(value, ['countryCode', 'identifier']);
      }
    }
    if (raw['products'] case final List products) {
      output['products'] = products
          .whereType<Map>()
          .where((p) => p['id'] == PremiumPurchaseService.productId)
          .map(
            (p) => _strings(p, [
              'id',
              'rawPrice',
              'currencyCode',
              'displayPrice',
              'priceLocale',
            ]),
          )
          .toList();
    }
    return output;
  }

  static Map<String, String> _strings(Map values, List<String> keys) => {
    for (final key in keys)
      if (values[key] is String) key: values[key] as String,
  };

  Future<Map<String, dynamic>> _flutter() async {
    final response = await _queryProducts({PremiumPurchaseService.productId});
    final matching = response.productDetails
        .where((p) => p.id == PremiumPurchaseService.productId)
        .toList();
    return {
      'status': response.error != null
          ? 'error'
          : matching.isEmpty
          ? 'empty'
          : 'ok',
      'rawProductCount': response.productDetails.length,
      'products': matching.map(priceSnapshot).toList(),
      if (response.error != null) 'errorCode': response.error!.code,
    };
  }
}
