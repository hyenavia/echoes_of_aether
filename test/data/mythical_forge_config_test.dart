import 'dart:io';

import 'package:echoes_of_aether/core/errors/config_exception.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/mythical_forge_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/data/repositories/game_config_repository.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/mythical_forge_config.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealConfig({
  Map<String, ItemDefinition>? itemsOverride,
  MythicalForgeConfig? forgeOverride,
}) {
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
    items:
        itemsOverride ??
        const ItemConfigParser().parse(_readAsset('items.json')),
    lootTables: const LootConfigParser().parse(_readAsset('loot_tables.json')),
    skills: const SkillConfigParser().parse(_readAsset('skills.json')),
    specializations: const SpecializationConfigParser().parse(
      _readAsset('specializations.json'),
    ),
    dungeons: const DungeonConfigParser().parse(
      _readAsset('dungeons.json'),
      ascensionMultiplier: difficulty.ascensionMultiplier,
    ),
    heroAscension: parser.parseHeroAscension(settings),
    mythicalForge:
        forgeOverride ??
        const MythicalForgeConfigParser().parse(
          _readAsset('mythical_forge.json'),
        ),
  );
}

void main() {
  group('Stage 1 — Mythical Forge & Set Config', () {
    test('AssetGameConfigRepository memuat mythical_forge.json & items set lengkap', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final repoConfig = await AssetGameConfigRepository().loadGameConfig();

      expect(repoConfig.mythicalForge.sets, hasLength(6));
      expect(repoConfig.mythicalForge.recipes, hasLength(18));

      for (final setDef in repoConfig.mythicalForge.sets.values) {
        final setItems = repoConfig.items.values
            .where((item) => item.equipment?.setId == setDef.id)
            .toList();
        expect(
          setItems,
          hasLength(4),
          reason: 'Set ${setDef.id} harus memiliki tepat 4 item (4 slot)',
        );
        expect(
          setItems.map((e) => e.equipment!.slot).toSet(),
          EquipmentSlot.values.toSet(),
          reason: 'Set ${setDef.id} harus mencakup semua 4 slot equipment',
        );
        for (final item in setItems) {
          expect(item.rarity, ItemRarity.mythical);
          expect(item.sellable, isFalse);
          expect(item.equipment!.fixedStats, isTrue);
        }
      }

      for (final recipe in repoConfig.mythicalForge.recipes.values) {
        expect(recipe.sacrificeMinRarity, ItemRarity.legendary);
        expect(recipe.goldCost, 50000);
        expect(recipe.materials['aether_scrap'], 200);
        expect(recipe.materials['boss_remnant'], 15);
        expect(recipe.materials['abyssal_remnant'], 5);
      }
    });

    test('MythicalForgeConfigParser menolak id ganda, target ganda, material kosong, dan rarity tidak dikenal', () {
      const parser = MythicalForgeConfigParser();

      expect(
        () => parser.parse('''
        {
          "sets": [
            {
              "id": "s1", "name": "S1", "signature_class_id": "paladin",
              "two_piece_bonus": {"atk": 5},
              "two_piece_description": "A", "four_piece_description": "B"
            },
            {
              "id": "s1", "name": "S1 Dup", "signature_class_id": "paladin",
              "two_piece_bonus": {"atk": 5},
              "two_piece_description": "A", "four_piece_description": "B"
            }
          ],
          "recipes": []
        }
        '''),
        throwsA(isA<ConfigException>()),
      );

      expect(
        () => parser.parse('''
        {
          "sets": [],
          "recipes": [
            {
              "id": "r1", "target_item_id": "t1", "set_id": "s1",
              "required_catalyst_weapon_id": "w1", "gold_cost": 100,
              "materials": {"aether_scrap": 10}
            },
            {
              "id": "r2", "target_item_id": "t1", "set_id": "s1",
              "required_catalyst_weapon_id": "w1", "gold_cost": 100,
              "materials": {"aether_scrap": 10}
            }
          ]
        }
        '''),
        throwsA(isA<ConfigException>()),
      );

      expect(
        () => parser.parse('''
        {
          "sets": [],
          "recipes": [
            {
              "id": "r1", "target_item_id": "t1", "set_id": "s1",
              "required_catalyst_weapon_id": "w1", "gold_cost": 100,
              "materials": {}
            }
          ]
        }
        '''),
        throwsA(isA<ConfigException>()),
      );

      expect(
        () => parser.parse('''
        {
          "sets": [],
          "recipes": [
            {
              "id": "r1", "target_item_id": "t1", "set_id": "s1",
              "required_catalyst_weapon_id": "w1", "sacrifice_min_rarity": "divine",
              "gold_cost": 100, "materials": {"aether_scrap": 10}
            }
          ]
        }
        '''),
        throwsA(isA<ConfigException>()),
      );
    });

    test(
      'GameConfigValidator menolak set/resep dengan referensi tidak valid',
      () {
        const validator = GameConfigValidator();
        final validConfig = _loadRealConfig();
        expect(() => validator.validate(validConfig), returnsNormally);

        final badSetConfig = _loadRealConfig(
          forgeOverride: MythicalForgeConfig(
            sets: {
              ...validConfig.mythicalForge.sets,
              'bad_set': const MythicalSetDefinition(
                id: 'bad_set',
                name: 'Bad Set',
                signatureClassId: 'unknown_class',
                twoPieceBonus: EquipmentStats(atk: 10),
                twoPieceDescription: 'desc',
                fourPieceDescription: 'desc4',
              ),
            },
            recipes: validConfig.mythicalForge.recipes,
          ),
        );
        expect(
          () => validator.validate(badSetConfig),
          throwsA(isA<ConfigException>()),
        );

        final weaponTargetRecipeConfig = _loadRealConfig(
          forgeOverride: MythicalForgeConfig(
            sets: validConfig.mythicalForge.sets,
            recipes: const {
              'bad_recipe': MythicalForgeRecipe(
                id: 'bad_recipe',
                targetItemId: 'dawns_aegis_blade',
                setId: 'dawns_aegis',
                requiredCatalystWeaponId: 'dawns_aegis_blade',
                goldCost: 1000,
                materials: {'aether_scrap': 10},
              ),
            },
          ),
        );
        expect(
          () => validator.validate(weaponTargetRecipeConfig),
          throwsA(isA<ConfigException>()),
        );

        final nonMaterialRecipeConfig = _loadRealConfig(
          forgeOverride: MythicalForgeConfig(
            sets: validConfig.mythicalForge.sets,
            recipes: const {
              'bad_mat': MythicalForgeRecipe(
                id: 'bad_mat',
                targetItemId: 'dawns_aegis_helm',
                setId: 'dawns_aegis',
                requiredCatalystWeaponId: 'dawns_aegis_blade',
                goldCost: 1000,
                materials: {'small_potion': 5},
              ),
            },
          ),
        );
        expect(
          () => validator.validate(nonMaterialRecipeConfig),
          throwsA(isA<ConfigException>()),
        );
      },
    );
  });
}
