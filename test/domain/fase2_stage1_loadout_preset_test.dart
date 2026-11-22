import 'dart:math';

import 'package:drift/native.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/equipment_config.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/loadout_preset.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/entities/specialization.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/loadout_preset_service.dart';
import 'package:echoes_of_aether/domain/services/save_snapshot_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const progression = ProgressionConfig(
    maxLevel: 90,
    expBase: 100,
    expGrowth: 2.0,
    baseStats: CombatStats(maxHp: 100, atk: 10, def: 5),
    perLevel: LevelGrowth(hp: 10, atk: 2, def: 1),
  );

  const specConfig = SpecializationConfig(
    unlockLevel: 10,
    definitions: {
      'vanguard': SpecializationDefinition(
        id: 'vanguard',
        name: 'Vanguard',
        description: 'Tank',
        bonus: EquipmentStats(hp: 50, def: 10),
      ),
      'arcanist': SpecializationDefinition(
        id: 'arcanist',
        name: 'Arcanist',
        description: 'Mage',
        bonus: EquipmentStats(atk: 20),
      ),
      'paladin': SpecializationDefinition(
        id: 'paladin',
        name: 'Paladin',
        description: 'Mythical Tank',
        rarity: ItemRarity.mythical,
        bonus: EquipmentStats(hp: 80, atk: 10, def: 15),
      ),
    },
  );

  const swordA = ItemDefinition(
    id: 'sword_a',
    name: 'Sword A',
    category: ItemCategory.equipment,
    rarity: ItemRarity.rare,
    equipment: EquipmentData(
      slot: EquipmentSlot.weapon,
      weaponType: 'sword',
      baseStats: EquipmentStats(atk: 15),
    ),
  );

  const staffB = ItemDefinition(
    id: 'staff_b',
    name: 'Staff B',
    category: ItemCategory.equipment,
    rarity: ItemRarity.epic,
    equipment: EquipmentData(
      slot: EquipmentSlot.weapon,
      weaponType: 'staff',
      baseStats: EquipmentStats(atk: 30),
    ),
  );

  const helmA = ItemDefinition(
    id: 'helm_a',
    name: 'Helm A',
    category: ItemCategory.equipment,
    rarity: ItemRarity.common,
    equipment: EquipmentData(
      slot: EquipmentSlot.head,
      baseStats: EquipmentStats(hp: 40),
    ),
  );

  final config = GameConfig(
    monsters: const {},
    revive: const ReviveConfig(),
    progression: progression,
    lootTables: const {},
    items: const {'sword_a': swordA, 'staff_b': staffB, 'helm_a': helmA},
    specializations: specConfig,
    dungeons: const {
      'forgotten_forest': DungeonDefinition(
        id: 'forgotten_forest',
        name: 'Forgotten Forest',
        biome: 'forest',
        startRoomId: 'forest_entrance',
        roomOrder: ['forest_entrance'],
        rooms: {
          'forest_entrance': RoomDefinition(
            id: 'forest_entrance',
            dungeonId: 'forgotten_forest',
            name: 'Forest Entrance',
            type: RoomType.normal,
            mapRef: 'test_map',
            layout: ['###', '#.#', '###'],
            entryPosition: GridPoint(1, 1),
            exitPosition: GridPoint(1, 1),
            spawns: [],
            completionCondition: RoomCompletionCondition(),
          ),
        },
      ),
    },
  );

  const eqFactory = EquipmentFactory(EquipmentConfig(rollVariance: 0.0));
  const presetService = LoadoutPresetService();

  group('Fase 2 Stage 1 — LoadoutPreset Domain & Persistence', () {
    test('captureCurrentBuild & applyPreset switch specialization, swap gear, and recalculate finalStats', () {
      final rng = Random(1);
      final inv = Inventory(definitions: config.items);
      final char = PlayerCharacter(
        config: progression,
        progress: const PlayerProgress(level: 20),
        specializationConfig: specConfig,
      );

      final eqSword = eqFactory.create(
        instanceId: 'eq_sword_1',
        definition: swordA,
        random: rng,
      );
      final eqStaff = eqFactory.create(
        instanceId: 'eq_staff_1',
        definition: staffB,
        random: rng,
      );
      final eqHelm = eqFactory.create(
        instanceId: 'eq_helm_1',
        definition: helmA,
        random: rng,
      );
      inv.addEquipment(eqSword);
      inv.addEquipment(eqStaff);
      inv.addEquipment(eqHelm);

      // Setup Build 1: Vanguard + Sword A + Helm A
      expect(char.chooseSpecialization('vanguard'), isTrue);
      char.loadout.equip(inv.takeEquipment('eq_sword_1')!);
      char.loadout.equip(inv.takeEquipment('eq_helm_1')!);
      final preset1 = presetService.captureCurrentBuild(
        slotIndex: 0,
        character: char,
      );
      final vanguardAtk = char.stats.atk;

      // Ubah ke Build 2: Arcanist + Staff B (tanpa helm)
      expect(char.chooseSpecialization('arcanist'), isTrue);
      inv.addEquipment(char.loadout.equip(inv.takeEquipment('eq_staff_1')!)!);
      inv.addEquipment(char.loadout.unequip(EquipmentSlot.head)!);
      final preset2 = presetService.captureCurrentBuild(
        slotIndex: 1,
        character: char,
      );
      expect(char.stats.atk, greaterThan(vanguardAtk));

      // Terapkan kembali Preset 1 -> Vanguard + Sword A + Helm A
      final res1 = presetService.applyPreset(
        preset: preset1,
        character: char,
        inventory: inv,
        unlockedSpecializations: const {'vanguard', 'arcanist'},
      );
      expect(res1.appliedSpecialization, isTrue);
      expect(res1.equippedCount, 2);
      expect(res1.missingItemCount, 0);
      expect(char.specializationId, 'vanguard');
      expect(char.loadout.instanceIn(EquipmentSlot.weapon)?.id, 'eq_sword_1');
      expect(char.loadout.instanceIn(EquipmentSlot.head)?.id, 'eq_helm_1');
      expect(char.stats.atk, vanguardAtk);
      expect(inv.equipmentById('eq_staff_1'), isNotNull);

      // Terapkan kembali Preset 2 -> Arcanist + Staff B, dan helm dilepas ke tas
      final res2 = presetService.applyPreset(
        preset: preset2,
        character: char,
        inventory: inv,
        unlockedSpecializations: const {'vanguard', 'arcanist'},
      );
      expect(res2.appliedSpecialization, isTrue);
      expect(res2.equippedCount, 1);
      expect(res2.unequippedCount, 1);
      expect(char.specializationId, 'arcanist');
      expect(char.loadout.instanceIn(EquipmentSlot.weapon)?.id, 'eq_staff_1');
      expect(char.loadout.instanceIn(EquipmentSlot.head), isNull);
      expect(inv.equipmentById('eq_helm_1'), isNotNull);
    });

    test('applyPreset skips locked specialization and missing items safely without data loss', () {
      final rng = Random(2);
      final inv = Inventory(definitions: config.items);
      final char = PlayerCharacter(
        config: progression,
        progress: const PlayerProgress(level: 20),
        specializationConfig: specConfig,
        initialSpecializationId: 'vanguard',
      );
      final eqSword = eqFactory.create(
        instanceId: 'eq_sword_keep',
        definition: swordA,
        random: rng,
      );
      char.loadout.equip(eqSword);

      const lockedPreset = LoadoutPreset(
        slotIndex: 2,
        name: 'Preset 3',
        specializationId: 'paladin',
        equipmentInstanceIds: {EquipmentSlot.weapon: 'eq_missing_weapon'},
      );

      final res = presetService.applyPreset(
        preset: lockedPreset,
        character: char,
        inventory: inv,
        unlockedSpecializations: const {'vanguard', 'arcanist'},
      );

      expect(res.appliedSpecialization, isFalse);
      expect(res.specializationSkipped, isTrue);
      expect(res.missingItemCount, 1);
      expect(res.hasChanges, isFalse);
      expect(char.specializationId, 'vanguard');
      expect(
        char.loadout.instanceIn(EquipmentSlot.weapon)?.id,
        'eq_sword_keep',
      );
    });

    test('SaveSnapshotCodec & DriftPlayerSaveRepository round-trip persist loadoutPresets cleanly', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DriftPlayerSaveRepository(db: db, config: config);

      final rng = Random(3);
      final eqSword = eqFactory.create(
        instanceId: 'eq_1',
        definition: swordA,
        random: rng,
      );
      const presets = [
        LoadoutPreset(
          slotIndex: 0,
          name: 'Preset 1',
          specializationId: 'vanguard',
          equipmentInstanceIds: {EquipmentSlot.weapon: 'eq_1'},
        ),
        LoadoutPreset(
          slotIndex: 2,
          name: 'Preset 3',
          specializationId: 'arcanist',
          equipmentInstanceIds: {},
        ),
      ];

      final snapshot = PlayerSaveSnapshot(
        character: PlayerCharacterSnapshot(
          progress: const PlayerProgress(level: 20, gold: 500),
          specializationId: 'vanguard',
          equipped: {EquipmentSlot.weapon: eqSword},
        ),
        inventory: const InventorySnapshot(equipmentCounter: 1),
        unlockedSpecializations: const {'vanguard', 'arcanist'},
        loadoutPresets: presets,
      );

      // 1) SaveSnapshotCodec round-trip
      const codec = SaveSnapshotCodec();
      final encodedJson = codec.encodeToCanonicalJson(snapshot);
      final decodedCodec = codec.decodeFromCanonicalJson(
        encodedJson,
        config: config,
      );
      expect(decodedCodec.loadoutPresets, presets);

      // Snapshot tanpa preset tidak memancarkan key 'loadoutPresets'
      final emptyJson = codec.encodeToCanonicalJson(
        snapshot.copyWith(loadoutPresets: const []),
      );
      expect(emptyJson.contains('loadoutPresets'), isFalse);

      // 2) Drift SQLite round-trip
      await repo.saveSnapshot(snapshot);
      final reloaded = await repo.loadSnapshot();
      expect(reloaded, isNotNull);
      expect(reloaded!.loadoutPresets, presets);
    });
  });
}
