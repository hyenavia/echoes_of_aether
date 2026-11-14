import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/domain/entities/specialization.dart';
import 'package:flutter_test/flutter_test.dart';

GameConfig _testConfig({bool includeExtraItem = true}) => GameConfig(
  monsters: const {},
  revive: const ReviveConfig(),
  progression: const ProgressionConfig(
    maxLevel: 10,
    expBase: 50,
    expGrowth: 1.5,
    baseStats: CombatStats(
      maxHp: 100,
      atk: 12,
      def: 2,
      attackSpeed: 1.5,
      critRate: 0.1,
      critDamage: 1.5,
      moveSpeed: 4.0,
      attackRange: 1.5,
    ),
    perLevel: LevelGrowth(hp: 15, atk: 2, def: 1),
  ),
  items: {
    'slime_gel': const ItemDefinition(
      id: 'slime_gel',
      name: 'Slime Gel',
      category: ItemCategory.material,
      maxStack: 999,
    ),
    if (includeExtraItem)
      'legacy_potion': const ItemDefinition(
        id: 'legacy_potion',
        name: 'Legacy Potion',
        category: ItemCategory.consumable,
        maxStack: 50,
      ),
    'rusty_sword': const ItemDefinition(
      id: 'rusty_sword',
      name: 'Rusty Sword',
      category: ItemCategory.equipment,
      rarity: ItemRarity.common,
      equipment: EquipmentData(
        slot: EquipmentSlot.weapon,
        weaponType: 'sword',
        baseStats: EquipmentStats(atk: 5),
      ),
    ),
    'iron_helm': const ItemDefinition(
      id: 'iron_helm',
      name: 'Iron Helm',
      category: ItemCategory.equipment,
      rarity: ItemRarity.uncommon,
      equipment: EquipmentData(
        slot: EquipmentSlot.head,
        baseStats: EquipmentStats(hp: 20, def: 3),
      ),
    ),
  },
  lootTables: const {},
  skills: const {
    'power_strike': SkillDefinition(
      id: 'power_strike',
      name: 'Power Strike',
      type: SkillType.active,
      effect: SkillEffectType.damage,
      damageType: SkillDamageType.physical,
      unlockLevel: 2,
      maxLevel: 5,
      upgradeCost: 25,
      cooldownSeconds: 5,
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
  specializations: const SpecializationConfig(
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
);

void main() {
  group('DriftPlayerSaveRepository', () {
    test('return null saat first launch (belum ada data tersimpan)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      final repo = DriftPlayerSaveRepository(db: db, config: _testConfig());
      expect(await repo.loadSnapshot(), isNull);
      expect(await repo.load(), isNull);
    });

    test('save & load round-trip mempertahankan seluruh progres, equip, dan tanpa duplikasi saat save ulang', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();
      final config = _testConfig();
      final repo = DriftPlayerSaveRepository(db: db, config: config);

      const weapon = EquipmentInstance(
        id: 'eq_1',
        definitionId: 'rusty_sword',
        slot: EquipmentSlot.weapon,
        rarity: ItemRarity.common,
        rolledStats: EquipmentStats(atk: 5.5),
      );
      const helm = EquipmentInstance(
        id: 'eq_2',
        definitionId: 'iron_helm',
        slot: EquipmentSlot.head,
        rarity: ItemRarity.uncommon,
        rolledStats: EquipmentStats(hp: 22, def: 3.1),
      );

      final snapshot = PlayerSaveSnapshot(
        character: const PlayerCharacterSnapshot(
          progress: PlayerProgress(level: 4, currentExp: 18, gold: 140),
          specializationId: 'vanguard',
          skillLevels: {'power_strike': 3, 'vitality': 2},
          skillCooldownTicks: {'power_strike': 40},
          equipped: {EquipmentSlot.weapon: weapon},
          currentHp: 195,
        ),
        inventory: const InventorySnapshot(
          stacks: {'slime_gel': 15},
          equipment: [helm],
          equipmentCounter: 2,
        ),
        dungeon: const DungeonProgressSnapshot(
          currentDungeonId: 'forgotten_forest',
          currentRoomId: 'ruined_shrine',
          currentRoomIndex: 2,
          highestClearedRoomIndex: 1,
          clearsCount: 1,
        ),
        session: const GameSessionSnapshot(
          lastActiveAtMs: 10000,
          lastSavedAtMs: 10500,
          lastOfflineClaimAtMs: 10500,
          autoSkillEnabled: false,
        ),
        claimedEventIds: const {'offline:100:200', 'dungeon_clear:1'},
      );

      // Save dua kali berurutan — tidak boleh menduplikasi inventory / equipment / skills.
      await repo.saveSnapshot(snapshot);
      await repo.saveSnapshot(snapshot);

      final eqRows = await db.select(db.equipmentInstances).get();
      final stackRows = await db.select(db.inventoryEntries).get();
      final skillRows = await db.select(db.skillProgresses).get();
      expect(eqRows, hasLength(2));
      expect(stackRows, hasLength(1));
      expect(skillRows, hasLength(2));

      final loaded = await repo.loadSnapshot();
      expect(loaded, isNotNull);
      expect(loaded!.character.progress.level, 4);
      expect(loaded.character.progress.currentExp, 18);
      expect(loaded.character.progress.gold, 140);
      expect(loaded.character.currentHp, 195);
      expect(loaded.character.specializationId, 'vanguard');
      expect(loaded.character.skillLevels['power_strike'], 3);
      expect(loaded.character.skillCooldownTicks['power_strike'], 40);
      expect(loaded.character.equipped[EquipmentSlot.weapon]?.id, 'eq_1');
      expect(loaded.inventory.stacks['slime_gel'], 15);
      expect(loaded.inventory.equipment.single.id, 'eq_2');
      expect(loaded.inventory.equipmentCounter, 2);
      expect(loaded.dungeon.currentRoomId, 'ruined_shrine');
      expect(loaded.dungeon.currentRoomIndex, 2);
      expect(loaded.dungeon.clearsCount, 1);
      expect(loaded.session.autoSkillEnabled, isFalse);
      expect(
        loaded.claimedEventIds,
        containsAll(['offline:100:200', 'dungeon_clear:1']),
      );

      // Rekonstruksi PlayerCharacter menghitung ulang derived stats tanpa ganda.
      final restoredChar = PlayerCharacter(
        config: config.progression,
        skillCatalog: config.skills,
        specializationConfig: config.specializations,
      )..restoreSnapshot(loaded.character);
      final restoredInv = Inventory(definitions: config.items)
        ..restore(loaded.inventory);
      expect(
        restoredChar.stats.atk,
        24,
      ); // lv4 base 18 + weapon 5.5 -> round 24
      expect(restoredInv.nextEquipmentId(), 'eq_3');
    });

    test(
      'pemulihan aman saat static config berubah atau JSON equipment rusak',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await db.initialize();

        final warnings = <String>[];
        final fullConfig = _testConfig(includeExtraItem: true);
        final fullRepo = DriftPlayerSaveRepository(db: db, config: fullConfig);

        await fullRepo.saveSnapshot(
          const PlayerSaveSnapshot(
            character: PlayerCharacterSnapshot(
              progress: PlayerProgress(level: 3, currentExp: 10, gold: 50),
              specializationId: 'vanguard',
            ),
            inventory: InventorySnapshot(
              stacks: {'slime_gel': 5, 'legacy_potion': 8},
              equipment: [
                EquipmentInstance(
                  id: 'eq_1',
                  definitionId: 'rusty_sword',
                  slot: EquipmentSlot.weapon,
                  rarity: ItemRarity.common,
                  rolledStats: EquipmentStats(atk: 7),
                ),
              ],
              equipmentCounter: 1,
            ),
          ),
        );

        // Simulasikan JSON stats korup + item definition dihapus pada update game.
        await (db.update(
          db.equipmentInstances,
        )..where((t) => t.instanceId.equals('eq_1'))).write(
          const EquipmentInstancesCompanion(
            rolledStatsJson: Value('{corrupted json'),
          ),
        );
        await (db.update(
          db.players,
        )..where((t) => t.id.equals('default_player'))).write(
          const PlayersCompanion(activeSpecializationId: Value('deleted_spec')),
        );

        final reducedConfig = _testConfig(includeExtraItem: false);
        final reducedRepo = DriftPlayerSaveRepository(
          db: db,
          config: reducedConfig,
          onRecoveryWarning: warnings.add,
        );

        final recovered = await reducedRepo.loadSnapshot();
        expect(recovered, isNotNull);
        // Item valid tetap selamat; item hilang diabaikan + warning dicatat.
        expect(recovered!.inventory.stacks, {'slime_gel': 5});
        expect(recovered.character.specializationId, isNull);
        // Equipment dengan JSON rusak memakai stat dasar definisi (atk: 5).
        expect(recovered.inventory.equipment.single.rolledStats.atk, 5);
        expect(warnings, hasLength(3));
      },
    );

    test('multi-dungeon DungeonProgresses, OfflineActivitySnapshot round-trip, dan sanitasi nilai negatif/rusak', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.initialize();

      final warnings = <String>[];
      final repo = DriftPlayerSaveRepository(
        db: db,
        config: _testConfig(),
        onRecoveryWarning: warnings.add,
      );

      const snapshot = PlayerSaveSnapshot(
        character: PlayerCharacterSnapshot(
          progress: PlayerProgress(level: 3, currentExp: 10, gold: 50),
          currentHp: 80,
        ),
        inventory: InventorySnapshot(),
        dungeon: DungeonProgressSnapshot(
          currentDungeonId: 'forgotten_forest',
          currentRoomId: 'ancient_path',
          currentRoomIndex: 1,
          highestClearedRoomIndex: 4,
          clearsCount: 2,
        ),
        dungeonProgresses: {
          'ancient_crypt': DungeonProgressSnapshot(
            currentDungeonId: 'ancient_crypt',
            currentRoomId: 'crypt_gate',
            currentRoomIndex: 0,
            highestClearedRoomIndex: -1,
            clearsCount: 0,
          ),
          'forgotten_forest': DungeonProgressSnapshot(
            currentDungeonId: 'forgotten_forest',
            currentRoomId: 'ancient_path',
            currentRoomIndex: 1,
            highestClearedRoomIndex: 4,
            clearsCount: 2,
          ),
        },
        session: GameSessionSnapshot(
          lastActiveAtMs: 50000,
          lastSavedAtMs: 50000,
          lastOfflineClaimAtMs: 50000,
        ),
        offlineActivity: OfflineActivitySnapshot(
          mode: OfflineActivityMode.autoFarming,
          state: OfflineActivityState.completed,
          selectedDungeonId: 'forgotten_forest',
          lastCheckpointAtMs: 90000,
          processedOfflineDurationMs: 40000,
          simulationSeed: 99,
          pendingSummary: OfflineSummarySnapshot(
            eventId: 'offline:50000:90000',
            mode: OfflineActivityMode.autoFarming,
            finalState: OfflineActivityState.completed,
            effectiveElapsedMs: 40000,
            runsAttempted: 1,
            runsCompleted: 1,
            roomsCleared: 5,
            encountersCleared: 10,
            expGained: 150,
            goldGained: 60,
            addedStacks: {'slime_gel': 3},
            generatedAtMs: 90000,
          ),
        ),
      );

      await repo.saveSnapshot(snapshot);
      final loaded = await repo.loadSnapshot();
      expect(loaded, isNotNull);
      expect(loaded!.dungeon.currentDungeonId, 'forgotten_forest');
      expect(
        loaded.dungeonProgresses.keys,
        containsAll(['ancient_crypt', 'forgotten_forest']),
      );
      expect(loaded.hasClearedDungeon('forgotten_forest'), isTrue);
      expect(loaded.hasClearedDungeon('ancient_crypt'), isFalse);
      expect(loaded.offlineActivity.mode, OfflineActivityMode.autoFarming);
      expect(loaded.offlineActivity.state, OfflineActivityState.completed);
      expect(loaded.offlineActivity.selectedDungeonId, 'forgotten_forest');
      expect(loaded.offlineActivity.simulationSeed, 99);
      expect(loaded.offlineActivity.pendingSummary?.expGained, 150);
      expect(loaded.offlineActivity.pendingSummary?.addedStacks, {
        'slime_gel': 3,
      });

      // Rusak JSON offlineActivity di SQLite -> fallback aman ke Pause Progression.
      await db.customUpdate(
        "UPDATE game_sessions SET session_data_json = "
        "'{\"offlineActivity\":{\"mode\":\"unknown_mode\",\"state\":\"bad\"}}' "
        "WHERE id = 'default_player'",
        updates: {db.gameSessions},
      );
      final recovered = await repo.loadSnapshot();
      expect(recovered!.offlineActivity.isPaused, isTrue);
      expect(recovered.offlineActivity.state, OfflineActivityState.inactive);
      expect(warnings.any((w) => w.contains('offlineActivity')), isTrue);
    });
  });
}
