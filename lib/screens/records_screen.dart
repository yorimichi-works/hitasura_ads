import 'dart:math';

import 'package:flutter/material.dart';

import '../models/ad_definition.dart';
import '../services/rewarded_ad_service.dart';
import '../state/app_controller.dart';

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({
    super.key,
    required this.controller,
    required this.onReplay,
    required this.onRewardUnlock,
    required this.rewardUnlockAvailable,
    required this.rewardInProgress,
    required this.rewardStatus,
  });

  final AppController controller;
  final Future<void> Function(AdDefinition ad) onReplay;
  final Future<bool> Function(AdDefinition ad) onRewardUnlock;
  final bool rewardUnlockAvailable;
  final bool rewardInProgress;
  final RewardedAdStatus rewardStatus;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        const _PageTitle(title: '記録', subtitle: '見た広告のことは、全部ここ。'),
        const SizedBox(height: 18),
        Card(
          child: InkWell(
            key: const Key('catalog-open-button'),
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CatalogScreen(
                  controller: controller,
                  onReplay: onReplay,
                  onRewardUnlock: onRewardUnlock,
                  rewardUnlockAvailable: rewardUnlockAvailable,
                  rewardInProgress: rewardInProgress,
                  rewardStatus: rewardStatus,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  const Icon(Icons.auto_stories, size: 44),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '広告図鑑',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${controller.discoveredCount} / 151',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (controller.isComplete)
                          const Text(
                            'COMPLETE',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _MetricCard(
                label: '今日の探索時間',
                value: formatDuration(controller.todayWatchSeconds),
              ),
              _MetricCard(
                label: '累計探索時間',
                value: formatDuration(controller.totalWatchSeconds),
              ),
              _MetricCard(label: '広告視聴回数', value: '${controller.watchCount} 回'),
            ];
            if (constraints.maxWidth < 620) {
              return Column(
                children: [
                  for (final card in cards)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: card,
                    ),
                ],
              );
            }
            return Row(
              children: [
                for (final card in cards)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: card,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        const Text(
          'ランキング',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        _RankingCard(
          title: '広告探索時間',
          entries: _timeRanking(controller),
          valueBuilder: formatDuration,
        ),
        const SizedBox(height: 12),
        _RankingCard(
          title: '広告発見種類',
          entries: _discoveryRanking(controller),
          valueBuilder: (value) => '$value 種類',
        ),
        const SizedBox(height: 8),
        const Text(
          'ランキングは現在この端末内のMVP表示です。クラウド接続後も画面構造はそのまま利用できます。',
          style: TextStyle(fontSize: 11, color: Colors.black54),
        ),
      ],
    );
  }

  List<_RankingEntry> _timeRanking(AppController controller) {
    final mine = controller.totalWatchSeconds;
    return [
      _RankingEntry('広告王', max(mine + 3600, 4920)),
      _RankingEntry(controller.user!.nickname, mine),
      _RankingEntry('AD太郎', max(0, mine - 813)),
    ]..sort((a, b) => b.value.compareTo(a.value));
  }

  List<_RankingEntry> _discoveryRanking(AppController controller) {
    final mine = controller.discoveredCount;
    return [
      _RankingEntry('広告王', min(151, max(mine + 12, 32))),
      _RankingEntry(controller.user!.nickname, mine),
      _RankingEntry('広告大好き', max(0, mine - 7)),
    ]..sort((a, b) => b.value.compareTo(a.value));
  }
}

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({
    super.key,
    required this.controller,
    required this.onReplay,
    required this.onRewardUnlock,
    required this.rewardUnlockAvailable,
    required this.rewardInProgress,
    required this.rewardStatus,
  });

  final AppController controller;
  final Future<void> Function(AdDefinition ad) onReplay;
  final Future<bool> Function(AdDefinition ad) onRewardUnlock;
  final bool rewardUnlockAvailable;
  final bool rewardInProgress;
  final RewardedAdStatus rewardStatus;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  bool _onlyDiscovered = false;

  @override
  Widget build(BuildContext context) {
    final ads = _onlyDiscovered
        ? widget.controller.catalog.all
              .where((ad) => widget.controller.discoveredIds.contains(ad.id))
              .toList()
        : widget.controller.catalog.all;
    return Scaffold(
      appBar: AppBar(
        title: const Text('広告図鑑'),
        actions: [
          FilterChip(
            label: const Text('発見済みのみ'),
            selected: _onlyDiscovered,
            onSelected: (value) => setState(() => _onlyDiscovered = value),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1000
              ? 5
              : constraints.maxWidth >= 700
              ? 4
              : constraints.maxWidth >= 450
              ? 3
              : 2;
          return GridView.builder(
            padding: const EdgeInsets.all(14),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: .82,
            ),
            itemCount: ads.length,
            itemBuilder: (context, index) {
              final ad = ads[index];
              final found = widget.controller.discoveredIds.contains(ad.id);
              return _CatalogTile(
                ad: ad,
                found: found,
                onTap: () => found
                    ? _showDetail(context, ad)
                    : _showLockedDetail(context, ad),
              );
            },
          );
        },
      ),
    );
  }

  void _showLockedDetail(BuildContext context, AdDefinition ad) {
    final regularFound = widget.controller.catalog.all
        .where((item) => !item.isSecret)
        .where((item) => widget.controller.discoveredIds.contains(item.id))
        .length;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ad.displayNumber,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              '未発見の広告',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            const Text(
              '通常の解放条件',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(ad.unlockCondition),
            if (ad.isSecret) ...[
              const SizedBox(height: 8),
              Text('発見状況: $regularFound / 150'),
            ],
            if (!ad.isSecret && widget.rewardUnlockAvailable) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                key: Key('reward-unlock-${ad.id}'),
                onPressed:
                    widget.rewardInProgress ||
                        (widget.rewardStatus != RewardedAdStatus.ready &&
                            widget.rewardStatus != RewardedAdStatus.failed)
                    ? null
                    : () async {
                        Navigator.pop(sheetContext);
                        await widget.onRewardUnlock(ad);
                        if (mounted) setState(() {});
                      },
                icon: const Icon(Icons.ondemand_video),
                label: Text(
                  widget.rewardStatus == RewardedAdStatus.loading
                      ? 'スポンサー広告を準備中'
                      : 'スポンサー広告を見てこの広告を解放',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, AdDefinition ad) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ad.displayNumber,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              ad.name,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text('「${ad.description}」', style: const TextStyle(fontSize: 17)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(ad.rarity)),
                Chip(label: Text(ad.category)),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: Key('catalog-replay-${ad.id}'),
              onPressed: () async {
                Navigator.pop(context);
                await widget.onReplay(ad);
              },
              icon: const Icon(Icons.sports_esports),
              label: const Text('この広告ゲームをもう一度遊ぶ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.ad,
    required this.found,
    required this.onTap,
  });

  final AdDefinition ad;
  final bool found;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final secret = ad.isSecret && !found;
    return Card(
      key: Key('catalog-tile-${ad.id}'),
      color: secret
          ? const Color(0xFF111111)
          : found
          ? Colors.white
          : const Color(0xFFE8E3DA),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ad.displayNumber,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: secret ? Colors.white : Colors.black,
                ),
              ),
              const Spacer(),
              Center(
                child: Text(
                  found
                      ? ad.symbol
                      : secret
                      ? 'SECRET'
                      : '？',
                  style: TextStyle(
                    fontSize: secret ? 18 : 36,
                    color: secret ? Colors.amber : Colors.black38,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                found ? ad.name : '？？？？？？？？？',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: secret ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                found
                    ? ad.rarity
                    : secret
                    ? 'SECRET'
                    : '未発見',
                style: TextStyle(
                  fontSize: 11,
                  color: secret ? Colors.amber : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    ),
  );
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.title,
    required this.entries,
    required this.valueBuilder,
  });

  final String title;
  final List<_RankingEntry> entries;
  final String Function(int) valueBuilder;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < entries.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${i + 1}位',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Expanded(child: Text(entries[i].name)),
                  Text(
                    valueBuilder(entries[i].value),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _RankingEntry {
  const _RankingEntry(this.name, this.value);
  final String name;
  final int value;
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
      ),
      Text(subtitle),
    ],
  );
}

String formatDuration(int totalSeconds) {
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  return '$hours時間${minutes.toString().padLeft(2, '0')}分${seconds.toString().padLeft(2, '0')}秒';
}
