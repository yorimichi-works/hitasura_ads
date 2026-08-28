import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/ad_definition.dart';
import '../models/ad_mini_game_definition.dart';
import '../models/ad_visual_assets.dart';

class AdThumbnailConfig {
  const AdThumbnailConfig({
    required this.foregroundAsset,
    required this.secondaryAsset,
    required this.backgroundAsset,
    required this.gameType,
    required this.experienceFormat,
  });

  factory AdThumbnailConfig.forAd(AdDefinition ad) {
    final visual = AdVisualAssets.forAd(ad);
    return AdThumbnailConfig(
      foregroundAsset: visual.foregroundAsset,
      secondaryAsset: visual.secondaryAsset,
      backgroundAsset: visual.backgroundAsset,
      gameType: AdMiniGameDefinition.forAd(ad).type,
      experienceFormat: ad.experienceFormat,
    );
  }

  final String? foregroundAsset;
  final String? secondaryAsset;
  final String backgroundAsset;
  final AdMiniGameType gameType;
  final AdExperienceFormat experienceFormat;
}

class AdThumbnail extends StatelessWidget {
  const AdThumbnail({super.key, required this.ad, required this.discovered});

  final AdDefinition ad;
  final bool discovered;

  @override
  Widget build(BuildContext context) {
    if (!discovered) return _LockedThumbnail(secret: ad.isSecret);
    final config = AdThumbnailConfig.forAd(ad);
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final decodeWidth = max(
            96,
            min(360, (constraints.maxWidth * 2).round()),
          );
          return Stack(
            key: Key('thumbnail-stage-${ad.id}'),
            fit: StackFit.expand,
            children: [
              _ThumbnailImage(
                adNumber: ad.number,
                path: config.backgroundAsset,
                fit: BoxFit.cover,
                cacheWidth: decodeWidth,
              ),
              const ColoredBox(color: Color(0x24000000)),
              if (config.secondaryAsset != null)
                Positioned(
                  top: 7,
                  right: 7,
                  width: constraints.maxWidth * .38,
                  height: constraints.maxHeight * .48,
                  child: _ThumbnailImage(
                    adNumber: ad.number,
                    path: config.secondaryAsset!,
                    fit: BoxFit.contain,
                    cacheWidth: max(64, (decodeWidth * .45).round()),
                  ),
                ),
              Positioned(
                left: 7,
                bottom: 5,
                width: constraints.maxWidth * .56,
                height: constraints.maxHeight * .72,
                child: config.foregroundAsset == null
                    ? _SemanticFallback(ad: ad)
                    : _ThumbnailImage(
                        adNumber: ad.number,
                        path: config.foregroundAsset!,
                        fit: BoxFit.contain,
                        cacheWidth: max(72, (decodeWidth * .65).round()),
                      ),
              ),
              Positioned(
                right: 6,
                bottom: 6,
                child: _ExperienceCue(
                  gameType: config.gameType,
                  format: config.experienceFormat,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ThumbnailImage extends StatelessWidget {
  const _ThumbnailImage({
    required this.adNumber,
    required this.path,
    required this.fit,
    required this.cacheWidth,
  });

  final int adNumber;
  final String path;
  final BoxFit fit;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) => Image.asset(
    path,
    fit: fit,
    cacheWidth: cacheWidth,
    filterQuality: FilterQuality.medium,
    errorBuilder: (_, error, _) {
      if (kDebugMode) {
        debugPrint('Thumbnail No.$adNumber: failed to load $path: $error');
      }
      return const ColoredBox(
        color: Color(0x33000000),
        child: Icon(Icons.image_not_supported_outlined, color: Colors.white70),
      );
    },
  );
}

class _SemanticFallback extends StatelessWidget {
  const _SemanticFallback({required this.ad});
  final AdDefinition ad;

  @override
  Widget build(BuildContext context) {
    final icon = switch (ad.number) {
      58 => Icons.local_drink,
      61 || 62 => Icons.directions_car,
      _ => switch (ad.category) {
        '古のWeb' => Icons.ads_click,
        '意味不明' => Icons.campaign,
        _ => Icons.sports_esports,
      },
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .48),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 38),
    );
  }
}

class _ExperienceCue extends StatelessWidget {
  const _ExperienceCue({required this.gameType, required this.format});
  final AdMiniGameType gameType;
  final AdExperienceFormat format;

  @override
  Widget build(BuildContext context) => Container(
    key: Key(
      'thumbnail-cue-${format == AdExperienceFormat.playable ? gameType.name : format.name}',
    ),
    width: 42,
    height: 42,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .78),
      border: Border.all(color: Colors.white, width: 2),
      shape: BoxShape.circle,
    ),
    child: format == AdExperienceFormat.playable
        ? _gameIcon(gameType)
        : Icon(_formatIcon(format), color: Colors.white, size: 22),
  );

  Widget _gameIcon(AdMiniGameType type) => switch (type) {
    AdMiniGameType.pinPull => const Icon(
      Icons.horizontal_rule,
      color: Colors.white,
    ),
    AdMiniGameType.drawPath => const Icon(Icons.gesture, color: Colors.white),
    AdMiniGameType.dragSort => const Icon(Icons.open_with, color: Colors.white),
    AdMiniGameType.numberGate => const Text(
      'x2',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
    ),
    AdMiniGameType.timing || AdMiniGameType.countdownStop => const Icon(
      Icons.timer,
      color: Colors.white,
    ),
    AdMiniGameType.scratch => const Icon(
      Icons.auto_fix_high,
      color: Colors.white,
    ),
    AdMiniGameType.packOpen => const Icon(Icons.swipe_up, color: Colors.white),
    AdMiniGameType.choice => const Icon(Icons.rule, color: Colors.white),
    AdMiniGameType.finale => const Icon(
      Icons.workspace_premium,
      color: Colors.amber,
    ),
    AdMiniGameType.tapChallenge ||
    AdMiniGameType.reveal => const Icon(Icons.touch_app, color: Colors.white),
  };

  IconData _formatIcon(AdExperienceFormat value) => switch (value) {
    AdExperienceFormat.productDemo => Icons.shopping_bag,
    AdExperienceFormat.factCheck => Icons.fact_check,
    AdExperienceFormat.personalityQuiz => Icons.psychology,
    AdExperienceFormat.storyReel => Icons.smart_display,
    AdExperienceFormat.newsBulletin => Icons.newspaper,
    AdExperienceFormat.systemScan => Icons.health_and_safety,
    AdExperienceFormat.webTrap => Icons.ads_click,
    AdExperienceFormat.playable => Icons.sports_esports,
  };
}

class _LockedThumbnail extends StatelessWidget {
  const _LockedThumbnail({required this.secret});
  final bool secret;

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: Key(secret ? 'thumbnail-secret-locked' : 'thumbnail-locked'),
    color: secret ? const Color(0xFF080808) : const Color(0xFFBBB8B1),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Icon(
          Icons.campaign,
          size: 72,
          color: secret ? Colors.amber.withValues(alpha: .12) : Colors.black12,
        ),
        Center(
          child: Text(
            secret ? 'SECRET' : '?',
            style: TextStyle(
              color: secret ? Colors.amber : Colors.white,
              fontSize: secret ? 16 : 42,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}
