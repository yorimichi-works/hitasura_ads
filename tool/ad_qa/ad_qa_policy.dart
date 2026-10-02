// Only the isolated Debug simulator target and its tests import this file.
const iosRewardedDemoUnit = 'ca-app-pub-3940256099942544/1712485313';

void requireRewardedQaEnvironment({
  required bool debug,
  required bool ios,
  required bool explicitlyEnabled,
  required bool nativeSimulator,
  required String adMode,
}) {
  if (!debug ||
      !ios ||
      !explicitlyEnabled ||
      !nativeSimulator ||
      adMode != 'test') {
    throw StateError(
      'Rewarded QA requires an enabled Debug iOS simulator and ADMOB_MODE=test',
    );
  }
}

/// These messages originate in the unchanged shipping service's SDK callbacks.
/// "showing" is a request, not an onAdShowedFullScreenContent callback.
String? sdkStageForLog(String? message) => switch (message) {
  '[RewardedAd] initialization completed' => 'sdk_initialized',
  '[RewardedAd] loaded' => 'sdk_load_callback',
  '[RewardedAd] showing' => 'sdk_show_requested',
  '[RewardedAd] reward earned' => 'sdk_reward_callback',
  '[RewardedAd] dismissed' => 'sdk_dismiss_callback',
  final String text when text.startsWith('[RewardedAd] load failed:') =>
    'sdk_load_failed',
  final String text when text.startsWith('[RewardedAd] show failed:') =>
    'sdk_show_failed',
  final String text
      when text.startsWith('[RewardedAd] initialization failed:') =>
    'sdk_initialization_failed',
  final String text when text.startsWith('[RewardedAd] ad request failed:') =>
    'sdk_request_failed',
  _ => null,
};
