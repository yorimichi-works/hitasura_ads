import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onPlay,
    required this.onDebug,
    required this.searchEnergy,
    required this.recoveryCountdown,
    required this.onSponsorReward,
    required this.sponsorLoading,
    required this.sponsorAvailable,
    required this.sponsorCanRequest,
    required this.sponsorStatus,
    required this.sponsorUsesTestAds,
  });

  final VoidCallback onPlay;
  final VoidCallback onDebug;
  final int searchEnergy;
  final String recoveryCountdown;
  final VoidCallback onSponsorReward;
  final bool sponsorLoading;
  final bool sponsorAvailable;
  final bool sponsorCanRequest;
  final String sponsorStatus;
  final bool sponsorUsesTestAds;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 600 || constraints.maxHeight < 620;
        final titleSize = compact ? 34.0 : 48.0;
        final buttonHeight = compact ? 126.0 : 170.0;
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFFFFF3D2)),
            CustomPaint(painter: _AdWallpaperPainter()),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 18 : 40,
                    vertical: compact ? 10 : 22,
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onLongPress: widget.onDebug,
                        child: Text(
                          'ひたすら広告',
                          style: TextStyle(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -2,
                          ),
                        ),
                      ),
                      const Text(
                        '広告を見る。それだけ。',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        '新しい広告を探す  残り ${widget.searchEnergy} / 5',
                        key: const Key('search-energy-label'),
                        style: TextStyle(
                          fontSize: compact ? 17 : 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (widget.searchEnergy < 5 &&
                          widget.sponsorAvailable) ...[
                        const SizedBox(height: 4),
                        Text(
                          '次の回復まで ${widget.recoveryCountdown}',
                          key: const Key('search-recovery-countdown'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                      const SizedBox(height: 10),
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, child) => Transform.scale(
                          scale: 1 + (_pulse.value * .025),
                          child: child,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: buttonHeight,
                          child: FilledButton(
                            key: const Key('play-ad-button'),
                            onPressed: widget.searchEnergy > 0
                                ? widget.onPlay
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFFF2D00),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(
                                  color: Colors.black,
                                  width: 5,
                                ),
                              ),
                              elevation: 10,
                              shadowColor: Colors.black,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '新しい広告を探す',
                                  style: TextStyle(
                                    fontSize: compact ? 27 : 38,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  '151種類からランダム抽選',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (widget.searchEnergy < 5) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          key: const Key('sponsor-reward-button'),
                          onPressed:
                              widget.sponsorLoading || !widget.sponsorCanRequest
                              ? null
                              : widget.onSponsorReward,
                          icon: const Icon(Icons.ondemand_video),
                          label: Text(
                            widget.sponsorLoading || !widget.sponsorCanRequest
                                ? 'スポンサー広告を準備中...'
                                : 'スポンサー広告を見て5/5に回復',
                          ),
                        ),
                      ],
                      if (kDebugMode && widget.sponsorAvailable)
                        Text(
                          'Ad Environment: ${widget.sponsorUsesTestAds ? 'TEST' : 'PRODUCTION'}  •  '
                          'Rewarded Ad: ${widget.sponsorStatus}',
                          key: const Key('rewarded-ad-debug-status'),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                        ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        color: Colors.black,
                        child: const Text(
                          'これはアプリ内で作られた架空の探索広告です',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AdWallpaperPainter extends CustomPainter {
  const _AdWallpaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(151);
    const labels = [
      'AD',
      'PR',
      'SALE!',
      'Sponsored',
      'CHECK!',
      'NEW!',
      '今だけ！',
      '注目！',
    ];
    for (var i = 0; i < 32; i++) {
      final center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final angle = (random.nextDouble() - .5) * .35;
      final painter = TextPainter(
        text: TextSpan(
          text: labels[i % labels.length],
          style: TextStyle(
            color: i.isEven ? const Color(0x1AFF2D00) : const Color(0x220055FF),
            fontSize: 15 + random.nextDouble() * 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      canvas.drawRect(
        Rect.fromLTWH(-8, -5, painter.width + 16, painter.height + 10),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0x22000000),
      );
      painter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
