import 'dart:math' as math;

import '../entities/clock_state.dart';
import '../entities/time_config.dart';

/// Pengaman jam monotonik (`max(candidateNow, lastSeen)`):
/// - Saat online dengan selisih waktu server melebihi [serverTimeToleranceMs],
///   kandidat waktu memakai `rawNowMs + serverOffsetMs` (waktu server).
/// - Saat offline atau selisih masih dalam toleransi, kandidat tetap
///   memakai `rawNowMs` (jam perangkat) dengan proteksi jam mundur.
/// - Jam yang mundur tidak menurunkan `lastSeenAtMs`, tidak memicu reset, dan
///   menandai `wentBack = true`.
/// - Lonjakan maju di atas `forwardJumpRecordThresholdMs` dicatat jumlah dan
///   nilai terbesarnya tanpa mengubah perilaku game.
class ClockGuard {
  const ClockGuard({this.timeConfig = const TimeConfig()});

  final TimeConfig timeConfig;

  static const int defaultServerTimeToleranceMs = 5 * 60 * 1000;

  static bool shouldUseServerTime({
    required int? serverOffsetMs,
    required bool isOnline,
    int serverTimeToleranceMs = defaultServerTimeToleranceMs,
  }) =>
      isOnline &&
      serverOffsetMs != null &&
      serverOffsetMs.abs() > serverTimeToleranceMs;

  static int candidateNowMs({
    required int rawNowMs,
    int? serverOffsetMs,
    bool isOnline = false,
    int serverTimeToleranceMs = defaultServerTimeToleranceMs,
  }) {
    if (!shouldUseServerTime(
      serverOffsetMs: serverOffsetMs,
      isOnline: isOnline,
      serverTimeToleranceMs: serverTimeToleranceMs,
    )) {
      return rawNowMs;
    }
    return math.max(0, rawNowMs + serverOffsetMs!);
  }

  ClockReading resolve({
    required ClockState current,
    required int rawNowMs,
    int? serverOffsetMs,
    bool isOnline = false,
    int serverTimeToleranceMs = defaultServerTimeToleranceMs,
  }) {
    final safeLastSeen = math.max(0, current.lastSeenAtMs);
    final candidateNow = candidateNowMs(
      rawNowMs: rawNowMs,
      serverOffsetMs: serverOffsetMs,
      isOnline: isOnline,
      serverTimeToleranceMs: serverTimeToleranceMs,
    );
    if (candidateNow < 0 || candidateNow < safeLastSeen) {
      return ClockReading(
        effectiveMs: safeLastSeen,
        wentBack: true,
        forwardJumpMs: 0,
        state: current.lastSeenAtMs == safeLastSeen
            ? current
            : current.copyWith(lastSeenAtMs: safeLastSeen),
      );
    }

    var jumpMs = 0;
    var jumpCount = math.max(0, current.forwardJumpCount);
    var maxJumpMs = math.max(0, current.maxForwardJumpMs);
    final thresholdMs = timeConfig.forwardJumpRecordThresholdMs;

    if (safeLastSeen > 0) {
      final delta = candidateNow - safeLastSeen;
      if (delta > thresholdMs) {
        jumpMs = delta;
        jumpCount += 1;
        maxJumpMs = math.max(maxJumpMs, delta);
      }
    }

    return ClockReading(
      effectiveMs: candidateNow,
      wentBack: false,
      forwardJumpMs: jumpMs,
      state: ClockState(
        lastSeenAtMs: candidateNow,
        forwardJumpCount: jumpCount,
        maxForwardJumpMs: maxJumpMs,
      ),
    );
  }
}
