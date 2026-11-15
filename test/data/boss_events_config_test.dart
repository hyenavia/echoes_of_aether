import 'dart:convert';
import 'dart:io';

import 'package:echoes_of_aether/core/errors/config_exception.dart';
import 'package:echoes_of_aether/data/models/boss_events_config_parser.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/boss_event.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/currency_config.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

void main() {
  group('BossEventsConfigParser & GameConfigValidator', () {
    test(
      'assets/data/boss_events.json valid dan terintegrasi dengan aset nyata',
      () {
        const parser = GameConfigParser();
        const dungeonParser = DungeonConfigParser();
        final settings = _readAsset('game_config.json');
        final dungeonsJson = _readAsset('dungeons.json');

        final bossEvents = const BossEventsConfigParser().parse(
          _readAsset('boss_events.json'),
        );
        expect(bossEvents.daily.questId, 'daily_boss');
        expect(bossEvents.daily.powerFactor, 1.25);
        expect(bossEvents.daily.pool.length, 3);
        expect(bossEvents.weekly.questId, 'weekly_boss');
        expect(bossEvents.weekly.powerFactor, 1.5);
        expect(bossEvents.weekly.pool.length, 2);
        expect(bossEvents.arenaMapRef, 'ancient_heart_map');

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
          dungeonCompletion: parser.parseDungeonCompletion(settings),
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
          bossEvents: bossEvents,
          shop: const ShopConfigParser().parse(_readAsset('shop.json')),
        );

        expect(
          () => const GameConfigValidator().validate(config),
          returnsNormally,
        );
      },
    );

    test(
      'parser menolak pool kosong, sprite_tint invalid, dan unknown key',
      () {
        const parser = BossEventsConfigParser();
        final base =
            jsonDecode(_readAsset('boss_events.json')) as Map<String, dynamic>;

        final emptyPool = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
        (emptyPool['daily'] as Map<String, dynamic>)['pool'] = [];
        expect(
          () => parser.parse(jsonEncode(emptyPool)),
          throwsA(isA<ConfigException>()),
        );

        final badTint = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
        (((badTint['daily'] as Map<String, dynamic>)['pool'] as List).first
                as Map<String, dynamic>)['sprite_tint'] =
            'not_hex';
        expect(
          () => parser.parse(jsonEncode(badTint)),
          throwsA(isA<ConfigException>()),
        );

        final unknownKey = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
        unknownKey['unexpected'] = 123;
        expect(
          () => parser.parse(jsonEncode(unknownKey)),
          throwsA(isA<ConfigException>()),
        );
      },
    );

    test('validator menolak sprite_ref dan arena_map_ref yang tidak ada', () {
      final validBossEvents = const BossEventsConfigParser().parse(
        _readAsset('boss_events.json'),
      );
      const monsters = {
        'ancient_heart_guardian': EnemyDefinition(
          id: 'ancient_heart_guardian',
          name: 'Ancient Heart Guardian',
          level: 6,
          isBoss: true,
          stats: CombatStats(maxHp: 420, atk: 20, def: 6),
        ),
      };
      const baseProg = ProgressionConfig(
        baseStats: CombatStats(maxHp: 100, atk: 12, def: 2),
        perLevel: LevelGrowth(hp: 15, atk: 2, def: 0.5),
      );

      // sprite_ref tidak ada di monsters
      final missingSprite = BossEventsConfig(
        daily: BossTierConfig(
          questId: 'daily_boss',
          powerFactor: 1.0,
          reward: validBossEvents.daily.reward,
          pool: const [
            BossEvent(
              id: 'b1',
              name: 'Missing Sprite Boss',
              spriteRef: 'missing_monster',
              spriteTint: '#C86432',
              baseStats: BossBaseStats(hp: 400, atk: 20, def: 5),
            ),
          ],
        ),
        weekly: validBossEvents.weekly,
        arenaMapRef: 'ancient_heart_map',
      );
      expect(
        () => const GameConfigValidator().validate(
          GameConfig(
            monsters: monsters,
            revive: const ReviveConfig(),
            progression: baseProg,
            items: const {},
            lootTables: const {},
            currencies: CurrencyDefinition.defaults,
            mapLayouts: const {
              'ancient_heart_map': ['###', '#.#', '###'],
            },
            bossEvents: missingSprite,
          ),
        ),
        throwsA(isA<ConfigException>()),
      );

      // arena_map_ref tidak ada di mapLayouts/dungeons
      final missingArena = BossEventsConfig(
        daily: validBossEvents.daily,
        weekly: validBossEvents.weekly,
        arenaMapRef: 'missing_map',
      );
      expect(
        () => const GameConfigValidator().validate(
          GameConfig(
            monsters: monsters,
            revive: const ReviveConfig(),
            progression: baseProg,
            items: const {},
            lootTables: const {},
            currencies: CurrencyDefinition.defaults,
            mapLayouts: const {
              'ancient_heart_map': ['###', '#.#', '###'],
            },
            dungeons: const <String, DungeonDefinition>{},
            bossEvents: missingArena,
          ),
        ),
        throwsA(isA<ConfigException>()),
      );
    });
  });
}
