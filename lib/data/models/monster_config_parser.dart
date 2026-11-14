import 'dart:convert';

import '../../core/errors/config_exception.dart';
import '../../domain/entities/combat_stats.dart';
import '../../domain/entities/enemy_definition.dart';

/// Membaca dan memvalidasi monsters.json. Definisi yang tidak valid
/// menghasilkan [ConfigException] dengan pesan jelas, bukan state game rusak.
class MonsterConfigParser {
  const MonsterConfigParser();

  static const String _file = 'monsters.json';

  Map<String, EnemyDefinition> parse(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw ConfigException('$_file bukan JSON valid: ${e.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ConfigException('$_file: root harus berupa object.');
    }
    final list = decoded['monsters'];
    if (list is! List) {
      throw const ConfigException('$_file: "monsters" harus berupa array.');
    }

    final result = <String, EnemyDefinition>{};
    for (var i = 0; i < list.length; i++) {
      final definition = _parseOne(list[i], 'monsters[$i]');
      if (result.containsKey(definition.id)) {
        throw ConfigException('$_file: id ganda "${definition.id}".');
      }
      result[definition.id] = definition;
    }
    return result;
  }

  static final RegExp _hexTintPattern = RegExp(
    r'^#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
  );

  static bool isValidHexTint(String value) => _hexTintPattern.hasMatch(value);

  EnemyDefinition _parseOne(Object? raw, String where) {
    final map = _asMap(raw, where);
    final stats = _asMap(map['stats'], '$where.stats');
    final spriteRef = _optionalString(map, 'sprite_ref', where);
    final spriteTint = _optionalString(map, 'sprite_tint', where);
    if (spriteTint != null && !isValidHexTint(spriteTint)) {
      throw ConfigException(
        '$_file: $where."sprite_tint" harus berformat hex #RRGGBB atau '
        '#AARRGGBB (nilai: "$spriteTint").',
      );
    }
    return EnemyDefinition(
      id: _string(map, 'id', where),
      name: _string(map, 'name', where),
      level: _int(map, 'level', where, min: 1),
      detectionRange: _double(
        map,
        'detection_range',
        where,
        min: 0,
        fallback: 6.0,
      ),
      leashRange: map['leash_range'] == null
          ? null
          : _double(map, 'leash_range', where, min: 0),
      isElite: _optionalBool(map, 'is_elite', where),
      isBoss: _optionalBool(map, 'is_boss', where),
      expReward: _optionalInt(map, 'exp_reward', where),
      goldReward: _optionalInt(map, 'gold_reward', where),
      lootTableId: _optionalString(map, 'loot_table_id', where),
      spriteRef: spriteRef,
      spriteTint: spriteTint,
      isFinalBoss: _optionalBool(map, 'is_final_boss', where),
      stats: CombatStats(
        maxHp: _int(stats, 'hp', '$where.stats', min: 1),
        atk: _int(stats, 'atk', '$where.stats', min: 0),
        def: _int(stats, 'def', '$where.stats', min: 0),
        attackSpeed: _double(
          map,
          'attack_speed',
          where,
          min: 0,
          exclusive: true,
          fallback: 1.0,
        ),
        moveSpeed: _double(map, 'move_speed', where, min: 0, exclusive: true),
        attackRange: _double(
          map,
          'attack_range',
          where,
          min: 0,
          exclusive: true,
        ),
      ),
    );
  }

  Map<String, dynamic> _asMap(Object? value, String where) {
    if (value is Map<String, dynamic>) return value;
    throw ConfigException('$_file: $where harus berupa object.');
  }

  String _string(Map<String, dynamic> map, String key, String where) {
    final value = map[key];
    if (value is String && value.isNotEmpty) return value;
    throw ConfigException(
      '$_file: $where."$key" harus berupa teks tidak kosong.',
    );
  }

  int _int(
    Map<String, dynamic> map,
    String key,
    String where, {
    required int min,
  }) {
    final value = map[key];
    if (value is! int) {
      throw ConfigException(
        '$_file: $where."$key" harus berupa bilangan bulat.',
      );
    }
    if (value < min) {
      throw ConfigException(
        '$_file: $where."$key" harus >= $min (nilai: $value).',
      );
    }
    return value;
  }

  String? _optionalString(Map<String, dynamic> map, String key, String where) {
    if (map[key] == null) return null;
    return _string(map, key, where);
  }

  int _optionalInt(Map<String, dynamic> map, String key, String where) {
    if (map[key] == null) return 0;
    return _int(map, key, where, min: 0);
  }

  bool _optionalBool(Map<String, dynamic> map, String key, String where) {
    final value = map[key];
    if (value == null) return false;
    if (value is! bool) {
      throw ConfigException('$_file: $where."$key" harus berupa boolean.');
    }
    return value;
  }

  double _double(
    Map<String, dynamic> map,
    String key,
    String where, {
    required double min,
    bool exclusive = false,
    double? fallback,
  }) {
    final value = map[key];
    if (value == null && fallback != null) return fallback;
    if (value is! num) {
      throw ConfigException('$_file: $where."$key" harus berupa angka.');
    }
    final number = value.toDouble();
    final invalid = exclusive ? number <= min : number < min;
    if (invalid) {
      final op = exclusive ? '>' : '>=';
      throw ConfigException(
        '$_file: $where."$key" harus $op $min (nilai: $number).',
      );
    }
    return number;
  }
}
