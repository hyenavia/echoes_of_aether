import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode, kProfileMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Ringkasan metrik frame-time untuk overlay debug/profile.
class _FrameStats {
  const _FrameStats({
    this.buildMs = 0,
    this.rasterMs = 0,
    this.maxBuildMs = 0,
    this.jankCount = 0,
  });

  final double buildMs;
  final double rasterMs;
  final double maxBuildMs;
  final int jankCount;
}

/// Overlay frame-time sederhana (hanya aktif di debug/profile, non-interaktif).
class PerfFrameOverlay extends StatefulWidget {
  const PerfFrameOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<PerfFrameOverlay> createState() => _PerfFrameOverlayState();
}

class _PerfFrameOverlayState extends State<PerfFrameOverlay> {
  static final bool _isWidgetTest = WidgetsBinding.instance.runtimeType
      .toString()
      .contains('TestWidgetsFlutterBinding');

  static bool get _active =>
      (kDebugMode || kProfileMode) &&
      !_isWidgetTest &&
      const bool.fromEnvironment('ENABLE_PERF_OVERLAY');

  final ValueNotifier<_FrameStats> _stats = ValueNotifier(const _FrameStats());
  double _windowMaxBuildMs = 0;
  int _jankCount = 0;
  int _lastPublishMs = 0;

  @override
  void initState() {
    super.initState();
    if (_active) {
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
    }
  }

  @override
  void dispose() {
    if (_active) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    }
    _stats.dispose();
    super.dispose();
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!mounted || timings.isEmpty) return;
    double lastBuild = 0;
    double lastRaster = 0;
    for (final t in timings) {
      final buildMs = t.buildDuration.inMicroseconds / 1000.0;
      final rasterMs = t.rasterDuration.inMicroseconds / 1000.0;
      lastBuild = buildMs;
      lastRaster = rasterMs;
      _windowMaxBuildMs = math.max(_windowMaxBuildMs, buildMs);
      if (buildMs > 16.67 || rasterMs > 16.67) {
        _jankCount++;
      }
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    // Throttle pembaruan overlay (~4 Hz) agar overlay tidak membebani UI.
    if (nowMs - _lastPublishMs < 250) return;
    _lastPublishMs = nowMs;

    _stats.value = _FrameStats(
      buildMs: lastBuild,
      rasterMs: lastRaster,
      maxBuildMs: _windowMaxBuildMs,
      jankCount: _jankCount,
    );
    _windowMaxBuildMs = 0;
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 4,
          right: 6,
          child: IgnorePointer(
            child: SafeArea(
              child: ValueListenableBuilder<_FrameStats>(
                valueListenable: _stats,
                builder: (context, s, _) {
                  final isJank = s.maxBuildMs > 16.67 || s.rasterMs > 16.67;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC0D1318),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isJank
                            ? const Color(0xFFEF5350)
                            : const Color(0xFF4CAF50),
                        width: 1,
                      ),
                    ),
                    child: DefaultTextStyle(
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontFamily: 'monospace',
                        color: Color(0xFFE6EDF3),
                        height: 1.2,
                      ),
                      child: Text(
                        'UI ${s.buildMs.toStringAsFixed(1)}ms '
                        '(max ${s.maxBuildMs.toStringAsFixed(1)}) '
                        'GPU ${s.rasterMs.toStringAsFixed(1)}ms '
                        'J:${s.jankCount}',
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
