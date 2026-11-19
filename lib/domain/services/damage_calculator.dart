import 'dart:math' as math;

import '../entities/combat_stats.dart';
import '../entities/skill_definition.dart';

/// Pilihan rumus kalkulasi damage (GDD Addendum §6, TDD Addendum §3.1).
enum DamageFormula {
  /// Rumus rasio: max(1, round(ATK * ATK / (ATK + max(0, DEF)))).
  ratio,

  /// Rumus lama: max(1, ATK - DEF), dipertahankan untuk regresi.
  subtractive,
}

class DamageResult {
  const DamageResult(
    this.amount,
    this.isCrit, {
    this.damageType = SkillDamageType.physical,
  });

  final int amount;
  final bool isCrit;
  final SkillDamageType damageType;
}

/// Rumus damage (GDD 2.3 & GDD Addendum §6). Seluruh rumus berada di Domain Layer,
/// bukan di komponen Flame. Keacakan berasal dari [math.Random] yang disuntikkan,
/// sehingga simulasi dengan seed sama menghasilkan hasil sama.
class DamageCalculator {
  const DamageCalculator({
    this.magicDefenseFactor = 0.80,
    this.formula = DamageFormula.ratio,
  });

  /// Batas pelindung teknis maksimum damage untuk menghindari overflow integer.
  static const int kMaxDamage = 2000000000;

  /// Faktor efektivitas DEF target terhadap magic damage (default 1.0 agar
  /// konsisten dengan desain combat DEF tunggal saat ini).
  final double magicDefenseFactor;

  /// Model rumus kalkulasi damage yang digunakan.
  final DamageFormula formula;

  /// Damage dasar sesuai [damageType].
  int baseDamage(
    int atk,
    int def, {
    SkillDamageType damageType = SkillDamageType.physical,
  }) => switch (damageType) {
    SkillDamageType.physical => physicalDamage(atk, def),
    SkillDamageType.magic => magicDamage(atk, def),
    SkillDamageType.trueDamage => trueDamage(atk),
  };

  int trueDamage(int atk) => math.max(1, math.min(kMaxDamage, atk));

  int physicalDamage(int atk, int def) => switch (formula) {
    DamageFormula.ratio => _calculateRatioDamage(atk, def),
    DamageFormula.subtractive => math.max(1, math.min(kMaxDamage, atk - def)),
  };

  int magicDamage(int atk, int def) {
    final effectiveDef = (def * magicDefenseFactor).round();
    return switch (formula) {
      DamageFormula.ratio => _calculateRatioDamage(atk, effectiveDef),
      DamageFormula.subtractive => math.max(
        1,
        math.min(kMaxDamage, atk - effectiveDef),
      ),
    };
  }

  int _calculateRatioDamage(int atk, int def) {
    if (atk <= 0) return 1;
    final dAtk = atk.toDouble();
    final safeDef = math.max(0, def).toDouble();
    final denom = dAtk + safeDef;
    if (denom <= 0) return 1;
    final raw = dAtk * (dAtk / denom);
    if (raw.isNaN) return 1;
    if (raw.isInfinite || raw >= kMaxDamage) return kMaxDamage;
    final rounded = raw.round();
    return math.max(1, math.min(kMaxDamage, rounded));
  }

  /// [multiplier] mengalikan ATK penyerang sebelum dikurangi/dibagi DEF
  /// (serangan biasa = 1.0; skill memakai damageMultiplierAt(level)).
  DamageResult roll({
    required CombatStats attacker,
    required int defenderDef,
    required math.Random random,
    double multiplier = 1.0,
    SkillDamageType damageType = SkillDamageType.physical,
  }) {
    final scaledAtk = (attacker.atk * multiplier).round();
    final base = baseDamage(scaledAtk, defenderDef, damageType: damageType);
    final isCrit =
        attacker.critRate > 0 && random.nextDouble() < attacker.critRate;
    final amount = isCrit ? (base * attacker.critDamage).round() : base;
    return DamageResult(
      math.max(1, math.min(kMaxDamage, amount)),
      isCrit,
      damageType: damageType,
    );
  }
}
