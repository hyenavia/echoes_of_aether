import 'equipment.dart';

enum SkillType { active, passive }

/// Jenis efek skill.
enum SkillEffectType { damage, healing, statModifier }

/// Tipe damage untuk skill bertipe [SkillEffectType.damage].
enum SkillDamageType { physical, magic }

/// Sasaran skill: satu musuh, semua musuh di sekitar target utama, atau diri
/// sendiri (untuk healing).
enum SkillTarget { single, area, self }

/// Definisi statis skill (dari skills.json).
class SkillDefinition {
  const SkillDefinition({
    required this.id,
    required this.name,
    required this.type,
    this.unlockLevel = 1,
    this.specializationId,
    this.cooldownSeconds = 0,
    SkillEffectType? effect,
    SkillDamageType? damageType,
    this.targetType = SkillTarget.single,
    double damageMultiplier = 1.0,
    double healPercent = 0,
    double? baseValue,
    this.valuePerLevel = 0,
    this.maxLevel = 5,
    this.upgradeCost = 50,
    this.range,
    this.radius = 0,
    this.useWhenHpBelow,
    this.minEnemies = 2,
    this.passiveStats = EquipmentStats.zero,
  }) : effect =
           effect ??
           (type == SkillType.passive
               ? SkillEffectType.statModifier
               : SkillEffectType.damage),
       damageType =
           (effect ??
                   (type == SkillType.passive
                       ? SkillEffectType.statModifier
                       : SkillEffectType.damage)) ==
               SkillEffectType.damage
           ? (damageType ?? SkillDamageType.physical)
           : null,
       baseValue =
           baseValue ??
           ((effect ??
                       (type == SkillType.passive
                           ? SkillEffectType.statModifier
                           : SkillEffectType.damage)) ==
                   SkillEffectType.healing
               ? healPercent
               : ((effect ??
                             (type == SkillType.passive
                                 ? SkillEffectType.statModifier
                                 : SkillEffectType.damage)) ==
                         SkillEffectType.statModifier
                     ? 1.0
                     : damageMultiplier));

  final String id;
  final String name;
  final SkillType type;

  /// Level karakter minimum agar skill terbuka.
  final int unlockLevel;

  /// Null berarti skill umum (tersedia untuk semua specialization).
  final String? specializationId;

  // ---- Skill aktif & efek ----
  final double cooldownSeconds;
  final SkillEffectType effect;
  final SkillDamageType? damageType;
  final SkillTarget targetType;

  /// Nilai dasar pada level 1 (pengali ATK, rasio heal, atau pengali stat pasif).
  final double baseValue;

  /// Kenaikan nilai per tambahan level di atas level 1.
  final double valuePerLevel;
  final int maxLevel;

  /// Biaya gold dasar untuk upgrade ke level berikutnya (cost = upgradeCost * level).
  final int upgradeCost;

  /// Jarak maksimum ke target utama; null memakai attack range karakter.
  final double? range;

  /// Radius area di sekitar target utama (skill area).
  final double radius;

  /// Healing hanya dipakai otomatis jika HP di bawah rasio ini (default 0.4).
  final double? useWhenHpBelow;

  /// Skill area hanya dipakai otomatis jika minimal sebanyak ini musuh
  /// berada dalam radius.
  final int minEnemies;

  // ---- Skill pasif ----
  final EquipmentStats passiveStats;

  SkillEffectType get effectType => effect;
  bool get isActive => type == SkillType.active;
  bool get isPassive => type == SkillType.passive;

  /// Pengali ATK level 1 untuk skill damage.
  double get damageMultiplier =>
      effect == SkillEffectType.damage ? baseValue : 0;

  /// Persentase max HP level 1 yang dipulihkan untuk skill healing.
  double get healPercent => effect == SkillEffectType.healing ? baseValue : 0;

  /// Nilai terskalakan pada [level] skill saat ini.
  double valueAtLevel(int level) {
    final effective = level.clamp(1, maxLevel < 1 ? 1 : maxLevel);
    return baseValue + valuePerLevel * (effective - 1);
  }

  double damageMultiplierAt(int level) =>
      effect == SkillEffectType.damage ? valueAtLevel(level) : 0;

  double healPercentAt(int level) => effect == SkillEffectType.healing
      ? valueAtLevel(level).clamp(0.0, 1.0)
      : 0;

  EquipmentStats passiveStatsAt(int level) =>
      effect == SkillEffectType.statModifier
      ? passiveStats.scaled(valueAtLevel(level))
      : EquipmentStats.zero;

  /// Biaya gold untuk naik dari [currentLevel] ke level berikutnya; 0 bila maks.
  int upgradeCostForNextLevel(int currentLevel) {
    if (currentLevel >= maxLevel) return 0;
    return upgradeCost * currentLevel;
  }

  /// Dipakai untuk memilih skill terkuat dalam kategori yang sama.
  double get power => baseValue;
}
