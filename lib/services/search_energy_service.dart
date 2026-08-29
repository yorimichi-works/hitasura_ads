class SearchEnergyState {
  const SearchEnergyState({
    required this.remaining,
    required this.recoveryAnchor,
  });

  final int remaining;
  final DateTime recoveryAnchor;
}

class SearchEnergyService {
  SearchEnergyService({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const maxEnergy = 5;
  static const recoveryInterval = Duration(minutes: 3);

  final DateTime Function() _clock;

  DateTime now() => _clock();

  SearchEnergyState synchronize(SearchEnergyState state) {
    final now = _clock();
    final remaining = state.remaining.clamp(0, maxEnergy);
    if (remaining >= maxEnergy || state.recoveryAnchor.isAfter(now)) {
      return SearchEnergyState(remaining: remaining, recoveryAnchor: now);
    }

    final elapsed = now.difference(state.recoveryAnchor);
    final recovered = elapsed.inMilliseconds ~/ recoveryInterval.inMilliseconds;
    if (recovered <= 0) {
      return SearchEnergyState(
        remaining: remaining,
        recoveryAnchor: state.recoveryAnchor,
      );
    }

    final nextRemaining = (remaining + recovered).clamp(0, maxEnergy);
    final nextAnchor = nextRemaining >= maxEnergy
        ? now
        : state.recoveryAnchor.add(recoveryInterval * recovered);
    return SearchEnergyState(
      remaining: nextRemaining,
      recoveryAnchor: nextAnchor,
    );
  }

  SearchEnergyState? consume(SearchEnergyState state) {
    final current = synchronize(state);
    if (current.remaining == 0) return null;
    return SearchEnergyState(
      remaining: current.remaining - 1,
      recoveryAnchor: current.remaining == maxEnergy
          ? _clock()
          : current.recoveryAnchor,
    );
  }

  SearchEnergyState refill() =>
      SearchEnergyState(remaining: maxEnergy, recoveryAnchor: _clock());

  Duration untilNextRecovery(SearchEnergyState state) {
    final current = synchronize(state);
    if (current.remaining >= maxEnergy) return Duration.zero;
    final remaining =
        recoveryInterval - _clock().difference(current.recoveryAnchor);
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
