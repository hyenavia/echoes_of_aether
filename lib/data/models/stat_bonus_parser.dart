import '../../core/errors/config_exception.dart';
import '../../domain/entities/equipment.dart';
import 'json_reader.dart';

/// Membaca blok stat bonus ({"atk": 4, "crit_rate": 0.02, ...}) yang dipakai
/// bersama oleh equipment, skill pasif, dan specialization.
class StatBonusParser {
  const StatBonusParser._();

  static const Set<String> keys = {
    'hp',
    'atk',
    'def',
    'crit_rate',
    'crit_damage',
    'attack_speed',
    'move_speed',
    'attack_range',
    'skill_haste',
  };

  /// Field tidak dikenal ditolak, dan minimal satu stat harus lebih dari 0.
  static EquipmentStats parse(
    JsonReader r,
    Map<String, dynamic> map,
    String where,
  ) {
    r.ensureKnownKeys(map, where, keys);
    double stat(String key, {double max = double.infinity}) =>
        r.number(map, where, key, min: 0, max: max, fallback: 0.0);

    final stats = EquipmentStats(
      hp: stat('hp'),
      atk: stat('atk'),
      def: stat('def'),
      critRate: stat('crit_rate', max: 1),
      critDamage: stat('crit_damage'),
      attackSpeed: stat('attack_speed'),
      moveSpeed: stat('move_speed'),
      attackRange: stat('attack_range'),
      skillHaste: stat('skill_haste', max: EquipmentStats.maxSkillHaste),
    );
    if (stats.isEmpty) {
      throw ConfigException(
        '${r.file}: $where harus memiliki minimal satu stat lebih dari 0.',
      );
    }
    return stats;
  }
}
