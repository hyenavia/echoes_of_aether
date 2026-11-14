import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('M6 Stage 1 — OfflineActivitySnapshot State Machine', () {
    test('default mode adalah Pause Progression pada state inactive dan tidak berjalan otomatis', () {
      const paused = OfflineActivitySnapshot.paused();
      expect(paused.mode, OfflineActivityMode.pauseProgression);
      expect(paused.state, OfflineActivityState.inactive);
      expect(paused.isPaused, isTrue);
      expect(paused.isRunnableOnResume, isFalse);

      expect(
        () => paused.transitionTo(OfflineActivityState.configured),
        throwsStateError,
      );
      expect(
        () => paused.transitionTo(
          OfflineActivityState.pending,
          mode: OfflineActivityMode.pauseProgression,
        ),
        throwsStateError,
      );
    });

    test('Mode A (Continue Dungeon) mewajibkan activeRunId dan mempertahankan runId hingga selesai tanpa replay', () {
      const initial = OfflineActivitySnapshot.paused();
      expect(
        () => initial.transitionTo(
          OfflineActivityState.configured,
          mode: OfflineActivityMode.continueDungeon,
          selectedDungeonId: 'forgotten_forest',
        ),
        throwsStateError,
      );

      final configured = initial.transitionTo(
        OfflineActivityState.configured,
        mode: OfflineActivityMode.continueDungeon,
        selectedDungeonId: 'forgotten_forest',
        activeRunId: 'run_abc',
        lastCheckpointAtMs: 1000,
        simulationSeed: 42,
      );
      expect(configured.isRunnableOnResume, isTrue);

      final pending = configured.transitionTo(OfflineActivityState.pending);
      final processing = pending.transitionTo(OfflineActivityState.processing);
      expect(processing.activeRunId, 'run_abc');

      const summary = OfflineSummarySnapshot(
        eventId: 'offline:1000:5000',
        mode: OfflineActivityMode.continueDungeon,
        finalState: OfflineActivityState.completed,
        effectiveElapsedMs: 4000,
        runsAttempted: 1,
        runsCompleted: 1,
        roomsCleared: 3,
        expGained: 120,
        goldGained: 45,
      );
      final completed = processing.transitionTo(
        OfflineActivityState.completed,
        lastCheckpointAtMs: 5000,
        processedOfflineDurationMs: 4000,
        pendingSummary: summary,
      );
      expect(completed.isRunnableOnResume, isFalse);

      // Completed tidak boleh langsung dijalankan ulang ke pending/processing/configured.
      expect(
        () => completed.transitionTo(OfflineActivityState.pending),
        throwsStateError,
      );
      expect(
        () => completed.transitionTo(OfflineActivityState.processing),
        throwsStateError,
      );

      // Hanya boleh kembali ke inactive setelah summary ditutup / reset.
      final acknowledged = summary.markAcknowledged();
      expect(acknowledged.acknowledged, isTrue);
      final reset = completed.transitionTo(
        OfflineActivityState.inactive,
        mode: OfflineActivityMode.pauseProgression,
        clearSelectedDungeonId: true,
        clearActiveRunId: true,
        pendingSummary: acknowledged,
      );
      expect(reset.state, OfflineActivityState.inactive);
      expect(reset.mode, OfflineActivityMode.pauseProgression);
      expect(reset.activeRunId, isNull);
    });

    test('Mode B (Auto Farming) mewajibkan selectedDungeonId, mendukung interrupted resume, dan terminal failed tidak replayable', () {
      const initial = OfflineActivitySnapshot.paused();
      expect(
        () => initial.transitionTo(
          OfflineActivityState.configured,
          mode: OfflineActivityMode.autoFarming,
        ),
        throwsStateError,
      );

      final configured = initial.transitionTo(
        OfflineActivityState.configured,
        mode: OfflineActivityMode.autoFarming,
        selectedDungeonId: 'forgotten_forest',
      );
      final pending = configured.transitionTo(OfflineActivityState.pending);
      final processing = pending.transitionTo(OfflineActivityState.processing);

      // Interrupted di tengah pemrosesan boleh dilanjutkan kembali.
      final interrupted = processing.transitionTo(
        OfflineActivityState.interrupted,
        lastCheckpointAtMs: 10000,
        processedOfflineDurationMs: 60000,
      );
      expect(interrupted.isRunnableOnResume, isTrue);
      final resumed = interrupted
          .transitionTo(OfflineActivityState.pending)
          .transitionTo(OfflineActivityState.processing);

      final failed = resumed.transitionTo(
        OfflineActivityState.failed,
        pendingSummary: const OfflineSummarySnapshot(
          eventId: 'offline:10000:90000',
          mode: OfflineActivityMode.autoFarming,
          finalState: OfflineActivityState.failed,
          effectiveElapsedMs: 80000,
          runsAttempted: 2,
          runsCompleted: 1,
          runsFailed: 1,
          failureReason: 'Player defeated while revive on cooldown',
        ),
      );
      expect(failed.isRunnableOnResume, isFalse);
      expect(
        () => failed.transitionTo(OfflineActivityState.configured),
        throwsStateError,
      );
    });

    test('PlayerSaveSnapshot.hasClearedDungeon memeriksa clearsCount per dungeonId secara akurat', () {
      const snapshot = PlayerSaveSnapshot(
        character: PlayerCharacterSnapshot(progress: PlayerProgress()),
        inventory: InventorySnapshot(),
        dungeon: DungeonProgressSnapshot(
          currentDungeonId: 'forgotten_forest',
          clearsCount: 1,
        ),
        dungeonProgresses: {
          'forgotten_forest': DungeonProgressSnapshot(
            currentDungeonId: 'forgotten_forest',
            clearsCount: 1,
          ),
          'shadow_cavern': DungeonProgressSnapshot(
            currentDungeonId: 'shadow_cavern',
            clearsCount: 0,
          ),
        },
      );

      expect(snapshot.hasClearedDungeon('forgotten_forest'), isTrue);
      expect(snapshot.hasClearedDungeon('shadow_cavern'), isFalse);
      expect(snapshot.hasClearedDungeon('unknown_dungeon'), isFalse);
    });

    test('Stage 3 helpers: withAutoFarming, withContinueDungeon, withPauseProgression, dan acknowledgePendingSummary menjaga validitas transisi', () {
      const initial = OfflineActivitySnapshot.paused();

      final farm = initial.withAutoFarming(
        dungeonId: 'forgotten_forest',
        checkpointAtMs: 5000,
        simulationSeed: 99,
      );
      expect(farm.mode, OfflineActivityMode.autoFarming);
      expect(farm.state, OfflineActivityState.configured);
      expect(farm.selectedDungeonId, 'forgotten_forest');
      expect(farm.activeRunId, isNull);
      expect(farm.lastCheckpointAtMs, 5000);

      final paused = farm.withPauseProgression();
      expect(paused.isPaused, isTrue);
      expect(paused.state, OfflineActivityState.inactive);
      expect(paused.selectedDungeonId, isNull);

      final cont = paused.withContinueDungeon(
        dungeonId: 'forgotten_forest',
        activeRunId: 'run_42',
        checkpointAtMs: 8000,
      );
      expect(cont.mode, OfflineActivityMode.continueDungeon);
      expect(cont.state, OfflineActivityState.configured);
      expect(cont.activeRunId, 'run_42');

      final completed = cont
          .transitionTo(OfflineActivityState.pending)
          .transitionTo(OfflineActivityState.processing)
          .transitionTo(
            OfflineActivityState.completed,
            pendingSummary: const OfflineSummarySnapshot(
              eventId: 'offline:8000:18000',
              mode: OfflineActivityMode.continueDungeon,
              finalState: OfflineActivityState.completed,
              effectiveElapsedMs: 10000,
              expGained: 80,
              goldGained: 25,
            ),
          );
      expect(completed.pendingSummary?.acknowledged, isFalse);

      final acked = completed.acknowledgePendingSummary();
      expect(acked.isPaused, isTrue);
      expect(acked.state, OfflineActivityState.inactive);
      expect(acked.activeRunId, isNull);
      expect(acked.selectedDungeonId, isNull);
      expect(acked.pendingSummary?.acknowledged, isTrue);
    });

    test('Stage 3 helpers: withAutoFarming, withContinueDungeon, withPauseProgression, dan acknowledgePendingSummary menjaga validitas transisi', () {
      const initial = OfflineActivitySnapshot.paused();

      final farm = initial.withAutoFarming(
        dungeonId: 'forgotten_forest',
        checkpointAtMs: 5000,
        simulationSeed: 99,
      );
      expect(farm.mode, OfflineActivityMode.autoFarming);
      expect(farm.state, OfflineActivityState.configured);
      expect(farm.selectedDungeonId, 'forgotten_forest');
      expect(farm.activeRunId, isNull);
      expect(farm.lastCheckpointAtMs, 5000);

      final paused = farm.withPauseProgression();
      expect(paused.isPaused, isTrue);
      expect(paused.state, OfflineActivityState.inactive);
      expect(paused.selectedDungeonId, isNull);

      final cont = paused.withContinueDungeon(
        dungeonId: 'forgotten_forest',
        activeRunId: 'run_42',
        checkpointAtMs: 8000,
      );
      expect(cont.mode, OfflineActivityMode.continueDungeon);
      expect(cont.state, OfflineActivityState.configured);
      expect(cont.activeRunId, 'run_42');

      final completed = cont
          .transitionTo(OfflineActivityState.pending)
          .transitionTo(OfflineActivityState.processing)
          .transitionTo(
            OfflineActivityState.completed,
            pendingSummary: const OfflineSummarySnapshot(
              eventId: 'offline:8000:18000',
              mode: OfflineActivityMode.continueDungeon,
              finalState: OfflineActivityState.completed,
              effectiveElapsedMs: 10000,
              expGained: 80,
              goldGained: 25,
            ),
          );
      expect(completed.pendingSummary?.acknowledged, isFalse);

      final acked = completed.acknowledgePendingSummary();
      expect(acked.isPaused, isTrue);
      expect(acked.state, OfflineActivityState.inactive);
      expect(acked.activeRunId, isNull);
      expect(acked.selectedDungeonId, isNull);
      expect(acked.pendingSummary?.acknowledged, isTrue);
    });
  });
}
