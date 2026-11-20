import 'dart:convert';

import '../../core/errors/config_exception.dart';
import '../../domain/entities/cloud_config.dart';
import '../../domain/entities/combat_stats.dart';
import '../../domain/entities/currency_config.dart';
import '../../domain/entities/damage_config.dart';
import '../../domain/entities/difficulty_config.dart';
import '../../domain/entities/dungeon_reward.dart';
import '../../domain/entities/equipment_config.dart';
import '../../domain/entities/farming_config.dart';
import '../../domain/entities/hero_ascension.dart';
import '../../domain/entities/notification_config.dart';
import '../../domain/entities/progression_config.dart';
import '../../domain/entities/revive_config.dart';
import '../../domain/entities/time_config.dart';
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
    const defaults = EquipmentConfig();
    final section = _section(root, 'equipment', 'equipment');
    _rejectUnknownKeys(section, const {
      'roll_variance',
      'pct_caps',
    }, 'equipment');
    final rollVariance = _number(
      section,
      'equipment',
      'roll_variance',
      min: 0,
      max: 0.5,
      fallback: defaults.rollVariance,
    );
    var pctCaps = defaults.pctCaps;
    if (section.containsKey('pct_caps')) {
      const capsWhere = 'equipment.pct_caps';
      final capsMap = _section(section, 'pct_caps', capsWhere);
      _rejectUnknownKeys(capsMap, const {
        'hp_pct',
        'atk_pct',
        'def_pct',
      }, capsWhere);
      pctCaps = EquipmentPctCaps(
        hpPct: _number(
          capsMap,
          capsWhere,
          'hp_pct',
          min: 0,
          max: 5.0,
          fallback: defaults.pctCaps.hpPct,
        ),
        atkPct: _number(
          capsMap,
          capsWhere,
          'atk_pct',
          min: 0,
          max: 5.0,
          fallback: defaults.pctCaps.atkPct,
        ),
        defPct: _number(
          capsMap,
          capsWhere,
          'def_pct',
          min: 0,
          max: 5.0,
          fallback: defaults.pctCaps.defPct,
        ),
      );
    }
    return EquipmentConfig(rollVariance: rollVariance, pctCaps: pctCaps);
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

    final mechanicsRaw = section['mechanics'];
    final EliteBossMechanicsConfig mechanics;
    if (mechanicsRaw == null) {
      mechanics = defaults.mechanics;
    } else {
      final m = _section(section, 'mechanics', '$w.mechanics');
      mechanics = EliteBossMechanicsConfig(
        minAscensionRank: _int(
          m,
          '$w.mechanics',
          'min_ascension_rank',
          min: 0,
          fallback: defaults.mechanics.minAscensionRank,
        ),
        stoneskinDamageReduction: _number(
          m,
          '$w.mechanics',
          'stoneskin_damage_reduction',
          min: 0,
          max: 0.95,
          fallback: defaults.mechanics.stoneskinDamageReduction,
        ),
        stoneskinHpThreshold: _number(
          m,
          '$w.mechanics',
          'stoneskin_hp_threshold',
          min: 0,
          max: 1.0,
          fallback: defaults.mechanics.stoneskinHpThreshold,
        ),
        berserkHpThreshold: _number(
          m,
          '$w.mechanics',
          'berserk_hp_threshold',
          min: 0,
          max: 1.0,
          fallback: defaults.mechanics.berserkHpThreshold,
        ),
        berserkAtkMultiplier: _number(
          m,
          '$w.mechanics',
          'berserk_atk_multiplier',
          min: 1.0,
          fallback: defaults.mechanics.berserkAtkMultiplier,
        ),
        berserkSpeedMultiplier: _number(
          m,
          '$w.mechanics',
          'berserk_speed_multiplier',
          min: 1.0,
          fallback: defaults.mechanics.berserkSpeedMultiplier,
        ),
        eliteHeavyStrikeCooldownSeconds: _number(
          m,
          '$w.mechanics',
          'elite_heavy_strike_cooldown_seconds',
          min: 0.5,
          fallback: defaults.mechanics.eliteHeavyStrikeCooldownSeconds,
        ),
        eliteHeavyStrikeMultiplier: _number(
          m,
          '$w.mechanics',
          'elite_heavy_strike_multiplier',
          min: 1.0,
          fallback: defaults.mechanics.eliteHeavyStrikeMultiplier,
        ),
        bossAoeCooldownSeconds: _number(
          m,
          '$w.mechanics',
          'boss_aoe_cooldown_seconds',
          min: 0.5,
          fallback: defaults.mechanics.bossAoeCooldownSeconds,
        ),
        bossAoeRadius: _number(
          m,
          '$w.mechanics',
          'boss_aoe_radius',
          min: 0.5,
          fallback: defaults.mechanics.bossAoeRadius,
        ),
        bossAoeMultiplier: _number(
          m,
          '$w.mechanics',
          'boss_aoe_multiplier',
          min: 1.0,
          fallback: defaults.mechanics.bossAoeMultiplier,
        ),
        bossSummonHpThreshold: _number(
          m,
          '$w.mechanics',
          'boss_summon_hp_threshold',
          min: 0,
          max: 1.0,
          fallback: defaults.mechanics.bossSummonHpThreshold,
        ),
        bossSummonCount: _int(
          m,
          '$w.mechanics',
          'boss_summon_count',
          min: 1,
          fallback: defaults.mechanics.bossSummonCount,
        ),
        dailyElementalWardReduction: _number(
          m,
          '$w.mechanics',
          'daily_elemental_ward_reduction',
          min: 0,
          max: 0.95,
          fallback: defaults.mechanics.dailyElementalWardReduction,
        ),
        dailyElementalWardDurationSeconds: _number(
          m,
          '$w.mechanics',
          'daily_elemental_ward_duration_seconds',
          min: 0.5,
          fallback: defaults.mechanics.dailyElementalWardDurationSeconds,
        ),
        dailyElementalWardHpThreshold: _number(
          m,
          '$w.mechanics',
          'daily_elemental_ward_hp_threshold',
          min: 0,
          max: 1.0,
          fallback: defaults.mechanics.dailyElementalWardHpThreshold,
        ),
        dailyBlazingSurgeCooldownSeconds: _number(
          m,
          '$w.mechanics',
          'daily_blazing_surge_cooldown_seconds',
          min: 0.5,
          fallback: defaults.mechanics.dailyBlazingSurgeCooldownSeconds,
        ),
        dailyBlazingSurgeRadius: _number(
          m,
          '$w.mechanics',
          'daily_blazing_surge_radius',
          min: 0.5,
          fallback: defaults.mechanics.dailyBlazingSurgeRadius,
        ),
        dailyBlazingSurgeMultiplier: _number(
          m,
          '$w.mechanics',
          'daily_blazing_surge_multiplier',
          min: 1.0,
          fallback: defaults.mechanics.dailyBlazingSurgeMultiplier,
        ),
        dailyEnragedRushHpThreshold: _number(
          m,
          '$w.mechanics',
          'daily_enraged_rush_hp_threshold',
          min: 0,
          max: 1.0,
          fallback: defaults.mechanics.dailyEnragedRushHpThreshold,
        ),
        dailyEnragedRushAtkMultiplier: _number(
          m,
          '$w.mechanics',
          'daily_enraged_rush_atk_multiplier',
          min: 1.0,
          fallback: defaults.mechanics.dailyEnragedRushAtkMultiplier,
        ),
        dailyEnragedRushSpeedMultiplier: _number(
          m,
          '$w.mechanics',
          'daily_enraged_rush_speed_multiplier',
          min: 1.0,
          fallback: defaults.mechanics.dailyEnragedRushSpeedMultiplier,
        ),
        weeklyLifeSiphonCooldownSeconds: _number(
          m,
          '$w.mechanics',
          'weekly_life_siphon_cooldown_seconds',
          min: 0.5,
          fallback: defaults.mechanics.weeklyLifeSiphonCooldownSeconds,
        ),
        weeklyLifeSiphonMultiplier: _number(
          m,
          '$w.mechanics',
          'weekly_life_siphon_multiplier',
          min: 1.0,
          fallback: defaults.mechanics.weeklyLifeSiphonMultiplier,
        ),
        weeklyLifeSiphonHealRatio: _number(
          m,
          '$w.mechanics',
          'weekly_life_siphon_heal_ratio',
          min: 0,
          max: 1.0,
          fallback: defaults.mechanics.weeklyLifeSiphonHealRatio,
        ),
        weeklyCataclysmCooldownSeconds: _number(
          m,
          '$w.mechanics',
          'weekly_cataclysm_cooldown_seconds',
          min: 0.5,
          fallback: defaults.mechanics.weeklyCataclysmCooldownSeconds,
        ),
        weeklyCataclysmRadius: _number(
          m,
          '$w.mechanics',
          'weekly_cataclysm_radius',
          min: 0.5,
          fallback: defaults.mechanics.weeklyCataclysmRadius,
        ),
        weeklyCataclysmMultiplier: _number(
          m,
          '$w.mechanics',
          'weekly_cataclysm_multiplier',
          min: 1.0,
          fallback: defaults.mechanics.weeklyCataclysmMultiplier,
        ),
        weeklySummonHpThreshold: _number(
          m,
          '$w.mechanics',
          'weekly_summon_hp_threshold',
          min: 0,
          max: 1.0,
          fallback: defaults.mechanics.weeklySummonHpThreshold,
        ),
        weeklySummonCount: _int(
          m,
          '$w.mechanics',
          'weekly_summon_count',
          min: 1,
          fallback: defaults.mechanics.weeklySummonCount,
        ),
        weeklyFinalStandHpThreshold: _number(
          m,
          '$w.mechanics',
          'weekly_final_stand_hp_threshold',
          min: 0,
          max: 1.0,
          fallback: defaults.mechanics.weeklyFinalStandHpThreshold,
        ),
        weeklyFinalStandAtkMultiplier: _number(
          m,
          '$w.mechanics',
          'weekly_final_stand_atk_multiplier',
          min: 1.0,
          fallback: defaults.mechanics.weeklyFinalStandAtkMultiplier,
        ),
        weeklyFinalStandSpeedMultiplier: _number(
          m,
          '$w.mechanics',
          'weekly_final_stand_speed_multiplier',
          min: 1.0,
          fallback: defaults.mechanics.weeklyFinalStandSpeedMultiplier,
        ),
        weeklyFinalStandDamageReduction: _number(
          m,
          '$w.mechanics',
          'weekly_final_stand_damage_reduction',
          min: 0,
          max: 0.95,
          fallback: defaults.mechanics.weeklyFinalStandDamageReduction,
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
      eliteHpPerRank: _number(
        section,
        w,
        'elite_hp_per_rank',
        min: 0,
        fallback: defaults.eliteHpPerRank,
      ),
      eliteAtkPerRank: _number(
        section,
        w,
        'elite_atk_per_rank',
        min: 0,
        fallback: defaults.eliteAtkPerRank,
      ),
      bossHpPerRank: _number(
        section,
        w,
        'boss_hp_per_rank',
        min: 0,
        fallback: defaults.bossHpPerRank,
      ),
      bossAtkPerRank: _number(
        section,
        w,
        'boss_atk_per_rank',
        min: 0,
        fallback: defaults.bossAtkPerRank,
      ),
      rewardExponent: _number(
        section,
        w,
        'reward_exponent',
        min: 0,
        fallback: defaults.rewardExponent,
      ),
      drop: drop,
      mechanics: mechanics,
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

  static const Set<String> _timeKeys = {
    'reset_hour',
    'week_start',
    'epoch_monday',
    'forward_jump_record_threshold_hours',
  };

  static const Set<String> _claimedRewardsKeys = {'retention_days'};

  /// Section "time" bersifat opsional; jika tidak ada, memakai default.
  TimeConfig parseTime(String source) {
    final root = _decodeRoot(source);
    if (root['time'] == null) {
      return const TimeConfig();
    }
    const defaults = TimeConfig();
    const w = 'time';
    final section = _section(root, w, w);
    _rejectUnknownKeys(section, _timeKeys, w);

    final resetHour = section.containsKey('reset_hour')
        ? _intRange(section, w, 'reset_hour', min: 0, max: 23)
        : defaults.resetHour;

    final String weekStart;
    if (section.containsKey('week_start')) {
      final raw = section['week_start'];
      if (raw is! String) {
        throw ConfigException('$_file: $w."week_start" harus berupa teks.');
      }
      if (raw != 'monday') {
        throw ConfigException(
          '$_file: $w."week_start" tidak dikenal: "$raw". Nilai yang didukung: "monday".',
        );
      }
      weekStart = raw;
    } else {
      weekStart = defaults.weekStart;
    }

    final String epochMonday;
    if (section.containsKey('epoch_monday')) {
      final raw = section['epoch_monday'];
      if (raw is! String) {
        throw ConfigException('$_file: $w."epoch_monday" harus berupa teks.');
      }
      final parsed = TimeConfig.tryParseDateUtc(raw);
      if (parsed == null) {
        throw ConfigException(
          '$_file: $w."epoch_monday" tidak valid: "$raw" (harus YYYY-MM-DD).',
        );
      }
      if (parsed.weekday != DateTime.monday) {
        throw ConfigException(
          '$_file: $w."epoch_monday" ($raw) harus hari Senin.',
        );
      }
      epochMonday = raw.trim();
    } else {
      epochMonday = defaults.epochMonday;
    }

    final thresholdHours =
        section.containsKey('forward_jump_record_threshold_hours')
        ? _int(section, w, 'forward_jump_record_threshold_hours', min: 1)
        : defaults.forwardJumpRecordThresholdHours;

    return TimeConfig(
      resetHour: resetHour,
      weekStart: weekStart,
      epochMonday: epochMonday,
      forwardJumpRecordThresholdHours: thresholdHours,
    );
  }

  /// Section "claimed_rewards" bersifat opsional; jika tidak ada, memakai default.
  ClaimedRewardsConfig parseClaimedRewards(String source) {
    final root = _decodeRoot(source);
    if (root['claimed_rewards'] == null) {
      return const ClaimedRewardsConfig();
    }
    const defaults = ClaimedRewardsConfig();
    const w = 'claimed_rewards';
    final section = _section(root, w, w);
    _rejectUnknownKeys(section, _claimedRewardsKeys, w);

    final retentionDays = section.containsKey('retention_days')
        ? _int(section, w, 'retention_days', min: 1)
        : defaults.retentionDays;

    return ClaimedRewardsConfig(retentionDays: retentionDays);
  }

  /// Section "currencies" bersifat opsional; jika tidak ada, memakai default.
  Map<String, CurrencyDefinition> parseCurrencies(String source) {
    final root = _decodeRoot(source);
    if (root['currencies'] == null) {
      return CurrencyDefinition.defaults;
    }
    const w = 'currencies';
    final section = _section(root, w, w);
    if (section.isEmpty) {
      throw const ConfigException('$_file: "$w" tidak boleh kosong.');
    }
    const allowedKeys = {'name', 'max_amount'};
    final result = <String, CurrencyDefinition>{};
    for (final entry in section.entries) {
      final id = entry.key.trim();
      if (id.isEmpty) {
        throw const ConfigException(
          '$_file: id mata uang pada "$w" tidak boleh kosong.',
        );
      }
      final raw = entry.value;
      if (raw is! Map<String, dynamic>) {
        throw ConfigException('$_file: "$w.$id" harus berupa object.');
      }
      _rejectUnknownKeys(raw, allowedKeys, '$w.$id');

      final rawName = raw['name'];
      if (rawName is! String || rawName.trim().isEmpty) {
        throw ConfigException(
          '$_file: $w.$id."name" harus berupa teks non-kosong.',
        );
      }
      final maxAmount = _int(raw, '$w.$id', 'max_amount', min: 1);
      result[id] = CurrencyDefinition(
        id: id,
        name: rawName.trim(),
        maxAmount: maxAmount,
      );
    }
    return Map.unmodifiable(result);
  }

  NotificationConfig parseNotifications(String source) {
    final root = _decodeRoot(source);
    if (root['notifications'] == null) {
      return const NotificationConfig();
    }
    const defaults = NotificationConfig();
    const w = 'notifications';
    final section = _section(root, w, w);
    const allowedKeys = {
      'daily_reminder_hour',
      'weekly_reminder_weekday',
      'weekly_reminder_hour',
      'quiet_hours',
      'max_per_day',
    };
    _rejectUnknownKeys(section, allowedKeys, w);

    final dailyHour = section.containsKey('daily_reminder_hour')
        ? _intRange(section, w, 'daily_reminder_hour', min: 0, max: 23)
        : defaults.dailyReminderHour;
    final weeklyHour = section.containsKey('weekly_reminder_hour')
        ? _intRange(section, w, 'weekly_reminder_hour', min: 0, max: 23)
        : defaults.weeklyReminderHour;

    var weeklyWeekday = defaults.weeklyReminderWeekday;
    if (section.containsKey('weekly_reminder_weekday')) {
      final rawWeekday = section['weekly_reminder_weekday'];
      if (rawWeekday is! String) {
        throw const ConfigException(
          '$_file: "$w.weekly_reminder_weekday" harus string.',
        );
      }
      final parsed = NotificationConfig.parseWeekday(rawWeekday);
      if (parsed == null) {
        throw ConfigException(
          '$_file: "$w.weekly_reminder_weekday" tidak dikenal ("$rawWeekday").',
        );
      }
      weeklyWeekday = parsed;
    }

    var quietHours = defaults.quietHours;
    if (section.containsKey('quiet_hours')) {
      final rawQh = _section(section, 'quiet_hours', '$w.quiet_hours');
      _rejectUnknownKeys(rawQh, const {'start', 'end'}, '$w.quiet_hours');
      final start = rawQh.containsKey('start')
          ? _intRange(rawQh, '$w.quiet_hours', 'start', min: 0, max: 23)
          : defaults.quietHours.startHour;
      final end = rawQh.containsKey('end')
          ? _intRange(rawQh, '$w.quiet_hours', 'end', min: 0, max: 23)
          : defaults.quietHours.endHour;
      quietHours = QuietHoursConfig(startHour: start, endHour: end);
    }

    final maxPerDay = section.containsKey('max_per_day')
        ? _int(section, w, 'max_per_day', min: 1)
        : defaults.maxPerDay;

    return NotificationConfig(
      dailyReminderHour: dailyHour,
      weeklyReminderWeekday: weeklyWeekday,
      weeklyReminderHour: weeklyHour,
      quietHours: quietHours,
      maxPerDay: maxPerDay,
    );
  }

  CloudConfig parseCloud(String source) {
    final root = _decodeRoot(source);
    if (root['cloud'] == null) {
      return const CloudConfig();
    }
    const defaults = CloudConfig();
    const w = 'cloud';
    final section = _section(root, w, w);
    const allowedKeys = {
      'auto_sync_min_interval_minutes',
      'reject_backoff_minutes',
      'server_time_tolerance_minutes',
    };
    _rejectUnknownKeys(section, allowedKeys, w);

    final autoSyncMinIntervalMinutes =
        section.containsKey('auto_sync_min_interval_minutes')
        ? _int(section, w, 'auto_sync_min_interval_minutes', min: 0)
        : defaults.autoSyncMinIntervalMinutes;
    final rejectBackoffMinutes = section.containsKey('reject_backoff_minutes')
        ? _int(section, w, 'reject_backoff_minutes', min: 1)
        : defaults.rejectBackoffMinutes;
    final serverTimeToleranceMinutes =
        section.containsKey('server_time_tolerance_minutes')
        ? _int(section, w, 'server_time_tolerance_minutes', min: 0)
        : defaults.serverTimeToleranceMinutes;

    return CloudConfig(
      autoSyncMinIntervalMinutes: autoSyncMinIntervalMinutes,
      rejectBackoffMinutes: rejectBackoffMinutes,
      serverTimeToleranceMinutes: serverTimeToleranceMinutes,
    );
  }

  HeroAscensionConfig parseHeroAscension(String source) {
    final root = _decodeRoot(source);
    final raw = root['hero_ascension'];
    if (raw == null) {
      return const HeroAscensionConfig();
    }
    if (raw is! Map<String, dynamic>) {
      throw const ConfigException(
        '$_file: "hero_ascension" harus berupa object.',
      );
    }
    const allowedRootKeys = {'max_phase', 'phases'};
    _rejectUnknownKeys(raw, allowedRootKeys, 'hero_ascension');

    final maxPhase = raw.containsKey('max_phase')
        ? _int(raw, 'hero_ascension', 'max_phase', min: 1)
        : 6;

    final phasesRaw = raw['phases'];
    if (phasesRaw is! List) {
      throw const ConfigException(
        '$_file: hero_ascension."phases" harus berupa array.',
      );
    }

    final phases = <HeroAscensionPhaseDefinition>[];
    for (var i = 0; i < phasesRaw.length; i++) {
      final p = phasesRaw[i];
      final where = 'hero_ascension.phases[$i]';
      if (p is! Map<String, dynamic>) {
        throw ConfigException('$_file: $where harus berupa object.');
      }
      const allowedPhaseKeys = {
        'phase',
        'level_cap',
        'required_player_level',
        'costs',
        'stat_boosts',
        'has_golden_aura',
      };
      _rejectUnknownKeys(p, allowedPhaseKeys, where);

      final phaseNum = _int(p, where, 'phase', min: 0);
      final levelCap = _int(p, where, 'level_cap', min: 1);
      final requiredPlayerLevel = p.containsKey('required_player_level')
          ? _int(p, where, 'required_player_level', min: 1)
          : 1;
      final hasGoldenAura = p['has_golden_aura'] as bool? ?? false;

      // costs
      final costsRaw = p['costs'];
      final int costGold;
      final Map<String, int> costItems = {};
      final Map<String, int> costCurrencies = {};

      if (costsRaw != null) {
        if (costsRaw is! Map<String, dynamic>) {
          throw ConfigException('$_file: $where."costs" harus berupa object.');
        }
        _rejectUnknownKeys(costsRaw, {
          'gold',
          'items',
          'currencies',
        }, '$where.costs');
        costGold = costsRaw.containsKey('gold')
            ? _int(costsRaw, '$where.costs', 'gold', min: 0)
            : 0;

        final itemsMap = costsRaw['items'];
        if (itemsMap != null) {
          if (itemsMap is! Map) {
            throw ConfigException(
              '$_file: $where.costs."items" harus berupa object.',
            );
          }
          for (final entry in itemsMap.entries) {
            final val = entry.value;
            if (val is! num || val < 0) {
              throw ConfigException(
                '$_file: $where.costs.items."${entry.key}" harus >= 0.',
              );
            }
            costItems[entry.key.toString()] = val.toInt();
          }
        }

        final currMap = costsRaw['currencies'];
        if (currMap != null) {
          if (currMap is! Map) {
            throw ConfigException(
              '$_file: $where.costs."currencies" harus berupa object.',
            );
          }
          for (final entry in currMap.entries) {
            final val = entry.value;
            if (val is! num || val < 0) {
              throw ConfigException(
                '$_file: $where.costs.currencies."${entry.key}" harus >= 0.',
              );
            }
            costCurrencies[entry.key.toString()] = val.toInt();
          }
        }
      } else {
        costGold = 0;
      }

      // stat_boosts
      final statsRaw = p['stat_boosts'];
      final int boostHp;
      final int boostAtk;
      final int boostDef;
      final double boostCritRate;
      final double boostAttackSpeed;
      final double boostCritDamage;
      final double boostSkillHaste;

      if (statsRaw != null) {
        if (statsRaw is! Map<String, dynamic>) {
          throw ConfigException(
            '$_file: $where."stat_boosts" harus berupa object.',
          );
        }
        const allowedStatKeys = {
          'hp',
          'atk',
          'def',
          'crit_rate',
          'attack_speed',
          'crit_damage',
          'skill_haste',
        };
        _rejectUnknownKeys(statsRaw, allowedStatKeys, '$where.stat_boosts');
        boostHp = statsRaw.containsKey('hp')
            ? _int(statsRaw, '$where.stat_boosts', 'hp', min: 0)
            : 0;
        boostAtk = statsRaw.containsKey('atk')
            ? _int(statsRaw, '$where.stat_boosts', 'atk', min: 0)
            : 0;
        boostDef = statsRaw.containsKey('def')
            ? _int(statsRaw, '$where.stat_boosts', 'def', min: 0)
            : 0;
        boostCritRate = statsRaw.containsKey('crit_rate')
            ? _number(statsRaw, '$where.stat_boosts', 'crit_rate', min: 0)
            : 0.0;
        boostAttackSpeed = statsRaw.containsKey('attack_speed')
            ? _number(statsRaw, '$where.stat_boosts', 'attack_speed', min: 0)
            : 0.0;
        boostCritDamage = statsRaw.containsKey('crit_damage')
            ? _number(statsRaw, '$where.stat_boosts', 'crit_damage', min: 0)
            : 0.0;
        boostSkillHaste = statsRaw.containsKey('skill_haste')
            ? _number(statsRaw, '$where.stat_boosts', 'skill_haste', min: 0)
            : 0.0;
      } else {
        boostHp = 0;
        boostAtk = 0;
        boostDef = 0;
        boostCritRate = 0.0;
        boostAttackSpeed = 0.0;
        boostCritDamage = 0.0;
        boostSkillHaste = 0.0;
      }

      phases.add(
        HeroAscensionPhaseDefinition(
          phase: phaseNum,
          levelCap: levelCap,
          requiredPlayerLevel: requiredPlayerLevel,
          cost: HeroAscensionCost(
            gold: costGold,
            items: Map.unmodifiable(costItems),
            currencies: Map.unmodifiable(costCurrencies),
          ),
          statBoost: HeroAscensionStatBoost(
            hp: boostHp,
            atk: boostAtk,
            def: boostDef,
            critRate: boostCritRate,
            attackSpeed: boostAttackSpeed,
            critDamage: boostCritDamage,
            skillHaste: boostSkillHaste,
          ),
          hasGoldenAura: hasGoldenAura,
        ),
      );
    }

    return HeroAscensionConfig(
      maxPhase: maxPhase,
      phases: List.unmodifiable(phases),
    );
  }

  void _rejectUnknownKeys(
    Map<String, dynamic> map,
    Set<String> allowed,
    String where,
  ) {
    for (final key in map.keys) {
      if (!allowed.contains(key)) {
        throw ConfigException(
          '$_file: key tidak dikenal "$key" pada "$where".',
        );
      }
    }
  }

  int _intRange(
    Map<String, dynamic> map,
    String where,
    String key, {
    required int min,
    required int max,
  }) {
    final value = _int(map, where, key, min: min);
    if (value > max) {
      throw ConfigException(
        '$_file: $where."$key" harus <= $max (nilai: $value).',
      );
    }
    return value;
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
    int? max,
    int? fallback,
  }) {
    final value = map[key];
    if (value == null) {
      if (fallback != null) return fallback;
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
    if (max != null && value > max) {
      throw ConfigException(
        '$_file: $where."$key" harus <= $max (nilai: $value).',
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
