import 'dart:io';

import 'package:drift/native.dart';
import 'package:echoes_of_aether/app/theme/echoes_theme.dart';
import 'package:echoes_of_aether/application/services/app_lifecycle_notification_observer.dart';
import 'package:echoes_of_aether/application/services/notification_scheduler.dart';
import 'package:echoes_of_aether/data/database/app_database.dart'
    hide PeriodicQuestState;
import 'package:echoes_of_aether/data/models/boss_events_config_parser.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/event_shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/event_shop_purchase.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/game_settings.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/periodic_quest_state.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/event_shop_service.dart';
import 'package:echoes_of_aether/domain/services/game_clock.dart';
import 'package:echoes_of_aether/domain/services/notification_planner.dart';
import 'package:echoes_of_aether/domain/services/shop_service.dart';
import 'package:echoes_of_aether/features/dungeon/settings_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedClock implements GameClock {
  const _FixedClock(this.nowMs);
  @override
  final int nowMs;
}

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadTestConfig() {
  const parser = GameConfigParser();
  const dungeonParser = DungeonConfigParser();
  final settings = _readAsset('game_config.json');
  final dungeonsJson = _readAsset('dungeons.json');
  return GameConfig(
    monsters: const MonsterConfigParser().parse(_readAsset('monsters.json')),
    damage: parser.parseDamage(settings),
    difficulty: parser.parseDifficulty(settings),
    farming: parser.parseFarming(settings),
    revive: parser.parseRevive(settings),
    progression: parser.parseProgression(settings),
    equipment: parser.parseEquipment(settings),
    time: parser.parseTime(settings),
    claimedRewards: parser.parseClaimedRewards(settings),
    currencies: parser.parseCurrencies(settings),
    notifications: parser.parseNotifications(settings),
    dungeonCompletion: parser.parseDungeonCompletion(settings),
    items: const ItemConfigParser().parse(_readAsset('items.json')),
    lootTables: const LootConfigParser().parse(_readAsset('loot_tables.json')),
    skills: const SkillConfigParser().parse(_readAsset('skills.json')),
    specializations: const SpecializationConfigParser().parse(
      _readAsset('specializations.json'),
    ),
    dungeons: dungeonParser.parse(
      dungeonsJson,
      ascensionMultiplier: parser.parseDifficulty(settings).ascensionMultiplier,
    ),
    mapLayouts: dungeonParser.parseMaps(dungeonsJson),
    bossEvents: const BossEventsConfigParser().parse(
      _readAsset('boss_events.json'),
    ),
    shop: const ShopConfigParser().parse(_readAsset('shop.json')),
    eventShop: const EventShopConfigParser().parse(
      _readAsset('event_shop.json'),
    ),
  );
}

void main() {
  group('Stage 5 Notifications — Settings, Permission & Observer', () {
    test('persistensi toggle notifikasi di GameSettings (Drift)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final config = _loadTestConfig();
      final repo = DriftPlayerSaveRepository(db: db, config: config);

      final initial = await repo.loadSettings();
      expect(initial.notifyAutoFarmingFull, isFalse);
      expect(initial.notifyDailyBossReminder, isFalse);
      expect(initial.notifyWeeklyBossReminder, isFalse);
      expect(initial.notifyQuietHoursEnabled, isTrue);

      final updated = initial.copyWith(
        notifyAutoFarmingFull: true,
        notifyDailyBossReminder: true,
        notifyWeeklyBossReminder: true,
        notifyQuietHoursEnabled: false,
      );
      await repo.saveSettings(updated);

      final reloaded = await repo.loadSettings();
      expect(reloaded, updated);
    });

    testWidgets(
      'penolakan izin mengembalikan toggle ke nonaktif dengan pesan jelas; izin diterima mengaktifkan toggle',
      (tester) async {
        final notifier = ValueNotifier<GameSettingsData>(
          const GameSettingsData(),
        );
        addTearDown(notifier.dispose);
        var permissionResult = false;
        var requestCalls = 0;

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: SettingsOverlay(
                settings: notifier,
                onChanged: (next) => notifier.value = next,
                onRequestNotificationPermission: () async {
                  requestCalls++;
                  return permissionResult;
                },
                onClose: () {},
              ),
            ),
          ),
        );

        await tester.ensureVisible(
          find.byKey(const Key('settings_notify_autofarm')),
        );
        await tester.tap(find.byKey(const Key('settings_notify_autofarm')));
        await tester.pumpAndSettle();

        expect(requestCalls, 1);
        expect(notifier.value.notifyAutoFarmingFull, isFalse);
        expect(
          find.byKey(const Key('settings_notify_permission_error')),
          findsOneWidget,
        );

        // Sekarang izin disetujui.
        permissionResult = true;
        await tester.tap(find.byKey(const Key('settings_notify_autofarm')));
        await tester.pumpAndSettle();

        expect(requestCalls, 2);
        expect(notifier.value.notifyAutoFarmingFull, isTrue);
        expect(
          find.byKey(const Key('settings_notify_permission_error')),
          findsNothing,
        );
      },
    );

    test('AppLifecycleNotificationObserver: paused -> replaceAll dengan plan benar; resumed -> cancelAll', () async {
      final config = _loadTestConfig();
      final scheduler = FakeNotificationScheduler();
      final nowMs = DateTime.utc(2026, 11, 16, 10, 0).millisecondsSinceEpoch;
      final observer = AppLifecycleNotificationObserver(
        scheduler: scheduler,
        clock: _FixedClock(nowMs),
        timeZoneOffset: Duration.zero,
        loadSnapshot: () async => NotificationRuntimeSnapshot(
          config: config,
          settings: const GameSettingsData(
            notifyAutoFarmingFull: true,
            notifyDailyBossReminder: true,
            notifyWeeklyBossReminder: true,
          ),
          offlineMode: OfflineActivityMode.autoFarming,
          lastOfflineClaimAtMs: nowMs,
          periodicQuestStates: const [
            // Daily sudah selesai hari ini, Weekly belum.
            PeriodicQuestState(
              questId: 'daily_boss',
              periodKey: '2026-11-16',
              completedAtMs: 1000,
            ),
          ],
        ),
      );

      await observer.handleLifecycleState(AppLifecycleState.paused);
      expect(scheduler.replaceAllCalls, 1);
      expect(scheduler.scheduled.map((e) => e.category).toList(), [
        NotificationCategory.autoFarmingFull,
        NotificationCategory.weeklyBossReminder,
      ]);

      await observer.handleLifecycleState(AppLifecycleState.resumed);
      expect(scheduler.cancelAllCalls, 1);
      expect(scheduler.scheduled, isEmpty);
    });

    testWidgets(
      'toggle Event Shop berganti di SettingsOverlay meminta izin dan memperbarui notifyEventShopEnding',
      (tester) async {
        final notifier = ValueNotifier(const GameSettingsData());
        addTearDown(notifier.dispose);
        var requestCalls = 0;

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: SettingsOverlay(
                settings: notifier,
                onChanged: (next) => notifier.value = next,
                onClose: () {},
                onRequestNotificationPermission: () async {
                  requestCalls += 1;
                  return true;
                },
              ),
            ),
          ),
        );

        await tester.scrollUntilVisible(
          find.byKey(const Key('settings_notify_event_shop')),
          200,
        );
        await tester.tap(find.byKey(const Key('settings_notify_event_shop')));
        await tester.pumpAndSettle();

        expect(requestCalls, 1);
        expect(notifier.value.notifyEventShopEnding, isTrue);
      },
    );

    test('AppLifecycleNotificationObserver mengevaluasi kelayakan Event Shop minggu berjalan sebelum menjadwalkan eventShopEnding', () async {
      final config = _loadTestConfig();
      final scheduler = FakeNotificationScheduler();
      final nowMs = DateTime.utc(2026, 11, 16, 10, 0).millisecondsSinceEpoch;
      final eventService = EventShopService(
        catalog: config.eventShop!,
        items: config.items,
        equipmentFactory: EquipmentFactory(config.equipment),
      );
      final periodKey = eventService.periodKeyAt(nowMs, offset: Duration.zero);
      final active = eventService.activeEntriesAt(nowMs, offset: Duration.zero);

      // 1. Syarat terpenuhi & belum dibeli -> eventShopEnding dijadwalkan.
      final eligibleObserver = AppLifecycleNotificationObserver(
        scheduler: scheduler,
        clock: _FixedClock(nowMs),
        timeZoneOffset: Duration.zero,
        loadSnapshot: () async => NotificationRuntimeSnapshot(
          config: config,
          settings: const GameSettingsData(notifyEventShopEnding: true),
          offlineMode: OfflineActivityMode.pauseProgression,
          lastOfflineClaimAtMs: nowMs,
          shopContext: const ShopPlayerContext(
            playerLevel: 30,
            dungeonProgresses: {
              'ancient_crypt': DungeonProgressSnapshot(
                currentDungeonId: 'ancient_crypt',
                clearsCount: 1,
              ),
            },
          ),
        ),
      );
      await eligibleObserver.handleLifecycleState(AppLifecycleState.paused);
      expect(scheduler.scheduled.map((e) => e.category).toList(), [
        NotificationCategory.eventShopEnding,
      ]);

      // 2. Semua item layak beli minggu ini sudah dibeli -> eventShopEnding tidak dijadwalkan.
      final boughtObserver = AppLifecycleNotificationObserver(
        scheduler: scheduler,
        clock: _FixedClock(nowMs),
        timeZoneOffset: Duration.zero,
        loadSnapshot: () async => NotificationRuntimeSnapshot(
          config: config,
          settings: const GameSettingsData(notifyEventShopEnding: true),
          offlineMode: OfflineActivityMode.pauseProgression,
          lastOfflineClaimAtMs: nowMs,
          shopContext: ShopPlayerContext(
            playerLevel: 30,
            cycleProgress: const CycleProgress(
              ascensionRank: 1,
              highestAscensionRank: 1,
            ),
            dungeonProgresses: const {
              'ancient_crypt': DungeonProgressSnapshot(
                currentDungeonId: 'ancient_crypt',
                clearsCount: 1,
              ),
            },
            eventShopPurchases: {
              for (final entry in active)
                (entry.id, periodKey): EventShopPurchaseRecord(
                  entryId: entry.id,
                  periodKey: periodKey,
                ).purchasedCount,
            },
          ),
        ),
      );
      await boughtObserver.handleLifecycleState(AppLifecycleState.paused);
      expect(scheduler.scheduled, isEmpty);

      // 3. Syarat belum terpenuhi sama sekali -> tidak dijadwalkan.
      final lockedObserver = AppLifecycleNotificationObserver(
        scheduler: scheduler,
        clock: _FixedClock(nowMs),
        timeZoneOffset: Duration.zero,
        loadSnapshot: () async => NotificationRuntimeSnapshot(
          config: config,
          settings: const GameSettingsData(notifyEventShopEnding: true),
          offlineMode: OfflineActivityMode.pauseProgression,
          lastOfflineClaimAtMs: nowMs,
          shopContext: const ShopPlayerContext(playerLevel: 5),
        ),
      );
      await lockedObserver.handleLifecycleState(AppLifecycleState.paused);
      expect(scheduler.scheduled, isEmpty);
    });

    testWidgets(
      'toggle Event Shop berganti di SettingsOverlay meminta izin dan memperbarui notifyEventShopEnding',
      (tester) async {
        final notifier = ValueNotifier(const GameSettingsData());
        addTearDown(notifier.dispose);
        var requestCalls = 0;

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: SettingsOverlay(
                settings: notifier,
                onChanged: (next) => notifier.value = next,
                onClose: () {},
                onRequestNotificationPermission: () async {
                  requestCalls += 1;
                  return true;
                },
              ),
            ),
          ),
        );

        await tester.scrollUntilVisible(
          find.byKey(const Key('settings_notify_event_shop')),
          200,
        );
        await tester.tap(find.byKey(const Key('settings_notify_event_shop')));
        await tester.pumpAndSettle();

        expect(requestCalls, 1);
        expect(notifier.value.notifyEventShopEnding, isTrue);
      },
    );

    test('AppLifecycleNotificationObserver mengevaluasi kelayakan Event Shop minggu berjalan sebelum menjadwalkan eventShopEnding', () async {
      final config = _loadTestConfig();
      final scheduler = FakeNotificationScheduler();
      final nowMs = DateTime.utc(2026, 11, 16, 10, 0).millisecondsSinceEpoch;
      final eventService = EventShopService(
        catalog: config.eventShop!,
        items: config.items,
        equipmentFactory: EquipmentFactory(config.equipment),
      );
      final periodKey = eventService.periodKeyAt(nowMs, offset: Duration.zero);
      final active = eventService.activeEntriesAt(nowMs, offset: Duration.zero);

      // 1. Syarat terpenuhi & belum dibeli -> eventShopEnding dijadwalkan.
      final eligibleObserver = AppLifecycleNotificationObserver(
        scheduler: scheduler,
        clock: _FixedClock(nowMs),
        timeZoneOffset: Duration.zero,
        loadSnapshot: () async => NotificationRuntimeSnapshot(
          config: config,
          settings: const GameSettingsData(notifyEventShopEnding: true),
          offlineMode: OfflineActivityMode.pauseProgression,
          lastOfflineClaimAtMs: nowMs,
          shopContext: const ShopPlayerContext(
            playerLevel: 30,
            dungeonProgresses: {
              'ancient_crypt': DungeonProgressSnapshot(
                currentDungeonId: 'ancient_crypt',
                clearsCount: 1,
              ),
            },
          ),
        ),
      );
      await eligibleObserver.handleLifecycleState(AppLifecycleState.paused);
      expect(scheduler.scheduled.map((e) => e.category).toList(), [
        NotificationCategory.eventShopEnding,
      ]);

      // 2. Semua item layak beli minggu ini sudah dibeli -> eventShopEnding tidak dijadwalkan.
      final boughtObserver = AppLifecycleNotificationObserver(
        scheduler: scheduler,
        clock: _FixedClock(nowMs),
        timeZoneOffset: Duration.zero,
        loadSnapshot: () async => NotificationRuntimeSnapshot(
          config: config,
          settings: const GameSettingsData(notifyEventShopEnding: true),
          offlineMode: OfflineActivityMode.pauseProgression,
          lastOfflineClaimAtMs: nowMs,
          shopContext: ShopPlayerContext(
            playerLevel: 30,
            cycleProgress: const CycleProgress(
              ascensionRank: 1,
              highestAscensionRank: 1,
            ),
            dungeonProgresses: const {
              'ancient_crypt': DungeonProgressSnapshot(
                currentDungeonId: 'ancient_crypt',
                clearsCount: 1,
              ),
            },
            eventShopPurchases: {
              for (final entry in active)
                (entry.id, periodKey): EventShopPurchaseRecord(
                  entryId: entry.id,
                  periodKey: periodKey,
                ).purchasedCount,
            },
          ),
        ),
      );
      await boughtObserver.handleLifecycleState(AppLifecycleState.paused);
      expect(scheduler.scheduled, isEmpty);

      // 3. Syarat belum terpenuhi sama sekali -> tidak dijadwalkan.
      final lockedObserver = AppLifecycleNotificationObserver(
        scheduler: scheduler,
        clock: _FixedClock(nowMs),
        timeZoneOffset: Duration.zero,
        loadSnapshot: () async => NotificationRuntimeSnapshot(
          config: config,
          settings: const GameSettingsData(notifyEventShopEnding: true),
          offlineMode: OfflineActivityMode.pauseProgression,
          lastOfflineClaimAtMs: nowMs,
          shopContext: const ShopPlayerContext(playerLevel: 5),
        ),
      );
      await lockedObserver.handleLifecycleState(AppLifecycleState.paused);
      expect(scheduler.scheduled, isEmpty);
    });

    testWidgets(
      'tombol Tes Notifikasi di SettingsOverlay memanggil onTestNotification',
      (tester) async {
        final scheduler = FakeNotificationScheduler();
        var testNotificationCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: SettingsOverlay(
                settings: ValueNotifier(const GameSettingsData()),
                onChanged: (_) {},
                onClose: () {},
                onTestNotification: () async {
                  testNotificationCalled = true;
                  await scheduler.sendTestNotification();
                },
              ),
            ),
          ),
        );

        final btn = find.byKey(const Key('settings_test_notification_btn'));
        expect(btn, findsOneWidget);
        await tester.ensureVisible(btn);
        await tester.tap(btn);
        await tester.pumpAndSettle();

        expect(testNotificationCalled, isTrue);
        expect(scheduler.sendTestNotificationCalls, 1);
      },
    );
  });
}
