import 'dart:io';

import 'package:echoes_of_aether/core/errors/config_exception.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_reward.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/loot_table.dart';
import 'package:flutter_test/flutter_test.dart';

String asset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig loadReal() {
  const parser = GameConfigParser();
  final settings = asset('game_config.json');
  return GameConfig(
    monsters: const MonsterConfigParser().parse(asset('monsters.json')),
    revive: parser.parseRevive(settings),
    progression: parser.parseProgression(settings),
    dungeonCompletion: parser.parseDungeonCompletion(settings),
    items: const ItemConfigParser().parse(asset('items.json')),
    lootTables: const LootConfigParser().parse(asset('loot_tables.json')),
  );
}

void main() {
  group('ItemConfigParser', () {
    const parser = ItemConfigParser();

    test('membaca items.json yang dikirim bersama game', () {
      final items = parser.parse(asset('items.json'));
      expect(items['slime_gel']!.category, ItemCategory.material);
      expect(items['small_potion']!.category, ItemCategory.consumable);
      expect(items['small_potion']!.maxStack, 99);
      expect(items['ancient_fragment']!.rarity, ItemRarity.uncommon);
    });

    test('rarity dan max_stack memakai default jika tidak ditulis', () {
      final items = parser.parse(
        '{"items":[{"id":"a","name":"A","category":"material"}]}',
      );
      expect(items['a']!.rarity, ItemRarity.common);
      expect(items['a']!.maxStack, 999);
    });

    test('kategori equipment belum didukung dan dijelaskan', () {
      expect(
        () => parser.parse(
          '{"items":[{"id":"a","name":"A","category":"equipment"}]}',
        ),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('equipment'),
          ),
        ),
      );
    });

    test('kategori dan rarity tidak dikenal ditolak', () {
      expect(
        () => parser.parse(
          '{"items":[{"id":"a","name":"A","category":"sihir"}]}',
        ),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => parser.parse(
          '{"items":[{"id":"a","name":"A","category":"material","rarity":"mythic"}]}',
        ),
        throwsA(isA<ConfigException>()),
      );
    });

    test('id ganda dan max_stack tidak valid ditolak', () {
      const one = '{"id":"a","name":"A","category":"material"';
      expect(
        () => parser.parse('{"items":[$one},$one}]}'),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => parser.parse('{"items":[$one,"max_stack":0}]}'),
        throwsA(isA<ConfigException>()),
      );
    });
  });

  group('LootConfigParser', () {
    const parser = LootConfigParser();

    test('membaca loot_tables.json yang dikirim bersama game', () {
      final tables = parser.parse(asset('loot_tables.json'));
      final slime = tables['slime_loot']!;
      expect(slime.entries.first.itemId, 'slime_gel');
      expect(slime.entries.first.minQuantity, 1);
      expect(slime.entries.first.maxQuantity, 2);
      expect(slime.entries[1].maxQuantity, 1); // default = min
    });

    test('chance di luar (0, 1] ditolak', () {
      String src(String chance) =>
          '{"loot_tables":[{"id":"t","entries":[{"item_id":"a","chance":$chance}]}]}';
      expect(() => parser.parse(src('0')), throwsA(isA<ConfigException>()));
      expect(() => parser.parse(src('1.5')), throwsA(isA<ConfigException>()));
      expect(parser.parse(src('1.0')).containsKey('t'), isTrue);
    });

    test('max_quantity lebih kecil dari min_quantity ditolak', () {
      const src = '''{"loot_tables":[{"id":"t","entries":[
        {"item_id":"a","chance":0.5,"min_quantity":3,"max_quantity":2}]}]}''';
      expect(() => parser.parse(src), throwsA(isA<ConfigException>()));
    });
  });

  group('GameConfigValidator', () {
    const validator = GameConfigValidator();

    test('seluruh konfigurasi asli saling konsisten', () {
      expect(() => validator.validate(loadReal()), returnsNormally);
    });

    test('loot table yang merujuk item tidak ada ditolak', () {
      final real = loadReal();
      final broken = GameConfig(
        monsters: real.monsters,
        revive: real.revive,
        progression: real.progression,
        items: real.items,
        lootTables: {
          'x': const LootTable(
            id: 'x',
            entries: [LootEntry(itemId: 'tidak_ada', chance: 0.5)],
          ),
        },
      );
      expect(
        () => validator.validate(broken),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('tidak_ada'),
          ),
        ),
      );
    });

    test('monster yang merujuk loot table tidak ada ditolak', () {
      final real = loadReal();
      final broken = GameConfig(
        monsters: real.monsters,
        revive: real.revive,
        progression: real.progression,
        items: real.items,
        lootTables: const {},
      );
      expect(
        () => validator.validate(broken),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('loot_table_id'),
          ),
        ),
      );
    });

    test('dungeon_completion dengan loot_table_id tidak ada ditolak', () {
      final real = loadReal();
      final broken = GameConfig(
        monsters: real.monsters,
        revive: real.revive,
        progression: real.progression,
        dungeonCompletion: const DungeonCompletionReward(
          expReward: 50,
          goldReward: 20,
          lootTableId: 'hilang',
        ),
        items: real.items,
        lootTables: real.lootTables,
      );
      expect(
        () => validator.validate(broken),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('hilang'),
          ),
        ),
      );
    });
  });
}
