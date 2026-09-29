import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../arcade/engine/game.dart';
import '../arcade/registry.dart';
import '../arcade/spec.dart';
import '../data/app_store.dart';
import '../l10n/l10n.dart';
import '../models/app_models.dart';
import '../services/cloud_progress_service.dart';
import '../services/google_auth_service.dart';
import '../services/search_energy_service.dart';

/// What a finished play earned.
class PlayReward {
  const PlayReward({
    required this.isNew,
    required this.coins,
    required this.xp,
    required this.leveledUp,
    required this.newLevel,
    required this.bestStars,
    required this.improved,
  });
  final bool isNew;
  final int coins;
  final int xp;
  final bool leveledUp;
  final int newLevel;
  final int bestStars;
  final bool improved;
}

class AppController extends ChangeNotifier {
  AppController._({
    required AppStore store,
    required AppSnapshot snapshot,
    required SearchEnergyService searchEnergyService,
    required AuthSession? authSession,
    required ProgressCloudStore? cloudStore,
    Random? random,
  })  : _store = store,
        _authSession = authSession,
        _cloudStore = cloudStore,
        _random = random ?? Random(),
        _user = snapshot.user,
        _cloudAccountUid = snapshot.cloudAccountUid,
        _profile = snapshot.explorationProfile,
        _discoveredIds = {...snapshot.discoveredIds},
        _totalWatchSeconds = snapshot.totalWatchSeconds,
        _todayWatchSeconds = _isToday(snapshot.statsDate) ? snapshot.todayWatchSeconds : 0,
        _watchCount = snapshot.watchCount,
        _soundEffectsEnabled = snapshot.soundEffectsEnabled,
        _arcade = snapshot.arcade,
        _searchEnergyService = searchEnergyService,
        _searchEnergyState = searchEnergyService.synchronize(
          SearchEnergyState(
            remaining: snapshot.searchEnergy,
            recoveryAnchor: snapshot.searchEnergyRecoveryAnchor ?? searchEnergyService.now(),
          ),
        ) {
    L10n.code = _arcade.language ?? L10n.detect();
  }

  static Future<AppController> create({
    AppStore? store,
    Random? random,
    DateTime Function()? clock,
    AuthSession? authSession,
    ProgressCloudStore? cloudStore,
  }) async {
    final actualStore = store ?? PreferencesAppStore();
    final controller = AppController._(
      store: actualStore,
      snapshot: await actualStore.load(),
      searchEnergyService: SearchEnergyService(clock: clock),
      authSession: authSession,
      cloudStore: cloudStore,
      random: random,
    );
    await controller._store.save(controller._snapshot());
    if (authSession != null && cloudStore != null) {
      await controller._startCloudSync();
    }
    return controller;
  }

  final AppStore _store;
  final SearchEnergyService _searchEnergyService;
  final AuthSession? _authSession;
  final ProgressCloudStore? _cloudStore;
  final Random _random;
  UserProfile? _user;
  String? _cloudAccountUid;
  ExplorationProfile _profile;
  final Set<String> _discoveredIds;
  int _totalWatchSeconds;
  int _todayWatchSeconds;
  int _watchCount;
  bool _soundEffectsEnabled;
  ArcadeState _arcade;
  SearchEnergyState _searchEnergyState;
  bool _cloudSyncing = false;
  bool _cloudSynced = false;
  String? _cloudSyncError;
  bool _unlockAll = false;
  final List<int> _recent = [];

  // ------------------------------------------------------------- getters ---

  List<GameSpec> get games => allGames;
  UserProfile? get user => _user;
  bool get isRegistered => _user != null;
  ArcadeState get arcade => _arcade;
  int get coins => _arcade.coins;
  int get level => _arcade.level;
  Set<String> get discoveredIds => Set.unmodifiable(_discoveredIds);
  bool isDiscovered(GameSpec g) => _unlockAll || _discoveredIds.contains(g.id);
  int get discoveredCount => _unlockAll ? allGames.length : allGames.where((g) => _discoveredIds.contains(g.id)).length;
  bool get isComplete => allGames.every((g) => _discoveredIds.contains(g.id));
  int starsOf(GameSpec g) => _arcade.stars[g.id] ?? 0;
  int playsOf(GameSpec g) => _arcade.plays[g.id] ?? 0;
  int get totalWatchSeconds => _totalWatchSeconds;
  int get watchCount => _watchCount;
  bool get soundEffectsEnabled => _soundEffectsEnabled;
  int get searchEnergy => _searchEnergyState.remaining;
  bool get canSearch => searchEnergy > 0;
  Duration get timeUntilSearchRecovery => _searchEnergyService.untilNextRecovery(_searchEnergyState);
  bool get cloudSyncing => _cloudSyncing;
  bool get cloudSynced => _cloudSynced;
  String? get cloudSyncError => _cloudSyncError;
  bool get unlockAll => _unlockAll;
  static const _adminToolsCompiled = bool.fromEnvironment('ENABLE_ADMIN_TOOLS');
  bool get adminToolsEnabled => kDebugMode || _adminToolsCompiled;

  /// Discovered games that fit in RUSH mode.
  List<GameSpec> get rushPool => allGames.where((g) => g.rushable && isDiscovered(g)).toList();
  static const rushUnlockCount = 5;
  bool get rushUnlocked => rushPool.length >= rushUnlockCount;

  bool get dailyAvailable => _arcade.dailyDate != _dateKey(DateTime.now());

  // ------------------------------------------------------------- actions ---

  Future<void> register(String nickname) async {
    final now = DateTime.now();
    _user = UserProfile(
      id: '${now.microsecondsSinceEpoch}-${Random().nextInt(999999)}',
      nickname: nickname.trim().isEmpty ? 'Ad Hunter' : nickname.trim(),
      age: 0,
      createdAt: now,
    );
    _arcade = _arcade.copyWith(language: L10n.code, coins: _arcade.coins + 100);
    await _persist();
    notifyListeners();
  }

  Future<void> setNickname(String nickname) async {
    if (_user == null || nickname.trim().isEmpty) return;
    _user = _user!.copyWith(nickname: nickname.trim());
    await _persist();
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    L10n.code = code;
    _arcade = _arcade.copyWith(language: code);
    await _persist();
    notifyListeners();
  }

  /// Chooses the next ad: prefers undiscovered ones, weighted by rarity,
  /// avoids recent repeats; the secret appears once all 150 are found.
  GameSpec pickNextGame() {
    final regular = allGames.where((g) => !g.isSecret).toList();
    final secret = allGames.firstWhere((g) => g.isSecret);
    final allRegularFound = regular.every((g) => _discoveredIds.contains(g.id));
    if (allRegularFound && !_discoveredIds.contains(secret.id)) return _remember(secret);
    final undiscovered = regular.where((g) => !_discoveredIds.contains(g.id)).toList();
    List<GameSpec> pool;
    if (undiscovered.isNotEmpty && _random.nextDouble() < .72) {
      pool = undiscovered;
    } else {
      pool = regular;
    }
    final candidates = pool.where((g) => !_recent.contains(g.no)).toList();
    if (candidates.isNotEmpty) pool = candidates;
    double weight(GameSpec g) => switch (g.rarity) {
          Rarity.common => 10,
          Rarity.uncommon => 6,
          Rarity.rare => 4,
          Rarity.superRare => 2.2,
          Rarity.secret => 0,
        };
    final total = pool.fold<double>(0, (a, g) => a + weight(g));
    var r = _random.nextDouble() * total;
    for (final g in pool) {
      r -= weight(g);
      if (r <= 0) return _remember(g);
    }
    return _remember(pool.last);
  }

  GameSpec _remember(GameSpec g) {
    _recent.add(g.no);
    if (_recent.length > 8) _recent.removeAt(0);
    return g;
  }

  /// Records a finished play. [discover] is false for replays that must not
  /// count as discovery (they are already discovered anyway).
  Future<PlayReward> recordPlay(GameSpec spec, GameResult result, {bool discover = true}) async {
    final isNew = discover && !_unlockAll && _discoveredIds.add(spec.id);
    final oldLevel = _arcade.level;
    final prevStars = _arcade.stars[spec.id] ?? 0;
    final stars = result.won ? result.stars : 0;
    final coins = 5 + stars * 10 + (isNew ? 50 : 0) + (stars > prevStars ? 10 : 0);
    final xp = 10 + stars * 6 + (isNew ? 30 : 0);
    _arcade = _arcade.copyWith(
      coins: _arcade.coins + coins,
      xp: _arcade.xp + xp,
      stars: {..._arcade.stars, spec.id: max(prevStars, stars)},
      plays: {..._arcade.plays, spec.id: (_arcade.plays[spec.id] ?? 0) + 1},
      wins: _arcade.wins + (result.won ? 1 : 0),
    );
    final secs = result.seconds.round().clamp(0, 120);
    _totalWatchSeconds += secs;
    _todayWatchSeconds += secs;
    _watchCount += 1;
    await _persist();
    notifyListeners();
    return PlayReward(
      isNew: isNew,
      coins: coins,
      xp: xp,
      leveledUp: _arcade.level > oldLevel,
      newLevel: _arcade.level,
      bestStars: max(prevStars, stars),
      improved: stars > prevStars,
    );
  }

  Future<void> recordRush(int stagesCleared, int coinsEarned) async {
    _arcade = _arcade.copyWith(
      rushBest: max(_arcade.rushBest, stagesCleared),
      coins: _arcade.coins + coinsEarned,
      xp: _arcade.xp + stagesCleared * 8,
    );
    await _persist();
    notifyListeners();
  }

  static const capsuleCost = 300;

  /// Spends coins to unlock a random undiscovered regular ad.
  Future<GameSpec?> buyCapsule() async {
    final pool = allGames.where((g) => !g.isSecret && !_discoveredIds.contains(g.id)).toList();
    if (pool.isEmpty || _arcade.coins < capsuleCost) return null;
    final g = pool[_random.nextInt(pool.length)];
    _discoveredIds.add(g.id);
    _arcade = _arcade.copyWith(coins: _arcade.coins - capsuleCost);
    await _persist();
    notifyListeners();
    return g;
  }

  Future<bool> unlockWithReward(String id) async {
    final g = gamesById[id];
    if (g == null || g.isSecret || _discoveredIds.contains(id)) return false;
    _discoveredIds.add(id);
    await _persist();
    notifyListeners();
    return true;
  }

  /// Claims the daily bonus; returns coins granted (0 if already claimed).
  Future<int> claimDaily() async {
    if (!dailyAvailable) return 0;
    final today = _dateKey(DateTime.now());
    final yesterday = _dateKey(DateTime.now().subtract(const Duration(days: 1)));
    final streak = _arcade.dailyDate == yesterday ? _arcade.streak + 1 : 1;
    final amount = 50 + min(streak, 7) * 25;
    _arcade = _arcade.copyWith(coins: _arcade.coins + amount, dailyDate: today, streak: streak);
    await _persist();
    notifyListeners();
    return amount;
  }

  Future<bool> consumeSearchEnergy() async {
    final next = _searchEnergyService.consume(_searchEnergyState);
    if (next == null) return false;
    _searchEnergyState = next;
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> refreshSearchEnergy() async {
    final next = _searchEnergyService.synchronize(_searchEnergyState);
    if (next.remaining == _searchEnergyState.remaining && next.recoveryAnchor == _searchEnergyState.recoveryAnchor) {
      return;
    }
    _searchEnergyState = next;
    await _persist();
    notifyListeners();
  }

  Future<void> refillSearchEnergy() async {
    _searchEnergyState = _searchEnergyService.refill();
    await _persist();
    notifyListeners();
  }

  Future<void> setSoundEffectsEnabled(bool enabled) async {
    if (_soundEffectsEnabled == enabled) return;
    _soundEffectsEnabled = enabled;
    await _persist();
    notifyListeners();
  }

  /// Admin/debug: view everything without saving it as discovered.
  void setUnlockAll(bool enabled) {
    if (!adminToolsEnabled || _unlockAll == enabled) return;
    _unlockAll = enabled;
    notifyListeners();
  }

  // ----------------------------------------------------------- cloud sync ---

  Future<void> _startCloudSync() async {
    _authSession!.addListener(_handleAuthStateChanged);
    if (_authSession.isSignedIn) await _syncFromCloud();
  }

  void _handleAuthStateChanged() {
    if (!_authSession!.isSignedIn) {
      _cloudSynced = false;
      _cloudSyncing = false;
      _cloudSyncError = null;
      notifyListeners();
      return;
    }
    unawaited(_syncFromCloud());
  }

  Future<void> _syncFromCloud() async {
    final uid = _authSession?.uid;
    if (uid == null || _cloudStore == null || _cloudSyncing) return;
    _cloudSyncing = true;
    _cloudSyncError = null;
    notifyListeners();
    try {
      final local = _snapshot();
      final remote = await _cloudStore.load(uid);
      final canMergeLocal = local.cloudAccountUid == null || local.cloudAccountUid == uid;
      final baseLocal = canMergeLocal ? local : const AppSnapshot();
      _applySnapshot(_mergeSnapshots(baseLocal, remote, uid));
      await _store.save(_snapshot());
      final account = _authSession?.account;
      if (account == null) return;
      await _cloudStore.save(uid, _snapshot(), account: account);
      _cloudSynced = true;
    } on Exception catch (error) {
      _cloudSynced = false;
      _cloudSyncError = 'sync_error';
      debugPrint('Cloud progress sync failed: $error');
    } finally {
      _cloudSyncing = false;
      notifyListeners();
    }
  }

  AppSnapshot _mergeSnapshots(AppSnapshot local, AppSnapshot? remote, String uid) {
    if (remote == null) return _withUid(local, uid);
    final sourceUser = remote.user ?? local.user;
    final user = sourceUser == null
        ? null
        : UserProfile(id: uid, nickname: sourceUser.nickname, age: sourceUser.age, createdAt: sourceUser.createdAt);
    final localAnchor = local.searchEnergyRecoveryAnchor;
    final remoteAnchor = remote.searchEnergyRecoveryAnchor;
    final useLocalEnergy = remoteAnchor == null || localAnchor != null && localAnchor.isAfter(remoteAnchor);
    return AppSnapshot(
      cloudAccountUid: uid,
      user: user,
      explorationProfile: local.explorationProfile,
      discoveredIds: {...local.discoveredIds, ...remote.discoveredIds},
      totalWatchSeconds: max(local.totalWatchSeconds, remote.totalWatchSeconds),
      todayWatchSeconds: max(local.todayWatchSeconds, remote.todayWatchSeconds),
      watchCount: max(local.watchCount, remote.watchCount),
      soundEffectsEnabled: remote.soundEffectsEnabled,
      searchEnergy: useLocalEnergy ? local.searchEnergy : remote.searchEnergy,
      searchEnergyRecoveryAnchor: useLocalEnergy ? localAnchor : remoteAnchor,
      statsDate: local.statsDate ?? remote.statsDate,
      arcade: ArcadeState.merge(local.arcade, remote.arcade),
    );
  }

  AppSnapshot _withUid(AppSnapshot s, String uid) => AppSnapshot(
        cloudAccountUid: uid,
        user: s.user == null ? null : UserProfile(id: uid, nickname: s.user!.nickname, age: s.user!.age, createdAt: s.user!.createdAt),
        explorationProfile: s.explorationProfile,
        discoveredIds: s.discoveredIds,
        totalWatchSeconds: s.totalWatchSeconds,
        todayWatchSeconds: s.todayWatchSeconds,
        watchCount: s.watchCount,
        soundEffectsEnabled: s.soundEffectsEnabled,
        searchEnergy: s.searchEnergy,
        searchEnergyRecoveryAnchor: s.searchEnergyRecoveryAnchor,
        statsDate: s.statsDate,
        arcade: s.arcade,
      );

  void _applySnapshot(AppSnapshot snapshot) {
    _cloudAccountUid = snapshot.cloudAccountUid;
    _user = snapshot.user;
    _profile = snapshot.explorationProfile;
    _discoveredIds
      ..clear()
      ..addAll(snapshot.discoveredIds);
    _totalWatchSeconds = snapshot.totalWatchSeconds;
    _todayWatchSeconds = _isToday(snapshot.statsDate) ? snapshot.todayWatchSeconds : 0;
    _watchCount = snapshot.watchCount;
    _soundEffectsEnabled = snapshot.soundEffectsEnabled;
    _arcade = snapshot.arcade;
    if (_arcade.language != null) L10n.code = _arcade.language!;
    _searchEnergyState = _searchEnergyService.synchronize(
      SearchEnergyState(
        remaining: snapshot.searchEnergy,
        recoveryAnchor: snapshot.searchEnergyRecoveryAnchor ?? _searchEnergyService.now(),
      ),
    );
  }

  AppSnapshot _snapshot() => AppSnapshot(
        cloudAccountUid: _cloudAccountUid,
        user: _user,
        explorationProfile: _profile,
        discoveredIds: _discoveredIds,
        totalWatchSeconds: _totalWatchSeconds,
        todayWatchSeconds: _todayWatchSeconds,
        watchCount: _watchCount,
        soundEffectsEnabled: _soundEffectsEnabled,
        searchEnergy: _searchEnergyState.remaining,
        searchEnergyRecoveryAnchor: _searchEnergyState.recoveryAnchor,
        statsDate: _dateKey(DateTime.now()),
        arcade: _arcade,
      );

  Future<void> _persist() async {
    final snapshot = _snapshot();
    await _store.save(snapshot);
    final uid = _authSession?.uid;
    final account = _authSession?.account;
    if (uid == null || account == null || _cloudStore == null || uid != _cloudAccountUid) return;
    try {
      await _cloudStore.save(uid, snapshot, account: account);
      _cloudSynced = true;
      _cloudSyncError = null;
    } on Exception catch (error) {
      _cloudSynced = false;
      _cloudSyncError = 'sync_error';
      debugPrint('Cloud progress save failed: $error');
    }
  }

  @override
  void dispose() {
    _authSession?.removeListener(_handleAuthStateChanged);
    super.dispose();
  }

  static bool _isToday(String? value) => value == _dateKey(DateTime.now());
  static String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';
}
