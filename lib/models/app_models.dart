class UserProfile {
  const UserProfile({
    required this.id,
    required this.nickname,
    required this.age,
    required this.createdAt,
  });

  final String id;
  final String nickname;
  final int age;
  final DateTime createdAt;

  UserProfile copyWith({String? nickname, int? age}) => UserProfile(
    id: id,
    nickname: nickname ?? this.nickname,
    age: age ?? this.age,
    createdAt: createdAt,
  );
}

class ExplorationProfile {
  const ExplorationProfile({
    this.ageGroup,
    this.gender,
    this.region,
    this.language,
    this.interests = const <String>{},
  });

  final String? ageGroup;
  final String? gender;
  final String? region;
  final String? language;
  final Set<String> interests;
}

class AdWatchLog {
  const AdWatchLog({
    required this.adId,
    required this.startedAt,
    required this.endedAt,
    required this.seconds,
  });

  final String adId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int seconds;
}

class AppSnapshot {
  const AppSnapshot({
    this.user,
    this.explorationProfile = const ExplorationProfile(),
    this.discoveredIds = const <String>{},
    this.totalWatchSeconds = 0,
    this.todayWatchSeconds = 0,
    this.watchCount = 0,
    this.statsDate,
  });

  final UserProfile? user;
  final ExplorationProfile explorationProfile;
  final Set<String> discoveredIds;
  final int totalWatchSeconds;
  final int todayWatchSeconds;
  final int watchCount;
  final String? statsDate;
}
