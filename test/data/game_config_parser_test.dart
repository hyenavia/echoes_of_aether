import 'package:echoes_of_aether/core/errors/config_exception.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/domain/services/damage_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = GameConfigParser();

  group('parseDamage', () {
    test('membaca konfigurasi damage formula ratio', () {
      final c = parser.parseDamage('{"damage": {"formula": "ratio"}}');
      expect(c.formula, DamageFormula.ratio);
    });

    test('membaca konfigurasi damage formula subtractive', () {
      final c = parser.parseDamage('{"damage": {"formula": "subtractive"}}');
      expect(c.formula, DamageFormula.subtractive);
    });

    test('damage section opsional: default ratio jika tidak ada', () {
      final c1 = parser.parseDamage('{}');
      expect(c1.formula, DamageFormula.ratio);

      final c2 = parser.parseDamage('{"damage": {}}');
      expect(c2.formula, DamageFormula.ratio);
    });

    test('formula tidak dikenal ditolak dengan pesan jelas', () {
      expect(
        () => parser.parseDamage('{"damage": {"formula": "exponential"}}'),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('tidak dikenal: "exponential"'),
          ),
        ),
      );
    });

    test('tipe formula bukan string ditolak', () {
      expect(
        () => parser.parseDamage('{"damage": {"formula": 123}}'),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('harus berupa teks'),
          ),
        ),
      );
    });

    test('damage bukan object ditolak', () {
      expect(
        () => parser.parseDamage('{"damage": "ratio"}'),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('"damage" harus berupa object'),
          ),
        ),
      );
    });
  });

  group('parseRevive', () {
    test('membaca konfigurasi revive', () {
      final c = parser.parseRevive('''
      {"revive": {"delay_seconds": 3, "hp_percent": 0.3,
                  "invulnerability_seconds": 2, "cooldown_seconds": 90}}''');
      expect(c.delaySeconds, 3.0);
      expect(c.hpPercent, 0.3);
      expect(c.invulnerabilitySeconds, 2.0);
      expect(c.cooldownSeconds, 90.0);
    });

    test('field yang tidak ada memakai nilai default GDD', () {
      final c = parser.parseRevive('{"revive": {}}');
      expect(c.delaySeconds, 3.0);
      expect(c.hpPercent, 0.3);
      expect(c.cooldownSeconds, 90.0);
    });

    test('hp_percent di luar (0, 1] ditolak', () {
      expect(
        () => parser.parseRevive('{"revive": {"hp_percent": 1.5}}'),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => parser.parseRevive('{"revive": {"hp_percent": 0}}'),
        throwsA(isA<ConfigException>()),
      );
    });

    test('nilai negatif dan tipe salah ditolak', () {
      expect(
        () => parser.parseRevive('{"revive": {"cooldown_seconds": -1}}'),
        throwsA(isA<ConfigException>()),
      );
      expect(
        () => parser.parseRevive('{"revive": {"delay_seconds": "3"}}'),
        throwsA(isA<ConfigException>()),
      );
    });

    test('section revive wajib ada', () {
      expect(() => parser.parseRevive('{}'), throwsA(isA<ConfigException>()));
    });
  });
}
