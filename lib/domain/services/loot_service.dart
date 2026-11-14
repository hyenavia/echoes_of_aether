import 'dart:math' as math;

import '../entities/item_definition.dart';
import '../entities/loot_table.dart';

/// Menentukan drop dari loot table (GDD bagian 7). Keacakan berasal dari
/// [math.Random] yang disuntikkan, sehingga hasilnya bisa direproduksi dan
/// dipakai ulang oleh offline simulation.
class LootService {
  const LootService();

  List<LootDrop> roll(
    LootTable table,
    math.Random random, {
    Map<String, ItemDefinition>? items,
    double rareDropChanceMultiplier = 1.0,
  }) {
    final safeRareMultiplier =
        rareDropChanceMultiplier.isFinite && rareDropChanceMultiplier > 1.0
        ? rareDropChanceMultiplier
        : 1.0;

    final drops = <LootDrop>[];
    for (final entry in table.entries) {
      var chance = entry.chance;
      if (safeRareMultiplier > 1.0 && items != null) {
        final item = items[entry.itemId];
        if (item != null && item.rarity.index >= ItemRarity.rare.index) {
          chance = (entry.chance * safeRareMultiplier).clamp(0.0, 1.0);
        }
      }
      if (random.nextDouble() >= chance) continue;
      final range = entry.maxQuantity - entry.minQuantity;
      final quantity =
          entry.minQuantity + (range > 0 ? random.nextInt(range + 1) : 0);
      drops.add(LootDrop(entry.itemId, quantity));
    }
    return drops;
  }
}
