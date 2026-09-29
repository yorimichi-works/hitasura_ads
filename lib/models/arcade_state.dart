import 'dart:convert';
import 'dart:math' as math;

/// Arcade progress that lives next to the original discovery data:
/// coins, XP, per-game best stars / play counts, rush record, language,
/// daily bonus streak.
class ArcadeState {
  const ArcadeState({
    this.coins = 0,
    this.xp = 0,
    this.stars = const {},
    this.plays = const {},
    this.wins = 0,
    this.rushBest = 0,
    this.language,
    this.dailyDate,
    this.streak = 0,
  });

  final int coins;
  final int xp;
  final Map<String, int> stars; // best stars per game id
  final Map<String, int> plays; // play count per game id
  final int wins;
  final int rushBest;
  final String? language;
  final String? dailyDate; // yyyy-m-d of last claimed daily bonus
  final int streak;

  int get totalPlays => plays.values.fold(0, (a, b) => a + b);
  int get totalStars => stars.values.fold(0, (a, b) => a + b);

  /// Level curve: each level needs a bit more XP.
  static int levelFor(int xp) => 1 + (math.sqrt(xp / 40)).floor();
  static int xpForLevel(int level) => (level - 1) * (level - 1) * 40;
  int get level => levelFor(xp);
  double get levelProgress {
    final a = xpForLevel(level), b = xpForLevel(level + 1);
    return ((xp - a) / (b - a)).clamp(0.0, 1.0);
  }

  ArcadeState copyWith({
    int? coins,
    int? xp,
    Map<String, int>? stars,
    Map<String, int>? plays,
    int? wins,
    int? rushBest,
    String? language,
    String? dailyDate,
    int? streak,
  }) =>
      ArcadeState(
        coins: coins ?? this.coins,
        xp: xp ?? this.xp,
        stars: stars ?? this.stars,
        plays: plays ?? this.plays,
        wins: wins ?? this.wins,
        rushBest: rushBest ?? this.rushBest,
        language: language ?? this.language,
        dailyDate: dailyDate ?? this.dailyDate,
        streak: streak ?? this.streak,
      );

  Map<String, dynamic> toJson() => {
        'coins': coins,
        'xp': xp,
        'stars': stars,
        'plays': plays,
        'wins': wins,
        'rushBest': rushBest,
        'language': language,
        'dailyDate': dailyDate,
        'streak': streak,
      };

  static ArcadeState fromJson(Object? raw) {
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        return const ArcadeState();
      }
    }
    if (raw is! Map) return const ArcadeState();
    Map<String, int> ints(Object? v) =>
        v is Map ? {for (final e in v.entries) e.key.toString(): (e.value is num ? (e.value as num).toInt() : 0)} : {};
    int i(Object? v) => v is num ? v.toInt() : 0;
    return ArcadeState(
      coins: i(raw['coins']),
      xp: i(raw['xp']),
      stars: ints(raw['stars']),
      plays: ints(raw['plays']),
      wins: i(raw['wins']),
      rushBest: i(raw['rushBest']),
      language: raw['language'] is String ? raw['language'] as String : null,
      dailyDate: raw['dailyDate'] is String ? raw['dailyDate'] as String : null,
      streak: i(raw['streak']),
    );
  }

  String encode() => jsonEncode(toJson());

  /// Merges two devices' progress without losing anything.
  static ArcadeState merge(ArcadeState a, ArcadeState b) {
    Map<String, int> maxMap(Map<String, int> x, Map<String, int> y) {
      final out = {...x};
      y.forEach((k, v) => out[k] = math.max(out[k] ?? 0, v));
      return out;
    }

    return ArcadeState(
      coins: math.max(a.coins, b.coins),
      xp: math.max(a.xp, b.xp),
      stars: maxMap(a.stars, b.stars),
      plays: maxMap(a.plays, b.plays),
      wins: math.max(a.wins, b.wins),
      rushBest: math.max(a.rushBest, b.rushBest),
      language: a.language ?? b.language,
      dailyDate: a.dailyDate ?? b.dailyDate,
      streak: math.max(a.streak, b.streak),
    );
  }
}
