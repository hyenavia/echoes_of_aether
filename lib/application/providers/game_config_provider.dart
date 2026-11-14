import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/game_config_repository.dart';
import '../../domain/entities/game_config.dart';
import '../../domain/repositories/game_config_repository.dart';
import '../../domain/services/damage_calculator.dart';
import '../../domain/services/difficulty_service.dart';
import '../../domain/services/dungeon_progression_service.dart';

final gameConfigRepositoryProvider = Provider<GameConfigRepository>(
  (ref) => AssetGameConfigRepository(),
);

/// Konfigurasi game yang sudah divalidasi. Layar dungeon menunggu provider
/// ini selesai sebelum membuat game.
final gameConfigProvider = FutureProvider<GameConfig>((ref) {
  return ref.watch(gameConfigRepositoryProvider).loadGameConfig();
});

/// Provider tunggal pembuatan [DamageCalculator] terpusat dari [GameConfig].
final damageCalculatorProvider = Provider<DamageCalculator>((ref) {
  final config = ref.watch(gameConfigProvider).asData?.value;
  if (config != null) {
    return config.damage.createCalculator();
  }
  return const DamageCalculator();
});

/// Provider terpusat [DifficultyService] dari konfigurasi kesulitan.
final difficultyServiceProvider = Provider<DifficultyService>((ref) {
  final config = ref.watch(gameConfigProvider).asData?.value;
  if (config != null) {
    return DifficultyService(config.difficulty);
  }
  return const DifficultyService();
});

/// Provider terpusat [DungeonProgressionService] dari konfigurasi kesulitan.
final dungeonProgressionServiceProvider = Provider<DungeonProgressionService>((
  ref,
) {
  final config = ref.watch(gameConfigProvider).asData?.value;
  if (config != null) {
    return DungeonProgressionService(config.difficulty);
  }
  return const DungeonProgressionService();
});
