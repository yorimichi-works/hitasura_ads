# Rewarded Ad Test Environment

## Reward routes

| Purpose | Entry point | Reward condition | Result |
| --- | --- | --- | --- |
| Search recovery | Home sponsor button | `onUserEarnedReward` | Search energy becomes 5/5 |
| Catalog unlock | Locked No.1-150 detail | `onUserEarnedReward` | Only the selected ad is discovered |

`RewardPurpose.restoreSearchEnergy` and `RewardPurpose.unlockAd(adId)` remain
separate through the full UI flow. No.151 has no reward button and is also
rejected by `AppController.unlockAdWithReward`.

## Environments

- Android debug: Google official rewarded test ID
  `ca-app-pub-3940256099942544/5224354917`
- iOS debug: Google official rewarded test ID
  `ca-app-pub-3940256099942544/1712485313`
- Web debug: clearly labelled in-app pseudo reward using the same reward
  application path
- Release: no debug controls or Web pseudo reward

## Debug controls

Long-press the home title in a debug build to open the test environment.

- Set search energy to 0/5, 1/5, or 5/5
- Set the entire catalog locked
- Set the entire catalog discovered
- Reset a specific discovered ad to locked
- Force-play a selected ad

These controls are guarded by `kDebugMode` and persist through the normal app
store so restart behavior can be checked.

## Automated coverage

- Search consumption, 20-minute recovery, upper bound, and persistence
- Rewarded search refill and incomplete-view no-reward behavior
- Selected catalog unlock without changing search energy
- No.1 and No.150 unlock support; No.151 rejection
- Web debug pseudo reward concurrency guard and ready-state restoration
- Debug catalog bulk and individual state controls

Local `dart analyze` passes. Flutter tests and release Web build are also run by
the GitHub Pages workflow before deployment.
