import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/ad_definition.dart';

class AdCatalog {
  AdCatalog._(this.all) : byId = {for (final ad in all) ad.id: ad};

  static Future<AdCatalog> load({AssetBundle? bundle}) =>
      _loadFrom(bundle ?? rootBundle);

  static Future<AdCatalog> _loadFrom(AssetBundle bundle) async {
    final data = await bundle.load('assets/data/ad_catalog.json');
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final source = utf8.decode(bytes);
    final decoded = jsonDecode(source) as List<dynamic>;
    return AdCatalog._(
      decoded
          .map((item) => AdDefinition.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final List<AdDefinition> all;
  final Map<String, AdDefinition> byId;

  AdDefinition operator [](String id) => byId[id]!;
}
