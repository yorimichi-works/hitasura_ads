import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/ad_catalog.dart';
import '../data/app_store.dart';
import '../models/ad_definition.dart';
import '../models/app_models.dart';
import '../services/ad_selection_service.dart';

class AppController extends ChangeNotifier {
  AppController._({
    required this.catalog,
    required this._store,
    required AppSnapshot snapshot,
    required this._selectionService,
  }) : _user = snapshot.user,
       _profile = snapshot.explorationProfile,
       _discoveredIds = {...snapshot.discoveredIds},
       _totalWatchSeconds = snapshot.totalWatchSeconds,
       _todayWatchSeconds = _isToday(snapshot.statsDate)
           ? snapshot.todayWatchSeconds
           : 0,
       _watchCount = snapshot.watchCount;

  static Future<AppController> create({
    AppStore? store,
    AdCatalog? catalog,
    Random? random,
  }) async {
    final actualStore = store ?? PreferencesAppStore();
    return AppController._(
      catalog: catalog ?? await AdCatalog.load(),
      store: actualStore,
      snapshot: await actualStore.load(),
      selectionService: AdSelectionService(random: random),
    );
  }

  final AdCatalog catalog;
  final AppStore _store;
  final AdSelectionService _selectionService;
  UserProfile? _user;
  ExplorationProfile _profile;
  final Set<String> _discoveredIds;
  int _totalWatchSeconds;
  int _todayWatchSeconds;
  int _watchCount;

  UserProfile? get user => _user;
  ExplorationProfile get profile => _profile;
  Set<String> get discoveredIds => Set.unmodifiable(_discoveredIds);
  int get discoveredCount => _discoveredIds.length;
  int get totalWatchSeconds => _totalWatchSeconds;
  int get todayWatchSeconds => _todayWatchSeconds;
  int get watchCount => _watchCount;
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

  Future<void> _persist() => _store.save(
    AppSnapshot(
      user: _user,
      explorationProfile: _profile,
      discoveredIds: _discoveredIds,
      totalWatchSeconds: _totalWatchSeconds,
      todayWatchSeconds: _todayWatchSeconds,
      watchCount: _watchCount,
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
