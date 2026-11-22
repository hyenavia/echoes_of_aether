import 'dart:math' as math;

import '../entities/equipment.dart';
import '../entities/equipment_config.dart';
import '../entities/item_definition.dart';

/// Membuat [EquipmentInstance] dari definisi dengan stat yang di-roll.
/// Keacakan disuntikkan agar hasilnya bisa direproduksi.
class EquipmentFactory {
  const EquipmentFactory(this.config);

  final EquipmentConfig config;

  EquipmentInstance create({
    required String instanceId,
    required ItemDefinition definition,
    required math.Random random,
    double rollBonus = 0.0,
  }) {
    final data = definition.equipment;
    if (data == null) {
      throw ArgumentError('Item "${definition.id}" bukan equipment.');
    }
    return EquipmentInstance(
      id: instanceId,
      definitionId: definition.id,
      slot: data.slot,
      rarity: definition.rarity,
      rolledStats: data.fixedStats
          ? data.baseStats
          : data.baseStats.roll(
              random,
              config.rollVariance,
              rollBonus: rollBonus,
            ),
      isFavorite:
          definition.rarity == ItemRarity.legendary ||
          definition.rarity == ItemRarity.mythical,
    );
  }
}
