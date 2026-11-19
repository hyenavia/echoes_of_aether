import 'dart:convert';
import 'dart:io';

import 'package:echoes_of_aether/core/errors/config_exception.dart';
import 'package:echoes_of_aether/data/models/boss_spire_config_parser.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

void main() {
  group('BossSpireConfigParser & GameConfigValidator', () {
    test(
      'assets/data/boss_spire.json valid dan terintegrasi dengan aset nyata',
      () {
        const parser = GameConfigParser();
        const dungeonParser = DungeonConfigParser();
        final settings = _readAsset('game_config.json');
        final dungeonsJson = _readAsset('dungeons.json');

        final spire = const BossSpireConfigParser().parse(
          _readAsset('boss_spire.json'),
        );
        expect(spire.spireId, 'boss_spire');
        expect(spire.name, isNotEmpty);
        expect(spire.arenaMapRef, 'ancient_heart_map');
        expect(spire.floors.length, 20);
        expect(spire.maxFloor, 20);

        // Pastikan lantai pertama dan terakhir memiliki spesifikasi yang benar
        final floor1 = spire.floorFor(1);
        expect(floor1, isNotNull);
        expect(floor1!.recommendedLevel, 10);
        expect(floor1.firstClearReward.gold, greaterThan(0));
        expect(floor1.firstClearReward.exp, greaterThan(0));
        expect(
          floor1.firstClearReward.currency['aether_shard'],
          greaterThan(0),
        );

        final floor20 = spire.floorFor(20);
        expect(floor20, isNotNull);
        expect(floor20!.recommendedLevel, 86);
        expect(floor20.baseStats.hp, greaterThan(floor1.baseStats.hp));
        expect(floor20.baseStats.atk, greaterThan(floor1.baseStats.atk));

        final config = GameConfig(
          monsters: const MonsterConfigParser().parse(
            _readAsset('monsters.json'),
          ),
          damage: parser.parseDamage(settings),
          difficulty: parser.parseDifficulty(settings),
          farming: parser.parseFarming(settings),
          revive: parser.parseRevive(settings),
          progression: parser.parseProgression(settings),
          equipment: parser.parseEquipment(settings),
          time: parser.parseTime(settings),
          claimedRewards: parser.parseClaimedRewards(settings),
          currencies: parser.parseCurrencies(settings),
          notifications: parser.parseNotifications(settings),
          items: const ItemConfigParser().parse(_readAsset('items.json')),
          lootTables: const LootConfigParser().parse(
            _readAsset('loot_tables.json'),
          ),
          skills: const SkillConfigParser().parse(_readAsset('skills.json')),
          specializations: const SpecializationConfigParser().parse(
            _readAsset('specializations.json'),
          ),
          dungeons: dungeonParser.parse(
            dungeonsJson,
            ascensionMultiplier: parser
                .parseDifficulty(settings)
                .ascensionMultiplier,
          ),
          mapLayouts: dungeonParser.parseMaps(dungeonsJson),
          shop: const ShopConfigParser().parse(_readAsset('shop.json')),
          bossSpire: spire,
        );

        expect(
          () => const GameConfigValidator().validate(config),
          returnsNormally,
        );
      },
    );

    test(
      'toEnemyDefinition mengonversi lantai menjadi combatant yang valid',
      () {
        final spire = const BossSpireConfigParser().parse(
          _readAsset('boss_spire.json'),
        );
        final floor1 = spire.floorFor(1)!;
        final template = EnemyDefinition(
          id: 'ancient_heart_guardian',
          name: 'Ancient Heart Guardian',
          level: 6,
          isBoss: true,
          stats: const CombatStats(
            maxHp: 420,
            atk: 20,
            def: 6,
            attackSpeed: 1.0,
            moveSpeed: 1.4,
            attackRange: 1.5,
          ),
          detectionRange: 10.0,
          expReward: 0,
          goldReward: 0,
        );

        final bossDef = floor1.toEnemyDefinition(spriteTemplate: template);
        expect(bossDef.id, floor1.bossId);
        expect(bossDef.name, floor1.bossName);
        expect(bossDef.isBoss, isTrue);
        expect(bossDef.stats.maxHp, floor1.baseStats.hp);
        expect(bossDef.stats.atk, floor1.baseStats.atk);
        expect(bossDef.stats.def, floor1.baseStats.def);
        expect(bossDef.stats.lifesteal, floor1.baseStats.lifesteal);
        expect(bossDef.stats.spellVamp, floor1.baseStats.spellVamp);
      },
    );

    test('menolak floors kosong atau kunci tidak dikenal', () {
      const parser = BossSpireConfigParser();
      expect(
        () => parser.parse('{"unknown_key": 123}'),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => parser.parse('''{
          "spire_id": "spire",
          "name": "Spire",
          "arena_map_ref": "map",
          "floors": []
        }'''),
        throwsA(isA<ConfigException>()),
      );
    });

    test('menolak nomor lantai tidak sekuensial atau ganda', () {
      const parser = BossSpireConfigParser();
      final validFloorJson = jsonEncode({
        "floor": 2,
        "name": "Floor 2",
        "boss_id": "b2",
        "boss_name": "Boss 2",
        "sprite_ref": "ancient_heart_guardian",
        "recommended_level": 10,
        "base_stats": {"hp": 100, "atk": 10, "def": 5},
        "first_clear_reward": {"exp": 10, "gold": 10},
      });

      expect(
        () => parser.parse('''{
          "spire_id": "spire",
          "name": "Spire",
          "arena_map_ref": "map",
          "floors": [$validFloorJson]
        }'''),
        throwsA(isA<ConfigException>()),
      );
    });
  });
}
