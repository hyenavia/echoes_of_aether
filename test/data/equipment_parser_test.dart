import 'dart:io';

import 'package:echoes_of_aether/core/errors/config_exception.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:flutter_test/flutter_test.dart';

String asset(String name) => File('assets/data/$name').readAsStringSync();

String itemJson(String extra) =>
    '{"items":[{"id":"a","name":"A","category":"equipment"$extra}]}';

void main() {
  const parser = ItemConfigParser();

  group('equipment di items.json', () {
    test('membaca definisi equipment yang dikirim bersama game', () {
      final items = parser.parse(asset('items.json'));
      final sword = items['rusty_sword']!;
      expect(sword.category, ItemCategory.equipment);
      expect(sword.equipment!.slot, EquipmentSlot.weapon);
      expect(sword.equipment!.weaponType, 'sword');
      expect(sword.equipment!.baseStats.atk, 4);
      expect(items['hunters_bow']!.equipment!.baseStats.attackSpeed, 0.1);
      expect(items['leather_cap']!.equipment!.slot, EquipmentSlot.head);
      expect(items['guardian_amulet']!.rarity, ItemRarity.rare);
    });

    test('semua slot MVP terwakili', () {
      final items = parser.parse(asset('items.json'));
      final slots = items.values
          .where((i) => i.isEquipment)
          .map((i) => i.equipment!.slot)
          .toSet();
      expect(slots, EquipmentSlot.values.toSet());
    });

    test('equipment wajib memiliki section "equipment"', () {
      expect(
        () => parser.parse(itemJson('')),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('equipment'),
          ),
        ),
      );
    });

    test('slot tidak dikenal ditolak', () {
      expect(
        () => parser.parse(
          itemJson(',"equipment":{"slot":"kaki","stats":{"atk":1}}'),
        ),
        throwsA(isA<ConfigException>()),
      );
    });

    test('stat salah ketik ditolak (field tidak dikenal)', () {
      expect(
        () => parser.parse(
          itemJson(',"equipment":{"slot":"weapon","stats":{"atck":1}}'),
        ),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('atck'),
          ),
        ),
      );
    });

    test('stats kosong, nol semua, atau negatif ditolak', () {
      for (final stats in ['{}', '{"atk":0}', '{"atk":-1}']) {
        expect(
          () => parser.parse(
            itemJson(',"equipment":{"slot":"weapon","stats":$stats}'),
          ),
          throwsA(isA<ConfigException>()),
          reason: stats,
        );
      }
    });

    test('weapon_type hanya untuk slot weapon', () {
      expect(
        () => parser.parse(
          itemJson(
            ',"equipment":{"slot":"head","weapon_type":"sword","stats":{"def":1}}',
          ),
        ),
        throwsA(isA<ConfigException>()),
      );
    });

    test('section equipment pada item non-equipment ditolak', () {
      expect(
        () => parser.parse(
          '{"items":[{"id":"a","name":"A","category":"material",'
          '"equipment":{"slot":"weapon","stats":{"atk":1}}}]}',
        ),
        throwsA(isA<ConfigException>()),
      );
    });

    test('hp_pct, atk_pct, def_pct, fixed_stats, dan sellable diparse', () {
      final parsed = parser.parse('''
{
  "items": [
    {
      "id": "event_blade",
      "name": "Event Blade",
      "category": "equipment",
      "rarity": "rare",
      "sellable": false,
      "equipment": {
        "slot": "weapon",
        "fixed_stats": true,
        "stats": {
          "atk": 12,
          "hp_pct": 0.1,
          "atk_pct": 0.15,
          "def_pct": 0.05
        }
      }
    }
  ]
}
''');
      final def = parsed['event_blade']!;
      expect(def.sellable, isFalse);
      expect(def.equipment!.fixedStats, isTrue);
      expect(def.equipment!.baseStats.atk, 12);
      expect(def.equipment!.baseStats.hpPct, 0.1);
      expect(def.equipment!.baseStats.atkPct, 0.15);
      expect(def.equipment!.baseStats.defPct, 0.05);
    });

    test('hp_pct/atk_pct/def_pct negatif atau > 1.0 ditolak', () {
      for (final stats in [
        '{"hp_pct":-0.01}',
        '{"atk_pct":-0.1}',
        '{"def_pct":-1}',
        '{"hp_pct":1.01}',
        '{"atk_pct":1.5}',
        '{"def_pct":2.0}',
      ]) {
        expect(
          () => parser.parse(
            itemJson(',"equipment":{"slot":"weapon","stats":$stats}'),
          ),
          throwsA(isA<ConfigException>()),
          reason: stats,
        );
      }
    });

    test('fixed_stats dan sellable bukan boolean ditolak', () {
      expect(
        () => parser.parse(
          itemJson(
            ',"equipment":{"slot":"weapon","fixed_stats":"yes","stats":{"atk":1}}',
          ),
        ),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => parser.parse(
          itemJson(
            ',"sellable":0,"equipment":{"slot":"weapon","stats":{"atk":1}}',
          ),
        ),
        throwsA(isA<ConfigException>()),
      );
    });
  });

  group('GameConfigParser.parseEquipment', () {
    const config = GameConfigParser();

    test('membaca roll_variance dan pct_caps dari game_config.json', () {
      final parsed = config.parseEquipment(asset('game_config.json'));
      expect(parsed.rollVariance, 0.15);
      expect(parsed.pctCaps.hpPct, 0.6);
      expect(parsed.pctCaps.atkPct, 0.5);
      expect(parsed.pctCaps.defPct, 0.5);
    });

    test('section opsional: default jika tidak ada', () {
      final parsed = config.parseEquipment('{}');
      expect(parsed.rollVariance, 0.15);
      expect(parsed.pctCaps.hpPct, 0.6);
      expect(parsed.pctCaps.atkPct, 0.5);
      expect(parsed.pctCaps.defPct, 0.5);
    });

    test('roll_variance dan pct_caps tidak valid ditolak', () {
      expect(
        () => config.parseEquipment('{"equipment":{"roll_variance":0.9}}'),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => config.parseEquipment('{"equipment":{"roll_variance":-0.1}}'),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () =>
            config.parseEquipment('{"equipment":{"pct_caps":{"hp_pct":-0.1}}}'),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => config.parseEquipment(
          '{"equipment":{"pct_caps":{"unknown_pct":0.2}}}',
        ),
        throwsA(isA<ConfigException>()),
      );
    });
  });
}
