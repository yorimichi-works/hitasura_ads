import 'package:flutter/material.dart';

enum AdDisplayType {
  retro,
  sale,
  product,
  review,
  rescue,
  gate,
  puzzle,
  makeover,
  merge,
  slot,
  roulette,
  scratch,
  pack,
  diagnosis,
  social,
  warning,
  meta,
  legendary,
  secret,
}

enum AdInteractionType {
  none,
  tap,
  choice,
  pinPull,
  gate,
  drag,
  spin,
  scratch,
  packOpen,
}

enum AdAnimationPreset {
  blink,
  pulse,
  shake,
  bounce,
  slide,
  rotate,
  glow,
  confetti,
}

class AdDefinition {
  const AdDefinition({
    required this.id,
    required this.number,
    required this.name,
    required this.description,
    required this.category,
    required this.rarity,
    required this.displayType,
    required this.minimumDisplaySeconds,
    required this.headline,
    required this.body,
    required this.ctaText,
    required this.animationPreset,
    required this.interactionType,
    required this.symbol,
    required this.accentColor,
    required this.targetTags,
    required this.unlockCondition,
  });

  factory AdDefinition.fromJson(Map<String, dynamic> json) {
    return AdDefinition(
      id: json['id'] as String,
      number: json['number'] as int,
      name: json['name'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      rarity: json['rarity'] as String,
      displayType: AdDisplayType.values.byName(json['displayType'] as String),
      minimumDisplaySeconds: json['minimumDisplaySeconds'] as int,
      headline: json['headline'] as String,
      body: json['body'] as String,
      ctaText: json['ctaText'] as String,
      animationPreset: AdAnimationPreset.values.byName(
        json['animationPreset'] as String,
      ),
      interactionType: AdInteractionType.values.byName(
        json['interactionType'] as String,
      ),
      symbol: json['symbol'] as String,
      accentColor: Color(int.parse(json['accentColor'] as String, radix: 16)),
      targetTags: List<String>.from(json['targetTags'] as List<dynamic>),
      unlockCondition: json['unlockCondition'] as String,
    );
  }

  final String id;
  final int number;
  final String name;
  final String description;
  final String category;
  final String rarity;
  final AdDisplayType displayType;
  final int minimumDisplaySeconds;
  final String headline;
  final String body;
  final String ctaText;
  final AdAnimationPreset animationPreset;
  final AdInteractionType interactionType;
  final String symbol;
  final Color accentColor;
  final List<String> targetTags;
  final String unlockCondition;

  bool get isSecret => number == 151;
  bool get isRare =>
      rarity == 'RARE' || rarity == 'SUPER RARE' || rarity == 'SECRET';
  String get displayNumber => 'No.${number.toString().padLeft(3, '0')}';
}
