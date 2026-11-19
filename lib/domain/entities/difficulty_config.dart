/// Eksponen scaling stat monster terhadap pengali kesulitan efektif [M].
class StatExponentsConfig {
  const StatExponentsConfig({this.hp = 1.0, this.atk = 1.0, this.def = 0.9});

  final double hp;
  final double atk;
  final double def;
}

/// Konfigurasi peningkatan peluang rare drop dan bonus roll equipment per rank.
class DropScalingConfig {
  const DropScalingConfig({
    this.rareChancePerRank = 0.1,
    this.maxChanceMultiplier = 3.0,
    this.rollBonusPerRank = 0.02,
    this.maxRollBonus = 0.5,
  });

  final double rareChancePerRank;
  final double maxChanceMultiplier;
  final double rollBonusPerRank;
  final double maxRollBonus;
}

/// Konfigurasi mekanik dan skill khusus untuk monster Elite dan Boss (Stage 2 & 3).
class EliteBossMechanicsConfig {
  const EliteBossMechanicsConfig({
    this.minAscensionRank = 1,
    this.stoneskinDamageReduction = 0.15,
    this.stoneskinHpThreshold = 0.50,
    this.berserkHpThreshold = 0.25,
    this.berserkAtkMultiplier = 1.10,
    this.berserkSpeedMultiplier = 1.10,
    this.eliteHeavyStrikeCooldownSeconds = 6.0,
    this.eliteHeavyStrikeMultiplier = 1.20,
    this.bossAoeCooldownSeconds = 8.0,
    this.bossAoeRadius = 2.5,
    this.bossAoeMultiplier = 1.05,
    this.bossSummonHpThreshold = 0.35,
    this.bossSummonCount = 1,
    this.dailyElementalWardReduction = 0.30,
    this.dailyElementalWardDurationSeconds = 6.0,
    this.dailyElementalWardHpThreshold = 0.60,
    this.dailyBlazingSurgeCooldownSeconds = 6.0,
    this.dailyBlazingSurgeRadius = 3.0,
    this.dailyBlazingSurgeMultiplier = 1.25,
    this.dailyEnragedRushHpThreshold = 0.30,
    this.dailyEnragedRushAtkMultiplier = 1.20,
    this.dailyEnragedRushSpeedMultiplier = 1.20,
    this.weeklyLifeSiphonCooldownSeconds = 5.0,
    this.weeklyLifeSiphonMultiplier = 1.35,
    this.weeklyLifeSiphonHealRatio = 0.30,
    this.weeklyCataclysmCooldownSeconds = 8.0,
    this.weeklyCataclysmRadius = 3.5,
    this.weeklyCataclysmMultiplier = 1.30,
    this.weeklySummonHpThreshold = 0.50,
    this.weeklySummonCount = 2,
    this.weeklyFinalStandHpThreshold = 0.20,
    this.weeklyFinalStandAtkMultiplier = 1.25,
    this.weeklyFinalStandSpeedMultiplier = 1.25,
    this.weeklyFinalStandDamageReduction = 0.20,
  });

  /// Rank minimum agar mekanik khusus aktif (default: 1, rank 0 standar unscaled).
  final int minAscensionRank;

  /// Persentase pengurangan damage saat Stoneskin aktif (0.0 - 1.0).
  final double stoneskinDamageReduction;

  /// Ambang batas rasio HP saat Stoneskin aktif (HP > threshold).
  final double stoneskinHpThreshold;

  /// Ambang batas rasio HP untuk memicu status Berserk (HP <= threshold).
  final double berserkHpThreshold;

  /// Pengali damage serangan saat monster dalam status Berserk.
  final double berserkAtkMultiplier;

  /// Pengali kecepatan serang saat monster dalam status Berserk.
  final double berserkSpeedMultiplier;

  /// Cooldown (detik) skill Heavy Strike milik monster Elite.
  final double eliteHeavyStrikeCooldownSeconds;

  /// Pengali damage Heavy Strike milik monster Elite.
  final double eliteHeavyStrikeMultiplier;

  /// Cooldown (detik) Ground Slam AoE milik Boss.
  final double bossAoeCooldownSeconds;

  /// Radius jangkauan (tile) Ground Slam AoE milik Boss.
  final double bossAoeRadius;

  /// Pengali damage Ground Slam AoE milik Boss.
  final double bossAoeMultiplier;

  /// Ambang batas rasio HP untuk memicu pemanggilan minion guards oleh Boss.
  final double bossSummonHpThreshold;

  /// Jumlah minion guards yang dipanggil oleh Boss.
  final int bossSummonCount;

  /// Persentase pengurangan damage saat Elemental Ward aktif pada Daily Boss (0.0 - 1.0).
  final double dailyElementalWardReduction;

  /// Durasi (detik) Elemental Ward aktif pada Daily Boss.
  final double dailyElementalWardDurationSeconds;

  /// Ambang batas rasio HP untuk memicu Elemental Ward pada Daily Boss.
  final double dailyElementalWardHpThreshold;

  /// Cooldown (detik) Blazing Surge AoE milik Daily Boss.
  final double dailyBlazingSurgeCooldownSeconds;

  /// Radius jangkauan (tile) Blazing Surge AoE milik Daily Boss.
  final double dailyBlazingSurgeRadius;

  /// Pengali damage Blazing Surge AoE milik Daily Boss.
  final double dailyBlazingSurgeMultiplier;

  /// Ambang batas rasio HP untuk memicu Enraged Rush pada Daily Boss.
  final double dailyEnragedRushHpThreshold;

  /// Pengali damage serangan saat Daily Boss dalam status Enraged Rush.
  final double dailyEnragedRushAtkMultiplier;

  /// Pengali kecepatan serang saat Daily Boss dalam status Enraged Rush.
  final double dailyEnragedRushSpeedMultiplier;

  /// Cooldown (detik) skill Life Siphon milik Weekly Boss.
  final double weeklyLifeSiphonCooldownSeconds;

  /// Pengali damage Life Siphon milik Weekly Boss.
  final double weeklyLifeSiphonMultiplier;

  /// Rasio damage Life Siphon yang diubah menjadi pemulihan HP Weekly Boss.
  final double weeklyLifeSiphonHealRatio;

  /// Cooldown (detik) Cataclysm AoE milik Weekly Boss.
  final double weeklyCataclysmCooldownSeconds;

  /// Radius jangkauan (tile) Cataclysm AoE milik Weekly Boss.
  final double weeklyCataclysmRadius;

  /// Pengali damage Cataclysm AoE milik Weekly Boss.
  final double weeklyCataclysmMultiplier;

  /// Ambang batas rasio HP untuk memicu pemanggilan guard elite oleh Weekly Boss.
  final double weeklySummonHpThreshold;

  /// Jumlah guard elite yang dipanggil oleh Weekly Boss.
  final int weeklySummonCount;

  /// Ambang batas rasio HP untuk memicu status Final Stand pada Weekly Boss.
  final double weeklyFinalStandHpThreshold;

  /// Pengali damage serangan saat Weekly Boss dalam status Final Stand.
  final double weeklyFinalStandAtkMultiplier;

  /// Pengali kecepatan serang saat Weekly Boss dalam status Final Stand.
  final double weeklyFinalStandSpeedMultiplier;

  /// Persentase pengurangan damage permanen saat Weekly Boss dalam Final Stand.
  final double weeklyFinalStandDamageReduction;

  /// Apakah mekanik aktif untuk [cycleRank] yang diberikan.
  bool isEnabledFor(int cycleRank) => cycleRank >= minAscensionRank;
}

/// Konfigurasi kesulitan dan scaling reward dari `game_config.json`.
class DifficultyConfig {
  const DifficultyConfig({
    this.cyclePerRank = 0.4,
    this.ascensionMultiplier = 1.35,
    this.statExponents = const StatExponentsConfig(),
    this.cycleStatExponents,
    this.cycleLevelStep,
    this.eliteHpPerRank = 0.04,
    this.eliteAtkPerRank = 0.01,
    this.bossHpPerRank = 0.05,
    this.bossAtkPerRank = 0.01,
    this.rewardExponent = 0.85,
    this.drop = const DropScalingConfig(),
    this.mechanics = const EliteBossMechanicsConfig(),
    this.maxMultiplier = 1000000000.0,
  });

  /// Batas teknis maksimum `max_multiplier` agar perkalian tidak berisiko overflow.
  static const double technicalMaxMultiplierLimit = 1e12;

  final double cyclePerRank;
  final double ascensionMultiplier;
  final StatExponentsConfig statExponents;

  /// Eksponen scaling stat khusus faktor siklus `C(rank)`.
  ///
  /// Jika null, faktor siklus memakai eksponen global [statExponents] agar
  /// konfigurasi lama dan test unit tetap kompatibel mundur.
  final StatExponentsConfig? cycleStatExponents;

  /// Kenaikan level rekomendasi/requirement linear per Ascension Rank (`rec(d, 0) + R * cycleLevelStep`).
  ///
  /// Jika null, memakai rumus logaritmik baseline M8/M9 (`ceil(8 * ln(C(R)) / ln(1.5))`).
  final int? cycleLevelStep;

  /// Pengali tambahan HP monster Elite per Ascension Rank: `(1 + eliteHpPerRank * rank)`.
  final double eliteHpPerRank;

  /// Pengali tambahan ATK monster Elite per Ascension Rank: `(1 + eliteAtkPerRank * rank)`.
  final double eliteAtkPerRank;

  /// Pengali tambahan HP monster Boss per Ascension Rank: `(1 + bossHpPerRank * rank)`.
  final double bossHpPerRank;

  /// Pengali tambahan ATK monster Boss per Ascension Rank: `(1 + bossAtkPerRank * rank)`.
  final double bossAtkPerRank;
  final double rewardExponent;
  final DropScalingConfig drop;
  final EliteBossMechanicsConfig mechanics;
  final double maxMultiplier;
}
