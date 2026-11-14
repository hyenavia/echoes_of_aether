import 'dart:math' as math;

import '../entities/offline_activity.dart';
import '../entities/player_save_snapshot.dart';

/// Hasil validasi jendela waktu offline oleh [OfflineTimeCalculator].
enum OfflineTimeValidationStatus {
  valid,
  firstLaunch,
  zeroElapsed,
  invalidClock,
  alreadyClaimed,
  budgetExhausted,
}

/// Snapshot perhitungan durasi offline deterministik beserta batas 8 jam
/// dan anchor timestamp yang aman dari klaim ulang.
class OfflineTimeWindow {
  const OfflineTimeWindow({
    required this.status,
    required this.anchorTimestampMs,
    required this.nowMs,
    required this.rawElapsed,
    required this.effectiveElapsed,
    required this.cappedAtMaxDuration,
    required this.previouslyProcessedMs,
    required this.remainingBudgetMs,
    required this.endTimestampMs,
    required this.eventId,
    required this.newLastOfflineClaimAtMs,
  });

  final OfflineTimeValidationStatus status;
  final int anchorTimestampMs;
  final int nowMs;
  final Duration rawElapsed;
  final Duration effectiveElapsed;
  final bool cappedAtMaxDuration;
  final int previouslyProcessedMs;
  final int remainingBudgetMs;
  final int endTimestampMs;
  final String eventId;
  final int newLastOfflineClaimAtMs;

  bool get isValid => status == OfflineTimeValidationStatus.valid;
}

/// Kalkulator waktu offline yang independen dari Flutter/Flame.
///
/// Menegakkan:
/// - Batas maksimal kumulatif 8 jam (`maxOfflineDuration`).
/// - Ambang minimal simulasi (`minElapsedDuration`) tanpa memajukan cursor
///   `lastOfflineClaimAtMs` bila selisih belum cukup (`zeroElapsed`).
/// - Penolakan durasi negatif / timestamp korup (`invalidClock`).
/// - Pencegahan klaim ulang interval yang sama via `lastOfflineClaimAtMs`,
///   `processedOfflineDurationMs`, dan `claimedEventIds`.
class OfflineTimeCalculator {
  const OfflineTimeCalculator({
    this.maxOfflineDuration = defaultMaxOfflineDuration,
    this.minElapsedDuration = defaultMinElapsedDuration,
  });

  static const Duration defaultMaxOfflineDuration = Duration(hours: 8);
  static const Duration defaultMinElapsedDuration = Duration(seconds: 1);
  static const int simulationTickDurationMs = 50;

  final Duration maxOfflineDuration;
  final Duration minElapsedDuration;

  OfflineTimeWindow calculate({
    required GameSessionSnapshot session,
    required int nowMs,
    OfflineActivitySnapshot activity = const OfflineActivitySnapshot.paused(),
    Set<String>? claimedEventIds,
  }) {
    final safeClaimAtMs = math.max(0, session.lastOfflineClaimAtMs);

    if (nowMs < 0) {
      return OfflineTimeWindow(
        status: OfflineTimeValidationStatus.invalidClock,
        anchorTimestampMs: math.max(0, session.lastSavedAtMs),
        nowMs: nowMs,
        rawElapsed: Duration.zero,
        effectiveElapsed: Duration.zero,
        cappedAtMaxDuration: false,
        previouslyProcessedMs: math.max(0, activity.processedOfflineDurationMs),
        remainingBudgetMs: maxOfflineDuration.inMilliseconds,
        endTimestampMs: math.max(0, session.lastSavedAtMs),
        eventId: '',
        newLastOfflineClaimAtMs: safeClaimAtMs,
      );
    }

    if (session.lastSavedAtMs < 0 ||
        session.lastOfflineClaimAtMs < 0 ||
        activity.lastCheckpointAtMs < 0 ||
        activity.processedOfflineDurationMs < 0) {
      return OfflineTimeWindow(
        status: OfflineTimeValidationStatus.invalidClock,
        anchorTimestampMs: math.max(0, session.lastSavedAtMs),
        nowMs: nowMs,
        rawElapsed: Duration.zero,
        effectiveElapsed: Duration.zero,
        cappedAtMaxDuration: false,
        previouslyProcessedMs: math.max(0, activity.processedOfflineDurationMs),
        remainingBudgetMs: maxOfflineDuration.inMilliseconds,
        endTimestampMs: math.max(0, session.lastSavedAtMs),
        eventId: '',
        newLastOfflineClaimAtMs: safeClaimAtMs,
      );
    }

    if (session.lastSavedAtMs == 0) {
      return OfflineTimeWindow(
        status: OfflineTimeValidationStatus.firstLaunch,
        anchorTimestampMs: 0,
        nowMs: nowMs,
        rawElapsed: Duration.zero,
        effectiveElapsed: Duration.zero,
        cappedAtMaxDuration: false,
        previouslyProcessedMs: 0,
        remainingBudgetMs: maxOfflineDuration.inMilliseconds,
        endTimestampMs: nowMs,
        eventId: '',
        newLastOfflineClaimAtMs: nowMs,
      );
    }

    final isResumingInterrupted =
        activity.state == OfflineActivityState.interrupted ||
        (activity.state == OfflineActivityState.pending &&
            activity.lastCheckpointAtMs > session.lastSavedAtMs);
    final anchorMs = isResumingInterrupted && activity.lastCheckpointAtMs > 0
        ? activity.lastCheckpointAtMs
        : session.lastSavedAtMs;

    // Rollback jam: waktu saat ini mundur di belakang titik checkpoint/simpan.
    if (nowMs < anchorMs || nowMs < session.lastSavedAtMs) {
      final rawNegative = nowMs - anchorMs;
      return OfflineTimeWindow(
        status: OfflineTimeValidationStatus.invalidClock,
        anchorTimestampMs: anchorMs,
        nowMs: nowMs,
        rawElapsed: Duration(milliseconds: rawNegative),
        effectiveElapsed: Duration.zero,
        cappedAtMaxDuration: false,
        previouslyProcessedMs: isResumingInterrupted
            ? activity.processedOfflineDurationMs
            : 0,
        remainingBudgetMs: maxOfflineDuration.inMilliseconds,
        endTimestampMs: anchorMs,
        eventId: '',
        newLastOfflineClaimAtMs: safeClaimAtMs,
      );
    }

    final rawMs = nowMs - anchorMs;
    final maxMs = maxOfflineDuration.inMilliseconds;
    final previouslyProcessedMs = isResumingInterrupted
        ? math.min(maxMs, activity.processedOfflineDurationMs)
        : 0;
    final remainingBudgetMs = math.max(0, maxMs - previouslyProcessedMs);

    if (rawMs == 0) {
      if (isResumingInterrupted) {
        return OfflineTimeWindow(
          status: OfflineTimeValidationStatus.budgetExhausted,
          anchorTimestampMs: anchorMs,
          nowMs: nowMs,
          rawElapsed: Duration.zero,
          effectiveElapsed: Duration.zero,
          cappedAtMaxDuration: remainingBudgetMs <= 0,
          previouslyProcessedMs: previouslyProcessedMs,
          remainingBudgetMs: remainingBudgetMs,
          endTimestampMs: anchorMs,
          eventId: '',
          newLastOfflineClaimAtMs: safeClaimAtMs,
        );
      }
      return OfflineTimeWindow(
        status: OfflineTimeValidationStatus.zeroElapsed,
        anchorTimestampMs: anchorMs,
        nowMs: nowMs,
        rawElapsed: Duration.zero,
        effectiveElapsed: Duration.zero,
        cappedAtMaxDuration: false,
        previouslyProcessedMs: 0,
        remainingBudgetMs: maxOfflineDuration.inMilliseconds,
        endTimestampMs: anchorMs,
        eventId: '',
        newLastOfflineClaimAtMs: safeClaimAtMs,
      );
    }

    // Jika rentang hingga `nowMs` sudah berada pada/di belakang cursor klaim
    // tanpa sedang melanjutkan batch interrupted setelah cursor tersebut.
    if (!isResumingInterrupted && session.lastOfflineClaimAtMs >= nowMs) {
      return OfflineTimeWindow(
        status: OfflineTimeValidationStatus.alreadyClaimed,
        anchorTimestampMs: anchorMs,
        nowMs: nowMs,
        rawElapsed: Duration(milliseconds: rawMs),
        effectiveElapsed: Duration.zero,
        cappedAtMaxDuration: false,
        previouslyProcessedMs: 0,
        remainingBudgetMs: maxOfflineDuration.inMilliseconds,
        endTimestampMs: anchorMs,
        eventId: '',
        newLastOfflineClaimAtMs: safeClaimAtMs,
      );
    }

    if (remainingBudgetMs <= 0) {
      return OfflineTimeWindow(
        status: OfflineTimeValidationStatus.budgetExhausted,
        anchorTimestampMs: anchorMs,
        nowMs: nowMs,
        rawElapsed: Duration(milliseconds: rawMs),
        effectiveElapsed: Duration.zero,
        cappedAtMaxDuration: true,
        previouslyProcessedMs: previouslyProcessedMs,
        remainingBudgetMs: 0,
        endTimestampMs: anchorMs,
        eventId: '',
        newLastOfflineClaimAtMs: safeClaimAtMs,
      );
    }

    final capped = rawMs > remainingBudgetMs;
    final effectiveMs = math.min(rawMs, remainingBudgetMs);

    // Fix Stage 1 zeroElapsed bug: bila selisih di bawah ambang minimum,
    // JANGAN memajukan `newLastOfflineClaimAtMs` ke `nowMs`.
    // Untuk batch `interrupted` lanjutan, sisa waktu >= 1 tick (50 ms) tetap
    // dijalankan; jika < 1 tick maka window dianggap tuntas (`budgetExhausted`).
    if (isResumingInterrupted) {
      if (effectiveMs < simulationTickDurationMs) {
        return OfflineTimeWindow(
          status: OfflineTimeValidationStatus.budgetExhausted,
          anchorTimestampMs: anchorMs,
          nowMs: nowMs,
          rawElapsed: Duration(milliseconds: rawMs),
          effectiveElapsed: Duration.zero,
          cappedAtMaxDuration: capped,
          previouslyProcessedMs: previouslyProcessedMs,
          remainingBudgetMs: remainingBudgetMs,
          endTimestampMs: anchorMs,
          eventId: '',
          newLastOfflineClaimAtMs: safeClaimAtMs,
        );
      }
    } else if (effectiveMs < minElapsedDuration.inMilliseconds) {
      return OfflineTimeWindow(
        status: OfflineTimeValidationStatus.zeroElapsed,
        anchorTimestampMs: anchorMs,
        nowMs: nowMs,
        rawElapsed: Duration(milliseconds: rawMs),
        effectiveElapsed: Duration.zero,
        cappedAtMaxDuration: capped,
        previouslyProcessedMs: previouslyProcessedMs,
        remainingBudgetMs: remainingBudgetMs,
        endTimestampMs: anchorMs,
        eventId: '',
        newLastOfflineClaimAtMs: safeClaimAtMs,
      );
    }

    final endMs = anchorMs + effectiveMs;
    final eventId = 'offline:$anchorMs:$endMs';

    if (claimedEventIds != null && claimedEventIds.contains(eventId)) {
      return OfflineTimeWindow(
        status: OfflineTimeValidationStatus.alreadyClaimed,
        anchorTimestampMs: anchorMs,
        nowMs: nowMs,
        rawElapsed: Duration(milliseconds: rawMs),
        effectiveElapsed: Duration.zero,
        cappedAtMaxDuration: capped,
        previouslyProcessedMs: previouslyProcessedMs,
        remainingBudgetMs: remainingBudgetMs,
        endTimestampMs: anchorMs,
        eventId: eventId,
        newLastOfflineClaimAtMs: safeClaimAtMs,
      );
    }

    return OfflineTimeWindow(
      status: OfflineTimeValidationStatus.valid,
      anchorTimestampMs: anchorMs,
      nowMs: nowMs,
      rawElapsed: Duration(milliseconds: rawMs),
      effectiveElapsed: Duration(milliseconds: effectiveMs),
      cappedAtMaxDuration: capped,
      previouslyProcessedMs: previouslyProcessedMs,
      remainingBudgetMs: remainingBudgetMs,
      endTimestampMs: endMs,
      eventId: eventId,
      newLastOfflineClaimAtMs: nowMs,
    );
  }
}
