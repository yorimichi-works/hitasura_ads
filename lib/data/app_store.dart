import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';

abstract interface class AppStore {
  Future<AppSnapshot> load();
  Future<void> save(AppSnapshot snapshot);
}

class PreferencesAppStore implements AppStore {
  static const _userId = 'user_id';
  static const _nickname = 'nickname';
  static const _age = 'age';
  static const _createdAt = 'created_at';
  static const _ageGroup = 'explore_age_group';
  static const _gender = 'explore_gender';
  static const _region = 'explore_region';
  static const _language = 'explore_language';
  static const _interests = 'explore_interests';
  static const _discovered = 'discovered_ids';
  static const _totalSeconds = 'total_watch_seconds';
  static const _todaySeconds = 'today_watch_seconds';
  static const _watchCount = 'watch_count';
  static const _soundEffectsEnabled = 'sound_effects_enabled';
  static const _searchEnergy = 'search_energy';
  static const _searchEnergyRecoveryAnchor = 'search_energy_recovery_anchor';
  static const _statsDate = 'stats_date';

  @override
  Future<AppSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_userId);
    final createdAt = DateTime.tryParse(prefs.getString(_createdAt) ?? '');
    final user = id == null
        ? null
        : UserProfile(
            id: id,
            nickname: prefs.getString(_nickname) ?? '広告好き',
            age: prefs.getInt(_age) ?? 0,
            createdAt: createdAt ?? DateTime.now(),
          );
    return AppSnapshot(
      user: user,
      explorationProfile: ExplorationProfile(
        ageGroup: prefs.getString(_ageGroup),
        gender: prefs.getString(_gender),
        region: prefs.getString(_region),
        language: prefs.getString(_language),
        interests: (prefs.getStringList(_interests) ?? const <String>[])
            .toSet(),
      ),
      discoveredIds: (prefs.getStringList(_discovered) ?? const <String>[])
          .toSet(),
      totalWatchSeconds: prefs.getInt(_totalSeconds) ?? 0,
      todayWatchSeconds: prefs.getInt(_todaySeconds) ?? 0,
      watchCount: prefs.getInt(_watchCount) ?? 0,
      soundEffectsEnabled: prefs.getBool(_soundEffectsEnabled) ?? true,
      searchEnergy: prefs.getInt(_searchEnergy) ?? 5,
      searchEnergyRecoveryAnchor: DateTime.tryParse(
        prefs.getString(_searchEnergyRecoveryAnchor) ?? '',
      ),
      statsDate: prefs.getString(_statsDate),
    );
  }

  @override
  Future<void> save(AppSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final user = snapshot.user;
    if (user != null) {
      await prefs.setString(_userId, user.id);
      await prefs.setString(_nickname, user.nickname);
      await prefs.setInt(_age, user.age);
      await prefs.setString(_createdAt, user.createdAt.toIso8601String());
    }
    await _setNullable(prefs, _ageGroup, snapshot.explorationProfile.ageGroup);
    await _setNullable(prefs, _gender, snapshot.explorationProfile.gender);
    await _setNullable(prefs, _region, snapshot.explorationProfile.region);
    await _setNullable(prefs, _language, snapshot.explorationProfile.language);
    await prefs.setStringList(
      _interests,
      snapshot.explorationProfile.interests.toList()..sort(),
    );
    await prefs.setStringList(
      _discovered,
      snapshot.discoveredIds.toList()..sort(),
    );
    await prefs.setInt(_totalSeconds, snapshot.totalWatchSeconds);
    await prefs.setInt(_todaySeconds, snapshot.todayWatchSeconds);
    await prefs.setInt(_watchCount, snapshot.watchCount);
    await prefs.setBool(_soundEffectsEnabled, snapshot.soundEffectsEnabled);
    await prefs.setInt(_searchEnergy, snapshot.searchEnergy);
    await prefs.setString(
      _searchEnergyRecoveryAnchor,
      snapshot.searchEnergyRecoveryAnchor!.toIso8601String(),
    );
    await _setNullable(prefs, _statsDate, snapshot.statsDate);
  }

  Future<void> _setNullable(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    if (value == null || value.isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }
}

class MemoryAppStore implements AppStore {
  MemoryAppStore([this.snapshot = const AppSnapshot()]);

  AppSnapshot snapshot;

  @override
  Future<AppSnapshot> load() async => snapshot;

  @override
  Future<void> save(AppSnapshot snapshot) async => this.snapshot = snapshot;
}
