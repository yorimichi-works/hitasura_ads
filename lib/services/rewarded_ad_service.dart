import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum RewardedAdResult { rewarded, notRewarded, unavailable, loadFailed }

enum AdNetworkMode { disabled, test, production }

enum RewardedAdStatus {
  unsupported,
  idle,
  initializing,
  loading,
  ready,
  showing,
  failed,
}

abstract class RewardedAdService extends ChangeNotifier {
  RewardedAdStatus get status;
  bool get isSupported;
  bool get usesTestAds;
  bool supportsPlacement(String placementName) => isSupported;
  Future<void> initialize();
  Future<RewardedAdResult> show({String placementName = 'reward'});
}

/// Debug-only stand-in used by isolated widget and service tests.
class DebugRewardedAdService extends RewardedAdService {
  RewardedAdStatus _status = RewardedAdStatus.ready;
  bool _showing = false;

  @override
  RewardedAdStatus get status => _status;

  @override
  bool get isSupported => kDebugMode;

  @override
  bool get usesTestAds => true;

  @override
  Future<void> initialize() async {
    if (!kDebugMode) return;
    _setStatus(RewardedAdStatus.ready);
  }

  @override
  Future<RewardedAdResult> show({String placementName = 'reward'}) async {
    if (!kDebugMode) return RewardedAdResult.unavailable;
    if (_showing || _status != RewardedAdStatus.ready) {
      return RewardedAdResult.loadFailed;
    }
    _showing = true;
    _setStatus(RewardedAdStatus.showing);
    debugPrint('[RewardedAd] DEBUG pseudo reward started');
    await Future<void>.delayed(const Duration(milliseconds: 650));
    _showing = false;
    _setStatus(RewardedAdStatus.ready);
    debugPrint('[RewardedAd] DEBUG pseudo reward earned');
    return RewardedAdResult.rewarded;
  }

  void _setStatus(RewardedAdStatus value) {
    if (_status == value) return;
    _status = value;
    notifyListeners();
  }
}

class GoogleRewardedAdService extends RewardedAdService {
  GoogleRewardedAdService({
    TargetPlatform? platform,
    bool? isWeb,
    bool? releaseMode,
    AdNetworkMode? adNetworkMode,
  }) : _platform = platform ?? defaultTargetPlatform,
       _isWeb = isWeb ?? kIsWeb,
       _adNetworkMode =
           adNetworkMode ?? _modeFromEnvironment(releaseMode ?? kReleaseMode);

  static const _androidTestId = 'ca-app-pub-3940256099942544/5224354917';
  static const _iosTestId = 'ca-app-pub-3940256099942544/1712485313';
  static const _androidProductionId = String.fromEnvironment(
    'ADMOB_ANDROID_REWARDED_ID',
  );
  static const _androidUnlockProductionId = String.fromEnvironment(
    'ADMOB_ANDROID_UNLOCK_REWARDED_ID',
  );
  static const _iosProductionId = String.fromEnvironment(
    'ADMOB_IOS_REWARDED_ID',
    defaultValue: 'ca-app-pub-3186852093801241/4511295842',
  );
  static const _iosUnlockProductionId = String.fromEnvironment(
    'ADMOB_IOS_UNLOCK_REWARDED_ID',
    defaultValue: 'ca-app-pub-3186852093801241/6036789642',
  );
  static const _configuredMode = String.fromEnvironment('ADMOB_MODE');

  RewardedAd? _ad;
  RewardedAdStatus _status = RewardedAdStatus.idle;
  bool _initialized = false;
  bool _rewardGranted = false;
  String? _loadedPlacement;
  final TargetPlatform _platform;
  final bool _isWeb;
  final AdNetworkMode _adNetworkMode;

  static AdNetworkMode _modeFromEnvironment(bool releaseMode) {
    return switch (_configuredMode.toLowerCase()) {
      'test' => AdNetworkMode.test,
      'production' => AdNetworkMode.production,
      'disabled' => AdNetworkMode.disabled,
      _ => releaseMode ? AdNetworkMode.disabled : AdNetworkMode.test,
    };
  }

  AdNetworkMode get adNetworkMode => _adNetworkMode;

  @override
  RewardedAdStatus get status =>
      isSupported ? _status : RewardedAdStatus.unsupported;

  @override
  bool get isSupported =>
      !_isWeb &&
      _adNetworkMode != AdNetworkMode.disabled &&
      (_platform == TargetPlatform.android ||
          _platform == TargetPlatform.iOS) &&
      (_adNetworkMode != AdNetworkMode.production ||
          (_platform == TargetPlatform.android
                  ? _androidProductionId
                  : _iosProductionId)
              .isNotEmpty);

  @override
  bool get usesTestAds => _adNetworkMode == AdNetworkMode.test;

  @override
  bool supportsPlacement(String placementName) =>
      _adUnitId(placementName) != null;

  String? _adUnitId(String placementName) {
    if (!isSupported) return null;
    final isAndroid = _platform == TargetPlatform.android;
    if (_adNetworkMode == AdNetworkMode.test) {
      return isAndroid ? _androidTestId : _iosTestId;
    }
    if (_adNetworkMode != AdNetworkMode.production) return null;
    final unlocking = placementName.startsWith('unlock_');
    final productionId = isAndroid
        ? (unlocking ? _androidUnlockProductionId : _androidProductionId)
        : (unlocking ? _iosUnlockProductionId : _iosProductionId);
    return productionId.isEmpty ? null : productionId;
  }

  @override
  Future<void> initialize() async {
    if (!isSupported ||
        status == RewardedAdStatus.ready ||
        status == RewardedAdStatus.loading ||
        status == RewardedAdStatus.initializing ||
        status == RewardedAdStatus.showing) {
      return;
    }
    try {
      if (!_initialized) {
        _setStatus(RewardedAdStatus.initializing);
        await MobileAds.instance.initialize();
        _initialized = true;
        _log('initialization completed');
      }
      await _load('restore_search_energy');
    } on Exception catch (error) {
      _log('initialization failed: $error');
      _setStatus(RewardedAdStatus.failed);
    }
  }

  Future<void> _load(String placementName) async {
    final adUnitId = _adUnitId(placementName);
    if (adUnitId == null) {
      _setStatus(RewardedAdStatus.unsupported);
      return;
    }
    _ad?.dispose();
    _ad = null;
    _loadedPlacement = null;
    _setStatus(RewardedAdStatus.loading);
    _log(usesTestAds ? 'loading test ad' : 'loading production ad');
    final loaded = Completer<void>();
    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loadedPlacement = placementName;
          _setStatus(RewardedAdStatus.ready);
          _log('loaded');
          loaded.complete();
        },
        onAdFailedToLoad: (error) {
          _ad = null;
          _setStatus(RewardedAdStatus.failed);
          _log('load failed: $error');
          loaded.complete();
        },
      ),
    );
    await loaded.future;
  }

  @override
  Future<RewardedAdResult> show({String placementName = 'reward'}) async {
    if (!isSupported) return RewardedAdResult.unavailable;
    if (status == RewardedAdStatus.failed || status == RewardedAdStatus.idle) {
      await initialize();
    }
    if (_adUnitId(placementName) == null) return RewardedAdResult.unavailable;
    if (_loadedPlacement != placementName) await _load(placementName);
    final ad = _ad;
    if (ad == null || status != RewardedAdStatus.ready) {
      return RewardedAdResult.loadFailed;
    }

    _ad = null;
    _loadedPlacement = null;
    _rewardGranted = false;
    _setStatus(RewardedAdStatus.showing);
    _log('showing');
    final completer = Completer<RewardedAdResult>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _log('dismissed');
        if (!completer.isCompleted) {
          completer.complete(
            _rewardGranted
                ? RewardedAdResult.rewarded
                : RewardedAdResult.notRewarded,
          );
        }
        _setStatus(RewardedAdStatus.idle);
        _log('reload started');
        unawaited(initialize());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _log('show failed: $error');
        if (!completer.isCompleted) {
          completer.complete(RewardedAdResult.loadFailed);
        }
        _setStatus(RewardedAdStatus.idle);
        unawaited(initialize());
      },
    );
    ad.show(
      onUserEarnedReward: (_, _) {
        if (_rewardGranted) return;
        _rewardGranted = true;
        _log('reward earned');
      },
    );
    return completer.future;
  }

  void _setStatus(RewardedAdStatus value) {
    if (_status == value) return;
    _status = value;
    notifyListeners();
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[RewardedAd] $message');
  }

  @override
  void dispose() {
    _ad?.dispose();
    _ad = null;
    super.dispose();
  }
}
