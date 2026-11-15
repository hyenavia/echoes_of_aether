import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../domain/entities/game_config.dart';
import '../../domain/entities/game_settings.dart';
import '../../domain/entities/offline_activity.dart';
import '../../domain/entities/periodic_quest_state.dart';
import '../../domain/services/equipment_factory.dart';
import '../../domain/services/event_shop_service.dart';
import '../../domain/services/game_clock.dart';
import '../../domain/services/notification_planner.dart';
import '../../domain/services/offline_time_calculator.dart';
import '../../domain/services/period_service.dart';
import '../../domain/services/requirement_evaluator.dart';
import 'notification_scheduler.dart';

/// Snapshot ringan state yang dibutuhkan observer notifikasi saat aplikasi
/// masuk/keluar latar belakang.
class NotificationRuntimeSnapshot {
  const NotificationRuntimeSnapshot({
    required this.config,
    required this.settings,
    required this.offlineMode,
    required this.lastOfflineClaimAtMs,
    this.lastSeenAtMs = 0,
    this.periodicQuestStates = const [],
    this.shopContext,
  });

  final GameConfig config;
  final GameSettingsData settings;
  final OfflineActivityMode offlineMode;
  final int lastOfflineClaimAtMs;
  final int lastSeenAtMs;
  final List<PeriodicQuestState> periodicQuestStates;
  final ShopPlayerContext? shopContext;
}

/// Observer lifecycle tingkat aplikasi untuk menjadwalkan notifikasi lokal saat
/// aplikasi masuk latar belakang (`paused`/`hidden`) dan membatalkannya saat
/// kembali aktif (`resumed`).
class AppLifecycleNotificationObserver with WidgetsBindingObserver {
  AppLifecycleNotificationObserver({
    required this.scheduler,
    required this.loadSnapshot,
    this.clock = const SystemGameClock(),
    this.planner = const NotificationPlanner(),
    this.offlineMaxDurationMs,
    this.timeZoneOffset,
  });

  final NotificationScheduler scheduler;
  final Future<NotificationRuntimeSnapshot?> Function() loadSnapshot;
  final GameClock clock;
  final NotificationPlanner planner;
  final int? offlineMaxDurationMs;
  final Duration? timeZoneOffset;

  bool _attached = false;

  void attach() {
    if (_attached) return;
    WidgetsBinding.instance.addObserver(this);
    _attached = true;
  }

  void detach() {
    if (!_attached) return;
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(handleLifecycleState(state));
  }

  /// Menangani transisi lifecycle secara eksplisit (mudah diuji tanpa binding).
  Future<void> handleLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      await _scheduleFromLatestState();
    } else if (state == AppLifecycleState.resumed) {
      await scheduler.cancelAll();
      // Hitung ulang dari state terbaru (refresh snapshot) bila diperlukan.
      await loadSnapshot();
    }
  }

  Future<void> _scheduleFromLatestState() async {
    final snap = await loadSnapshot();
    if (snap == null) return;
    if (!snap.settings.anyNotificationCategoryEnabled) {
      await scheduler.cancelAll();
      return;
    }

    final rawNowMs = clock.nowMs;
    final effectiveNowMs = rawNowMs < snap.lastSeenAtMs
        ? snap.lastSeenAtMs
        : rawNowMs;
    final periodService = PeriodService(
      config: snap.config.time,
      timeZoneOffset: timeZoneOffset != null ? () => timeZoneOffset! : null,
    );
    final bossEvents = snap.config.bossEvents;
    final dailyKey = periodService.keyFor(Period.daily, effectiveNowMs);
    final weeklyKey = periodService.keyFor(Period.weekly, effectiveNowMs);

    var dailyDone = false;
    var weeklyDone = false;
    if (bossEvents != null) {
      for (final q in snap.periodicQuestStates) {
        if (q.questId == bossEvents.daily.questId && q.periodKey == dailyKey) {
          dailyDone = true;
        }
        if (q.questId == bossEvents.weekly.questId &&
            q.periodKey == weeklyKey) {
          weeklyDone = true;
        }
      }
    }

    var hasPurchasableEventItem = false;
    final eventShop = snap.config.eventShop;
    final shopContext = snap.shopContext;
    if (eventShop != null && shopContext != null) {
      final eventShopService = EventShopService(
        catalog: eventShop,
        items: snap.config.items,
        equipmentFactory: EquipmentFactory(snap.config.equipment),
        periodService: periodService,
      );
      hasPurchasableEventItem = eventShopService.hasEligibleUnboughtEntry(
        effectiveNowMs: effectiveNowMs,
        context: shopContext,
        offset: timeZoneOffset,
      );
    }

    final maxOfflineMs =
        offlineMaxDurationMs ??
        OfflineTimeCalculator.defaultMaxOfflineDuration.inMilliseconds;
    final planned = planner.plan(
      NotificationInputs(
        nowMs: effectiveNowMs,
        settings: snap.settings,
        offlineMode: snap.offlineMode,
        lastOfflineClaimAtMs: snap.lastOfflineClaimAtMs,
        offlineMaxDurationMs: maxOfflineMs,
        dailyBossQuestCompleted: dailyDone,
        weeklyBossQuestCompleted: weeklyDone,
        hasPurchasableUnboughtEventItem: hasPurchasableEventItem,
        config: snap.config.notifications,
        timeConfig: snap.config.time,
        timeZoneOffset: timeZoneOffset,
      ),
    );
    await scheduler.replaceAll(planned);
  }
}
