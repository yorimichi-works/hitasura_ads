import 'package:flutter/material.dart';

import '../arcade/engine/sfx.dart';
import '../arcade/registry.dart';
import '../arcade/spec.dart';
import '../l10n/l10n.dart';
import '../state/app_controller.dart';
import 'ad_player.dart';
import 'kit.dart';
import 'thumbs.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({
    super.key,
    required this.controller,
    this.onUnlockWithSponsor,
    this.sponsorAvailable = false,
  });
  final AppController controller;
  final Future<bool> Function(GameSpec g)? onUnlockWithSponsor;
  final bool sponsorAvailable;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  GameCat? _filter;

  AppController get c => widget.controller;

  @override
  Widget build(BuildContext context) {
    final games = allGames
        .where((g) => _filter == null || g.cat == _filter)
        .toList();
    return Scaffold(
      body: NightBackground(
        hue: 40,
        child: SafeArea(
          child: AnimatedBuilder(
            animation: c,
            builder: (context, _) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          K.tap(Sfx.back);
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                      Expanded(
                        child: InkText(
                          L10n.ui('collection'),
                          size: 26,
                          align: TextAlign.start,
                          color: K.yellow,
                        ),
                      ),
                      Pill(
                        '${c.discoveredCount}/${allGames.length}',
                        color: K.yellow,
                        size: 14,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _chip(null),
                      for (final cat in GameCat.values) _chip(cat),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final cols = (box.maxWidth / 118).floor().clamp(3, 8);
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 10,
                          childAspectRatio: 9 / 21,
                        ),
                        itemCount: games.length,
                        itemBuilder: (context, i) => _card(games[i]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(GameCat? cat) {
    final selected = _filter == cat;
    final col = cat == null ? Colors.white : K.category(cat);
    final label = cat == null
        ? L10n.ui('filter_all')
        : L10n.ui('cat_${cat.name}');
    final found = allGames
        .where((g) => (cat == null || g.cat == cat) && c.isDiscovered(g))
        .length;
    final total = allGames.where((g) => cat == null || g.cat == cat).length;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          K.tap();
          setState(() => _filter = cat);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? col : col.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected ? K.ink : col.withValues(alpha: .6),
              width: 2,
            ),
          ),
          child: Text(
            '$label $found/$total',
            style: K.t(
              12,
              color: selected ? K.ink : Colors.white,
              weight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(GameSpec g) {
    final unlocked = c.isDiscovered(g);
    final stars = c.starsOf(g);
    final text = L10n.game(g.no);
    final secretHidden = g.isSecret && !unlocked;
    return GestureDetector(
      onTap: () {
        K.tap(Sfx.select);
        _detail(g);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: unlocked ? K.rarity(g.rarity) : Colors.white24,
                width: 3,
              ),
              boxShadow: const [BoxShadow(color: K.ink, offset: Offset(0, 3))],
            ),
            child: GameThumb(spec: g, unlocked: unlocked, radius: 9),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                g.no.toString().padLeft(3, '0'),
                style: K.t(10, color: Colors.white54),
              ),
              const Spacer(),
              for (var i = 0; i < 3; i++)
                Icon(
                  Icons.star_rounded,
                  size: 11,
                  color: i < stars ? K.yellow : Colors.white24,
                ),
            ],
          ),
          Text(
            unlocked ? text.title : (secretHidden ? '???' : '? ? ?'),
            style: K.t(11, color: unlocked ? Colors.white : Colors.white38),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _detail(GameSpec g) {
    final unlocked = c.isDiscovered(g);
    final text = L10n.game(g.no);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: const BoxConstraints(maxWidth: 480),
        margin: const EdgeInsets.all(12),
        child: Sticker(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: K.ink, width: 3),
                      ),
                      child: GameThumb(spec: g, unlocked: unlocked, radius: 11),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.label,
                          style: K.t(12, color: K.ink.withValues(alpha: .5)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          unlocked ? text.title : '???',
                          style: K.t(22, color: K.ink, weight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Pill(
                              L10n.ui('cat_${g.cat.name}'),
                              color: K.category(g.cat),
                              size: 11,
                            ),
                            RarityBadge(
                              g.rarity,
                              label: L10n.ui('rarity_${g.rarity.name}'),
                              size: 11,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          unlocked
                              ? text.hook
                              : (g.isSecret
                                    ? L10n.ui('secret_hint')
                                    : L10n.ui('locked_hint')),
                          style: K.t(
                            14,
                            color: K.ink.withValues(alpha: .75),
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (unlocked)
                          Row(
                            children: [
                              for (var i = 0; i < 3; i++)
                                Icon(
                                  Icons.star_rounded,
                                  size: 24,
                                  color: i < c.starsOf(g)
                                      ? K.orange
                                      : K.ink.withValues(alpha: .15),
                                ),
                              const SizedBox(width: 8),
                              Text(
                                '${L10n.ui('plays')}: ${c.playsOf(g)}',
                                style: K.t(
                                  12,
                                  color: K.ink.withValues(alpha: .6),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (unlocked)
                ChunkyButton(
                  color: K.pink,
                  sound: Sfx.go,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AdPlayerScreen(
                          controller: c,
                          first: g,
                          roulette: false,
                          replayMode: true,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                      const SizedBox(width: 6),
                      InkText(L10n.ui('play'), size: 22, shadow: false),
                    ],
                  ),
                )
              else if ((!g.isSecret || c.premiumNoAds) &&
                  widget.sponsorAvailable &&
                  widget.onUnlockWithSponsor != null)
                ChunkyButton(
                  color: K.lime,
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await widget.onUnlockWithSponsor!(g);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        c.premiumNoAds
                            ? Icons.lock_open_rounded
                            : Icons.ondemand_video_rounded,
                        color: K.ink,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          L10n.ui(c.premiumNoAds ? 'unlock_any' : 'sponsored'),
                          style: K.t(16, color: K.ink, weight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
