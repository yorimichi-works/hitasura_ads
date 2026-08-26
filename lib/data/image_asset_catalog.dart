import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/image_asset_definition.dart';

class ImageAssetCatalog {
  ImageAssetCatalog._(this.all)
    : byId = {for (final asset in all) asset.id: asset};

  static Future<ImageAssetCatalog> load({AssetBundle? bundle}) =>
      _loadFrom(bundle ?? rootBundle);

  static Future<ImageAssetCatalog> _loadFrom(AssetBundle bundle) async {
    final data = await bundle.load('assets/data/image_asset_catalog.json');
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final decoded = jsonDecode(utf8.decode(bytes)) as List<dynamic>;
    return ImageAssetCatalog._(
      decoded
          .map(
            (item) =>
                ImageAssetDefinition.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  final List<ImageAssetDefinition> all;
  final Map<String, ImageAssetDefinition> byId;

  ImageAssetDefinition operator [](String id) => byId[id]!;

  Iterable<ImageAssetDefinition> ofType(ImageAssetType type) =>
      all.where((asset) => asset.type == type);
}
