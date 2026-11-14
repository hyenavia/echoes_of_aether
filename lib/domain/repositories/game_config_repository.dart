import '../entities/enemy_definition.dart';
import '../entities/game_config.dart';

/// Kontrak repository untuk memuat konfigurasi statis game.
abstract interface class GameConfigRepository {
  Future<Map<String, EnemyDefinition>> loadMonsters();

  Future<GameConfig> loadGameConfig();
}
