/// Parameter sistem equipment dari game_config.json.
class EquipmentConfig {
  const EquipmentConfig({this.rollVariance = 0.15});

  /// Rentang acak stat equipment saat drop (0.15 = ±15% dari nilai dasar).
  final double rollVariance;
}
