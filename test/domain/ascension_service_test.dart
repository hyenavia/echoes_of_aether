import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/equipment_config.dart';
import 'package:echoes_of_aether/domain/entities/equipment_loadout.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/domain/entities/specialization.dart';
import 'package:echoes_of_aether/domain/services/ascension_service.dart';
import 'package:echoes_of_aether/domain/services/dungeon_progression_service.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:flutter_test/flutter_test.dart';

const _testLayout = <String>['#####', '#...#', '#####'];

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
        type: kind == DungeonKind.ascension ? RoomType.boss : RoomType.normal,
        mapRef: roomId,
        layout: _testLayout,
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

List<DungeonDefinition> _fiveNormalCatalog({bool includeAscension = true}) {
  return [
    _makeDungeon(id: 'forgotten_forest', order: 1),
    _makeDungeon(
      id: 'whispering_woods',
      order: 2,
      unlockRequiresDungeonId: 'forgotten_forest',
    ),
    _makeDungeon(
      id: 'deep_cavern',
      order: 3,
      unlockRequiresDungeonId: 'whispering_woods',
    ),
    _makeDungeon(
      id: 'shadow_ruins',
      order: 4,
      unlockRequiresDungeonId: 'deep_cavern',
    ),
    _makeDungeon(
      id: 'aether_sanctum',
      order: 5,
      unlockRequiresDungeonId: 'shadow_ruins',
    ),
    if (includeAscension)
      _makeDungeon(
        id: 'ascension_sanctum',
        order: 6,
        kind: DungeonKind.ascension,
        unlockRequiresDungeonId: 'aether_sanctum',
        baseDungeonId: 'aether_sanctum',
      ),
  ];
}

DungeonProgressSnapshot _progress(
  String dungeonId, {
  int clearsCount = 0,
  int clearedInCycleRank = -1,
}) {
  return DungeonProgressSnapshot(
    currentDungeonId: dungeonId,
    currentRoomId: '${dungeonId}_r1',
    clearsCount: clearsCount,
    clearedInCycleRank: clearedInCycleRank,
  );
}

void main() {
  group('CycleProgress value semantics & sanitization', () {
    test('sanitizes negative rank and whitespace dungeon ID', () {
      const defaults = CycleProgress();
      expect(defaults.ascensionRank, 0);
      expect(defaults.lastNormalDungeonId, isNull);
      expect(defaults.hasLastNormalDungeon, isFalse);

      final sanitized = CycleProgress.sanitized(
        ascensionRank: -4,
        lastNormalDungeonId: '   ',
      );
      expect(sanitized.ascensionRank, 0);
      expect(sanitized.lastNormalDungeonId, isNull);
      expect(sanitized, equals(defaults));

      final clampedCopy = const CycleProgress(
        ascensionRank: 3,
        lastNormalDungeonId: 'deep_cavern',
      ).copyWith(ascensionRank: -2);
      expect(clampedCopy.ascensionRank, 0);
      expect(clampedCopy.hasLastNormalDungeon, isTrue);

      final clearedCopy = clampedCopy.copyWith(clearLastNormalDungeonId: true);
      expect(clearedCopy.lastNormalDungeonId, isNull);
    });
  });

  group('AscensionService', () {
    const ascensionService = AscensionService();
    const progressionService = DungeonProgressionService();

    test('canEnterAscension requires Dungeon 5 clear in the current cycle', () {
      final dungeons = _fiveNormalCatalog();
      const rank0 = CycleProgress(ascensionRank: 0);

      final onlyD1ToD4Cleared = <String, DungeonProgressSnapshot>{
        'forgotten_forest': _progress(
          'forgotten_forest',
          clearsCount: 1,
          clearedInCycleRank: 0,
        ),
        'whispering_woods': _progress(
          'whispering_woods',
          clearsCount: 1,
          clearedInCycleRank: 0,
        ),
        'deep_cavern': _progress(
          'deep_cavern',
          clearsCount: 1,
          clearedInCycleRank: 0,
        ),
        'shadow_ruins': _progress(
          'shadow_ruins',
          clearsCount: 1,
          clearedInCycleRank: 0,
        ),
        'aether_sanctum': _progress(
          'aether_sanctum',
          clearsCount: 0,
          clearedInCycleRank: -1,
        ),
      };
      expect(
        ascensionService.canEnterAscension(
          dungeons: dungeons,
          cycleProgress: rank0,
          dungeonProgresses: onlyD1ToD4Cleared,
        ),
        isFalse,
      );

      final d5ClearedRank0 = {
        ...onlyD1ToD4Cleared,
        'aether_sanctum': _progress(
          'aether_sanctum',
          clearsCount: 1,
          clearedInCycleRank: 0,
        ),
      };
      expect(
        ascensionService.canEnterAscension(
          dungeons: dungeons,
          cycleProgress: rank0,
          dungeonProgresses: d5ClearedRank0,
        ),
        isTrue,
      );

      // On cycle rank 1, an older rank-0 clear does not reopen Ascension.
      expect(
        ascensionService.canEnterAscension(
          dungeons: dungeons,
          cycleProgress: const CycleProgress(ascensionRank: 1),
          dungeonProgresses: d5ClearedRank0,
        ),
        isFalse,
      );
    });

    test('complete is idempotent with eventId "ascension:{runId}" via RewardProcessor and claimedEventIds', () {
      final dungeons = _fiveNormalCatalog();
      final items = <String, ItemDefinition>{};
      final character = PlayerCharacter(
        config: const ProgressionConfig(
          baseStats: CombatStats(
            maxHp: 120,
            atk: 20,
            def: 5,
            attackSpeed: 1.5,
            moveSpeed: 4.0,
            attackRange: 1.5,
          ),
          perLevel: LevelGrowth(hp: 20, atk: 4, def: 2),
        ),
      );
      final rewardProcessor = RewardProcessor(
        character: character,
        inventory: Inventory(definitions: items),
        items: items,
        lootTables: const {},
        equipmentFactory: const EquipmentFactory(EquipmentConfig()),
      );

      const cycle = CycleProgress(
        ascensionRank: 0,
        lastNormalDungeonId: 'aether_sanctum',
      );
      final progresses = <String, DungeonProgressSnapshot>{
        for (final d in dungeons.where((d) => d.isNormal))
          d.id: _progress(d.id, clearsCount: 1, clearedInCycleRank: 0),
      };

      final first = ascensionService.complete(
        runId: 'asc_run_101',
        dungeons: dungeons,
        cycleProgress: cycle,
        dungeonProgresses: progresses,
        rewardProcessor: rewardProcessor,
      );

      expect(first.alreadyCompleted, isFalse);
      expect(first.rankIncremented, isTrue);
      expect(first.eventId, 'ascension:asc_run_101');
      expect(first.previousRank, 0);
      expect(first.newRank, 1);
      expect(first.cycleProgress.ascensionRank, 1);
      expect(first.cycleProgress.lastNormalDungeonId, 'forgotten_forest');
      expect(rewardProcessor.isClaimed('ascension:asc_run_101'), isTrue);

      // Duplicate invocation with same RewardProcessor is a strict no-op.
      final secondViaProcessor = ascensionService.complete(
        runId: 'asc_run_101',
        dungeons: dungeons,
        cycleProgress: first.cycleProgress,
        dungeonProgresses: first.dungeonProgresses,
        rewardProcessor: rewardProcessor,
      );
      expect(secondViaProcessor.alreadyCompleted, isTrue);
      expect(secondViaProcessor.rankIncremented, isFalse);
      expect(secondViaProcessor.cycleProgress.ascensionRank, 1);

      // Duplicate invocation with persisted claimedEventIds set (no RewardProcessor)
      // is also a strict no-op.
      final secondViaSet = ascensionService.complete(
        runId: 'asc_run_101',
        dungeons: dungeons,
        cycleProgress: first.cycleProgress,
        dungeonProgresses: first.dungeonProgresses,
        claimedEventIds: first.claimedEventIds,
      );
      expect(secondViaSet.alreadyCompleted, isTrue);
      expect(secondViaSet.cycleProgress.ascensionRank, 1);

      // Distinct runId can advance the next cycle.
      final nextRun = ascensionService.complete(
        runId: 'asc_run_102',
        dungeons: dungeons,
        cycleProgress: first.cycleProgress,
        dungeonProgresses: {
          for (final d in dungeons.where((d) => d.isNormal))
            d.id: _progress(d.id, clearsCount: 2, clearedInCycleRank: 1),
        },
        rewardProcessor: rewardProcessor,
      );
      expect(nextRun.alreadyCompleted, isFalse);
      expect(nextRun.cycleProgress.ascensionRank, 2);
      expect(rewardProcessor.isClaimed('ascension:asc_run_102'), isTrue);

      expect(
        () => ascensionService.complete(
          runId: '   ',
          dungeons: dungeons,
          cycleProgress: cycle,
          dungeonProgresses: progresses,
        ),
        throwsArgumentError,
      );
    });

    test('complete resets cycle clears so only Dungeon 1 is unlocked and preserves player progress, gear, inventory, and lifetime clearsCount', () {
      final dungeons = _fiveNormalCatalog();
      const weaponDef = ItemDefinition(
        id: 'crimson_blade',
        name: 'Crimson Blade',
        category: ItemCategory.equipment,
        equipment: EquipmentData(
          slot: EquipmentSlot.weapon,
          baseStats: EquipmentStats(atk: 25),
          weaponType: 'sword',
        ),
      );
      const potionDef = ItemDefinition(
        id: 'slime_gel',
        name: 'Slime Gel',
        category: ItemCategory.material,
        maxStack: 999,
      );
      final items = {weaponDef.id: weaponDef, potionDef.id: potionDef};
      const equippedWeapon = EquipmentInstance(
        id: 'eq_1',
        definitionId: 'crimson_blade',
        slot: EquipmentSlot.weapon,
        rarity: ItemRarity.rare,
        rolledStats: EquipmentStats(atk: 29, critRate: 0.08),
      );
      const bagAccessory = EquipmentInstance(
        id: 'eq_2',
        definitionId: 'crimson_blade',
        slot: EquipmentSlot.accessory,
        rarity: ItemRarity.uncommon,
        rolledStats: EquipmentStats(hp: 40),
      );

      final loadout = EquipmentLoadout()..equip(equippedWeapon);
      final character = PlayerCharacter(
        config: const ProgressionConfig(
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
        progress: const PlayerProgress(level: 26, currentExp: 840, gold: 12450),
        loadout: loadout,
        specializationConfig: const SpecializationConfig(
          definitions: {
            'vanguard': SpecializationDefinition(
              id: 'vanguard',
              name: 'Vanguard',
              description: 'Frontline',
              unlockLevel: 10,
              bonus: EquipmentStats(hp: 100, def: 15),
            ),
          },
        ),
        initialSpecializationId: 'vanguard',
        skillCatalog: const {
          'power_slash': SkillDefinition(
            id: 'power_slash',
            name: 'Power Slash',
            type: SkillType.active,
            cooldownSeconds: 4.0,
            damageMultiplier: 2.0,
          ),
        },
        skillLevels: const {'power_slash': 5},
      );
      final inventory = Inventory(definitions: items);
      inventory.add('slime_gel', 42);
      inventory.addEquipment(bagAccessory);

      final rewardProcessor = RewardProcessor(
        character: character,
        inventory: inventory,
        items: items,
        lootTables: const {},
        equipmentFactory: const EquipmentFactory(EquipmentConfig()),
      );

      final beforeLevel = character.progress.level;
      final beforeExp = character.progress.currentExp;
      final beforeGold = character.progress.gold;
      final beforeSpec = character.specializationId;
      final beforeSkillLv = character.skillLevel('power_slash');
      final beforeEquipped = character.loadout.equipped;
      final beforeSnapshot = inventory.toSnapshot();
      final beforeStacks = Map<String, int>.from(beforeSnapshot.stacks);
      final beforeEquipmentCount = beforeSnapshot.equipment.length;

      final progresses = <String, DungeonProgressSnapshot>{
        'forgotten_forest': _progress(
          'forgotten_forest',
          clearsCount: 7,
          clearedInCycleRank: 0,
        ),
        'whispering_woods': _progress(
          'whispering_woods',
          clearsCount: 5,
          clearedInCycleRank: 0,
        ),
        'deep_cavern': _progress(
          'deep_cavern',
          clearsCount: 4,
          clearedInCycleRank: 0,
        ),
        'shadow_ruins': _progress(
          'shadow_ruins',
          clearsCount: 3,
          clearedInCycleRank: 0,
        ),
        'aether_sanctum': _progress(
          'aether_sanctum',
          clearsCount: 2,
          clearedInCycleRank: 0,
        ),
      };

      final result = ascensionService.complete(
        runId: 'asc_preserve_test',
        dungeons: dungeons,
        cycleProgress: const CycleProgress(
          ascensionRank: 0,
          lastNormalDungeonId: 'aether_sanctum',
        ),
        dungeonProgresses: progresses,
        rewardProcessor: rewardProcessor,
      );

      // Cycle progression reset check: only Dungeon 1 unlocked; D2..D5 & Ascension locked.
      expect(result.cycleProgress.ascensionRank, 1);
      expect(result.cycleProgress.lastNormalDungeonId, 'forgotten_forest');
      expect(
        progressionService.isUnlocked(
          dungeons[0],
          result.cycleProgress,
          result.dungeonProgresses,
          allDungeons: dungeons,
        ),
        isTrue,
      );
      for (final lockedDungeon in dungeons.skip(1)) {
        expect(
          progressionService.isUnlocked(
            lockedDungeon,
            result.cycleProgress,
            result.dungeonProgresses,
            allDungeons: dungeons,
          ),
          isFalse,
          reason: '${lockedDungeon.id} should be locked after ascension reset',
        );
      }

      // Lifetime clearsCount must remain untouched while clearedInCycleRank resets to -1.
      expect(result.dungeonProgresses['forgotten_forest']!.clearsCount, 7);
      expect(
        result.dungeonProgresses['forgotten_forest']!.clearedInCycleRank,
        -1,
      );
      expect(result.dungeonProgresses['whispering_woods']!.clearsCount, 5);
      expect(result.dungeonProgresses['deep_cavern']!.clearsCount, 4);
      expect(result.dungeonProgresses['shadow_ruins']!.clearsCount, 3);
      expect(result.dungeonProgresses['aether_sanctum']!.clearsCount, 2);
      expect(
        result.dungeonProgresses['aether_sanctum']!.clearedInCycleRank,
        -1,
      );

      // Player state and inventory/equipment remain 100% preserved.
      expect(character.progress.level, beforeLevel);
      expect(character.progress.currentExp, beforeExp);
      expect(character.progress.gold, beforeGold);
      expect(character.specializationId, beforeSpec);
      expect(character.skillLevel('power_slash'), beforeSkillLv);
      expect(character.loadout.equipped, beforeEquipped);
      final afterSnapshot = inventory.toSnapshot();
      expect(afterSnapshot.stacks, beforeStacks);
      expect(afterSnapshot.equipment.length, beforeEquipmentCount);
      expect(afterSnapshot.equipment.first.id, 'eq_2');
    });

    test('handles peak world rank (Rank 5 Peak) and upper bound safely without overflow', () {
      final dungeons = _fiveNormalCatalog();
      final progresses = {
        for (final d in dungeons.where((d) => d.isNormal))
          d.id: _progress(d.id, clearsCount: 5, clearedInCycleRank: 5),
      };

      final capped = ascensionService.complete(
        runId: 'peak_rank_run',
        dungeons: dungeons,
        cycleProgress: const CycleProgress(
          ascensionRank: AscensionService.kPeakWorldRank,
          lastNormalDungeonId: 'aether_sanctum',
        ),
        dungeonProgresses: progresses,
      );

      expect(capped.previousRank, 5);
      expect(capped.newRank, 5);
      expect(capped.cycleProgress.ascensionRank, 5);
      expect(capped.cycleProgress.ascensionRank.isNegative, isFalse);
      expect(capped.isPeakWorldTier, isTrue);
      expect(capped.isAetherAscendant, isTrue);

      // Dengan custom maxRank lebih tinggi (mis. simulasi legacy tanpa cap):
      const customService = AscensionService(maxRank: 1000000);
      final r1001 = customService.complete(
        runId: 'high_rank_run',
        dungeons: dungeons,
        cycleProgress: const CycleProgress(
          ascensionRank: 1000,
          lastNormalDungeonId: 'aether_sanctum',
        ),
        dungeonProgresses: progresses,
      );
      expect(r1001.previousRank, 1000);
      expect(r1001.newRank, 1001);
      expect(r1001.cycleProgress.ascensionRank, 1001);
    });
  });

  group('DungeonProgressionService — Farm Dungeon & titik respawn M9', () {
    const progression = DungeonProgressionService();

    test('kalah di dungeon normal menjaga titik kembali di dungeon normal tersebut', () {
      final dungeons = _fiveNormalCatalog();
      var cycle = const CycleProgress(
        ascensionRank: 0,
        lastNormalDungeonId: 'forgotten_forest',
      );
      final progresses = <String, DungeonProgressSnapshot>{
        'forgotten_forest': _progress(
          'forgotten_forest',
          clearsCount: 1,
          clearedInCycleRank: 0,
        ),
        'whispering_woods': _progress(
          'whispering_woods',
          clearsCount: 1,
          clearedInCycleRank: 0,
        ),
      };

      // Pemain memasuki deep_cavern (terbuka, belum clear) lalu kalah.
      cycle = progression.recordDungeonEntered(cycle, dungeons[2]);
      expect(cycle.lastNormalDungeonId, 'deep_cavern');

      final respawn = progression.resolveRespawnDungeonId(
        dungeons: dungeons,
        cycle: cycle,
        progresses: progresses,
        exitedDungeonId: 'deep_cavern',
      );
      expect(respawn, 'deep_cavern');

      // Farm dungeon masih memilih dungeon tertinggi yang benar-benar clear (D2).
      final farmTarget = progression.resolveFarmDungeonId(
        dungeons: dungeons,
        cycle: cycle,
        progresses: progresses,
      );
      expect(farmTarget, 'whispering_woods');
    });

    test('kalah di Ascension mempertahankan titik kembali dungeon normal sebelum Ascension', () {
      final dungeons = _fiveNormalCatalog();
      final progresses = <String, DungeonProgressSnapshot>{
        for (final d in dungeons.where((d) => d.isNormal))
          d.id: _progress(d.id, clearsCount: 1, clearedInCycleRank: 0),
      };

      // Sebelum masuk Ascension, pemain bermain di shadow_ruins (D4).
      var cycle = const CycleProgress(
        ascensionRank: 0,
        lastNormalDungeonId: 'shadow_ruins',
      );

      // Masuk Ascension tidak menimpa lastNormalDungeonId.
      cycle = progression.recordDungeonEntered(cycle, dungeons.last);
      expect(cycle.lastNormalDungeonId, 'shadow_ruins');

      // Kalah / keluar dari Ascension mengembalikan target ke shadow_ruins.
      final respawn = progression.resolveRespawnDungeonId(
        dungeons: dungeons,
        cycle: cycle,
        progresses: progresses,
        exitedDungeonId: 'ascension_sanctum',
      );
      expect(respawn, 'shadow_ruins');

      // Farm dungeon juga menghormati lastNormalDungeonId jika sudah clear di siklus ini.
      final farmTarget = progression.resolveFarmDungeonId(
        dungeons: dungeons,
        cycle: cycle,
        progresses: progresses,
      );
      expect(farmTarget, 'shadow_ruins');
    });
  });
}
