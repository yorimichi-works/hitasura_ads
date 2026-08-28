import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_models.dart';
import 'google_auth_service.dart';

abstract interface class ProgressCloudStore {
  Future<AppSnapshot?> load(String uid);
  Future<void> save(
    String uid,
    AppSnapshot snapshot, {
    required GoogleAccountInfo account,
  });
}

class FirestoreProgressCloudStore implements ProgressCloudStore {
  FirestoreProgressCloudStore({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _document(String uid) =>
      _firestore.collection('users').doc(uid);

  @override
  Future<AppSnapshot?> load(String uid) async {
    final document = await _document(uid).get();
    final data = document.data();
    return data == null ? null : AppSnapshotCodec.fromMap(data);
  }

  @override
  Future<void> save(
    String uid,
    AppSnapshot snapshot, {
    required GoogleAccountInfo account,
  }) async {
    if (account.uid != uid) {
      throw ArgumentError.value(account.uid, 'account.uid', 'must match uid');
    }
    final reference = _document(uid);
    final data = FirestoreUserDocumentCodec.toMap(snapshot, account)
      ..['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      if (!existing.exists || existing.data()?['createdAt'] == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      transaction.set(reference, data, SetOptions(merge: true));
    });
  }
}

abstract final class FirestoreUserDocumentCodec {
  static Map<String, dynamic> toMap(
    AppSnapshot snapshot,
    GoogleAccountInfo account,
  ) => AppSnapshotCodec.toMap(snapshot)
    ..addAll({
      'uid': account.uid,
      'displayName': account.displayName ?? '',
      'email': account.email,
      'photoUrl': account.photoUrl,
    });
}

abstract final class AppSnapshotCodec {
  static Map<String, dynamic> toMap(AppSnapshot snapshot) => {
    'schemaVersion': 1,
    'cloudAccountUid': snapshot.cloudAccountUid,
    'user': snapshot.user == null
        ? null
        : {
            'nickname': snapshot.user!.nickname,
            'age': snapshot.user!.age,
            'createdAt': snapshot.user!.createdAt.toUtc().toIso8601String(),
          },
    'explorationProfile': {
      'ageGroup': snapshot.explorationProfile.ageGroup,
      'gender': snapshot.explorationProfile.gender,
      'region': snapshot.explorationProfile.region,
      'language': snapshot.explorationProfile.language,
      'interests': snapshot.explorationProfile.interests.toList()..sort(),
    },
    'discoveredIds': snapshot.discoveredIds.toList()..sort(),
    'totalWatchSeconds': snapshot.totalWatchSeconds,
    'todayWatchSeconds': snapshot.todayWatchSeconds,
    'watchCount': snapshot.watchCount,
    'soundEffectsEnabled': snapshot.soundEffectsEnabled,
    'searchEnergy': snapshot.searchEnergy,
    'searchEnergyRecoveryAnchor': snapshot.searchEnergyRecoveryAnchor
        ?.toUtc()
        .toIso8601String(),
    'statsDate': snapshot.statsDate,
  };

  static AppSnapshot fromMap(Map<String, dynamic> data) {
    final userData = _map(data['user']);
    final profileData = _map(data['explorationProfile']);
    final uid = _string(data['cloudAccountUid']);
    return AppSnapshot(
      cloudAccountUid: uid,
      user: userData == null
          ? null
          : UserProfile(
              id: uid ?? 'cloud-user',
              nickname: _string(userData['nickname']) ?? '広告好き',
              age: _integer(userData['age']),
              createdAt:
                  DateTime.tryParse(_string(userData['createdAt']) ?? '') ??
                  DateTime.now(),
            ),
      explorationProfile: ExplorationProfile(
        ageGroup: _string(profileData?['ageGroup']),
        gender: _string(profileData?['gender']),
        region: _string(profileData?['region']),
        language: _string(profileData?['language']),
        interests: _strings(profileData?['interests']).toSet(),
      ),
      discoveredIds: _strings(data['discoveredIds']).toSet(),
      totalWatchSeconds: _integer(data['totalWatchSeconds']),
      todayWatchSeconds: _integer(data['todayWatchSeconds']),
      watchCount: _integer(data['watchCount']),
      soundEffectsEnabled: data['soundEffectsEnabled'] as bool? ?? true,
      searchEnergy: _integer(data['searchEnergy'], fallback: 5),
      searchEnergyRecoveryAnchor: DateTime.tryParse(
        _string(data['searchEnergyRecoveryAnchor']) ?? '',
      ),
      statsDate: _string(data['statsDate']),
    );
  }

  static Map<String, dynamic>? _map(Object? value) => value is Map
      ? value.map((key, value) => MapEntry(key.toString(), value))
      : null;
  static String? _string(Object? value) => value is String ? value : null;
  static int _integer(Object? value, {int fallback = 0}) =>
      value is num ? value.toInt() : fallback;
  static List<String> _strings(Object? value) =>
      value is Iterable ? value.whereType<String>().toList() : const [];
}
