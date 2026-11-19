import '../entities/equipment.dart';
import '../entities/equipment_loadout.dart';
import '../entities/game_config.dart';
import '../entities/inventory.dart';
import '../entities/item_definition.dart';
import 'blacksmith_service.dart';

/// Hasil pembersihan equipment otomatis setelah sesi AFK/offline.
class OfflineEquipmentCleanupResult {
  const OfflineEquipmentCleanupResult({
    this.salvagedCount = 0,
    this.scrapGained = 0,
    this.keptCount = 0,
  });

  final int salvagedCount;
  final int scrapGained;
  final int keptCount;
}

/// Menyaring equipment Rare/Epic/Legendary setelah kembali dari mode AFK:
/// tiap kategori ([EquipmentSlot]) dinilai terpisah berdasarkan Combat Power /
/// kualitas sub-stat, menyisakan [keepTopPerSlot] item terbaik dan membongkar
/// sisanya menjadi `aether_scrap` via [BlacksmithService].
class OfflineEquipmentCleanupService {
  const OfflineEquipmentCleanupService({
    this.keepTopPerSlot = 3,
    this.targetRarities = const {
      ItemRarity.rare,
      ItemRarity.epic,
      ItemRarity.legendary,
    },
  });

  final int keepTopPerSlot;
  final Set<ItemRarity> targetRarities;

  /// Menghitung skor kualitas / Combat Power sebuah equipment dari stat efektifnya.
  static double scoreEquipment(EquipmentInstance item) {
    final s = item.effectiveStats;
    return (s.hp * 0.25) +
        (s.atk * 2.0) +
        (s.def * 1.5) +
        (s.hpPct * 120.0) +
        (s.atkPct * 200.0) +
        (s.defPct * 150.0) +
        (s.critRate * 250.0) +
        (s.critDamage * 120.0) +
        (s.attackSpeed * 180.0) +
        (s.skillHaste * 160.0) +
        (s.lifesteal * 200.0) +
        (s.spellVamp * 200.0) +
        (s.moveSpeed * 40.0) +
        (s.attackRange * 35.0);
  }

  /// Menyaring & membongkar kelebihan equipment per kategori [EquipmentSlot].
  /// Item yang sedang dipakai di [loadout], berstatus `isFavorite`, atau
  /// ber-rarity di luar [targetRarities] (mis. `mythical`) tidak tersentuh.
  OfflineEquipmentCleanupResult cleanupAfterOffline({
    required Inventory inventory,
    required EquipmentLoadout loadout,
    required GameConfig config,
  }) {
    final equippedIds = {for (final eq in loadout.equipped.values) eq.id};
    final bySlot = <EquipmentSlot, List<EquipmentInstance>>{};

    for (final item in inventory.equipmentSnapshot()) {
      if (equippedIds.contains(item.id)) continue;
      if (item.isFavorite) continue;
      if (!targetRarities.contains(item.rarity)) continue;
      bySlot.putIfAbsent(item.slot, () => []).add(item);
    }

    if (bySlot.isEmpty) {
      return const OfflineEquipmentCleanupResult();
    }

    final blacksmith = BlacksmithService(equipmentConfig: config.equipment);
    var salvagedCount = 0;
    var scrapGained = 0;
    var keptCount = 0;

    for (final items in bySlot.values) {
      items.sort((a, b) {
        final scoreCmp = scoreEquipment(b).compareTo(scoreEquipment(a));
        if (scoreCmp != 0) return scoreCmp;
        final rarityCmp = b.rarity.index.compareTo(a.rarity.index);
        if (rarityCmp != 0) return rarityCmp;
        final enhCmp = b.enhancementLevel.compareTo(a.enhancementLevel);
        if (enhCmp != 0) return enhCmp;
        return a.id.compareTo(b.id);
      });

      final keepLimit = keepTopPerSlot < 0 ? 0 : keepTopPerSlot;
      if (items.length <= keepLimit) {
        keptCount += items.length;
        continue;
      }

      keptCount += keepLimit;
      for (var i = keepLimit; i < items.length; i++) {
        final result = blacksmith.salvageEquipment(
          inventory: inventory,
          instanceId: items[i].id,
          loadout: loadout,
        );
        if (result.isSuccess) {
          salvagedCount++;
          scrapGained += result.aetherScrapGained;
        } else if (result.status == BlacksmithSalvageStatus.inventoryFull) {
          break;
        }
      }
    }

    return OfflineEquipmentCleanupResult(
      salvagedCount: salvagedCount,
      scrapGained: scrapGained,
      keptCount: keptCount,
    );
  }
}
