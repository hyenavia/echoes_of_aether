/// Abstraksi sumber waktu yang dapat disuntikkan agar logika game
/// deterministik dan mudah diuji tanpa memanggil `DateTime.now()` langsung.
abstract interface class GameClock {
  int get nowMs;
}

/// Implementasi default [GameClock] berbasis waktu sistem perangkat.
class SystemGameClock implements GameClock {
  const SystemGameClock();

  @override
  int get nowMs => DateTime.now().millisecondsSinceEpoch;
}
