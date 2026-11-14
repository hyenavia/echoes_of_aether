import 'dart:io';

import 'package:echoes_of_aether/core/errors/config_exception.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:flutter_test/flutter_test.dart';

const valid = '''
{
  "monsters": [
    {
      "id": "forest_slime",
      "name": "Forest Slime",
      "level": 1,
      "stats": { "hp": 50, "atk": 5, "def": 1 },
      "attack_range": 1.0,
      "move_speed": 1.2
    }
  ]
}
''';

void main() {
  const parser = MonsterConfigParser();

  test('membaca definisi valid dan memakai nilai default', () {
    final result = parser.parse(valid);
    final slime = result['forest_slime']!;
    expect(slime.name, 'Forest Slime');
    expect(slime.stats.maxHp, 50);
    expect(slime.stats.attackSpeed, 1.0); // default
    expect(slime.detectionRange, 6.0); // default
  });

  test('JSON rusak menghasilkan ConfigException', () {
    expect(() => parser.parse('{ bukan json'), throwsA(isA<ConfigException>()));
  });

  test('field wajib yang hilang menyebut nama field', () {
    final broken = valid.replaceAll('"hp": 50, ', '');
    expect(
      () => parser.parse(broken),
      throwsA(
        isA<ConfigException>().having(
          (e) => e.message,
          'message',
          contains('hp'),
        ),
      ),
    );
  });

  test('nilai di luar batas ditolak', () {
    final broken = valid.replaceAll('"move_speed": 1.2', '"move_speed": 0');
    expect(() => parser.parse(broken), throwsA(isA<ConfigException>()));
  });

  test('id ganda ditolak', () {
    final one = valid.substring(
      valid.indexOf('{', valid.indexOf('[')),
      valid.lastIndexOf('}', valid.lastIndexOf(']')) + 1,
    );
    final dup = '{"monsters": [$one, $one]}';
    expect(
      () => parser.parse(dup),
      throwsA(
        isA<ConfigException>().having(
          (e) => e.message,
          'message',
          contains('ganda'),
        ),
      ),
    );
  });

  test('membaca monsters.json asli mencakup normal, elite, dan boss', () {
    final monsters = parser.parse(
      File('assets/data/monsters.json').readAsStringSync(),
    );
    expect(monsters['forest_slime']!.tier, EnemyTier.normal);
    expect(monsters['aether_slime']!.tier, EnemyTier.normal);
    expect(monsters['forest_wolf']!.tier, EnemyTier.normal);
    expect(monsters['corrupted_treant']!.tier, EnemyTier.normal);
    expect(monsters['corrupted_guardian']!.tier, EnemyTier.elite);
    expect(monsters['ancient_heart_guardian']!.tier, EnemyTier.boss);
  });
}
