import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/services/offline_time_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calculator = OfflineTimeCalculator();
  final maxMs = OfflineTimeCalculator.defaultMaxOfflineDuration.inMilliseconds;

  group('OfflineTimeCalculator', () {
    test('firstLaunch (lastSavedAtMs == 0) tidak menghasilkan elapsed & memajukan cursor', () {
      final window = calculator.calculate(
        session: const GameSessionSnapshot(lastSavedAtMs: 0),
        nowMs: 500000,
      );

      expect(window.status, OfflineTimeValidationStatus.firstLaunch);
      expect(window.isValid, isFalse);
      expect(window.effectiveElapsed, Duration.zero);
      expect(window.newLastOfflineClaimAtMs, 500000);
      expect(window.eventId, isEmpty);
    });

    test('zeroElapsed (0ms dan < 1s) mengembalikan zeroElapsed TANPA memajukan cursor', () {
      final exactZero = calculator.calculate(
        session: const GameSessionSnapshot(
          lastSavedAtMs: 100000,
          lastOfflineClaimAtMs: 90000,
        ),
        nowMs: 100000,
      );
      expect(exactZero.status, OfflineTimeValidationStatus.zeroElapsed);
      expect(exactZero.newLastOfflineClaimAtMs, 90000);

      // Fix Stage 1 bug: selisih 500 ms (< minElapsed 1s) tidak boleh memajukan
      // lastOfflineClaimAtMs sehingga waktu tidak hilang diam-diam.
      final subSecond = calculator.calculate(
        session: const GameSessionSnapshot(
          lastSavedAtMs: 100000,
          lastOfflineClaimAtMs: 90000,
        ),
        nowMs: 100500,
      );
      expect(subSecond.status, OfflineTimeValidationStatus.zeroElapsed);
      expect(subSecond.effectiveElapsed, Duration.zero);
      expect(subSecond.newLastOfflineClaimAtMs, 90000);
      expect(subSecond.eventId, isEmpty);
    });

    test('menolak durasi negatif / clock rollback dan timestamp korup', () {
      final rollback = calculator.calculate(
        session: const GameSessionSnapshot(
          lastSavedAtMs: 500000,
          lastOfflineClaimAtMs: 450000,
        ),
        nowMs: 400000,
      );
      expect(rollback.status, OfflineTimeValidationStatus.invalidClock);
      expect(rollback.rawElapsed.isNegative, isTrue);
      expect(rollback.newLastOfflineClaimAtMs, 450000);

      final negativeNow = calculator.calculate(
        session: const GameSessionSnapshot(lastSavedAtMs: 100000),
        nowMs: -5,
      );
      expect(negativeNow.status, OfflineTimeValidationStatus.invalidClock);

      final corruptSaved = calculator.calculate(
        session: const GameSessionSnapshot(lastSavedAtMs: -100),
        nowMs: 100000,
      );
      expect(corruptSaved.status, OfflineTimeValidationStatus.invalidClock);

      final corruptActivity = calculator.calculate(
        session: const GameSessionSnapshot(lastSavedAtMs: 100000),
        nowMs: 200000,
        activity: const OfflineActivitySnapshot(
          mode: OfflineActivityMode.autoFarming,
          state: OfflineActivityState.interrupted,
          selectedDungeonId: 'forgotten_forest',
          processedOfflineDurationMs: -1,
        ),
      );
      expect(corruptActivity.status, OfflineTimeValidationStatus.invalidClock);
    });

    test(
      'durasi normal (30 detik, 1 jam, tepat 4 jam) valid dan tidak di-cap',
      () {
        const startMs = 1000000;

        for (final dur in const [
          Duration(seconds: 30),
          Duration(hours: 1),
          Duration(hours: 4),
        ]) {
          final nowMs = startMs + dur.inMilliseconds;
          final window = calculator.calculate(
            session: const GameSessionSnapshot(
              lastSavedAtMs: startMs,
              lastOfflineClaimAtMs: startMs,
            ),
            nowMs: nowMs,
          );
          expect(window.status, OfflineTimeValidationStatus.valid);
          expect(window.isValid, isTrue);
          expect(window.effectiveElapsed, dur);
          expect(window.cappedAtMaxDuration, isFalse);
          expect(window.eventId, 'offline:$startMs:$nowMs');
          expect(window.newLastOfflineClaimAtMs, nowMs);
        }
      },
    );

    test('durasi melebihi 4 jam (24 jam) dibatasi tepat 4 jam', () {
      const startMs = 1000000;
      final nowMs = startMs + const Duration(hours: 24).inMilliseconds;
      final window = calculator.calculate(
        session: const GameSessionSnapshot(lastSavedAtMs: startMs),
        nowMs: nowMs,
      );

      expect(window.status, OfflineTimeValidationStatus.valid);
      expect(window.cappedAtMaxDuration, isTrue);
      expect(window.effectiveElapsed, const Duration(hours: 4));
      expect(window.endTimestampMs, startMs + maxMs);
      expect(window.eventId, 'offline:$startMs:${startMs + maxMs}');
      expect(window.newLastOfflineClaimAtMs, nowMs);
    });

    test(
      'mencegah klaim ulang melalui lastOfflineClaimAtMs dan claimedEventIds',
      () {
        const startMs = 1000000;
        final endMs = startMs + const Duration(minutes: 10).inMilliseconds;

        final dupByCursor = calculator.calculate(
          session: GameSessionSnapshot(
            lastSavedAtMs: startMs,
            lastOfflineClaimAtMs: endMs,
          ),
          nowMs: endMs,
        );
        expect(dupByCursor.status, OfflineTimeValidationStatus.alreadyClaimed);

        final dupByEvent = calculator.calculate(
          session: const GameSessionSnapshot(lastSavedAtMs: startMs),
          nowMs: endMs,
          claimedEventIds: {'offline:$startMs:$endMs'},
        );
        expect(dupByEvent.status, OfflineTimeValidationStatus.alreadyClaimed);
        expect(dupByEvent.effectiveElapsed, Duration.zero);
      },
    );

    test('melanjutkan activity interrupted menghormati anchor checkpoint & sisa budget 4 jam', () {
      const savedMs = 1000000;
      final processedMs = const Duration(hours: 2).inMilliseconds;
      final checkpointMs = savedMs + processedMs;
      final resumeNowMs = savedMs + const Duration(hours: 10).inMilliseconds;

      final remainingWindow = calculator.calculate(
        session: GameSessionSnapshot(
          lastSavedAtMs: checkpointMs,
          lastOfflineClaimAtMs: checkpointMs,
        ),
        nowMs: resumeNowMs,
        activity: OfflineActivitySnapshot(
          mode: OfflineActivityMode.autoFarming,
          state: OfflineActivityState.interrupted,
          selectedDungeonId: 'forgotten_forest',
          lastCheckpointAtMs: checkpointMs,
          processedOfflineDurationMs: processedMs,
        ),
      );
      expect(remainingWindow.status, OfflineTimeValidationStatus.valid);
      expect(remainingWindow.anchorTimestampMs, checkpointMs);
      expect(remainingWindow.previouslyProcessedMs, processedMs);
      expect(
        remainingWindow.remainingBudgetMs,
        const Duration(hours: 2).inMilliseconds,
      );
      expect(remainingWindow.effectiveElapsed, const Duration(hours: 2));
      expect(remainingWindow.cappedAtMaxDuration, isTrue);

      // Bila sisa waktu batch interrupted masih >= 50ms walau < 1s -> tetap valid
      final shortTail = calculator.calculate(
        session: GameSessionSnapshot(
          lastSavedAtMs: checkpointMs,
          lastOfflineClaimAtMs: checkpointMs,
        ),
        nowMs: checkpointMs + 250,
        activity: OfflineActivitySnapshot(
          mode: OfflineActivityMode.autoFarming,
          state: OfflineActivityState.interrupted,
          selectedDungeonId: 'forgotten_forest',
          lastCheckpointAtMs: checkpointMs,
          processedOfflineDurationMs: processedMs,
        ),
      );
      expect(shortTail.status, OfflineTimeValidationStatus.valid);
      expect(shortTail.effectiveElapsed, const Duration(milliseconds: 250));

      // Bila sisa waktu < 1 tick (20 ms) -> budgetExhausted
      final subTickTail = calculator.calculate(
        session: GameSessionSnapshot(
          lastSavedAtMs: checkpointMs,
          lastOfflineClaimAtMs: checkpointMs,
        ),
        nowMs: checkpointMs + 20,
        activity: OfflineActivitySnapshot(
          mode: OfflineActivityMode.autoFarming,
          state: OfflineActivityState.interrupted,
          selectedDungeonId: 'forgotten_forest',
          lastCheckpointAtMs: checkpointMs,
          processedOfflineDurationMs: processedMs,
        ),
      );
      expect(subTickTail.status, OfflineTimeValidationStatus.budgetExhausted);

      // Bila budget 8 jam sudah habis -> budgetExhausted
      final exhausted = calculator.calculate(
        session: GameSessionSnapshot(
          lastSavedAtMs: savedMs + maxMs,
          lastOfflineClaimAtMs: savedMs + maxMs,
        ),
        nowMs: resumeNowMs,
        activity: OfflineActivitySnapshot(
          mode: OfflineActivityMode.autoFarming,
          state: OfflineActivityState.interrupted,
          selectedDungeonId: 'forgotten_forest',
          lastCheckpointAtMs: savedMs + maxMs,
          processedOfflineDurationMs: maxMs,
        ),
      );
      expect(exhausted.status, OfflineTimeValidationStatus.budgetExhausted);
    });
  });
}
