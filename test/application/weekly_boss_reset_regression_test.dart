import 'dart:io';

import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
import 'package:echoes_of_aether/data/database/app_database.dart'
    hide ClockState, PeriodicQuestState;
import 'package:echoes_of_aether/data/models/boss_events_config_parser.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/core/errors/config_exception.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/domain/entities/boss_event.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/services/boss_quest_service.dart';
import 'package:echoes_of_aether/domain/services/currency_service.dart';
import 'package:echoes_of_aether/domain/services/difficulty_service.dart';
import 'package:echoes_of_aether/domain/services/dungeon_manager.dart';
import 'package:echoes_of_aether/domain/services/encounter_tracker.dart';
import 'package:echoes_of_aether/domain/services/game_clock.dart';
import 'package:echoes_of_aether/domain/services/period_service.dart';
import 'package:echoes_of_aether/features/dungeon/boss_events_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MutableClock implements GameClock {
  _MutableClock(this.nowMs);

  @override
  int nowMs;
}

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadFullConfig() {
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
  );
}

void main() {
  late GameConfig config;

  setUpAll(() {
    config = _loadFullConfig();
  });

  group('Regresi Integrasi Weekly Boss & Weekly Quest Reset', () {
    test('a,b,c,f: Weekly Quest tetap Selesai melewati reset harian (Selasa 00:00), terbuka Senin 00:00 berikutnya, kemenangan kedua minggu sama tanpa hadiah, Daily buka tiap hari, claimId & DB pakai tanggal Senin', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final clock = _MutableClock(
        DateTime(2026, 11, 16, 10, 0).millisecondsSinceEpoch, // Senin 10:00
      );
      final repo = DriftPlayerSaveRepository(
        db: db,
        config: config,
        clock: clock,
      );
      final periodService = PeriodService(config: config.time);

      Future<
        ({
          GameSessionCoordinator coordinator,
          LoadedGameSession boot,
          CurrencyService currencies,
          BossQuestService quests,
          DungeonManager manager,
        })
      >
      bootAt(DateTime localTime) async {
        clock.nowMs = localTime.millisecondsSinceEpoch;
        final coordinator = GameSessionCoordinator(
          repository: repo,
          config: config,
          nowMs: () => clock.nowMs,
        );
        final boot = await coordinator.loadAndProcessOffline();
        final currencies = CurrencyService(
          definitions: config.currencies,
          initialBalances: boot.currencies,
          claimedIds: boot.rewardProcessor.claimedEventIds,
        );
        final quests = BossQuestService(
          initialStates: boot.periodicQuestStates,
        );
        final manager = DungeonManager(
          dungeons: config.dungeons,
          encounterTracker: EncounterTracker(
            monsterCatalog: config.monsters,
            difficultyService: DifficultyService(config.difficulty),
          ),
          clock: clock,
          difficultyService: DifficultyService(config.difficulty),
        );
        return (
          coordinator: coordinator,
          boot: boot,
          currencies: currencies,
          quests: quests,
          manager: manager,
        );
      }

      // 1. Senin 2026-11-16 10:00 -> mulai & menangkan Weekly Boss + Daily Boss.
      var session = await bootAt(DateTime(2026, 11, 16, 10, 0));
      final mondayKey = '2026-11-16';
      expect(periodService.keyFor(Period.weekly, clock.nowMs), mondayKey);
      expect(periodService.keyFor(Period.daily, clock.nowMs), '2026-11-16');

      final weeklyPrep1 = await session.coordinator.startBossRun(
        period: Period.weekly,
        dungeonManager: session.manager,
        character: session.boot.character,
        inventory: session.boot.inventory,
        dungeon: session.boot.dungeon,
        dungeonProgresses: session.boot.dungeonProgresses,
        cycleProgress: session.boot.cycleProgress,
        rewardProcessor: session.boot.rewardProcessor,
        autoSkillEnabled: session.boot.session.autoSkillEnabled,
        lastOfflineClaimAtMs: session.boot.session.lastOfflineClaimAtMs,
        currencyService: session.currencies,
        periodicQuestStates: session.quests.toSnapshot(),
      );
      expect(weeklyPrep1.periodKey, mondayKey);

      final weeklyWin1 = await session.coordinator.settleBossQuestVictory(
        period: Period.weekly,
        periodKeyAtStart: weeklyPrep1.periodKey,
        difficultyProfile: weeklyPrep1.difficultyProfile,
        character: session.boot.character,
        inventory: session.boot.inventory,
        dungeon: session.boot.dungeon,
        dungeonProgresses: session.boot.dungeonProgresses,
        cycleProgress: session.boot.cycleProgress,
        rewardProcessor: session.boot.rewardProcessor,
        currencyService: session.currencies,
        bossQuestService: session.quests,
        autoSkillEnabled: session.boot.session.autoSkillEnabled,
        lastOfflineClaimAtMs: session.boot.session.lastOfflineClaimAtMs,
      );
      expect(weeklyWin1.rewardGranted, isTrue);
      expect(weeklyWin1.claimId, 'bossquest:weekly_boss:$mondayKey');
      expect(
        session.quests.isCompleted(
          config.bossEvents!.weekly.questId,
          mondayKey,
        ),
        isTrue,
      );

      final shardAfterWeekly1 = session.currencies.balance('aether_shard');
      expect(
        shardAfterWeekly1,
        config.bossEvents!.weekly.reward.currency['aether_shard'],
      );

      session.manager.exitToTown();
      final dailyPrepMon = await session.coordinator.startBossRun(
        period: Period.daily,
        dungeonManager: session.manager,
        character: session.boot.character,
        inventory: session.boot.inventory,
        dungeon: session.boot.dungeon,
        dungeonProgresses: session.boot.dungeonProgresses,
        cycleProgress: session.boot.cycleProgress,
        rewardProcessor: session.boot.rewardProcessor,
        autoSkillEnabled: session.boot.session.autoSkillEnabled,
        lastOfflineClaimAtMs: session.boot.session.lastOfflineClaimAtMs,
        currencyService: session.currencies,
        periodicQuestStates: session.quests.toSnapshot(),
      );
      final dailyWinMon = await session.coordinator.settleBossQuestVictory(
        period: Period.daily,
        periodKeyAtStart: dailyPrepMon.periodKey,
        difficultyProfile: dailyPrepMon.difficultyProfile,
        character: session.boot.character,
        inventory: session.boot.inventory,
        dungeon: session.boot.dungeon,
        dungeonProgresses: session.boot.dungeonProgresses,
        cycleProgress: session.boot.cycleProgress,
        rewardProcessor: session.boot.rewardProcessor,
        currencyService: session.currencies,
        bossQuestService: session.quests,
        autoSkillEnabled: session.boot.session.autoSkillEnabled,
        lastOfflineClaimAtMs: session.boot.session.lastOfflineClaimAtMs,
      );
      expect(dailyWinMon.rewardGranted, isTrue);
      expect(dailyWinMon.claimId, 'bossquest:daily_boss:2026-11-16');

      // Verifikasi (f): baris PeriodicQuestStates & ClaimedRewards di Drift memakai tanggal Senin.
      final storedRows = await db.select(db.periodicQuestStates).get();
      final storedWeekly = storedRows.where(
        (r) => r.questId == config.bossEvents!.weekly.questId,
      );
      expect(storedWeekly.map((r) => r.periodKey).toList(), [mondayKey]);
      final storedClaims = await db.select(db.claimedRewards).get();
      expect(
        storedClaims.map((r) => r.eventId),
        contains('bossquest:weekly_boss:$mondayKey'),
      );

      // 2. Lewati reset HARIAN -> Selasa 2026-11-17 00:05.
      session = await bootAt(DateTime(2026, 11, 17, 0, 5));
      final tuesdayWeeklyKey = periodService.keyFor(Period.weekly, clock.nowMs);
      final tuesdayDailyKey = periodService.keyFor(Period.daily, clock.nowMs);
      expect(tuesdayWeeklyKey, mondayKey);
      expect(tuesdayDailyKey, '2026-11-17');

      // Verifikasi (a): Weekly Quest MASIH Selesai melewati Selasa 00:00.
      expect(
        session.quests.isCompleted(
          config.bossEvents!.weekly.questId,
          tuesdayWeeklyKey,
        ),
        isTrue,
      );
      // Verifikasi (b): Daily Quest sudah terbuka lagi (Belum selesai).
      expect(
        session.quests.isCompleted(
          config.bossEvents!.daily.questId,
          tuesdayDailyKey,
        ),
        isFalse,
      );

      // Verifikasi (c): Kemenangan Weekly Boss kedua di minggu yang sama (Rabu 12:00)
      // tidak memberi hadiah sama sekali.
      session = await bootAt(DateTime(2026, 11, 18, 12, 0));
      final shardBeforeWeekly2 = session.currencies.balance('aether_shard');
      final goldBeforeWeekly2 = session.boot.character.gold;
      final expBeforeWeekly2 = session.boot.character.currentExp;
      final lvlBeforeWeekly2 = session.boot.character.level;

      final weeklyPrep2 = await session.coordinator.startBossRun(
        period: Period.weekly,
        dungeonManager: session.manager,
        character: session.boot.character,
        inventory: session.boot.inventory,
        dungeon: session.boot.dungeon,
        dungeonProgresses: session.boot.dungeonProgresses,
        cycleProgress: session.boot.cycleProgress,
        rewardProcessor: session.boot.rewardProcessor,
        autoSkillEnabled: session.boot.session.autoSkillEnabled,
        lastOfflineClaimAtMs: session.boot.session.lastOfflineClaimAtMs,
        currencyService: session.currencies,
        periodicQuestStates: session.quests.toSnapshot(),
      );
      final weeklyWin2 = await session.coordinator.settleBossQuestVictory(
        period: Period.weekly,
        periodKeyAtStart: weeklyPrep2.periodKey,
        difficultyProfile: weeklyPrep2.difficultyProfile,
        character: session.boot.character,
        inventory: session.boot.inventory,
        dungeon: session.boot.dungeon,
        dungeonProgresses: session.boot.dungeonProgresses,
        cycleProgress: session.boot.cycleProgress,
        rewardProcessor: session.boot.rewardProcessor,
        currencyService: session.currencies,
        bossQuestService: session.quests,
        autoSkillEnabled: session.boot.session.autoSkillEnabled,
        lastOfflineClaimAtMs: session.boot.session.lastOfflineClaimAtMs,
      );
      expect(weeklyWin2.rewardGranted, isFalse);
      expect(
        weeklyWin2.noRewardReason,
        BossQuestNoRewardReason.alreadyCompleted,
      );
      expect(session.currencies.balance('aether_shard'), shardBeforeWeekly2);
      expect(session.boot.character.gold, goldBeforeWeekly2);
      expect(session.boot.character.currentExp, expBeforeWeekly2);
      expect(session.boot.character.level, lvlBeforeWeekly2);

      // Daily Quest pada Rabu harus tetap bisa diklaim.
      session.manager.exitToTown();
      final dailyPrepWed = await session.coordinator.startBossRun(
        period: Period.daily,
        dungeonManager: session.manager,
        character: session.boot.character,
        inventory: session.boot.inventory,
        dungeon: session.boot.dungeon,
        dungeonProgresses: session.boot.dungeonProgresses,
        cycleProgress: session.boot.cycleProgress,
        rewardProcessor: session.boot.rewardProcessor,
        autoSkillEnabled: session.boot.session.autoSkillEnabled,
        lastOfflineClaimAtMs: session.boot.session.lastOfflineClaimAtMs,
        currencyService: session.currencies,
        periodicQuestStates: session.quests.toSnapshot(),
      );
      final dailyWinWed = await session.coordinator.settleBossQuestVictory(
        period: Period.daily,
        periodKeyAtStart: dailyPrepWed.periodKey,
        difficultyProfile: dailyPrepWed.difficultyProfile,
        character: session.boot.character,
        inventory: session.boot.inventory,
        dungeon: session.boot.dungeon,
        dungeonProgresses: session.boot.dungeonProgresses,
        cycleProgress: session.boot.cycleProgress,
        rewardProcessor: session.boot.rewardProcessor,
        currencyService: session.currencies,
        bossQuestService: session.quests,
        autoSkillEnabled: session.boot.session.autoSkillEnabled,
        lastOfflineClaimAtMs: session.boot.session.lastOfflineClaimAtMs,
      );
      expect(dailyWinWed.rewardGranted, isTrue);

      // Minggu 23:59 -> masih minggu 2026-11-16 -> Weekly masih Selesai.
      session = await bootAt(DateTime(2026, 11, 22, 23, 59));
      expect(periodService.keyFor(Period.weekly, clock.nowMs), mondayKey);
      expect(
        session.quests.isCompleted(
          config.bossEvents!.weekly.questId,
          mondayKey,
        ),
        isTrue,
      );

      // 3. Senin berikutnya 2026-11-23 00:00 -> Weekly Quest terbuka lagi dan dapat diklaim.
      session = await bootAt(DateTime(2026, 11, 23, 0, 0));
      const nextMondayKey = '2026-11-23';
      expect(periodService.keyFor(Period.weekly, clock.nowMs), nextMondayKey);
      expect(
        session.quests.isCompleted(
          config.bossEvents!.weekly.questId,
          nextMondayKey,
        ),
        isFalse,
      );

      final weeklyPrepNextWeek = await session.coordinator.startBossRun(
        period: Period.weekly,
        dungeonManager: session.manager,
        character: session.boot.character,
        inventory: session.boot.inventory,
        dungeon: session.boot.dungeon,
        dungeonProgresses: session.boot.dungeonProgresses,
        cycleProgress: session.boot.cycleProgress,
        rewardProcessor: session.boot.rewardProcessor,
        autoSkillEnabled: session.boot.session.autoSkillEnabled,
        lastOfflineClaimAtMs: session.boot.session.lastOfflineClaimAtMs,
        currencyService: session.currencies,
        periodicQuestStates: session.quests.toSnapshot(),
      );
      final weeklyWinNextWeek = await session.coordinator
          .settleBossQuestVictory(
            period: Period.weekly,
            periodKeyAtStart: weeklyPrepNextWeek.periodKey,
            difficultyProfile: weeklyPrepNextWeek.difficultyProfile,
            character: session.boot.character,
            inventory: session.boot.inventory,
            dungeon: session.boot.dungeon,
            dungeonProgresses: session.boot.dungeonProgresses,
            cycleProgress: session.boot.cycleProgress,
            rewardProcessor: session.boot.rewardProcessor,
            currencyService: session.currencies,
            bossQuestService: session.quests,
            autoSkillEnabled: session.boot.session.autoSkillEnabled,
            lastOfflineClaimAtMs: session.boot.session.lastOfflineClaimAtMs,
          );
      expect(weeklyWinNextWeek.rewardGranted, isTrue);
      expect(weeklyWinNextWeek.claimId, 'bossquest:weekly_boss:$nextMondayKey');
    });

    test('e: Rotasi Weekly Boss berganti per minggu (tetap sepanjang Senin-Minggu) sedangkan Daily Boss berganti per hari', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final clock = _MutableClock(0);
      final repo = DriftPlayerSaveRepository(
        db: db,
        config: config,
        clock: clock,
      );

      Future<(String dailyBossId, String weeklyBossId)> bossIdsAt(
        DateTime dt,
      ) async {
        clock.nowMs = dt.millisecondsSinceEpoch;
        final coordinator = GameSessionCoordinator(
          repository: repo,
          config: config,
          nowMs: () => clock.nowMs,
        );
        final boot = await coordinator.loadAndProcessOffline();
        final daily = coordinator.prepareBossRun(
          period: Period.daily,
          cycleProgress: boot.cycleProgress,
          dungeonProgresses: boot.dungeonProgresses,
        );
        final weekly = coordinator.prepareBossRun(
          period: Period.weekly,
          cycleProgress: boot.cycleProgress,
          dungeonProgresses: boot.dungeonProgresses,
        );
        return (daily.boss.id, weekly.boss.id);
      }

      final (monD, monW) = await bossIdsAt(DateTime(2026, 11, 16, 10, 0));
      final (tueD, tueW) = await bossIdsAt(DateTime(2026, 11, 17, 10, 0));
      final (wedD, wedW) = await bossIdsAt(DateTime(2026, 11, 18, 10, 0));
      final (sunD, sunW) = await bossIdsAt(DateTime(2026, 11, 22, 23, 0));
      final (nextMonD, nextMonW) = await bossIdsAt(
        DateTime(2026, 11, 23, 0, 5),
      );

      // Daily berganti setiap hari (pool berisi 3 boss).
      expect({monD, tueD, wedD}.length, 3);
      expect(sunD, isNot(equals(nextMonD)));

      // Weekly tetap sama dari Senin s.d. Minggu, baru berganti pada Senin berikutnya.
      expect(tueW, monW);
      expect(wedW, monW);
      expect(sunW, monW);
      expect(nextMonW, isNot(equals(monW)));
    });

    testWidgets(
      'd: Hitung mundur kartu Weekly = waktu ke Senin 00:00, Daily = waktu ke 00:00 berikutnya (pada Rabu berbeda; pada Minggu keduanya Senin 00:00)',
      (tester) async {
        final periodService = PeriodService(config: config.time);

        // Rabu 2026-11-18 12:00: Daily -> Kamis 00:00 (12:00:00); Weekly -> Senin 2026-11-23 00:00 (4 hari 12 jam -> 4h 12:00:00).
        final wedNoon = DateTime(2026, 11, 18, 12, 0).millisecondsSinceEpoch;
        final dailyRemainingWed = Duration(
          milliseconds:
              periodService.nextResetMs(Period.daily, wedNoon) - wedNoon,
        );
        final weeklyRemainingWed = Duration(
          milliseconds:
              periodService.nextResetMs(Period.weekly, wedNoon) - wedNoon,
        );
        expect(dailyRemainingWed, const Duration(hours: 12));
        expect(weeklyRemainingWed, const Duration(days: 4, hours: 12));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BossEventsOverlay(
                daily: BossEventCardData(
                  periodKeyId: 'daily',
                  periodLabel: 'Daily Boss',
                  bossName: 'Crypt Sentinel',
                  referenceDungeonName: 'Forgotten Forest',
                  recommendedLevel: 1,
                  isCompleted: false,
                  remainingToReset: dailyRemainingWed,
                  rewardSummary: '10 Aether Shard',
                  onFight: () {},
                ),
                weekly: BossEventCardData(
                  periodKeyId: 'weekly',
                  periodLabel: 'Weekly Boss',
                  bossName: 'Crimson Sovereign',
                  referenceDungeonName: 'Forgotten Forest',
                  recommendedLevel: 1,
                  isCompleted: true,
                  remainingToReset: weeklyRemainingWed,
                  rewardSummary: '50 Aether Shard',
                  onFight: () {},
                ),
                onClose: () {},
              ),
            ),
          ),
        );

        expect(find.text('Reset dalam: 12:00:00'), findsOneWidget);
        expect(find.text('Reset dalam: 4h 12:00:00'), findsOneWidget);

        // Pada hari Minggu (2026-11-15 06:45), besok 00:00 adalah Senin 2026-11-16 00:00,
        // sehingga Daily dan Weekly memang bertepatan pada batas reset yang sama.
        final sunMorning = DateTime(2026, 11, 15, 6, 45).millisecondsSinceEpoch;
        expect(
          periodService.nextResetMs(Period.weekly, sunMorning),
          periodService.nextResetMs(Period.daily, sunMorning),
        );
      },
    );

    test('single source of truth Period pada BossEventsConfig, recovery sesi weekly, jam mundur UI, dan validasi config', () async {
      final bossEvents = config.bossEvents!;
      expect(bossEvents.daily.period, Period.daily);
      expect(bossEvents.weekly.period, Period.weekly);
      expect(bossEvents.tierFor(Period.weekly).questId, 'weekly_boss');
      expect(bossEvents.periodForQuestId('weekly_boss'), Period.weekly);
      expect(bossEvents.periodForQuestId('daily_boss'), Period.daily);
      expect(
        bossEvents.periodForBossId('weekly_crimson_sovereign'),
        Period.weekly,
      );
      expect(
        bossEvents.periodForSession(
          dungeon: null,
          bossEventId: 'weekly_crimson_sovereign',
          dungeonId: 'boss_weekly:weekly_crimson_sovereign',
        ),
        Period.weekly,
      );
      expect(
        bossEvents.periodForSession(
          dungeon: null,
          bossEventId: null,
          dungeonId: null,
        ),
        isNull,
      );

      // Recovery sesi Weekly Boss & effectiveClockMs saat jam perangkat dimundurkan.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final wed = DateTime(2026, 11, 18, 12, 0).millisecondsSinceEpoch;
      final clock = _MutableClock(wed);
      final repo = DriftPlayerSaveRepository(
        db: db,
        config: config,
        clock: clock,
      );
      final coordinator = GameSessionCoordinator(
        repository: repo,
        config: config,
        nowMs: () => clock.nowMs,
      );
      final boot = await coordinator.loadAndProcessOffline();
      final recovered = coordinator.prepareBossRecovery(
        const ActiveDungeonSessionSnapshot(
          runId: 'run_weekly_recover',
          dungeonId: 'boss_weekly:weekly_crimson_sovereign',
          currentRoomId: 'boss_arena',
          currentRoomIndex: 0,
          status: DungeonSessionStatus.inProgress,
          bossEventId: 'weekly_crimson_sovereign',
          periodKeyAtStart: '2026-11-16',
        ),
        cycleProgress: boot.cycleProgress,
        dungeonProgresses: boot.dungeonProgresses,
      );
      expect(recovered, isNotNull);
      expect(recovered!.period, Period.weekly);
      expect(recovered.bossDungeon.kind, DungeonKind.bossWeekly);

      clock.nowMs = DateTime(2026, 11, 16, 12, 0).millisecondsSinceEpoch;
      expect(coordinator.effectiveClockMs, wed);

      // Validator menolak daily & weekly yang memakai quest_id sama.
      final colliding = BossEventsConfig(
        daily: bossEvents.daily,
        weekly: BossTierConfig(
          period: Period.weekly,
          questId: bossEvents.daily.questId,
          powerFactor: bossEvents.weekly.powerFactor,
          reward: bossEvents.weekly.reward,
          pool: bossEvents.weekly.pool,
        ),
        arenaMapRef: bossEvents.arenaMapRef,
      );
      expect(
        () => const GameConfigValidator().validate(
          GameConfig(
            monsters: config.monsters,
            revive: config.revive,
            progression: config.progression,
            items: config.items,
            lootTables: config.lootTables,
            currencies: config.currencies,
            mapLayouts: config.mapLayouts,
            dungeons: config.dungeons,
            bossEvents: colliding,
          ),
        ),
        throwsA(isA<ConfigException>()),
      );
    });
  });
}
