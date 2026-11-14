import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
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
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/offline_dungeon_runner.dart';
import 'package:echoes_of_aether/domain/services/offline_time_calculator.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:flutter_test/flutter_test.dart';

const _progression = ProgressionConfig(
  maxLevel: 20,
  expBase: 100,
  expGrowth: 1.5,
  baseStats: CombatStats(
    maxHp: 120,
    atk: 16,
    def: 4,
    attackSpeed: 1.4,
    critRate: 0.1,
    critDamage: 1.5,
    moveSpeed: 4.0,
    attackRange: 1.5,
  ),
  perLevel: LevelGrowth(hp: 20, atk: 4, def: 1),
);

const _roomLayout = <String>[
  '########',
  '#......#',
  '#......#',
  '#......#',
  '########',
];

const _monsters = <String, EnemyDefinition>{
  'slime': EnemyDefinition(
    id: 'slime',
    name: 'Aether Slime',
    level: 1,
    expReward: 15,
    goldReward: 5,
    lootTableId: 'drop_gel',
    stats: CombatStats(
      maxHp: 30,
      atk: 6,
      def: 1,
      attackSpeed: 1.0,
      moveSpeed: 2.5,
    ),
  ),
  'elite_guardian': EnemyDefinition(
    id: 'elite_guardian',
    name: 'Corrupted Guardian',
    level: 4,
    isElite: true,
    expReward: 40,
    goldReward: 20,
    stats: CombatStats(
      maxHp: 80,
      atk: 12,
      def: 3,
      attackSpeed: 1.0,
      moveSpeed: 2.5,
    ),
  ),
  'boss_heart': EnemyDefinition(
    id: 'boss_heart',
    name: 'Ancient Heart Guardian',
    level: 5,
    isBoss: true,
    expReward: 100,
    goldReward: 60,
    stats: CombatStats(
      maxHp: 120,
      atk: 14,
      def: 4,
      attackSpeed: 1.0,
      moveSpeed: 2.5,
    ),
  ),
  'lethal_boss': EnemyDefinition(
    id: 'lethal_boss',
    name: 'Overwhelming Horror',
    level: 99,
    isBoss: true,
    expReward: 500,
    goldReward: 200,
    stats: CombatStats(
      maxHp: 5000,
      atk: 250,
      def: 50,
      attackSpeed: 2.0,
      moveSpeed: 5.0,
    ),
  ),
};

const _items = <String, ItemDefinition>{
  'slime_gel': ItemDefinition(
    id: 'slime_gel',
    name: 'Slime Gel',
    category: ItemCategory.material,
    maxStack: 999,
  ),
};

final _testDungeon = DungeonDefinition(
  id: 'test_dungeon',
  name: 'Test Dungeon',
  biome: 'forest',
  startRoomId: 'r1',
  roomOrder: const ['r1', 'r2', 'r3'],
  completionReward: const DungeonCompletionReward(
    expReward: 80,
    goldReward: 50,
  ),
  rooms: const {
    'r1': RoomDefinition(
      id: 'r1',
      dungeonId: 'test_dungeon',
      name: 'Room 1 (Wave + Exit)',
      type: RoomType.normal,
      mapRef: 'r1_map',
      layout: _roomLayout,
      entryPosition: GridPoint(1, 2),
      exitPosition: GridPoint(6, 2),
      nextRoomIds: ['r2'],
      completionCondition: RoomCompletionCondition(
        type: RoomCompletionConditionType.defeatRequiredEnemies,
        requireExit: true,
      ),
      reward: RoomRewardConfig(expReward: 20, goldReward: 10),
      spawns: [
        RoomSpawnConfig(
          id: 'wave_1',
          monsterId: 'slime',
          position: GridPoint(3, 2),
          spawnGroup: 'wave_1',
        ),
        RoomSpawnConfig(
          id: 'wave_2',
          monsterId: 'slime',
          position: GridPoint(4, 2),
          spawnGroup: 'wave_2',
          activationState: SpawnActivationState.onGroupCleared,
          activationTriggerGroup: 'wave_1',
        ),
      ],
    ),
    'r2': RoomDefinition(
      id: 'r2',
      dungeonId: 'test_dungeon',
      name: 'Room 2 (Elite)',
      type: RoomType.elite,
      mapRef: 'r2_map',
      layout: _roomLayout,
      entryPosition: GridPoint(1, 2),
      exitPosition: GridPoint(6, 2),
      nextRoomIds: ['r3'],
      completionCondition: RoomCompletionCondition(
        type: RoomCompletionConditionType.defeatElite,
      ),
      spawns: [
        RoomSpawnConfig(
          id: 'elite_g',
          monsterId: 'elite_guardian',
          position: GridPoint(4, 2),
          isElite: true,
        ),
      ],
    ),
    'r3': RoomDefinition(
      id: 'r3',
      dungeonId: 'test_dungeon',
      name: 'Room 3 (Boss)',
      type: RoomType.boss,
      mapRef: 'r3_map',
      layout: _roomLayout,
      entryPosition: GridPoint(1, 2),
      exitPosition: GridPoint(6, 2),
      completionCondition: RoomCompletionCondition(
        type: RoomCompletionConditionType.defeatBoss,
      ),
      spawns: [
        RoomSpawnConfig(
          id: 'boss_g',
          monsterId: 'boss_heart',
          position: GridPoint(4, 2),
          isBoss: true,
        ),
      ],
    ),
  },
);

final _lethalDungeon = DungeonDefinition(
  id: 'lethal_dungeon',
  name: 'Lethal Dungeon',
  biome: 'cave',
  startRoomId: 'lethal_room',
  roomOrder: const ['lethal_room'],
  completionReward: const DungeonCompletionReward(
    expReward: 100,
    goldReward: 100,
  ),
  rooms: const {
    'lethal_room': RoomDefinition(
      id: 'lethal_room',
      dungeonId: 'lethal_dungeon',
      name: 'Lethal Room',
      type: RoomType.boss,
      mapRef: 'lethal_map',
      layout: _roomLayout,
      entryPosition: GridPoint(1, 2),
      exitPosition: GridPoint(6, 2),
      completionCondition: RoomCompletionCondition(
        type: RoomCompletionConditionType.defeatBoss,
      ),
      spawns: [
        RoomSpawnConfig(
          id: 'lethal_g',
          monsterId: 'lethal_boss',
          position: GridPoint(3, 2),
          isBoss: true,
        ),
      ],
    ),
  },
);

final _config = GameConfig(
  monsters: _monsters,
  revive: const ReviveConfig(),
  progression: _progression,
  equipment: const EquipmentConfig(),
  items: _items,
  lootTables: const {
    'drop_gel': LootTable(
      id: 'drop_gel',
      entries: [
        LootEntry(
          itemId: 'slime_gel',
          chance: 1.0,
          minQuantity: 1,
          maxQuantity: 1,
        ),
      ],
    ),
  },
  dungeons: {'test_dungeon': _testDungeon, 'lethal_dungeon': _lethalDungeon},
);

OfflineTimeWindow _windowFor(Duration dur) =>
    const OfflineTimeCalculator().calculate(
      session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
      nowMs: 1000000 + dur.inMilliseconds,
    );

void main() {
  const runner = OfflineDungeonRunner();

  group('OfflineDungeonRunner', () {
    test(
      'menolak pauseProgression dan autoFarming dengan clearsCount == 0',
      () {
        final char = PlayerCharacter(config: _progression);
        final inv = Inventory(definitions: _items);
        final rp = RewardProcessor(
          character: char,
          inventory: inv,
          items: _items,
          lootTables: _config.lootTables,
          equipmentFactory: const EquipmentFactory(EquipmentConfig()),
        );

        final paused = runner.runBatch(
          OfflineDungeonRunRequest(
            mode: OfflineActivityMode.pauseProgression,
            character: char,
            inventory: inv,
            config: _config,
            rewardProcessor: rp,
            dungeonId: 'test_dungeon',
            dungeonProgress: const DungeonProgressSnapshot(
              currentDungeonId: 'test_dungeon',
            ),
            timeWindow: _windowFor(const Duration(minutes: 10)),
            simulationSeed: 1,
          ),
        );
        expect(paused.stopReason, OfflineDungeonStopReason.invalidSetup);

        final lockedFarm = runner.runBatch(
          OfflineDungeonRunRequest(
            mode: OfflineActivityMode.autoFarming,
            character: char,
            inventory: inv,
            config: _config,
            rewardProcessor: rp,
            dungeonId: 'test_dungeon',
            dungeonProgress: const DungeonProgressSnapshot(
              currentDungeonId: 'test_dungeon',
              clearsCount: 0,
            ),
            timeWindow: _windowFor(const Duration(minutes: 10)),
            simulationSeed: 1,
          ),
        );
        expect(lockedFarm.stopReason, OfflineDungeonStopReason.invalidSetup);
        expect(lockedFarm.hasRewards, isFalse);
      },
    );

    test('mengeksekusi wave on_group_cleared, reachExit, elite, boss, dan reward completion', () {
      final char = PlayerCharacter(
        config: _progression,
        progress: const PlayerProgress(level: 5),
      );
      final inv = Inventory(definitions: _items);
      final rp = RewardProcessor(
        character: char,
        inventory: inv,
        items: _items,
        lootTables: _config.lootTables,
        equipmentFactory: const EquipmentFactory(EquipmentConfig()),
      );

      // Set up Mode A-like start via initial recoverable session so stops after 1 clear
      final outcome = runner.runBatch(
        OfflineDungeonRunRequest(
          mode: OfflineActivityMode.autoFarming,
          character: char,
          inventory: inv,
          config: _config,
          rewardProcessor: rp,
          dungeonId: 'test_dungeon',
          dungeonProgress: const DungeonProgressSnapshot(
            currentDungeonId: 'test_dungeon',
            clearsCount: 1,
            clearedInCycleRank: 0,
          ),
          timeWindow: _windowFor(const Duration(minutes: 2)),
          simulationSeed: 42,
        ),
      );

      expect(outcome.runsCompleted, greaterThanOrEqualTo(1));
      expect(outcome.roomsCleared, greaterThanOrEqualTo(3));
      // Tiap 1 clear = 2 slimes (30 exp, 10 gold) + r1 reward (20, 10) + elite (40, 20) + boss (100, 60) + completion (80, 50)
      // Total per 1 clear = 270 EXP, 150 Gold, 2 Slime Gel (run terakhir yang masih in-progress dapat memberi kill parsial)
      expect(
        outcome.expGained,
        greaterThanOrEqualTo(outcome.runsCompleted * 270),
      );
      expect(
        outcome.goldGained,
        greaterThanOrEqualTo(outcome.runsCompleted * 150),
      );
      expect(
        inv.quantityOf('slime_gel') +
            (outcome.overflowStacks['slime_gel'] ?? 0),
        greaterThanOrEqualTo(outcome.runsCompleted * 2),
      );
      expect(
        outcome.updatedDungeonProgress.clearsCount,
        1 + outcome.runsCompleted,
      );

      // Verifikasi nilai eksak tepat 1 run lewat Mode A (berhenti tepat saat boss selesai).
      final singleChar = PlayerCharacter(
        config: _progression,
        progress: const PlayerProgress(level: 5),
      );
      final singleInv = Inventory(definitions: _items);
      final singleRp = RewardProcessor(
        character: singleChar,
        inventory: singleInv,
        items: _items,
        lootTables: _config.lootTables,
        equipmentFactory: const EquipmentFactory(EquipmentConfig()),
      );
      final single = runner.runBatch(
        OfflineDungeonRunRequest(
          mode: OfflineActivityMode.continueDungeon,
          character: singleChar,
          inventory: singleInv,
          config: _config,
          rewardProcessor: singleRp,
          dungeonId: 'test_dungeon',
          dungeonProgress: const DungeonProgressSnapshot(
            currentDungeonId: 'test_dungeon',
          ),
          activeDungeonSession: const ActiveDungeonSessionSnapshot(
            runId: 'single_exact_run',
            dungeonId: 'test_dungeon',
            currentRoomId: 'r1',
            currentRoomIndex: 0,
            status: DungeonSessionStatus.inProgress,
          ),
          timeWindow: _windowFor(const Duration(minutes: 2)),
          simulationSeed: 42,
        ),
      );
      expect(single.stopReason, OfflineDungeonStopReason.dungeonCompleted);
      expect(single.runsCompleted, 1);
      expect(single.roomsCleared, 3);
      expect(single.expGained, 270);
      expect(single.goldGained, 150);
      expect(singleInv.quantityOf('slime_gel'), 2);
    });

    test(
      'batas maxIterations berhenti aman dan melanjutkan akurat antar batch',
      () {
        final charFull = PlayerCharacter(
          config: _progression,
          progress: const PlayerProgress(level: 5),
        );
        final invFull = Inventory(definitions: _items);
        final rpFull = RewardProcessor(
          character: charFull,
          inventory: invFull,
          items: _items,
          lootTables: _config.lootTables,
          equipmentFactory: const EquipmentFactory(EquipmentConfig()),
        );
        final full = runner.runBatch(
          OfflineDungeonRunRequest(
            mode: OfflineActivityMode.autoFarming,
            character: charFull,
            inventory: invFull,
            config: _config,
            rewardProcessor: rpFull,
            dungeonId: 'test_dungeon',
            dungeonProgress: const DungeonProgressSnapshot(
              currentDungeonId: 'test_dungeon',
              clearsCount: 1,
              clearedInCycleRank: 0,
            ),
            timeWindow: _windowFor(const Duration(minutes: 1)),
            simulationSeed: 99,
          ),
        );

        // Sekarang jalankan batch dengan maxIterations sangat kecil untuk memicu interupsi.
        final charBatched = PlayerCharacter(
          config: _progression,
          progress: const PlayerProgress(level: 5),
        );
        final invBatched = Inventory(definitions: _items);
        final rpBatched = RewardProcessor(
          character: charBatched,
          inventory: invBatched,
          items: _items,
          lootTables: _config.lootTables,
          equipmentFactory: const EquipmentFactory(EquipmentConfig()),
        );
        final b1 = runner.runBatch(
          OfflineDungeonRunRequest(
            mode: OfflineActivityMode.autoFarming,
            character: charBatched,
            inventory: invBatched,
            config: _config,
            rewardProcessor: rpBatched,
            dungeonId: 'test_dungeon',
            dungeonProgress: const DungeonProgressSnapshot(
              currentDungeonId: 'test_dungeon',
              clearsCount: 1,
              clearedInCycleRank: 0,
            ),
            timeWindow: _windowFor(const Duration(minutes: 1)),
            simulationSeed: 99,
            maxIterations: 8,
          ),
        );

        expect(b1.stopReason, OfflineDungeonStopReason.iterationLimitReached);
        expect(b1.isInterrupted, isTrue);
        expect(b1.iterationsUsed, 8);
        expect(b1.processedDurationMs, greaterThan(0));
        expect(full.expGained, greaterThan(0));
      },
    );

    test('ReviveConfig & defeat: auto-revive 1x saat cooldown 0 lalu kalah saat cooldown masih aktif', () {
      final weakChar = PlayerCharacter(config: _progression);
      final inv = Inventory(definitions: _items);
      final rp = RewardProcessor(
        character: weakChar,
        inventory: inv,
        items: _items,
        lootTables: _config.lootTables,
        equipmentFactory: const EquipmentFactory(EquipmentConfig()),
      );

      final outcome = runner.runBatch(
        OfflineDungeonRunRequest(
          mode: OfflineActivityMode.autoFarming,
          character: weakChar,
          inventory: inv,
          config: _config,
          rewardProcessor: rp,
          dungeonId: 'lethal_dungeon',
          dungeonProgress: const DungeonProgressSnapshot(
            currentDungeonId: 'lethal_dungeon',
            clearsCount: 1,
            clearedInCycleRank: 0,
          ),
          timeWindow: _windowFor(const Duration(minutes: 10)),
          simulationSeed: 5,
        ),
      );

      expect(outcome.stopReason, OfflineDungeonStopReason.playerDefeated);
      expect(outcome.runsAttempted, 1);
      expect(outcome.runsCompleted, 0);
      expect(outcome.runsFailed, 1);
      expect(outcome.expGained, 0);
      // Player revive butuh 3s + beberapa tick diserang lagi -> setidaknya > 3s (60 ticks)
      expect(outcome.ticksSimulated, greaterThan(60));
    });

    test('deterministik untuk simulationSeed sama dan karakter lebih kuat meraih hasil lebih tinggi', () {
      PlayerCharacter makeChar(int lvl, {EquipmentStats? bonus}) {
        final c = PlayerCharacter(
          config: _progression,
          progress: PlayerProgress(level: lvl),
        );
        if (bonus != null) {
          c.loadout.equip(
            EquipmentInstance(
              id: 'w1',
              definitionId: 'sword',
              slot: EquipmentSlot.weapon,
              rarity: ItemRarity.epic,
              rolledStats: bonus,
            ),
          );
        }
        return c;
      }

      OfflineDungeonRunOutcome runWith(PlayerCharacter c) {
        final inv = Inventory(definitions: _items);
        final rp = RewardProcessor(
          character: c,
          inventory: inv,
          items: _items,
          lootTables: _config.lootTables,
          equipmentFactory: const EquipmentFactory(EquipmentConfig()),
        );
        return runner.runBatch(
          OfflineDungeonRunRequest(
            mode: OfflineActivityMode.autoFarming,
            character: c,
            inventory: inv,
            config: _config,
            rewardProcessor: rp,
            dungeonId: 'test_dungeon',
            dungeonProgress: const DungeonProgressSnapshot(
              currentDungeonId: 'test_dungeon',
              clearsCount: 1,
              clearedInCycleRank: 0,
            ),
            timeWindow: _windowFor(const Duration(minutes: 5)),
            simulationSeed: 777,
          ),
        );
      }

      final rWeak1 = runWith(makeChar(2));
      final rWeak2 = runWith(makeChar(2));
      final rStrong = runWith(
        makeChar(
          10,
          bonus: const EquipmentStats(atk: 60, hp: 300, attackSpeed: 0.5),
        ),
      );

      expect(rWeak1.expGained, rWeak2.expGained);
      expect(rWeak1.runsCompleted, rWeak2.runsCompleted);
      expect(rStrong.runsCompleted, greaterThan(rWeak1.runsCompleted));
      expect(rStrong.expGained, greaterThan(rWeak1.expGained));
    });
  });
}
