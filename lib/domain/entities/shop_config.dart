import 'item_definition.dart';

/// Syarat pembelian item di Shop (M10 Stage 1).
sealed class PurchaseRequirement {
  const PurchaseRequirement();
}

/// Mensyaratkan level karakter minimal [minLevel].
final class MinLevelRequirement extends PurchaseRequirement {
  const MinLevelRequirement(this.minLevel);

  final int minLevel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MinLevelRequirement && other.minLevel == minLevel;

  @override
  int get hashCode => minLevel.hashCode;
}

/// Mensyaratkan [dungeonId] pernah diselesaikan seumur hidup (`clearsCount > 0`).
final class DungeonClearedRequirement extends PurchaseRequirement {
  const DungeonClearedRequirement(this.dungeonId);

  final String dungeonId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DungeonClearedRequirement && other.dungeonId == dungeonId;

  @override
  int get hashCode => dungeonId.hashCode;
}

/// Mensyaratkan Ascension Rank minimal [minRank].
final class MinAscensionRankRequirement extends PurchaseRequirement {
  const MinAscensionRankRequirement(this.minRank);

  final int minRank;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MinAscensionRankRequirement && other.minRank == minRank;

  @override
  int get hashCode => minRank.hashCode;
}

/// Satu entri barang yang dijual di Shop.
class ShopEntry {
  const ShopEntry({
    required this.id,
    required this.itemId,
    required this.price,
    this.purchaseLimit,
    this.requirements = const [],
  });

  final String id;
  final String itemId;
  final int price;
  final int? purchaseLimit;
  final List<PurchaseRequirement> requirements;
}

/// Aturan penjualan item ke Shop.
class SellRules {
  const SellRules({
    this.sellableCategories = const {ItemCategory.equipment},
    this.confirmMinRarity = ItemRarity.rare,
    this.equippedSellable = false,
    this.maxSellRatio = 0.4,
  });

  final Set<ItemCategory> sellableCategories;
  final ItemRarity confirmMinRarity;
  final bool equippedSellable;
  final double maxSellRatio;
}

/// Katalog statis Shop & aturan jual-beli (M10 Stage 1).
class ShopCatalog {
  ShopCatalog({
    List<ShopEntry> entries = const [],
    this.sell = const SellRules(),
  }) : entries = List<ShopEntry>.unmodifiable(entries),
       _byId = {for (final entry in entries) entry.id: entry};

  const ShopCatalog.empty({this.sell = const SellRules()})
    : entries = const [],
      _byId = const {};

  final List<ShopEntry> entries;
  final SellRules sell;
  final Map<String, ShopEntry> _byId;

  ShopEntry? byId(String entryId) => _byId[entryId];
}
