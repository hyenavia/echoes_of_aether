import '../entities/game_settings.dart';
import '../entities/notification_config.dart';
import '../entities/offline_activity.dart';
import '../entities/time_config.dart';

/// Kategori notifikasi lokal yang dapat diatur secara independen.
enum NotificationCategory {
  autoFarmingFull,
  dailyBossReminder,
  weeklyBossReminder,
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
    this.offlineMaxDurationMs = 8 * 60 * 60 * 1000,
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

  static const String channelOffline = 'offline_farming';
  static const String channelBossEvents = 'boss_events';
  static const String channelEventShop = 'event_shop';

  List<PlannedNotification> plan(NotificationInputs inputs) {
    final tzOffset = inputs.timeZoneOffset ?? DateTime.now().timeZoneOffset;
    final rawCandidates = <PlannedNotification>[];

    // 1. Auto Farming / Continue Dungeon penuh (batas 8 jam).
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
        final shiftedMs = _applyQuietHours(
          utcMs: rawFireMs,
          tzOffset: tzOffset,
          config: inputs.config,
          enabled: inputs.settings.notifyQuietHoursEnabled,
        );
        rawCandidates.add(
          PlannedNotification(
            id: idAutoFarmingFull,
            channel: channelOffline,
            category: NotificationCategory.autoFarmingFull,
            fireAtMs: shiftedMs,
            title: 'Auto Farming Selesai',
            body: 'Batas offline 8 jam tercapai. Hasil farming siap diklaim.',
          ),
        );
      }
    }

    // 2. Pengingat Daily Boss (bila belum selesai pada periode ini).
    if (inputs.settings.notifyDailyBossReminder &&
        !inputs.dailyBossQuestCompleted) {
      final rawFireMs = _nextDailyReminderMs(
        nowMs: inputs.nowMs,
        tzOffset: tzOffset,
        hour: inputs.config.dailyReminderHour,
      );
      final shiftedMs = _applyQuietHours(
        utcMs: rawFireMs,
        tzOffset: tzOffset,
        config: inputs.config,
        enabled: inputs.settings.notifyQuietHoursEnabled,
      );
      rawCandidates.add(
        PlannedNotification(
          id: idDailyBossReminder,
          channel: channelBossEvents,
          category: NotificationCategory.dailyBossReminder,
          fireAtMs: shiftedMs,
          title: 'Daily Boss Menanti',
          body: 'Daily Boss hari ini belum dikalahkan. Hadiah menanti di Town.',
        ),
      );
    }

    // 3. Pengingat Weekly Boss (bila belum selesai pada minggu ini).
    if (inputs.settings.notifyWeeklyBossReminder &&
        !inputs.weeklyBossQuestCompleted) {
      final rawFireMs = _nextWeeklyReminderMs(
        nowMs: inputs.nowMs,
        tzOffset: tzOffset,
        weekday: inputs.config.weeklyReminderWeekday,
        hour: inputs.config.weeklyReminderHour,
      );
      final shiftedMs = _applyQuietHours(
        utcMs: rawFireMs,
        tzOffset: tzOffset,
        config: inputs.config,
        enabled: inputs.settings.notifyQuietHoursEnabled,
      );
      rawCandidates.add(
        PlannedNotification(
          id: idWeeklyBossReminder,
          channel: channelBossEvents,
          category: NotificationCategory.weeklyBossReminder,
          fireAtMs: shiftedMs,
          title: 'Weekly Boss Menanti',
          body: 'Weekly Boss minggu ini masih tersedia untuk ditantang.',
        ),
      );
    }

    // 4. Pengingat Event Shop berganti (Minggu pukul weeklyReminderHour bila
    //    masih ada item event yang belum dibeli & syaratnya terpenuhi).
    if (inputs.settings.notifyEventShopEnding &&
        inputs.hasPurchasableUnboughtEventItem) {
      final rawFireMs = _nextWeeklyReminderMs(
        nowMs: inputs.nowMs,
        tzOffset: tzOffset,
        weekday: inputs.config.weeklyReminderWeekday,
        hour: inputs.config.weeklyReminderHour,
      );
      final shiftedMs = _applyQuietHours(
        utcMs: rawFireMs,
        tzOffset: tzOffset,
        config: inputs.config,
        enabled: inputs.settings.notifyQuietHoursEnabled,
      );
      rawCandidates.add(
        PlannedNotification(
          id: idEventShopEnding,
          channel: channelEventShop,
          category: NotificationCategory.eventShopEnding,
          fireAtMs: shiftedMs,
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

  static int _nextDailyReminderMs({
    required int nowMs,
    required Duration tzOffset,
    required int hour,
  }) {
    final nowLocal = DateTime.fromMillisecondsSinceEpoch(
      nowMs,
      isUtc: true,
    ).add(tzOffset);
    var targetLocal = DateTime.utc(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day,
      hour,
    );
    if (!targetLocal.isAfter(nowLocal)) {
      targetLocal = targetLocal.add(const Duration(days: 1));
    }
    return targetLocal.subtract(tzOffset).millisecondsSinceEpoch;
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

  static int _applyQuietHours({
    required int utcMs,
    required Duration tzOffset,
    required NotificationConfig config,
    required bool enabled,
  }) {
    if (!enabled) return utcMs;
    final qh = config.quietHours;
    final local = DateTime.fromMillisecondsSinceEpoch(
      utcMs,
      isUtc: true,
    ).add(tzOffset);
    if (!qh.containsHour(local.hour)) return utcMs;

    var endLocal = DateTime.utc(local.year, local.month, local.day, qh.endHour);
    // Jika rentang melewati tengah malam dan saat ini berada pada jam >= startHour,
    // akhir jam tenang ada di hari berikutnya pukul endHour:00.
    if (qh.startHour > qh.endHour && local.hour >= qh.startHour) {
      endLocal = endLocal.add(const Duration(days: 1));
    } else if (!endLocal.isAfter(local)) {
      endLocal = endLocal.add(const Duration(days: 1));
    }
    return endLocal.subtract(tzOffset).millisecondsSinceEpoch;
  }
}
