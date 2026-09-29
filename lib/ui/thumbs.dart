import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../arcade/engine/game_view.dart';
import '../arcade/spec.dart';
import 'kit.dart';

/// Renders real frames of games for thumbnails, one at a time, cached.
class ThumbCache {
  ThumbCache._();
  static final instance = ThumbCache._();

  final Map<int, ui.Image> _images = {};
  final Map<int, List<VoidCallback>> _waiting = {};
  final Queue<GameSpec> _queue = Queue();
  bool _running = false;

  ui.Image? get(int no) => _images[no];

  void request(GameSpec spec, VoidCallback onReady) {
    if (_images.containsKey(spec.no)) return;
    final list = _waiting.putIfAbsent(spec.no, () => []);
    list.add(onReady);
    if (list.length == 1) _queue.add(spec);
    _pump();
  }

  void cancel(int no, VoidCallback cb) => _waiting[no]?.remove(cb);

  void _pump() {
    if (_running || _queue.isEmpty) return;
    _running = true;
    final spec = _queue.removeFirst();
    // Skip work nobody waits for any more (scrolled away).
    if ((_waiting[spec.no] ?? const []).isEmpty) {
      _waiting.remove(spec.no);
      _running = false;
      scheduleMicrotask(_pump);
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 16), () async {
      final img = await renderGameThumbnail(spec.create(), seconds: 1.6, duration: spec.duration);
      if (img != null) _images[spec.no] = img;
      final cbs = _waiting.remove(spec.no) ?? const [];
      for (final cb in cbs) {
        cb();
      }
      _running = false;
      _pump();
    });
  }
}

/// A 9:16 thumbnail of a game. Locked games show a mystery card.
class GameThumb extends StatefulWidget {
  const GameThumb({super.key, required this.spec, required this.unlocked, this.radius = 12});
  final GameSpec spec;
  final bool unlocked;
  final double radius;

  @override
  State<GameThumb> createState() => _GameThumbState();
}

class _GameThumbState extends State<GameThumb> {
  void _ready() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    if (widget.unlocked) ThumbCache.instance.request(widget.spec, _ready);
  }

  @override
  void didUpdateWidget(GameThumb old) {
    super.didUpdateWidget(old);
    if (widget.unlocked && (old.spec.no != widget.spec.no || !old.unlocked)) {
      ThumbCache.instance.request(widget.spec, _ready);
    }
  }

  @override
  void dispose() {
    ThumbCache.instance.cancel(widget.spec.no, _ready);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cat = K.category(widget.spec.cat);
    final img = widget.unlocked ? ThumbCache.instance.get(widget.spec.no) : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: img != null
            ? RawImage(image: img, fit: BoxFit.cover)
            : DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color.lerp(cat, K.ink, widget.unlocked ? .2 : .65)!, Color.lerp(cat, K.ink, .85)!],
                  ),
                ),
                child: Center(
                  child: widget.unlocked
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white54))
                      : InkText('?', size: 34, color: cat.withValues(alpha: .9)),
                ),
              ),
      ),
    );
  }
}
