import 'dart:math';

import '../models/ad_definition.dart';

class AdSelectionService {
  AdSelectionService({Random? random}) : _random = random ?? Random();

  final Random _random;

  AdDefinition select(
    List<AdDefinition> catalog,
    Set<String> discoveredIds, {
    int? age,
    String? gender,
  }) {
    final allRegular = catalog
        .where((ad) => !ad.isSecret)
        .toList(growable: false);
    final eligible = allRegular
        .where((ad) => isEligible(ad, age: age, gender: gender))
        .toList(growable: false);
    final regular = eligible.isEmpty ? allRegular : eligible;
    final completedRegular = allRegular.every(
      (ad) => discoveredIds.contains(ad.id),
    );
    final secret = catalog.singleWhere((ad) => ad.isSecret);
    if (completedRegular && !discoveredIds.contains(secret.id)) return secret;
    return regular[_random.nextInt(regular.length)];
  }

  bool isEligible(AdDefinition ad, {int? age, String? gender}) {
    return conditionsEligible(
      [...ad.targetTags, ad.unlockCondition],
      age: age,
      gender: gender,
    );
  }

  bool conditionsEligible(Iterable<String> values, {int? age, String? gender}) {
    final conditions = values.join(' ');
    if (conditions.contains('男性') && gender != '男性') return false;
    if (conditions.contains('女性') && gender != '女性') return false;
    final minimum = RegExp(r'(\d+)歳以上').firstMatch(conditions);
    if (minimum != null &&
        (age == null || age < int.parse(minimum.group(1)!))) {
      return false;
    }
    final maximum = RegExp(r'(\d+)歳未満').firstMatch(conditions);
    if (maximum != null &&
        (age == null || age >= int.parse(maximum.group(1)!))) {
      return false;
    }
    return true;
  }
}
