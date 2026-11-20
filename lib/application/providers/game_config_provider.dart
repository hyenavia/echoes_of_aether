import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/game_config_repository.dart';
import '../../domain/entities/game_config.dart';
import '../../domain/entities/hero_ascension.dart';
import '../../domain/repositories/game_config_repository.dart';
import '../../domain/services/damage_calculator.dart';
import '../../domain/services/difficulty_service.dart';
import '../../domain/services/dungeon_progression_service.dart';
import '../../domain/services/equipment_factory.dart';
import '../../domain/services/gacha_service.dart';
import '../../domain/services/hero_ascension_service.dart';
import '../../domain/services/infinite_spire_service.dart';
import '../../domain/services/weapon_resonance_service.dart';
import 'game_clock_provider.dart';

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

/// Provider terpusat [GachaService] dari konfigurasi gacha dan period service.
final gachaServiceProvider = Provider<GachaService?>((ref) {
  final config = ref.watch(gameConfigProvider).asData?.value;
  if (config == null || config.gacha == null) return null;
  final periodService = ref.watch(periodServiceProvider);
  return GachaService(
    gachaConfig: config.gacha!,
    items: config.items,
    specializations: config.specializations.definitions,
    equipmentFactory: EquipmentFactory(config.equipment),
    periodService: periodService,
  );
});

/// Provider terpusat [WeaponResonanceService].
final weaponResonanceServiceProvider = Provider<WeaponResonanceService>((ref) {
  return const WeaponResonanceService();
});

/// Provider terpusat [HeroAscensionService] untuk validasi dan terobosan level karakter.
final heroAscensionServiceProvider = Provider<HeroAscensionService>((ref) {
  final config = ref.watch(gameConfigProvider).asData?.value;
  if (config != null) {
    return HeroAscensionService(config.heroAscension);
  }
  return const HeroAscensionService(HeroAscensionConfig());
});

/// Provider terpusat [InfiniteSpireService] untuk manajemen The Infinite Spire.
final infiniteSpireServiceProvider = Provider<InfiniteSpireService?>((ref) {
  final config = ref.watch(gameConfigProvider).asData?.value;
  if (config != null && config.infiniteSpire != null) {
    return InfiniteSpireService(config.infiniteSpire!);
  }
  return null;
});
