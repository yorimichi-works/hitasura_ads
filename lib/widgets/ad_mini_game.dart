import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/ad_definition.dart';
import '../models/ad_mini_game_definition.dart';
import '../models/ad_visual_assets.dart';
import '../models/mini_game_rules.dart';

enum MiniGamePhase { notStarted, playing, success, failure }

class AdMiniGame extends StatefulWidget {
  const AdMiniGame({
    super.key,
    required this.ad,
    required this.onInteraction,
    this.seed,
  });

  final AdDefinition ad;
  final VoidCallback onInteraction;
  final int? seed;

  @override
  State<AdMiniGame> createState() => _AdMiniGameState();
}

class _AdMiniGameState extends State<AdMiniGame>
    with SingleTickerProviderStateMixin {
  late final AdMiniGameDefinition game = AdMiniGameDefinition.forAd(widget.ad);
  late final AdVisualAssets visualAssets = AdVisualAssets.forAd(widget.ad);
  late final AdMiniGameRules rules = AdMiniGameRules.forAd(widget.ad);
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
  int _run = 0;
  late Random _random;
  late int _value;
  int _score = 0;
  int _mistakes = 0;
  late int _correctChoice;
  late int _dragTarget;
  late List<int> _pinOrder;
  late List<NumberOperation> _gates;
  String _packReward = '???';
  String _scratchReward = '';
  int _tapOffset = 0;
  double _pathY = 0;

  @override
  void initState() {
    super.initState();
    _prepareRun();
    if (game.type == AdMiniGameType.countdownStop) _startCountdown();
  }

  void _prepareRun() {
    final seed = widget.seed ?? DateTime.now().microsecondsSinceEpoch;
    _random = Random(seed + widget.ad.number * 997 + _run++);
    _value = rules.initialValue;
    _score = 0;
    _mistakes = 0;
    _correctChoice = _random.nextInt(3);
    _dragTarget = _random.nextInt(2);
    _pinOrder = [0, 1, 2]..shuffle(_random);
    _gates = rules.gates(_random, round: _progress);
    const scratchRewards = ['コイン 100', '装備 R', '経験値 999', 'ハズレ風の当たり'];
    _packReward = '???';
    _scratchReward = scratchRewards[_random.nextInt(scratchRewards.length)];
    _tapOffset = _random.nextInt(5);
    _pathY = -.45 + _random.nextDouble() * .9;
    _motion.duration = Duration(milliseconds: 1100 + _random.nextInt(900));
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
      _prepareRun();
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
                  Padding(
                    padding: const EdgeInsets.only(top: 38),
                    child: _buildGame(constraints),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    top: 6,
                    child: _GameHud(
                      progress: _progress,
                      rounds: rules.rounds,
                      value: _value,
                      score: _score,
                    ),
                  ),
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
              text:
                  '${rules.grade(mistakes: _mistakes, score: _score).name.toUpperCase()}! ${widget.ad.resultText}',
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
      const Alignment(-.45, .45),
      const Alignment(.5, -.5),
    ];
    return Stack(
      children: [
        AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          alignment: alignments[(_progress + _tapOffset) % alignments.length],
          child: Semantics(
            button: true,
            label: '光る対象',
            child: InkResponse(
              key: const Key('mini-game-tap-target'),
              radius: 42,
              onTap: () {
                _start();
                setState(() {
                  _progress++;
                  _score += 100;
                  _value += 1;
                });
                if (_progress >= rules.rounds) _finish(true);
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
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: game.assetPath == null
                        ? Border.all(color: Colors.white, width: 4)
                        : null,
                  ),
                  child: game.assetPath == null
                      ? Text(
                          '${min(_progress + 1, rules.rounds)}/${rules.rounds}',
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
    const symbols = ['★', '◆', '●'];
    return Column(
      children: [
        Text(
          'お題と同じ記号を選べ：${symbols[_correctChoice]}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: FilledButton(
                      key: Key('mini-game-choice-$i'),
                      onPressed:
                          _phase == MiniGamePhase.success ||
                              _phase == MiniGamePhase.failure
                          ? null
                          : () {
                              _start();
                              if (i != _correctChoice) {
                                _mistakes++;
                                _finish(false);
                                return;
                              }
                              setState(() {
                                _progress++;
                                _score += 100;
                                _value += 3;
                                _correctChoice = _random.nextInt(3);
                              });
                              if (_progress >= rules.rounds) _finish(true);
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.primaries[i * 3],
                        minimumSize: const Size.fromHeight(130),
                        shape: const RoundedRectangleBorder(),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (i == 0 && game.assetPath != null)
                            SizedBox(
                              width: 58,
                              height: 58,
                              child: _Asset(
                                path: game.assetPath!,
                                adNumber: widget.ad.number,
                              ),
                            ),
                          Text(
                            symbols[i],
                            style: const TextStyle(fontSize: 28),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pinGame() {
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
                              final expected = _pinOrder[_removedPins.length];
                              if (i != expected) {
                                _mistakes++;
                                _finish(false);
                                return;
                              }
                              setState(() {
                                _removedPins.add(i);
                                _progress++;
                                _score += 100;
                                _value += 5;
                              });
                              if (_removedPins.length == 3) _finish(true);
                            },
                      icon: const Icon(Icons.horizontal_rule),
                      label: Text('PIN ${i + 1}  順${_pinOrder.indexOf(i) + 1}'),
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
    final results = _gates.map((gate) => gate.apply(_value)).toList();
    final correct = results[0] >= results[1] ? 0 : 1;
    return Column(
      children: [
        SizedBox(height: 44, child: _ValueCrowd(value: _value)),
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < 2; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: InkWell(
                      key: Key('mini-game-gate-$i'),
                      onTap:
                          _phase == MiniGamePhase.success ||
                              _phase == MiniGamePhase.failure
                          ? null
                          : () {
                              _start();
                              if (i != correct) {
                                _mistakes++;
                                _finish(false);
                                return;
                              }
                              setState(() {
                                _value = results[i].clamp(0, 999999);
                                _progress++;
                                _score += 100;
                                _gates = rules.gates(_random, round: _progress);
                              });
                              if (_progress >= rules.rounds) _finish(true);
                            },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i == 0 ? Colors.green : Colors.deepOrange,
                          border: Border.all(color: Colors.white, width: 5),
                        ),
                        child: Text(
                          '${_gates[i].label}\n→ ${results[i]}',
                          textAlign: TextAlign.center,
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
          ),
        ),
      ],
    );
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
            (start.dy - end.dy).abs() < constraints.maxHeight * .3 &&
            (start.dy / constraints.maxHeight * 2 - 1 - _pathY).abs() < .55;
        if (valid) {
          setState(() {
            _progress = 1;
            _score = 100;
            _value += 10;
          });
        } else {
          _mistakes++;
        }
        _finish(valid);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _PathPainter(points: _line, color: widget.ad.accentColor),
          ),
          Align(
            alignment: Alignment(-1, _pathY),
            child: _StageObject(
              path: game.assetPath,
              adNumber: widget.ad.number,
              fallback: widget.ad.number == 58 ? Icons.local_drink : Icons.pets,
              label: '守る',
            ),
          ),
          Align(
            alignment: Alignment(1, _pathY),
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
                  onAcceptWithDetails: (_) {
                    _start();
                    if (i != _dragTarget) {
                      _mistakes++;
                      _finish(false);
                      return;
                    }
                    setState(() {
                      _progress++;
                      _score += 100;
                      _value += 2;
                      _dragTarget = _random.nextInt(2);
                    });
                    if (_progress >= rules.rounds) _finish(true);
                  },
                  builder: (context, candidates, _) => Container(
                    height: 82,
                    margin: const EdgeInsets.all(6),
                    alignment: Alignment.center,
                    color: candidates.isEmpty
                        ? (i == 0 ? Colors.blueGrey : Colors.brown)
                        : Colors.green,
                    child: Text(
                      '${i == 0 ? 'BOX A' : 'BOX B'}${i == _dragTarget ? '\nここへ' : ''}',
                      textAlign: TextAlign.center,
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
                  key: Key('mini-game-timing-zone'),
                  width: 90,
                  child: ColoredBox(color: Colors.green),
                ),
              ),
              Align(
                alignment: Alignment(_motion.value * 2 - 1, 0),
                child: Container(
                  key: const Key('mini-game-timing-needle'),
                  width: 8,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const Key('mini-game-timing-stop'),
          onPressed: () {
            _motion.stop();
            final success = _motion.value >= .4 && _motion.value <= .6;
            if (success) {
              setState(() {
                _progress = 1;
                _score = 100;
                _value += rules.rewardDelta;
              });
            } else {
              _mistakes++;
            }
            _finish(success);
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
      if (_scratched.length >= 42 && _phase != MiniGamePhase.success) {
        setState(() {
          _progress = 1;
          _score = 100;
          _value += 100;
        });
        _finish(true);
      }
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
            child: Text(
              _scratchReward,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
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
    onVerticalDragEnd: (_) {
      if (_swipeDistance < 55) {
        _mistakes++;
        _finish(false);
        return;
      }
      const rewards = ['コイン +50', '装備 GET', 'LEVEL +1', '謎アイテム'];
      setState(() {
        _progress++;
        _score += 100;
        _value += 50;
        _packReward = rewards[_random.nextInt(rewards.length)];
        _swipeDistance = 0;
      });
      if (_progress >= rules.rounds) _finish(true);
    },
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
          Text(_packReward == '???' ? '上へスワイプ' : _packReward),
        ],
      ),
    ),
  );

  Widget _countdownGame() => Center(
    child: InkWell(
      key: const Key('mini-game-countdown-stop'),
      onTap: () {
        _countdownTimer?.cancel();
        final success = _countdown == 1;
        if (success) {
          setState(() {
            _progress = 1;
            _score = 100;
            _value += 1;
          });
        } else {
          _mistakes++;
        }
        _finish(success);
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
        onTap: () {
          _start();
          setState(() {
            _progress++;
            _score += 100;
            _value += 1;
          });
          if (_progress >= rules.rounds) _finish(true);
        },
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
        setState(() {
          _progress++;
          _score += 100;
          _value = min(999, _value + 1);
        });
        if (_progress >= rules.rounds) _finish(true);
      },
      child: Container(
        width: 170,
        height: 170,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _value >= 999 ? Colors.amber.shade700 : Colors.black,
          border: Border.all(color: Colors.amber, width: 6),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: .7),
              blurRadius: 30,
            ),
          ],
        ),
        child: Text(
          _value >= 999 ? 'AD GON\nLv999\n広告王形態' : 'AD\nGON\nLv$_value',
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

class _GameHud extends StatelessWidget {
  const _GameHud({
    required this.progress,
    required this.rounds,
    required this.value,
    required this.score,
  });

  final int progress;
  final int rounds;
  final int value;
  final int score;

  @override
  Widget build(BuildContext context) => Container(
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    color: value >= 9999 ? const Color(0xE6B8860B) : const Color(0xCC000000),
    child: Row(
      children: [
        Text(
          'ROUND ${min(progress + 1, rounds)}/$rounds',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Text(
          value >= 9999
              ? 'MAX $value  POWERED UP!'
              : 'VALUE $value  SCORE $score',
          key: const Key('mini-game-state-value'),
          style: const TextStyle(
            color: Colors.amber,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _ValueCrowd extends StatelessWidget {
  const _ValueCrowd({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final visible = min(24, max(3, sqrt(max(1, value)).round() * 2));
    return Wrap(
      key: const Key('mini-game-value-crowd'),
      alignment: WrapAlignment.center,
      spacing: 2,
      runSpacing: 1,
      children: [
        for (var i = 0; i < visible; i++)
          const Icon(Icons.person, size: 15, color: Colors.white),
      ],
    );
  }
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
  Widget build(BuildContext context) => SizedBox(
    width: 88,
    height: 112,
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
            shadows: [
              Shadow(color: Colors.black, blurRadius: 3),
              Shadow(color: Colors.black, offset: Offset(1, 1)),
            ],
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
