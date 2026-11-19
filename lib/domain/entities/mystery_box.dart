import 'dart:math' as math;

import 'item_definition.dart';

/// Tingkat peti misteri yang tersedia di Toko (Shop).
enum MysteryBoxTier { novice, warrior, aether }

/// Definisi statis satu tingkat Peti Misteri.
class MysteryBoxDefinition {
  const MysteryBoxDefinition({
    required this.tier,
    required this.name,
    required this.description,
    required this.goldCost,
    this.minLevel = 1,
    required this.rarityWeights,
  });

  final MysteryBoxTier tier;
  final String name;
  final String description;
  final int goldCost;
  final int minLevel;
  final Map<ItemRarity, int> rarityWeights;

  /// Total bobot gacha.
  int get totalWeight => rarityWeights.values.fold(0, (sum, w) => sum + w);

  /// Melakukan roll rarity secara deterministik berdasarkan [random] dan bobot.
  ItemRarity rollRarity(math.Random random) {
    final total = totalWeight;
    if (total <= 0) return ItemRarity.common;
    final roll = random.nextInt(total);
    var cumulative = 0;
    for (final entry in rarityWeights.entries) {
      cumulative += entry.value;
      if (roll < cumulative) {
        return entry.key;
      }
    }
    return rarityWeights.keys.last;
  }

  /// Ringkasan persentase peluang per rarity.
  String describeProbabilities() {
    final total = totalWeight;
    if (total <= 0) return '';
    final parts = <String>[];
    for (final entry in rarityWeights.entries) {
      final pct = (entry.value / total * 100).round();
      final label = switch (entry.key) {
        ItemRarity.common => 'Common',
        ItemRarity.uncommon => 'Uncommon',
        ItemRarity.rare => 'Rare',
        ItemRarity.epic => 'Epic',
        ItemRarity.legendary => 'Legendary',
        ItemRarity.mythical => 'Mythical',
      };
      parts.add('$label $pct%');
    }
    return parts.join(' • ');
  }

  static const Map<MysteryBoxTier, MysteryBoxDefinition> defaults = {
    MysteryBoxTier.novice: MysteryBoxDefinition(
      tier: MysteryBoxTier.novice,
      name: 'Peti Petualang',
      description:
          'Peti kayu petualang dengan peluang Common, Uncommon, dan Rare.',
      goldCost: 25000,
      minLevel: 1,
      rarityWeights: {
        ItemRarity.common: 55,
        ItemRarity.uncommon: 38,
        ItemRarity.rare: 7,
      },
    ),
    MysteryBoxTier.warrior: MysteryBoxDefinition(
      tier: MysteryBoxTier.warrior,
      name: 'Peti Prajurit Kuno',
      description:
          'Peti besi tempa prajurit dengan peluang tinggi Rare dan Epic.',
      goldCost: 100000,
      minLevel: 10,
      rarityWeights: {
        ItemRarity.uncommon: 50,
        ItemRarity.rare: 40,
        ItemRarity.epic: 10,
      },
    ),
    MysteryBoxTier.aether: MysteryBoxDefinition(
      tier: MysteryBoxTier.aether,
      name: 'Peti Aether Kerajaan',
      description: 'Peti pusaka berlapis emas kuno dengan peluang pusaka Epic dan Legendary.',
      goldCost: 500000,
      minLevel: 20,
      rarityWeights: {
        ItemRarity.rare: 55,
        ItemRarity.epic: 38,
        ItemRarity.legendary: 7,
      },
    ),
  };
}
