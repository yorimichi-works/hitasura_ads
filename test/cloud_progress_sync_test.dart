import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitasura_ads/data/ad_catalog.dart';
import 'package:hitasura_ads/data/app_store.dart';
import 'package:hitasura_ads/models/app_models.dart';
import 'package:hitasura_ads/services/cloud_progress_service.dart';
import 'package:hitasura_ads/services/google_auth_service.dart';
import 'package:hitasura_ads/state/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AdCatalog catalog;

  setUpAll(() async {
    catalog = await AdCatalog.load();
  });

  test('cloud snapshot codec preserves all progression fields', () {
    final anchor = DateTime.utc(2026, 8, 28, 12);
    final snapshot = AppSnapshot(
      cloudAccountUid: 'uid-1',
      user: UserProfile(
        id: 'uid-1',
        nickname: '広告王',
        age: 28,
        createdAt: anchor,
      ),
      explorationProfile: const ExplorationProfile(
        ageGroup: '25〜34歳',
        gender: '男性',
        region: '日本',
        language: '日本語',
        interests: {'ゲーム', 'IT'},
      ),
      discoveredIds: const {'AD_001', 'AD_040'},
      totalWatchSeconds: 120,
      todayWatchSeconds: 20,
      watchCount: 7,
      soundEffectsEnabled: false,
      searchEnergy: 3,
      searchEnergyRecoveryAnchor: anchor,
      statsDate: '2026-8-28',
    );

    final decoded = AppSnapshotCodec.fromMap(AppSnapshotCodec.toMap(snapshot));
    expect(decoded.cloudAccountUid, 'uid-1');
    expect(decoded.user?.nickname, '広告王');
    expect(decoded.explorationProfile.interests, {'ゲーム', 'IT'});
    expect(decoded.discoveredIds, {'AD_001', 'AD_040'});
    expect(decoded.totalWatchSeconds, 120);
    expect(decoded.searchEnergy, 3);
    expect(decoded.searchEnergyRecoveryAnchor, anchor);
  });

  test('Firestore user document includes authenticated profile fields', () {
    const account = GoogleAccountInfo(
      uid: 'uid-1',
      email: 'user@example.com',
      displayName: 'Google User',
      photoUrl: 'https://example.com/photo.png',
    );
    const snapshot = AppSnapshot(cloudAccountUid: 'uid-1');

    final data = FirestoreUserDocumentCodec.toMap(snapshot, account);

    expect(data['uid'], 'uid-1');
    expect(data['displayName'], 'Google User');
    expect(data['email'], 'user@example.com');
    expect(data['photoUrl'], 'https://example.com/photo.png');
    expect(data['cloudAccountUid'], 'uid-1');
  });

  test('first Google login merges anonymous and cloud discoveries', () async {
    final now = DateTime.now();
    final localStore = MemoryAppStore(
      AppSnapshot(
        user: _user('local', '端末ユーザー', now),
        discoveredIds: const {'AD_001'},
        totalWatchSeconds: 10,
        watchCount: 1,
        searchEnergy: 2,
        searchEnergyRecoveryAnchor: now,
        statsDate: _dateKey(now),
      ),
    );
    final cloud = _MemoryCloudStore({
      'google-1': AppSnapshot(
        cloudAccountUid: 'google-1',
        user: _user('google-1', 'クラウドユーザー', now),
        discoveredIds: const {'AD_002'},
        totalWatchSeconds: 40,
        watchCount: 3,
        searchEnergy: 4,
        searchEnergyRecoveryAnchor: now.subtract(const Duration(minutes: 2)),
        statsDate: _dateKey(now),
      ),
    });
    final auth = _FakeAuthSession('google-1');

    final controller = await AppController.create(
      catalog: catalog,
      store: localStore,
      authSession: auth,
      cloudStore: cloud,
      clock: () => now,
    );

    expect(controller.discoveredIds, {'AD_001', 'AD_002'});
    expect(controller.totalWatchSeconds, 40);
    expect(controller.watchCount, 3);
    expect(controller.searchEnergy, 2);
    expect(controller.cloudSynced, isTrue);
    expect(localStore.snapshot.cloudAccountUid, 'google-1');
    expect(cloud.snapshots['google-1']?.discoveredIds, {'AD_001', 'AD_002'});
    controller.dispose();
    auth.dispose();
  });

  test(
    'switching Google account never inherits another users catalog',
    () async {
      final now = DateTime.now();
      final localStore = MemoryAppStore(
        AppSnapshot(
          cloudAccountUid: 'google-a',
          user: _user('google-a', 'A', now),
          discoveredIds: const {'AD_001'},
          searchEnergyRecoveryAnchor: now,
          statsDate: _dateKey(now),
        ),
      );
      final cloud = _MemoryCloudStore({
        'google-b': AppSnapshot(
          cloudAccountUid: 'google-b',
          user: _user('google-b', 'B', now),
          discoveredIds: const {'AD_002'},
          searchEnergyRecoveryAnchor: now,
          statsDate: _dateKey(now),
        ),
      });
      final auth = _FakeAuthSession('google-b');

      final controller = await AppController.create(
        catalog: catalog,
        store: localStore,
        authSession: auth,
        cloudStore: cloud,
        clock: () => now,
      );

      expect(controller.discoveredIds, {'AD_002'});
      expect(controller.user?.nickname, 'B');
      expect(localStore.snapshot.cloudAccountUid, 'google-b');
      controller.dispose();
      auth.dispose();
    },
  );

  test('new discovery is persisted to the signed-in cloud account', () async {
    final now = DateTime.now();
    final localStore = MemoryAppStore(
      AppSnapshot(
        user: _user('local', '端末', now),
        searchEnergyRecoveryAnchor: now,
        statsDate: _dateKey(now),
      ),
    );
    final cloud = _MemoryCloudStore();
    final auth = _FakeAuthSession('google-1');
    final controller = await AppController.create(
      catalog: catalog,
      store: localStore,
      authSession: auth,
      cloudStore: cloud,
      clock: () => now,
    );

    await controller.completeAd(catalog['AD_040'], 8);

    expect(cloud.snapshots['google-1']?.discoveredIds, contains('AD_040'));
    expect(cloud.snapshots['google-1']?.watchCount, 1);
    expect(cloud.snapshots['google-1']?.totalWatchSeconds, 8);
    controller.dispose();
    auth.dispose();
  });
}

UserProfile _user(String id, String nickname, DateTime now) =>
    UserProfile(id: id, nickname: nickname, age: 28, createdAt: now);

String _dateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

class _FakeAuthSession extends ChangeNotifier implements AuthSession {
  _FakeAuthSession(this._uid);
  String? _uid;

  @override
  bool get isSignedIn => _uid != null;
  @override
  String? get uid => _uid;
  @override
  GoogleAccountInfo? get account => _uid == null
      ? null
      : GoogleAccountInfo(
          uid: _uid!,
          email: '$_uid@example.com',
          displayName: 'Test User',
          photoUrl: null,
        );

  void signIn(String uid) {
    _uid = uid;
    notifyListeners();
  }
}

class _MemoryCloudStore implements ProgressCloudStore {
  _MemoryCloudStore([Map<String, AppSnapshot>? seed]) : snapshots = {...?seed};

  final Map<String, AppSnapshot> snapshots;

  @override
  Future<AppSnapshot?> load(String uid) async => snapshots[uid];

  @override
  Future<void> save(
    String uid,
    AppSnapshot snapshot, {
    required GoogleAccountInfo account,
  }) async {
    expect(account.uid, uid);
    snapshots[uid] = snapshot;
  }
}
