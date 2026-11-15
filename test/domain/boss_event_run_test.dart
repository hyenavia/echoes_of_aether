import 'dart:io';

import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
import 'package:echoes_of_aether/data/database/app_database.dart'
    hide ClockState;
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
import 'package:echoes_of_aether/domain/entities/combat_event.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/difficulty_service.dart';
import 'package:echoes_of_aether/domain/services/dungeon_manager.dart';
import 'package:echoes_of_aether/domain/services/encounter_tracker.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/game_clock.dart';
import 'package:echoes_of_aether/domain/services/offline_dungeon_runner.dart';
import 'package:echoes_of_aether/domain/services/offline_progression_service.dart';
import 'package:echoes_of_aether/domain/services/offline_time_calculator.dart';
import 'package:echoes_of_aether/domain/services/period_service.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedClock implements GameClock {
  const _FixedClock(this.nowMs);
  @override
  final int nowMs;
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

DungeonSessionStatus _runHeadlessBossFight({
  required GameConfig config,
  required PreparedBossRun prepared,
  required CombatStats playerStats,
  required int seed,
}) {
  final tracker = EncounterTracker(
    monsterCatalog: config.monsters,
    difficultyService: DifficultyService(config.difficulty),
  );
  final manager = DungeonManager(
    dungeons: config.dungeons,
    encounterTracker: tracker,
    autoCompleteOnEncounter: true,
    clock: const _FixedClock(1763251200000),
  );
  manager.startBossDungeon(
    bossDungeon: prepared.bossDungeon,
    bossMonster: prepared.bossMonster,
    difficultyProfile: prepared.difficultyProfile,
    bossEventId: prepared.boss.id,
    periodKeyAtStart: prepared.periodKey,
    cycleRank: prepared.reference.cycleRank,
    runId: 'boss_sim_$seed',
  );
  final room = manager.activeRoom!;
  final grid = manager.activeGrid!;
  final player = Combatant(
    id: 'player',
    team: Team.player,
    stats: playerStats,
    cell: room.entryPosition,
  );
  final sim = CombatSimulation(
    grid: grid,
    pathfinder: const AStarPathfinder(),
    player: player,
    reviveConfig: config.revive,
    seed: seed,
  );
  tracker.onRoomLoaded(sim, grid: grid);
  manager.activateRoom();
  tracker.onRoomActivated(sim, grid: grid);

  for (var tick = 0; tick < 2000; tick++) {
    sim.tick();
    for (final e in sim.drainEvents()) {
      if (e is EnemyDefeatedEvent) {
        tracker.onEnemyDefeated(e.enemyId, simulation: sim, grid: grid);
      } else if (e is RunEndedEvent) {
        manager.endRun(
          finalStatus: DungeonSessionStatus.failed,
          reason: DungeonEndReason.defeated,
        );
      }
    }
    manager.updatePlayerCell(
      GridPoint(sim.player.x.floor(), sim.player.y.floor()),
    );
    if (manager.session?.isTerminal == true) {
      break;
    }
  }
  return manager.session!.status;
}

void main() {
  group('Boss Event Run, Recovery & Offline Policy', () {
    test('run boss dapat dimulai dan diselesaikan dalam simulasi headless (menang & kalah)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final config = _loadFullConfig();
      const clock = _FixedClock(1763251200000);
      final repo = DriftPlayerSaveRepository(
        db: db,
        config: config,
        clock: clock,
      );
      final coordinator = GameSessionCoordinator(
        repository: repo,
        config: config,
        clock: clock,
      );
      final loaded = await coordinator.loadAndProcessOffline();
      final prepared = coordinator.prepareBossRun(
        period: Period.daily,
        cycleProgress: loaded.cycleProgress,
        dungeonProgresses: loaded.dungeonProgresses,
      );

      // Skenario menang: player kuat mengalahkan boss
      final winStatus = _runHeadlessBossFight(
        config: config,
        prepared: prepared,
        playerStats: const CombatStats(
          maxHp: 2000,
          atk: 80,
          def: 20,
          attackSpeed: 2.0,
          attackRange: 1.5,
          moveSpeed: 4.0,
        ),
        seed: 42,
      );
      expect(winStatus, DungeonSessionStatus.completed);

      // Skenario kalah: player lemah dikalahkan boss sampai runEnded
      final loseStatus = _runHeadlessBossFight(
        config: config,
        prepared: prepared,
        playerStats: const CombatStats(
          maxHp: 20,
          atk: 1,
          def: 0,
          attackSpeed: 1.0,
          attackRange: 1.5,
          moveSpeed: 4.0,
        ),
        seed: 42,
      );
      expect(loseStatus, DungeonSessionStatus.failed);
    });

    test('recovery sesi run boss memulihkan bossEventId & periodKeyAtStart, '
        'dan offline dipaksa Pause saat run boss aktif', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final config = _loadFullConfig();
      const startMs = 1763251200000;
      const resumeMs = startMs + 600000; // +10 menit
      var currentNow = startMs;
      final clock = _FixedClock(startMs);
      final repo = DriftPlayerSaveRepository(
        db: db,
        config: config,
        clock: clock,
      );
      final coordinator = GameSessionCoordinator(
        repository: repo,
        config: config,
        nowMs: () => currentNow,
      );
      final firstBoot = await coordinator.loadAndProcessOffline();

      final tracker = EncounterTracker(monsterCatalog: config.monsters);
      final manager = DungeonManager(
        dungeons: config.dungeons,
        encounterTracker: tracker,
        clock: clock,
      );

      final started = await coordinator.startBossRun(
        period: Period.daily,
        dungeonManager: manager,
        character: firstBoot.character,
        inventory: firstBoot.inventory,
        dungeon: firstBoot.dungeon,
        dungeonProgresses: firstBoot.dungeonProgresses,
        cycleProgress: firstBoot.cycleProgress,
        rewardProcessor: firstBoot.rewardProcessor,
        autoSkillEnabled: firstBoot.session.autoSkillEnabled,
        lastOfflineClaimAtMs: firstBoot.session.lastOfflineClaimAtMs,
        offlineActivity: const OfflineActivitySnapshot(
          mode: OfflineActivityMode.continueDungeon,
          state: OfflineActivityState.configured,
          selectedDungeonId: 'forgotten_forest',
          activeRunId: 'boss_run_recover_1',
        ),
        runId: 'boss_run_recover_1',
      );

      // Simulasi app ditutup selama 10 menit lalu dibuka kembali.
      currentNow = resumeMs;
      final coordinator2 = GameSessionCoordinator(
        repository: repo,
        config: config,
        nowMs: () => currentNow,
      );
      final reboot = await coordinator2.loadAndProcessOffline();

      // Offline dipaksa pauseProgression saat run boss aktif dengan alasan tercatat.
      expect(
        reboot.offlineResult.status,
        OfflineProgressionStatus.noEligibleEncounter,
      );
      expect(reboot.offlineActivity.mode, OfflineActivityMode.pauseProgression);
      expect(
        reboot.offlineActivity.pendingSummary?.failureReason,
        contains('Boss Event'),
      );

      // Sesi boss yang tersimpan masih recoverable dengan bossEventId & periodKeyAtStart.
      final savedSession = reboot.activeDungeonSession;
      expect(savedSession, isNotNull);
      expect(savedSession!.isRecoverable, isTrue);
      expect(savedSession.bossEventId, started.boss.id);
      expect(savedSession.periodKeyAtStart, started.periodKey);

      final recoveryPrepared = coordinator2.prepareBossRecovery(
        savedSession,
        cycleProgress: reboot.cycleProgress,
        dungeonProgresses: reboot.dungeonProgresses,
      );
      expect(recoveryPrepared, isNotNull);

      final tracker2 = EncounterTracker(monsterCatalog: config.monsters);
      final manager2 = DungeonManager(
        dungeons: config.dungeons,
        encounterTracker: tracker2,
        clock: const _FixedClock(resumeMs),
      );
      final restored = manager2.restoreSession(
        savedSession,
        runtimeDungeon: recoveryPrepared!.bossDungeon,
        runtimeBossMonster: recoveryPrepared.bossMonster,
        runtimeDifficultyProfile: recoveryPrepared.difficultyProfile,
      );
      expect(restored, isNotNull);
      expect(restored!.bossEventId, started.boss.id);
      expect(restored.periodKeyAtStart, started.periodKey);
      expect(restored.runId, 'boss_run_recover_1');
    });

    test('Auto Farming menolak dungeon bertipe bossDaily dan bossWeekly', () {
      final config = _loadFullConfig();
      const clock = _FixedClock(1763251200000);
      final coordinator = GameSessionCoordinator(
        repository: DriftPlayerSaveRepository(
          db: AppDatabase(NativeDatabase.memory()),
          config: config,
          clock: clock,
        ),
        config: config,
        clock: clock,
      );
      final dailyPrepared = coordinator.prepareBossRun(
        period: Period.daily,
        cycleProgress: const CycleProgress(),
        dungeonProgresses: const {},
      );
      final weeklyPrepared = coordinator.prepareBossRun(
        period: Period.weekly,
        cycleProgress: const CycleProgress(),
        dungeonProgresses: const {},
      );

      for (final bossDungeon in [
        dailyPrepared.bossDungeon,
        weeklyPrepared.bossDungeon,
      ]) {
        final cfgWithBoss = GameConfig(
          monsters: {
            ...config.monsters,
            dailyPrepared.bossMonster.id: dailyPrepared.bossMonster,
            weeklyPrepared.bossMonster.id: weeklyPrepared.bossMonster,
          },
          revive: config.revive,
          progression: config.progression,
          items: config.items,
          lootTables: config.lootTables,
          damage: config.damage,
          difficulty: config.difficulty,
          farming: config.farming,
          equipment: config.equipment,
          time: config.time,
          claimedRewards: config.claimedRewards,
          currencies: config.currencies,
          dungeons: {...config.dungeons, bossDungeon.id: bossDungeon},
        );
        final character = PlayerCharacter(config: config.progression);
        final inventory = Inventory(definitions: config.items);

        final runnerOutcome = const OfflineDungeonRunner().runBatch(
          OfflineDungeonRunRequest(
            mode: OfflineActivityMode.autoFarming,
            character: character,
            inventory: inventory,
            config: cfgWithBoss,
            rewardProcessor: RewardProcessor(
              character: character,
              inventory: inventory,
              items: config.items,
              lootTables: config.lootTables,
              equipmentFactory: EquipmentFactory(config.equipment),
            ),
            dungeonId: bossDungeon.id,
            dungeonProgress: DungeonProgressSnapshot(
              currentDungeonId: bossDungeon.id,
              clearsCount: 1,
              clearedInCycleRank: 0,
            ),
            timeWindow: const OfflineTimeWindow(
              status: OfflineTimeValidationStatus.valid,
              anchorTimestampMs: 0,
              nowMs: 600000,
              rawElapsed: Duration(minutes: 10),
              effectiveElapsed: Duration(minutes: 10),
              cappedAtMaxDuration: false,
              previouslyProcessedMs: 0,
              remainingBudgetMs: 600000,
              endTimestampMs: 600000,
              eventId: 'offline:0:600000',
              newLastOfflineClaimAtMs: 600000,
            ),
            simulationSeed: 1,
          ),
        );
        expect(runnerOutcome.stopReason, OfflineDungeonStopReason.invalidSetup);
        expect(runnerOutcome.failureReason, contains('Boss Event'));
      }
    });
  });
}
