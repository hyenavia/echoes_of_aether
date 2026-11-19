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
import 'package:echoes_of_aether/domain/entities/player_status.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/services/offline_dungeon_runner.dart';
import 'package:echoes_of_aether/domain/services/offline_progression_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _progression = ProgressionConfig(
  maxLevel: 5,
  expBase: 50,
  expGrowth: 1.5,
  baseStats: CombatStats(
    maxHp: 100,
    atk: 14,
    def: 3,
    attackSpeed: 1.5,
    critRate: 0.1,
    critDamage: 1.5,
    moveSpeed: 4.0,
    attackRange: 1.5,
  ),
  perLevel: LevelGrowth(hp: 20, atk: 3, def: 1),
);

const _items = {
  'slime_gel': ItemDefinition(
    id: 'slime_gel',
    name: 'Slime Gel',
    category: ItemCategory.material,
    maxStack: 999,
  ),
  'rusty_sword': ItemDefinition(
    id: 'rusty_sword',
    name: 'Rusty Sword',
    category: ItemCategory.equipment,
    equipment: EquipmentData(
      slot: EquipmentSlot.weapon,
      weaponType: 'sword',
      baseStats: EquipmentStats(atk: 4),
    ),
  ),
};

const _roomLayout = <String>[
  '########',
  '#......#',
  '#......#',
  '#......#',
  '########',
];

const _dungeonDef = DungeonDefinition(
  id: 'forgotten_forest',
  name: 'Forgotten Forest',
  biome: 'forest',
  startRoomId: 'r1',
  roomOrder: ['r1', 'r2', 'r3'],
  completionReward: DungeonCompletionReward(expReward: 40, goldReward: 25),
  rooms: {
    'r1': RoomDefinition(
      id: 'r1',
      dungeonId: 'forgotten_forest',
      name: 'Entrance',
      type: RoomType.normal,
      mapRef: 'r1_map',
      layout: _roomLayout,
      entryPosition: GridPoint(1, 2),
      exitPosition: GridPoint(6, 2),
      nextRoomIds: ['r2'],
      completionCondition: RoomCompletionCondition(
        type: RoomCompletionConditionType.defeatRequiredEnemies,
      ),
      spawns: [
        RoomSpawnConfig(
          id: 'g1',
          monsterId: 'forest_slime',
          position: GridPoint(3, 2),
        ),
      ],
    ),
    'r2': RoomDefinition(
      id: 'r2',
      dungeonId: 'forgotten_forest',
      name: 'Shrine',
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
          id: 'g2',
          monsterId: 'forest_elite',
          position: GridPoint(4, 2),
          isElite: true,
        ),
      ],
    ),
    'r3': RoomDefinition(
      id: 'r3',
      dungeonId: 'forgotten_forest',
      name: 'Heart',
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
          id: 'g3',
          monsterId: 'forest_boss',
          position: GridPoint(4, 2),
          isBoss: true,
        ),
      ],
    ),
  },
);

const _lethalDungeonDef = DungeonDefinition(
  id: 'lethal_cave',
  name: 'Lethal Cave',
  biome: 'cave',
  startRoomId: 'boss_room',
  roomOrder: ['boss_room'],
  rooms: {
    'boss_room': RoomDefinition(
      id: 'boss_room',
      dungeonId: 'lethal_cave',
      name: 'Doom',
      type: RoomType.boss,
      mapRef: 'doom_map',
      layout: _roomLayout,
      entryPosition: GridPoint(1, 2),
      exitPosition: GridPoint(6, 2),
      completionCondition: RoomCompletionCondition(
        type: RoomCompletionConditionType.defeatBoss,
      ),
      spawns: [
        RoomSpawnConfig(
          id: 'g_doom',
          monsterId: 'doom_boss',
          position: GridPoint(3, 2),
          isBoss: true,
        ),
      ],
    ),
  },
);

const _config = GameConfig(
  monsters: {
    'forest_slime': EnemyDefinition(
      id: 'forest_slime',
      name: 'Forest Slime',
      level: 1,
      expReward: 10,
      goldReward: 3,
      lootTableId: 'slime_loot',
      stats: CombatStats(maxHp: 30, atk: 4, def: 1, attackSpeed: 1.0),
    ),
    'forest_elite': EnemyDefinition(
      id: 'forest_elite',
      name: 'Corrupted Guardian',
      level: 2,
      isElite: true,
      expReward: 20,
      goldReward: 8,
      lootTableId: 'slime_loot',
      stats: CombatStats(maxHp: 45, atk: 5, def: 1, attackSpeed: 1.0),
    ),
    'forest_boss': EnemyDefinition(
      id: 'forest_boss',
      name: 'Ancient Heart Guardian',
      level: 3,
      isBoss: true,
      expReward: 35,
      goldReward: 15,
      lootTableId: 'slime_loot',
      stats: CombatStats(maxHp: 55, atk: 6, def: 1, attackSpeed: 1.0),
    ),
    'doom_boss': EnemyDefinition(
      id: 'doom_boss',
      name: 'Overlord',
      level: 99,
      isBoss: true,
      expReward: 500,
      goldReward: 500,
      stats: CombatStats(maxHp: 9000, atk: 300, def: 50, attackSpeed: 2.0),
    ),
  },
  revive: ReviveConfig(),
  progression: _progression,
  equipment: EquipmentConfig(),
  items: _items,
  lootTables: {
    'slime_loot': LootTable(
      id: 'slime_loot',
      entries: [
        LootEntry(
          itemId: 'slime_gel',
          chance: 1.0,
          minQuantity: 1,
          maxQuantity: 1,
        ),
        LootEntry(itemId: 'rusty_sword', chance: 0.1),
      ],
    ),
  },
  dungeons: {'forgotten_forest': _dungeonDef, 'lethal_cave': _lethalDungeonDef},
);

OfflineActivitySnapshot _configuredAutoFarm({
  String dungeonId = 'forgotten_forest',
  int? seed,
}) => OfflineActivitySnapshot(
  mode: OfflineActivityMode.autoFarming,
  state: OfflineActivityState.configured,
  selectedDungeonId: dungeonId,
  simulationSeed: seed,
);

void main() {
  const service = OfflineProgressionService();

  test('Pause Progression default tidak menghasilkan simulasi, reward, atau summary', () {
    final c = PlayerCharacter(config: _progression);
    final inv = Inventory(definitions: _items);

    final paused = service.process(
      character: c,
      inventory: inv,
      config: _config,
      session: const GameSessionSnapshot(lastSavedAtMs: 100000),
      nowMs: 100000 + const Duration(hours: 8).inMilliseconds,
    );

    expect(paused.status, OfflineProgressionStatus.paused);
    expect(paused.hasRewards, isFalse);
    expect(paused.runsAttempted, 0);
    expect(paused.updatedOfflineActivity?.pendingSummary, isNull);
    expect(c.gold, 0);
    expect(c.level, 1);
  });

  test('first launch dan zero elapsed (termasuk < 1s) aman dan tidak memajukan cursor', () {
    final c = PlayerCharacter(config: _progression);
    final inv = Inventory(definitions: _items);

    final firstLaunch = service.process(
      character: c,
      inventory: inv,
      config: _config,
      session: const GameSessionSnapshot(lastSavedAtMs: 0),
      nowMs: 100000,
    );
    expect(firstLaunch.status, OfflineProgressionStatus.firstLaunch);
    expect(firstLaunch.hasRewards, isFalse);

    final zeroElapsed = service.process(
      character: c,
      inventory: inv,
      config: _config,
      offlineActivity: _configuredAutoFarm(seed: 1),
      session: const GameSessionSnapshot(
        lastSavedAtMs: 100000,
        lastOfflineClaimAtMs: 95000,
      ),
      nowMs: 100500,
    );
    expect(zeroElapsed.status, OfflineProgressionStatus.zeroElapsed);
    expect(zeroElapsed.hasRewards, isFalse);
    expect(zeroElapsed.newLastOfflineClaimAtMs, 95000);
  });

  test(
    'durasi negatif atau timestamp masa depan ditolak aman tanpa reward',
    () {
      final c = PlayerCharacter(config: _progression);
      final inv = Inventory(definitions: _items);

      final result = service.process(
        character: c,
        inventory: inv,
        config: _config,
        offlineActivity: _configuredAutoFarm(seed: 1),
        session: const GameSessionSnapshot(
          lastSavedAtMs: 500000,
          lastOfflineClaimAtMs: 400000,
        ),
        nowMs: 300000,
      );
      expect(result.status, OfflineProgressionStatus.invalidClock);
      expect(result.hasRewards, isFalse);
      expect(result.newLastOfflineClaimAtMs, 400000);
      expect(c.gold, 0);
    },
  );

  group('Mode A — Continue Dungeon', () {
    test('melanjutkan checkpoint room terakhir, menjaga runId, selesai 1x tanpa memulai dungeon baru', () {
      final c = PlayerCharacter(
        config: _progression,
        progress: const PlayerProgress(level: 3),
      );
      final inv = Inventory(definitions: _items);
      const activeSession = ActiveDungeonSessionSnapshot(
        runId: 'active_run_77',
        dungeonId: 'forgotten_forest',
        currentRoomId: 'r2',
        currentRoomIndex: 1,
        status: DungeonSessionStatus.inProgress,
        clearedRoomIds: {'r1'},
      );
      const activity = OfflineActivitySnapshot(
        mode: OfflineActivityMode.continueDungeon,
        state: OfflineActivityState.configured,
        activeRunId: 'active_run_77',
        selectedDungeonId: 'forgotten_forest',
        simulationSeed: 21,
      );

      final result = service.process(
        character: c,
        inventory: inv,
        config: _config,
        session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
        nowMs: 1000000 + const Duration(hours: 4).inMilliseconds,
        offlineActivity: activity,
        activeDungeonSession: activeSession,
        dungeonProgress: const DungeonProgressSnapshot(
          currentDungeonId: 'forgotten_forest',
          currentRoomId: 'r2',
          currentRoomIndex: 1,
          highestClearedRoomIndex: 0,
        ),
        initialHp: 90,
      );

      expect(result.status, OfflineProgressionStatus.applied);
      expect(result.stopReason, OfflineDungeonStopReason.dungeonCompleted);
      expect(result.runsAttempted, 1);
      expect(result.runsCompleted, 1);
      expect(result.roomsCleared, 2); // r2 & r3
      expect(result.updatedActiveDungeonSession?.runId, 'active_run_77');
      expect(result.updatedActiveDungeonSession?.isRecoverable, isFalse);
      expect(result.updatedDungeonProgress?.clearsCount, 1);
      // Elite (20e, 8g) + Boss (35e, 15g) + Completion (40e, 25g) = 95 EXP, 48 Gold
      expect(result.expGained, 95);
      expect(result.goldGained, 48);
      expect(
        result.updatedOfflineActivity?.state,
        OfflineActivityState.completed,
      );
    });

    test('sesi Downed mengikuti revive M5 (30% HP + cooldown 90s) dan kalah bila boss terlalu kuat', () {
      final c = PlayerCharacter(config: _progression);
      final inv = Inventory(definitions: _items);
      const activeSession = ActiveDungeonSessionSnapshot(
        runId: 'lethal_run_1',
        dungeonId: 'lethal_cave',
        currentRoomId: 'boss_room',
        currentRoomIndex: 0,
        status: DungeonSessionStatus.inProgress,
        playerStatus: PlayerStatus.downed,
      );
      const activity = OfflineActivitySnapshot(
        mode: OfflineActivityMode.continueDungeon,
        state: OfflineActivityState.configured,
        activeRunId: 'lethal_run_1',
        selectedDungeonId: 'lethal_cave',
        simulationSeed: 9,
      );

      final result = service.process(
        character: c,
        inventory: inv,
        config: _config,
        session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
        nowMs: 1000000 + const Duration(minutes: 5).inMilliseconds,
        offlineActivity: activity,
        activeDungeonSession: activeSession,
        dungeonProgress: const DungeonProgressSnapshot(
          currentDungeonId: 'lethal_cave',
        ),
        initialHp: 0,
      );

      expect(result.status, OfflineProgressionStatus.failed);
      expect(result.stopReason, OfflineDungeonStopReason.playerDefeated);
      expect(result.runsFailed, 1);
      expect(result.updatedOfflineActivity?.state, OfflineActivityState.failed);
    });

    test('menolak activeDungeonSession tidak valid / runId mismatch', () {
      final c = PlayerCharacter(config: _progression);
      final inv = Inventory(definitions: _items);

      final res = service.process(
        character: c,
        inventory: inv,
        config: _config,
        session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
        nowMs: 1000000 + const Duration(minutes: 10).inMilliseconds,
        offlineActivity: const OfflineActivitySnapshot(
          mode: OfflineActivityMode.continueDungeon,
          state: OfflineActivityState.configured,
          activeRunId: 'expected_run',
        ),
        activeDungeonSession: const ActiveDungeonSessionSnapshot(
          runId: 'other_run',
          dungeonId: 'forgotten_forest',
          currentRoomId: 'r1',
          currentRoomIndex: 0,
          status: DungeonSessionStatus.inProgress,
        ),
      );

      expect(res.status, OfflineProgressionStatus.failed);
      expect(res.hasRewards, isFalse);
      expect(res.updatedOfflineActivity?.state, OfflineActivityState.failed);
    });
  });

  group('Mode B — Auto Farming', () {
    test('menolak Auto Farming bila dungeon belum pernah diselesaikan (clearsCount == 0)', () {
      final c = PlayerCharacter(config: _progression);
      final inv = Inventory(definitions: _items);

      final res = service.process(
        character: c,
        inventory: inv,
        config: _config,
        session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
        nowMs: 1000000 + const Duration(hours: 1).inMilliseconds,
        offlineActivity: _configuredAutoFarm(seed: 10),
        dungeonProgress: const DungeonProgressSnapshot(
          currentDungeonId: 'forgotten_forest',
          clearsCount: 0,
        ),
      );

      expect(res.status, OfflineProgressionStatus.noEligibleEncounter);
      expect(res.hasRewards, isFalse);
      expect(
        res.updatedOfflineActivity?.mode,
        OfflineActivityMode.pauseProgression,
      );
      expect(res.updatedOfflineActivity?.state, OfflineActivityState.inactive);
    });

    test('durasi normal menghasilkan multiple run, EXP, gold, loot, level up, dan deterministik', () {
      PlayerCharacter makeChar() => PlayerCharacter(config: _progression);
      Inventory makeInv() => Inventory(definitions: _items);
      const cleared = DungeonProgressSnapshot(
        currentDungeonId: 'forgotten_forest',
        clearsCount: 1,
        clearedInCycleRank: 0,
      );

      final c1 = makeChar();
      final inv1 = makeInv();
      final r1 = service.process(
        character: c1,
        inventory: inv1,
        config: _config,
        session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
        nowMs: 1000000 + const Duration(minutes: 30).inMilliseconds,
        offlineActivity: _configuredAutoFarm(seed: 7),
        dungeonProgress: cleared,
        claimedEventIds: <String>{},
      );

      final c2 = makeChar();
      final inv2 = makeInv();
      final r2 = service.process(
        character: c2,
        inventory: inv2,
        config: _config,
        session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
        nowMs: 1000000 + const Duration(minutes: 30).inMilliseconds,
        offlineActivity: _configuredAutoFarm(seed: 7),
        dungeonProgress: cleared,
        claimedEventIds: <String>{},
      );

      expect(r1.status, OfflineProgressionStatus.applied);
      expect(r1.cappedAtMaxDuration, isFalse);
      expect(r1.runsCompleted, greaterThan(0));
      expect(r1.encountersCleared, greaterThan(0));
      expect(r1.expGained, greaterThan(0));
      expect(r1.goldGained, greaterThan(0));
      expect(c1.level, greaterThan(1));
      expect(
        inv1.quantityOf('slime_gel') + (r1.overflowStacks['slime_gel'] ?? 0),
        r1.encountersCleared,
      );

      expect(r1.expGained, r2.expGained);
      expect(r1.goldGained, r2.goldGained);
      expect(c1.level, c2.level);
      expect(inv1.quantityOf('slime_gel'), inv2.quantityOf('slime_gel'));
    });

    test('durasi offline melebihi 8 jam dibatasi tepat 8 jam dan menghormati maxLevel', () {
      const cleared = DungeonProgressSnapshot(
        currentDungeonId: 'forgotten_forest',
        clearsCount: 1,
        clearedInCycleRank: 0,
      );

      final c8 = PlayerCharacter(config: _progression);
      final inv8 = Inventory(definitions: _items);
      final r8 = service.process(
        character: c8,
        inventory: inv8,
        config: _config,
        session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
        nowMs: 1000000 + const Duration(hours: 8).inMilliseconds,
        offlineActivity: _configuredAutoFarm(seed: 12),
        dungeonProgress: cleared,
        maxIterations: 250000,
      );

      final c24 = PlayerCharacter(config: _progression);
      final inv24 = Inventory(definitions: _items);
      final r24 = service.process(
        character: c24,
        inventory: inv24,
        config: _config,
        session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
        nowMs: 1000000 + const Duration(hours: 24).inMilliseconds,
        offlineActivity: _configuredAutoFarm(seed: 12),
        dungeonProgress: cleared,
        maxIterations: 250000,
      );

      expect(r8.cappedAtMaxDuration, isFalse);
      expect(r24.cappedAtMaxDuration, isTrue);
      expect(r24.effectiveElapsed, const Duration(hours: 8));
      expect(r24.expGained, r8.expGained);
      expect(r24.goldGained, r8.goldGained);
      expect(c24.level, _progression.maxLevel);
      expect(c24.currentExp, 0);
    });

    test('stopOnDefeat menghentikan Auto Farming segera bila pemain kalah', () {
      final c = PlayerCharacter(config: _progression);
      final inv = Inventory(definitions: _items);

      final res = service.process(
        character: c,
        inventory: inv,
        config: _config,
        session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
        nowMs: 1000000 + const Duration(hours: 4).inMilliseconds,
        offlineActivity: _configuredAutoFarm(dungeonId: 'lethal_cave', seed: 3),
        dungeonProgress: const DungeonProgressSnapshot(
          currentDungeonId: 'lethal_cave',
          clearsCount: 1,
          clearedInCycleRank: 0,
        ),
      );

      expect(res.status, OfflineProgressionStatus.failed);
      expect(res.stopReason, OfflineDungeonStopReason.playerDefeated);
      expect(res.runsAttempted, 1);
      expect(res.runsFailed, 1);
      expect(res.updatedOfflineActivity?.state, OfflineActivityState.failed);
    });

    test('pencegahan klaim offline ganda lewat cursor, claimedEventIds, dan terminal state', () {
      final c = PlayerCharacter(config: _progression);
      final inv = Inventory(definitions: _items);
      final claimed = <String>{};
      const startMs = 1000000;
      final endMs = startMs + const Duration(hours: 1).inMilliseconds;
      const cleared = DungeonProgressSnapshot(
        currentDungeonId: 'forgotten_forest',
        clearsCount: 1,
        clearedInCycleRank: 0,
      );

      final first = service.process(
        character: c,
        inventory: inv,
        config: _config,
        session: const GameSessionSnapshot(lastSavedAtMs: startMs),
        nowMs: endMs,
        offlineActivity: _configuredAutoFarm(seed: 5),
        dungeonProgress: cleared,
        claimedEventIds: claimed,
      );
      expect(first.status, OfflineProgressionStatus.applied);
      final goldAfterFirst = c.gold;

      // State completed tidak boleh di-replay.
      final replayTerminal = service.process(
        character: c,
        inventory: inv,
        config: _config,
        session: const GameSessionSnapshot(lastSavedAtMs: startMs),
        nowMs: endMs + 60000,
        offlineActivity: first.updatedOfflineActivity!,
        dungeonProgress: cleared,
        claimedEventIds: claimed,
      );
      expect(replayTerminal.status, OfflineProgressionStatus.alreadyClaimed);
      expect(c.gold, goldAfterFirst);

      // EventId sama dengan snapshot baru juga ditolak.
      final dupByEvent = service.process(
        character: c,
        inventory: inv,
        config: _config,
        session: const GameSessionSnapshot(lastSavedAtMs: startMs),
        nowMs: endMs,
        offlineActivity: _configuredAutoFarm(seed: 5),
        dungeonProgress: cleared,
        claimedEventIds: claimed,
      );
      expect(dupByEvent.status, OfflineProgressionStatus.alreadyClaimed);
      expect(c.gold, goldAfterFirst);

      // Cursor lastOfflineClaimAtMs >= nowMs juga ditolak.
      final dupByCursor = service.process(
        character: c,
        inventory: inv,
        config: _config,
        session: GameSessionSnapshot(
          lastSavedAtMs: startMs,
          lastOfflineClaimAtMs: endMs,
        ),
        nowMs: endMs,
        offlineActivity: _configuredAutoFarm(seed: 5),
        dungeonProgress: cleared,
        claimedEventIds: <String>{},
      );
      expect(dupByCursor.status, OfflineProgressionStatus.alreadyClaimed);
      expect(c.gold, goldAfterFirst);
    });

    test('karakter lebih kuat meraih efisiensi lebih tinggi dibanding karakter lemah', () {
      const cleared = DungeonProgressSnapshot(
        currentDungeonId: 'forgotten_forest',
        clearsCount: 1,
        clearedInCycleRank: 0,
      );
      final weakChar = PlayerCharacter(config: _progression);
      final strongChar =
          PlayerCharacter(
              config: _progression,
              progress: const PlayerProgress(level: 4),
            )
            ..loadout.equip(
              const EquipmentInstance(
                id: 'eq_w',
                definitionId: 'rusty_sword',
                slot: EquipmentSlot.weapon,
                rarity: ItemRarity.epic,
                rolledStats: EquipmentStats(atk: 25, hp: 100, def: 10),
              ),
            );

      final rWeak = service.process(
        character: weakChar,
        inventory: Inventory(definitions: _items),
        config: _config,
        session: const GameSessionSnapshot(lastSavedAtMs: 1000),
        nowMs: 1000 + const Duration(minutes: 20).inMilliseconds,
        offlineActivity: _configuredAutoFarm(seed: 1),
        dungeonProgress: cleared,
      );
      final rStrong = service.process(
        character: strongChar,
        inventory: Inventory(definitions: _items),
        config: _config,
        session: const GameSessionSnapshot(lastSavedAtMs: 1000),
        nowMs: 1000 + const Duration(minutes: 20).inMilliseconds,
        offlineActivity: _configuredAutoFarm(seed: 1),
        dungeonProgress: cleared,
      );

      expect(rStrong.runsCompleted, greaterThan(rWeak.runsCompleted));
      expect(rStrong.encountersCleared, greaterThan(rWeak.encountersCleared));
    });

    test('Auto-sell Common & Uncommon gear saat Offline Farming mengonversi gear sampah ke Gold dan menjaga tas tetap bersih', () {
      const commonDagger = ItemDefinition(
        id: 'common_dagger',
        name: 'Common Dagger',
        category: ItemCategory.equipment,
        rarity: ItemRarity.common,
        sellValue: 40,
        equipment: EquipmentData(
          slot: EquipmentSlot.weapon,
          weaponType: 'dagger',
          baseStats: EquipmentStats(atk: 5),
        ),
      );
      const rareDagger = ItemDefinition(
        id: 'rare_dagger',
        name: 'Rare Dagger',
        category: ItemCategory.equipment,
        rarity: ItemRarity.rare,
        sellValue: 300,
        equipment: EquipmentData(
          slot: EquipmentSlot.weapon,
          weaponType: 'dagger',
          baseStats: EquipmentStats(atk: 25),
        ),
      );

      final customItems = {
        ..._items,
        commonDagger.id: commonDagger,
        rareDagger.id: rareDagger,
      };

      const customLootTable = LootTable(
        id: 'test_auto_sell_loot',
        entries: [
          LootEntry(
            itemId: 'common_dagger',
            chance: 1.0,
            minQuantity: 1,
            maxQuantity: 1,
          ),
          LootEntry(
            itemId: 'rare_dagger',
            chance: 1.0,
            minQuantity: 1,
            maxQuantity: 1,
          ),
        ],
      );

      final customMonsters = {
        ..._config.monsters,
        'forest_slime': const EnemyDefinition(
          id: 'forest_slime',
          name: 'Slime',
          level: 1,
          expReward: 10,
          goldReward: 5,
          lootTableId: 'test_auto_sell_loot',
          stats: CombatStats(maxHp: 1, atk: 1, def: 0),
        ),
      };

      final customConfig = GameConfig(
        monsters: customMonsters,
        damage: _config.damage,
        difficulty: _config.difficulty,
        farming: _config.farming,
        revive: _config.revive,
        progression: _progression,
        equipment: _config.equipment,
        dungeonCompletion: _config.dungeonCompletion,
        items: customItems,
        lootTables: {
          ..._config.lootTables,
          customLootTable.id: customLootTable,
        },
        skills: _config.skills,
        specializations: _config.specializations,
        dungeons: _config.dungeons,
      );

      final char = PlayerCharacter(config: _progression);
      final inv = Inventory(definitions: customItems);
      const cleared = DungeonProgressSnapshot(
        currentDungeonId: 'forgotten_forest',
        clearsCount: 1,
        clearedInCycleRank: 0,
      );

      final result = service.process(
        character: char,
        inventory: inv,
        config: customConfig,
        session: const GameSessionSnapshot(lastSavedAtMs: 1000),
        nowMs: 1000 + const Duration(minutes: 5).inMilliseconds,
        offlineActivity: _configuredAutoFarm(seed: 42),
        dungeonProgress: cleared,
      );

      // Run harus selesai minimal 1x
      expect(result.runsCompleted, greaterThanOrEqualTo(1));

      // Common Dagger otomatis terjual -> tidak masuk ke tas
      expect(
        inv.equipmentSnapshot().any((e) => e.definitionId == 'common_dagger'),
        isFalse,
      );

      // Rare Dagger TIDAK otomatis terjual -> masuk ke tas
      expect(
        inv.equipmentSnapshot().any((e) => e.definitionId == 'rare_dagger'),
        isTrue,
      );

      // Statistik auto-sold tercatat
      expect(result.autoSoldEquipmentCount, greaterThan(0));
      expect(result.autoSoldEquipmentGold, greaterThan(0));

      // Gold karakter bertambah dan mencakup auto-sold equipment
      expect(char.gold, result.goldGained);
      expect(result.goldGained, greaterThan(result.autoSoldEquipmentGold));
    });
  });
}
