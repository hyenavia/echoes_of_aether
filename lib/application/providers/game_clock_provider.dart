import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/clock_guard.dart';
import '../../domain/services/game_clock.dart';
import '../../domain/services/period_service.dart';
import 'game_config_provider.dart';

/// Sumber waktu tunggal yang dapat di-override di test.
final gameClockProvider = Provider<GameClock>((ref) => const SystemGameClock());

/// Layanan periode harian/mingguan berbasis konfigurasi `time` aktif.
final periodServiceProvider = Provider<PeriodService>((ref) {
  final asyncConfig = ref.watch(gameConfigProvider);
  final timeConfig = asyncConfig.asData?.value.time;
  return timeConfig != null
      ? PeriodService(config: timeConfig)
      : const PeriodService();
});

/// Pengaman jam monotonik berbasis konfigurasi `time` aktif.
final clockGuardProvider = Provider<ClockGuard>((ref) {
  final asyncConfig = ref.watch(gameConfigProvider);
  final timeConfig = asyncConfig.asData?.value.time;
  return timeConfig != null
      ? ClockGuard(timeConfig: timeConfig)
      : const ClockGuard();
});
