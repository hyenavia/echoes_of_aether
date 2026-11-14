import 'dart:io';
import 'dart:math' as math;

import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/combat_event.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/difficulty_service.dart';
import 'package:echoes_of_aether/domain/services/dungeon_manager.dart';
import 'package:echoes_of_aether/domain/services/dungeon_reward_settlement_service.dart';
import 'package:echoes_of_aether/domain/services/encounter_tracker.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/offline_dungeon_runner.dart';
import 'package:echoes_of_aether/domain/services/offline_time_calculator.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:echoes_of_aether/game/echoes_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadConfig({String? dungeonsOverride}) {
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
      dungeonsOverride ?? _readAsset('dungeons.json'),
      ascensionMultiplier: difficulty.ascensionMultiplier,
    ),
  );
  const GameConfigValidator().validate(config);
  return config;
}

const _scaledTestDungeons = '''
{
  "maps": {
    "corridor": [
      "#######",
      "#.....#",
      "#######"
    ]
  },
  "dungeons": [
    {
      "id": "scaled_grove",
      "name": "Scaled Grove",
      "biome": "forgotten_forest",
      "kind": "normal",
      "order": 1,
      "difficulty_scale": 2.0,
      "recommended_level": 10,
      "start_room_id": "sg_room1",
      "completion_reward": {
        "exp_reward": 100,
        "gold_reward": 50
      },
      "rooms": [
        {
          "id": "sg_room1",
          "name": "Grove Entry",
          "type": "normal",
          "map_ref": "corridor",
          "entry_position": { "x": 1, "y": 1 },
          "exit_position": { "x": 5, "y": 1 },
          "spawns": [
            {
              "id": "s1",
              "monster_id": "aether_slime",
              "position": { "x": 3, "y": 1 },
              "quantity": 1,
              "required": true,
              "stat_modifier": {
                "hp_multiplier": 1.2,
                "hp_bonus": 10
              }
            }
          ],
          "completion_condition": { "type": "defeat_required_enemies" },
          "reward": {
            "exp_reward": 40,
            "gold_reward": 20
          },
          "next_room_ids": ["sg_room2"]
        },
        {
          "id": "sg_room2",
          "name": "Grove Heart",
          "type": "boss",
          "map_ref": "corridor",
          "entry_position": { "x": 1, "y": 1 },
          "exit_position": { "x": 5, "y": 1 },
          "spawns": [
            {
              "id": "b1",
              "monster_id": "forest_wolf",
              "position": { "x": 3, "y": 1 },
              "quantity": 1,
              "is_boss": true,
              "required": true
            }
          ],
          "completion_condition": { "type": "defeat_boss" },
          "next_room_ids": []
        }
      ]
    }
  ]
}
''';

void main() {
  group('Stage 3 — Paritas Online / Offline & Forgotten Forest', () {
    test('Forgotten Forest (difficulty_scale 1.0, cycleRank 0) identik dengan pra-Stage 3', () {
      final config = _loadConfig();
      const seed = 777;
      final window = const OfflineTimeCalculator().calculate(
        session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
        nowMs: 1000000 + const Duration(minutes: 10).inMilliseconds,
      );

      final character = PlayerCharacter(
        config: config.progression,
        progress: PlayerProgress(level: 10),
        skillCatalog: config.skills,
        specializationConfig: config.specializations,
      );
      final inventory = Inventory(definitions: config.items);
      final rewardProcessor = RewardProcessor(
        character: character,
        inventory: inventory,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: EquipmentFactory(config.equipment),
      );

      final outcome =
          OfflineDungeonRunner(
            damageCalculator: config.damage.createCalculator(),
          ).runBatch(
            OfflineDungeonRunRequest(
              mode: OfflineActivityMode.continueDungeon,
              character: character,
              inventory: inventory,
              config: config,
              rewardProcessor: rewardProcessor,
              dungeonId: 'forgotten_forest',
              dungeonProgress: const DungeonProgressSnapshot(
                currentDungeonId: 'forgotten_forest',
                currentRoomId: 'forest_entrance',
                currentRoomIndex: 0,
              ),
              activeDungeonSession: const ActiveDungeonSessionSnapshot(
                runId: 'ff_parity',
                dungeonId: 'forgotten_forest',
                currentRoomId: 'forest_entrance',
                currentRoomIndex: 0,
                status: DungeonSessionStatus.inProgress,
              ),
              timeWindow: window,
              simulationSeed: seed,
            ),
          );

      expect(outcome.stopReason, OfflineDungeonStopReason.dungeonCompleted);
      expect(outcome.runsCompleted, 1);

      final tracker = EncounterTracker(monsterCatalog: config.monsters);
      final manager = DungeonManager(
        dungeons: config.dungeons,
        encounterTracker: tracker,
        difficultyService: DifficultyService(config.difficulty),
      );
      manager.startDungeon('forgotten_forest');
      expect(manager.activeDifficultyProfile.isIdentity, isTrue);

      final slimeDef = config.monsters['aether_slime']!;
      final sim = CombatSimulation(
        grid: manager.activeGrid!,
        pathfinder: const AStarPathfinder(),
        player: Combatant(
          id: 'player',
          team: Team.player,
          stats: character.stats,
          cell: manager.activeRoom!.entryPosition,
        ),
      );
      tracker.onRoomLoaded(sim, grid: sim.grid);
      manager.activateRoom();
      final spawned = tracker.onRoomActivated(sim, grid: sim.grid);
      expect(spawned, isNotEmpty);
      final enemy = sim.enemies.firstWhere(
        (e) => e.id == spawned.first.enemyId,
      );
      expect(enemy.stats.maxHp, slimeDef.stats.maxHp);
      expect(enemy.stats.atk, slimeDef.stats.atk);
      expect(enemy.stats.def, slimeDef.stats.def);
    });

    test('dungeon berskala (difficulty_scale 2.0): EncounterTracker, jalur Online, dan OfflineDungeonRunner identik', () {
      final config = _loadConfig(dungeonsOverride: _scaledTestDungeons);
      const seed = 4242;
      final diffService = DifficultyService(config.difficulty);
      final dungeon = config.dungeons['scaled_grove']!;
      final expectedProfile = diffService.profileFor(dungeon, 0);
      final window = const OfflineTimeCalculator().calculate(
        session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
        nowMs: 1000000 + const Duration(minutes: 10).inMilliseconds,
      );

      expect(expectedProfile.multiplier, 2.0);
      expect(expectedProfile.hpMultiplier, 2.0);
      expect(expectedProfile.atkMultiplier, 2.0);
      expect(expectedProfile.defMultiplier, closeTo(math.pow(2.0, 0.9), 1e-9));
      expect(
        expectedProfile.rewardMultiplier,
        closeTo(math.pow(2.0, 0.85), 1e-9),
      );

      // 1. Cek stat monster pada EncounterTracker setelah SpawnStatModifier.
      final baseSlime = config.monsters['aether_slime']!;
      final spawnMod = dungeon.rooms['sg_room1']!.spawns.first.statModifier;
      final afterMod = spawnMod.applyTo(baseSlime.stats);
      final expectedSlimeStats = diffService.scaleMonsterStats(
        afterMod,
        expectedProfile,
      );

      // 2. Jalankan OfflineDungeonRunner untuk scaled_grove.
      final offChar = PlayerCharacter(
        config: config.progression,
        progress: PlayerProgress(level: 25),
        skillCatalog: config.skills,
        specializationConfig: config.specializations,
      );
      final offInv = Inventory(definitions: config.items);
      final offProcessor = RewardProcessor(
        character: offChar,
        inventory: offInv,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: EquipmentFactory(config.equipment),
      );
      final offOutcome =
          OfflineDungeonRunner(
            damageCalculator: config.damage.createCalculator(),
          ).runBatch(
            OfflineDungeonRunRequest(
              mode: OfflineActivityMode.continueDungeon,
              character: offChar,
              inventory: offInv,
              config: config,
              rewardProcessor: offProcessor,
              dungeonId: 'scaled_grove',
              dungeonProgress: const DungeonProgressSnapshot(
                currentDungeonId: 'scaled_grove',
                currentRoomId: 'sg_room1',
                currentRoomIndex: 0,
              ),
              activeDungeonSession: const ActiveDungeonSessionSnapshot(
                runId: 'scaled_run',
                dungeonId: 'scaled_grove',
                currentRoomId: 'sg_room1',
                currentRoomIndex: 0,
                status: DungeonSessionStatus.inProgress,
              ),
              timeWindow: window,
              simulationSeed: seed,
            ),
          );
      expect(offOutcome.stopReason, OfflineDungeonStopReason.dungeonCompleted);

      // 3. Jalankan jalur Online (DungeonManager + EncounterTracker + Settlement).
      final onChar = PlayerCharacter(
        config: config.progression,
        progress: PlayerProgress(level: 25),
        skillCatalog: config.skills,
        specializationConfig: config.specializations,
      );
      final onInv = Inventory(definitions: config.items);
      final onProcessor = RewardProcessor(
        character: onChar,
        inventory: onInv,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: EquipmentFactory(config.equipment),
      );
      final onTracker = EncounterTracker(monsterCatalog: config.monsters);
      final onManager = DungeonManager(
        dungeons: config.dungeons,
        encounterTracker: onTracker,
        difficultyService: diffService,
      );
      onManager.startDungeon('scaled_grove', runId: 'online_scaled');

      final startRoom = onManager.activeRoom!;
      final onSim = CombatSimulation(
        grid: onManager.activeGrid!,
        pathfinder: const AStarPathfinder(),
        player: Combatant(
          id: 'player',
          team: Team.player,
          stats: onChar.stats,
          cell: startRoom.entryPosition,
        ),
        reviveConfig: config.revive,
        damageCalculator: config.damage.createCalculator(),
        seed: seed,
      );

      onTracker.onRoomLoaded(onSim, grid: onSim.grid);
      onManager.activateRoom();
      final spawnedRoom1 = onTracker.onRoomActivated(onSim, grid: onSim.grid);
      final slimeEnemy = onSim.enemies.firstWhere(
        (e) => e.id == spawnedRoom1.first.enemyId,
      );
      expect(slimeEnemy.stats.maxHp, expectedSlimeStats.maxHp);
      expect(slimeEnemy.stats.atk, expectedSlimeStats.atk);
      expect(slimeEnemy.stats.def, expectedSlimeStats.def);

      var appliedLevel = onChar.level;
      const settlement = DungeonRewardSettlementService();
      var onlineExp = 0;
      var onlineGold = 0;

      for (var tick = 0; tick < 3000; tick++) {
        final cur = onManager.session!;
        if (cur.isTerminal) break;
        if (cur.roomLifecycle == RoomLifecycleState.completed) {
          onManager.transitionToNextRoom();
          if (onManager.hasActiveSession && onManager.activeRoom != null) {
            final nextRoom = onManager.activeRoom!;
            final nextGrid = onManager.activeGrid!;
            onSim.loadRoom(nextGrid, entryCell: nextRoom.entryPosition);
            onTracker.onRoomLoaded(onSim, grid: nextGrid);
            onManager.activateRoom();
            onTracker.onRoomActivated(onSim, grid: nextGrid);
          }
          continue;
        }

        onSim.tick();
        for (final ev in onSim.drainEvents()) {
          if (ev is EnemyDefeatedEvent) {
            final granted = onProcessor.processEnemyDefeated(
              eventId: 'kill:${cur.runId}:${ev.enemyId}',
              definition: ev.definition,
              random: math.Random(seed),
              difficultyProfile: onManager.activeDifficultyProfile,
              difficultyService: diffService,
            );
            if (!granted.alreadyClaimed) {
              onlineExp += granted.expGranted;
              onlineGold += granted.goldGranted;
            }
            onTracker.onEnemyDefeated(
              ev.enemyId,
              simulation: onSim,
              grid: onSim.grid,
            );
          }
        }
        if (onChar.level != appliedLevel) {
          appliedLevel = onChar.level;
          onSim.player.applyStats(onChar.stats);
        }

        if (onManager.hasActiveSession &&
            onManager.session!.roomLifecycle == RoomLifecycleState.active) {
          final cell = onSim.player.follower.currentCell;
          final eval = onManager.evaluateCurrentRoom(playerCell: cell);
          if (eval.isCompleted &&
              onManager.tryCompleteActiveRoom(
                playerCell: cell,
                expectedRunId: cur.runId,
                expectedRoomId: onManager.activeRoom!.id,
              )) {
            final rGranted = settlement.settleRoomCompleted(
              session: onManager.session!,
              room: dungeon.rooms[cur.currentRoomId]!,
              rewardProcessor: onProcessor,
              random: math.Random(seed),
              difficultyProfile: onManager.activeDifficultyProfile,
              difficultyService: diffService,
            );
            if (rGranted != null && !rGranted.alreadyClaimed) {
              onlineExp += rGranted.expGranted;
              onlineGold += rGranted.goldGranted;
            }
            if (onManager.session!.status == DungeonSessionStatus.completed) {
              final ended = DungeonEndedEvent(
                onManager.session!,
                DungeonSessionStatus.completed,
                reason: DungeonEndReason.completed,
                dungeon: dungeon,
              );
              final dSettled = settlement.settleDungeonCompleted(
                event: ended,
                config: config,
                rewardProcessor: onProcessor,
                random: math.Random(seed),
                dungeonManager: onManager,
                difficultyProfile: onManager.activeDifficultyProfile,
                difficultyService: diffService,
              );
              if (dSettled.granted != null &&
                  !dSettled.granted!.alreadyClaimed) {
                onlineExp += dSettled.granted!.expGranted;
                onlineGold += dSettled.granted!.goldGranted;
              }
            }
          }
        }
      }

      final baseWolf = config.monsters['forest_wolf']!;
      final expectedExp =
          diffService.scaleExp(baseSlime.expReward, expectedProfile) +
          diffService.scaleExp(baseWolf.expReward, expectedProfile) +
          diffService.scaleExp(40, expectedProfile) +
          diffService.scaleExp(100, expectedProfile);
      final expectedGold =
          diffService.scaleGold(baseSlime.goldReward, expectedProfile) +
          diffService.scaleGold(baseWolf.goldReward, expectedProfile) +
          diffService.scaleGold(20, expectedProfile) +
          diffService.scaleGold(50, expectedProfile);

      expect(onlineExp, expectedExp);
      expect(onlineGold, expectedGold);
      expect(offOutcome.expGained, onlineExp);
      expect(offOutcome.goldGained, onlineGold);
      expect(offChar.level, onChar.level);
      expect(offChar.gold, onChar.gold);
    });

    testWidgets(
      'CombatSystem Flame melalui EchoesGame menerapkan pengali reward pada kill, room, dan dungeon completion',
      (tester) async {
        final config = _loadConfig(dungeonsOverride: _scaledTestDungeons);
        final diffService = DifficultyService(config.difficulty);
        final dungeon = config.dungeons['scaled_grove']!;
        final profile = diffService.profileFor(dungeon, 0);

        final character = PlayerCharacter(
          config: config.progression,
          progress: PlayerProgress(level: 30),
          skillCatalog: config.skills,
          specializationConfig: config.specializations,
        );
        final inventory = Inventory(definitions: config.items);
        final tracker = EncounterTracker(monsterCatalog: config.monsters);
        final manager = DungeonManager(
          dungeons: config.dungeons,
          encounterTracker: tracker,
          difficultyService: diffService,
          runIdGenerator: () => 'flame_scaled_run',
        );
        manager.startDungeon('scaled_grove');

        final game = EchoesGame(
          config: config,
          character: character,
          inventory: inventory,
          autoSkill: ValueNotifier(true),
          dungeonManager: manager,
          roomTransitionDelaySeconds: 0.2,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: GameWidget<EchoesGame>(game: game)),
          ),
        );
        await tester.pump();
        await tester.pump();

        for (var i = 0; i < 300; i++) {
          if (manager.session?.status == DungeonSessionStatus.completed) break;
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(manager.session?.status, DungeonSessionStatus.completed);

        final baseSlime = config.monsters['aether_slime']!;
        final baseWolf = config.monsters['forest_wolf']!;
        final expectedGold =
            diffService.scaleGold(baseSlime.goldReward, profile) +
            diffService.scaleGold(baseWolf.goldReward, profile) +
            diffService.scaleGold(20, profile) +
            diffService.scaleGold(50, profile);

        expect(character.gold, expectedGold);
      },
    );
  });
}
