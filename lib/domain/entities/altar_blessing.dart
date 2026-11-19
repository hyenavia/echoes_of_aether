import 'equipment.dart';

/// Jenis berkah permanen yang disediakan oleh Camp Altar.
enum AltarBlessingType { might, vitality, aegis, fortune }

/// Definisi statis satu jenis berkah altar.
class AltarBlessingDefinition {
  const AltarBlessingDefinition({
    required this.type,
    required this.id,
    required this.name,
    required this.description,
    this.maxLevel = 20,
  });

  final AltarBlessingType type;
  final String id;
  final String name;
  final String description;
  final int maxLevel;

  static const Map<AltarBlessingType, AltarBlessingDefinition> defaults = {
    AltarBlessingType.might: AltarBlessingDefinition(
      type: AltarBlessingType.might,
      id: 'altar_might',
      name: 'Berkah Kekuatan',
      description: 'Meningkatkan ATK permanen sebesar +2 per level.',
    ),
    AltarBlessingType.vitality: AltarBlessingDefinition(
      type: AltarBlessingType.vitality,
      id: 'altar_vitality',
      name: 'Berkah Vitalitas',
      description: 'Meningkatkan Max HP permanen sebesar +20 per level.',
    ),
    AltarBlessingType.aegis: AltarBlessingDefinition(
      type: AltarBlessingType.aegis,
      id: 'altar_aegis',
      name: 'Berkah Perlindungan',
      description: 'Meningkatkan DEF permanen sebesar +2 per level.',
    ),
    AltarBlessingType.fortune: AltarBlessingDefinition(
      type: AltarBlessingType.fortune,
      id: 'altar_fortune',
      name: 'Berkah Kemakmuran',
      description:
          'Meningkatkan perolehan Gold permanen sebesar +1% per level.',
    ),
  };

  /// Biaya gold untuk naik dari [currentLevel] (0..maxLevel-1) ke level berikutnya.
  int? upgradeCost(int currentLevel) {
    if (currentLevel < 0 || currentLevel >= maxLevel) return null;
    return _costs[currentLevel + 1];
  }

  /// Menghitung bonus stat tempur pada [level] tertentu (untuk might, vitality, aegis).
  EquipmentStats statBonusAt(int level) {
    if (level <= 0) return EquipmentStats.zero;
    final lvl = level.clamp(0, maxLevel);
    switch (type) {
      case AltarBlessingType.might:
        return EquipmentStats(atk: lvl * 2.0);
      case AltarBlessingType.vitality:
        return EquipmentStats(hp: lvl * 20.0);
      case AltarBlessingType.aegis:
        return EquipmentStats(def: lvl * 2.0);
      case AltarBlessingType.fortune:
        return EquipmentStats.zero; // Fortune memberikan gold multiplier
    }
  }

  /// Bonus persentase perolehan gold pada [level] tertentu (untuk fortune: +1% per level).
  double goldBonusPercentAt(int level) {
    if (type != AltarBlessingType.fortune || level <= 0) return 0.0;
    return level.clamp(0, maxLevel) * 0.01;
  }

  /// Ringkasan efek bonus pada level tertentu.
  String describeEffectAt(int level) {
    final lvl = level.clamp(0, maxLevel);
    switch (type) {
      case AltarBlessingType.might:
        return 'ATK +${(lvl * 2.0).round()}';
      case AltarBlessingType.vitality:
        return 'HP +${(lvl * 20.0).round()}';
      case AltarBlessingType.aegis:
        return 'DEF +${(lvl * 2.0).round()}';
      case AltarBlessingType.fortune:
        return 'Gold Gain +${(lvl * 1.0).round()}%';
    }
  }

  /// Tabel biaya gold per level (1..20).
  static const Map<int, int> _costs = {
    1: 10000,
    2: 25000,
    3: 50000,
    4: 100000,
    5: 200000,
    6: 400000,
    7: 800000,
    8: 1500000,
    9: 2500000,
    10: 4000000,
    11: 6000000,
    12: 9000000,
    13: 13000000,
    14: 18000000,
    15: 25000000,
    16: 35000000,
    17: 50000000,
    18: 70000000,
    19: 95000000,
    20: 125000000,
  };
}
