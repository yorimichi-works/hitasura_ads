import 'dart:math';

import '../models/ad_definition.dart';

class AdSelectionService {
  AdSelectionService({Random? random}) : _random = random ?? Random();

  final Random _random;

  AdDefinition select(List<AdDefinition> catalog, Set<String> discoveredIds) {
    final regular = catalog.where((ad) => !ad.isSecret).toList(growable: false);
    final completedRegular = regular.every(
      (ad) => discoveredIds.contains(ad.id),
    );
    final secret = catalog.singleWhere((ad) => ad.isSecret);
    if (completedRegular && !discoveredIds.contains(secret.id)) return secret;
    return regular[_random.nextInt(regular.length)];
  }
}
