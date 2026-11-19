import 'dart:developer' as developer;

import 'package:flutter/foundation.dart'
    show debugPrint, kDebugMode, kProfileMode;

/// Utilitas instrumentasi performa ringan (aktif hanya di debug/profile).
abstract final class PerfTracer {
  static const bool enabled =
      (kDebugMode || kProfileMode) && bool.fromEnvironment('ENABLE_PERF_LOG');

  /// Mengukur blok sinkron dengan [developer.Timeline] dan [Stopwatch].
  /// Mencetak log jika durasi melebihi [warnThresholdMs] (default 8 ms).
  static T traceSync<T>(
    String name,
    T Function() fn, {
    int warnThresholdMs = 8,
  }) {
    if (!enabled) return fn();
    final sw = Stopwatch()..start();
    developer.Timeline.startSync(name);
    try {
      return fn();
    } finally {
      developer.Timeline.finishSync();
      sw.stop();
      final elapsedUs = sw.elapsedMicroseconds;
      if (elapsedUs > warnThresholdMs * 1000) {
        final ms = (elapsedUs / 1000.0).toStringAsFixed(2);
        debugPrint('[PERF] $name took ${ms}ms');
      }
    }
  }

  /// Mengukur blok asinkron dengan [developer.TimelineTask] dan [Stopwatch].
  /// Mencetak log jika total durasi melebihi [warnThresholdMs] (default 8 ms).
  static Future<T> traceAsync<T>(
    String name,
    Future<T> Function() fn, {
    int warnThresholdMs = 8,
  }) async {
    if (!enabled) return fn();
    final task = developer.TimelineTask()..start(name);
    final sw = Stopwatch()..start();
    try {
      return await fn();
    } finally {
      sw.stop();
      task.finish();
      final elapsedUs = sw.elapsedMicroseconds;
      if (elapsedUs > warnThresholdMs * 1000) {
        final ms = (elapsedUs / 1000.0).toStringAsFixed(2);
        debugPrint('[PERF] $name took ${ms}ms');
      }
    }
  }
}
