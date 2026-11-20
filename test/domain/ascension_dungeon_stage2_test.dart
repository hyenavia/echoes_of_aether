import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/combat_event.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/player_status.dart';
import 'package:echoes_of_aether/domain/services/ascension_service.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/difficulty_service.dart';
import 'package:echoes_of_aether/domain/services/dungeon_manager.dart';
import 'package:echoes_of_aether/domain/services/dungeon_progression_service.dart';
import 'package:echoes_of_aether/domain/services/dungeon_reward_settlement_service.dart';
import 'package:echoes_of_aether/domain/services/encounter_tracker.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/offline_dungeon_runner.dart';
import 'package:echoes_of_aether/domain/services/offline_progression_service.dart';
import 'package:echoes_of_aether/domain/services/offline_time_calculator.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealConfig() {
  const parser = GameConfigParser();
  final settings = _readAsset('game_config.json');
  final difficulty = parser.parseDifficulty(settings);
  final config = GameConfig(
    monsters: const MonsterConfigParser().parse(_readAsset('monsters.json')),
    damage: parser.parseDamage(settings),
    difficulty: difficulty,
    farming: parser.parseFarming(settings),
    revive: parser.parseRevive(settings),
    progression: parser.parseProgression(settings),
    equipment: parser.parseEquipment(settings),
    dungeonCompletion: parser.parseDungeonCompletion(settings),
    items: const ItemConfigParser().parse(_readAsset('items.json')),
    lootTables: const LootConfigParser().parse(_readAsset('loot_tables.json')),
    skills: const SkillConfigParser().parse(_readAsset('skills.json')),
    specializations: const SpecializationConfigParser().parse(
      _readAsset('specializations.json'),
    ),
    dungeons: const DungeonConfigParser().parse(
      _readAsset('dungeons.json'),
      ascensionMultiplier: difficulty.ascensionMultiplier,
    ),
  );
  const GameConfigValidator().validate(config);
  return config;
}

void main() {
  late GameConfig config;

  setUpAll(() {
    config = _loadRealConfig();
  });

  group('M9 Stage 2 — Data & Scaling Ascension Dungeon', () {
    test(
      'ascension_sanctum dan ascension_clear_loot valid dengan scale D5 * 1.35',
      () {
        final d5 = config.dungeons['aether_sanctum']!;
        final asc = config.dungeons['ascension_sanctum']!;

        expect(asc.kind, DungeonKind.ascension);
        expect(asc.isAscension, true);
        expect(asc.order, 7);
        expect(asc.baseDungeonId, 'aether_sanctum');
        expect(asc.unlockRequiresDungeonId, 'aether_sanctum');
        expect(asc.recommendedLevel, 49);
        expect(
          asc.difficultyScale,
          closeTo(
            d5.difficultyScale * config.difficulty.ascensionMultiplier,
            1e-9,
          ),
        );
        expect(asc.difficultyScale, closeTo(6.834375, 1e-9));
        expect(asc.roomOrder, d5.roomOrder);
        for (final roomId in asc.roomOrder) {
          expect(asc.roomById(roomId)?.dungeonId, 'ascension_sanctum');
        }

        final reward = asc.completionReward!;
        expect(reward.expReward, 800);
        expect(reward.goldReward, 400);
        expect(reward.lootTableId, 'ascension_clear_loot');

        final lootTable = config.lootTables['ascension_clear_loot']!;
        expect(lootTable.entries, isNotEmpty);
        for (final entry in lootTable.entries) {
          expect(config.items.containsKey(entry.itemId), true);
          expect(entry.chance, greaterThan(0));
          expect(entry.chance, lessThanOrEqualTo(1));
        }
      },
    );

    test('canEnterAscension dan isUnlocked mensyaratkan D5 selesai di siklus aktif + level rekomendasi mengikuti rank', () {
      final asc = config.dungeons['ascension_sanctum']!;
      const progression = DungeonProgressionService();
      const ascensionService = AscensionService();

      final emptyProgress = <String, DungeonProgressSnapshot>{
        'forgotten_forest': const DungeonProgressSnapshot(
          currentDungeonId: 'forgotten_forest',
          clearsCount: 1,
          clearedInCycleRank: 0,
        ),
      };
      expect(
        ascensionService.canEnterAscension(
          dungeons: config.dungeons.values,
          cycleProgress: const CycleProgress(ascensionRank: 0),
          dungeonProgresses: emptyProgress,
        ),
        false,
      );
      expect(
        progression.isUnlocked(
          asc,
          const CycleProgress(ascensionRank: 0),
          emptyProgress,
          allDungeons: config.dungeons.values,
        ),
        false,
      );

      // Rank 1, D5 baru pernah selesai di Rank 0.
      final staleCycleProgress = <String, DungeonProgressSnapshot>{
        'aether_sanctum': const DungeonProgressSnapshot(
          currentDungeonId: 'aether_sanctum',
          clearsCount: 1,
          clearedInCycleRank: 0,
        ),
      };
      expect(
        ascensionService.canEnterAscension(
          dungeons: config.dungeons.values,
          cycleProgress: const CycleProgress(ascensionRank: 1),
          dungeonProgresses: staleCycleProgress,
        ),
        false,
      );
      expect(
        progression.isUnlocked(
          asc,
          const CycleProgress(ascensionRank: 1),
          staleCycleProgress,
          allDungeons: config.dungeons.values,
        ),
        false,
      );

      // Rank 1, D5 sudah selesai di Rank 1.
      final unlockedProgress = <String, DungeonProgressSnapshot>{
        'aether_sanctum': const DungeonProgressSnapshot(
          currentDungeonId: 'aether_sanctum',
          clearsCount: 2,
          clearedInCycleRank: 1,
        ),
      };
      expect(
        ascensionService.canEnterAscension(
          dungeons: config.dungeons.values,
          cycleProgress: const CycleProgress(ascensionRank: 1),
          dungeonProgresses: unlockedProgress,
        ),
        true,
      );
      expect(
        progression.isUnlocked(
          asc,
          const CycleProgress(ascensionRank: 1),
          unlockedProgress,
          allDungeons: config.dungeons.values,
        ),
        true,
      );

      expect(progression.recommendedLevel(asc, 0), 49);
      expect(progression.recommendedLevel(asc, 1), 56);
      expect(progression.recommendedLevel(asc, 2), 61);
    });

    test('Option B + Hard Lock: cycleLevelStep linear, D1 Rank 0 min Lv 1, dan blokir level kurang', () {
      final optBProgression = DungeonProgressionService(config.difficulty);
      final optBAscension = AscensionService(
        progressionService: optBProgression,
      );
      final d1 = config.dungeons['forgotten_forest']!;
      final d2 = config.dungeons['crystal_cavern']!;
      final asc = config.dungeons['ascension_sanctum']!;

      // Rank 0: D1 tetap boleh masuk di Lv 1 meski recommendedLevel = 5.
      expect(optBProgression.recommendedLevel(d1, 0), 5);
      expect(optBProgression.requiredLevel(d1, 0), 1);
      expect(optBProgression.meetsLevelRequirement(d1, 0, 1), isTrue);

      // Rank 0: D2..Asc mewajibkan level >= recommendedLevel.
      expect(optBProgression.requiredLevel(d2, 0), 8);
      expect(optBProgression.meetsLevelRequirement(d2, 0, 7), isFalse);
      expect(optBProgression.meetsLevelRequirement(d2, 0, 8), isTrue);
      expect(optBProgression.requiredLevel(asc, 0), 49);
      expect(optBProgression.meetsLevelRequirement(asc, 0, 48), isFalse);
      expect(optBProgression.meetsLevelRequirement(asc, 0, 49), isTrue);

      // Rank 1: D1 tetap min Lv 1 (Opsi 3), sedangkan D2..Asc naik +44 & Hard Lock.
      expect(optBProgression.recommendedLevel(d1, 1), 49);
      expect(optBProgression.requiredLevel(d1, 1), 1);
      expect(optBProgression.meetsLevelRequirement(d1, 1, 44), isTrue);
      expect(optBProgression.recommendedLevel(d2, 1), 52);
      expect(optBProgression.requiredLevel(d2, 1), 52);
      expect(optBProgression.meetsLevelRequirement(d2, 1, 51), isFalse);
      expect(optBProgression.meetsLevelRequirement(d2, 1, 52), isTrue);
      expect(optBProgression.recommendedLevel(asc, 1), 93);
      expect(optBProgression.requiredLevel(asc, 1), 93);

      // Rank Switcher: saat turun ke Rank 0 (ascensionRank: 0, highest: 1),
      // semua dungeon normal Rank 0 tetap dianggap clear pada siklus tsb &
      // menyelesaikan Ascension di Rank 0 tidak menaikkan highestAscensionRank.
      const switchedDown = CycleProgress(
        ascensionRank: 0,
        highestAscensionRank: 1,
        lastNormalDungeonId: 'aether_sanctum',
      );
      expect(
        optBProgression.isUnlocked(
          config.dungeons['aether_sanctum']!,
          switchedDown,
          const {},
          allDungeons: config.dungeons.values,
          playerLevel: 44,
        ),
        isTrue,
      );
      final lowerAscResult = optBAscension.complete(
        runId: 'lower_rank_asc_1',
        dungeons: config.dungeons.values,
        cycleProgress: switchedDown,
        dungeonProgresses: const {
          'forgotten_forest': DungeonProgressSnapshot(
            currentDungeonId: 'forgotten_forest',
            clearsCount: 2,
            clearedInCycleRank: 1,
          ),
        },
      );
      expect(lowerAscResult.rankIncremented, isFalse);
      expect(lowerAscResult.cycleProgress.ascensionRank, 0);
      expect(lowerAscResult.cycleProgress.highestAscensionRank, 1);
      expect(
        lowerAscResult
            .dungeonProgresses['forgotten_forest']
            ?.clearedInCycleRank,
        1,
      );

      final d5DoneRank0 = <String, DungeonProgressSnapshot>{
        'aether_sanctum': const DungeonProgressSnapshot(
          currentDungeonId: 'aether_sanctum',
          clearsCount: 1,
          clearedInCycleRank: 0,
        ),
      };
      expect(
        optBAscension.canEnterAscension(
          dungeons: config.dungeons.values,
          cycleProgress: const CycleProgress(ascensionRank: 0),
          dungeonProgresses: d5DoneRank0,
          playerLevel: 48,
        ),
        isFalse,
      );
      expect(
        optBAscension.canEnterAscension(
          dungeons: config.dungeons.values,
          cycleProgress: const CycleProgress(ascensionRank: 0),
          dungeonProgresses: d5DoneRank0,
          playerLevel: 49,
        ),
        isTrue,
      );
    });

    test('scaling musuh dan reward Ascension mengikuti D5 * 1.35 * C(rank) pada jalur online', () {
      final asc = config.dungeons['ascension_sanctum']!;
      final diffService = DifficultyService(config.difficulty);

      for (final rank in [0, 1]) {
        final profile = diffService.profileFor(asc, rank);
        final expectedCycle = 1.0 + config.difficulty.cyclePerRank * rank;
        expect(profile.multiplier, closeTo(6.834375 * expectedCycle, 1e-9));

        final char = PlayerCharacter(
          config: config.progression,
          progress: const PlayerProgress(level: 50),
          skillCatalog: config.skills,
          specializationConfig: config.specializations,
          initialSpecializationId: 'vanguard',
        );
        final inv = Inventory(definitions: config.items);
        final processor = RewardProcessor(
          character: char,
          inventory: inv,
          items: config.items,
          lootTables: config.lootTables,
          equipmentFactory: EquipmentFactory(config.equipment),
        );
        final tracker = EncounterTracker(monsterCatalog: config.monsters);
        final manager = DungeonManager(
          dungeons: config.dungeons,
          encounterTracker: tracker,
          difficultyService: diffService,
        );

        final session = manager.startDungeon(
          'ascension_sanctum',
          runId: 'asc_scale_r$rank',
          cycleRank: rank,
        );
        expect(session.cycleRank, rank);
        expect(manager.activeDifficultyProfile.multiplier, profile.multiplier);

        final startRoom = manager.activeRoom!;
        final sim = CombatSimulation(
          grid: manager.activeGrid!,
          pathfinder: const AStarPathfinder(),
          player: Combatant(
            id: 'player',
            team: Team.player,
            stats: char.stats,
            cell: startRoom.entryPosition,
          ),
          reviveConfig: config.revive,
          damageCalculator: config.damage.createCalculator(),
          seed: 9,
        );
        tracker.onRoomLoaded(sim, grid: sim.grid);
        manager.activateRoom();
        final spawned = tracker.onRoomActivated(sim, grid: sim.grid);
        final firstSpawn = spawned.first;
        final baseMonster = config.monsters[firstSpawn.monsterId]!;
        final enemy = sim.enemies.firstWhere((e) => e.id == firstSpawn.enemyId);
        final expectedStats = diffService.scaleMonsterStats(
          baseMonster.stats,
          profile,
        );
        expect(enemy.stats.maxHp, expectedStats.maxHp);
        expect(enemy.stats.atk, expectedStats.atk);
        expect(enemy.stats.def, expectedStats.def);

        final killGranted = processor.processEnemyDefeated(
          eventId: 'asc_kill_${rank}_${firstSpawn.enemyId}',
          definition: baseMonster,
          random: math.Random(1),
          difficultyProfile: manager.activeDifficultyProfile,
          difficultyService: diffService,
        );
        expect(
          killGranted.expGranted,
          diffService.scaleExp(baseMonster.expReward, profile),
        );
        expect(
          killGranted.goldGranted,
          diffService.scaleGold(baseMonster.goldReward, profile),
        );

        const settlement = DungeonRewardSettlementService();
        final finalTracker = EncounterTracker(monsterCatalog: config.monsters);
        final finalManager = DungeonManager(
          dungeons: config.dungeons,
          encounterTracker: finalTracker,
          difficultyService: diffService,
        );
        finalManager.restoreSession(
          ActiveDungeonSessionSnapshot(
            runId: 'asc_settle_r$rank',
            dungeonId: 'ascension_sanctum',
            currentRoomId: asc.roomOrder.last,
            currentRoomIndex: asc.roomOrder.length - 1,
            status: DungeonSessionStatus.inProgress,
            clearedRoomIds: asc.roomOrder
                .take(asc.roomOrder.length - 1)
                .toSet(),
            cycleRank: rank,
          ),
        );
        DungeonEndedEvent? ended;
        finalManager.addListener((event) {
          if (event is DungeonEndedEvent) {
            ended = event;
          }
        });
        final bossRoom = finalManager.activeRoom!;
        final bossSim = CombatSimulation(
          grid: finalManager.activeGrid!,
          pathfinder: const AStarPathfinder(),
          player: Combatant(
            id: 'player_boss',
            team: Team.player,
            stats: const CombatStats(
              maxHp: 999999,
              atk: 999999,
              def: 999999,
              attackSpeed: 5,
              moveSpeed: 10,
              attackRange: 10,
            ),
            cell: bossRoom.entryPosition,
          ),
          reviveConfig: config.revive,
          damageCalculator: config.damage.createCalculator(),
          seed: 9,
        );
        finalTracker.onRoomLoaded(bossSim, grid: bossSim.grid);
        finalManager.activateRoom();
        finalTracker.onRoomActivated(bossSim, grid: bossSim.grid);
        for (
          var t = 0;
          t < 100 && !finalTracker.allRequiredEncountersCompleted;
          t++
        ) {
          bossSim.tick();
          for (final ev
              in bossSim.drainEvents().whereType<EnemyDefeatedEvent>()) {
            finalTracker.onEnemyDefeated(
              ev.enemyId,
              simulation: bossSim,
              grid: bossSim.grid,
            );
          }
        }
        expect(
          finalManager.advanceRoomIfCompleted(
            playerCell: bossSim.player.follower.currentCell,
          ),
          true,
        );
        expect(ended, isNotNull);
        final settled = settlement.settleDungeonCompleted(
          event: ended!,
          config: config,
          rewardProcessor: processor,
          random: math.Random(1),
          dungeonManager: finalManager,
          difficultyProfile: finalManager.activeDifficultyProfile,
          difficultyService: diffService,
        );
        expect(settled.validCompletion, true);
        expect(
          settled.granted?.expGranted,
          diffService.scaleExp(asc.completionReward!.expReward, profile),
        );
        expect(
          settled.granted?.goldGranted,
          diffService.scaleGold(asc.completionReward!.goldReward, profile),
        );
      }
    });
  });

  group('M9 Stage 2 — Persistensi cycleRank & Recovery Sesi', () {
    test('activeDungeonSession.cycleRank tersimpan di Drift dan session recovery menjaga difficulty awal meski DB rank berubah', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      final repo = DriftPlayerSaveRepository(db: db, config: config);
      final diffService = DifficultyService(config.difficulty);
      final manager = DungeonManager(
        dungeons: config.dungeons,
        encounterTracker: EncounterTracker(monsterCatalog: config.monsters),
        difficultyService: diffService,
      );

      final started = manager.startDungeon(
        'ascension_sanctum',
        runId: 'asc_recover_rank1',
        cycleRank: 1,
      );
      expect(started.cycleRank, 1);

      final activeSnapshot = manager.toActiveSessionSnapshot(
        reviveCooldownTicks: 120,
        playerStatus: PlayerStatus.alive,
      )!;
      expect(activeSnapshot.cycleRank, 1);

      await repo.saveSnapshot(
        PlayerSaveSnapshot(
          character: PlayerCharacter(
            config: config.progression,
            progress: const PlayerProgress(level: 50),
          ).toSnapshot(),
          inventory: Inventory(definitions: config.items).toSnapshot(),
          cycleProgress: const CycleProgress(
            ascensionRank: 1,
            lastNormalDungeonId: 'aether_sanctum',
          ),
          dungeon: const DungeonProgressSnapshot(
            currentDungeonId: 'ascension_sanctum',
            currentRoomId: 'as_outer_sanctum',
            currentRoomIndex: 0,
          ),
          dungeonProgresses: const {
            'aether_sanctum': DungeonProgressSnapshot(
              currentDungeonId: 'aether_sanctum',
              clearsCount: 2,
              clearedInCycleRank: 1,
            ),
          },
          activeDungeonSession: activeSnapshot,
          session: const GameSessionSnapshot(lastSavedAtMs: 50000),
        ),
      );

      // Simulasikan perubahan DB rank ke 3 sebelum recovery dijalankan.
      final currentLoaded = (await repo.loadSnapshot())!;
      await repo.saveSnapshot(
        PlayerSaveSnapshot(
          character: currentLoaded.character,
          inventory: currentLoaded.inventory,
          dungeon: currentLoaded.dungeon,
          dungeonProgresses: currentLoaded.dungeonProgresses,
          cycleProgress: const CycleProgress(
            ascensionRank: 3,
            lastNormalDungeonId: 'aether_sanctum',
          ),
          session: currentLoaded.session,
          claimedEventIds: currentLoaded.claimedEventIds,
          activeDungeonSession: currentLoaded.activeDungeonSession,
          offlineActivity: currentLoaded.offlineActivity,
        ),
      );

      final reloaded = (await repo.loadSnapshot())!;
      expect(reloaded.cycleProgress.ascensionRank, 3);
      expect(reloaded.activeDungeonSession?.cycleRank, 1);

      final recoveredTracker = EncounterTracker(
        monsterCatalog: config.monsters,
      );
      final recoveredManager = DungeonManager(
        dungeons: config.dungeons,
        encounterTracker: recoveredTracker,
        difficultyService: diffService,
      );
      final restored = recoveredManager.restoreSession(
        reloaded.activeDungeonSession!,
      )!;

      expect(restored.cycleRank, 1);
      expect(
        recoveredManager.activeDifficultyProfile.multiplier,
        closeTo(6.834375 * (1.0 + config.difficulty.cyclePerRank), 1e-9),
      );

      final sim = CombatSimulation(
        grid: recoveredManager.activeGrid!,
        pathfinder: const AStarPathfinder(),
        player: Combatant(
          id: 'player',
          team: Team.player,
          stats: config.progression.baseStats,
          cell: recoveredManager.activeRoom!.entryPosition,
        ),
        reviveConfig: config.revive,
        damageCalculator: config.damage.createCalculator(),
        seed: 3,
      );
      recoveredTracker.onRoomLoaded(sim, grid: sim.grid);
      recoveredManager.activateRoom();
      final spawned = recoveredTracker.onRoomActivated(sim, grid: sim.grid);
      final first = spawned.first;
      final enemy = sim.enemies.firstWhere((e) => e.id == first.enemyId);

      final rank1Profile = diffService.profileFor(
        config.dungeons['ascension_sanctum']!,
        1,
      );
      final rank3Profile = diffService.profileFor(
        config.dungeons['ascension_sanctum']!,
        3,
      );
      final rank1Stats = diffService.scaleMonsterStats(
        config.monsters[first.monsterId]!.stats,
        rank1Profile,
      );
      final rank3Stats = diffService.scaleMonsterStats(
        config.monsters[first.monsterId]!.stats,
        rank3Profile,
      );

      expect(enemy.stats.maxHp, rank1Stats.maxHp);
      expect(enemy.stats.atk, rank1Stats.atk);
      expect(enemy.stats.maxHp, isNot(rank3Stats.maxHp));
    });

    test(
      'decode JSON legacy tanpa field cycleRank memberi fallback 0 secara aman',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await db.initialize();
        final repo = DriftPlayerSaveRepository(db: db, config: config);

        final char = PlayerCharacter(config: config.progression).toSnapshot();
        final inv = Inventory(definitions: config.items).toSnapshot();
        await repo.saveSnapshot(
          PlayerSaveSnapshot(
            character: char,
            inventory: inv,
            activeDungeonSession: const ActiveDungeonSessionSnapshot(
              runId: 'legacy_run',
              dungeonId: 'forgotten_forest',
              currentRoomId: 'forest_entrance',
              currentRoomIndex: 0,
              status: DungeonSessionStatus.inProgress,
              cycleRank: 2,
            ),
          ),
        );

        final rows = await db.select(db.gameSessions).get();
        final decodedMap =
            jsonDecode(rows.single.sessionDataJson) as Map<String, Object?>;
        final activeMap = Map<String, Object?>.from(
          decodedMap['activeDungeonSession']! as Map,
        )..remove('cycleRank');
        decodedMap['activeDungeonSession'] = activeMap;

        await db
            .update(db.gameSessions)
            .write(
              GameSessionsCompanion(
                sessionDataJson: Value(jsonEncode(decodedMap)),
              ),
            );

        final reloaded = (await repo.loadSnapshot())!;
        expect(reloaded.activeDungeonSession?.runId, 'legacy_run');
        expect(reloaded.activeDungeonSession?.cycleRank, 0);
      },
    );

    test('OfflineDungeonRunner menjaga cycleRank awal sesi normal saat request cycleRank berubah', () {
      final d1 = config.dungeons['forgotten_forest']!;
      final lastRoomId = d1.roomOrder.last;
      final charRank0 = PlayerCharacter(
        config: config.progression,
        progress: const PlayerProgress(level: 20),
        skillCatalog: config.skills,
        specializationConfig: config.specializations,
      );
      final invRank0 = Inventory(definitions: config.items);
      final runner = OfflineDungeonRunner(
        damageCalculator: config.damage.createCalculator(),
      );
      final window = const OfflineTimeCalculator().calculate(
        session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
        nowMs: 1000000 + const Duration(minutes: 10).inMilliseconds,
      );

      final baseline = runner.runBatch(
        OfflineDungeonRunRequest(
          mode: OfflineActivityMode.continueDungeon,
          character: charRank0,
          inventory: invRank0,
          config: config,
          rewardProcessor: RewardProcessor(
            character: charRank0,
            inventory: invRank0,
            items: config.items,
            lootTables: config.lootTables,
            equipmentFactory: EquipmentFactory(config.equipment),
          ),
          dungeonId: 'forgotten_forest',
          dungeonProgress: const DungeonProgressSnapshot(
            currentDungeonId: 'forgotten_forest',
          ),
          activeDungeonSession: ActiveDungeonSessionSnapshot(
            runId: 'resume_norm_rank0',
            dungeonId: 'forgotten_forest',
            currentRoomId: lastRoomId,
            currentRoomIndex: d1.roomOrder.length - 1,
            status: DungeonSessionStatus.inProgress,
            clearedRoomIds: d1.roomOrder.take(d1.roomOrder.length - 1).toSet(),
            cycleRank: 0,
          ),
          timeWindow: window,
          simulationSeed: 77,
          cycleRank: 0,
        ),
      );

      final recoveredAtHigherCycle = PlayerCharacter(
        config: config.progression,
        progress: const PlayerProgress(level: 20),
        skillCatalog: config.skills,
        specializationConfig: config.specializations,
      );
      final recoveredInv = Inventory(definitions: config.items);
      final recovered = runner.runBatch(
        OfflineDungeonRunRequest(
          mode: OfflineActivityMode.continueDungeon,
          character: recoveredAtHigherCycle,
          inventory: recoveredInv,
          config: config,
          rewardProcessor: RewardProcessor(
            character: recoveredAtHigherCycle,
            inventory: recoveredInv,
            items: config.items,
            lootTables: config.lootTables,
            equipmentFactory: EquipmentFactory(config.equipment),
          ),
          dungeonId: 'forgotten_forest',
          dungeonProgress: const DungeonProgressSnapshot(
            currentDungeonId: 'forgotten_forest',
          ),
          activeDungeonSession: ActiveDungeonSessionSnapshot(
            runId: 'resume_norm_rank0',
            dungeonId: 'forgotten_forest',
            currentRoomId: lastRoomId,
            currentRoomIndex: d1.roomOrder.length - 1,
            status: DungeonSessionStatus.inProgress,
            clearedRoomIds: d1.roomOrder.take(d1.roomOrder.length - 1).toSet(),
            cycleRank: 0,
          ),
          timeWindow: window,
          simulationSeed: 77,
          cycleRank: 3,
        ),
      );

      expect(baseline.stopReason, OfflineDungeonStopReason.dungeonCompleted);
      expect(recovered.stopReason, OfflineDungeonStopReason.dungeonCompleted);
      expect(recovered.expGained, baseline.expGained);
      expect(recovered.goldGained, baseline.goldGained);
    });
  });

  group('M9 Stage 2 — Manual-Only Enforcement untuk ascension_sanctum', () {
    test('OfflineProgressionService & OfflineDungeonRunner menolak Auto Farming pada ascension_sanctum', () {
      const startMs = 1000000;
      final endMs = startMs + const Duration(minutes: 30).inMilliseconds;
      final char = PlayerCharacter(
        config: config.progression,
        progress: const PlayerProgress(level: 60),
      );
      final inv = Inventory(definitions: config.items);
      final service = OfflineProgressionService();

      final result = service.process(
        character: char,
        inventory: inv,
        config: config,
        session: const GameSessionSnapshot(lastSavedAtMs: startMs),
        nowMs: endMs,
        cycleProgress: const CycleProgress(ascensionRank: 1),
        offlineActivity: const OfflineActivitySnapshot(
          mode: OfflineActivityMode.autoFarming,
          state: OfflineActivityState.configured,
          selectedDungeonId: 'ascension_sanctum',
          simulationSeed: 12,
        ),
        dungeonProgresses: const {
          'aether_sanctum': DungeonProgressSnapshot(
            currentDungeonId: 'aether_sanctum',
            clearsCount: 2,
            clearedInCycleRank: 1,
          ),
          'ascension_sanctum': DungeonProgressSnapshot(
            currentDungeonId: 'ascension_sanctum',
            clearsCount: 1,
            clearedInCycleRank: 1,
          ),
        },
      );

      expect(result.status, OfflineProgressionStatus.noEligibleEncounter);
      expect(result.hasRewards, false);
      expect(
        result.updatedOfflineActivity?.mode,
        OfflineActivityMode.pauseProgression,
      );
      expect(
        result.updatedOfflineActivity?.state,
        OfflineActivityState.inactive,
      );

      final runnerOutcome = const OfflineDungeonRunner().runBatch(
        OfflineDungeonRunRequest(
          mode: OfflineActivityMode.autoFarming,
          character: char,
          inventory: inv,
          config: config,
          rewardProcessor: RewardProcessor(
            character: char,
            inventory: inv,
            items: config.items,
            lootTables: config.lootTables,
            equipmentFactory: EquipmentFactory(config.equipment),
          ),
          dungeonId: 'ascension_sanctum',
          dungeonProgress: const DungeonProgressSnapshot(
            currentDungeonId: 'ascension_sanctum',
            clearsCount: 1,
            clearedInCycleRank: 1,
          ),
          timeWindow: const OfflineTimeCalculator().calculate(
            session: const GameSessionSnapshot(lastSavedAtMs: startMs),
            nowMs: endMs,
          ),
          simulationSeed: 12,
          cycleRank: 1,
        ),
      );
      expect(runnerOutcome.stopReason, OfflineDungeonStopReason.invalidSetup);
      expect(runnerOutcome.runsAttempted, 0);
      expect(runnerOutcome.failureReason, isNotNull);
    });

    test('GameSessionCoordinator mengalihkan sesi aktif ascension_sanctum offline ke Pause Progression dengan pesan summary & sesi tetap utuh', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      const savedAtMs = 2000000;
      final nowMs = savedAtMs + const Duration(minutes: 45).inMilliseconds;
      final repo = DriftPlayerSaveRepository(db: db, config: config);
      final coord = GameSessionCoordinator(
        repository: repo,
        config: config,
        nowMs: () => nowMs,
      );

      final char = PlayerCharacter(
        config: config.progression,
        progress: const PlayerProgress(level: 55, currentExp: 10, gold: 200),
      );
      await repo.saveSnapshot(
        PlayerSaveSnapshot(
          character: char.toSnapshot(),
          inventory: Inventory(definitions: config.items).toSnapshot(),
          cycleProgress: const CycleProgress(
            ascensionRank: 1,
            lastNormalDungeonId: 'aether_sanctum',
          ),
          dungeon: const DungeonProgressSnapshot(
            currentDungeonId: 'ascension_sanctum',
            currentRoomId: 'as_arcane_bridge',
            currentRoomIndex: 1,
          ),
          dungeonProgresses: const {
            'aether_sanctum': DungeonProgressSnapshot(
              currentDungeonId: 'aether_sanctum',
              clearsCount: 2,
              clearedInCycleRank: 1,
            ),
          },
          activeDungeonSession: const ActiveDungeonSessionSnapshot(
            runId: 'asc_manual_run_1',
            dungeonId: 'ascension_sanctum',
            currentRoomId: 'as_arcane_bridge',
            currentRoomIndex: 1,
            status: DungeonSessionStatus.inProgress,
            clearedRoomIds: {'as_outer_sanctum'},
            cycleRank: 1,
          ),
          offlineActivity: const OfflineActivitySnapshot(
            mode: OfflineActivityMode.continueDungeon,
            state: OfflineActivityState.configured,
            selectedDungeonId: 'ascension_sanctum',
            activeRunId: 'asc_manual_run_1',
            simulationSeed: 5,
          ),
          session: const GameSessionSnapshot(
            lastSavedAtMs: savedAtMs,
            lastActiveAtMs: savedAtMs,
          ),
        ),
      );

      final boot = await coord.loadAndProcessOffline();
      expect(boot.offlineResult.hasRewards, false);
      expect(boot.character.level, 55);
      expect(boot.character.currentExp, 10);
      expect(boot.character.gold, 200);
      expect(boot.offlineActivity.mode, OfflineActivityMode.pauseProgression);
      expect(boot.offlineActivity.state, OfflineActivityState.inactive);
      expect(
        boot.offlineActivity.pendingSummary?.failureReason,
        contains('Ascension'),
      );
      expect(boot.activeDungeonSession?.dungeonId, 'ascension_sanctum');
      expect(boot.activeDungeonSession?.cycleRank, 1);

      final reloaded = (await repo.loadSnapshot())!;
      expect(
        reloaded.offlineActivity.mode,
        OfflineActivityMode.pauseProgression,
      );
      expect(reloaded.activeDungeonSession?.dungeonId, 'ascension_sanctum');
      expect(reloaded.activeDungeonSession?.cycleRank, 1);
    });
  });
}
