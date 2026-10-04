import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../arcade/engine/audio.dart';
import '../arcade/engine/sfx.dart';
import '../arcade/registry.dart';
import '../arcade/spec.dart';
import '../l10n/l10n.dart';
import '../models/reward_purpose.dart';
import '../services/rewarded_ad_service.dart';
import '../services/search_energy_service.dart';
import '../state/app_controller.dart';
import 'ad_player.dart';
import 'collection.dart';
import 'kit.dart';
import 'premium.dart';
import 'reveal.dart';
import 'rush.dart';
import 'settings.dart';
import 'thumbs.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    this.rewardedAdService,
  });
  final AppController controller;
  final RewardedAdService? rewardedAdService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final RewardedAdService _ads;
  late final Timer _ticker;
  bool _busy = false;
  bool _premiumOpen = false;

  AppController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _ads = widget.rewardedAdService ?? GoogleRewardedAdService();
    _ads.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_ads.preparePrivacy());
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      await c.refreshSearchEnergy();
      if (mounted) setState(() {});
    });
    ArcadeAudio.instance.bgm('menu');
    ArcadeAudio.instance.preload(Sfx.all);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.cancel();
    _ads.removeListener(_refresh);
    _ads.dispose();
    super.dispose();
  }

  void _toast(String key) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(L10n.ui(key), style: K.t(14)),
          backgroundColor: K.ink,
        ),
      );
  }

  Future<GameSpec?> _takeTicketAndPick() async {
    if (!await c.consumeSearchEnergy()) return null;
    return c.pickNextGame();
  }

  Future<void> _watch() async {
    if (_busy) return;
    _busy = true;
    try {
      final g = await _takeTicketAndPick();
      if (!mounted) return;
      if (g == null) {
        _toast('out_of_tickets');
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AdPlayerScreen(
            controller: c,
            first: g,
            nextGame: _takeTicketAndPick,
          ),
        ),
      );
    } finally {
      _busy = false;
    }
    ArcadeAudio.instance.bgm('menu');
    if (mounted) setState(() {});
  }

  Future<void> _sponsor() async {
    if (_busy) return;
    _busy = true;
    try {
      final r = await _ads.show(
        placementName: const RewardPurpose.restoreSearchEnergy().placementName,
      );
      if (r == RewardedAdResult.rewarded) {
        await c.refillSearchEnergy();
        ArcadeAudio.instance.sfx(Sfx.powerup);
        _toast('refilled');
      } else {
        _toast(switch (r) {
          RewardedAdResult.notRewarded => 'sponsor_incomplete',
          RewardedAdResult.unavailable => 'sponsor_unavailable',
          _ => 'sponsor_failed',
        });
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _daily() async {
    final amount = await c.claimDaily();
    if (amount > 0) {
      ArcadeAudio.instance.sfx(Sfx.coins);
      ArcadeAudio.instance.sfx(Sfx.fanfare, volume: .6);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: K.ink,
          content: Text(
            '${L10n.ui('daily_bonus')}  +$amount / ${L10n.ui('streak', {'n': c.arcade.streak})}',
            style: K.t(15, color: K.yellow),
          ),
        ),
      );
    }
  }

  Future<void> _capsule() async {
    if (c.coins < AppController.capsuleCost) {
      _toast('not_enough_coins');
      ArcadeAudio.instance.sfx(Sfx.buzzer, volume: .6);
      return;
    }
    final g = await c.buyCapsule();
    if (!mounted) return;
    if (g == null) {
      _toast('all_found');
      return;
    }
    await showDiscoveryReveal(context, g);
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    ArcadeAudio.instance.bgm('menu');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AnimatedBuilder(
                animation: c,
                builder: (context, _) => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                  children: [
                    _topBar(),
                    const SizedBox(height: 14),
                    _logo(),
                    const SizedBox(height: 14),
                    _Tv(controller: c),
                    const SizedBox(height: 14),
                    _tickets(),
                    const SizedBox(height: 12),
                    _watchButton(),
                    const SizedBox(height: 18),
                    _progress(),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: _rushCard()),
                        const SizedBox(width: 12),
                        Expanded(child: _collectionCard()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _dailyCard()),
                        const SizedBox(width: 12),
                        Expanded(child: _capsuleCard()),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _premiumEntry(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPremium() async {
    if (_premiumOpen) return;
    _premiumOpen = true;
    K.tap();
    try {
      await _open(PremiumScreen(controller: c));
    } finally {
      _premiumOpen = false;
    }
  }

  Widget _premiumEntry() => OutlinedButton(
    key: const ValueKey('home-premium-entry'),
    onPressed: _openPremium,
    style: OutlinedButton.styleFrom(
      foregroundColor: K.paper,
      minimumSize: const Size.fromHeight(56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      side: const BorderSide(color: K.paper, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    child: Row(
      children: [
        Icon(c.premiumNoAds ? Icons.check_circle_outline : Icons.block_rounded),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            L10n.ui(c.premiumNoAds ? 'premium_active' : 'premium_home_entry'),
            style: K.t(16, color: K.paper),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right_rounded),
      ],
    ),
  );

  Widget _topBar() {
    final a = c.arcade;
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: K.cyan,
            shape: BoxShape.circle,
            border: Border.all(color: K.ink, width: 3),
            boxShadow: const [BoxShadow(color: K.ink, offset: Offset(0, 3))],
          ),
          child: Text(
            '${a.level}',
            style: K.t(18, color: K.ink, weight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.user?.nickname ?? '',
                style: K.t(15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: a.levelProgress,
                  minHeight: 7,
                  backgroundColor: Colors.white12,
                  color: K.cyan,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Pill(
          _fmt(c.coins),
          icon: Icons.monetization_on_rounded,
          color: K.yellow,
          size: 14,
        ),
        const SizedBox(width: 6),
        IconButton(
          onPressed: () {
            K.tap();
            _open(SettingsScreen(controller: c, rewardedAdService: _ads));
          },
          icon: const Icon(Icons.settings_rounded, color: Colors.white),
        ),
      ],
    );
  }

  Widget _logo() => Column(
    children: [
      Transform.rotate(
        angle: -.04,
        child: InkText(L10n.ui('app_title'), size: 44, color: K.yellow),
      ),
      const SizedBox(height: 4),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Pill(
            L10n.ui('app_sub'),
            color: K.pink,
            textColor: Colors.white,
            size: 13,
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        L10n.ui('tagline'),
        textAlign: TextAlign.center,
        style: K.t(13, color: Colors.white70),
      ),
    ],
  );

  Widget _tickets() {
    final n = c.searchEnergy;
    final wait = c.timeUntilSearchRecovery;
    final mm = wait.inMinutes.toString();
    final ss = (wait.inSeconds % 60).toString().padLeft(2, '0');
    return Row(
      children: [
        Text(L10n.ui('tickets'), style: K.t(13, color: Colors.white70)),
        const SizedBox(width: 8),
        for (var i = 0; i < SearchEnergyService.maxEnergy; i++)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Transform.rotate(
              angle: -.15,
              child: Icon(
                Icons.confirmation_number_rounded,
                size: 24,
                color: i < n ? K.yellow : Colors.white24,
              ),
            ),
          ),
        const Spacer(),
        Text(
          c.premiumNoAds
              ? L10n.ui('unlimited')
              : n >= SearchEnergyService.maxEnergy
              ? L10n.ui('full')
              : L10n.ui('refill_in', {'t': '$mm:$ss'}),
          style: K.t(
            12,
            color: n >= SearchEnergyService.maxEnergy ? K.lime : Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _watchButton() {
    if (!c.canSearch) {
      return ChunkyButton(
        onTap: _ads.isSupported ? _sponsor : null,
        color: K.lime,
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.ondemand_video_rounded, color: K.ink, size: 28),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                L10n.ui('sponsor_refill'),
                style: K.t(17, color: K.ink, weight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
    }
    return Pulse(
      amount: .03,
      child: ChunkyButton(
        onTap: _watch,
        color: K.pink,
        height: 76,
        sound: Sfx.go,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.play_circle_fill_rounded,
              color: Colors.white,
              size: 38,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkText(L10n.ui('watch_next'), size: 24, shadow: false),
                  Text(
                    L10n.ui('watch_sub'),
                    style: K.t(11, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progress() {
    final n = c.discoveredCount;
    final total = allGames.length;
    return Sticker(
      color: const Color(0xFF2B1F55),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: K.yellow),
              const SizedBox(width: 6),
              Text(L10n.ui('discovered'), style: K.t(15)),
              const Spacer(),
              Directionality(
                textDirection: TextDirection.ltr,
                child: InkText(
                  '$n / $total',
                  size: 20,
                  color: K.yellow,
                  shadow: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Stack(
              children: [
                Container(height: 14, color: Colors.white12),
                FractionallySizedBox(
                  widthFactor: n / total,
                  child: Container(
                    height: 14,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [K.pink, K.yellow, K.lime, K.cyan],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (c.isComplete) ...[
            const SizedBox(height: 8),
            Text(L10n.ui('complete'), style: K.t(13, color: K.lime)),
          ],
        ],
      ),
    );
  }

  Widget _modeCard({
    required String title,
    required String sub,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool locked = false,
    TextDirection? subDirection,
  }) {
    return GestureDetector(
      onTap: () {
        K.tap(Sfx.select);
        onTap();
      },
      child: Sticker(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: locked
              ? [const Color(0xFF4A4266), const Color(0xFF2F2848)]
              : [color, Color.lerp(color, K.ink, .35)!],
        ),
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 112,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    locked ? Icons.lock_rounded : icon,
                    color: Colors.white,
                    size: 30,
                  ),
                  const Spacer(),
                ],
              ),
              const Spacer(),
              InkText(title, size: 20, align: TextAlign.start, maxLines: 1),
              const SizedBox(height: 2),
              Text(
                sub,
                textDirection: subDirection,
                style: K.t(11, color: Colors.white.withValues(alpha: .85)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rushCard() {
    final unlocked = c.rushUnlocked;
    final need = AppController.rushUnlockCount - c.rushPool.length;
    return _modeCard(
      title: L10n.ui('rush'),
      sub: unlocked
          ? '${L10n.ui('rush_best')}: ${c.arcade.rushBest} / ${L10n.ui('rush_desc')}'
          : L10n.ui('rush_locked', {'n': need}),
      icon: Icons.bolt_rounded,
      color: K.red,
      locked: !unlocked,
      onTap: () {
        if (!unlocked) {
          _toast('rush_desc_long');
          return;
        }
        _open(RushScreen(controller: c));
      },
    );
  }

  Widget _collectionCard() => _modeCard(
    title: L10n.ui('collection'),
    sub: '${c.discoveredCount} / ${allGames.length}',
    subDirection: TextDirection.ltr,
    icon: Icons.grid_view_rounded,
    color: K.purple,
    onTap: () => _open(
      CollectionScreen(
        controller: c,
        onUnlockWithSponsor: _unlockWithSponsor,
        sponsorAvailable:
            c.premiumNoAds || _ads.supportsPlacement('unlock_catalog'),
      ),
    ),
  );

  Widget _dailyCard() {
    final available = c.dailyAvailable;
    return _modeCard(
      title: L10n.ui('daily_bonus'),
      sub: available
          ? L10n.ui('claim')
          : '${L10n.ui('claimed')} / ${L10n.ui('streak', {'n': c.arcade.streak})}',
      icon: available
          ? Icons.card_giftcard_rounded
          : Icons.check_circle_rounded,
      color: available ? K.orange : const Color(0xFF6B5E8E),
      onTap: _daily,
    );
  }

  Widget _capsuleCard() => _modeCard(
    title: L10n.ui('ad_capsule'),
    sub:
        '${AppController.capsuleCost} ${L10n.ui('coins')} / ${L10n.ui('ad_capsule_desc')}',
    icon: Icons.egg_alt_rounded,
    color: K.cyan.withValues(alpha: 1),
    onTap: _capsule,
  );

  Future<bool> _unlockWithSponsor(GameSpec g) async {
    if (c.premiumNoAds) {
      final ok = await c.unlockWithReward(g.id);
      if (ok && mounted) await showDiscoveryReveal(context, g);
      return ok;
    }
    final r = await _ads.show(
      placementName: RewardPurpose.unlockAd(g.id).placementName,
    );
    if (r != RewardedAdResult.rewarded) {
      _toast(switch (r) {
        RewardedAdResult.notRewarded => 'sponsor_incomplete',
        RewardedAdResult.unavailable => 'sponsor_unavailable',
        _ => 'sponsor_failed',
      });
      return false;
    }
    final ok = await c.unlockWithReward(g.id);
    if (ok && mounted) await showDiscoveryReveal(context, g);
    return ok;
  }

  static String _fmt(int n) =>
      n >= 100000 ? '${(n / 1000).toStringAsFixed(0)}K' : '$n';
}

/// Retro TV that flips through discovered ads (or mystery channels).
class _Tv extends StatefulWidget {
  const _Tv({required this.controller});
  final AppController controller;

  @override
  State<_Tv> createState() => _TvState();
}

class _TvState extends State<_Tv> {
  late Timer _timer;
  int _index = 0;
  bool _static = false;
  final _rng = math.Random();

  List<GameSpec> get _pool {
    final found = allGames.where(widget.controller.isDiscovered).toList();
    return found.isEmpty
        ? allGames.where((g) => g.rarity == Rarity.superRare).toList()
        : found;
  }

  @override
  void initState() {
    super.initState();
    _index = _rng.nextInt(1000);
    _timer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
      if (!mounted) return;
      setState(() => _static = true);
      Future.delayed(const Duration(milliseconds: 180), () {
        if (mounted) {
          setState(() {
            _static = false;
            _index++;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pool = _pool;
    final g = pool[_index % pool.length];
    final unlocked = widget.controller.isDiscovered(g);
    final text = L10n.game(g.no);
    return Sticker(
      color: const Color(0xFF3A2C5E),
      radius: 26,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Stack(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: K.ink, width: 3),
                  ),
                  child: GameThumb(
                    key: ValueKey(g.no),
                    spec: g,
                    unlocked: unlocked,
                    radius: 9,
                  ),
                ),
                if (_static)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ColoredBox(
                        color: Colors.white.withValues(alpha: .6),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: K.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      L10n.ui('now_showing'),
                      style: K.t(11, color: K.red, weight: FontWeight.w900),
                    ),
                    const Spacer(),
                    Text(
                      '${L10n.ui('channel')} ${g.no.toString().padLeft(3, '0')}',
                      style: K.t(11, color: Colors.white54),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  unlocked ? text.title : '???',
                  style: K.t(18, weight: FontWeight.w900),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  unlocked ? text.hook : L10n.ui('locked_hint'),
                  style: K.t(12, color: Colors.white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Pill(
                      L10n.ui('cat_${g.cat.name}'),
                      color: K.category(g.cat),
                      size: 10,
                    ),
                    RarityBadge(
                      g.rarity,
                      label: L10n.ui('rarity_${g.rarity.name}'),
                      size: 9,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
