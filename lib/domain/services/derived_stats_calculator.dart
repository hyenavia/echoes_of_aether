import 'dart:math' as math;

import '../entities/combat_stats.dart';
import '../entities/equipment.dart';
import '../entities/skill_definition.dart';
import '../entities/specialization.dart';

/// Batas aman atribut akhir karakter setelah seluruh modifier diterapkan
/// (GDD 3.2, 6.6). Mencegah nilai tidak valid seperti HP <= 0 atau ASPD <= 0.
class StatBounds {
  const StatBounds({
    this.minHp = 1,
    this.minAtk = 0,
    this.minDef = 0,
    this.minAttackSpeed = 0.1,
    this.maxAttackSpeed = 10.0,
    this.minCritRate = 0.0,
    this.maxCritRate = 1.0,
    this.minCritDamage = 1.0,
    this.minMoveSpeed = 0.1,
    this.maxMoveSpeed = 20.0,
    this.minAttackRange = 0.5,
    this.maxAttackRange = 20.0,
    this.minSkillHaste = 0.0,
    this.maxSkillHaste = EquipmentStats.maxSkillHaste,
  });

  final int minHp;
  final int minAtk;
  final int minDef;
  final double minAttackSpeed;
  final double maxAttackSpeed;
  final double minCritRate;
  final double maxCritRate;
  final double minCritDamage;
  final double minMoveSpeed;
  final double maxMoveSpeed;
  final double minAttackRange;
  final double maxAttackRange;
  final double minSkillHaste;
  final double maxSkillHaste;
}

/// Sumber tunggal perhitungan atribut akhir karakter (TDD 9.2):
///
/// ```text
/// Final Stats =
///   Base Stats (level)
///   + Equipment Modifiers
///   + Specialization Modifiers
///   + Passive Skill Modifiers (beserta skill affinity specialization)
/// ```
///
/// Aturan perhitungan:
/// - Seluruh modifier aditif dijumlahkan dalam bentuk pecahan (`double`) terlebih
///   dahulu lalu dibulatkan satu kali untuk `maxHp`, `atk`, dan `def` agar
///   bebas drift pembulatan per item/skill.
/// - `specialization.attackRange`, jika terisi, menggantikan base `attackRange`
///   sebelum ditambahkan bonus `attackRange` dari modifier aditif lain.
/// - Perhitungan bersifat murni (stateless): tidak menyimpan akumulasi hasil
///   sebelumnya sehingga pemanggilan berulang selalu identik.
class DerivedStatsCalculator {
  const DerivedStatsCalculator({this.bounds = const StatBounds()});

  final StatBounds bounds;

  CombatStats calculate({
    required CombatStats baseStats,
    EquipmentStats equipmentBonus = EquipmentStats.zero,
    SpecializationDefinition? specialization,
    Iterable<SkillDefinition> passiveSkills = const [],
    int Function(String skillId)? skillLevelOf,
  }) {
    var totalBonus = equipmentBonus;
    for (final skill in passiveSkills) {
      if (!skill.isPassive) continue;
      final level = skillLevelOf?.call(skill.id) ?? 1;
      final affinity = specialization?.affinityFor(skill.id) ?? 0.0;
      totalBonus =
          totalBonus + skill.passiveStatsAt(level).scaled(1.0 + affinity);
    }
    if (specialization != null) {
      totalBonus = totalBonus + specialization.bonus;
    }

    final rawMaxHp = baseStats.maxHp + totalBonus.hp.round();
    final rawAtk = baseStats.atk + totalBonus.atk.round();
    final rawDef = baseStats.def + totalBonus.def.round();
    final baseRange = specialization?.attackRange ?? baseStats.attackRange;

    return clamp(
      CombatStats(
        maxHp: rawMaxHp,
        atk: rawAtk,
        def: rawDef,
        attackSpeed: baseStats.attackSpeed + totalBonus.attackSpeed,
        critRate: baseStats.critRate + totalBonus.critRate,
        critDamage: baseStats.critDamage + totalBonus.critDamage,
        moveSpeed: baseStats.moveSpeed + totalBonus.moveSpeed,
        attackRange: baseRange + totalBonus.attackRange,
        skillHaste: baseStats.skillHaste + totalBonus.skillHaste,
      ),
    );
  }

  /// Memastikan setiap atribut tetap berada dalam batas domain yang valid.
  CombatStats clamp(CombatStats stats) {
    return CombatStats(
      maxHp: math.max(bounds.minHp, stats.maxHp),
      atk: math.max(bounds.minAtk, stats.atk),
      def: math.max(bounds.minDef, stats.def),
      attackSpeed: _clampDouble(
        stats.attackSpeed,
        bounds.minAttackSpeed,
        bounds.maxAttackSpeed,
      ),
      critRate: _clampDouble(
        stats.critRate,
        bounds.minCritRate,
        bounds.maxCritRate,
      ),
      critDamage: math.max(bounds.minCritDamage, stats.critDamage),
      moveSpeed: _clampDouble(
        stats.moveSpeed,
        bounds.minMoveSpeed,
        bounds.maxMoveSpeed,
      ),
      attackRange: _clampDouble(
        stats.attackRange,
        bounds.minAttackRange,
        bounds.maxAttackRange,
      ),
      skillHaste: _clampDouble(
        stats.skillHaste,
        bounds.minSkillHaste,
        bounds.maxSkillHaste,
      ),
    );
  }

  double _clampDouble(double value, double min, double max) {
    if (value.isNaN || value.isInfinite) return min;
    return value.clamp(min, max).toDouble();
  }
}
