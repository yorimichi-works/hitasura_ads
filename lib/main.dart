import 'dart:math';

import 'package:flutter/material.dart';

void main() => runApp(const HitasuraAdsApp());

class HitasuraAdsApp extends StatelessWidget {
  const HitasuraAdsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ひたすら広告',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFC83D),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1020),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final Random _rng = Random();
  final AdCatalogRepository _repo = AdCatalogRepository.build();

  UserProfile _user = UserProfile(
    id: 'demo-user-001',
    nickname: '',
    age: 0,
    createdAt: DateTime.now(),
    explorationProfile: const ExplorationProfile(),
  );

  bool _initialized = false;
  int _tab = 0;
  int _todaySeconds = 0;
  int _totalSeconds = 0;
  int _viewCount = 0;
  String _status = 'READY';
  final List<AdLog> _logs = [];
  bool _secretOpened = false;

  List<AdDefinition> get _allAds => _repo.all;

  Future<void> _register(String nickname, int age) async {
    setState(() {
      _user = _user.copyWith(nickname: nickname, age: age);
      _initialized = true;
    });
  }

  void _openRanking() => setState(() => _tab = 1);
  void _openHome() => setState(() => _tab = 0);
  void _openProfile() => setState(() => _tab = 2);
  void _openCatalog() => setState(() => _tab = 3);

  void _watchAd({String? forcedId}) {
    final ad = forcedId == null
        ? _repo.randomAd(_rng, allowSecret: _secretOpened)
        : _repo.byId(forcedId)!;
    final seconds = 3 + _rng.nextInt(28);
    final now = DateTime.now();
    final newlySeen = _repo.markSeen(ad.id);

    setState(() {
      _todaySeconds += seconds;
      _totalSeconds += seconds;
      _viewCount += 1;
      _status = newlySeen ? 'NEW AD!' : 'SEEN AGAIN';
      _logs.insert(
        0,
        AdLog(
          adId: ad.id,
          title: ad.name,
          category: ad.category,
          rarity: ad.rarity,
          seconds: seconds,
          seenAt: now,
        ),
      );
      if (_repo.discoveredCount >= 150) {
        _secretOpened = true;
      }
    });
  }

  Future<void> _editProfile() async {
    final result = await showModalBottomSheet<ProfileDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF11172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => ProfileSheet(
        profile: _user.explorationProfile,
        nickname: _user.nickname,
        age: _user.age,
      ),
    );
    if (result == null) return;

    setState(() {
      _user = _user.copyWith(
        nickname: result.nickname,
        age: result.age,
        explorationProfile: result.profile,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return FirstLaunchScreen(onContinue: _register);
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.12,
                  child: CustomPaint(painter: AdNoisePainter()),
                ),
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      FilledButton.tonal(
                        onPressed: _openHome,
                        child: const Text('HOME'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: _openRanking,
                        child: const Text('RANKING'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: _openProfile,
                        child: const Text('EXPLORATION'),
                      ),
                      const Spacer(),
                      FilledButton.tonal(
                        onPressed: _openCatalog,
                        child: const Text('CATALOG'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _tab,
                    children: [
                      HomeScreen(
                        user: _user,
                        todaySeconds: _todaySeconds,
                        totalSeconds: _totalSeconds,
                        viewCount: _viewCount,
                        discoveredCount: _repo.discoveredCount,
                        totalCount: _allAds.length,
                        status: _status,
                        logs: _logs,
                        ads: _allAds,
                        onWatchAd: _watchAd,
                        onOpenRanking: _openRanking,
                        onOpenProfile: _openProfile,
                        onOpenCatalog: _openCatalog,
                        secretOpened: _secretOpened,
                      ),
                      RankingScreen(
                        user: _user,
                        totalSeconds: _totalSeconds,
                        discoveredCount: _repo.discoveredCount,
                        logs: _logs,
                      ),
                      ProfileScreen(
                        profile: _user.explorationProfile,
                        onEdit: _editProfile,
                      ),
                      CatalogScreen(
                        ads: _allAds,
                        discovered: _repo.discoveredIds,
                        onSelect: (id) {
                          _watchAd(forcedId: id);
                          setState(() => _tab = 0);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _watchAd,
        icon: const Icon(Icons.play_arrow),
        label: const Text('WATCH AD'),
      ),
    );
  }
}

class FirstLaunchScreen extends StatefulWidget {
  const FirstLaunchScreen({super.key, required this.onContinue});

  final Future<void> Function(String nickname, int age) onContinue;

  @override
  State<FirstLaunchScreen> createState() => _FirstLaunchScreenState();
}

class _FirstLaunchScreenState extends State<FirstLaunchScreen> {
  final TextEditingController _nickname = TextEditingController(text: '広告王');
  final TextEditingController _age = TextEditingController(text: '24');
  String? _error;

  @override
  void dispose() {
    _nickname.dispose();
    _age.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nickname = _nickname.text.trim();
    final age = int.tryParse(_age.text.trim());
    if (nickname.isEmpty || age == null || age < 1 || age > 120) {
      setState(() => _error = 'Nickname and age are required.');
      return;
    }
    await widget.onContinue(nickname, age);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                color: const Color(0xFF121A31),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        'ひたすら広告',
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ad is the content. That is all.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _nickname,
                        decoration: const InputDecoration(
                          labelText: 'Nickname',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _age,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Age',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      FilledButton(
                        onPressed: _submit,
                        child: const Text('はじめる'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.user,
    required this.todaySeconds,
    required this.totalSeconds,
    required this.viewCount,
    required this.discoveredCount,
    required this.totalCount,
    required this.status,
    required this.logs,
    required this.ads,
    required this.onWatchAd,
    required this.onOpenRanking,
    required this.onOpenProfile,
    required this.onOpenCatalog,
    required this.secretOpened,
  });

  final UserProfile user;
  final int todaySeconds;
  final int totalSeconds;
  final int viewCount;
  final int discoveredCount;
  final int totalCount;
  final String status;
  final List<AdLog> logs;
  final List<AdDefinition> ads;
  final VoidCallback onWatchAd;
  final VoidCallback onOpenRanking;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenCatalog;
  final bool secretOpened;

  @override
  Widget build(BuildContext context) {
    final topAd = logs.isEmpty
        ? ads.first
        : ads.firstWhere((a) => a.id == logs.first.adId, orElse: () => ads.first);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroAdCard(
            user: user,
            ad: topAd,
            status: status,
            onWatchAd: onWatchAd,
            onOpenCatalog: onOpenCatalog,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: StatCard(label: 'TODAY', value: formatDuration(todaySeconds))),
              const SizedBox(width: 12),
              Expanded(child: StatCard(label: 'TOTAL', value: formatDuration(totalSeconds))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: StatCard(label: 'VIEWS', value: viewCount.toString())),
              const SizedBox(width: 12),
              Expanded(child: StatCard(label: 'DISCOVERED', value: '$discoveredCount / $totalCount')),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HomeChip(label: 'Ranking', onTap: onOpenRanking),
              _HomeChip(label: 'Exploration', onTap: onOpenProfile),
              _HomeChip(label: 'Catalog', onTap: onOpenCatalog),
            ],
          ),
          const SizedBox(height: 16),
          if (secretOpened)
            const SecretPanel()
          else
            const _AttentionBanner(),
          const SizedBox(height: 16),
          Text('Recent logs', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...logs.take(6).map(
                (log) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      title: Text(log.title),
                      subtitle: Text('${log.category} · ${log.rarity} · ${formatDuration(log.seconds)}'),
                      trailing: Text(
                        '${log.seenAt.hour.toString().padLeft(2, '0')}:${log.seenAt.minute.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _HeroAdCard extends StatelessWidget {
  const _HeroAdCard({
    required this.user,
    required this.ad,
    required this.status,
    required this.onWatchAd,
    required this.onOpenCatalog,
  });

  final UserProfile user;
  final AdDefinition ad;
  final String status;
  final VoidCallback onWatchAd;
  final VoidCallback onOpenCatalog;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFF141E39),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF1D2A4D), Color(0xFF11172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Tag(text: 'AD'),
                const SizedBox(width: 8),
                Tag(text: ad.category),
                const Spacer(),
                Tag(text: status),
              ],
            ),
            const SizedBox(height: 16),
            Text('Welcome, ${user.nickname}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(ad.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(ad.description),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onWatchAd,
                    child: const Text('WATCH NOW'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: onOpenCatalog,
                  child: const Text('OPEN CATALOG'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeChip extends StatelessWidget {
  const _HomeChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }
}

class _AttentionBanner extends StatelessWidget {
  const _AttentionBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
        gradient: const LinearGradient(
          colors: [Color(0xFF232D4F), Color(0xFF11172A)],
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AD / PR / Sponsored / CHECK!'),
          SizedBox(height: 8),
          Text('The screen is intentionally crowded. The click target is obvious.'),
        ],
      ),
    );
  }
}

class Tag extends StatelessWidget {
  const Tag({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class RankingScreen extends StatelessWidget {
  const RankingScreen({
    super.key,
    required this.user,
    required this.totalSeconds,
    required this.discoveredCount,
    required this.logs,
  });

  final UserProfile user;
  final int totalSeconds;
  final int discoveredCount;
  final List<AdLog> logs;

  @override
  Widget build(BuildContext context) {
    final watchRanking = [
      RankingEntry(user.nickname, totalSeconds),
      RankingEntry('AD太郎', max(0, totalSeconds - 1372)),
      RankingEntry('広告大好き', max(0, totalSeconds - 2011)),
    ];
    final discoveryRanking = [
      RankingEntry(user.nickname, discoveredCount),
      RankingEntry('AD太郎', max(0, discoveredCount - 8)),
      RankingEntry('広告大好き', max(0, discoveredCount - 15)),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Ranking', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        RankingCard(
          title: 'Watch time',
          subtitle: 'Total ad viewing time',
          entries: watchRanking,
          formatValue: formatDuration,
        ),
        const SizedBox(height: 12),
        RankingCard(
          title: 'Discovery count',
          subtitle: 'Unique ad types discovered',
          entries: discoveryRanking,
          formatValue: (value) => '$value types',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Latest log: ${logs.isEmpty ? 'none' : logs.first.title}',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      ],
    );
  }
}

class RankingEntry {
  const RankingEntry(this.nickname, this.value);

  final String nickname;
  final int value;
}

class RankingCard extends StatelessWidget {
  const RankingCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.entries,
    required this.formatValue,
  });

  final String title;
  final String subtitle;
  final List<RankingEntry> entries;
  final String Function(int value) formatValue;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            for (var i = 0; i < entries.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(entries[i].nickname)),
                    Text(formatValue(entries[i].value)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.profile, required this.onEdit});

  final ExplorationProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Exploration profile', style: Theme.of(context).textTheme.headlineSmall),
            ),
            FilledButton(onPressed: onEdit, child: const Text('EDIT')),
          ],
        ),
        const SizedBox(height: 12),
        InfoCard(
          title: 'Basics',
          lines: [
            'Age group: ${profile.ageGroup ?? 'unset'}',
            'Gender: ${profile.gender ?? 'unset'}',
            'Region: ${profile.region ?? 'unset'}',
            'Language: ${profile.language ?? 'unset'}',
          ],
        ),
        const SizedBox(height: 12),
        InfoCard(
          title: 'Interests',
          lines: profile.interests.isEmpty ? const ['unset'] : (profile.interests.toList()..sort()),
        ),
        const SizedBox(height: 12),
        const InfoCard(
          title: 'Privacy',
          lines: [
            'Exploration settings are separate from real consent.',
            'Sensitive attributes are not collected.',
          ],
        ),
      ],
    );
  }
}

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({
    super.key,
    required this.ads,
    required this.discovered,
    required this.onSelect,
  });

  final List<AdDefinition> ads;
  final Set<String> discovered;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: ads.length,
      itemBuilder: (context, index) {
        final ad = ads[index];
        return _CatalogTile(
          ad: ad,
          discovered: discovered.contains(ad.id),
          onTap: () => onSelect(ad.id),
        );
      },
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.ad,
    required this.discovered,
    required this.onTap,
  });

  final AdDefinition ad;
  final bool discovered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Card(
        color: discovered ? const Color(0xFF16243E) : const Color(0xFF10182A),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Tag(text: ad.id),
                  const Spacer(),
                  Tag(text: discovered ? 'FOUND' : 'NEW'),
                ],
              ),
              const SizedBox(height: 12),
              Text(ad.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(ad.description, maxLines: 4, overflow: TextOverflow.ellipsis),
              const Spacer(),
              Text('${ad.category} · ${ad.rarity}', style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line),
              ),
          ],
        ),
      ),
    );
  }
}

class ProfileSheet extends StatefulWidget {
  const ProfileSheet({
    super.key,
    required this.profile,
    required this.nickname,
    required this.age,
  });

  final ExplorationProfile profile;
  final String nickname;
  final int age;

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  late final TextEditingController _nickname;
  late final TextEditingController _age;
  late final TextEditingController _region;
  late final TextEditingController _language;
  String? _gender;
  final Set<String> _interests = {};

  static const List<String> _interestOptions = [
    'Game',
    'Manga',
    'Anime',
    'Movie',
    'Music',
    'Travel',
    'Gourmet',
    'Fashion',
    'IT',
    'Car',
    'Education',
    'Business',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _nickname = TextEditingController(text: widget.nickname);
    _age = TextEditingController(text: widget.age == 0 ? '' : widget.age.toString());
    _region = TextEditingController(text: widget.profile.region ?? '');
    _language = TextEditingController(text: widget.profile.language ?? '');
    _gender = widget.profile.gender;
    _interests.addAll(widget.profile.interests);
  }

  @override
  void dispose() {
    _nickname.dispose();
    _age.dispose();
    _region.dispose();
    _language.dispose();
    super.dispose();
  }

  void _save() {
    final age = int.tryParse(_age.text.trim()) ?? widget.age;
    final profile = ExplorationProfile(
      ageGroup: _ageGroupFromAge(age),
      gender: _gender,
      region: _region.text.trim().isEmpty ? null : _region.text.trim(),
      language: _language.text.trim().isEmpty ? null : _language.text.trim(),
      interests: _interests,
    );
    Navigator.of(context).pop(
      ProfileDraft(
        nickname: _nickname.text.trim().isEmpty ? widget.nickname : _nickname.text.trim(),
        age: age,
        profile: profile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 56,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Exploration edit', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            TextField(
              controller: _nickname,
              decoration: const InputDecoration(labelText: 'Nickname', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _age,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _gender ?? 'unset',
              decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'unset', child: Text('Unset')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (value) => setState(() => _gender = value == 'unset' ? null : value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _region,
              decoration: const InputDecoration(labelText: 'Region', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _language,
              decoration: const InputDecoration(labelText: 'Language', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final interest in _interestOptions)
                  FilterChip(
                    label: Text(interest),
                    selected: _interests.contains(interest),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _interests.add(interest);
                        } else {
                          _interests.remove(interest);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('SAVE')),
          ],
        ),
      ),
    );
  }
}

class SecretPanel extends StatelessWidget {
  const SecretPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF23161F),
        border: Border.all(color: const Color(0xFFFFC83D).withValues(alpha: 0.6)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SECRET PANEL', style: TextStyle(fontWeight: FontWeight.w900)),
          SizedBox(height: 8),
          Text('All 151 ads discovered. Hidden metadata is now available.'),
        ],
      ),
    );
  }
}

class AdNoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke;
    const texts = ['AD', 'PR', 'Sponsored', 'CHECK!', 'PICK UP', 'NOW'];
    final rng = Random(4);
    for (var i = 0; i < 120; i++) {
      paint.color = Colors.primaries[i % Colors.primaries.length].withValues(alpha: 0.2);
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final w = 50 + rng.nextDouble() * 160;
      final h = 16 + rng.nextDouble() * 48;
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(10));
      canvas.drawRRect(rect, paint);
      final tp = TextPainter(
        text: TextSpan(
          text: texts[i % texts.length],
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.12),
            fontSize: 10 + (i % 4).toDouble(),
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + 6, y + 4));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String formatDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m ${secs.toString().padLeft(2, '0')}s';
}

String? _ageGroupFromAge(int age) {
  if (age < 18) return 'under 18';
  if (age < 25) return '18-24';
  if (age < 35) return '25-34';
  if (age < 45) return '35-44';
  if (age < 55) return '45-54';
  return '55+';
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.nickname,
    required this.age,
    required this.createdAt,
    required this.explorationProfile,
  });

  final String id;
  final String nickname;
  final int age;
  final DateTime createdAt;
  final ExplorationProfile explorationProfile;

  UserProfile copyWith({
    String? nickname,
    int? age,
    ExplorationProfile? explorationProfile,
  }) {
    return UserProfile(
      id: id,
      nickname: nickname ?? this.nickname,
      age: age ?? this.age,
      createdAt: createdAt,
      explorationProfile: explorationProfile ?? this.explorationProfile,
    );
  }
}

class ExplorationProfile {
  const ExplorationProfile({
    this.ageGroup,
    this.gender,
    this.region,
    this.language,
    this.interests = const {},
  });

  final String? ageGroup;
  final String? gender;
  final String? region;
  final String? language;
  final Set<String> interests;
}

class ProfileDraft {
  const ProfileDraft({
    required this.nickname,
    required this.age,
    required this.profile,
  });

  final String nickname;
  final int age;
  final ExplorationProfile profile;
}

class AdLog {
  const AdLog({
    required this.adId,
    required this.title,
    required this.category,
    required this.rarity,
    required this.seconds,
    required this.seenAt,
  });

  final String adId;
  final String title;
  final String category;
  final String rarity;
  final int seconds;
  final DateTime seenAt;
}

enum AdInteractionType { banner, card, video, native, popup }

class AdDefinition {
  const AdDefinition({
    required this.id,
    required this.number,
    required this.name,
    required this.description,
    required this.category,
    required this.rarity,
    required this.interactionType,
    required this.targetTags,
    required this.unlockCondition,
  });

  final String id;
  final int number;
  final String name;
  final String description;
  final String category;
  final String rarity;
  final AdInteractionType interactionType;
  final List<String> targetTags;
  final String unlockCondition;
}

class AdCatalogRepository {
  AdCatalogRepository._(this.all, this.discoveredIds);

  factory AdCatalogRepository.build() {
    final all = <AdDefinition>[];
    final discoveredIds = <String>{};
    const categories = [
      'Food',
      'Game',
      'Travel',
      'Fashion',
      'Education',
      'Finance',
      'App',
      'Movie',
      'Music',
      'Utility',
    ];
    const rarities = ['Common', 'Uncommon', 'Rare', 'Epic', 'Legendary'];
    const interactions = AdInteractionType.values;
    for (var i = 1; i <= 151; i++) {
      final category = categories[(i - 1) % categories.length];
      final rarity = rarities[(i - 1) % rarities.length];
      final interactionType = interactions[(i - 1) % interactions.length];
      final id = 'AD_${i.toString().padLeft(3, '0')}';
      all.add(
        AdDefinition(
          id: id,
          number: i,
          name: _titleFor(i),
          description: _descriptionFor(i, category, rarity, interactionType),
          category: category,
          rarity: rarity,
          interactionType: interactionType,
          targetTags: _tagsFor(category, i),
          unlockCondition: i == 151
              ? 'Discover 150 types to reveal the secret'
              : 'Visible from the start',
        ),
      );
    }
    return AdCatalogRepository._(all, discoveredIds);
  }

  final List<AdDefinition> all;
  final Set<String> discoveredIds;

  int get discoveredCount => discoveredIds.length;

  AdDefinition? byId(String id) {
    for (final ad in all) {
      if (ad.id == id) return ad;
    }
    return null;
  }

  bool markSeen(String id) => discoveredIds.add(id);

  AdDefinition randomAd(Random rng, {required bool allowSecret}) {
    final pool = allowSecret ? all : all.where((ad) => ad.id != 'AD_151').toList(growable: false);
    return pool[rng.nextInt(pool.length)];
  }

  static String _titleFor(int index) {
    const prefixes = [
      'Flash',
      'Ultra',
      'Mega',
      'Daily',
      'Prime',
      'Lucky',
      'Secret',
      'Bright',
      'Rapid',
      'Neo',
    ];
    const nouns = [
      'Snack',
      'Quest',
      'Sale',
      'Boost',
      'Guide',
      'Play',
      'Deal',
      'Trip',
      'Beat',
      'Lab',
    ];
    return '${prefixes[(index - 1) % prefixes.length]} ${nouns[(index - 1) % nouns.length]} ${index.toString().padLeft(3, '0')}';
  }

  static String _descriptionFor(int index, String category, String rarity, AdInteractionType type) {
    final typeLabel = switch (type) {
      AdInteractionType.banner => 'banner',
      AdInteractionType.card => 'card',
      AdInteractionType.video => 'video',
      AdInteractionType.native => 'native',
      AdInteractionType.popup => 'popup',
    };
    return 'A $rarity $category ad built as a $typeLabel unit. Entry #$index in the discovery catalog.';
  }

  static List<String> _tagsFor(String category, int index) {
    final tags = <String>[category, 'catalog', 'ad'];
    if (index % 2 == 0) tags.add('even');
    if (index % 3 == 0) tags.add('triad');
    if (index % 5 == 0) tags.add('special');
    return tags;
  }
}
