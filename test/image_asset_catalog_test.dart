import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/data/image_asset_catalog.dart';
import 'package:hitasura_ads/models/image_asset_definition.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads 100 ordered and classified image assets', () async {
    final catalog = await ImageAssetCatalog.load();

    expect(catalog.all, hasLength(100));
    expect(catalog.byId, hasLength(100));
    expect(catalog.ofType(ImageAssetType.adPart), hasLength(40));
    expect(catalog.ofType(ImageAssetType.completeAd), hasLength(20));
    expect(catalog.ofType(ImageAssetType.background), hasLength(40));

    for (var sheet = 1; sheet <= 5; sheet++) {
      final assets = catalog.all
          .where((asset) => asset.sheet == sheet)
          .toList();
      expect(assets, hasLength(20), reason: 'sheet$sheet');
      expect(
        assets.map((asset) => asset.index),
        orderedEquals(List.generate(20, (i) => i + 1)),
      );

      for (final asset in assets) {
        expect(asset.row, ((asset.index - 1) ~/ 5) + 1);
        expect(asset.column, ((asset.index - 1) % 5) + 1);
        expect(asset.width, anyOf(307, 308));
        expect(asset.height, 256);
        expect(File(asset.assetPath).existsSync(), isTrue, reason: asset.id);
      }
      expect(assets.map((asset) => asset.width).reduce((a, b) => a + b), 6144);
    }
  });
}
