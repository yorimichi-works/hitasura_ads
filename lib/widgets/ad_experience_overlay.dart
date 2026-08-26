import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/ad_definition.dart';
import '../models/ad_visual_assets.dart';
import '../services/ad_audio_manager.dart';
import 'ad_mini_game.dart';

class AdPlaybackResult {
  const AdPlaybackResult(this.activeSeconds);
  final int activeSeconds;
}

class AdExperienceOverlay extends StatefulWidget {
  const AdExperienceOverlay({
    super.key,
    required this.ad,
    this.soundEffectsEnabled = true,
  });

  final AdDefinition ad;
  final bool soundEffectsEnabled;

  @override
  State<AdExperienceOverlay> createState() => _AdExperienceOverlayState();
}

class _AdExperienceOverlayState extends State<AdExperienceOverlay>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  Timer? _timer;
  late int _remaining = widget.ad.minimumDisplaySeconds;
  int _activeSeconds = 0;
  bool _foreground = true;
  bool _interacted = false;
  int _scratchProgress = 0;
  late final AdAudioManager _audio = AdAudioManager();
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..repeat(reverse: true);
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.ad.isSecret) {
      unawaited(
        _audio.playSecretSequence(
          widget.ad,
          soundEffectsEnabled: widget.soundEffectsEnabled,
        ),
      );
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_foreground || !mounted) return;
      setState(() {
        _activeSeconds += 1;
        if (_remaining > 0) _remaining -= 1;
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _animation.dispose();
    _spin.dispose();
    unawaited(_audio.dispose());
    super.dispose();
  }

  void _interact() {
    unawaited(
      _audio.playInteraction(widget.ad, enabled: widget.soundEffectsEnabled),
    );
    if (widget.ad.interactionType == AdInteractionType.scratch) {
      setState(() {
        _scratchProgress = min(100, _scratchProgress + 34);
        _interacted = _scratchProgress >= 100;
      });
      return;
    }
    if (widget.ad.interactionType == AdInteractionType.spin) {
      _spin.forward(from: 0).whenComplete(() {
        if (mounted) setState(() => _interacted = true);
      });
      return;
    }
    setState(() => _interacted = true);
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final visualAssets = AdVisualAssets.forAd(ad);
    return PopScope(
      canPop: _remaining == 0,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          minimum: const EdgeInsets.all(10),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 600;
                  return Container(
                    width: double.infinity,
                    height: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: _backgroundFor(ad),
                      border: Border.all(
                        color: ad.isSecret ? Colors.amber : Colors.white,
                        width: ad.isSecret ? 5 : 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ad.accentColor.withValues(alpha: .6),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            visualAssets.backgroundAsset,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                        Positioned.fill(
                          child: ColoredBox(
                            color: _backgroundFor(ad).withValues(alpha: .62),
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _AdBurstPainter(
                              color: ad.accentColor,
                              seed: ad.number,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            compact ? 14 : 24,
                            compact ? 12 : 20,
                            compact ? 14 : 24,
                            compact ? 12 : 20,
                          ),
                          child: Column(
                            children: [
                              _AdHeader(ad: ad),
                              SizedBox(height: compact ? 8 : 16),
                              Expanded(
                                child: Column(
                                  children: [
                                    Flexible(
                                      flex: compact ? 1 : 2,
                                      child: AnimatedBuilder(
                                        animation: Listenable.merge([
                                          _animation,
                                          _spin,
                                        ]),
                                        builder: (context, _) => FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: SizedBox(
                                            width: 620,
                                            height: 240,
                                            child: _AnimatedExperience(
                                              ad: ad,
                                              pulse: _animation.value,
                                              spin: _spin.value,
                                              interacted: _interacted,
                                              scratchProgress: _scratchProgress,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      flex: 3,
                                      child: AdMiniGame(
                                        ad: ad,
                                        onInteraction: _interact,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: compact ? 8 : 12),
                              if (_remaining > 0)
                                Semantics(
                                  liveRegion: true,
                                  child: Container(
                                    key: const Key('ad-countdown'),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 10,
                                    ),
                                    color: Colors.black,
                                    child: Text(
                                      '広告終了まで あと $_remaining 秒',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                OutlinedButton.icon(
                                  key: const Key('close-ad-button'),
                                  onPressed: () => Navigator.pop(
                                    context,
                                    AdPlaybackResult(_activeSeconds),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    minimumSize: const Size(
                                      double.infinity,
                                      52,
                                    ),
                                    side: const BorderSide(width: 3),
                                  ),
                                  icon: const Icon(Icons.close),
                                  label: const Text(
                                    '広告を終了する',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _backgroundFor(AdDefinition ad) => switch (ad.displayType) {
  AdDisplayType.retro => const Color(0xFF000080),
  AdDisplayType.sale => const Color(0xFFFFFF00),
  AdDisplayType.product => const Color(0xFFFFF3E0),
  AdDisplayType.review => const Color(0xFFE8F5E9),
  AdDisplayType.rescue => const Color(0xFF263238),
  AdDisplayType.gate => const Color(0xFF03A9F4),
  AdDisplayType.puzzle => const Color(0xFF7E57C2),
  AdDisplayType.makeover => const Color(0xFFF8BBD0),
  AdDisplayType.merge => const Color(0xFF00695C),
  AdDisplayType.slot => const Color(0xFF7F0000),
  AdDisplayType.roulette => const Color(0xFF004D40),
  AdDisplayType.scratch => const Color(0xFF455A64),
  AdDisplayType.pack => const Color(0xFF311B92),
  AdDisplayType.diagnosis => const Color(0xFFE3F2FD),
  AdDisplayType.social => const Color(0xFF212121),
  AdDisplayType.warning => const Color(0xFFFFE000),
  AdDisplayType.meta => const Color(0xFFF5F5F5),
  AdDisplayType.legendary => const Color(0xFF3E2723),
  AdDisplayType.secret => const Color(0xFF050509),
};

Color _foregroundFor(AdDefinition ad) => switch (ad.displayType) {
  AdDisplayType.product ||
  AdDisplayType.review ||
  AdDisplayType.makeover ||
  AdDisplayType.diagnosis ||
  AdDisplayType.warning ||
  AdDisplayType.meta => Colors.black,
  _ => Colors.white,
};

Color _contrast(Color color) =>
    color.computeLuminance() > .45 ? Colors.black : Colors.white;

class _AdHeader extends StatelessWidget {
  const _AdHeader({required this.ad});
  final AdDefinition ad;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        color: Colors.black,
        child: const Text(
          '架空広告',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        ad.displayNumber,
        style: TextStyle(
          color: _foregroundFor(ad),
          fontWeight: FontWeight.w900,
        ),
      ),
      const Spacer(),
      Text(
        ad.rarity,
        style: TextStyle(
          color: ad.isRare ? ad.accentColor : _foregroundFor(ad),
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

class _AnimatedExperience extends StatelessWidget {
  const _AnimatedExperience({
    required this.ad,
    required this.pulse,
    required this.spin,
    required this.interacted,
    required this.scratchProgress,
  });

  final AdDefinition ad;
  final double pulse;
  final double spin;
  final bool interacted;
  final int scratchProgress;

  @override
  Widget build(BuildContext context) {
    final transform = Matrix4.identity();
    switch (ad.animationPreset) {
      case AdAnimationPreset.shake:
        transform.translateByDouble(sin(pulse * pi * 4) * 5, 0, 0, 1);
      case AdAnimationPreset.pulse || AdAnimationPreset.bounce:
        transform.scaleByDouble(1 + pulse * .05, 1 + pulse * .05, 1, 1);
      case AdAnimationPreset.rotate:
        transform.rotateZ((pulse - .5) * .08);
      case AdAnimationPreset.slide:
        transform.translateByDouble((pulse - .5) * 18, 0, 0, 1);
      case AdAnimationPreset.blink ||
          AdAnimationPreset.glow ||
          AdAnimationPreset.confetti:
        break;
    }
    return Transform(
      alignment: Alignment.center,
      transform: transform,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: _ExperienceVisual(
              ad: ad,
              spin: spin,
              interacted: interacted,
              scratchProgress: scratchProgress,
            ),
          ),
          if (ad.fixedValues.isNotEmpty) ...[
            const SizedBox(height: 8),
            _FixedFacts(ad: ad),
          ],
          const SizedBox(height: 12),
          Text(
            ad.headline,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _foregroundFor(ad),
              fontSize: 28,
              height: 1.05,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(color: ad.accentColor, offset: const Offset(2, 2)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ad.body,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _foregroundFor(ad),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FixedFacts extends StatelessWidget {
  const _FixedFacts({required this.ad});

  final AdDefinition ad;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final value in ad.fixedValues.values.toSet())
        Container(
          key: Key('fixed-${ad.id}-$value'),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: ad.accentColor, width: 2),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
    ],
  );
}

class _ExperienceVisual extends StatelessWidget {
  const _ExperienceVisual({
    required this.ad,
    required this.spin,
    required this.interacted,
    required this.scratchProgress,
  });
  final AdDefinition ad;
  final double spin;
  final bool interacted;
  final int scratchProgress;

  @override
  Widget build(BuildContext context) {
    return switch (ad.displayType) {
      AdDisplayType.rescue => _RescueVisual(ad: ad, solved: interacted),
      AdDisplayType.gate => _GateVisual(ad: ad, solved: interacted),
      AdDisplayType.slot || AdDisplayType.roulette => _SpinVisual(
        ad: ad,
        spin: spin,
        solved: interacted,
      ),
      AdDisplayType.scratch => _ScratchVisual(
        progress: scratchProgress,
        color: ad.accentColor,
      ),
      AdDisplayType.pack => _PackVisual(ad: ad, opened: interacted),
      AdDisplayType.secret => _SecretVisual(pulse: spin + .5),
      _ => _PosterVisual(ad: ad, interacted: interacted),
    };
  }
}

class _PosterVisual extends StatelessWidget {
  const _PosterVisual({required this.ad, required this.interacted});
  final AdDefinition ad;
  final bool interacted;

  @override
  Widget build(BuildContext context) {
    final visual = AdVisualAssets.forAd(ad);
    return Container(
      width: 150,
      height: 100,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ad.accentColor,
        border: Border.all(width: 5),
        shape: ad.number.isEven ? BoxShape.rectangle : BoxShape.circle,
      ),
      child: visual.foregroundAsset == null
          ? Text(
              interacted ? '完了!?' : ad.symbol,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _contrast(ad.accentColor),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            )
          : AnimatedScale(
              duration: const Duration(milliseconds: 220),
              scale: interacted ? 1.12 : 1,
              child: Image.asset(
                visual.foregroundAsset!,
                fit: BoxFit.contain,
                errorBuilder: (_, error, _) {
                  assert(() {
                    debugPrint(
                      'Ad No.${ad.number}: failed to load '
                      '${visual.foregroundAsset}: $error',
                    );
                    return true;
                  }());
                  return const Icon(Icons.image_not_supported, size: 48);
                },
              ),
            ),
    );
  }
}

class _RescueVisual extends StatelessWidget {
  const _RescueVisual({required this.ad, required this.solved});
  final AdDefinition ad;
  final bool solved;

  @override
  Widget build(BuildContext context) {
    final visual = AdVisualAssets.forAd(ad);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            solved ? '操作完了' : ad.symbol,
            style: TextStyle(
              fontSize: 42,
              color: ad.accentColor,
              fontWeight: FontWeight.w900,
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 18),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: visual.foregroundAsset == null
                ? Text(
                    solved ? 'SAFE' : '!?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                : AnimatedScale(
                    duration: const Duration(milliseconds: 220),
                    scale: solved ? 1.12 : 1,
                    child: Image.asset(
                      visual.foregroundAsset!,
                      width: 84,
                      height: 84,
                      fit: BoxFit.contain,
                    ),
                  ),
          ),
          Text(
            solved ? '宝' : 'PIN',
            style: TextStyle(
              fontSize: 34,
              color: ad.accentColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _GateVisual extends StatelessWidget {
  const _GateVisual({required this.ad, required this.solved});
  final AdDefinition ad;
  final bool solved;

  @override
  Widget build(BuildContext context) {
    final labels = ad.fixedValues.isEmpty
        ? const ['＋？', '×？']
        : ad.fixedValues.values.toSet().take(3).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            for (final label in labels)
              Container(
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: label.startsWith('＋') ? Colors.green : Colors.red,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
        Text(
          solved ? 'ゲート通過！' : 'どれを選ぶ？',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SpinVisual extends StatelessWidget {
  const _SpinVisual({
    required this.ad,
    required this.spin,
    required this.solved,
  });
  final AdDefinition ad;
  final double spin;
  final bool solved;

  @override
  Widget build(BuildContext context) {
    final configuredReels = [
      ad.fixedValues['reelA'],
      ad.fixedValues['reelB'],
      ad.fixedValues['reelC'],
    ].whereType<String>().toList();
    final symbols = configuredReels.length == 3
        ? configuredReels
        : solved
        ? ['7', '7', '謎']
        : ['★', ad.symbol, '7'];
    return Transform.rotate(
      angle: ad.displayType == AdDisplayType.roulette ? spin * pi * 6 : 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 68,
              height: 76,
              margin: const EdgeInsets.all(5),
              alignment: Alignment.center,
              color: Colors.white,
              child: Text(
                spin > 0 && spin < 1
                    ? '${(spin * 99).floor() % 10}'
                    : symbols[i],
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScratchVisual extends StatelessWidget {
  const _ScratchVisual({required this.progress, required this.color});
  final int progress;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 230,
    height: 100,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Color.lerp(Colors.grey, color, progress / 100),
      border: Border.all(color: Colors.white, width: 4),
    ),
    child: Text(
      progress >= 100 ? '広告でした！' : '？？？\n$progress%',
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _PackVisual extends StatelessWidget {
  const _PackVisual({required this.ad, required this.opened});
  final AdDefinition ad;
  final bool opened;

  @override
  Widget build(BuildContext context) => Container(
    width: opened ? 180 : 130,
    height: 150,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [ad.accentColor, Colors.black]),
      border: Border.all(color: Colors.white, width: 5),
      borderRadius: BorderRadius.circular(opened ? 4 : 18),
    ),
    child: Text(
      opened
          ? '${ad.fixedValues['cardRarity'] ?? ad.fixedValues['reveal'] ?? 'R'}\n広告カード'
          : '${ad.fixedValues['packClaim'] ?? 'SSR!?'}\n広告パック',
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _SecretVisual extends StatelessWidget {
  const _SecretVisual({required this.pulse});
  final double pulse;

  @override
  Widget build(BuildContext context) => Container(
    width: 190,
    height: 190,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const RadialGradient(
        colors: [Colors.amber, Color(0xFF9C6B00), Colors.black],
      ),
      boxShadow: [
        BoxShadow(color: Colors.amber.withValues(alpha: .7), blurRadius: 35),
      ],
    ),
    child: const Text(
      'AD\nGON',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontSize: 38,
        fontWeight: FontWeight.w900,
        letterSpacing: 4,
      ),
    ),
  );
}

class _AdBurstPainter extends CustomPainter {
  const _AdBurstPainter({required this.color, required this.seed});
  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    final paint = Paint()..color = color.withValues(alpha: .18);
    for (var i = 0; i < 30; i++) {
      final center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final radius = 3 + random.nextDouble() * 18;
      if (i.isEven) {
        canvas.drawCircle(center, radius, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: center,
            width: radius * 2,
            height: radius / 2,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AdBurstPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.seed != seed;
}
