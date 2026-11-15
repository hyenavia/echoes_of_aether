import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
import 'package:echoes_of_aether/data/database/app_database.dart'
    hide ClockState;
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/clock_state.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/entities/time_config.dart';
import 'package:echoes_of_aether/domain/services/clock_guard.dart';
import 'package:echoes_of_aether/domain/services/game_clock.dart';
import 'package:echoes_of_aether/domain/services/offline_progression_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _MutableClock implements GameClock {
  _MutableClock(this._nowMs);
  int _nowMs;
  @override
  int get nowMs => _nowMs;
  set nowMs(int value) => _nowMs = value;
}

GameConfig _testConfig() => const GameConfig(
  monsters: {},
  revive: ReviveConfig(),
  progression: ProgressionConfig(
    baseStats: CombatStats(maxHp: 100, atk: 12, def: 2),
    perLevel: LevelGrowth(hp: 15, atk: 2, def: 0.5),
  ),
  items: {},
  lootTables: {},
  time: TimeConfig(forwardJumpRecordThresholdHours: 48),
);

void main() {
  group('ClockGuard', () {
    test(
      'jam mundur tidak mengubah waktu efektif atau menurunkan lastSeenAtMs',
      () {
        const guard = ClockGuard(
          timeConfig: TimeConfig(forwardJumpRecordThresholdHours: 48),
        );
        const initial = ClockState(lastSeenAtMs: 10_000_000);

        final backward = guard.resolve(current: initial, rawNowMs: 9_000_000);
        expect(backward.wentBack, isTrue);
        expect(backward.effectiveMs, 10_000_000);
        expect(backward.forwardJumpMs, 0);
        expect(backward.state.lastSeenAtMs, 10_000_000);
        expect(backward.state.forwardJumpCount, 0);

        final negative = guard.resolve(current: initial, rawNowMs: -500);
        expect(negative.wentBack, isTrue);
        expect(negative.effectiveMs, 10_000_000);
        expect(negative.state.lastSeenAtMs, 10_000_000);
      },
    );

    test(
      'lonjakan maju melebihi ambang dicatat jumlah dan nilai terbesarnya',
      () {
        const guard = ClockGuard(
          timeConfig: TimeConfig(forwardJumpRecordThresholdHours: 48),
        );
        const t0 = 1_700_000_000_000;
        const initial = ClockState(lastSeenAtMs: t0);

        // Lompat +10 jam (di bawah 48 jam) -> tidak dicatat
        final normalStep = guard.resolve(
          current: initial,
          rawNowMs: t0 + const Duration(hours: 10).inMilliseconds,
        );
        expect(normalStep.wentBack, isFalse);
        expect(normalStep.forwardJumpMs, 0);
        expect(normalStep.state.forwardJumpCount, 0);

        // Lompat +60 jam (di atas 48 jam) -> dicatat
        final jump1 = const Duration(hours: 60).inMilliseconds;
        final r1 = guard.resolve(
          current: normalStep.state,
          rawNowMs: normalStep.effectiveMs + jump1,
        );
        expect(r1.wentBack, isFalse);
        expect(r1.forwardJumpMs, jump1);
        expect(r1.state.forwardJumpCount, 1);
        expect(r1.state.maxForwardJumpMs, jump1);

        // Lompat lagi +50 jam (di atas 48 jam, lebih kecil dari 60 jam)
        final jump2 = const Duration(hours: 50).inMilliseconds;
        final r2 = guard.resolve(
          current: r1.state,
          rawNowMs: r1.effectiveMs + jump2,
        );
        expect(r2.state.forwardJumpCount, 2);
        expect(r2.state.maxForwardJumpMs, jump1);
      },
    );

    test(
      'persistensi, restore ClockStates, dan keselarasan invalidClock offline',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final config = _testConfig();
        const t0 = 1_700_000_000_000;
        final clock = _MutableClock(t0);
        final repo = DriftPlayerSaveRepository(
          db: db,
          config: config,
          clock: clock,
        );

        // Baris belum ada -> default ClockState()
        expect(await repo.loadClockState(), const ClockState());

        await repo.saveSnapshot(
          PlayerSaveSnapshot(
            character: const PlayerCharacterSnapshot(
              progress: PlayerProgress(level: 5),
            ),
            inventory: const InventorySnapshot(),
            session: const GameSessionSnapshot(
              lastActiveAtMs: t0,
              lastSavedAtMs: t0,
              lastOfflineClaimAtMs: t0,
            ),
            clockState: const ClockState(lastSeenAtMs: t0),
          ),
        );

        // Lompat maju 72 jam -> tercatat di ClockStates saat load
        final jumpMs = const Duration(hours: 72).inMilliseconds;
        clock.nowMs = t0 + jumpMs;
        final coordinator = GameSessionCoordinator(
          repository: repo,
          config: config,
          clock: clock,
        );
        final afterJump = await coordinator.loadAndProcessOffline();
        expect(afterJump.clockState.lastSeenAtMs, t0 + jumpMs);
        expect(afterJump.clockState.forwardJumpCount, 1);
        expect(afterJump.clockState.maxForwardJumpMs, jumpMs);

        final persistedClock = await repo.loadClockState();
        expect(persistedClock, afterJump.clockState);

        // Jam dimundurkan -> invalidClock offline tetap terdeteksi, ClockState tidak turun
        clock.nowMs = t0 + const Duration(hours: 10).inMilliseconds;
        await repo.saveSnapshot(
          PlayerSaveSnapshot(
            character: const PlayerCharacterSnapshot(
              progress: PlayerProgress(level: 5),
            ),
            inventory: const InventorySnapshot(),
            session: GameSessionSnapshot(
              lastActiveAtMs: t0 + jumpMs,
              lastSavedAtMs: t0 + jumpMs,
              lastOfflineClaimAtMs: t0 + jumpMs,
            ),
            offlineActivity: OfflineActivitySnapshot.paused().withAutoFarming(
              dungeonId: 'forgotten_forest',
              checkpointAtMs: t0 + jumpMs,
            ),
            clockState: persistedClock,
          ),
        );

        final coordinator2 = GameSessionCoordinator(
          repository: repo,
          config: config,
          clock: clock,
        );
        final afterBack = await coordinator2.loadAndProcessOffline();
        expect(
          afterBack.offlineResult.status,
          OfflineProgressionStatus.invalidClock,
        );
        expect(afterBack.clockState.lastSeenAtMs, t0 + jumpMs);
        expect(afterBack.clockState.forwardJumpCount, 1);
      },
    );
  });
}
