import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum RewardedAdResult { rewarded, notRewarded, unavailable, loadFailed }

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
  Future<void> initialize();
  Future<RewardedAdResult> show();
}

/// Debug-only stand-in for platforms where the Google Mobile Ads SDK cannot
/// display rewarded ads, notably Flutter Web.
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
  Future<RewardedAdResult> show() async {
    if (!kDebugMode) return RewardedAdResult.unavailable;
    if (_showing || _status != RewardedAdStatus.ready) {
      return RewardedAdResult.loadFailed;
    }
    _showing = true;
    _setStatus(RewardedAdStatus.showing);
    debugPrint('[RewardedAd] WEB DEBUG pseudo reward started');
    await Future<void>.delayed(const Duration(milliseconds: 650));
    _showing = false;
    _setStatus(RewardedAdStatus.ready);
    debugPrint('[RewardedAd] WEB DEBUG pseudo reward earned');
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
  }) : _platform = platform ?? defaultTargetPlatform,
       _isWeb = isWeb ?? kIsWeb,
       _releaseMode = releaseMode ?? kReleaseMode;

  static const _androidTestId = 'ca-app-pub-3940256099942544/5224354917';
  static const _iosTestId = 'ca-app-pub-3940256099942544/1712485313';
  static const _androidProductionId = String.fromEnvironment(
    'ADMOB_ANDROID_REWARDED_ID',
  );
  static const _iosProductionId = String.fromEnvironment(
    'ADMOB_IOS_REWARDED_ID',
  );

  RewardedAd? _ad;
  RewardedAdStatus _status = RewardedAdStatus.idle;
  bool _initialized = false;
  bool _rewardGranted = false;
  final TargetPlatform _platform;
  final bool _isWeb;
  final bool _releaseMode;

  @override
  RewardedAdStatus get status =>
      isSupported ? _status : RewardedAdStatus.unsupported;

  @override
  bool get isSupported =>
      !_isWeb &&
      (_platform == TargetPlatform.android || _platform == TargetPlatform.iOS);

  @override
  bool get usesTestAds => !_releaseMode;

  String? get _adUnitId {
    if (!isSupported) return null;
    final isAndroid = _platform == TargetPlatform.android;
    if (!_releaseMode) return isAndroid ? _androidTestId : _iosTestId;
    final productionId = isAndroid ? _androidProductionId : _iosProductionId;
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
      await _load();
    } on Exception catch (error) {
      _log('initialization failed: $error');
      _setStatus(RewardedAdStatus.failed);
    }
  }

  Future<void> _load() async {
    final adUnitId = _adUnitId;
    if (adUnitId == null) {
      _setStatus(RewardedAdStatus.unsupported);
      return;
    }
    _ad?.dispose();
    _ad = null;
    _setStatus(RewardedAdStatus.loading);
    _log(usesTestAds ? 'loading test ad' : 'loading production ad');
    await RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _setStatus(RewardedAdStatus.ready);
          _log('loaded');
        },
        onAdFailedToLoad: (error) {
          _ad = null;
          _setStatus(RewardedAdStatus.failed);
          _log('load failed: $error');
        },
      ),
    );
  }

  @override
  Future<RewardedAdResult> show() async {
    if (!isSupported) return RewardedAdResult.unavailable;
    if (status == RewardedAdStatus.failed || status == RewardedAdStatus.idle) {
      await initialize();
    }
    final ad = _ad;
    if (ad == null || status != RewardedAdStatus.ready) {
      return RewardedAdResult.loadFailed;
    }

    _ad = null;
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
