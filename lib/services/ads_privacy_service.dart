import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Small boundary around UMP so privacy failures can be tested without ads.
abstract interface class AdsConsentGateway {
  Future<void> update();
  Future<void> collectIfRequired();
  Future<bool> canRequestAds();
  Future<bool> privacyOptionsRequired();
  Future<void> showPrivacyOptions();
}

class UmpAdsConsentGateway implements AdsConsentGateway {
  @override
  Future<void> update() {
    final result = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => result.complete(),
      (error) => result.completeError(error),
    );
    return result.future;
  }

  @override
  Future<void> collectIfRequired() async {
    FormError? failure;
    await ConsentForm.loadAndShowConsentFormIfRequired((error) {
      failure = error;
    });
    if (failure != null) throw failure!;
  }

  @override
  Future<bool> canRequestAds() => ConsentInformation.instance.canRequestAds();

  @override
  Future<bool> privacyOptionsRequired() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  @override
  Future<void> showPrivacyOptions() async {
    FormError? failure;
    await ConsentForm.showPrivacyOptionsForm((error) {
      failure = error;
    });
    if (failure != null) throw failure!;
  }
}

/// Never treats a saved app flag or a failed UMP request as ad permission.
/// One successful update is required per service/app session, then UMP is
/// checked again immediately before every ad load and presentation.
class AdsPrivacyService extends ChangeNotifier {
  AdsPrivacyService({AdsConsentGateway? gateway})
    : _gateway = gateway ?? UmpAdsConsentGateway();

  final AdsConsentGateway _gateway;
  Future<bool>? _initializing;
  Future<bool>? _preparing;
  bool _updated = false;
  bool _collected = false;
  bool _disposed = false;
  bool _optionsOpen = false;
  bool canRequestAds = false;
  bool privacyOptionsRequired = false;
  bool busy = false;
  bool hasError = false;

  /// Refreshes the settings entry on launch without initializing Mobile Ads
  /// or asking a premium user to consent to an ad they will never request.
  Future<bool> prepare() async {
    if (_disposed || _optionsOpen) return false;
    if (_preparing != null) return _preparing!;
    if (_updated) return true;
    final operation = _updateInformation();
    _preparing = operation;
    try {
      return await operation;
    } finally {
      _preparing = null;
    }
  }

  Future<bool> _updateInformation() async {
    busy = true;
    hasError = false;
    _notify();
    try {
      await _gateway.update();
      if (_disposed) return false;
      privacyOptionsRequired = await _gateway.privacyOptionsRequired();
      _updated = true;
      return !_disposed;
    } catch (_) {
      canRequestAds = false;
      hasError = true;
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> ensureConsent() async {
    if (_disposed || _optionsOpen) return false;
    if (_initializing != null) return _initializing!;
    if (_collected) return refreshPermission();
    final operation = _gatherConsent();
    _initializing = operation;
    try {
      return await operation;
    } finally {
      _initializing = null;
    }
  }

  Future<bool> _gatherConsent() async {
    if (!await prepare()) return false;
    busy = true;
    hasError = false;
    canRequestAds = false;
    _notify();
    try {
      await _gateway.collectIfRequired();
      if (_disposed) return false;
      _collected = true;
      return await refreshPermission();
    } catch (_) {
      hasError = true;
      canRequestAds = false;
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> refreshPermission() async {
    if (_disposed || !_collected || _optionsOpen) return false;
    try {
      final allowed = await _gateway.canRequestAds();
      if (_disposed || _optionsOpen) return false;
      canRequestAds = allowed;
      hasError = false;
    } catch (_) {
      canRequestAds = false;
      hasError = true;
    }
    _notify();
    return !_disposed && canRequestAds;
  }

  Future<void> showPrivacyOptions() async {
    if (_disposed || busy || !privacyOptionsRequired) return;
    _optionsOpen = true;
    busy = true;
    hasError = false;
    // Invalidate any preloaded ad before consent choices can change.
    canRequestAds = false;
    _notify();
    try {
      await _gateway.showPrivacyOptions();
      if (_disposed) return;
      privacyOptionsRequired = await _gateway.privacyOptionsRequired();
      _updated = true;
      _collected = true;
      _optionsOpen = false;
      await refreshPermission();
    } catch (_) {
      _updated = false;
      _collected = false;
      hasError = true;
      canRequestAds = false;
    } finally {
      _optionsOpen = false;
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
