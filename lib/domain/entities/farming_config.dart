/// Konfigurasi perilaku farming dan deteksi death-loop dari `game_config.json`.
class FarmingConfig {
  const FarmingConfig({this.deathLoopSuggestAfter = 3});

  final int deathLoopSuggestAfter;
}
