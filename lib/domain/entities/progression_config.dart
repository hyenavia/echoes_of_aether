import 'dart:math' as math;

import 'combat_stats.dart';

/// Jenis kurva kebutuhan EXP untuk naik level (GDD Addendum §5, TDD Addendum §2.1).
enum ExpCurveType {
  /// Kurva polinomial: base * level^exponent (default baru).
  polynomial,

  /// Kurva eksponensial: base * growth^(level-1) (dipertahankan untuk regresi).
  exponential,
}

/// Konfigurasi kurva EXP.
class ExpCurveConfig {
  const ExpCurveConfig.polynomial({this.base = 60.0, this.exponent = 1.8})
    : type = ExpCurveType.polynomial,
      growth = null;

  const ExpCurveConfig.exponential({
    required this.base,
    required double this.growth,
  }) : type = ExpCurveType.exponential,
       exponent = null;

  final ExpCurveType type;
  final double base;
  final double? exponent;
  final double? growth;
}

/// Pertambahan atribut per level (di atas level 1).
class LevelGrowth {
  const LevelGrowth({required this.hp, required this.atk, required this.def});

  final double hp;
  final double atk;
  final double def;
}

/// Kurva EXP dan pertumbuhan stat player. Dimuat dari game_config.json,
/// sehingga balancing bisa diubah tanpa menyentuh kode.
class ProgressionConfig {
  const ProgressionConfig({
    this.maxLevel,
    this.expCurve = const ExpCurveConfig.polynomial(),
    double? expBase,
    double? expGrowth,
    required this.baseStats,
    required this.perLevel,
  }) : _legacyExpBase = expBase,
       _legacyExpGrowth = expGrowth;

  /// Batas pelindung teknis untuk mencegah iterasi tak terbatas atau overflow memori/perhitungan.
  /// Bukan batas desain permainan dan tidak boleh ditampilkan di UI (TDD Addendum §3.2).
  static const int kTechnicalMaxLevel = 1000000;

  /// Batas aman EXP per level berikutnya agar tetap aman dalam representasi integer 32-bit.
  static const int kMaxExpToNext = 2000000000;

  /// Level maksimum karakter. `null` berarti tanpa batas (endless leveling).
  final int? maxLevel;

  /// Konfigurasi kurva EXP (polinomial atau eksponensial).
  final ExpCurveConfig expCurve;

  final double? _legacyExpBase;
  final double? _legacyExpGrowth;

  /// EXP yang dibutuhkan untuk naik dari level 1 ke level 2.
  double get expBase => _legacyExpBase ?? expCurve.base;

  /// Pengali kebutuhan EXP untuk setiap level berikutnya (>= 1).
  double get expGrowth => _legacyExpGrowth ?? expCurve.growth ?? 1.0;

  /// Stat pada level 1.
  final CombatStats baseStats;

  final LevelGrowth perLevel;

  /// EXP yang dibutuhkan untuk naik dari [level] ke level berikutnya.
  /// Aman terhadap level negatif/nol, NaN, Infinity, dan di-clamp ke [kMaxExpToNext].
  int expToNext(int level) {
    final effectiveLevel = math.max(1, level);
    final double raw;
    if (_legacyExpBase != null && _legacyExpGrowth != null) {
      raw = _legacyExpBase * math.pow(_legacyExpGrowth, effectiveLevel - 1);
    } else {
      switch (expCurve.type) {
        case ExpCurveType.polynomial:
          final exp = expCurve.exponent ?? 1.8;
          raw = expCurve.base * math.pow(effectiveLevel, exp);
        case ExpCurveType.exponential:
          final growth = expCurve.growth ?? 1.0;
          raw = expCurve.base * math.pow(growth, effectiveLevel - 1);
      }
    }

    if (raw.isNaN || raw <= 0) return 1;
    if (raw.isInfinite || raw >= kMaxExpToNext) return kMaxExpToNext;
    return raw.round().clamp(1, kMaxExpToNext);
  }

  /// Stat tempur player pada [level] (tanpa equipment, skill, specialization).
  CombatStats statsAt(int level) {
    final steps = math.max(0, level - 1);
    return CombatStats(
      maxHp: baseStats.maxHp + (perLevel.hp * steps).round(),
      atk: baseStats.atk + (perLevel.atk * steps).round(),
      def: baseStats.def + (perLevel.def * steps).round(),
      attackSpeed: baseStats.attackSpeed,
      critRate: baseStats.critRate,
      critDamage: baseStats.critDamage,
      moveSpeed: baseStats.moveSpeed,
      attackRange: baseStats.attackRange,
      skillHaste: baseStats.skillHaste,
    );
  }
}
