import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/ad_catalog.dart';
import '../data/app_store.dart';
import '../models/ad_definition.dart';
import '../models/app_models.dart';
import '../services/ad_selection_service.dart';
import '../services/cloud_progress_service.dart';
import '../services/google_auth_service.dart';
import '../services/search_energy_service.dart';

class AppController extends ChangeNotifier {
  AppController._({
    required this.catalog,
    required this._store,
    required AppSnapshot snapshot,
    required this._selectionService,
    required SearchEnergyService searchEnergyService,
    required this._authSession,
    required this._cloudStore,
  }) : _user = snapshot.user,
       _cloudAccountUid = snapshot.cloudAccountUid,
       _profile = snapshot.explorationProfile,
       _discoveredIds = {...snapshot.discoveredIds},
       _totalWatchSeconds = snapshot.totalWatchSeconds,
       _todayWatchSeconds = _isToday(snapshot.statsDate)
           ? snapshot.todayWatchSeconds
           : 0,
       _watchCount = snapshot.watchCount,
       _soundEffectsEnabled = snapshot.soundEffectsEnabled,
       _searchEnergyService = searchEnergyService,
       _searchEnergyState = searchEnergyService.synchronize(
         SearchEnergyState(
           remaining: snapshot.searchEnergy,
           recoveryAnchor:
               snapshot.searchEnergyRecoveryAnchor ?? searchEnergyService.now(),
         ),
       );

  static Future<AppController> create({
    AppStore? store,
    AdCatalog? catalog,
    Random? random,
    DateTime Function()? clock,
    AuthSession? authSession,
    ProgressCloudStore? cloudStore,
  }) async {
    final actualStore = store ?? PreferencesAppStore();
    final searchEnergyService = SearchEnergyService(clock: clock);
    final controller = AppController._(
      catalog: catalog ?? await AdCatalog.load(),
      store: actualStore,
      snapshot: await actualStore.load(),
      selectionService: AdSelectionService(random: random),
      searchEnergyService: searchEnergyService,
      authSession: authSession,
      cloudStore: cloudStore,
    );
    await controller._store.save(controller._snapshot());
    if (authSession != null && cloudStore != null) {
      await controller._startCloudSync();
    }
    return controller;
  }

  final AdCatalog catalog;
  final AppStore _store;
  final AdSelectionService _selectionService;
  final SearchEnergyService _searchEnergyService;
  final AuthSession? _authSession;
  final ProgressCloudStore? _cloudStore;
  UserProfile? _user;
  String? _cloudAccountUid;
  ExplorationProfile _profile;
  final Set<String> _discoveredIds;
  int _totalWatchSeconds;
  int _todayWatchSeconds;
  int _watchCount;
  bool _soundEffectsEnabled;
  SearchEnergyState _searchEnergyState;
  bool _debugUnlockAll = false;
  bool _cloudSyncing = false;
  bool _cloudSynced = false;
  String? _cloudSyncError;

  UserProfile? get user => _user;
  ExplorationProfile get profile => _profile;
  Set<String> get discoveredIds => Set.unmodifiable(_discoveredIds);
  bool _adminUnlockAll = false;
  static const _adminToolsCompiled = bool.fromEnvironment('ENABLE_ADMIN_TOOLS');
  bool get adminToolsEnabled => kDebugMode || _adminToolsCompiled;
  Set<String> get visibleDiscoveredIds => (debugUnlockAll || adminUnlockAll)
      ? Set.unmodifiable(catalog.all.map((ad) => ad.id).toSet())
      : discoveredIds;
  int get discoveredCount => (debugUnlockAll || adminUnlockAll)
      ? catalog.all.length
      : _discoveredIds.length;
  bool get debugUnlockAll => kDebugMode && _debugUnlockAll;
  bool get adminUnlockAll => adminToolsEnabled && _adminUnlockAll;
  bool isAdVisibleAsDiscovered(String adId) =>
      debugUnlockAll || _adminUnlockAll || _discoveredIds.contains(adId);
  int get totalWatchSeconds => _totalWatchSeconds;
  int get todayWatchSeconds => _todayWatchSeconds;
  int get watchCount => _watchCount;
  bool get soundEffectsEnabled => _soundEffectsEnabled;
  int get searchEnergy => _searchEnergyState.remaining;
  bool get canSearch => searchEnergy > 0;
  Duration get timeUntilSearchRecovery =>
      _searchEnergyService.untilNextRecovery(_searchEnergyState);
  bool get isRegistered => _user != null;
  bool get isComplete => _discoveredIds.length == catalog.all.length;
  bool get cloudSyncing => _cloudSyncing;
  bool get cloudSynced => _cloudSynced;
  String? get cloudSyncError => _cloudSyncError;

  Future<void> register(String nickname, int age, String gender) async {
    final now = DateTime.now();
    _user = UserProfile(
      id: '${now.microsecondsSinceEpoch}-${Random().nextInt(999999)}',
      nickname: nickname.trim().isEmpty ? '広告大好き' : nickname.trim(),
      age: age,
      createdAt: now,
    );
    _profile = ExplorationProfile(
      ageGroup: ageGroupFor(age),
      gender: gender,
      language: '日本語',
    );
    await _persist();
    notifyListeners();
  }

  Future<void> updateProfile({
    required String nickname,
    required int age,
    required ExplorationProfile explorationProfile,
  }) async {
    _user = _user?.copyWith(nickname: nickname.trim(), age: age);
    _profile = explorationProfile;
    await _persist();
    notifyListeners();
  }

  AdDefinition selectAd() => _selectionService.select(
    catalog.all,
    _discoveredIds,
    age: _user?.age,
    gender: _profile.gender,
  );

  Future<bool> completeAd(
    AdDefinition ad,
    int activeSeconds, {
    bool allowDiscovery = true,
  }) async {
    final isNew = allowDiscovery && _discoveredIds.add(ad.id);
    final safeSeconds = activeSeconds.clamp(0, 120);
    _totalWatchSeconds += safeSeconds;
    _todayWatchSeconds += safeSeconds;
    _watchCount += 1;
    await _persist();
    notifyListeners();
    return isNew;
  }

  Future<bool> unlockAdWithReward(String adId) async {
    final ad = catalog.byId[adId];
    if (ad == null || ad.isSecret || _discoveredIds.contains(ad.id)) {
      return false;
    }
    _discoveredIds.add(ad.id);
    await _persist();
    notifyListeners();
    return true;
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
    if (next.remaining == _searchEnergyState.remaining &&
        next.recoveryAnchor == _searchEnergyState.recoveryAnchor) {
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

  Future<void> setSearchEnergyForDebug(int remaining) async {
    if (!kDebugMode) return;
    _searchEnergyState = SearchEnergyState(
      remaining: remaining.clamp(0, SearchEnergyService.maxEnergy),
      recoveryAnchor: _searchEnergyService.now(),
    );
    await _persist();
    notifyListeners();
  }

  Future<void> setSoundEffectsEnabled(bool enabled) async {
    if (_soundEffectsEnabled == enabled) return;
    _soundEffectsEnabled = enabled;
    await _persist();
    notifyListeners();
  }

  Future<void> resetDiscoveryForDebug(String adId) async {
    if (!kDebugMode || !_discoveredIds.remove(adId)) return;
    await _persist();
    notifyListeners();
  }

  void setDebugUnlockAll(bool enabled) {
    if (!kDebugMode) return;
    if (_debugUnlockAll == enabled) return;
    _debugUnlockAll = enabled;
    notifyListeners();
  }

  /// Temporary admin-facing "show everything" toggle, usable in production
  /// builds too. View-only: never persisted, never counts as real discovery.
  void setAdminUnlockAll(bool enabled) {
    if (!adminToolsEnabled) return;
    if (_adminUnlockAll == enabled) return;
    _adminUnlockAll = enabled;
    notifyListeners();
  }

  Future<void> clearAllDiscoveryForDebug() async {
    if (!kDebugMode) return;
    _discoveredIds.clear();
    await _persist();
    notifyListeners();
  }

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
      final canMergeLocal =
          local.cloudAccountUid == null || local.cloudAccountUid == uid;
      final baseLocal = canMergeLocal ? local : const AppSnapshot();
      final merged = _mergeSnapshots(baseLocal, remote, uid);
      _applySnapshot(merged);
      await _store.save(_snapshot());
      final account = _authSession?.account;
      if (account == null) return;
      await _cloudStore.save(uid, _snapshot(), account: account);
      _cloudSynced = true;
    } on Exception catch (error) {
      _cloudSynced = false;
      _cloudSyncError = '進行状況をクラウドと同期できませんでした。';
      debugPrint('Cloud progress sync failed: $error');
    } finally {
      _cloudSyncing = false;
      notifyListeners();
    }
  }

  AppSnapshot _mergeSnapshots(
    AppSnapshot local,
    AppSnapshot? remote,
    String uid,
  ) {
    if (remote == null) return _copySnapshot(local, cloudAccountUid: uid);
    final discovered = {...local.discoveredIds, ...remote.discoveredIds};
    final sourceUser = remote.user ?? local.user;
    final user = sourceUser == null
        ? null
        : UserProfile(
            id: uid,
            nickname: sourceUser.nickname,
            age: sourceUser.age,
            createdAt: sourceUser.createdAt,
          );
    final profile = _hasProfile(remote.explorationProfile)
        ? remote.explorationProfile
        : local.explorationProfile;
    final sameStatsDate = local.statsDate == remote.statsDate;
    final useLocalStats = _isLaterDate(local.statsDate, remote.statsDate);
    final localAnchor = local.searchEnergyRecoveryAnchor;
    final remoteAnchor = remote.searchEnergyRecoveryAnchor;
    final useLocalEnergy =
        remoteAnchor == null ||
        localAnchor != null && localAnchor.isAfter(remoteAnchor);
    return AppSnapshot(
      cloudAccountUid: uid,
      user: user,
      explorationProfile: profile,
      discoveredIds: discovered,
      totalWatchSeconds: max(local.totalWatchSeconds, remote.totalWatchSeconds),
      todayWatchSeconds: sameStatsDate
          ? max(local.todayWatchSeconds, remote.todayWatchSeconds)
          : useLocalStats
          ? local.todayWatchSeconds
          : remote.todayWatchSeconds,
      watchCount: max(local.watchCount, remote.watchCount),
      soundEffectsEnabled: remote.soundEffectsEnabled,
      searchEnergy: useLocalEnergy ? local.searchEnergy : remote.searchEnergy,
      searchEnergyRecoveryAnchor: useLocalEnergy ? localAnchor : remoteAnchor,
      statsDate: useLocalStats
          ? local.statsDate
          : remote.statsDate ?? local.statsDate,
    );
  }

  bool _hasProfile(ExplorationProfile profile) =>
      profile.ageGroup != null ||
      profile.gender != null ||
      profile.region != null ||
      profile.language != null ||
      profile.interests.isNotEmpty;

  bool _isLaterDate(String? left, String? right) {
    if (left == null) return false;
    if (right == null) return true;
    final leftParts = left.split('-').map(int.tryParse).toList();
    final rightParts = right.split('-').map(int.tryParse).toList();
    if (leftParts.length != 3 ||
        rightParts.length != 3 ||
        leftParts.contains(null) ||
        rightParts.contains(null)) {
      return false;
    }
    final leftDate = DateTime(leftParts[0]!, leftParts[1]!, leftParts[2]!);
    final rightDate = DateTime(rightParts[0]!, rightParts[1]!, rightParts[2]!);
    return leftDate.isAfter(rightDate);
  }

  AppSnapshot _copySnapshot(
    AppSnapshot snapshot, {
    required String cloudAccountUid,
  }) => AppSnapshot(
    cloudAccountUid: cloudAccountUid,
    user: snapshot.user == null
        ? null
        : UserProfile(
            id: cloudAccountUid,
            nickname: snapshot.user!.nickname,
            age: snapshot.user!.age,
            createdAt: snapshot.user!.createdAt,
          ),
    explorationProfile: snapshot.explorationProfile,
    discoveredIds: snapshot.discoveredIds,
    totalWatchSeconds: snapshot.totalWatchSeconds,
    todayWatchSeconds: snapshot.todayWatchSeconds,
    watchCount: snapshot.watchCount,
    soundEffectsEnabled: snapshot.soundEffectsEnabled,
    searchEnergy: snapshot.searchEnergy,
    searchEnergyRecoveryAnchor: snapshot.searchEnergyRecoveryAnchor,
    statsDate: snapshot.statsDate,
  );

  void _applySnapshot(AppSnapshot snapshot) {
    _cloudAccountUid = snapshot.cloudAccountUid;
    _user = snapshot.user;
    _profile = snapshot.explorationProfile;
    _discoveredIds
      ..clear()
      ..addAll(snapshot.discoveredIds);
    _totalWatchSeconds = snapshot.totalWatchSeconds;
    _todayWatchSeconds = _isToday(snapshot.statsDate)
        ? snapshot.todayWatchSeconds
        : 0;
    _watchCount = snapshot.watchCount;
    _soundEffectsEnabled = snapshot.soundEffectsEnabled;
    _searchEnergyState = _searchEnergyService.synchronize(
      SearchEnergyState(
        remaining: snapshot.searchEnergy,
        recoveryAnchor:
            snapshot.searchEnergyRecoveryAnchor ?? _searchEnergyService.now(),
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
  );

  Future<void> _persist() async {
    final snapshot = _snapshot();
    await _store.save(snapshot);
    final uid = _authSession?.uid;
    final account = _authSession?.account;
    if (uid == null ||
        account == null ||
        _cloudStore == null ||
        uid != _cloudAccountUid) {
      return;
    }
    try {
      await _cloudStore.save(uid, snapshot, account: account);
      _cloudSynced = true;
      _cloudSyncError = null;
    } on Exception catch (error) {
      _cloudSynced = false;
      _cloudSyncError = '進行状況をクラウドへ保存できませんでした。';
      debugPrint('Cloud progress save failed: $error');
    }
  }

  @override
  void dispose() {
    _authSession?.removeListener(_handleAuthStateChanged);
    super.dispose();
  }

  static bool _isToday(String? value) => value == _dateKey(DateTime.now());
  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';
}

String ageGroupFor(int age) {
  if (age < 18) return '18歳未満';
  if (age < 25) return '18〜24歳';
  if (age < 35) return '25〜34歳';
  if (age < 45) return '35〜44歳';
  if (age < 55) return '45〜54歳';
  if (age < 65) return '55〜64歳';
  return '65歳以上';
}
