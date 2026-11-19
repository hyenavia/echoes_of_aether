import '../../core/errors/config_exception.dart';
import '../../domain/entities/boss_event.dart';
import '../../domain/entities/boss_spire.dart';
import 'json_reader.dart';
import 'monster_config_parser.dart';

/// Membaca dan memvalidasi `assets/data/boss_spire.json`.
class BossSpireConfigParser {
  const BossSpireConfigParser();

  static const String _file = 'boss_spire.json';
  static const JsonReader _r = JsonReader(_file);

  static const Set<String> _rootKeys = {
    'spire_id',
    'name',
    'arena_map_ref',
    'floors',
  };

  static const Set<String> _floorKeys = {
    'floor',
    'name',
    'boss_id',
    'boss_name',
    'sprite_ref',
    'sprite_tint',
    'recommended_level',
    'affix_description',
    'base_stats',
    'first_clear_reward',
  };

  static const Set<String> _rewardKeys = {'currency', 'exp', 'gold'};

  static const Set<String> _statsKeys = {
    'hp',
    'atk',
    'def',
    'lifesteal',
    'spell_vamp',
  };

  BossSpireConfig parse(String source) {
    final root = _r.decodeRoot(source);
    _r.ensureKnownKeys(root, 'root', _rootKeys);

    final spireId = _r.string(root, 'root', 'spire_id');
    final name = _r.string(root, 'root', 'name');
    final arenaMapRef = _r.string(root, 'root', 'arena_map_ref');
    final rawFloors = _r.list(root, 'root', 'floors');

    if (rawFloors.isEmpty) {
      throw const ConfigException(
        '$_file: "floors" harus memiliki minimal 1 lantai.',
      );
    }

    final floors = <BossSpireFloorConfig>[];
    final seenFloors = <int>{};
    final seenBossIds = <String>{};

    for (var i = 0; i < rawFloors.length; i++) {
      final where = 'floors[$i]';
      final floorMap = _r.asMap(rawFloors[i], where);
      final floor = _parseFloor(floorMap, where);

      if (seenFloors.contains(floor.floor)) {
        throw ConfigException(
          '$_file: nomor lantai ganda ${floor.floor} pada $where.',
        );
      }
      seenFloors.add(floor.floor);

      if (seenBossIds.contains(floor.bossId)) {
        throw ConfigException(
          '$_file: boss_id ganda "${floor.bossId}" pada $where.',
        );
      }
      seenBossIds.add(floor.bossId);

      // Pastikan lantai terurut 1..N secara sekuensial tanpa loncatan.
      final expectedFloor = i + 1;
      if (floor.floor != expectedFloor) {
        throw ConfigException(
          '$_file: lantai pada indeks $i harus bernilai $expectedFloor (ditemukan ${floor.floor}).',
        );
      }

      floors.add(floor);
    }

    return BossSpireConfig(
      spireId: spireId,
      name: name,
      arenaMapRef: arenaMapRef,
      floors: List.unmodifiable(floors),
    );
  }

  BossSpireFloorConfig _parseFloor(Map<String, dynamic> map, String where) {
    _r.ensureKnownKeys(map, where, _floorKeys);

    final floor = _r.integer(map, where, 'floor', min: 1);
    final name = _r.string(map, where, 'name');
    final bossId = _r.string(map, where, 'boss_id');
    final bossName = _r.string(map, where, 'boss_name');
    final spriteRef = _r.string(map, where, 'sprite_ref');
    final spriteTint = _parseTint(map, where);
    final recommendedLevel = _r.integer(
      map,
      where,
      'recommended_level',
      min: 1,
    );
    final affixDescription = map['affix_description'] == null
        ? null
        : _r.string(map, where, 'affix_description');

    final baseStats = _parseStats(
      _r.asMap(map['base_stats'], '$where.base_stats'),
      '$where.base_stats',
    );
    final firstClearReward = _parseReward(
      _r.asMap(map['first_clear_reward'], '$where.first_clear_reward'),
      '$where.first_clear_reward',
    );

    return BossSpireFloorConfig(
      floor: floor,
      name: name,
      bossId: bossId,
      bossName: bossName,
      spriteRef: spriteRef,
      spriteTint: spriteTint,
      recommendedLevel: recommendedLevel,
      affixDescription: affixDescription,
      baseStats: baseStats,
      firstClearReward: firstClearReward,
    );
  }

  String? _parseTint(Map<String, dynamic> map, String where) {
    final raw = map['sprite_tint'];
    if (raw == null) return null;
    final value = _r.string(map, where, 'sprite_tint').trim();
    if (!MonsterConfigParser.isValidHexTint(value)) {
      throw ConfigException(
        '$_file: $where."sprite_tint" harus berformat hex "#RRGGBB" atau "#RRGGBBAA" (ditemukan "$value").',
      );
    }
    return value;
  }

  BossBaseStats _parseStats(Map<String, dynamic> map, String where) {
    _r.ensureKnownKeys(map, where, _statsKeys);
    return BossBaseStats(
      hp: _r.integer(map, where, 'hp', min: 1),
      atk: _r.integer(map, where, 'atk', min: 0),
      def: _r.integer(map, where, 'def', min: 0),
      lifesteal: _r.number(
        map,
        where,
        'lifesteal',
        min: 0.0,
        max: 1.0,
        fallback: 0.0,
      ),
      spellVamp: _r.number(
        map,
        where,
        'spell_vamp',
        min: 0.0,
        max: 1.0,
        fallback: 0.0,
      ),
    );
  }

  BossQuestReward _parseReward(Map<String, dynamic> map, String where) {
    _r.ensureKnownKeys(map, where, _rewardKeys);
    final currency = <String, int>{};
    final rawCurrency = map['currency'];
    if (rawCurrency != null) {
      final currMap = _r.asMap(rawCurrency, '$where.currency');
      for (final entry in currMap.entries) {
        final cid = entry.key.trim();
        if (cid.isEmpty) {
          throw ConfigException(
            '$_file: $where.currency memiliki ID mata uang kosong.',
          );
        }
        final amount = _r.integer(currMap, '$where.currency.$cid', cid, min: 0);
        currency[cid] = amount;
      }
    }

    final exp = _r.integer(map, where, 'exp', min: 0, fallback: 0);
    final gold = _r.integer(map, where, 'gold', min: 0, fallback: 0);

    return BossQuestReward(
      currency: Map.unmodifiable(currency),
      exp: exp,
      gold: gold,
    );
  }
}
