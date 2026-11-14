import 'dart:convert';

import '../../core/errors/config_exception.dart';
import '../../domain/entities/combat_stats.dart';
import '../../domain/entities/damage_config.dart';
import '../../domain/entities/difficulty_config.dart';
import '../../domain/entities/dungeon_reward.dart';
import '../../domain/entities/equipment_config.dart';
import '../../domain/entities/farming_config.dart';
import '../../domain/entities/progression_config.dart';
import '../../domain/entities/revive_config.dart';
import '../../domain/services/damage_calculator.dart';

/// Membaca dan memvalidasi game_config.json.
class GameConfigParser {
  const GameConfigParser();

  static const String _file = 'game_config.json';

  /// Section "damage" bersifat opsional; jika tidak ada, memakai default ratio.
  DamageConfig parseDamage(String source) {
    final root = _decodeRoot(source);
    final raw = root['damage'];
    if (raw == null) {
      return const DamageConfig(formula: DamageFormula.ratio);
    }
    if (raw is! Map<String, dynamic>) {
      throw const ConfigException('$_file: "damage" harus berupa object.');
    }
    final formulaRaw = raw['formula'];
    if (formulaRaw == null) {
      return const DamageConfig(formula: DamageFormula.ratio);
    }
    if (formulaRaw is! String) {
      throw const ConfigException(
        '$_file: damage."formula" harus berupa teks.',
      );
    }
    return switch (formulaRaw) {
      'ratio' => const DamageConfig(formula: DamageFormula.ratio),
      'subtractive' => const DamageConfig(formula: DamageFormula.subtractive),
      _ => throw ConfigException(
        '$_file: damage."formula" tidak dikenal: "$formulaRaw". Nilai yang didukung: "ratio", "subtractive".',
      ),
    };
  }

  ReviveConfig parseRevive(String source) {
    final revive = _section(_decodeRoot(source), 'revive', 'revive');
    const defaults = ReviveConfig();
    return ReviveConfig(
      delaySeconds: _number(
        revive,
        'revive',
        'delay_seconds',
        min: 0,
        fallback: defaults.delaySeconds,
      ),
      hpPercent: _number(
        revive,
        'revive',
        'hp_percent',
        min: 0,
        minExclusive: true,
        max: 1,
        fallback: defaults.hpPercent,
      ),
      invulnerabilitySeconds: _number(
        revive,
        'revive',
        'invulnerability_seconds',
        min: 0,
        fallback: defaults.invulnerabilitySeconds,
      ),
      cooldownSeconds: _number(
        revive,
        'revive',
        'cooldown_seconds',
        min: 0,
        fallback: defaults.cooldownSeconds,
      ),
    );
  }

  ProgressionConfig parseProgression(String source) {
    const w = 'progression';
    final root = _section(_decodeRoot(source), w, w);
    final exp = _section(root, 'exp', '$w.exp');
    final base = _section(root, 'base_stats', '$w.base_stats');
    final perLevel = _section(root, 'per_level', '$w.per_level');

    final rawMaxLevel = root['max_level'];
    final int? maxLevel;
    if (rawMaxLevel == null) {
      maxLevel = null;
    } else if (rawMaxLevel is int) {
      if (rawMaxLevel < 1) {
        throw ConfigException(
          '$_file: $w."max_level" harus >= 1 (nilai: $rawMaxLevel).',
        );
      }
      maxLevel = rawMaxLevel;
    } else {
      throw ConfigException(
        '$_file: $w."max_level" harus berupa bilangan bulat atau null.',
      );
    }

    final typeStr = exp['type'] as String?;
    final ExpCurveConfig expCurve;
    if (typeStr == 'polynomial' ||
        (typeStr == null && exp.containsKey('exponent'))) {
      final baseVal = _number(
        exp,
        '$w.exp',
        'base',
        min: 0,
        minExclusive: true,
      );
      final expVal = _number(
        exp,
        '$w.exp',
        'exponent',
        min: 0,
        minExclusive: true,
        fallback: 1.8,
      );
      expCurve = ExpCurveConfig.polynomial(base: baseVal, exponent: expVal);
    } else if (typeStr == 'exponential' ||
        (typeStr == null && exp.containsKey('growth'))) {
      final baseVal = _number(
        exp,
        '$w.exp',
        'base',
        min: 0,
        minExclusive: true,
      );
      final growthVal = _number(exp, '$w.exp', 'growth', min: 1);
      expCurve = ExpCurveConfig.exponential(base: baseVal, growth: growthVal);
    } else {
      throw ConfigException(
        '$_file: $w.exp."type" harus "polynomial" atau "exponential" (nilai: $typeStr).',
      );
    }

    return ProgressionConfig(
      maxLevel: maxLevel,
      expCurve: expCurve,
      baseStats: CombatStats(
        maxHp: _int(base, '$w.base_stats', 'hp', min: 1),
        atk: _int(base, '$w.base_stats', 'atk', min: 0),
        def: _int(base, '$w.base_stats', 'def', min: 0),
        attackSpeed: _number(
          base,
          '$w.base_stats',
          'attack_speed',
          min: 0,
          minExclusive: true,
        ),
        critRate: _number(base, '$w.base_stats', 'crit_rate', min: 0, max: 1),
        critDamage: _number(base, '$w.base_stats', 'crit_damage', min: 1),
        moveSpeed: _number(
          base,
          '$w.base_stats',
          'move_speed',
          min: 0,
          minExclusive: true,
        ),
        attackRange: _number(
          base,
          '$w.base_stats',
          'attack_range',
          min: 0,
          minExclusive: true,
        ),
        skillHaste: _number(
          base,
          '$w.base_stats',
          'skill_haste',
          min: 0,
          max: 0.75,
          fallback: 0.0,
        ),
      ),
      perLevel: LevelGrowth(
        hp: _number(perLevel, '$w.per_level', 'hp', min: 0),
        atk: _number(perLevel, '$w.per_level', 'atk', min: 0),
        def: _number(perLevel, '$w.per_level', 'def', min: 0),
      ),
    );
  }

  /// Section "equipment" bersifat opsional; jika tidak ada, memakai default.
  EquipmentConfig parseEquipment(String source) {
    final root = _decodeRoot(source);
    if (root['equipment'] == null) return const EquipmentConfig();
    final section = _section(root, 'equipment', 'equipment');
    return EquipmentConfig(
      rollVariance: _number(
        section,
        'equipment',
        'roll_variance',
        min: 0,
        max: 0.5,
        fallback: const EquipmentConfig().rollVariance,
      ),
    );
  }

  /// Section "dungeon_completion" bersifat opsional; jika tidak ada, memakai default.
  DungeonCompletionReward parseDungeonCompletion(String source) {
    final root = _decodeRoot(source);
    if (root['dungeon_completion'] == null) {
      return const DungeonCompletionReward();
    }
    final section = _section(root, 'dungeon_completion', 'dungeon_completion');
    final tableRaw = section['loot_table_id'];
    String? lootTableId;
    if (tableRaw != null) {
      if (tableRaw is! String || tableRaw.isEmpty) {
        throw const ConfigException(
          '$_file: dungeon_completion."loot_table_id" harus berupa teks tidak kosong.',
        );
      }
      lootTableId = tableRaw;
    }
    return DungeonCompletionReward(
      expReward: section['exp_reward'] == null
          ? 0
          : _int(section, 'dungeon_completion', 'exp_reward', min: 0),
      goldReward: section['gold_reward'] == null
          ? 0
          : _int(section, 'dungeon_completion', 'gold_reward', min: 0),
      lootTableId: lootTableId,
    );
  }

  /// Section "difficulty" bersifat opsional; jika tidak ada, memakai default.
  DifficultyConfig parseDifficulty(String source) {
    final root = _decodeRoot(source);
    if (root['difficulty'] == null) {
      return const DifficultyConfig();
    }
    const defaults = DifficultyConfig();
    const w = 'difficulty';
    final section = _section(root, w, w);

    final exponents = section['stat_exponents'] == null
        ? defaults.statExponents
        : _parseStatExponents(
            section,
            w,
            'stat_exponents',
            defaults.statExponents,
          );
    final cycleExponents = section['cycle_stat_exponents'] == null
        ? null
        : _parseStatExponents(
            section,
            w,
            'cycle_stat_exponents',
            defaults.statExponents,
          );

    final dropRaw = section['drop'];
    final DropScalingConfig drop;
    if (dropRaw == null) {
      drop = defaults.drop;
    } else {
      final dropMap = _section(section, 'drop', '$w.drop');
      drop = DropScalingConfig(
        rareChancePerRank: _number(
          dropMap,
          '$w.drop',
          'rare_chance_per_rank',
          min: 0,
          fallback: defaults.drop.rareChancePerRank,
        ),
        maxChanceMultiplier: _number(
          dropMap,
          '$w.drop',
          'max_chance_multiplier',
          min: 1.0,
          fallback: defaults.drop.maxChanceMultiplier,
        ),
        rollBonusPerRank: _number(
          dropMap,
          '$w.drop',
          'roll_bonus_per_rank',
          min: 0,
          fallback: defaults.drop.rollBonusPerRank,
        ),
        maxRollBonus: _number(
          dropMap,
          '$w.drop',
          'max_roll_bonus',
          min: 0,
          fallback: defaults.drop.maxRollBonus,
        ),
      );
    }

    return DifficultyConfig(
      cyclePerRank: _number(
        section,
        w,
        'cycle_per_rank',
        min: 0,
        fallback: defaults.cyclePerRank,
      ),
      ascensionMultiplier: _number(
        section,
        w,
        'ascension_multiplier',
        min: 1.0,
        fallback: defaults.ascensionMultiplier,
      ),
      statExponents: exponents,
      cycleStatExponents: cycleExponents,
      cycleLevelStep: section['cycle_level_step'] == null
          ? null
          : _int(section, w, 'cycle_level_step', min: 0),
      rewardExponent: _number(
        section,
        w,
        'reward_exponent',
        min: 0,
        fallback: defaults.rewardExponent,
      ),
      drop: drop,
      maxMultiplier: _number(
        section,
        w,
        'max_multiplier',
        min: 1.0,
        fallback: defaults.maxMultiplier,
      ),
    );
  }

  StatExponentsConfig _parseStatExponents(
    Map<String, dynamic> section,
    String parentWhere,
    String key,
    StatExponentsConfig fallback,
  ) {
    final where = '$parentWhere.$key';
    final expMap = _section(section, key, where);
    return StatExponentsConfig(
      hp: _number(expMap, where, 'hp', min: 0, fallback: fallback.hp),
      atk: _number(expMap, where, 'atk', min: 0, fallback: fallback.atk),
      def: _number(expMap, where, 'def', min: 0, fallback: fallback.def),
    );
  }

  /// Section "farming" bersifat opsional; jika tidak ada, memakai default.
  FarmingConfig parseFarming(String source) {
    final root = _decodeRoot(source);
    if (root['farming'] == null) {
      return const FarmingConfig();
    }
    const defaults = FarmingConfig();
    const w = 'farming';
    final section = _section(root, w, w);
    final rawCount = section['death_loop_suggest_after'];
    return FarmingConfig(
      deathLoopSuggestAfter: rawCount == null
          ? defaults.deathLoopSuggestAfter
          : _int(section, w, 'death_loop_suggest_after', min: 1),
    );
  }

  Map<String, dynamic> _decodeRoot(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw ConfigException('$_file bukan JSON valid: ${e.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ConfigException('$_file: root harus berupa object.');
    }
    return decoded;
  }

  Map<String, dynamic> _section(
    Map<String, dynamic> map,
    String key,
    String where,
  ) {
    final value = map[key];
    if (value is Map<String, dynamic>) return value;
    throw ConfigException('$_file: "$where" harus berupa object.');
  }

  int _int(
    Map<String, dynamic> map,
    String where,
    String key, {
    required int min,
  }) {
    final value = map[key];
    if (value == null) {
      throw ConfigException('$_file: $where."$key" wajib diisi.');
    }
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

  /// Angka dengan batas. Tanpa [fallback], field wajib diisi.
  double _number(
    Map<String, dynamic> map,
    String where,
    String key, {
    required double min,
    bool minExclusive = false,
    double? max,
    double? fallback,
  }) {
    final value = map[key];
    if (value == null) {
      if (fallback != null) return fallback;
      throw ConfigException('$_file: $where."$key" wajib diisi.');
    }
    if (value is! num) {
      throw ConfigException('$_file: $where."$key" harus berupa angka.');
    }
    final number = value.toDouble();
    if (minExclusive ? number <= min : number < min) {
      final op = minExclusive ? '>' : '>=';
      throw ConfigException(
        '$_file: $where."$key" harus $op $min (nilai: $number).',
      );
    }
    if (max != null && number > max) {
      throw ConfigException(
        '$_file: $where."$key" harus <= $max (nilai: $number).',
      );
    }
    return number;
  }
}
