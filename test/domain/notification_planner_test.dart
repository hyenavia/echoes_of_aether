import 'package:echoes_of_aether/core/errors/config_exception.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/game_settings.dart';
import 'package:echoes_of_aether/domain/entities/notification_config.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/services/notification_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = NotificationPlanner();

  group('NotificationPlanner', () {
    test('menjadwalkan semua kategori aktif dengan pesan netral', () {
      // Senin 2026-11-16 10:00 UTC (tzOffset = 0).
      final nowMs = DateTime.utc(2026, 11, 16, 10, 0).millisecondsSinceEpoch;
      final planned = planner.plan(
        NotificationInputs(
          nowMs: nowMs,
          settings: const GameSettingsData(
            notifyAutoFarmingFull: true,
            notifyDailyBossReminder: true,
            notifyWeeklyBossReminder: true,
            notifyQuietHoursEnabled: true,
          ),
          offlineMode: OfflineActivityMode.autoFarming,
          lastOfflineClaimAtMs: nowMs,
          timeZoneOffset: Duration.zero,
        ),
      );

      expect(planned, hasLength(3));
      final autoFarm = planned.firstWhere(
        (n) => n.category == NotificationCategory.autoFarmingFull,
      );
      expect(
        autoFarm.fireAtMs,
        DateTime.utc(2026, 11, 16, 18, 0).millisecondsSinceEpoch,
      );
      expect(
        autoFarm.body,
        'Batas offline 8 jam tercapai. Hasil farming siap diklaim.',
      );

      final daily = planned.firstWhere(
        (n) => n.category == NotificationCategory.dailyBossReminder,
      );
      expect(
        daily.fireAtMs,
        DateTime.utc(2026, 11, 16, 18, 0).millisecondsSinceEpoch,
      );

      final weekly = planned.firstWhere(
        (n) => n.category == NotificationCategory.weeklyBossReminder,
      );
      expect(
        weekly.fireAtMs,
        DateTime.utc(2026, 11, 22, 18, 0).millisecondsSinceEpoch,
      );
    });

    test('mode pauseProgression dan quest selesai tidak dijadwalkan', () {
      final nowMs = DateTime.utc(2026, 11, 16, 10, 0).millisecondsSinceEpoch;
      final planned = planner.plan(
        NotificationInputs(
          nowMs: nowMs,
          settings: const GameSettingsData(
            notifyAutoFarmingFull: true,
            notifyDailyBossReminder: true,
            notifyWeeklyBossReminder: true,
          ),
          offlineMode: OfflineActivityMode.pauseProgression,
          lastOfflineClaimAtMs: nowMs,
          dailyBossQuestCompleted: true,
          weeklyBossQuestCompleted: true,
          timeZoneOffset: Duration.zero,
        ),
      );

      expect(planned, isEmpty);
    });

    test('toggle mati tidak menjadwalkan kategori terkait', () {
      final nowMs = DateTime.utc(2026, 11, 16, 10, 0).millisecondsSinceEpoch;
      final planned = planner.plan(
        NotificationInputs(
          nowMs: nowMs,
          settings: const GameSettingsData(
            notifyAutoFarmingFull: false,
            notifyDailyBossReminder: true,
            notifyWeeklyBossReminder: false,
          ),
          offlineMode: OfflineActivityMode.autoFarming,
          lastOfflineClaimAtMs: nowMs,
          timeZoneOffset: Duration.zero,
        ),
      );

      expect(planned, hasLength(1));
      expect(planned.single.category, NotificationCategory.dailyBossReminder);
    });

    test('jam tenang menggeser notifikasi ke akhir jam tenang (07:00)', () {
      // 2026-11-16 17:00 -> +8 jam = 2026-11-17 01:00 (di dalam 23..07) -> digeser ke 07:00.
      final nowMs = DateTime.utc(2026, 11, 16, 17, 0).millisecondsSinceEpoch;
      final planned = planner.plan(
        NotificationInputs(
          nowMs: nowMs,
          settings: const GameSettingsData(
            notifyAutoFarmingFull: true,
            notifyQuietHoursEnabled: true,
          ),
          offlineMode: OfflineActivityMode.continueDungeon,
          lastOfflineClaimAtMs: nowMs,
          timeZoneOffset: Duration.zero,
        ),
      );

      expect(planned, hasLength(1));
      expect(
        planned.single.fireAtMs,
        DateTime.utc(2026, 11, 17, 7, 0).millisecondsSinceEpoch,
      );
    });

    test('max_per_day membatasi jumlah notifikasi per hari kalender', () {
      final nowMs = DateTime.utc(2026, 11, 22, 10, 0).millisecondsSinceEpoch;
      // Minggu 10:00: autoFarm (+8h=18:00), daily (18:00), weekly (18:00) semua di hari yg sama.
      final planned = planner.plan(
        NotificationInputs(
          nowMs: nowMs,
          settings: const GameSettingsData(
            notifyAutoFarmingFull: true,
            notifyDailyBossReminder: true,
            notifyWeeklyBossReminder: true,
          ),
          offlineMode: OfflineActivityMode.autoFarming,
          lastOfflineClaimAtMs: nowMs,
          config: const NotificationConfig(maxPerDay: 2),
          timeZoneOffset: Duration.zero,
        ),
      );

      expect(planned, hasLength(2));
    });

    test(
      'lintas pergantian hari dan minggu menjadwalkan pengingat berikutnya',
      () {
        // Minggu 2026-11-22 19:00 (setelah jam 18:00) -> daily besok Senin 18:00, weekly Minggu depan 2026-11-29 18:00.
        final nowMs = DateTime.utc(2026, 11, 22, 19, 0).millisecondsSinceEpoch;
        final planned = planner.plan(
          NotificationInputs(
            nowMs: nowMs,
            settings: const GameSettingsData(
              notifyDailyBossReminder: true,
              notifyWeeklyBossReminder: true,
            ),
            offlineMode: OfflineActivityMode.pauseProgression,
            lastOfflineClaimAtMs: nowMs,
            timeZoneOffset: Duration.zero,
          ),
        );

        expect(planned, hasLength(2));
        expect(
          planned[0].fireAtMs,
          DateTime.utc(2026, 11, 23, 18, 0).millisecondsSinceEpoch,
        );
        expect(
          planned[1].fireAtMs,
          DateTime.utc(2026, 11, 29, 18, 0).millisecondsSinceEpoch,
        );
      },
    );

    test(
      'parser notifications menolak jam invalid dan weekday tidak dikenal',
      () {
        const parser = GameConfigParser();
        expect(
          () => parser.parseNotifications(
            '{"notifications": {"daily_reminder_hour": 24}}',
          ),
          throwsA(isA<ConfigException>()),
        );
        expect(
          () => parser.parseNotifications(
            '{"notifications": {"weekly_reminder_weekday": "funday"}}',
          ),
          throwsA(isA<ConfigException>()),
        );
      },
    );

    test('event_shop_ending dijadwalkan Minggu bila toggle aktif dan ada item layak beli, patuh jam tenang & maxPerDay', () {
      final nowMs = DateTime.utc(2026, 11, 16, 10, 0).millisecondsSinceEpoch;
      // Tidak ada item layak beli -> tidak dijadwalkan.
      final noItemPlan = planner.plan(
        NotificationInputs(
          nowMs: nowMs,
          settings: const GameSettingsData(notifyEventShopEnding: true),
          offlineMode: OfflineActivityMode.pauseProgression,
          lastOfflineClaimAtMs: nowMs,
          hasPurchasableUnboughtEventItem: false,
          timeZoneOffset: Duration.zero,
        ),
      );
      expect(noItemPlan, isEmpty);

      // Toggle aktif + ada item layak beli -> Minggu 2026-11-22 18:00.
      final eligiblePlan = planner.plan(
        NotificationInputs(
          nowMs: nowMs,
          settings: const GameSettingsData(notifyEventShopEnding: true),
          offlineMode: OfflineActivityMode.pauseProgression,
          lastOfflineClaimAtMs: nowMs,
          hasPurchasableUnboughtEventItem: true,
          timeZoneOffset: Duration.zero,
        ),
      );
      expect(eligiblePlan, hasLength(1));
      expect(
        eligiblePlan.single.category,
        NotificationCategory.eventShopEnding,
      );
      expect(eligiblePlan.single.id, NotificationPlanner.idEventShopEnding);
      expect(eligiblePlan.single.channel, NotificationPlanner.channelEventShop);
      expect(
        eligiblePlan.single.fireAtMs,
        DateTime.utc(2026, 11, 22, 18, 0).millisecondsSinceEpoch,
      );

      // Jam tenang menggeser pengingat pukul 23:00 ke 07:00 keesokan paginya.
      final quietPlan = planner.plan(
        NotificationInputs(
          nowMs: nowMs,
          settings: const GameSettingsData(
            notifyEventShopEnding: true,
            notifyQuietHoursEnabled: true,
          ),
          offlineMode: OfflineActivityMode.pauseProgression,
          lastOfflineClaimAtMs: nowMs,
          hasPurchasableUnboughtEventItem: true,
          config: const NotificationConfig(weeklyReminderHour: 23),
          timeZoneOffset: Duration.zero,
        ),
      );
      expect(
        quietPlan.single.fireAtMs,
        DateTime.utc(2026, 11, 23, 7, 0).millisecondsSinceEpoch,
      );
    });

    test('event_shop_ending dijadwalkan Minggu bila toggle aktif dan ada item layak beli, patuh jam tenang & maxPerDay', () {
      final nowMs = DateTime.utc(2026, 11, 16, 10, 0).millisecondsSinceEpoch;
      // Tidak ada item layak beli -> tidak dijadwalkan.
      final noItemPlan = planner.plan(
        NotificationInputs(
          nowMs: nowMs,
          settings: const GameSettingsData(notifyEventShopEnding: true),
          offlineMode: OfflineActivityMode.pauseProgression,
          lastOfflineClaimAtMs: nowMs,
          hasPurchasableUnboughtEventItem: false,
          timeZoneOffset: Duration.zero,
        ),
      );
      expect(noItemPlan, isEmpty);

      // Toggle aktif + ada item layak beli -> Minggu 2026-11-22 18:00.
      final eligiblePlan = planner.plan(
        NotificationInputs(
          nowMs: nowMs,
          settings: const GameSettingsData(notifyEventShopEnding: true),
          offlineMode: OfflineActivityMode.pauseProgression,
          lastOfflineClaimAtMs: nowMs,
          hasPurchasableUnboughtEventItem: true,
          timeZoneOffset: Duration.zero,
        ),
      );
      expect(eligiblePlan, hasLength(1));
      expect(
        eligiblePlan.single.category,
        NotificationCategory.eventShopEnding,
      );
      expect(eligiblePlan.single.id, NotificationPlanner.idEventShopEnding);
      expect(eligiblePlan.single.channel, NotificationPlanner.channelEventShop);
      expect(
        eligiblePlan.single.fireAtMs,
        DateTime.utc(2026, 11, 22, 18, 0).millisecondsSinceEpoch,
      );

      // Jam tenang menggeser pengingat pukul 23:00 ke 07:00 keesokan paginya.
      final quietPlan = planner.plan(
        NotificationInputs(
          nowMs: nowMs,
          settings: const GameSettingsData(
            notifyEventShopEnding: true,
            notifyQuietHoursEnabled: true,
          ),
          offlineMode: OfflineActivityMode.pauseProgression,
          lastOfflineClaimAtMs: nowMs,
          hasPurchasableUnboughtEventItem: true,
          config: const NotificationConfig(weeklyReminderHour: 23),
          timeZoneOffset: Duration.zero,
        ),
      );
      expect(
        quietPlan.single.fireAtMs,
        DateTime.utc(2026, 11, 23, 7, 0).millisecondsSinceEpoch,
      );
    });
  });
}
