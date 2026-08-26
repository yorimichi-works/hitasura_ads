enum RewardPurposeType { restoreSearchEnergy, unlockAd }

class RewardPurpose {
  const RewardPurpose._(this.type, this.adId);

  const RewardPurpose.restoreSearchEnergy()
    : this._(RewardPurposeType.restoreSearchEnergy, null);

  const RewardPurpose.unlockAd(String adId)
    : this._(RewardPurposeType.unlockAd, adId);

  final RewardPurposeType type;
  final String? adId;
}
