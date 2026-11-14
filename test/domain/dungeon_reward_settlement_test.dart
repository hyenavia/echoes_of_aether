import 'dart:math';

import 'package:echoes_of_aether/domain/entities/combat_event.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_reward.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/equipment_config.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/loot_table.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/dungeon_manager.dart';
import 'package:echoes_of_aether/domain/services/dungeon_reward_settlement_service.dart';
import 'package:echoes_of_aether/domain/services/encounter_tracker.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const layout = <String>[
    '#########',
    '#.......#',
    '#.......#',
    '#.......#',
    '#########',
  ];

  const items = <String, ItemDefinition>{
    'slime_gel': ItemDefinition(
      id: 'slime_gel',
      name: 'Slime Gel',
      category: ItemCategory.material,
      maxStack: 99,
    ),
    'forest_charm': ItemDefinition(
      id: 'forest_charm',
      name: 'Forest Charm',
      category: ItemCategory.equipment,
      rarity: ItemRarity.rare,
      equipment: EquipmentData(
        slot: EquipmentSlot.accessory,
        baseStats: EquipmentStats(hp: 25, atk: 4),
      ),
    ),
  };

  const lootTables = <String, LootTable>{
    'slime_loot': LootTable(
      id: 'slime_loot',
      entries: [LootEntry(itemId: 'slime_gel', chance: 1.0)],
    ),
    'clear_loot': LootTable(
      id: 'clear_loot',
      entries: [LootEntry(itemId: 'forest_charm', chance: 1.0)],
    ),
  };

  const slime = EnemyDefinition(
    id: 'aether_slime',
    name: 'Aether Slime',
    level: 1,
    expReward: 20,
    goldReward: 10,
    lootTableId: 'slime_loot',
    stats: CombatStats(maxHp: 30, atk: 5, def: 0),
  );

  const boss = EnemyDefinition(
    id: 'ancient_heart_guardian',
    name: 'Ancient Heart Guardian',
    level: 5,
    isBoss: true,
    expReward: 100,
    goldReward: 50,
    stats: CombatStats(maxHp: 120, atk: 12, def: 2),
  );

  const dungeon = DungeonDefinition(
    id: 'forgotten_forest',
    name: 'Forgotten Forest',
    biome: 'forgotten_forest',
    startRoomId: 'room_1',
    roomOrder: ['room_1', 'room_2'],
    rooms: {
      'room_1': RoomDefinition(
        id: 'room_1',
        dungeonId: 'forgotten_forest',
        name: 'Entrance',
        type: RoomType.normal,
        mapRef: 'map_1',
        layout: layout,
        entryPosition: GridPoint(1, 2),
        exitPosition: GridPoint(7, 2),
        spawns: [
          RoomSpawnConfig(
            id: 's1',
            monsterId: 'aether_slime',
            position: GridPoint(4, 2),
          ),
        ],
        completionCondition: RoomCompletionCondition(),
        nextRoomIds: ['room_2'],
        reward: RoomRewardConfig(expReward: 15, goldReward: 5),
      ),
      'room_2': RoomDefinition(
        id: 'room_2',
        dungeonId: 'forgotten_forest',
        name: 'Ancient Heart',
        type: RoomType.boss,
        mapRef: 'map_2',
        layout: layout,
        entryPosition: GridPoint(1, 2),
        exitPosition: GridPoint(7, 2),
        spawns: [
          RoomSpawnConfig(
            id: 'b1',
            monsterId: 'ancient_heart_guardian',
            position: GridPoint(6, 2),
            isBoss: true,
          ),
        ],
        completionCondition: RoomCompletionCondition(
          type: RoomCompletionConditionType.defeatBoss,
        ),
        nextRoomIds: [],
      ),
    },
  );

  final config = GameConfig(
    monsters: const {'aether_slime': slime, 'ancient_heart_guardian': boss},
    revive: const ReviveConfig(),
    progression: const ProgressionConfig(
      maxLevel: 30,
      expBase: 200,
      expGrowth: 1.5,
      baseStats: CombatStats(maxHp: 100, atk: 15, def: 2),
      perLevel: LevelGrowth(hp: 15, atk: 2, def: 1),
    ),
    items: items,
    lootTables: lootTables,
    dungeonCompletion: const DungeonCompletionReward(
      expReward: 120,
      goldReward: 50,
      lootTableId: 'clear_loot',
    ),
    dungeons: const {'forgotten_forest': dungeon},
  );

  group('Stage 5 — DungeonRewardSettlementService & Anti-Duplicate Claims', () {
    const settlement = DungeonRewardSettlementService();

    test('dungeon completion memberikan reward satu kali per runId dan menolak duplikat', () {
      final character = PlayerCharacter(config: config.progression);
      final inventory = Inventory(definitions: items);
      final rewardProcessor = RewardProcessor(
        character: character,
        inventory: inventory,
        items: items,
        lootTables: lootTables,
        equipmentFactory: const EquipmentFactory(EquipmentConfig()),
      );
      final tracker = EncounterTracker(monsterCatalog: config.monsters);
      final manager = DungeonManager(
        dungeons: config.dungeons,
        encounterTracker: tracker,
        runIdGenerator: () => 'run_unique_1',
      );

      DungeonEndedEvent? endedEvent;
      manager.addListener((e) {
        if (e is RoomLoadedEvent) {
          // Simulasi saat room dimuat: tempatkan ulang/reset grid.
        }
        if (e is DungeonEndedEvent) endedEvent = e;
      });

      manager.startDungeon('forgotten_forest');
      final sim = CombatSimulation(
        grid: manager.activeGrid!,
        pathfinder: const AStarPathfinder(),
        player: Combatant(
          id: 'player',
          team: Team.player,
          stats: const CombatStats(
            maxHp: 500,
            atk: 200,
            def: 10,
            attackSpeed: 4,
            moveSpeed: 8,
            attackRange: 3,
          ),
          cell: manager.activeRoom!.entryPosition,
        ),
      );
      manager.activateRoom();
      tracker.onRoomActivated(sim, grid: manager.activeGrid!);

      // Kalahkan musuh room_1.
      for (var t = 0; t < 100 && !tracker.allRequiredEncountersCompleted; t++) {
        sim.tick();
        for (final ev in sim.drainEvents().whereType<EnemyDefeatedEvent>()) {
          tracker.onEnemyDefeated(ev.enemyId, simulation: sim, grid: sim.grid);
        }
      }
      expect(manager.advanceRoomIfCompleted(), isTrue);
      expect(
        manager.activeRoom!.id,
        'ancient_heart_guardian'.isEmpty ? '' : 'room_2',
      );

      // Muat & aktifkan room_2 di simulasi lalu kalahkan boss.
      sim.loadRoom(
        manager.activeGrid!,
        entryCell: manager.activeRoom!.entryPosition,
      );
      manager.activateRoom();
      tracker.onRoomActivated(sim, grid: manager.activeGrid!);
      for (var t = 0; t < 100 && !tracker.allRequiredEncountersCompleted; t++) {
        sim.tick();
        for (final ev in sim.drainEvents().whereType<EnemyDefeatedEvent>()) {
          tracker.onEnemyDefeated(ev.enemyId, simulation: sim, grid: sim.grid);
        }
      }
      expect(manager.advanceRoomIfCompleted(), isTrue);
      expect(endedEvent, isNotNull);

      final res1 = settlement.settleDungeonCompleted(
        event: endedEvent!,
        config: config,
        rewardProcessor: rewardProcessor,
        random: Random(1),
        dungeonManager: manager,
      );
      expect(res1.validCompletion, isTrue);
      expect(res1.granted!.alreadyClaimed, isFalse);
      expect(manager.session!.completionRewardClaimed, isTrue);
      expect(character.gold, 50);

      final res2 = settlement.settleDungeonCompleted(
        event: endedEvent!,
        config: config,
        rewardProcessor: rewardProcessor,
        random: Random(2),
        dungeonManager: manager,
      );
      expect(res2.granted!.alreadyClaimed, isTrue);
      expect(character.gold, 50);
    });

    test('settleRoomCompleted dan settleDungeonCompleted idempotent termasuk lintas restart', () {
      final character = PlayerCharacter(config: config.progression);
      final inventory = Inventory(definitions: items);
      final processor1 = RewardProcessor(
        character: character,
        inventory: inventory,
        items: items,
        lootTables: lootTables,
        equipmentFactory: const EquipmentFactory(EquipmentConfig()),
      );

      const clearedRoom1 = DungeonSession(
        runId: 'run_42',
        dungeonId: 'forgotten_forest',
        currentRoomId: 'room_1',
        currentRoomIndex: 0,
        status: DungeonSessionStatus.roomCompleted,
        clearedRoomIds: {'room_1'},
      );

      final roomRes1 = settlement.settleRoomCompleted(
        session: clearedRoom1,
        room: dungeon.roomById('room_1')!,
        rewardProcessor: processor1,
        random: Random(1),
      );
      expect(roomRes1, isNotNull);
      expect(roomRes1!.alreadyClaimed, isFalse);
      expect(roomRes1.expGranted, 15);
      expect(roomRes1.goldGranted, 5);
      expect(character.gold, 5);
      expect(character.currentExp, 15);

      // Panggilan ulang untuk room yang sama pada run yang sama tidak memberi reward lagi.
      final roomResDup = settlement.settleRoomCompleted(
        session: clearedRoom1,
        room: dungeon.roomById('room_1')!,
        rewardProcessor: processor1,
        random: Random(2),
      );
      expect(roomResDup!.alreadyClaimed, isTrue);
      expect(character.gold, 5);

      // Dungeon completion valid di room final.
      const completedSession = DungeonSession(
        runId: 'run_42',
        dungeonId: 'forgotten_forest',
        currentRoomId: 'room_2',
        currentRoomIndex: 1,
        status: DungeonSessionStatus.completed,
        clearedRoomIds: {'room_1', 'room_2'},
      );
      final ended = DungeonEndedEvent(
        completedSession,
        DungeonSessionStatus.completed,
        reason: DungeonEndReason.completed,
        dungeon: dungeon,
      );

      final clear1 = settlement.settleDungeonCompleted(
        event: ended,
        config: config,
        rewardProcessor: processor1,
        random: Random(3),
      );
      expect(clear1.validCompletion, isTrue);
      expect(clear1.granted!.alreadyClaimed, isFalse);
      expect(clear1.granted!.expGranted, 120);
      expect(clear1.granted!.goldGranted, 50);
      expect(inventory.equipmentSnapshot(), hasLength(1));
      expect(character.gold, 55); // 5 + 50
      expect(character.currentExp, 135); // 15 + 120

      // Event completion ganda dalam run yang sama tidak memberi reward lagi.
      final clearDup = settlement.settleDungeonCompleted(
        event: ended,
        config: config,
        rewardProcessor: processor1,
        random: Random(4),
      );
      expect(clearDup.granted!.alreadyClaimed, isTrue);
      expect(character.gold, 55);
      expect(inventory.equipmentSnapshot(), hasLength(1));

      // Simulasi restart: RewardProcessor baru dengan claimedEventIds hasil load DB.
      final processorAfterRestart = RewardProcessor(
        character: character,
        inventory: inventory,
        items: items,
        lootTables: lootTables,
        equipmentFactory: const EquipmentFactory(EquipmentConfig()),
        claimedEventIds: processor1.claimedEventIds,
      );
      final roomAfterRestart = settlement.settleRoomCompleted(
        session: clearedRoom1,
        room: dungeon.roomById('room_1')!,
        rewardProcessor: processorAfterRestart,
        random: Random(5),
      );
      final clearAfterRestart = settlement.settleDungeonCompleted(
        event: ended,
        config: config,
        rewardProcessor: processorAfterRestart,
        random: Random(6),
      );
      expect(roomAfterRestart!.alreadyClaimed, isTrue);
      expect(clearAfterRestart.granted!.alreadyClaimed, isTrue);
      expect(character.gold, 55);
    });

    test('failed run maupun completion tidak sah tidak memberi dungeon completion reward tetapi loot terkonfirmasi tetap bertahan', () {
      final character = PlayerCharacter(config: config.progression);
      final inventory = Inventory(definitions: items);
      final processor = RewardProcessor(
        character: character,
        inventory: inventory,
        items: items,
        lootTables: lootTables,
        equipmentFactory: const EquipmentFactory(EquipmentConfig()),
      );

      // Loot monster sebelum pemain kalah.
      final enemyLoot = processor.processEnemyDefeated(
        eventId: 'enemy:10:room_1__s1__0',
        definition: slime,
        random: Random(1),
      );
      expect(enemyLoot.alreadyClaimed, isFalse);
      expect(inventory.quantityOf('slime_gel'), 1);
      expect(character.gold, 10);

      // Run berakhir failed di room_2.
      const failedSession = DungeonSession(
        runId: 'run_fail_1',
        dungeonId: 'forgotten_forest',
        currentRoomId: 'room_2',
        currentRoomIndex: 1,
        status: DungeonSessionStatus.failed,
        clearedRoomIds: {'room_1'},
      );
      final failedEvent = DungeonEndedEvent(
        failedSession,
        DungeonSessionStatus.failed,
        reason: DungeonEndReason.defeated,
        dungeon: dungeon,
      );
      final failRes = settlement.settleDungeonCompleted(
        event: failedEvent,
        config: config,
        rewardProcessor: processor,
        random: Random(7),
      );
      expect(failRes.validCompletion, isFalse);
      expect(failRes.granted, isNull);
      expect(character.gold, 10); // tidak mendapat +50 clear gold
      expect(
        inventory.quantityOf('slime_gel'),
        1,
      ); // loot terkonfirmasi bertahan
      expect(inventory.equipmentSnapshot(), isEmpty);

      // Completion palsu di room non-final juga ditolak.
      const prematureCompleted = DungeonSession(
        runId: 'run_cheat_1',
        dungeonId: 'forgotten_forest',
        currentRoomId: 'room_1',
        currentRoomIndex: 0,
        status: DungeonSessionStatus.completed,
        clearedRoomIds: {'room_1'},
      );
      final prematureEvent = DungeonEndedEvent(
        prematureCompleted,
        DungeonSessionStatus.completed,
        reason: DungeonEndReason.completed,
        dungeon: dungeon,
      );
      final prematureRes = settlement.settleDungeonCompleted(
        event: prematureEvent,
        config: config,
        rewardProcessor: processor,
        random: Random(8),
      );
      expect(prematureRes.validCompletion, isFalse);
      expect(prematureRes.granted, isNull);
    });
  });
}
