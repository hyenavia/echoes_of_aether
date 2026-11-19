import '../../core/errors/config_exception.dart';
import '../../domain/entities/skill_definition.dart';
import 'json_reader.dart';
import 'stat_bonus_parser.dart';

/// Membaca dan memvalidasi skills.json. Kecocokan specialization_id dan
/// konsistensi tambahan diperiksa oleh `GameConfigValidator`.
class SkillConfigParser {
  const SkillConfigParser();

  static const JsonReader _r = JsonReader('skills.json');

  static const Set<String> _commonKeys = {
    'id',
    'name',
    'type',
    'unlock_level',
    'specialization_id',
    'effect',
    'max_level',
    'upgrade_cost',
    'base_value',
    'value_per_level',
  };
  static const Set<String> _activeKeys = {
    'cooldown',
    'damage_type',
    'damage_multiplier',
    'heal_percent',
    'target_type',
    'range',
    'radius',
    'use_when_hp_below',
    'min_enemies',
  };

  Map<String, SkillDefinition> parse(String source) {
    final root = _r.decodeRoot(source);
    final list = _r.list(root, 'root', 'skills');

    final result = <String, SkillDefinition>{};
    for (var i = 0; i < list.length; i++) {
      final where = 'skills[$i]';
      final map = _r.asMap(list[i], where);
      final id = _r.string(map, where, 'id');
      if (result.containsKey(id)) {
        throw ConfigException('skills.json: id ganda "$id".');
      }
      final type = _type(_r.string(map, where, 'type'), where);
      result[id] = type == SkillType.active
          ? _active(map, where, id)
          : _passive(map, where, id);
    }
    return result;
  }

  SkillDefinition _passive(Map<String, dynamic> map, String where, String id) {
    _r.ensureKnownKeys(map, where, {..._commonKeys, 'stats', 'cooldown'});

    final effect = map['effect'] == null
        ? SkillEffectType.statModifier
        : _effect(_r.string(map, where, 'effect'), where);
    if (effect != SkillEffectType.statModifier) {
      throw ConfigException(
        'skills.json: $where skill passive harus memiliki effect "stat_modifier".',
      );
    }

    final cooldown = map['cooldown'] == null
        ? 0.0
        : _r.number(map, where, 'cooldown', min: 0);
    final maxLevel = _r.integer(map, where, 'max_level', min: 1, fallback: 5);
    final upgradeCost = _r.integer(
      map,
      where,
      'upgrade_cost',
      min: 0,
      fallback: 50,
    );
    final baseValue = map['base_value'] == null
        ? 1.0
        : _r.number(map, where, 'base_value', min: 0, minExclusive: true);
    final valuePerLevel = map['value_per_level'] == null
        ? 0.0
        : _r.number(map, where, 'value_per_level', min: 0);

    final sw = '$where.stats';
    return SkillDefinition(
      id: id,
      name: _r.string(map, where, 'name'),
      type: SkillType.passive,
      unlockLevel: _r.integer(map, where, 'unlock_level', min: 1, fallback: 1),
      specializationId: _optionalString(map, where, 'specialization_id'),
      cooldownSeconds: cooldown,
      effect: SkillEffectType.statModifier,
      baseValue: baseValue,
      valuePerLevel: valuePerLevel,
      maxLevel: maxLevel,
      upgradeCost: upgradeCost,
      passiveStats: StatBonusParser.parse(_r, _r.asMap(map['stats'], sw), sw),
    );
  }

  SkillDefinition _active(Map<String, dynamic> map, String where, String id) {
    _r.ensureKnownKeys(map, where, {..._commonKeys, ..._activeKeys});

    final effect = _effect(
      map['effect'] == null ? 'damage' : _r.string(map, where, 'effect'),
      where,
    );
    if (effect == SkillEffectType.statModifier) {
      throw ConfigException(
        'skills.json: $where skill active tidak mendukung effect "stat_modifier".',
      );
    }

    final target = _target(
      map['target_type'] == null
          ? (effect == SkillEffectType.healing ? 'self' : 'single')
          : _r.string(map, where, 'target_type'),
      where,
    );

    final maxLevel = _r.integer(map, where, 'max_level', min: 1, fallback: 5);
    final upgradeCost = _r.integer(
      map,
      where,
      'upgrade_cost',
      min: 0,
      fallback: 50,
    );
    final valuePerLevel = map['value_per_level'] == null
        ? 0.0
        : _r.number(map, where, 'value_per_level', min: 0);

    late final double baseValue;
    SkillDamageType? damageType;
    double radius = 0;

    if (effect == SkillEffectType.healing) {
      if (target != SkillTarget.self) {
        throw ConfigException(
          'skills.json: $where skill healing harus bertarget "self".',
        );
      }
      if (map.containsKey('damage_type') && map['damage_type'] != null) {
        throw ConfigException(
          'skills.json: $where skill healing tidak boleh memiliki "damage_type".',
        );
      }
      final key = map.containsKey('base_value') ? 'base_value' : 'heal_percent';
      baseValue = _r.number(
        map,
        where,
        key,
        min: 0,
        minExclusive: true,
        max: 1,
      );
      if (baseValue + valuePerLevel * (maxLevel - 1) > 1.0) {
        throw ConfigException(
          'skills.json: $where nilai healing maksimum melebihi 1.0.',
        );
      }
    } else {
      if (target == SkillTarget.self) {
        throw ConfigException(
          'skills.json: $where skill damage tidak boleh bertarget "self".',
        );
      }
      damageType = map['damage_type'] == null
          ? SkillDamageType.physical
          : _damageType(_r.string(map, where, 'damage_type'), where);
      final key = map.containsKey('base_value')
          ? 'base_value'
          : 'damage_multiplier';
      baseValue = _r.number(map, where, key, min: 0, minExclusive: true);
      if (target == SkillTarget.area) {
        radius = _r.number(map, where, 'radius', min: 0, minExclusive: true);
      }
    }

    return SkillDefinition(
      id: id,
      name: _r.string(map, where, 'name'),
      type: SkillType.active,
      unlockLevel: _r.integer(map, where, 'unlock_level', min: 1, fallback: 1),
      specializationId: _optionalString(map, where, 'specialization_id'),
      cooldownSeconds: _r.number(
        map,
        where,
        'cooldown',
        min: 0,
        minExclusive: true,
      ),
      effect: effect,
      damageType: damageType,
      targetType: target,
      baseValue: baseValue,
      valuePerLevel: valuePerLevel,
      maxLevel: maxLevel,
      upgradeCost: upgradeCost,
      range: map['range'] == null
          ? null
          : _r.number(map, where, 'range', min: 0, minExclusive: true),
      radius: radius,
      useWhenHpBelow: map['use_when_hp_below'] == null
          ? null
          : _r.number(
              map,
              where,
              'use_when_hp_below',
              min: 0,
              minExclusive: true,
              max: 1,
            ),
      minEnemies: _r.integer(map, where, 'min_enemies', min: 1, fallback: 2),
    );
  }

  String? _optionalString(Map<String, dynamic> map, String where, String key) =>
      map[key] == null ? null : _r.string(map, where, key);

  SkillType _type(String raw, String where) => switch (raw) {
    'active' => SkillType.active,
    'passive' => SkillType.passive,
    _ => throw ConfigException(
      'skills.json: $where."type" tidak dikenal: "$raw" '
      '(pilihan: active, passive).',
    ),
  };

  SkillEffectType _effect(String raw, String where) => switch (raw) {
    'damage' => SkillEffectType.damage,
    'heal' || 'healing' => SkillEffectType.healing,
    'stat_modifier' => SkillEffectType.statModifier,
    _ => throw ConfigException(
      'skills.json: $where."effect" tidak dikenal: "$raw" '
      '(pilihan: damage, healing, stat_modifier).',
    ),
  };

  SkillDamageType _damageType(String raw, String where) => switch (raw) {
    'physical' => SkillDamageType.physical,
    'magic' => SkillDamageType.magic,
    'true_damage' || 'trueDamage' => SkillDamageType.trueDamage,
    _ => throw ConfigException(
      'skills.json: $where."damage_type" tidak dikenal: "$raw" '
      '(pilihan: physical, magic, true_damage).',
    ),
  };

  SkillTarget _target(String raw, String where) => switch (raw) {
    'single' => SkillTarget.single,
    'area' => SkillTarget.area,
    'self' => SkillTarget.self,
    _ => throw ConfigException(
      'skills.json: $where."target_type" tidak dikenal: "$raw" '
      '(pilihan: single, area, self).',
    ),
  };
}
