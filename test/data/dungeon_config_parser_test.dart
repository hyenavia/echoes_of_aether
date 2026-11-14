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
import 'package:echoes_of_aether/data/repositories/game_config_repository.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:flutter_test/flutter_test.dart';

String _asset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadFullRealConfig({String? dungeonsOverride}) {
  const parser = GameConfigParser();
  final settings = _asset('game_config.json');
  return GameConfig(
    monsters: const MonsterConfigParser().parse(_asset('monsters.json')),
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
    ),
  );
}

const _minimalValidDungeons = '''
{
  "maps": {
    "room_a_map": [
      "#####",
      "#...#",
      "#####"
    ],
    "room_b_map": [
      "#####",
      "#...#",
      "#####"
    ]
  },
  "dungeons": [
    {
      "id": "test_dungeon",
      "name": "Test Dungeon",
      "biome": "test_biome",
      "start_room_id": "room_a",
      "rooms": [
        {
          "id": "room_a",
          "name": "Room A",
          "type": "normal",
          "map_ref": "room_a_map",
          "entry_position": { "x": 1, "y": 1 },
          "exit_position": { "x": 3, "y": 1 },
          "spawns": [
            {
              "id": "s1",
              "monster_id": "aether_slime",
              "position": { "x": 2, "y": 1 },
              "required": true
            }
          ],
          "completion_condition": { "type": "defeat_required_enemies" },
          "next_room_ids": ["room_b"]
        },
        {
          "id": "room_b",
          "name": "Room B",
          "type": "boss",
          "map_ref": "room_b_map",
          "entry_position": { "x": 1, "y": 1 },
          "exit_position": { "x": 3, "y": 1 },
          "spawns": [
            {
              "id": "s2",
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
  const parser = DungeonConfigParser();
  const validator = GameConfigValidator();

  group('DungeonConfigParser — assets/data/dungeons.json', () {
    test('membaca Forgotten Forest dengan 5 room linear MVP', () {
      final dungeons = parser.parse(_asset('dungeons.json'));
      expect(dungeons.keys, contains('forgotten_forest'));

      final ff = dungeons['forgotten_forest']!;
      expect(ff.name, 'Forgotten Forest');
      expect(ff.startRoomId, 'forest_entrance');
      expect(ff.roomOrder, [
        'forest_entrance',
        'ancient_path',
        'ruined_shrine',
        'hidden_chamber',
        'ancient_heart',
      ]);

      expect(ff.roomById('forest_entrance')!.type, RoomType.normal);
      expect(ff.roomById('ancient_path')!.type, RoomType.normal);
      expect(ff.roomById('ruined_shrine')!.type, RoomType.normal);
      expect(ff.roomById('hidden_chamber')!.type, RoomType.elite);
      expect(ff.roomById('ancient_heart')!.type, RoomType.boss);

      expect(
        ff.roomById('hidden_chamber')!.completionCondition.type,
        RoomCompletionConditionType.defeatElite,
      );
      expect(
        ff.roomById('ancient_heart')!.completionCondition.type,
        RoomCompletionConditionType.defeatBoss,
      );
      expect(ff.roomById('ancient_heart')!.isFinalRoom, isTrue);
    });

    test('seluruh konfigurasi nyata lolos GameConfigValidator', () {
      final config = _loadFullRealConfig();
      expect(() => validator.validate(config), returnsNormally);
    });

    test(
      'AssetGameConfigRepository memuat dungeons.json melalui bundle',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        final config = await AssetGameConfigRepository().loadGameConfig();
        expect(config.dungeons.containsKey('forgotten_forest'), isTrue);
        expect(config.dungeons['forgotten_forest']!.rooms, hasLength(5));
      },
    );
  });

  group('DungeonConfigParser — error handling', () {
    test('menolak JSON rusak', () {
      expect(
        () => parser.parse('{ bukan json'),
        throwsA(isA<ConfigException>()),
      );
    });

    test('menolak missing room ID', () {
      final broken = _minimalValidDungeons.replaceFirst('"id": "room_a",', '');
      expect(
        () => parser.parse(broken),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('id'),
          ),
        ),
      );
    });

    test('menolak duplicate room ID', () {
      final broken = _minimalValidDungeons.replaceFirst(
        '"id": "room_b",',
        '"id": "room_a",',
      );
      expect(
        () => parser.parse(broken),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('ganda'),
          ),
        ),
      );
    });

    test('menolak duplicate dungeon ID', () {
      final singleDungeon = _minimalValidDungeons.substring(
        _minimalValidDungeons.indexOf('{', _minimalValidDungeons.indexOf('[')),
        _minimalValidDungeons.lastIndexOf('}'),
      );
      final broken =
          '''
      {
        "maps": {
          "room_a_map": ["#####", "#...#", "#####"],
          "room_b_map": ["#####", "#...#", "#####"]
        },
        "dungeons": [$singleDungeon
      ''';
      // Uji langsung dengan struktur minimal ganda.
      const dupJson = '''
      {
        "maps": { "m": ["#####", "#...#", "#####"] },
        "dungeons": [
          {
            "id": "dup",
            "name": "D1",
            "biome": "b",
            "start_room_id": "r1",
            "rooms": [{
              "id": "r1", "name": "R1", "type": "normal", "map_ref": "m",
              "entry_position": {"x": 1, "y": 1}, "exit_position": {"x": 3, "y": 1},
              "spawns": [{"monster_id": "aether_slime", "position": {"x": 2, "y": 1}}],
              "completion_condition": {"type": "defeat_required_enemies"},
              "next_room_ids": []
            }]
          },
          {
            "id": "dup",
            "name": "D2",
            "biome": "b",
            "start_room_id": "r1",
            "rooms": [{
              "id": "r1", "name": "R1", "type": "normal", "map_ref": "m",
              "entry_position": {"x": 1, "y": 1}, "exit_position": {"x": 3, "y": 1},
              "spawns": [{"monster_id": "aether_slime", "position": {"x": 2, "y": 1}}],
              "completion_condition": {"type": "defeat_required_enemies"},
              "next_room_ids": []
            }]
          }
        ]
      }
      ''';
      expect(broken, isNotEmpty);
      expect(
        () => parser.parse(dupJson),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('ganda'),
          ),
        ),
      );
    });

    test('menolak missing map reference', () {
      final broken = _minimalValidDungeons.replaceFirst(
        '"map_ref": "room_a_map",',
        '"map_ref": "missing_map",',
      );
      expect(
        () => parser.parse(broken),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('missing_map'),
          ),
        ),
      );
    });

    test('menolak room tanpa map_ref maupun layout', () {
      final broken = _minimalValidDungeons.replaceFirst(
        '"map_ref": "room_a_map",',
        '',
      );
      expect(() => parser.parse(broken), throwsA(isA<ConfigException>()));
    });

    test('menolak invalid spawn point (di luar bounds atau di dinding)', () {
      final outOfBounds = _minimalValidDungeons.replaceFirst(
        '"position": { "x": 2, "y": 1 }',
        '"position": { "x": 99, "y": 1 }',
      );
      expect(() => parser.parse(outOfBounds), throwsA(isA<ConfigException>()));

      final onWall = _minimalValidDungeons.replaceFirst(
        '"position": { "x": 2, "y": 1 }',
        '"position": { "x": 0, "y": 0 }',
      );
      expect(() => parser.parse(onWall), throwsA(isA<ConfigException>()));
    });
  });

  group('GameConfigValidator — dungeon cross-references', () {
    test('menolak invalid next_room_ids reference', () {
      final broken = _minimalValidDungeons.replaceFirst(
        '"next_room_ids": ["room_b"]',
        '"next_room_ids": ["ghost_room"]',
      );
      expect(
        () => validator.validate(_loadFullRealConfig(dungeonsOverride: broken)),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('ghost_room'),
          ),
        ),
      );
    });

    test('menolak siklus graph antar-room', () {
      final cyclic = _minimalValidDungeons.replaceFirst(
        '"next_room_ids": []',
        '"next_room_ids": ["room_a"]',
      );
      expect(
        () => validator.validate(_loadFullRealConfig(dungeonsOverride: cyclic)),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('siklus'),
          ),
        ),
      );
    });

    test('menolak monster_id yang tidak ada di monsters.json', () {
      final broken = _minimalValidDungeons.replaceFirst(
        '"monster_id": "aether_slime"',
        '"monster_id": "unknown_dragon"',
      );
      expect(
        () => validator.validate(_loadFullRealConfig(dungeonsOverride: broken)),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('unknown_dragon'),
          ),
        ),
      );
    });

    test('menolak reward.loot_table_id yang tidak ada di loot_tables.json', () {
      final broken = _minimalValidDungeons.replaceFirst(
        '"next_room_ids": ["room_b"]',
        '"next_room_ids": ["room_b"], "reward": {"loot_table_id": "missing_loot"}',
      );
      expect(
        () => validator.validate(_loadFullRealConfig(dungeonsOverride: broken)),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('missing_loot'),
          ),
        ),
      );
    });

    test(
      'menolak completion_condition tanpa target spawn wajib yang valid',
      () {
        final broken = _minimalValidDungeons.replaceFirst(
          '"required": true',
          '"required": false',
        );
        expect(
          () =>
              validator.validate(_loadFullRealConfig(dungeonsOverride: broken)),
          throwsA(isA<ConfigException>()),
        );
      },
    );
  });
}
