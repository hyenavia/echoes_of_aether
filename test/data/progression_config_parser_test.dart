import 'dart:io';

import 'package:echoes_of_aether/core/errors/config_exception.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = GameConfigParser();

  group('parseProgression', () {
    test('membaca assets/data/game_config.json yang dikirim bersama game', () {
      final source = File('assets/data/game_config.json').readAsStringSync();
      final c = parser.parseProgression(source);
      expect(c.maxLevel, isNull);
      expect(c.baseStats.maxHp, 100);
      expect(c.expToNext(1), 60);
      expect(c.statsAt(2).maxHp, 115);
    });

    test('section progression wajib ada', () {
      expect(
        () => parser.parseProgression('{"revive": {}}'),
        throwsA(isA<ConfigException>()),
      );
    });

    test('max_level opsional dan mendukung null atau angka bulat >= 1', () {
      final baseSource = File('assets/data/game_config.json')
          .readAsStringSync();
      // Omit max_level
      final withoutMax = baseSource.replaceAll('"max_level": null,', '');
      expect(parser.parseProgression(withoutMax).maxLevel, isNull);

      // Explicit integer max_level
      final withMax = baseSource.replaceAll(
        '"max_level": null,',
        '"max_level": 50,',
      );
      expect(parser.parseProgression(withMax).maxLevel, 50);

      // Invalid max_level < 1
      final withZero = baseSource.replaceAll(
        '"max_level": null,',
        '"max_level": 0,',
      );
      expect(
        () => parser.parseProgression(withZero),
        throwsA(isA<ConfigException>()),
      );
    });

    test('field wajib yang hilang menyebut nama field', () {
      final source = File('assets/data/game_config.json')
          .readAsStringSync()
          .replaceAll('"base": 60,', '');
      expect(
        () => parser.parseProgression(source),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('base'),
          ),
        ),
      );
    });

    test('mendukung mode exponential untuk kompatibilitas regresi', () {
      final source = File('assets/data/game_config.json')
          .readAsStringSync()
          .replaceAll(
            '"exp": { "type": "polynomial", "base": 60, "exponent": 1.8 }',
            '"exp": { "type": "exponential", "base": 50, "growth": 1.4 }',
          );
      final c = parser.parseProgression(source);
      expect(c.expBase, 50);
      expect(c.expGrowth, 1.4);
      expect(c.expToNext(1), 50);
      expect(c.expToNext(2), 70);
    });

    test('exp growth < 1 pada exponential ditolak', () {
      final source = File('assets/data/game_config.json')
          .readAsStringSync()
          .replaceAll(
            '"exp": { "type": "polynomial", "base": 60, "exponent": 1.8 }',
            '"exp": { "type": "exponential", "base": 50, "growth": 0.5 }',
          );
      expect(
        () => parser.parseProgression(source),
        throwsA(isA<ConfigException>()),
      );
    });
  });

  group('monster rewards', () {
    const monster = '''
    {"monsters": [{
      "id": "m", "name": "M", "level": 1,
      "stats": {"hp": 10, "atk": 1, "def": 0},
      "attack_range": 1.0, "move_speed": 1.0 %EXTRA%
    }]}''';

    test('reward dibaca dari JSON', () {
      final src = monster.replaceAll(
        '%EXTRA%',
        ', "exp_reward": 12, "gold_reward": 4',
      );
      final m = const MonsterConfigParser().parse(src)['m']!;
      expect(m.expReward, 12);
      expect(m.goldReward, 4);
    });

    test('reward default 0 jika tidak ditulis', () {
      final m = const MonsterConfigParser().parse(
        monster.replaceAll('%EXTRA%', ''),
      )['m']!;
      expect(m.expReward, 0);
      expect(m.goldReward, 0);
    });

    test('reward negatif ditolak', () {
      final src = monster.replaceAll('%EXTRA%', ', "exp_reward": -1');
      expect(
        () => const MonsterConfigParser().parse(src),
        throwsA(isA<ConfigException>()),
      );
    });
  });
}
