import '../entities/game_settings.dart';

/// Kontrak repository untuk pengaturan audio dan preferensi aplikasi lokal.
abstract interface class GameSettingsRepository {
  Future<GameSettingsData> loadSettings();

  Future<void> saveSettings(GameSettingsData settings);
}
