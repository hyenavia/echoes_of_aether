/// Status player dalam sebuah dungeon run.
enum PlayerStatus {
  /// Bertarung normal.
  alive,

  /// HP nol; combat berhenti sementara menunggu revive otomatis.
  downed,

  /// Kalah saat revive cooldown; dungeon run berakhir.
  runEnded,
}
