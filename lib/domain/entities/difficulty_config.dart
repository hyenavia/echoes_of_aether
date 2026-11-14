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

/// Konfigurasi kesulitan dan scaling reward dari `game_config.json`.
class DifficultyConfig {
  const DifficultyConfig({
    this.cyclePerRank = 0.4,
    this.ascensionMultiplier = 1.35,
    this.statExponents = const StatExponentsConfig(),
    this.cycleStatExponents,
    this.cycleLevelStep,
    this.rewardExponent = 0.85,
    this.drop = const DropScalingConfig(),
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
  final double rewardExponent;
  final DropScalingConfig drop;
  final double maxMultiplier;
}
