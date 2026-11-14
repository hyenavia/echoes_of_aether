/// Satu baris pada loot table: peluang menjatuhkan item dalam rentang jumlah.
class LootEntry {
  const LootEntry({
    required this.itemId,
    required this.chance,
    this.minQuantity = 1,
    this.maxQuantity = 1,
  });

  final String itemId;

  /// Peluang drop, lebih dari 0 dan paling besar 1.0.
  final double chance;
  final int minQuantity;
  final int maxQuantity;
}

/// Loot table yang dapat dikonfigurasi (loot_tables.json).
class LootTable {
  const LootTable({required this.id, required this.entries});

  final String id;
  final List<LootEntry> entries;
}

/// Hasil satu kali roll loot.
class LootDrop {
  const LootDrop(this.itemId, this.quantity);

  final String itemId;
  final int quantity;
}
