import 'dart:math';

import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/combat_event.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_reward.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/equipment_config.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/loot_table.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/domain/entities/specialization.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/equipment_service.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:echoes_of_aether/domain/services/offline_progression_service.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:flutter_test/flutter_test.dart';

const _boss = EnemyDefinition(
  id: 'guardian',
  name: 'Guardian',
  level: 3,
  isBoss: true,
  expReward: 140,
  goldReward: 80,
  lootTableId: 'boss_loot',
  stats: CombatStats(maxHp: 35, atk: 2, def: 0),
);

const _slime = EnemyDefinition(
  id: 'forest_slime',
  name: 'Slime',
  level: 1,
  expReward: 15,
  goldReward: 5,
  lootTableId: 'slime_loot',
  stats: CombatStats(maxHp: 30, atk: 3, def: 0),
);

const _roomLayout = <String>[
  '########',
  '#......#',
  '#......#',
  '#......#',
  '########',
];

const _config = GameConfig(
  monsters: {'forest_slime': _slime, 'guardian': _boss},
  revive: ReviveConfig(),
  progression: ProgressionConfig(
    maxLevel: 10,
    expBase: 50,
    expGrowth: 1.5,
    baseStats: CombatStats(
      maxHp: 120,
      atk: 20,
      def: 3,
      attackSpeed: 1.5,
      critRate: 0.1,
      critDamage: 1.5,
      moveSpeed: 4.0,
      attackRange: 1.5,
    ),
    perLevel: LevelGrowth(hp: 20, atk: 3, def: 1),
  ),
  items: {
    'slime_gel': ItemDefinition(
      id: 'slime_gel',
      name: 'Slime Gel',
      category: ItemCategory.material,
      maxStack: 999,
    ),
    'aether_blade': ItemDefinition(
      id: 'aether_blade',
      name: 'Aether Blade',
      category: ItemCategory.equipment,
      rarity: ItemRarity.epic,
      equipment: EquipmentData(
        slot: EquipmentSlot.weapon,
        weaponType: 'sword',
        baseStats: EquipmentStats(atk: 12),
      ),
    ),
  },
  lootTables: {
    'slime_loot': LootTable(
      id: 'slime_loot',
      entries: [
        LootEntry(
          itemId: 'slime_gel',
          chance: 1.0,
          minQuantity: 2,
          maxQuantity: 2,
        ),
      ],
    ),
    'boss_loot': LootTable(
      id: 'boss_loot',
      entries: [LootEntry(itemId: 'aether_blade', chance: 1.0)],
    ),
    'clear_loot': LootTable(
      id: 'clear_loot',
      entries: [
        LootEntry(
          itemId: 'slime_gel',
          chance: 1.0,
          minQuantity: 5,
          maxQuantity: 5,
        ),
      ],
    ),
  },
  dungeonCompletion: DungeonCompletionReward(
    expReward: 60,
    goldReward: 40,
    lootTableId: 'clear_loot',
  ),
  skills: {
    'power_strike': SkillDefinition(
      id: 'power_strike',
      name: 'Power Strike',
      type: SkillType.active,
      effect: SkillEffectType.damage,
      damageType: SkillDamageType.physical,
      unlockLevel: 2,
      maxLevel: 5,
      upgradeCost: 25,
      cooldownSeconds: 4,
      baseValue: 1.5,
    ),
    'vitality': SkillDefinition(
      id: 'vitality',
      name: 'Vitality',
      type: SkillType.passive,
      effect: SkillEffectType.statModifier,
      unlockLevel: 3,
      maxLevel: 5,
      upgradeCost: 30,
      passiveStats: EquipmentStats(hp: 30, def: 2),
    ),
  },
  specializations: SpecializationConfig(
    unlockLevel: 3,
    definitions: {
      'vanguard': SpecializationDefinition(
        id: 'vanguard',
        name: 'Vanguard',
        bonus: EquipmentStats(hp: 60, def: 3),
        attackRange: 1.5,
        skillAffinities: {'vitality': 0.25},
      ),
    },
  ),
  dungeons: {
    'forgotten_forest': DungeonDefinition(
      id: 'forgotten_forest',
      name: 'Forgotten Forest',
      biome: 'forest',
      startRoomId: 'ancient_heart',
      roomOrder: ['ancient_heart'],
      completionReward: DungeonCompletionReward(
        expReward: 60,
        goldReward: 40,
        lootTableId: 'clear_loot',
      ),
      rooms: {
        'ancient_heart': RoomDefinition(
          id: 'ancient_heart',
          dungeonId: 'forgotten_forest',
          name: 'Ancient Heart',
          type: RoomType.boss,
          mapRef: 'heart_map',
          layout: _roomLayout,
          entryPosition: GridPoint(1, 2),
          exitPosition: GridPoint(6, 2),
          completionCondition: RoomCompletionCondition(
            type: RoomCompletionConditionType.defeatBoss,
          ),
          spawns: [
            RoomSpawnConfig(
              id: 'boss_wave',
              monsterId: 'guardian',
              position: GridPoint(4, 2),
              isBoss: true,
            ),
          ],
        ),
      },
    ),
  },
);

void main() {
  group('M4 Phase F — Persistence & Offline Integration', () {
    test('alur lengkap lintas sesi: combat -> loot/inventory -> equip -> skill upgrade '
        '-> specialization -> dungeon clear -> save -> reload -> offline 2 jam -> idempotency', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      var clockMs = 1000000;
      final repo = DriftPlayerSaveRepository(db: db, config: _config);
      final session1Coord = GameSessionCoordinator(
        repository: repo,
        config: _config,
        nowMs: () => clockMs,
      );

      // Sesi 1: First launch.
      final boot1 = await session1Coord.loadAndProcessOffline();
      expect(boot1.isFirstLaunch, isTrue);
      expect(boot1.offlineResult.hasRewards, isFalse);

      final char1 = boot1.character;
      final inv1 = boot1.inventory;
      final reward1 = boot1.rewardProcessor;

      // Combat melawan boss -> dapat EXP, gold, dan aether_blade.
      final combatant = Combatant(
        id: 'player',
        team: Team.player,
        stats: char1.stats,
        cell: const GridPoint(1, 1),
      );
      final sim = CombatSimulation(
        grid: NavigationGrid.open(columns: 8, rows: 4),
        pathfinder: const AStarPathfinder(),
        player: combatant,
        seed: 1,
      );
      sim.spawnEnemy(_boss, const GridPoint(2, 1));
      for (var i = 0; i < 60 && sim.aliveEnemies.isNotEmpty; i++) {
        sim.tick();
        for (final event in sim.drainEvents().whereType<EnemyDefeatedEvent>()) {
          reward1.processEnemyDefeated(
            eventId: 'enemy:${event.tick}:${event.enemyId}',
            definition: event.definition,
            random: Random(3),
          );
        }
      }
      // EXP 140: lv1(50) + lv2(75) = 125 -> lv3 sisa 15 EXP; Gold = 80
      expect(char1.level, 3);
      expect(char1.gold, 80);

      // Equip weapon drop + pilih specialization + upgrade skill
      final blade = inv1.equipmentSnapshot().single;
      expect(
        EquipmentService(
          inventory: inv1,
          loadout: char1.loadout,
        ).equip(blade.id),
        isTrue,
      );
      expect(char1.chooseSpecialization('vanguard'), isTrue);
      expect(
        char1.upgradeSkill('power_strike').succeeded,
        isTrue,
      ); // -25 gold -> 55
      expect(
        char1.upgradeSkill('vitality').succeeded,
        isTrue,
      ); // -30 gold -> 25

      // Selesaikan dungeon completion via RewardProcessor
      reward1.processDungeonCompletion(
        eventId: 'dungeon_clear:run_1',
        reward: _config.dungeonCompletion,
        random: Random(4),
      );
      // +60 EXP -> 15+60 = 75 (lv3 butuh 113 -> tetap lv3, currentExp=75); gold 25+40=65
      expect(char1.gold, 65);
      final preSaveStats = char1.stats;

      // Simpan state sesi 1 ke SQLite dengan Mode B Auto Farming terkonfigurasi.
      clockMs = 2000000;
      const clearedForest = DungeonProgressSnapshot(
        currentDungeonId: 'forgotten_forest',
        currentRoomId: 'ancient_heart',
        currentRoomIndex: 0,
        highestClearedRoomIndex: 0,
        clearsCount: 1,
        clearedInCycleRank: 0,
      );
      await session1Coord.saveFromRuntime(
        character: char1,
        inventory: inv1,
        dungeon: clearedForest,
        rewardProcessor: reward1,
        autoSkillEnabled: false,
        lastOfflineClaimAtMs: boot1.offlineResult.newLastOfflineClaimAtMs,
        offlineActivity: const OfflineActivitySnapshot(
          mode: OfflineActivityMode.autoFarming,
          state: OfflineActivityState.configured,
          selectedDungeonId: 'forgotten_forest',
          simulationSeed: 42,
        ),
      );

      // Sesi 2: Simulasi aplikasi ditutup 2 jam, lalu dibuka kembali dengan instance baru!
      clockMs = 2000000 + const Duration(hours: 2).inMilliseconds;
      final session2Coord = GameSessionCoordinator(
        repository: DriftPlayerSaveRepository(db: db, config: _config),
        config: _config,
        nowMs: () => clockMs,
      );

      final boot2 = await session2Coord.loadAndProcessOffline();
      expect(boot2.isFirstLaunch, isFalse);
      expect(boot2.offlineResult.status, OfflineProgressionStatus.applied);
      expect(boot2.offlineResult.expGained, greaterThan(0));
      expect(boot2.offlineResult.goldGained, greaterThan(0));

      // State pra-offline + offline terakumulasi tepat tanpa duplikasi modifier.
      expect(boot2.session.autoSkillEnabled, isFalse);
      expect(boot2.dungeon.clearsCount, greaterThan(1));
      expect(boot2.character.specializationId, 'vanguard');
      expect(boot2.character.skillLevel('power_strike'), 2);
      expect(boot2.character.skillLevel('vitality'), 2);
      expect(
        boot2.character.loadout.instanceIn(EquipmentSlot.weapon)?.id,
        blade.id,
      );
      expect(boot2.character.stats.atk, greaterThanOrEqualTo(preSaveStats.atk));

      // Event dungeon_clear:run_1 tetap terlindungi lintas restart!
      final replayClear = boot2.rewardProcessor.processDungeonCompletion(
        eventId: 'dungeon_clear:run_1',
        reward: _config.dungeonCompletion,
        random: Random(9),
      );
      expect(replayClear.alreadyClaimed, isTrue);

      // Restart seketika di timestamp yang sama tidak memberi offline reward kedua kali.
      final boot3 = await session2Coord.loadAndProcessOffline();
      expect(boot3.offlineResult.hasRewards, isFalse);
      expect(
        boot3.offlineResult.status,
        OfflineProgressionStatus.alreadyClaimed,
      );
    });

    test('default Pause Progression pada DB tidak menghasilkan reward setelah 2 jam offline', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      var clockMs = 1000000;
      final repo = DriftPlayerSaveRepository(db: db, config: _config);
      final coord1 = GameSessionCoordinator(
        repository: repo,
        config: _config,
        nowMs: () => clockMs,
      );
      final boot1 = await coord1.loadAndProcessOffline();
      await coord1.saveFromRuntime(
        character: boot1.character,
        inventory: boot1.inventory,
        dungeon: const DungeonProgressSnapshot(clearsCount: 1),
        rewardProcessor: boot1.rewardProcessor,
        autoSkillEnabled: true,
        lastOfflineClaimAtMs: boot1.offlineResult.newLastOfflineClaimAtMs,
      );

      clockMs += const Duration(hours: 2).inMilliseconds;
      final boot2 = await coord1.loadAndProcessOffline();
      expect(boot2.offlineResult.status, OfflineProgressionStatus.paused);
      expect(boot2.offlineResult.hasRewards, isFalse);
      expect(boot2.character.gold, 0);
    });

    test('antrean save berurutan mencegah race condition antar pemanggilan save konkuren', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      final repo = DriftPlayerSaveRepository(db: db, config: _config);
      final coordinator = GameSessionCoordinator(
        repository: repo,
        config: _config,
        nowMs: () => 50000,
      );

      final c = PlayerCharacter(config: _config.progression);
      final inv = Inventory(definitions: _config.items);
      final rp = RewardProcessor(
        character: c,
        inventory: inv,
        items: _config.items,
        lootTables: _config.lootTables,
        equipmentFactory: const EquipmentFactory(EquipmentConfig()),
      );

      // Trigger dua perubahan cepat secara bersamaan -> antrean memastikan state final (gold=200) menang.
      c.receiveReward(gold: 50);
      final f1 = coordinator.saveFromRuntime(
        character: c,
        inventory: inv,
        dungeon: const DungeonProgressSnapshot(),
        rewardProcessor: rp,
        autoSkillEnabled: true,
        lastOfflineClaimAtMs: 50000,
      );
      c.receiveReward(gold: 150);
      final f2 = coordinator.saveFromRuntime(
        character: c,
        inventory: inv,
        dungeon: const DungeonProgressSnapshot(),
        rewardProcessor: rp,
        autoSkillEnabled: true,
        lastOfflineClaimAtMs: 50000,
      );

      await Future.wait([f1, f2]);
      final loaded = await repo.loadSnapshot();
      expect(loaded!.character.progress.gold, 200);
    });
  });
}
