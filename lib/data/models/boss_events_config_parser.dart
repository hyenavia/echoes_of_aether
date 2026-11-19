import '../../core/errors/config_exception.dart';
import '../../domain/entities/boss_event.dart';
import '../../domain/services/period_service.dart';
import 'json_reader.dart';
import 'monster_config_parser.dart';

/// Membaca dan memvalidasi `assets/data/boss_events.json`.
class BossEventsConfigParser {
  const BossEventsConfigParser();

  static const String _file = 'boss_events.json';
  static const JsonReader _r = JsonReader(_file);

  static const Set<String> _rootKeys = {'daily', 'weekly', 'arena_map_ref'};
  static const Set<String> _tierKeys = {
    'quest_id',
    'power_factor',
    'reward',
    'pool',
  };
  static const Set<String> _rewardKeys = {'currency', 'exp', 'gold'};
  static const Set<String> _bossKeys = {
    'id',
    'name',
    'sprite_ref',
    'sprite_tint',
    'base_stats',
  };
  static const Set<String> _statsKeys = {
    'hp',
    'atk',
    'def',
    'lifesteal',
    'spell_vamp',
  };

  BossEventsConfig parse(String source) {
    final root = _r.decodeRoot(source);
    _r.ensureKnownKeys(root, 'root', _rootKeys);

    final daily = _parseTier(
      _r.asMap(root['daily'], 'daily'),
      'daily',
      Period.daily,
    );
    final weekly = _parseTier(
      _r.asMap(root['weekly'], 'weekly'),
      'weekly',
      Period.weekly,
    );
    final arenaMapRef = _r.string(root, 'root', 'arena_map_ref');

    return BossEventsConfig(
      daily: daily,
      weekly: weekly,
      arenaMapRef: arenaMapRef,
    );
  }

  BossTierConfig _parseTier(
    Map<String, dynamic> map,
    String where,
    Period period,
  ) {
    _r.ensureKnownKeys(map, where, _tierKeys);
    final questId = _r.string(map, where, 'quest_id');
    final powerFactor = _r.number(map, where, 'power_factor', min: 0.0001);
    final reward = _parseReward(
      _r.asMap(map['reward'], '$where.reward'),
      '$where.reward',
    );
    final rawPool = _r.list(map, where, 'pool');
    if (rawPool.isEmpty) {
      throw ConfigException(
        '$_file: $where."pool" harus memiliki minimal 1 boss.',
      );
    }
    final pool = <BossEvent>[];
    for (var i = 0; i < rawPool.length; i++) {
      pool.add(
        _parseBoss(_r.asMap(rawPool[i], '$where.pool[$i]'), '$where.pool[$i]'),
      );
    }
    return BossTierConfig(
      period: period,
      questId: questId,
      powerFactor: powerFactor,
      reward: reward,
      pool: List.unmodifiable(pool),
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
            '$_file: $where."currency" memiliki key kosong.',
          );
        }
        final val = entry.value;
        if (val is! int || val < 0) {
          throw ConfigException(
            '$_file: $where.currency."$cid" harus bilangan bulat >= 0.',
          );
        }
        currency[cid] = val;
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

  BossEvent _parseBoss(Map<String, dynamic> map, String where) {
    _r.ensureKnownKeys(map, where, _bossKeys);
    final id = _r.string(map, where, 'id');
    final name = _r.string(map, where, 'name');
    final spriteRef = _r.string(map, where, 'sprite_ref');
    String? spriteTint;
    if (map.containsKey('sprite_tint') && map['sprite_tint'] != null) {
      final rawTint = map['sprite_tint'];
      if (rawTint is! String) {
        throw ConfigException('$_file: $where."sprite_tint" harus teks.');
      }
      spriteTint = rawTint.trim();
      if (!MonsterConfigParser.isValidHexTint(spriteTint)) {
        throw ConfigException(
          '$_file: $where."sprite_tint" harus format hex (#RRGGBB atau #AARRGGBB).',
        );
      }
    }
    final statsMap = _r.asMap(map['base_stats'], '$where.base_stats');
    _r.ensureKnownKeys(statsMap, '$where.base_stats', _statsKeys);
    final hp = _r.integer(statsMap, '$where.base_stats', 'hp', min: 1);
    final atk = _r.integer(statsMap, '$where.base_stats', 'atk', min: 0);
    final def = _r.integer(statsMap, '$where.base_stats', 'def', min: 0);
    final lifesteal = _r.number(
      statsMap,
      '$where.base_stats',
      'lifesteal',
      min: 0,
      max: 1.0,
      fallback: 0.0,
    );
    final spellVamp = _r.number(
      statsMap,
      '$where.base_stats',
      'spell_vamp',
      min: 0,
      max: 1.0,
      fallback: 0.0,
    );

    return BossEvent(
      id: id,
      name: name,
      spriteRef: spriteRef,
      spriteTint: spriteTint,
      baseStats: BossBaseStats(
        hp: hp,
        atk: atk,
        def: def,
        lifesteal: lifesteal,
        spellVamp: spellVamp,
      ),
    );
  }
}
