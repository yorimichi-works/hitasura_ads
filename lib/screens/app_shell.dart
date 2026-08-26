import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/ad_definition.dart';
import '../models/reward_purpose.dart';
import '../services/ad_audio_manager.dart';
import '../services/rewarded_ad_service.dart';
import '../state/app_controller.dart';
import '../widgets/ad_experience_overlay.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'records_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller, this.rewardedAdService});

  final AppController controller;
  final RewardedAdService? rewardedAdService;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  late final AdAudioManager _audio = AdAudioManager();
  late final RewardedAdService _rewardedAds;
  late final Timer _energyTicker;
  bool _rewardInProgress = false;
  bool _playInProgress = false;

  @override
  void initState() {
    super.initState();
    _rewardedAds =
        widget.rewardedAdService ??
        (kDebugMode && kIsWeb
            ? DebugRewardedAdService()
            : GoogleRewardedAdService());
    _rewardedAds.addListener(_onRewardStatusChanged);
    unawaited(_rewardedAds.initialize());
    _energyTicker = Timer.periodic(const Duration(seconds: 1), (_) async {
      await widget.controller.refreshSearchEnergy();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    unawaited(_audio.dispose());
    _energyTicker.cancel();
    _rewardedAds.removeListener(_onRewardStatusChanged);
    _rewardedAds.dispose();
    super.dispose();
  }

  void _onRewardStatusChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _play([AdDefinition? forcedAd]) async {
    if (_playInProgress) return;
    _playInProgress = true;
    try {
      await _performPlay(forcedAd);
    } finally {
      _playInProgress = false;
    }
  }

  Future<void> _replay(AdDefinition ad) async {
    if (_playInProgress) return;
    _playInProgress = true;
    try {
      await _performPlay(ad, consumeEnergy: false);
    } finally {
      _playInProgress = false;
    }
  }

  Future<void> _performPlay(
    AdDefinition? forcedAd, {
    bool consumeEnergy = true,
  }) async {
    if (consumeEnergy && !await widget.controller.consumeSearchEnergy()) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('探索回数が回復するまでお待ちください')));
      }
      return;
    }
    if (!mounted) return;
    final ad = forcedAd ?? widget.controller.selectAd();
    final result = await showGeneralDialog<AdPlaybackResult>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (context, animation, _, child) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: animation, child: child),
      ),
      pageBuilder: (context, _, _) => AdExperienceOverlay(
        ad: ad,
        soundEffectsEnabled: widget.controller.soundEffectsEnabled,
      ),
    );
    if (result == null || !mounted) return;
    final isNew = await widget.controller.completeAd(
      ad,
      result.activeSeconds,
      allowDiscovery: !widget.controller.debugUnlockAll,
    );
    if (!mounted || !isNew) return;
    await Future<void>.delayed(const Duration(milliseconds: 160));
    unawaited(
      _audio.playDiscovery(enabled: widget.controller.soundEffectsEnabled),
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) =>
          _DiscoveryDialog(ad: ad, complete: widget.controller.isComplete),
    );
  }

  Future<void> _restoreWithSponsor() async {
    await _runReward(const RewardPurpose.restoreSearchEnergy());
  }

  Future<bool> _unlockWithSponsor(AdDefinition ad) =>
      _runReward(RewardPurpose.unlockAd(ad.id));

  Future<bool> _runReward(RewardPurpose purpose) async {
    if (_rewardInProgress) return false;
    setState(() => _rewardInProgress = true);
    RewardedAdResult result;
    var rewardApplied = false;
    AdDefinition? unlockedAd;
    try {
      result = await _rewardedAds.show();
      if (result == RewardedAdResult.rewarded) {
        switch (purpose.type) {
          case RewardPurposeType.restoreSearchEnergy:
            await widget.controller.refillSearchEnergy();
            rewardApplied = true;
            break;
          case RewardPurposeType.unlockAd:
            final target = widget.controller.catalog.byId[purpose.adId];
            if (target != null) {
              rewardApplied = await widget.controller.unlockAdWithReward(
                target.id,
              );
              if (rewardApplied) unlockedAd = target;
            }
            break;
        }
      }
    } finally {
      if (mounted) setState(() => _rewardInProgress = false);
    }
    if (!mounted) return rewardApplied;
    if (unlockedAd != null) {
      await Future<void>.delayed(const Duration(milliseconds: 160));
      unawaited(
        _audio.playDiscovery(enabled: widget.controller.soundEffectsEnabled),
      );
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => _DiscoveryDialog(
            ad: unlockedAd!,
            complete: widget.controller.isComplete,
          ),
        );
      }
      return true;
    }
    final message = switch (result) {
      RewardedAdResult.rewarded when rewardApplied => '探索回数が5/5まで回復しました',
      RewardedAdResult.rewarded => 'この広告はすでに発見済みです',
      RewardedAdResult.notRewarded => '広告の視聴が完了しなかったため報酬はありません',
      RewardedAdResult.unavailable => 'この環境ではスポンサー広告を利用できません',
      RewardedAdResult.loadFailed => 'スポンサー広告を読み込めませんでした',
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    return rewardApplied;
  }

  Future<void> _openDebugPicker() async {
    if (!kDebugMode) return;
    final ad = await showModalBottomSheet<AdDefinition>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .82,
          child: Column(
            children: [
              const ListTile(
                title: Text(
                  'テスト環境',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text('開発ビルド専用。通常の報酬導線を検証します'),
              ),
              ListTile(
                key: const Key('debug-ad-environment'),
                leading: const Icon(Icons.science_outlined),
                title: const Text('Ad Environment: TEST'),
                subtitle: Text(kIsWeb ? 'WEB DEBUG 疑似リワード' : 'Google公式テスト広告ID'),
              ),
              ListTile(
                leading: const Icon(Icons.battery_5_bar),
                title: Text('探索回数 ${widget.controller.searchEnergy}/5'),
                trailing: PopupMenuButton<int>(
                  tooltip: '探索回数をテスト変更',
                  onSelected: widget.controller.setSearchEnergyForDebug,
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 0, child: Text('0/5にする')),
                    PopupMenuItem(value: 1, child: Text('1/5にする')),
                    PopupMenuItem(value: 5, child: Text('5/5にする')),
                  ],
                ),
              ),
              SwitchListTile(
                key: const Key('debug-unlock-all-toggle'),
                secondary: const Icon(Icons.visibility_outlined),
                title: const Text('全開放デバッグモード'),
                subtitle: Text(
                  widget.controller.debugUnlockAll
                      ? 'DEBUG：全広告表示中（保存データは変更しません）'
                      : '本来の図鑑状態を表示中',
                ),
                value: widget.controller.debugUnlockAll,
                onChanged: (value) {
                  widget.controller.setDebugUnlockAll(value);
                  setState(() {});
                  Navigator.pop(context);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton(
                  key: const Key('debug-lock-all'),
                  onPressed: () async {
                    await widget.controller.clearAllDiscoveryForDebug();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('保存済み図鑑を全件未開放にする'),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.controller.catalog.all.length,
                  itemBuilder: (context, index) {
                    final item = widget.controller.catalog.all[index];
                    final discovered = widget.controller.discoveredIds.contains(
                      item.id,
                    );
                    return ListTile(
                      leading: Text(item.displayNumber),
                      title: Text(item.name),
                      trailing: discovered
                          ? IconButton(
                              key: Key('reset-discovery-${item.id}'),
                              tooltip: '${item.displayNumber}を未発見に戻す',
                              icon: const Icon(Icons.restart_alt),
                              onPressed: () async {
                                await widget.controller.resetDiscoveryForDebug(
                                  item.id,
                                );
                                if (context.mounted) Navigator.pop(context);
                              },
                            )
                          : null,
                      onTap: () => Navigator.pop(context, item),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ad != null && mounted) await _play(ad);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        onPlay: _play,
        onDebug: kDebugMode ? _openDebugPicker : null,
        searchEnergy: widget.controller.searchEnergy,
        recoveryCountdown: _formatCountdown(
          widget.controller.timeUntilSearchRecovery,
        ),
        onSponsorReward: _restoreWithSponsor,
        sponsorLoading: _rewardInProgress,
        sponsorAvailable: _rewardedAds.isSupported,
        sponsorCanRequest:
            _rewardedAds.status == RewardedAdStatus.ready ||
            _rewardedAds.status == RewardedAdStatus.failed,
        sponsorStatus: _rewardedAds.status.name.toUpperCase(),
        sponsorUsesTestAds: _rewardedAds.usesTestAds,
      ),
      RecordsScreen(
        controller: widget.controller,
        onReplay: _replay,
        onRewardUnlock: _unlockWithSponsor,
        rewardUnlockAvailable: _rewardedAds.isSupported,
        rewardInProgress: _rewardInProgress,
        rewardStatus: _rewardedAds.status,
      ),
      ProfileScreen(controller: widget.controller),
    ];
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.smart_display_outlined),
            selectedIcon: Icon(Icons.smart_display),
            label: 'ホーム',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: '記録',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune),
            selectedIcon: Icon(Icons.tune),
            label: '広告探索',
          ),
        ],
      ),
    );
  }

  String _formatCountdown(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 20 * 60);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _DiscoveryDialog extends StatelessWidget {
  const _DiscoveryDialog({required this.ad, required this.complete});

  final AdDefinition ad;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Text(
        ad.isSecret
            ? '151 / 151'
            : ad.isRare
            ? 'RARE!'
            : 'NEW!',
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
      ),
      title: Text(
        ad.isSecret ? 'おめでとう！\n151番目の広告を見つけたぞ！' : '新しい広告！',
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(ad.displayNumber),
          const SizedBox(height: 8),
          Text(
            ad.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            '「${ad.discoveryText}」',
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            complete ? '広告図鑑 COMPLETE' : '広告図鑑に登録しました！',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}
