import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/ad_catalog.dart';
import '../data/app_store.dart';
import '../models/ad_definition.dart';
import '../models/app_models.dart';
import '../services/ad_selection_service.dart';
import '../services/search_energy_service.dart';

class AppController extends ChangeNotifier {
  AppController._({
    required this.catalog,
    required this._store,
    required AppSnapshot snapshot,
    required this._selectionService,
    required SearchEnergyService searchEnergyService,
  }) : _user = snapshot.user,
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
  }) async {
    final actualStore = store ?? PreferencesAppStore();
    final searchEnergyService = SearchEnergyService(clock: clock);
    final controller = AppController._(
      catalog: catalog ?? await AdCatalog.load(),
      store: actualStore,
      snapshot: await actualStore.load(),
      selectionService: AdSelectionService(random: random),
      searchEnergyService: searchEnergyService,
    );
    await controller._persist();
    return controller;
  }

  final AdCatalog catalog;
  final AppStore _store;
  final AdSelectionService _selectionService;
  final SearchEnergyService _searchEnergyService;
  UserProfile? _user;
  ExplorationProfile _profile;
  final Set<String> _discoveredIds;
  int _totalWatchSeconds;
  int _todayWatchSeconds;
  int _watchCount;
  bool _soundEffectsEnabled;
  SearchEnergyState _searchEnergyState;

  UserProfile? get user => _user;
  ExplorationProfile get profile => _profile;
  Set<String> get discoveredIds => Set.unmodifiable(_discoveredIds);
  int get discoveredCount => _discoveredIds.length;
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

  Future<void> register(String nickname, int age) async {
    final now = DateTime.now();
    _user = UserProfile(
      id: '${now.microsecondsSinceEpoch}-${Random().nextInt(999999)}',
      nickname: nickname.trim(),
      age: age,
      createdAt: now,
    );
    _profile = ExplorationProfile(ageGroup: ageGroupFor(age), language: '日本語');
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

  AdDefinition selectAd() =>
      _selectionService.select(catalog.all, _discoveredIds);

  Future<bool> completeAd(AdDefinition ad, int activeSeconds) async {
    final isNew = _discoveredIds.add(ad.id);
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

  Future<void> _persist() => _store.save(
    AppSnapshot(
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
    ),
  );

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
