import '../services/damage_calculator.dart';

/// Konfigurasi rumus kalkulasi damage (GDD Addendum §6, TDD Addendum §2.1).
class DamageConfig {
  const DamageConfig({this.formula = DamageFormula.ratio});

  final DamageFormula formula;

  /// Membuat [DamageCalculator] sesuai konfigurasi rumus saat ini.
  DamageCalculator createCalculator({double magicDefenseFactor = 0.80}) =>
      DamageCalculator(
        magicDefenseFactor: magicDefenseFactor,
        formula: formula,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DamageConfig &&
          runtimeType == other.runtimeType &&
          formula == other.formula;

  @override
  int get hashCode => formula.hashCode;
}
