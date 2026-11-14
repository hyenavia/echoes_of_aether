/// Konstanta global game. Nilai yang berkaitan dengan balancing RPG
/// TIDAK ditaruh di sini, melainkan di JSON config (aturan #4 GDD).
class GameConstants {
  GameConstants._();

  /// Ukuran satu tile dalam piksel dunia.
  static const double tileSize = 16;

  /// Ukuran dungeon uji coba dalam jumlah tile.
  static const int testRoomColumns = 20;
  static const int testRoomRows = 11;

  /// Resolusi virtual kamera (pixel-art, di-scale ke layar).
  static const double viewWidth = testRoomColumns * tileSize; // 320
  static const double viewHeight = testRoomRows * tileSize; // 176

  /// Simulasi combat berjalan 20 tick/detik (GDD 12.7). Dipakai mulai Milestone 3.
  static const Duration simulationStep = Duration(milliseconds: 50);
}
