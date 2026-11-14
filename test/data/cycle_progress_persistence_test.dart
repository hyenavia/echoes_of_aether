import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/difficulty_config.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/domain/entities/specialization.dart';
import 'package:echoes_of_aether/domain/services/ascension_service.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:flutter_test/flutter_test.dart';

const _layout = <String>['#####', '#...#', '#####'];

DungeonDefinition _makeDungeon({
  required String id,
  required int order,
  DungeonKind kind = DungeonKind.normal,
  String? unlockRequiresDungeonId,
  String? baseDungeonId,
}) {
  final roomId = '${id}_r1';
  return DungeonDefinition(
    id: id,
    name: id,
    biome: 'test',
    kind: kind,
    order: order,
    recommendedLevel: order * 5,
    unlockRequiresDungeonId: unlockRequiresDungeonId,
    baseDungeonId: baseDungeonId,
    startRoomId: roomId,
    roomOrder: [roomId],
    rooms: {
      roomId: RoomDefinition(
        id: roomId,
        dungeonId: id,
        name: '$id Room',
        type: RoomType.normal,
        mapRef: roomId,
        layout: _layout,
        entryPosition: const GridPoint(1, 1),
        exitPosition: const GridPoint(3, 1),
        completionCondition: const RoomCompletionCondition(
          type: RoomCompletionConditionType.reachExit,
        ),
        spawns: const [],
      ),
    },
  );
}

GameConfig _makeConfig() {
  return GameConfig(
    monsters: const {},
    revive: const ReviveConfig(),
    progression: const ProgressionConfig(
      maxLevel: 40,
      baseStats: CombatStats(
        maxHp: 180,
        atk: 25,
        def: 6,
        attackSpeed: 1.5,
        moveSpeed: 4.0,
        attackRange: 1.5,
      ),
      perLevel: LevelGrowth(hp: 25, atk: 5, def: 2),
    ),
    difficulty: const DifficultyConfig(),
    items: const {
      'slime_gel': ItemDefinition(
        id: 'slime_gel',
        name: 'Slime Gel',
        category: ItemCategory.material,
        maxStack: 999,
      ),
      'oak_sword': ItemDefinition(
        id: 'oak_sword',
        name: 'Oak Sword',
        category: ItemCategory.equipment,
        equipment: EquipmentData(
          slot: EquipmentSlot.weapon,
          baseStats: EquipmentStats(atk: 18),
          weaponType: 'sword',
        ),
      ),
    },
    lootTables: const {},
    skills: const {
      'arcane_bolt': SkillDefinition(
        id: 'arcane_bolt',
        name: 'Arcane Bolt',
        type: SkillType.active,
        cooldownSeconds: 3.0,
        damageMultiplier: 1.8,
        unlockLevel: 1,
        specializationId: 'arcanist',
      ),
    },
    specializations: const SpecializationConfig(
      definitions: {
        'arcanist': SpecializationDefinition(
          id: 'arcanist',
          name: 'Arcanist',
          description: 'Caster',
          unlockLevel: 10,
          bonus: EquipmentStats(atk: 20),
        ),
      },
    ),
    dungeons: {
      'forgotten_forest': _makeDungeon(id: 'forgotten_forest', order: 1),
      'whispering_woods': _makeDungeon(
        id: 'whispering_woods',
        order: 2,
        unlockRequiresDungeonId: 'forgotten_forest',
      ),
      'deep_cavern': _makeDungeon(
        id: 'deep_cavern',
        order: 3,
        unlockRequiresDungeonId: 'whispering_woods',
      ),
      'shadow_ruins': _makeDungeon(
        id: 'shadow_ruins',
        order: 4,
        unlockRequiresDungeonId: 'deep_cavern',
      ),
      'aether_sanctum': _makeDungeon(
        id: 'aether_sanctum',
        order: 5,
        unlockRequiresDungeonId: 'shadow_ruins',
      ),
      'ascension_sanctum': _makeDungeon(
        id: 'ascension_sanctum',
        order: 6,
        kind: DungeonKind.ascension,
        unlockRequiresDungeonId: 'aether_sanctum',
        baseDungeonId: 'aether_sanctum',
      ),
    },
  );
}

void main() {
  group('M9 Stage 1 — CycleProgress & Ascension Persistence', () {
    test('DriftPlayerSaveRepository saves, loads, and sanitizes CycleProgress directly', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final config = _makeConfig();
      final warnings = <String>[];
      final repo = DriftPlayerSaveRepository(
        db: db,
        config: config,
        onRecoveryWarning: warnings.add,
      );

      final initial = await repo.loadCycleProgress();
      expect(initial.ascensionRank, 0);
      expect(initial.lastNormalDungeonId, isNull);

      await repo.saveCycleProgress(
        const CycleProgress(
          ascensionRank: 3,
          lastNormalDungeonId: 'shadow_ruins',
        ),
      );
      final loaded = await repo.loadCycleProgress();
      expect(loaded.ascensionRank, 3);
      expect(loaded.lastNormalDungeonId, 'shadow_ruins');

      // Sanitization against non-normal / unknown dungeon id on load & save.
      await repo.saveCycleProgress(
        const CycleProgress(
          ascensionRank: 2,
          lastNormalDungeonId: 'ascension_sanctum',
        ),
      );
      final sanitized = await repo.loadCycleProgress();
      expect(sanitized.ascensionRank, 2);
      expect(sanitized.lastNormalDungeonId, isNull);
      expect(warnings.any((w) => w.contains('lastNormalDungeonId')), isTrue);
    });

    test('atomic saveCycleTransition persists Ascension rank, resets cycle clears, logs claimedEventId, and preserves player character/inventory/clearsCount across restart', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final config = _makeConfig();
      var repo = DriftPlayerSaveRepository(db: db, config: config);
      var coordinator = GameSessionCoordinator(
        repository: repo,
        config: config,
        nowMs: () => 1000000,
      );

      const equippedSword = EquipmentInstance(
        id: 'eq_10',
        definitionId: 'oak_sword',
        slot: EquipmentSlot.weapon,
        rarity: ItemRarity.rare,
        rolledStats: EquipmentStats(atk: 24, critRate: 0.05),
      );
      const bagSword = EquipmentInstance(
        id: 'eq_11',
        definitionId: 'oak_sword',
        slot: EquipmentSlot.weapon,
        rarity: ItemRarity.common,
        rolledStats: EquipmentStats(atk: 17),
      );

      final initialProgresses = <String, DungeonProgressSnapshot>{
        'forgotten_forest': const DungeonProgressSnapshot(
          currentDungeonId: 'forgotten_forest',
          currentRoomId: 'forgotten_forest_r1',
          clearsCount: 4,
          clearedInCycleRank: 0,
        ),
        'whispering_woods': const DungeonProgressSnapshot(
          currentDungeonId: 'whispering_woods',
          currentRoomId: 'whispering_woods_r1',
          clearsCount: 3,
          clearedInCycleRank: 0,
        ),
        'deep_cavern': const DungeonProgressSnapshot(
          currentDungeonId: 'deep_cavern',
          currentRoomId: 'deep_cavern_r1',
          clearsCount: 2,
          clearedInCycleRank: 0,
        ),
        'shadow_ruins': const DungeonProgressSnapshot(
          currentDungeonId: 'shadow_ruins',
          currentRoomId: 'shadow_ruins_r1',
          clearsCount: 2,
          clearedInCycleRank: 0,
        ),
        'aether_sanctum': const DungeonProgressSnapshot(
          currentDungeonId: 'aether_sanctum',
          currentRoomId: 'aether_sanctum_r1',
          clearsCount: 1,
          clearedInCycleRank: 0,
        ),
      };

      await coordinator.saveSnapshot(
        PlayerSaveSnapshot(
          character: PlayerCharacterSnapshot(
            progress: const PlayerProgress(
              level: 22,
              currentExp: 650,
              gold: 4800,
            ),
            specializationId: 'arcanist',
            skillLevels: const {'arcane_bolt': 4},
            equipped: const {EquipmentSlot.weapon: equippedSword},
            currentHp: 500,
          ),
          inventory: const InventorySnapshot(
            stacks: {'slime_gel': 29},
            equipment: [bagSword],
            equipmentCounter: 11,
          ),
          dungeon: initialProgresses['aether_sanctum']!,
          dungeonProgresses: initialProgresses,
          cycleProgress: const CycleProgress(
            ascensionRank: 0,
            lastNormalDungeonId: 'aether_sanctum',
          ),
          session: const GameSessionSnapshot(
            lastActiveAtMs: 999000,
            lastSavedAtMs: 999000,
            lastOfflineClaimAtMs: 999000,
          ),
        ),
      );

      const ascensionService = AscensionService();
      final result = ascensionService.complete(
        runId: 'persist_asc_01',
        dungeons: config.dungeons.values,
        cycleProgress: const CycleProgress(
          ascensionRank: 0,
          lastNormalDungeonId: 'aether_sanctum',
        ),
        dungeonProgresses: initialProgresses,
      );

      await coordinator.saveCycleTransition(
        cycleProgress: result.cycleProgress,
        dungeonProgresses: result.dungeonProgresses,
        claimEventId: result.eventId,
        updatedAtMs: 1000500,
      );

      // Simulate restart with fresh repository & coordinator over the same DB.
      repo = DriftPlayerSaveRepository(db: db, config: config);
      coordinator = GameSessionCoordinator(
        repository: repo,
        config: config,
        nowMs: () => 1001000,
      );
      final reloaded = await repo.loadSnapshot();
      expect(reloaded, isNotNull);

      expect(reloaded!.cycleProgress.ascensionRank, 1);
      expect(reloaded.cycleProgress.lastNormalDungeonId, 'forgotten_forest');
      expect(
        reloaded.claimedEventIds.contains('ascension:persist_asc_01'),
        isTrue,
      );

      // Cycle markers reset while lifetime clearsCount stay completely intact.
      expect(reloaded.dungeonProgresses['forgotten_forest']!.clearsCount, 4);
      expect(
        reloaded.dungeonProgresses['forgotten_forest']!.clearedInCycleRank,
        -1,
      );
      expect(reloaded.dungeonProgresses['aether_sanctum']!.clearsCount, 1);
      expect(
        reloaded.dungeonProgresses['aether_sanctum']!.clearedInCycleRank,
        -1,
      );

      // Character progression, specialization, skills, gold, inventory, and gear untouched.
      expect(reloaded.character.progress.level, 22);
      expect(reloaded.character.progress.currentExp, 650);
      expect(reloaded.character.progress.gold, 4800);
      expect(reloaded.character.specializationId, 'arcanist');
      expect(reloaded.character.skillLevels['arcane_bolt'], 4);
      expect(reloaded.character.equipped[EquipmentSlot.weapon]?.id, 'eq_10');
      expect(reloaded.inventory.stacks['slime_gel'], 29);
      expect(reloaded.inventory.equipment.single.id, 'eq_11');

      // Re-running Ascension completion after restart with loaded claimedEventIds is idempotent.
      final replay = ascensionService.complete(
        runId: 'persist_asc_01',
        dungeons: config.dungeons.values,
        cycleProgress: reloaded.cycleProgress,
        dungeonProgresses: reloaded.dungeonProgresses,
        claimedEventIds: reloaded.claimedEventIds,
      );
      expect(replay.alreadyCompleted, isTrue);
      expect(replay.cycleProgress.ascensionRank, 1);
    });

    test('GameSessionCoordinator.saveFromRuntime preserves "ascension:" claimed event IDs and serializes queued writes', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final config = _makeConfig();
      final warnings = <String>[];
      final repo = DriftPlayerSaveRepository(
        db: db,
        config: config,
        onRecoveryWarning: warnings.add,
      );
      final coordinator = GameSessionCoordinator(
        repository: repo,
        config: config,
        nowMs: () => 2000000,
      );

      final character = PlayerCharacter(config: config.progression);
      final inventory = Inventory(definitions: config.items);
      final rewardProcessor = RewardProcessor(
        character: character,
        inventory: inventory,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: EquipmentFactory(config.equipment),
      );
      rewardProcessor.markClaimed('ascension:runtime_run_7');
      rewardProcessor.markClaimed('transient_room_event');

      const initialForest = DungeonProgressSnapshot(
        currentDungeonId: 'forgotten_forest',
        currentRoomId: 'forgotten_forest_r1',
        clearsCount: 1,
        clearedInCycleRank: -1,
      );

      await coordinator.saveFromRuntime(
        character: character,
        inventory: inventory,
        rewardProcessor: rewardProcessor,
        dungeon: initialForest,
        dungeonProgresses: const {'forgotten_forest': initialForest},
        cycleProgress: const CycleProgress(
          ascensionRank: 1,
          lastNormalDungeonId: 'forgotten_forest',
        ),
        lastOfflineClaimAtMs: 2000000,
        autoSkillEnabled: true,
      );

      // Concurrent sequential writes through _saveQueue settle cleanly in order.
      await Future.wait([
        coordinator.saveCycleProgress(
          const CycleProgress(
            ascensionRank: 1,
            lastNormalDungeonId: 'deep_cavern',
          ),
        ),
        coordinator.saveCycleProgress(
          const CycleProgress(
            ascensionRank: 1,
            lastNormalDungeonId: 'shadow_ruins',
          ),
        ),
      ]);

      final reloaded = await repo.loadSnapshot();
      expect(reloaded, isNotNull);
      expect(
        reloaded!.claimedEventIds.contains('ascension:runtime_run_7'),
        isTrue,
      );
      expect(
        reloaded.claimedEventIds.contains('transient_room_event'),
        isFalse,
      );
      expect(reloaded.cycleProgress.ascensionRank, 1);
      expect(reloaded.cycleProgress.lastNormalDungeonId, 'shadow_ruins');
    });
  });
}
