/// Progres milik player: level, EXP, dan gold. Immutable; mudah disimpan
/// ke database pada Milestone 6.
class PlayerProgress {
  const PlayerProgress({this.level = 1, this.currentExp = 0, this.gold = 0});

  final int level;
  final int currentExp;
  final int gold;
}
