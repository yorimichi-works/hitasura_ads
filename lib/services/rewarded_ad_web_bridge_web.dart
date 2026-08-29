import 'dart:js_interop';

@JS('hitasuraRewardedAds.isSupported')
external JSBoolean _isSupported();

@JS('hitasuraRewardedAds.usesTestAds')
external JSBoolean _usesTestAds();

@JS('hitasuraRewardedAds.show')
external JSPromise<JSString> _showRewardedAd(JSString placementName);

class WebRewardedAdBridge {
  bool get isSupported => _isSupported().toDart;
  bool get usesTestAds => _usesTestAds().toDart;

  Future<String> show(String placementName) async {
    final result = await _showRewardedAd(placementName.toJS).toDart;
    return result.toDart;
  }
}
