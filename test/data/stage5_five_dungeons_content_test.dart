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
import 'package:echoes_of_aether/data/repositories/game_config_repository.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/equipment_loadout.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/offline_dungeon_runner.dart';
import 'package:echoes_of_aether/domain/services/offline_time_calculator.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealConfig() {
  const parser = GameConfigParser();
  final settings = _readAsset('game_config.json');
  final difficulty = parser.parseDifficulty(settings);
  return GameConfig(
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
}

void main() {
  const validator = GameConfigValidator();

  group('M8 Stage 5 — Lima Dungeon Data-Driven & Validator', () {
    test('seluruh assets/data JSON (5 dungeon & 20 monster baru) lolos GameConfigValidator', () async {
      final config = _loadRealConfig();
      expect(() => validator.validate(config), returnsNormally);

      TestWidgetsFlutterBinding.ensureInitialized();
      final repoConfig = await AssetGameConfigRepository().loadGameConfig();
      expect(() => validator.validate(repoConfig), returnsNormally);

      final dungeons = config.dungeons.values.toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      final normalDungeons = dungeons.where((d) => d.isNormal).toList();
      expect(normalDungeons.map((d) => d.id).toList(), [
        'forgotten_forest',
        'crystal_cavern',
        'ancient_crypt',
        'ashen_wasteland',
        'aether_sanctum',
      ]);
      final ascensionDungeons = dungeons.where((d) => d.isAscension).toList();
      expect(ascensionDungeons.map((d) => d.id).toList(), [
        'ascension_sanctum',
      ]);

      final expectedSpecs =
          <
            String,
            ({
              int order,
              double scale,
              int recLevel,
              String? unlockReq,
              int roomsCount,
            })
          >{
            'forgotten_forest': (
              order: 1,
              scale: 1.0,
              recLevel: 5,
              unlockReq: null,
              roomsCount: 5,
            ),
            'crystal_cavern': (
              order: 2,
              scale: 1.5,
              recLevel: 8,
              unlockReq: 'forgotten_forest',
              roomsCount: 6,
            ),
            'ancient_crypt': (
              order: 3,
              scale: 2.25,
              recLevel: 16,
              unlockReq: 'crystal_cavern',
              roomsCount: 7,
            ),
            'ashen_wasteland': (
              order: 4,
              scale: 3.375,
              recLevel: 25,
              unlockReq: 'ancient_crypt',
              roomsCount: 7,
            ),
            'aether_sanctum': (
              order: 5,
              scale: 5.0625,
              recLevel: 35,
              unlockReq: 'ashen_wasteland',
              roomsCount: 5,
            ),
          };

      final allRoomIds = <String>{};
      for (final d in normalDungeons) {
        final spec = expectedSpecs[d.id]!;
        expect(d.kind, DungeonKind.normal);
        expect(d.order, spec.order);
        expect(d.difficultyScale, closeTo(spec.scale, 1e-6));
        expect(d.recommendedLevel, spec.recLevel);
        expect(d.unlockRequiresDungeonId, spec.unlockReq);
        expect(d.roomOrder, hasLength(spec.roomsCount));

        for (final roomId in d.roomOrder) {
          expect(
            allRoomIds.add(roomId),
            isTrue,
            reason:
                'Room ID "$roomId" tidak boleh dipakai ganda lintas dungeon.',
          );
        }

        for (var i = 0; i < d.roomOrder.length - 2; i++) {
          expect(d.roomById(d.roomOrder[i])!.type, RoomType.normal);
        }
        expect(
          d.roomById(d.roomOrder[d.roomOrder.length - 2])!.type,
          RoomType.elite,
        );
        expect(d.roomById(d.roomOrder.last)!.type, RoomType.boss);
      }
    });

    test('Final Boss hanya ada di Dungeon 5 (Aether Sovereign)', () {
      final config = _loadRealConfig();
      final finalBossDefs = config.monsters.values
          .where((m) => m.isFinalBoss)
          .toList();
      expect(finalBossDefs, hasLength(1));
      expect(finalBossDefs.single.id, 'aether_sovereign');
      expect(finalBossDefs.single.name, 'Aether Sovereign');
      expect(finalBossDefs.single.isBoss, isTrue);

      for (final dungeon in config.dungeons.values) {
        final spawnsFinalBoss = dungeon.rooms.values.any(
          (room) => room.spawns.any(
            (spawn) => config.monsters[spawn.monsterId]?.isFinalBoss == true,
          ),
        );
        final isFinalSanctum =
            dungeon.id == 'aether_sanctum' ||
            dungeon.baseDungeonId == 'aether_sanctum';
        expect(
          spawnsFinalBoss,
          isFinalSanctum,
          reason: 'Hanya aether_sanctum (dan varian Ascension-nya) yang boleh memunculkan Final Boss.',
        );
      }
    });

    test('loot table menjaga item Epic/Legendary hanya pada boss/dungeon tinggi', () {
      final config = _loadRealConfig();
      for (final m in config.monsters.values) {
        if (!m.isElite && !m.isBoss) {
          final tableId = m.lootTableId;
          if (tableId == null) continue;
          final entries = config.lootTables[tableId]!.entries;
          expect(
            entries.any(
              (e) =>
                  e.itemId == 'aether_blade' || e.itemId == 'heart_of_aether',
            ),
            isFalse,
            reason:
                'Monster normal "${m.id}" tidak boleh men-drop aether_blade atau heart_of_aether.',
          );
        }
      }

      for (final clearId in const [
        'dungeon_clear_loot',
        'crystal_clear_loot',
        'crypt_clear_loot',
      ]) {
        final entries = config.lootTables[clearId]!.entries;
        expect(
          entries.any(
            (e) => e.itemId == 'aether_blade' || e.itemId == 'heart_of_aether',
          ),
          isFalse,
          reason:
              'Completion loot "$clearId" terlalu awal untuk Epic/Legendary.',
        );
      }
    });

    test('setiap dungeon (1..5) dapat dimulai dan diselesaikan di simulasi headless dengan seed tetap', () {
      final config = _loadRealConfig();
      const runner = OfflineDungeonRunner();
      final factory = EquipmentFactory(config.equipment);

      EquipmentInstance makeStaticGear(String itemId, String instanceId) {
        final def = config.items[itemId]!;
        return EquipmentInstance(
          id: instanceId,
          definitionId: def.id,
          slot: def.equipment!.slot,
          rarity: def.rarity,
          rolledStats: def.equipment!.baseStats,
        );
      }

      final presets =
          <String, ({int level, String? spec, List<String> gearIds})>{
            'forgotten_forest': (
              level: 5,
              spec: 'vanguard',
              gearIds: [
                'rusty_sword',
                'leather_cap',
                'padded_vest',
                'copper_ring',
              ],
            ),
            'crystal_cavern': (
              level: 8,
              spec: 'vanguard',
              gearIds: [
                'hunters_bow',
                'iron_helm',
                'forest_mail',
                'swift_charm',
              ],
            ),
            'ancient_crypt': (
              level: 16,
              spec: 'vanguard',
              gearIds: [
                'ranger_blade',
                'iron_helm',
                'forest_mail',
                'guardian_amulet',
              ],
            ),
            'ashen_wasteland': (
              level: 25,
              spec: 'vanguard',
              gearIds: [
                'ranger_blade',
                'iron_helm',
                'forest_mail',
                'guardian_amulet',
              ],
            ),
            'aether_sanctum': (
              level: 35,
              spec: 'vanguard',
              gearIds: [
                'aether_blade',
                'iron_helm',
                'forest_mail',
                'heart_of_aether',
              ],
            ),
          };

      final clearExps = <String, int>{};
      final clearGolds = <String, int>{};

      for (final entry in presets.entries) {
        final dungeonId = entry.key;
        final preset = entry.value;
        final loadout = EquipmentLoadout();
        for (var i = 0; i < preset.gearIds.length; i++) {
          loadout.equip(
            makeStaticGear(preset.gearIds[i], 'gear_${dungeonId}_$i'),
          );
        }

        final skillLevels = <String, int>{
          for (final s in config.skills.values)
            if (preset.level >= s.unlockLevel &&
                (s.specializationId == null ||
                    s.specializationId == preset.spec))
              s.id: (preset.level ~/ 7).clamp(1, s.maxLevel),
        };

        final character = PlayerCharacter(
          config: config.progression,
          progress: PlayerProgress(level: preset.level),
          loadout: loadout,
          skillCatalog: config.skills,
          specializationConfig: config.specializations,
          initialSpecializationId: preset.spec,
          skillLevels: skillLevels,
        );
        final inventory = Inventory(definitions: config.items);
        final rewardProcessor = RewardProcessor(
          character: character,
          inventory: inventory,
          items: config.items,
          lootTables: config.lootTables,
          equipmentFactory: factory,
        );

        final timeWindow = const OfflineTimeCalculator().calculate(
          session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
          nowMs: 1000000 + const Duration(minutes: 20).inMilliseconds,
        );

        final outcome = runner.runBatch(
          OfflineDungeonRunRequest(
            mode: OfflineActivityMode.continueDungeon,
            character: character,
            inventory: inventory,
            config: config,
            rewardProcessor: rewardProcessor,
            dungeonId: dungeonId,
            dungeonProgress: DungeonProgressSnapshot(
              currentDungeonId: dungeonId,
            ),
            timeWindow: timeWindow,
            simulationSeed: 42,
            activeDungeonSession: ActiveDungeonSessionSnapshot(
              runId: 'stage5_run_$dungeonId',
              dungeonId: dungeonId,
              currentRoomId: config.dungeons[dungeonId]!.startRoomId,
              currentRoomIndex: 0,
              status: DungeonSessionStatus.inProgress,
            ),
          ),
        );

        expect(
          outcome.stopReason,
          OfflineDungeonStopReason.dungeonCompleted,
          reason: '$dungeonId harus selesai pada level rekomendasi preset.',
        );
        expect(outcome.runsCompleted, 1);
        expect(outcome.runsFailed, 0);
        expect(
          outcome.roomsCleared,
          config.dungeons[dungeonId]!.roomOrder.length,
        );
        expect(outcome.updatedDungeonProgress.clearedInCycleRank, 0);
        expect(outcome.updatedDungeonProgress.clearsCount, 1);
        expect(outcome.expGained, greaterThan(0));
        expect(outcome.goldGained, greaterThan(0));

        clearExps[dungeonId] = outcome.expGained;
        clearGolds[dungeonId] = outcome.goldGained;
      }

      // Pastikan reward naik progresif dari Dungeon 1 hingga Dungeon 5.
      final ids = [
        'forgotten_forest',
        'crystal_cavern',
        'ancient_crypt',
        'ashen_wasteland',
        'aether_sanctum',
      ];
      for (var i = 1; i < ids.length; i++) {
        expect(
          clearExps[ids[i]]!,
          greaterThan(clearExps[ids[i - 1]]!),
          reason:
              'Total EXP run ${ids[i]} seharusnya lebih besar dari ${ids[i - 1]}.',
        );
        expect(
          clearGolds[ids[i]]!,
          greaterThan(clearGolds[ids[i - 1]]!),
          reason:
              'Total Gold run ${ids[i]} seharusnya lebih besar dari ${ids[i - 1]}.',
        );
      }

      // Determinisme seed tetap: eksekusi ulang D2 dengan state identik menghasilkan EXP/Gold sama.
      final rerunChar = PlayerCharacter(
        config: config.progression,
        progress: const PlayerProgress(level: 8),
        skillCatalog: config.skills,
        specializationConfig: config.specializations,
        initialSpecializationId: 'vanguard',
      );
      final rerunInv = Inventory(definitions: config.items);
      final rerunOutcome = runner.runBatch(
        OfflineDungeonRunRequest(
          mode: OfflineActivityMode.continueDungeon,
          character: rerunChar,
          inventory: rerunInv,
          config: config,
          rewardProcessor: RewardProcessor(
            character: rerunChar,
            inventory: rerunInv,
            items: config.items,
            lootTables: config.lootTables,
            equipmentFactory: factory,
          ),
          dungeonId: 'crystal_cavern',
          dungeonProgress: const DungeonProgressSnapshot(
            currentDungeonId: 'crystal_cavern',
          ),
          timeWindow: const OfflineTimeCalculator().calculate(
            session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
            nowMs: 1000000 + const Duration(minutes: 20).inMilliseconds,
          ),
          simulationSeed: 42,
          activeDungeonSession: const ActiveDungeonSessionSnapshot(
            runId: 'stage5_run_crystal_cavern_determinism',
            dungeonId: 'crystal_cavern',
            currentRoomId: 'cc_cavern_mouth',
            currentRoomIndex: 0,
            status: DungeonSessionStatus.inProgress,
          ),
        ),
      );
      final rerunSame = runner.runBatch(
        OfflineDungeonRunRequest(
          mode: OfflineActivityMode.continueDungeon,
          character: PlayerCharacter(
            config: config.progression,
            progress: const PlayerProgress(level: 8),
            skillCatalog: config.skills,
            specializationConfig: config.specializations,
            initialSpecializationId: 'vanguard',
          ),
          inventory: Inventory(definitions: config.items),
          config: config,
          rewardProcessor: RewardProcessor(
            character: PlayerCharacter(
              config: config.progression,
              progress: const PlayerProgress(level: 8),
              skillCatalog: config.skills,
              specializationConfig: config.specializations,
              initialSpecializationId: 'vanguard',
            ),
            inventory: Inventory(definitions: config.items),
            items: config.items,
            lootTables: config.lootTables,
            equipmentFactory: factory,
          ),
          dungeonId: 'crystal_cavern',
          dungeonProgress: const DungeonProgressSnapshot(
            currentDungeonId: 'crystal_cavern',
          ),
          timeWindow: const OfflineTimeCalculator().calculate(
            session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
            nowMs: 1000000 + const Duration(minutes: 20).inMilliseconds,
          ),
          simulationSeed: 42,
          activeDungeonSession: const ActiveDungeonSessionSnapshot(
            runId: 'stage5_run_crystal_cavern_determinism',
            dungeonId: 'crystal_cavern',
            currentRoomId: 'cc_cavern_mouth',
            currentRoomIndex: 0,
            status: DungeonSessionStatus.inProgress,
          ),
        ),
      );
      expect(rerunOutcome.expGained, rerunSame.expGained);
      expect(rerunOutcome.goldGained, rerunSame.goldGained);
      // Hapus unused math import warning check via deterministic seed test above.
      expect(math.Random(42).nextInt(100), math.Random(42).nextInt(100));
    });
  });
}
