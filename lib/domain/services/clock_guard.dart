import 'dart:math' as math;

import '../entities/clock_state.dart';
import '../entities/time_config.dart';

/// Pengaman jam monotonik (`max(raw, lastSeen)`):
/// - Jam yang mundur tidak menurunkan `lastSeenAtMs`, tidak memicu reset, dan
///   menandai `wentBack = true`.
/// - Lonjakan maju di atas `forwardJumpRecordThresholdMs` dicatat jumlah dan
///   nilai terbesarnya tanpa mengubah perilaku game.
class ClockGuard {
  const ClockGuard({this.timeConfig = const TimeConfig()});

  final TimeConfig timeConfig;

  ClockReading resolve({required ClockState current, required int rawNowMs}) {
    final safeLastSeen = math.max(0, current.lastSeenAtMs);
    if (rawNowMs < 0 || rawNowMs < safeLastSeen) {
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
      final delta = rawNowMs - safeLastSeen;
      if (delta > thresholdMs) {
        jumpMs = delta;
        jumpCount += 1;
        maxJumpMs = math.max(maxJumpMs, delta);
      }
    }

    return ClockReading(
      effectiveMs: rawNowMs,
      wentBack: false,
      forwardJumpMs: jumpMs,
      state: ClockState(
        lastSeenAtMs: rawNowMs,
        forwardJumpCount: jumpCount,
        maxForwardJumpMs: maxJumpMs,
      ),
    );
  }
}
