import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/ad_definition.dart';
import '../state/app_controller.dart';
import '../widgets/ad_experience_overlay.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'records_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  Future<void> _play([AdDefinition? forcedAd]) async {
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
      pageBuilder: (context, _, _) => AdExperienceOverlay(ad: ad),
    );
    if (result == null || !mounted) return;
    final isNew = await widget.controller.completeAd(ad, result.activeSeconds);
    if (!mounted || !isNew) return;
    await showDialog<void>(
      context: context,
      builder: (context) =>
          _DiscoveryDialog(ad: ad, complete: widget.controller.isComplete),
    );
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
                  '広告デバッグ',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text('任意の広告を強制表示します'),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.controller.catalog.all.length,
                  itemBuilder: (context, index) {
                    final item = widget.controller.catalog.all[index];
                    return ListTile(
                      leading: Text(item.displayNumber),
                      title: Text(item.name),
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
      HomeScreen(onPlay: _play, onDebug: _openDebugPicker),
      RecordsScreen(controller: widget.controller),
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
