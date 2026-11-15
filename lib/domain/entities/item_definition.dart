import 'equipment.dart';

/// Kategori item (GDD bagian 7).
enum ItemCategory { equipment, material, consumable, questItem }

/// Rarity item (GDD 3.4).
enum ItemRarity { common, uncommon, rare, epic, legendary }

/// Definisi statis satu jenis item (dari items.json).
/// Material dan consumable disimpan sebagai stack di `Inventory`; equipment
/// menjadi `EquipmentInstance` terpisah dengan hasil roll masing-masing.
class ItemDefinition {
  const ItemDefinition({
    required this.id,
    required this.name,
    required this.category,
    this.rarity = ItemRarity.common,
    this.maxStack = 999,
    this.sellValue = 0,
    this.sellable = true,
    this.equipment,
  });

  final String id;
  final String name;
  final ItemCategory category;
  final ItemRarity rarity;

  /// Jumlah maksimum item ini yang bisa ditumpuk di inventory.
  final int maxStack;

  /// Harga jual (gold). Dipakai saat sistem toko tersedia.
  final int sellValue;

  /// Apakah item boleh dijual ke toko reguler (`false` untuk item event M13).
  final bool sellable;

  /// Hanya terisi untuk kategori equipment.
  final EquipmentData? equipment;

  bool get isEquipment => category == ItemCategory.equipment;
}
