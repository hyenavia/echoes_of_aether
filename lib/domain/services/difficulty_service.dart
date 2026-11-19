import 'dart:math' as math;

import '../entities/boss_event.dart';
import '../entities/combat_stats.dart';
import '../entities/difficulty_config.dart';
import '../entities/dungeon_definition.dart';
import 'period_service.dart';

/// Profil pengali kesulitan efektif untuk satu dungeon run.
class DifficultyProfile {
  const DifficultyProfile({
    this.multiplier = 1.0,
    this.hpMultiplier = 1.0,
    this.atkMultiplier = 1.0,
    this.defMultiplier = 1.0,
    this.rewardMultiplier = 1.0,
    this.rareDropChanceMultiplier = 1.0,
    this.equipmentRollBonus = 0.0,
    this.eliteHpMultiplier = 1.0,
    this.eliteAtkMultiplier = 1.0,
    this.bossHpMultiplier = 1.0,
    this.bossAtkMultiplier = 1.0,
    this.cycleRank = 0,
  });

  static const DifficultyProfile identity = DifficultyProfile();

  /// Pengali kesulitan efektif `M = dungeon.difficultyScale * (1 + cyclePerRank * rank)`.
  final double multiplier;
  final double hpMultiplier;
  final double atkMultiplier;
  final double defMultiplier;
  final double rewardMultiplier;
  final double rareDropChanceMultiplier;
  final double equipmentRollBonus;
  final double eliteHpMultiplier;
  final double eliteAtkMultiplier;
  final double bossHpMultiplier;
  final double bossAtkMultiplier;
  final int cycleRank;

  bool get isIdentity =>
      multiplier == 1.0 &&
      hpMultiplier == 1.0 &&
      atkMultiplier == 1.0 &&
      defMultiplier == 1.0 &&
      rewardMultiplier == 1.0 &&
      rareDropChanceMultiplier == 1.0 &&
      equipmentRollBonus == 0.0 &&
      eliteHpMultiplier == 1.0 &&
      eliteAtkMultiplier == 1.0 &&
      bossHpMultiplier == 1.0 &&
      bossAtkMultiplier == 1.0 &&
      cycleRank == 0;
}

/// Layanan domain deterministik untuk menghitung pengali kesulitan stat monster,
/// reward EXP/gold, serta bonus drop & roll equipment.
class DifficultyService {
  const DifficultyService([this.config = const DifficultyConfig()]);

  /// Batas aman bilangan bulat agar tidak terjadi overflow 64-bit / hilangnya
  /// presisi double ketika dikalikan pada rank tinggi.
  static const int kMaxScaledValue = 1000000000000000; // 10^15

  final DifficultyConfig config;

  /// Menghitung [DifficultyProfile] untuk [dungeon] pada [cycleRank].
  DifficultyProfile profileFor(DungeonDefinition dungeon, int cycleRank) {
    final safeRank = cycleRank < 0 ? 0 : cycleRank;
    final safeMax = _resolvedMaxMultiplier();

    final baseScale =
        (!dungeon.difficultyScale.isFinite || dungeon.difficultyScale <= 0)
        ? 1.0
        : dungeon.difficultyScale;
    final cyclePerRank =
        (!config.cyclePerRank.isFinite || config.cyclePerRank < 0)
        ? 0.0
        : config.cyclePerRank;

    final rawCycleFactor = 1.0 + cyclePerRank * safeRank;
    final cycleFactor = !rawCycleFactor.isFinite
        ? safeMax
        : math.min(rawCycleFactor, safeMax);
    final rawMultiplier = baseScale * rawCycleFactor;
    final multiplier = !rawMultiplier.isFinite
        ? safeMax
        : math.min(rawMultiplier, safeMax);

    double computeStatMultiplier(double baseExp, double? cycleExp) {
      if (cycleExp == null) {
        return _powClamped(multiplier, baseExp, safeMax);
      }
      final safeBase = !baseScale.isFinite
          ? safeMax
          : math.min(baseScale, safeMax);
      final basePart = _powClamped(safeBase, baseExp, safeMax);
      final cyclePart = _powClamped(cycleFactor, cycleExp, safeMax);
      final product = basePart * cyclePart;
      if (!product.isFinite || product > safeMax) return safeMax;
      return product;
    }

    final cycleExponents = config.cycleStatExponents;
    final hpMultiplier = computeStatMultiplier(
      config.statExponents.hp,
      cycleExponents?.hp,
    );
    final atkMultiplier = computeStatMultiplier(
      config.statExponents.atk,
      cycleExponents?.atk,
    );
    final defMultiplier = computeStatMultiplier(
      config.statExponents.def,
      cycleExponents?.def,
    );
    final rewardMultiplier = _powClamped(
      multiplier,
      config.rewardExponent,
      safeMax,
    );

    final rareChancePerRank =
        (!config.drop.rareChancePerRank.isFinite ||
            config.drop.rareChancePerRank < 0)
        ? 0.0
        : config.drop.rareChancePerRank;
    final maxChanceMultiplier =
        (!config.drop.maxChanceMultiplier.isFinite ||
            config.drop.maxChanceMultiplier < 1.0)
        ? 1.0
        : config.drop.maxChanceMultiplier;
    final rawRareChance = 1.0 + rareChancePerRank * safeRank;
    final rareDropChanceMultiplier = !rawRareChance.isFinite
        ? maxChanceMultiplier
        : rawRareChance.clamp(1.0, maxChanceMultiplier);

    final rollBonusPerRank =
        (!config.drop.rollBonusPerRank.isFinite ||
            config.drop.rollBonusPerRank < 0)
        ? 0.0
        : config.drop.rollBonusPerRank;
    final maxRollBonus =
        (!config.drop.maxRollBonus.isFinite || config.drop.maxRollBonus < 0.0)
        ? 0.0
        : config.drop.maxRollBonus;
    final rawRollBonus = rollBonusPerRank * safeRank;
    final equipmentRollBonus = !rawRollBonus.isFinite
        ? maxRollBonus
        : rawRollBonus.clamp(0.0, maxRollBonus);

    final safeEliteHpBonus = math.max(0.0, config.eliteHpPerRank);
    final safeEliteAtkBonus = math.max(0.0, config.eliteAtkPerRank);
    final safeBossHpBonus = math.max(0.0, config.bossHpPerRank);
    final safeBossAtkBonus = math.max(0.0, config.bossAtkPerRank);

    final rawEliteHp = hpMultiplier * (1.0 + safeEliteHpBonus * safeRank);
    final eliteHpMultiplier = !rawEliteHp.isFinite
        ? safeMax
        : math.min(rawEliteHp, safeMax);

    final rawEliteAtk = atkMultiplier * (1.0 + safeEliteAtkBonus * safeRank);
    final eliteAtkMultiplier = !rawEliteAtk.isFinite
        ? safeMax
        : math.min(rawEliteAtk, safeMax);

    final rawBossHp = hpMultiplier * (1.0 + safeBossHpBonus * safeRank);
    final bossHpMultiplier = !rawBossHp.isFinite
        ? safeMax
        : math.min(rawBossHp, safeMax);

    final rawBossAtk = atkMultiplier * (1.0 + safeBossAtkBonus * safeRank);
    final bossAtkMultiplier = !rawBossAtk.isFinite
        ? safeMax
        : math.min(rawBossAtk, safeMax);

    return DifficultyProfile(
      multiplier: multiplier,
      hpMultiplier: hpMultiplier,
      atkMultiplier: atkMultiplier,
      defMultiplier: defMultiplier,
      rewardMultiplier: rewardMultiplier,
      rareDropChanceMultiplier: rareDropChanceMultiplier,
      equipmentRollBonus: equipmentRollBonus,
      eliteHpMultiplier: eliteHpMultiplier,
      eliteAtkMultiplier: eliteAtkMultiplier,
      bossHpMultiplier: bossHpMultiplier,
      bossAtkMultiplier: bossAtkMultiplier,
      cycleRank: safeRank,
    );
  }

  /// Menghitung faktor pengali kekuatan Boss Event bertingkat berdasarkan
  /// [basePowerFactor] dan tingkat ascension [cycleRank].
  ///
  /// - Pada Rank 0: mempertahankan pengali awal yang aman (1.25x - 1.5x).
  /// - Pada Rank 1..4: meningkat secara bertahap dan seimbang menuju tantangan end-game.
  /// - Pada Rank 5+: mencapai batas pengali yang seimbang (hingga 1.50x untuk Daily Boss dan 2.00x untuk Weekly Boss).
  double computeBossPowerFactor(
    double basePowerFactor,
    int cycleRank, {
    Period? period,
  }) {
    if (cycleRank <= 0) return basePowerFactor;
    final isWeekly = period == Period.weekly || basePowerFactor >= 1.4;
    final targetMax = isWeekly ? 2.0 : 1.5;
    final initial = basePowerFactor;
    final progress = math.min(1.0, cycleRank / 5.0);
    return initial + (targetMax - initial) * progress;
  }

  /// Menghitung [DifficultyProfile] untuk Boss Event berdasarkan [reference]
  /// (dungeon acuan dan rank terpilih) dengan mengalikan [powerFactor] pada
  /// pengali stat (`hpMultiplier`, `atkMultiplier`, `defMultiplier`).
  /// `rewardMultiplier` dan bonus drop tetap mengikuti profil acuan.
  DifficultyProfile profileForBoss(
    BossReference reference,
    double powerFactor,
  ) {
    final base = profileFor(reference.dungeon, reference.cycleRank);
    final safeFactor = (!powerFactor.isFinite || powerFactor <= 0)
        ? 1.0
        : powerFactor;
    final safeMax = _resolvedMaxMultiplier();

    double scaleStat(double value) {
      final scaled = value * safeFactor;
      if (!scaled.isFinite || scaled > safeMax) return safeMax;
      return scaled;
    }

    return DifficultyProfile(
      multiplier: base.multiplier,
      hpMultiplier: scaleStat(base.hpMultiplier),
      atkMultiplier: scaleStat(base.atkMultiplier),
      defMultiplier: scaleStat(base.defMultiplier),
      rewardMultiplier: base.rewardMultiplier,
      rareDropChanceMultiplier: base.rareDropChanceMultiplier,
      equipmentRollBonus: base.equipmentRollBonus,
      eliteHpMultiplier: scaleStat(base.eliteHpMultiplier),
      eliteAtkMultiplier: scaleStat(base.eliteAtkMultiplier),
      bossHpMultiplier: scaleStat(base.bossHpMultiplier),
      bossAtkMultiplier: scaleStat(base.bossAtkMultiplier),
      cycleRank: reference.cycleRank,
    );
  }

  /// Menskalakan stat HP, ATK, dan DEF monster menggunakan [profile].
  /// Jika [isBoss] atau [isElite] true, pengali khusus tier pada rank bersangkutan diterapkan.
  /// Stat sekunder (attackSpeed, critRate, dll.) tetap dipertahankan.
  CombatStats scaleMonsterStats(
    CombatStats base,
    DifficultyProfile profile, {
    bool isElite = false,
    bool isBoss = false,
  }) {
    final effectiveHpMul = isBoss
        ? profile.bossHpMultiplier
        : (isElite ? profile.eliteHpMultiplier : profile.hpMultiplier);
    final effectiveAtkMul = isBoss
        ? profile.bossAtkMultiplier
        : (isElite ? profile.eliteAtkMultiplier : profile.atkMultiplier);
    final effectiveDefMul = profile.defMultiplier;

    if (effectiveHpMul == 1.0 &&
        effectiveAtkMul == 1.0 &&
        effectiveDefMul == 1.0) {
      return base;
    }
    return CombatStats(
      maxHp: _scalePositiveInt(base.maxHp, effectiveHpMul, minResult: 1),
      atk: _scalePositiveInt(base.atk, effectiveAtkMul, minResult: 1),
      def: _scalePositiveInt(base.def, effectiveDefMul, minResult: 0),
      attackSpeed: base.attackSpeed,
      critRate: base.critRate,
      critDamage: base.critDamage,
      moveSpeed: base.moveSpeed,
      attackRange: base.attackRange,
      skillHaste: base.skillHaste,
      lifesteal: isBoss && profile.cycleRank >= 1
          ? math.min(0.05, math.max(base.lifesteal, 0.005 * profile.cycleRank))
          : base.lifesteal,
      spellVamp: isBoss && profile.cycleRank >= 1
          ? math.min(0.06, math.max(base.spellVamp, 0.008 * profile.cycleRank))
          : base.spellVamp,
    );
  }

  /// Menskalakan EXP reward (pembulatan terdekat, minimum 1 bila [base] > 0).
  int scaleExp(int base, DifficultyProfile profile) =>
      _scaleReward(base, profile.rewardMultiplier);

  /// Menskalakan gold reward (pembulatan terdekat, minimum 1 bila [base] > 0).
  int scaleGold(int base, DifficultyProfile profile) =>
      _scaleReward(base, profile.rewardMultiplier);

  double _resolvedMaxMultiplier() {
    if (!config.maxMultiplier.isFinite || config.maxMultiplier < 1.0) {
      return 1.0;
    }
    return math.min(
      config.maxMultiplier,
      DifficultyConfig.technicalMaxMultiplierLimit,
    );
  }

  double _powClamped(double base, double exponent, double maxMul) {
    if (base == 1.0 || exponent == 0.0) return 1.0;
    if (!base.isFinite || !exponent.isFinite) return maxMul;
    if (exponent < 0.0) return 1.0;
    if (base <= 0.0) return 0.0;

    final result = math.pow(base, exponent).toDouble();
    if (!result.isFinite || result > maxMul) return maxMul;
    if (result < 0.0) return 0.0;
    return result;
  }

  int _scalePositiveInt(int base, double multiplier, {required int minResult}) {
    if (base <= 0) return minResult > 0 ? minResult : 0;
    if (multiplier == 1.0) return base;
    if (!multiplier.isFinite || multiplier < 0.0) return base;
    final scaled = base * multiplier;
    if (!scaled.isFinite || scaled >= kMaxScaledValue) {
      return kMaxScaledValue;
    }
    final rounded = scaled.round();
    return math.max(minResult, math.min(kMaxScaledValue, rounded));
  }

  int _scaleReward(int base, double multiplier) {
    if (base <= 0) return 0;
    if (multiplier == 1.0) return base;
    if (!multiplier.isFinite || multiplier <= 0.0) return base;
    final scaled = base * multiplier;
    if (!scaled.isFinite || scaled >= kMaxScaledValue) {
      return kMaxScaledValue;
    }
    return math.max(1, math.min(kMaxScaledValue, scaled.round()));
  }
}
