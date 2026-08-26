import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/ad_definition.dart';
import '../models/ad_mini_game_definition.dart';
import '../models/ad_visual_assets.dart';

enum MiniGamePhase { notStarted, playing, success, failure }

class AdMiniGame extends StatefulWidget {
  const AdMiniGame({super.key, required this.ad, required this.onInteraction});

  final AdDefinition ad;
  final VoidCallback onInteraction;

  @override
  State<AdMiniGame> createState() => _AdMiniGameState();
}

class _AdMiniGameState extends State<AdMiniGame>
    with SingleTickerProviderStateMixin {
  late final AdMiniGameDefinition game = AdMiniGameDefinition.forAd(widget.ad);
  late final AdVisualAssets visualAssets = AdVisualAssets.forAd(widget.ad);
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);
  MiniGamePhase _phase = MiniGamePhase.notStarted;
  int _progress = 0;
  int _countdown = 5;
  Timer? _countdownTimer;
  final List<Offset> _line = [];
  final Set<int> _scratched = {};
  final Set<int> _removedPins = {};
  double _swipeDistance = 0;

  @override
  void initState() {
    super.initState();
    if (game.type == AdMiniGameType.countdownStop) _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _motion.dispose();
    super.dispose();
  }

  void _start() {
    if (_phase == MiniGamePhase.notStarted) {
      setState(() => _phase = MiniGamePhase.playing);
      widget.onInteraction();
    }
  }

  void _finish(bool success) {
    if (_phase == MiniGamePhase.success || _phase == MiniGamePhase.failure) {
      return;
    }
    _start();
    setState(() {
      _phase = success ? MiniGamePhase.success : MiniGamePhase.failure;
    });
    if (success) _motion.stop();
  }

  void _reset() {
    _countdownTimer?.cancel();
    setState(() {
      _phase = MiniGamePhase.notStarted;
      _progress = 0;
      _countdown = 5;
      _line.clear();
      _scratched.clear();
      _removedPins.clear();
      _swipeDistance = 0;
    });
    _motion.repeat(reverse: true);
    if (game.type == AdMiniGameType.countdownStop) _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 650), (_) {
      if (!mounted || _phase == MiniGamePhase.success) return;
      setState(() => _countdown = _countdown <= 0 ? 5 : _countdown - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          game.instruction,
          key: const Key('mini-game-instruction'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: AdGameStage(
            ad: widget.ad,
            backgroundAsset: visualAssets.backgroundAsset,
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                fit: StackFit.expand,
                children: [
                  _buildGame(constraints),
                  if (game.assetPath != null && _needsReactiveActor)
                    IgnorePointer(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: _ReactiveActor(
                          path: game.assetPath!,
                          adNumber: widget.ad.number,
                          phase: _phase,
                          maxHeight: min(92, constraints.maxHeight * .38),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: switch (_phase) {
            MiniGamePhase.success => _ResultBanner(
              key: const Key('mini-game-success'),
              color: Colors.green,
              text: 'CLEAR! ${widget.ad.resultText}',
              onRetry: _reset,
            ),
            MiniGamePhase.failure => _ResultBanner(
              key: const Key('mini-game-failure'),
              color: Colors.red,
              text: '失敗！ ${game.failureCondition}',
              onRetry: _reset,
            ),
            _ => const SizedBox(
              key: Key('mini-game-playing'),
              height: 42,
              child: Center(child: Text('操作して結果を変えよう')),
            ),
          },
        ),
      ],
    );
  }

  Widget _buildGame(BoxConstraints constraints) => switch (game.type) {
    AdMiniGameType.tapChallenge => _tapGame(),
    AdMiniGameType.choice => _choiceGame(),
    AdMiniGameType.pinPull => _pinGame(),
    AdMiniGameType.numberGate => _gateGame(),
    AdMiniGameType.drawPath => _drawGame(constraints),
    AdMiniGameType.dragSort => _dragGame(),
    AdMiniGameType.timing => _timingGame(),
    AdMiniGameType.scratch => _scratchGame(constraints),
    AdMiniGameType.packOpen => _packGame(),
    AdMiniGameType.countdownStop => _countdownGame(),
    AdMiniGameType.reveal => _revealGame(),
    AdMiniGameType.finale => _finaleGame(),
  };

  bool get _needsReactiveActor => switch (game.type) {
    AdMiniGameType.numberGate ||
    AdMiniGameType.timing ||
    AdMiniGameType.scratch ||
    AdMiniGameType.countdownStop ||
    AdMiniGameType.finale => true,
    _ => false,
  };

  Widget _tapGame() {
    final alignments = [
      const Alignment(-.7, -.4),
      const Alignment(.65, -.2),
      const Alignment(0, .55),
    ];
    return Stack(
      children: [
        AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          alignment: alignments[min(_progress, 2)],
          child: Semantics(
            button: true,
            label: '光る対象',
            child: InkResponse(
              key: const Key('mini-game-tap-target'),
              radius: 42,
              onTap: () {
                _start();
                setState(() => _progress++);
                if (_progress >= 3) _finish(true);
              },
              child: AnimatedScale(
                duration: const Duration(milliseconds: 140),
                scale: _phase == MiniGamePhase.playing ? 1.08 : 1,
                child: Container(
                  width: game.assetPath == null ? 72 : 96,
                  height: game.assetPath == null ? 72 : 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: game.assetPath == null
                        ? widget.ad.accentColor
                        : Colors.white.withValues(alpha: .2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: game.assetPath == null
                      ? Text(
                          '${min(_progress + 1, 3)}/3',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        )
                      : _Asset(
                          path: game.assetPath!,
                          adNumber: widget.ad.number,
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _choiceGame() {
    final correct = widget.ad.number.isEven ? 0 : 1;
    return Row(
      children: [
        for (var i = 0; i < 2; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: FilledButton(
                key: Key('mini-game-choice-$i'),
                onPressed:
                    _phase == MiniGamePhase.success ||
                        _phase == MiniGamePhase.failure
                    ? null
                    : () => _finish(i == correct),
                style: FilledButton.styleFrom(
                  backgroundColor: i == 0 ? Colors.blue : Colors.orange,
                  minimumSize: const Size.fromHeight(130),
                  shape: const RoundedRectangleBorder(),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child:
                          (i == 0
                                  ? game.assetPath
                                  : visualAssets.secondaryAsset) !=
                              null
                          ? _Asset(
                              path: (i == 0
                                  ? game.assetPath
                                  : visualAssets.secondaryAsset)!,
                              adNumber: widget.ad.number,
                            )
                          : Icon(
                              i == 0 ? Icons.checkroom : Icons.auto_fix_high,
                              size: 42,
                            ),
                    ),
                    Text(i == 0 ? 'Aを選ぶ' : 'Bを選ぶ'),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _pinGame() {
    final firstSafe = widget.ad.number % 3;
    final order = [firstSafe, (firstSafe + 1) % 3, (firstSafe + 2) % 3];
    return Row(
      children: [
        Expanded(
          child: game.assetPath == null
              ? const Icon(Icons.person, size: 90)
              : _Asset(path: game.assetPath!, adNumber: widget.ad.number),
        ),
        if (visualAssets.secondaryAsset != null)
          Expanded(
            child: _Asset(
              path: visualAssets.secondaryAsset!,
              adNumber: widget.ad.number,
            ),
          ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < 3; i++)
                AnimatedSlide(
                  duration: const Duration(milliseconds: 260),
                  offset: _removedPins.contains(i)
                      ? const Offset(1.6, 0)
                      : Offset.zero,
                  child: SizedBox(
                    width: 150,
                    height: 48,
                    child: FilledButton.icon(
                      key: Key('mini-game-pin-$i'),
                      onPressed:
                          _removedPins.contains(i) ||
                              _phase == MiniGamePhase.failure ||
                              _phase == MiniGamePhase.success
                          ? null
                          : () {
                              _start();
                              final expected = order[_removedPins.length];
                              if (i != expected) {
                                _finish(false);
                                return;
                              }
                              setState(() => _removedPins.add(i));
                              if (_removedPins.length == 3) _finish(true);
                            },
                      icon: const Icon(Icons.horizontal_rule),
                      label: Text('PIN ${i + 1}'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gateGame() {
    final labels = widget.ad.fixedValues.values.toSet().take(2).toList();
    while (labels.length < 2) {
      labels.add(labels.isEmpty ? '＋10' : '×2');
    }
    final values = labels.map(_gateValue).toList();
    final correct = values[0] >= values[1] ? 0 : 1;
    return Row(
      children: [
        for (var i = 0; i < 2; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: InkWell(
                key: Key('mini-game-gate-$i'),
                onTap: () => _finish(i == correct),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == 0 ? Colors.green : Colors.deepOrange,
                    border: Border.all(color: Colors.white, width: 5),
                  ),
                  child: Text(
                    labels[i],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  int _gateValue(String label) {
    final number =
        int.tryParse(RegExp(r'\d+').firstMatch(label)?.group(0) ?? '0') ?? 0;
    if (label.contains('×')) return 10 * number;
    if (label.contains('÷')) return number == 0 ? 0 : 10 ~/ number;
    if (label.contains('－') || label.contains('-')) return 10 - number;
    return 10 + number;
  }

  Widget _drawGame(BoxConstraints constraints) {
    return GestureDetector(
      key: const Key('mini-game-draw-area'),
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        _start();
        setState(() {
          _line
            ..clear()
            ..add(details.localPosition);
        });
      },
      onPanUpdate: (details) =>
          setState(() => _line.add(details.localPosition)),
      onPanEnd: (_) {
        if (_line.length < 2) return _finish(false);
        final start = _line.first;
        final end = _line.last;
        final valid =
            start.dx < constraints.maxWidth * .3 &&
            end.dx > constraints.maxWidth * .7 &&
            (start.dy - end.dy).abs() < constraints.maxHeight * .55;
        _finish(valid);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _PathPainter(points: _line, color: widget.ad.accentColor),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _StageObject(
              path: game.assetPath,
              adNumber: widget.ad.number,
              fallback: widget.ad.number == 58 ? Icons.local_drink : Icons.pets,
              label: '守る',
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _StageObject(
              path: visualAssets.secondaryAsset,
              adNumber: widget.ad.number,
              fallback: Icons.flag,
              label: widget.ad.number == 59 ? 'ハチ' : 'GOAL',
            ),
          ),
        ],
      ),
    );
  }

  Widget _dragGame() {
    final correct = widget.ad.number.isEven ? 0 : 1;
    return Column(
      children: [
        Expanded(
          child: Draggable<int>(
            key: const Key('mini-game-draggable'),
            data: 1,
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 72,
                height: 72,
                child: game.assetPath == null
                    ? Icon(_fallbackObjectIcon, size: 72, color: Colors.amber)
                    : _Asset(path: game.assetPath!, adNumber: widget.ad.number),
              ),
            ),
            childWhenDragging: const SizedBox(width: 72, height: 72),
            child: SizedBox(
              width: 72,
              height: 72,
              child: game.assetPath == null
                  ? Icon(_fallbackObjectIcon, size: 72, color: Colors.amber)
                  : _Asset(path: game.assetPath!, adNumber: widget.ad.number),
            ),
          ),
        ),
        Row(
          children: [
            for (var i = 0; i < 2; i++)
              Expanded(
                child: DragTarget<int>(
                  key: Key('mini-game-drop-$i'),
                  onWillAcceptWithDetails: (_) => true,
                  onAcceptWithDetails: (_) => _finish(i == correct),
                  builder: (context, candidates, _) => Container(
                    height: 82,
                    margin: const EdgeInsets.all(6),
                    alignment: Alignment.center,
                    color: candidates.isEmpty
                        ? (i == 0 ? Colors.blueGrey : Colors.brown)
                        : Colors.green,
                    child: Text(
                      i == 0 ? 'BOX A' : 'BOX B',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _timingGame() => AnimatedBuilder(
    animation: _motion,
    builder: (context, _) => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 54,
          child: Stack(
            children: [
              Positioned.fill(child: Container(color: Colors.red.shade300)),
              const Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: 90,
                  child: ColoredBox(color: Colors.green),
                ),
              ),
              Align(
                alignment: Alignment(_motion.value * 2 - 1, 0),
                child: Container(width: 8, color: Colors.black),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const Key('mini-game-timing-stop'),
          onPressed: () {
            _motion.stop();
            _finish(_motion.value >= .4 && _motion.value <= .6);
          },
          icon: const Icon(Icons.stop_circle),
          label: const Text('ここで止める'),
        ),
      ],
    ),
  );

  IconData get _fallbackObjectIcon {
    if (widget.ad.number == 61 || widget.ad.number == 62) {
      return Icons.directions_car;
    }
    return switch (widget.ad.category) {
      '変身' => Icons.face_retouching_natural,
      '成長・マージ' => Icons.merge,
      '意味不明' => Icons.ads_click,
      _ => Icons.extension,
    };
  }

  Widget _scratchGame(BoxConstraints constraints) {
    const columns = 10;
    const rows = 6;
    void scratch(Offset point) {
      _start();
      final x = (point.dx / max(1, constraints.maxWidth) * columns)
          .floor()
          .clamp(0, columns - 1);
      final y = (point.dy / max(1, constraints.maxHeight) * rows).floor().clamp(
        0,
        rows - 1,
      );
      setState(() => _scratched.add(y * columns + x));
      if (_scratched.length >= 42) _finish(true);
    }

    return GestureDetector(
      key: const Key('mini-game-scratch-area'),
      onPanStart: (details) => scratch(details.localPosition),
      onPanUpdate: (details) => scratch(details.localPosition),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            alignment: Alignment.center,
            color: widget.ad.accentColor,
            child: const Text('広告でした！', style: TextStyle(fontSize: 28)),
          ),
          CustomPaint(
            painter: _ScratchPainter(
              scratched: Set<int>.of(_scratched),
              columns: columns,
              rows: rows,
            ),
          ),
        ],
      ),
    );
  }

  Widget _packGame() => GestureDetector(
    key: const Key('mini-game-pack'),
    onVerticalDragStart: (_) => _start(),
    onVerticalDragUpdate: (details) {
      if (details.delta.dy < 0) _swipeDistance -= details.delta.dy;
    },
    onVerticalDragEnd: (_) => _finish(_swipeDistance >= 55),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.all(20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.ad.accentColor,
        border: Border.all(color: Colors.white, width: 6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (game.assetPath != null)
            Expanded(
              child: _Asset(path: game.assetPath!, adNumber: widget.ad.number),
            ),
          const Icon(Icons.swipe_up, size: 48),
          Text(_phase == MiniGamePhase.success ? 'OPEN!' : '上へスワイプ'),
        ],
      ),
    ),
  );

  Widget _countdownGame() => Center(
    child: InkWell(
      key: const Key('mini-game-countdown-stop'),
      onTap: () {
        _countdownTimer?.cancel();
        _finish(_countdown == 1);
      },
      child: Container(
        width: 150,
        height: 150,
        alignment: Alignment.center,
        color: _countdown == 1 ? Colors.green : Colors.red,
        child: Text(
          '$_countdown',
          style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w900),
        ),
      ),
    ),
  );

  Widget _revealGame() => AnimatedBuilder(
    animation: _motion,
    builder: (context, _) => Align(
      alignment: Alignment(
        sin(_motion.value * pi * 2) * .75,
        cos(_motion.value * pi) * .55,
      ),
      child: InkResponse(
        key: const Key('mini-game-reveal-target'),
        radius: 46,
        onTap: () => _finish(true),
        child: Container(
          width: game.assetPath == null ? 82 : 104,
          height: game.assetPath == null ? 82 : 104,
          alignment: Alignment.center,
          color: widget.ad.accentColor.withValues(alpha: .82),
          child: game.assetPath == null
              ? const Icon(Icons.ads_click, size: 42)
              : _Asset(path: game.assetPath!, adNumber: widget.ad.number),
        ),
      ),
    ),
  );

  Widget _finaleGame() => Center(
    child: InkResponse(
      key: const Key('mini-game-finale'),
      radius: 90,
      onTap: () {
        _start();
        setState(() => _progress++);
        if (_progress >= 3) _finish(true);
      },
      child: Container(
        width: 170,
        height: 170,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black,
          border: Border.all(color: Colors.amber, width: 6),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: .7),
              blurRadius: 30,
            ),
          ],
        ),
        child: Text(
          'AD\nGON\n${min(_progress, 3)}/3',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.amber,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ),
  );
}

class AdGameStage extends StatelessWidget {
  const AdGameStage({
    super.key,
    required this.ad,
    required this.backgroundAsset,
    required this.child,
  });

  final AdDefinition ad;
  final String backgroundAsset;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black,
      border: Border.all(color: Colors.white.withValues(alpha: .8), width: 2),
      boxShadow: const [
        BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
      ],
    ),
    child: ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            backgroundAsset,
            fit: BoxFit.cover,
            errorBuilder: (_, error, _) {
              assert(() {
                debugPrint(
                  'Ad No.${ad.number}: failed to load $backgroundAsset: $error',
                );
                return true;
              }());
              return ColoredBox(color: ad.accentColor.withValues(alpha: .45));
            },
          ),
          const ColoredBox(color: Color(0x26000000)),
          child,
        ],
      ),
    ),
  );
}

class _StageObject extends StatelessWidget {
  const _StageObject({
    required this.path,
    required this.adNumber,
    required this.fallback,
    required this.label,
  });

  final String? path;
  final int adNumber;
  final IconData fallback;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    width: 88,
    height: 112,
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .2),
      border: Border.all(color: Colors.white, width: 2),
    ),
    child: Column(
      children: [
        Expanded(
          child: path == null
              ? Icon(fallback, size: 52, color: Colors.white)
              : _Asset(path: path!, adNumber: adNumber),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _ReactiveActor extends StatelessWidget {
  const _ReactiveActor({
    required this.path,
    required this.adNumber,
    required this.phase,
    required this.maxHeight,
  });

  final String path;
  final int adNumber;
  final MiniGamePhase phase;
  final double maxHeight;

  @override
  Widget build(BuildContext context) => AnimatedRotation(
    duration: const Duration(milliseconds: 220),
    turns: phase == MiniGamePhase.failure ? -.035 : 0,
    child: AnimatedScale(
      duration: const Duration(milliseconds: 220),
      scale: phase == MiniGamePhase.success
          ? 1.16
          : phase == MiniGamePhase.failure
          ? .9
          : 1,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: phase == MiniGamePhase.failure ? .55 : 1,
        child: SizedBox(
          height: maxHeight,
          width: maxHeight,
          child: _Asset(path: path, adNumber: adNumber),
        ),
      ),
    ),
  );
}

class _Asset extends StatelessWidget {
  const _Asset({required this.path, required this.adNumber});
  final String path;
  final int adNumber;

  @override
  Widget build(BuildContext context) => Image.asset(
    path,
    fit: BoxFit.contain,
    errorBuilder: (_, error, _) {
      assert(() {
        debugPrint('Ad No.$adNumber: failed to load $path: $error');
        return true;
      }());
      return const Icon(Icons.image_not_supported, size: 60);
    },
  );
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({
    super.key,
    required this.color,
    required this.text,
    required this.onRetry,
  });
  final Color color;
  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 54,
    child: Row(
      children: [
        Expanded(
          child: Container(
            height: 54,
            alignment: Alignment.center,
            color: color,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        IconButton(
          key: const Key('mini-game-reset'),
          tooltip: 'もう一度',
          onPressed: onRetry,
          icon: const Icon(Icons.replay),
        ),
      ],
    ),
  );
}

class _PathPainter extends CustomPainter {
  const _PathPainter({required this.points, required this.color});
  final List<Offset> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PathPainter oldDelegate) => true;
}

class _ScratchPainter extends CustomPainter {
  const _ScratchPainter({
    required this.scratched,
    required this.columns,
    required this.rows,
  });
  final Set<int> scratched;
  final int columns;
  final int rows;

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = size.width / columns;
    final cellHeight = size.height / rows;
    final paint = Paint()..color = Colors.grey.shade500;
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < columns; x++) {
        if (!scratched.contains(y * columns + x)) {
          canvas.drawRect(
            Rect.fromLTWH(
              x * cellWidth,
              y * cellHeight,
              cellWidth + 1,
              cellHeight + 1,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ScratchPainter oldDelegate) =>
      scratched.length != oldDelegate.scratched.length;
}
