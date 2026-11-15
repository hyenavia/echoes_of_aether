/// Batas maksimum akumulasi bonus stat persentase dari equipment (M13 Stage 1).
class EquipmentPctCaps {
  const EquipmentPctCaps({
    this.hpPct = 0.6,
    this.atkPct = 0.5,
    this.defPct = 0.5,
  });

  final double hpPct;
  final double atkPct;
  final double defPct;
}

/// Parameter sistem equipment dari game_config.json.
class EquipmentConfig {
  const EquipmentConfig({
    this.rollVariance = 0.15,
    this.pctCaps = const EquipmentPctCaps(),
  });

  /// Rentang acak stat equipment saat drop (0.15 = ±15% dari nilai dasar).
  final double rollVariance;

  /// Batas maksimum akumulasi total stat persentase (`hp_pct`, `atk_pct`, `def_pct`).
  final EquipmentPctCaps pctCaps;
}
