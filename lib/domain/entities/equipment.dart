import 'dart:math' as math;

import 'combat_stats.dart';
import 'item_definition.dart';

/// Slot equipment MVP (GDD 3.4).
enum EquipmentSlot { weapon, head, body, accessory }

/// Bonus atribut flat/aditif. Dipakai oleh equipment, skill pasif, dan
/// specialization. HP/ATK/DEF bersifat flat; crit, attack speed, move speed,
/// attack range, dan skill haste bersifat aditif terhadap stat dasar karakter.
class EquipmentStats {
  const EquipmentStats({
    this.hp = 0,
    this.atk = 0,
    this.def = 0,
    this.hpPct = 0,
    this.atkPct = 0,
    this.defPct = 0,
    this.critRate = 0,
    this.critDamage = 0,
    this.attackSpeed = 0,
    this.moveSpeed = 0,
    this.attackRange = 0,
    this.skillHaste = 0,
    this.lifesteal = 0,
    this.spellVamp = 0,
  });

  static const EquipmentStats zero = EquipmentStats();

  /// Batas atas total skill haste agar cooldown tidak menjadi nol.
  static const double maxSkillHaste = 0.75;

  final double hp;
  final double atk;
  final double def;
  final double hpPct;
  final double atkPct;
  final double defPct;
  final double critRate;
  final double critDamage;
  final double attackSpeed;
  final double moveSpeed;
  final double attackRange;
  final double skillHaste;
  final double lifesteal;
  final double spellVamp;

  bool get isEmpty =>
      hp == 0 &&
      atk == 0 &&
      def == 0 &&
      hpPct == 0 &&
      atkPct == 0 &&
      defPct == 0 &&
      critRate == 0 &&
      critDamage == 0 &&
      attackSpeed == 0 &&
      moveSpeed == 0 &&
      attackRange == 0 &&
      skillHaste == 0 &&
      lifesteal == 0 &&
      spellVamp == 0;

  EquipmentStats operator +(EquipmentStats o) => EquipmentStats(
    hp: hp + o.hp,
    atk: atk + o.atk,
    def: def + o.def,
    hpPct: hpPct + o.hpPct,
    atkPct: atkPct + o.atkPct,
    defPct: defPct + o.defPct,
    critRate: critRate + o.critRate,
    critDamage: critDamage + o.critDamage,
    attackSpeed: attackSpeed + o.attackSpeed,
    moveSpeed: moveSpeed + o.moveSpeed,
    attackRange: attackRange + o.attackRange,
    skillHaste: skillHaste + o.skillHaste,
    lifesteal: lifesteal + o.lifesteal,
    spellVamp: spellVamp + o.spellVamp,
  );

  EquipmentStats scaled(double factor) => factor == 1.0
      ? this
      : EquipmentStats(
          hp: hp * factor,
          atk: atk * factor,
          def: def * factor,
          hpPct: hpPct * factor,
          atkPct: atkPct * factor,
          defPct: defPct * factor,
          critRate: critRate * factor,
          critDamage: critDamage * factor,
          attackSpeed: attackSpeed * factor,
          moveSpeed: moveSpeed * factor,
          attackRange: attackRange * factor,
          skillHaste: skillHaste * factor,
          lifesteal: lifesteal * factor,
          spellVamp: spellVamp * factor,
        );

  /// Mengacak setiap stat yang tidak nol dalam rentang ±[variance]
  /// (0.15 = 85%..115% dari nilai dasar) ditambah [rollBonus] aditif.
  /// Urutan pemanggilan `random` tetap, sehingga seed yang sama menghasilkan
  /// hasil yang sama.
  EquipmentStats roll(
    math.Random random,
    double variance, {
    double rollBonus = 0.0,
  }) {
    final safeBonus = rollBonus.isFinite && rollBonus > 0 ? rollBonus : 0.0;
    double r(double value) {
      if (value == 0) return 0;
      final factor = 1 + (random.nextDouble() * 2 - 1) * variance + safeBonus;
      return value * (factor < 0 ? 0 : factor);
    }

    return EquipmentStats(
      hp: r(hp),
      atk: r(atk),
      def: r(def),
      hpPct: r(hpPct),
      atkPct: r(atkPct),
      defPct: r(defPct),
      critRate: r(critRate),
      critDamage: r(critDamage),
      attackSpeed: r(attackSpeed),
      moveSpeed: r(moveSpeed),
      attackRange: r(attackRange),
      skillHaste: r(skillHaste),
      lifesteal: r(lifesteal),
      spellVamp: r(spellVamp),
    );
  }

  /// Menggabungkan bonus ini ke stat dasar. Pembulatan dilakukan sekali pada
  /// jumlah total, bukan per item.
  CombatStats applyTo(CombatStats base) => CombatStats(
    maxHp: math.max(1, base.maxHp + hp.round()),
    atk: math.max(0, base.atk + atk.round()),
    def: math.max(0, base.def + def.round()),
    attackSpeed: math.max(0.1, base.attackSpeed + attackSpeed),
    critRate: math.min(1.0, math.max(0.0, base.critRate + critRate)),
    critDamage: math.max(1.0, base.critDamage + critDamage),
    moveSpeed: math.max(0.1, base.moveSpeed + moveSpeed),
    attackRange: math.max(0.5, base.attackRange + attackRange),
    skillHaste: math.min(
      maxSkillHaste,
      math.max(0.0, base.skillHaste + skillHaste),
    ),
    lifesteal: math.min(1.0, math.max(0.0, base.lifesteal + lifesteal)),
    spellVamp: math.min(1.0, math.max(0.0, base.spellVamp + spellVamp)),
  );
}

/// Data khusus equipment pada [ItemDefinition].
class EquipmentData {
  const EquipmentData({
    required this.slot,
    required this.baseStats,
    this.weaponType,
    this.fixedStats = false,
    this.signatureClassId,
    this.resonanceDescription,
    this.setId,
  });

  final EquipmentSlot slot;
  final EquipmentStats baseStats;

  /// sword / staff / bow / gun / scythe; hanya untuk slot weapon.
  final String? weaponType;

  /// Jika `true`, item tidak di-roll saat dibuat oleh [EquipmentFactory].
  final bool fixedStats;

  /// Class specialization yang bersinergi dengan senjata ini (jika ada).
  final String? signatureClassId;

  /// Penjelasan efek khusus saat dipakai oleh signature class.
  final String? resonanceDescription;

  /// ID equipment set Mythical yang menaungi item ini (jika bagian dari set).
  final String? setId;
}

/// Satu item equipment milik player dengan hasil roll tersendiri (GDD 13).
/// Berbeda dari [ItemDefinition], yang hanya mendeskripsikan jenis item.
class EquipmentInstance {
  const EquipmentInstance({
    required this.id,
    required this.definitionId,
    required this.slot,
    required this.rarity,
    required this.rolledStats,
    this.enhancementLevel = 0,
    this.isFavorite = false,
  });

  final String id;
  final String definitionId;
  final EquipmentSlot slot;
  final ItemRarity rarity;
  final EquipmentStats rolledStats;

  /// Tingkat enhancement item (+1 sampai +10).
  final int enhancementLevel;

  /// Menandai apakah item ini difavoritkan sehingga terlindungi dari penjualan.
  final bool isFavorite;

  EquipmentInstance copyWith({
    String? id,
    String? definitionId,
    EquipmentSlot? slot,
    ItemRarity? rarity,
    EquipmentStats? rolledStats,
    int? enhancementLevel,
    bool? isFavorite,
  }) => EquipmentInstance(
    id: id ?? this.id,
    definitionId: definitionId ?? this.definitionId,
    slot: slot ?? this.slot,
    rarity: rarity ?? this.rarity,
    rolledStats: rolledStats ?? this.rolledStats,
    enhancementLevel: enhancementLevel ?? this.enhancementLevel,
    isFavorite: isFavorite ?? this.isFavorite,
  );

  /// Stat efektif setelah memperhitungkan enhancement (+5% per level pada flat stats).
  EquipmentStats get effectiveStats {
    if (enhancementLevel <= 0) return rolledStats;
    final factor = 1.0 + (enhancementLevel * 0.05);
    return EquipmentStats(
      hp: rolledStats.hp * factor,
      atk: rolledStats.atk * factor,
      def: rolledStats.def * factor,
      hpPct: rolledStats.hpPct,
      atkPct: rolledStats.atkPct,
      defPct: rolledStats.defPct,
      critRate: rolledStats.critRate,
      critDamage: rolledStats.critDamage,
      attackSpeed: rolledStats.attackSpeed,
      moveSpeed: rolledStats.moveSpeed,
      attackRange: rolledStats.attackRange,
      skillHaste: rolledStats.skillHaste,
      lifesteal: rolledStats.lifesteal,
      spellVamp: rolledStats.spellVamp,
    );
  }
}
