import 'dart:io';

import 'package:echoes_of_aether/core/errors/config_exception.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/difficulty_config.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/farming_config.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:flutter_test/flutter_test.dart';

String _asset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealWith({String? settingsOverride, String? dungeonsOverride}) {
  const parser = GameConfigParser();
  final settings = settingsOverride ?? _asset('game_config.json');
  final difficulty = parser.parseDifficulty(settings);
  return GameConfig(
    monsters: const MonsterConfigParser().parse(_asset('monsters.json')),
    damage: parser.parseDamage(settings),
    difficulty: difficulty,
    farming: parser.parseFarming(settings),
    revive: parser.parseRevive(settings),
    progression: parser.parseProgression(settings),
    equipment: parser.parseEquipment(settings),
    dungeonCompletion: parser.parseDungeonCompletion(settings),
    items: const ItemConfigParser().parse(_asset('items.json')),
    lootTables: const LootConfigParser().parse(_asset('loot_tables.json')),
    skills: const SkillConfigParser().parse(_asset('skills.json')),
    specializations: const SpecializationConfigParser().parse(
      _asset('specializations.json'),
    ),
    dungeons: const DungeonConfigParser().parse(
      dungeonsOverride ?? _asset('dungeons.json'),
      ascensionMultiplier: difficulty.ascensionMultiplier,
    ),
  );
}

const _twoNormalDungeons = '''
{
  "maps": {
    "room_map": [
      "#####",
      "#...#",
      "#####"
    ]
  },
  "dungeons": [
    {
      "id": "dungeon_1",
      "name": "Dungeon Satu",
      "biome": "forgotten_forest",
      "kind": "normal",
      "order": 1,
      "difficulty_scale": 1.0,
      "recommended_level": 1,
      "start_room_id": "d1_r1",
      "rooms": [
        {
          "id": "d1_r1",
          "name": "D1 Room",
          "type": "boss",
          "map_ref": "room_map",
          "entry_position": { "x": 1, "y": 1 },
          "exit_position": { "x": 3, "y": 1 },
          "spawns": [
            {
              "id": "b1",
              "monster_id": "ancient_heart_guardian",
              "position": { "x": 2, "y": 1 },
              "is_boss": true,
              "required": true
            }
          ],
          "completion_condition": { "type": "defeat_boss" },
          "next_room_ids": []
        }
      ]
    },
    {
      "id": "dungeon_2",
      "name": "Dungeon Dua",
      "biome": "forgotten_forest",
      "kind": "normal",
      "order": 2,
      "difficulty_scale": 1.5,
      "recommended_level": 8,
      "unlock_requires_dungeon_id": "dungeon_1",
      "start_room_id": "d2_r1",
      "rooms": [
        {
          "id": "d2_r1",
          "name": "D2 Room",
          "type": "boss",
          "map_ref": "room_map",
          "entry_position": { "x": 1, "y": 1 },
          "exit_position": { "x": 3, "y": 1 },
          "spawns": [
            {
              "id": "b2",
              "monster_id": "ancient_heart_guardian",
              "position": { "x": 2, "y": 1 },
              "is_boss": true,
              "required": true
            }
          ],
          "completion_condition": { "type": "defeat_boss" },
          "next_room_ids": []
        }
      ]
    }
  ]
}
''';

void main() {
  const gameParser = GameConfigParser();
  const monsterParser = MonsterConfigParser();
  const dungeonParser = DungeonConfigParser();
  const validator = GameConfigValidator();

  group('Stage 3 — GameConfig difficulty & farming', () {
    test(
      'membaca blok difficulty dan farming dari assets/data/game_config.json',
      () {
        final source = _asset('game_config.json');
        final diff = gameParser.parseDifficulty(source);
        final farming = gameParser.parseFarming(source);

        expect(diff.cyclePerRank, 6.5);
        expect(diff.ascensionMultiplier, 1.35);
        expect(diff.cycleLevelStep, 44);
        expect(diff.statExponents.hp, 1.0);
        expect(diff.statExponents.atk, 1.0);
        expect(diff.statExponents.def, 0.9);
        expect(diff.cycleStatExponents, isNotNull);
        expect(diff.cycleStatExponents!.hp, 0.25);
        expect(diff.cycleStatExponents!.atk, 0.22);
        expect(diff.cycleStatExponents!.def, 0.2);
        expect(diff.eliteHpPerRank, 0.02);
        expect(diff.eliteAtkPerRank, 0.01);
        expect(diff.bossHpPerRank, 0.02);
        expect(diff.bossAtkPerRank, 0.01);
        expect(diff.mechanics.minAscensionRank, 1);
        expect(diff.mechanics.stoneskinDamageReduction, 0.15);
        expect(diff.mechanics.stoneskinHpThreshold, 0.50);
        expect(diff.mechanics.berserkHpThreshold, 0.25);
        expect(diff.mechanics.berserkAtkMultiplier, 1.10);
        expect(diff.mechanics.berserkSpeedMultiplier, 1.10);
        expect(diff.mechanics.eliteHeavyStrikeCooldownSeconds, 6.0);
        expect(diff.mechanics.eliteHeavyStrikeMultiplier, 1.20);
        expect(diff.mechanics.bossAoeCooldownSeconds, 8.0);
        expect(diff.mechanics.bossAoeRadius, 2.5);
        expect(diff.mechanics.bossAoeMultiplier, 1.05);
        expect(diff.mechanics.bossSummonHpThreshold, 0.35);
        expect(diff.mechanics.bossSummonCount, 1);
        expect(diff.rewardExponent, 0.85);
        expect(diff.drop.rareChancePerRank, 0.1);
        expect(diff.drop.maxChanceMultiplier, 3.0);
        expect(diff.drop.rollBonusPerRank, 0.02);
        expect(diff.drop.maxRollBonus, 0.5);
        expect(diff.maxMultiplier, 1000000000.0);
        expect(farming.deathLoopSuggestAfter, 3);
      },
    );

    test('memakai default bila blok difficulty dan farming tidak ada', () {
      final diff = gameParser.parseDifficulty('{}');
      final farming = gameParser.parseFarming('{}');
      expect(diff.cyclePerRank, 0.4);
      expect(diff.ascensionMultiplier, 1.35);
      expect(diff.cycleLevelStep, isNull);
      expect(diff.cycleStatExponents, isNull);
      expect(diff.maxMultiplier, 1000000000.0);
      expect(farming.deathLoopSuggestAfter, 3);
    });

    test('parser menolak nilai negatif atau tidak valid', () {
      expect(
        () => gameParser.parseDifficulty(
          '{"difficulty": {"cycle_per_rank": -0.1}}',
        ),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => gameParser.parseDifficulty(
          '{"difficulty": {"ascension_multiplier": 0.5}}',
        ),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => gameParser.parseDifficulty(
          '{"difficulty": {"cycle_stat_exponents": {"hp": -0.1}}}',
        ),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => gameParser.parseFarming(
          '{"farming": {"death_loop_suggest_after": 0}}',
        ),
        throwsA(isA<ConfigException>()),
      );
    });

    test('validator menolak eksponen tidak masuk akal & maxMultiplier overflow-prone', () {
      final base = _loadRealWith();
      expect(() => validator.validate(base), returnsNormally);

      final badExponent = GameConfig(
        monsters: base.monsters,
        damage: base.damage,
        difficulty: const DifficultyConfig(
          statExponents: StatExponentsConfig(hp: 9.0),
        ),
        farming: base.farming,
        revive: base.revive,
        progression: base.progression,
        items: base.items,
        lootTables: base.lootTables,
        skills: base.skills,
        specializations: base.specializations,
        dungeons: base.dungeons,
      );
      expect(
        () => validator.validate(badExponent),
        throwsA(isA<ConfigException>()),
      );

      final badCycleExponent = GameConfig(
        monsters: base.monsters,
        damage: base.damage,
        difficulty: const DifficultyConfig(
          cycleStatExponents: StatExponentsConfig(atk: 9.0),
        ),
        farming: base.farming,
        revive: base.revive,
        progression: base.progression,
        items: base.items,
        lootTables: base.lootTables,
        skills: base.skills,
        specializations: base.specializations,
        dungeons: base.dungeons,
      );
      expect(
        () => validator.validate(badCycleExponent),
        throwsA(isA<ConfigException>()),
      );

      final badCycleLevelStep = GameConfig(
        monsters: base.monsters,
        damage: base.damage,
        difficulty: const DifficultyConfig(cycleLevelStep: -1),
        farming: base.farming,
        revive: base.revive,
        progression: base.progression,
        items: base.items,
        lootTables: base.lootTables,
        skills: base.skills,
        specializations: base.specializations,
        dungeons: base.dungeons,
      );
      expect(
        () => validator.validate(badCycleLevelStep),
        throwsA(isA<ConfigException>()),
      );

      final overflowMaxMul = GameConfig(
        monsters: base.monsters,
        damage: base.damage,
        difficulty: const DifficultyConfig(maxMultiplier: 1e20),
        farming: base.farming,
        revive: base.revive,
        progression: base.progression,
        items: base.items,
        lootTables: base.lootTables,
        skills: base.skills,
        specializations: base.specializations,
        dungeons: base.dungeons,
      );
      expect(
        () => validator.validate(overflowMaxMul),
        throwsA(isA<ConfigException>()),
      );

      final nanMul = GameConfig(
        monsters: base.monsters,
        damage: base.damage,
        difficulty: const DifficultyConfig(rewardExponent: double.nan),
        farming: base.farming,
        revive: base.revive,
        progression: base.progression,
        items: base.items,
        lootTables: base.lootTables,
        skills: base.skills,
        specializations: base.specializations,
        dungeons: base.dungeons,
      );
      expect(() => validator.validate(nanMul), throwsA(isA<ConfigException>()));

      final badFarming = GameConfig(
        monsters: base.monsters,
        damage: base.damage,
        difficulty: base.difficulty,
        farming: const FarmingConfig(deathLoopSuggestAfter: 0),
        revive: base.revive,
        progression: base.progression,
        items: base.items,
        lootTables: base.lootTables,
        skills: base.skills,
        specializations: base.specializations,
        dungeons: base.dungeons,
      );
      expect(
        () => validator.validate(badFarming),
        throwsA(isA<ConfigException>()),
      );
    });
  });

  group('Stage 3 — MonsterConfigParser metadata opsional', () {
    String monsterJson({String extra = ''}) =>
        '''
    {
      "monsters": [
        {
          "id": "slime_variant",
          "name": "Crystal Slime",
          "level": 3,
          "stats": { "hp": 30, "atk": 5, "def": 1 },
          "attack_speed": 1.0,
          "move_speed": 2.0,
          "attack_range": 1.2
          $extra
        }
      ]
    }
    ''';

    test('default sprite_ref, sprite_tint, is_final_boss bila tidak diisi', () {
      final parsed = monsterParser.parse(monsterJson());
      final m = parsed['slime_variant']!;
      expect(m.spriteRef, isNull);
      expect(m.spriteTint, isNull);
      expect(m.isFinalBoss, isFalse);
    });

    test('mem-parse sprite_ref, sprite_tint hex #RRGGBB/#AARRGGBB, dan is_final_boss', () {
      final parsed = monsterParser.parse(
        monsterJson(
          extra: ', "sprite_ref": "aether_slime", "sprite_tint": "#65BFE8", "is_final_boss": true',
        ),
      );
      final m = parsed['slime_variant']!;
      expect(m.spriteRef, 'aether_slime');
      expect(m.spriteTint, '#65BFE8');
      expect(m.isFinalBoss, isTrue);

      final parsedAlpha = monsterParser.parse(
        monsterJson(extra: ', "sprite_tint": "#FF65BFE8"'),
      );
      expect(parsedAlpha['slime_variant']!.spriteTint, '#FF65BFE8');
    });

    test('menolak sprite_tint bukan format hex valid', () {
      for (final invalid in ['red', '#123', '65BFE8', '#GGGGGG']) {
        expect(
          () => monsterParser.parse(
            monsterJson(extra: ', "sprite_tint": "$invalid"'),
          ),
          throwsA(isA<ConfigException>()),
          reason: 'Seharusnya menolak sprite_tint "$invalid"',
        );
      }
    });
  });

  group('Stage 3 — DungeonConfigParser & GameConfigValidator', () {
    test('Forgotten Forest punya metadata Stage 3 yang valid', () {
      final config = _loadRealWith();
      expect(() => validator.validate(config), returnsNormally);
      final ff = config.dungeons['forgotten_forest']!;
      expect(ff.kind, DungeonKind.normal);
      expect(ff.order, 1);
      expect(ff.recommendedLevel, 5);
      expect(ff.unlockRequiresDungeonId, isNull);
      expect(ff.difficultyScale, 1.0);
    });

    test('mem-parse chain normal + dungeon ascension dari base_dungeon_id', () {
      final withAscension = '''
      {
        "maps": {
          "room_map": ["#####", "#...#", "#####"]
        },
        "dungeons": [
          {
            "id": "dungeon_1",
            "name": "Dungeon Satu",
            "biome": "forgotten_forest",
            "kind": "normal",
            "order": 1,
            "difficulty_scale": 1.0,
            "recommended_level": 1,
            "start_room_id": "d1_r1",
            "rooms": [
              {
                "id": "d1_r1",
                "name": "D1 Room",
                "type": "boss",
                "map_ref": "room_map",
                "entry_position": { "x": 1, "y": 1 },
                "exit_position": { "x": 3, "y": 1 },
                "spawns": [
                  {
                    "id": "b1",
                    "monster_id": "ancient_heart_guardian",
                    "position": { "x": 2, "y": 1 },
                    "is_boss": true,
                    "required": true
                  }
                ],
                "completion_condition": { "type": "defeat_boss" },
                "next_room_ids": []
              }
            ]
          },
          {
            "id": "dungeon_2",
            "name": "Dungeon Dua",
            "biome": "forgotten_forest",
            "kind": "normal",
            "order": 2,
            "difficulty_scale": 1.5,
            "recommended_level": 8,
            "unlock_requires_dungeon_id": "dungeon_1",
            "start_room_id": "d2_r1",
            "rooms": [
              {
                "id": "d2_r1",
                "name": "D2 Room",
                "type": "boss",
                "map_ref": "room_map",
                "entry_position": { "x": 1, "y": 1 },
                "exit_position": { "x": 3, "y": 1 },
                "spawns": [
                  {
                    "id": "b2",
                    "monster_id": "ancient_heart_guardian",
                    "position": { "x": 2, "y": 1 },
                    "is_boss": true,
                    "required": true
                  }
                ],
                "completion_condition": { "type": "defeat_boss" },
                "next_room_ids": []
              }
            ]
          },
          {
            "id": "ascension_test",
            "name": "Ascension Test",
            "kind": "ascension",
            "order": 3,
            "base_dungeon_id": "dungeon_2",
            "unlock_requires_dungeon_id": "dungeon_2",
            "completion_reward": { "exp_reward": 500, "gold_reward": 250 }
          }
        ]
      }
      ''';

      final config = _loadRealWith(dungeonsOverride: withAscension);
      expect(() => validator.validate(config), returnsNormally);

      final asc = config.dungeons['ascension_test']!;
      expect(asc.kind, DungeonKind.ascension);
      expect(asc.isAscension, isTrue);
      expect(asc.order, 3);
      expect(asc.baseDungeonId, 'dungeon_2');
      expect(asc.recommendedLevel, 8);
      expect(asc.difficultyScale, closeTo(1.5 * 1.35, 1e-9));
      expect(asc.rooms.keys, ['d2_r1']);
      expect(asc.rooms['d2_r1']!.dungeonId, 'ascension_test');
      expect(asc.completionReward!.expReward, 500);
    });

    test('validator menolak order ganda atau berlubang', () {
      final dupOrder = _twoNormalDungeons.replaceFirst(
        '"order": 2,',
        '"order": 1,',
      );
      expect(
        () => validator.validate(_loadRealWith(dungeonsOverride: dupOrder)),
        throwsA(isA<ConfigException>()),
      );

      final gapOrder = _twoNormalDungeons.replaceFirst(
        '"order": 2,',
        '"order": 3,',
      );
      expect(
        () => validator.validate(_loadRealWith(dungeonsOverride: gapOrder)),
        throwsA(isA<ConfigException>()),
      );
    });

    test(
      'validator menolak unlock pointing ke order >= atau siklus unlock',
      () {
        final invalidOrderUnlock = _twoNormalDungeons.replaceFirst(
          '"order": 1,',
          '"order": 1, "unlock_requires_dungeon_id": "dungeon_2",',
        );
        expect(
          () => validator.validate(
            _loadRealWith(dungeonsOverride: invalidOrderUnlock),
          ),
          throwsA(isA<ConfigException>()),
        );

        final missingUnlock = _twoNormalDungeons.replaceFirst(
          '"unlock_requires_dungeon_id": "dungeon_1",',
          '"unlock_requires_dungeon_id": "tidak_ada",',
        );
        expect(
          () => validator.validate(
            _loadRealWith(dungeonsOverride: missingUnlock),
          ),
          throwsA(isA<ConfigException>()),
        );

        final selfCycle = _twoNormalDungeons.replaceFirst(
          '"order": 1,',
          '"order": 1, "unlock_requires_dungeon_id": "dungeon_1",',
        );
        expect(
          () => validator.validate(_loadRealWith(dungeonsOverride: selfCycle)),
          throwsA(isA<ConfigException>()),
        );
      },
    );

    test('menolak >1 dungeon ascension atau base_dungeon_id tidak valid', () {
      final twoAscensions = '''
      {
        "maps": { "room_map": ["#####", "#...#", "#####"] },
        "dungeons": [
          {
            "id": "dungeon_1",
            "name": "D1",
            "biome": "forgotten_forest",
            "kind": "normal",
            "order": 1,
            "start_room_id": "r1",
            "rooms": [
              {
                "id": "r1",
                "name": "R1",
                "type": "boss",
                "map_ref": "room_map",
                "entry_position": { "x": 1, "y": 1 },
                "exit_position": { "x": 3, "y": 1 },
                "spawns": [
                  { "id": "b1", "monster_id": "ancient_heart_guardian", "position": { "x": 2, "y": 1 }, "is_boss": true, "required": true }
                ],
                "completion_condition": { "type": "defeat_boss" },
                "next_room_ids": []
              }
            ]
          },
          { "id": "asc_1", "name": "Asc 1", "kind": "ascension", "order": 2, "base_dungeon_id": "dungeon_1" },
          { "id": "asc_2", "name": "Asc 2", "kind": "ascension", "order": 3, "base_dungeon_id": "dungeon_1" }
        ]
      }
      ''';
      expect(
        () =>
            validator.validate(_loadRealWith(dungeonsOverride: twoAscensions)),
        throwsA(isA<ConfigException>()),
      );

      final badBase = '''
      {
        "maps": { "room_map": ["#####", "#...#", "#####"] },
        "dungeons": [
          {
            "id": "dungeon_1",
            "name": "D1",
            "biome": "forgotten_forest",
            "kind": "normal",
            "order": 1,
            "start_room_id": "r1",
            "rooms": [
              {
                "id": "r1",
                "name": "R1",
                "type": "boss",
                "map_ref": "room_map",
                "entry_position": { "x": 1, "y": 1 },
                "exit_position": { "x": 3, "y": 1 },
                "spawns": [
                  { "id": "b1", "monster_id": "ancient_heart_guardian", "position": { "x": 2, "y": 1 }, "is_boss": true, "required": true }
                ],
                "completion_condition": { "type": "defeat_boss" },
                "next_room_ids": []
              }
            ]
          },
          { "id": "asc_1", "name": "Asc 1", "kind": "ascension", "order": 2, "base_dungeon_id": "asc_1" }
        ]
      }
      ''';
      expect(
        () => dungeonParser.parse(badBase),
        throwsA(isA<ConfigException>()),
      );
    });
  });
}
