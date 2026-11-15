import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/drift_player_save_repository.dart';
import '../../domain/repositories/game_settings_repository.dart';
import '../../domain/repositories/player_progress_repository.dart';
import '../../domain/services/offline_dungeon_runner.dart';
import '../../domain/services/offline_progression_service.dart';
import 'game_clock_provider.dart';
import 'game_config_provider.dart';

/// Menyediakan instance [AppDatabase] dan menutup koneksi saat provider di-dispose.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final offlineProgressionServiceProvider = Provider<OfflineProgressionService>((
  ref,
) {
  final damageCalculator = ref.watch(damageCalculatorProvider);
  return OfflineProgressionService(
    runner: OfflineDungeonRunner(damageCalculator: damageCalculator),
  );
});

/// Repository persistensi snapshot progres pemain berbasis Drift/SQLite.
final playerSaveRepositoryProvider = FutureProvider<PlayerSaveRepository>((
  ref,
) async {
  final db = ref.watch(appDatabaseProvider);
  final config = await ref.watch(gameConfigProvider.future);
  final clock = ref.watch(gameClockProvider);
  await db.initialize();
  return DriftPlayerSaveRepository(db: db, config: config, clock: clock);
});

/// Repository pengaturan aplikasi & audio berbasis tabel `GameSettings`.
final gameSettingsRepositoryProvider = FutureProvider<GameSettingsRepository>((
  ref,
) async {
  final db = ref.watch(appDatabaseProvider);
  final config = await ref.watch(gameConfigProvider.future);
  final clock = ref.watch(gameClockProvider);
  await db.initialize();
  return DriftPlayerSaveRepository(db: db, config: config, clock: clock);
});
