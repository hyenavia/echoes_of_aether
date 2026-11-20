/// Progres milik player: level, EXP, dan gold. Immutable; mudah disimpan
/// ke database pada Milestone 6.
class PlayerProgress {
  const PlayerProgress({
    this.level = 1,
    this.currentExp = 0,
    this.gold = 0,
    this.ascensionPhase = 0,
  });

  final int level;
  final int currentExp;
  final int gold;
  final int ascensionPhase;

  PlayerProgress copyWith({
    int? level,
    int? currentExp,
    int? gold,
    int? ascensionPhase,
  }) {
    return PlayerProgress(
      level: level ?? this.level,
      currentExp: currentExp ?? this.currentExp,
      gold: gold ?? this.gold,
      ascensionPhase: ascensionPhase ?? this.ascensionPhase,
    );
  }
}
