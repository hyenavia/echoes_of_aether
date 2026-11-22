import '../entities/game_settings.dart';
import '../entities/notification_config.dart';
import '../entities/offline_activity.dart';
import '../entities/time_config.dart';
import 'period_service.dart';

/// Kategori notifikasi lokal yang dapat diatur secara independen.
enum NotificationCategory {
  autoFarmingFull,
  dailyBossReminder,
  weeklyBossReminder,
  abyssalSpireReset,
  eventShopEnding,
}

/// Rencana satu notifikasi lokal yang siap dijadwalkan oleh [NotificationScheduler].
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.channel,
    required this.category,
    required this.fireAtMs,
    required this.title,
    required this.body,
  });

  final int id;
  final String channel;
  final NotificationCategory category;
  final int fireAtMs;
  final String title;
  final String body;
}

/// Masukan deterministik untuk [NotificationPlanner.plan].
class NotificationInputs {
  const NotificationInputs({
    required this.nowMs,
    required this.settings,
    required this.offlineMode,
    required this.lastOfflineClaimAtMs,
    this.offlineMaxDurationMs = 4 * 60 * 60 * 1000,
    this.dailyBossQuestCompleted = false,
    this.weeklyBossQuestCompleted = false,
    this.hasPurchasableUnboughtEventItem = false,
    this.config = const NotificationConfig(),
    this.timeConfig = const TimeConfig(),
    this.timeZoneOffset,
  });

  final int nowMs;
  final GameSettingsData settings;
  final OfflineActivityMode offlineMode;
  final int lastOfflineClaimAtMs;
  final int offlineMaxDurationMs;
  final bool dailyBossQuestCompleted;
  final bool weeklyBossQuestCompleted;
  final bool hasPurchasableUnboughtEventItem;
  final NotificationConfig config;
  final TimeConfig timeConfig;
  final Duration? timeZoneOffset;
}

/// Perencana notifikasi lokal domain murni (tanpa dependensi Flutter/plugin).
class NotificationPlanner {
  const NotificationPlanner();

  static const int idAutoFarmingFull = 1001;
  static const int idDailyBossReminder = 1002;
  static const int idWeeklyBossReminder = 1003;
  static const int idEventShopEnding = 1004;
  static const int idAbyssalSpireReset = 1005;

  static const String channelOffline = 'offline_farming';
  static const String channelBossEvents = 'boss_events';
  static const String channelEventShop = 'event_shop';

  List<PlannedNotification> plan(NotificationInputs inputs) {
    final tzOffset = inputs.timeZoneOffset ?? DateTime.now().timeZoneOffset;
    final periodService = PeriodService(
      config: inputs.timeConfig,
      timeZoneOffset: () => tzOffset,
    );
    final rawCandidates = <PlannedNotification>[];

    // 1. Auto Farming / Continue Dungeon penuh (batas 4 jam).
    final isOfflineRunnable =
        inputs.offlineMode == OfflineActivityMode.autoFarming ||
        inputs.offlineMode == OfflineActivityMode.continueDungeon;
    if (inputs.settings.notifyAutoFarmingFull &&
        isOfflineRunnable &&
        inputs.offlineMaxDurationMs > 0) {
      final anchorMs = inputs.lastOfflineClaimAtMs > 0
          ? inputs.lastOfflineClaimAtMs
          : inputs.nowMs;
      final rawFireMs = anchorMs + inputs.offlineMaxDurationMs;
      if (rawFireMs > inputs.nowMs) {
        rawCandidates.add(
          PlannedNotification(
            id: idAutoFarmingFull,
            channel: channelOffline,
            category: NotificationCategory.autoFarmingFull,
            fireAtMs: rawFireMs,
            title: 'Auto Farming Selesai',
            body: 'Batas offline 4 jam tercapai. Hasil farming siap diklaim.',
          ),
        );
      }
    }

    // 2. Notifikasi Daily Reset (saat pergantian hari / reset_hour).
    if (inputs.settings.notifyDailyBossReminder) {
      final fireMs = periodService.nextResetMs(
        Period.daily,
        inputs.nowMs,
        offset: tzOffset,
      );
      rawCandidates.add(
        PlannedNotification(
          id: idDailyBossReminder,
          channel: channelBossEvents,
          category: NotificationCategory.dailyBossReminder,
          fireAtMs: fireMs,
          title: 'Daily Reset',
          body: 'Quest & Daily Boss hari baru sudah tersedia!',
        ),
      );
    }

    // 3. Notifikasi Weekly Reset (Senin pukul reset_hour).
    if (inputs.settings.notifyWeeklyBossReminder) {
      final fireMs = periodService.nextResetMs(
        Period.weekly,
        inputs.nowMs,
        offset: tzOffset,
      );
      rawCandidates.add(
        PlannedNotification(
          id: idWeeklyBossReminder,
          channel: channelBossEvents,
          category: NotificationCategory.weeklyBossReminder,
          fireAtMs: fireMs,
          title: 'Weekly Reset',
          body: 'Quest & Weekly Boss minggu baru sudah direset!',
        ),
      );
    }

    // 4. Notifikasi Menara Bos Abyssal Reset (siklus 2 mingguan).
    if (inputs.settings.notifyAbyssalSpireReset) {
      final fireMs = periodService.nextBiweeklyResetMs(
        inputs.nowMs,
        offset: tzOffset,
      );
      rawCandidates.add(
        PlannedNotification(
          id: idAbyssalSpireReset,
          channel: channelBossEvents,
          category: NotificationCategory.abyssalSpireReset,
          fireAtMs: fireMs,
          title: 'Menara Bos Abyssal Reset',
          body: 'Siklus baru Menara Bos Abyssal telah dimulai!',
        ),
      );
    }

    // 5. Pengingat Event Shop berganti (Minggu pukul weeklyReminderHour bila
    //    masih ada item event yang belum dibeli & syaratnya terpenuhi).
    if (inputs.settings.notifyEventShopEnding &&
        inputs.hasPurchasableUnboughtEventItem) {
      final rawFireMs = _nextWeeklyReminderMs(
        nowMs: inputs.nowMs,
        tzOffset: tzOffset,
        weekday: inputs.config.weeklyReminderWeekday,
        hour: inputs.config.weeklyReminderHour,
      );
      rawCandidates.add(
        PlannedNotification(
          id: idEventShopEnding,
          channel: channelEventShop,
          category: NotificationCategory.eventShopEnding,
          fireAtMs: rawFireMs,
          title: 'Event Shop Akan Berganti',
          body: 'Item mingguan Event Shop tersedia sebelum rotasi berganti.',
        ),
      );
    }

    // Urutkan berdasarkan waktu tercepat, lalu ID stabil.
    rawCandidates.sort((a, b) {
      final timeCmp = a.fireAtMs.compareTo(b.fireAtMs);
      return timeCmp != 0 ? timeCmp : a.id.compareTo(b.id);
    });

    // Batasi maksimal maxPerDay per hari kalender lokal.
    final maxPerDay = inputs.config.maxPerDay < 1 ? 1 : inputs.config.maxPerDay;
    final countsByDay = <String, int>{};
    final result = <PlannedNotification>[];
    for (final item in rawCandidates) {
      final local = DateTime.fromMillisecondsSinceEpoch(
        item.fireAtMs,
        isUtc: true,
      ).add(tzOffset);
      final dayKey =
          '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
      final count = countsByDay[dayKey] ?? 0;
      if (count >= maxPerDay) continue;
      countsByDay[dayKey] = count + 1;
      result.add(item);
    }
    return List<PlannedNotification>.unmodifiable(result);
  }

  static int _nextWeeklyReminderMs({
    required int nowMs,
    required Duration tzOffset,
    required int weekday,
    required int hour,
  }) {
    final nowLocal = DateTime.fromMillisecondsSinceEpoch(
      nowMs,
      isUtc: true,
    ).add(tzOffset);
    var daysAhead = (weekday - nowLocal.weekday) % 7;
    if (daysAhead < 0) daysAhead += 7;
    var targetLocal = DateTime.utc(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day,
      hour,
    ).add(Duration(days: daysAhead));
    if (!targetLocal.isAfter(nowLocal)) {
      targetLocal = targetLocal.add(const Duration(days: 7));
    }
    return targetLocal.subtract(tzOffset).millisecondsSinceEpoch;
  }
}
