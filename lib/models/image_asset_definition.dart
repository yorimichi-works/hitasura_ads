enum ImageAssetType { adPart, completeAd, background }

class ImageAssetDefinition {
  const ImageAssetDefinition({
    required this.id,
    required this.type,
    required this.assetPath,
    required this.sheet,
    required this.index,
    required this.row,
    required this.column,
    required this.width,
    required this.height,
  });

  factory ImageAssetDefinition.fromJson(Map<String, dynamic> json) {
    return ImageAssetDefinition(
      id: json['id'] as String,
      type: ImageAssetType.values.byName(json['type'] as String),
      assetPath: json['assetPath'] as String,
      sheet: json['sheet'] as int,
      index: json['index'] as int,
      row: json['row'] as int,
      column: json['column'] as int,
      width: json['width'] as int,
      height: json['height'] as int,
    );
  }

  final String id;
  final ImageAssetType type;
  final String assetPath;
  final int sheet;
  final int index;
  final int row;
  final int column;
  final int width;
  final int height;
}
