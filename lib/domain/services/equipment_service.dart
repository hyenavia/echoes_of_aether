import '../entities/equipment.dart';
import '../entities/equipment_loadout.dart';
import '../entities/inventory.dart';

/// Memasang dan melepas equipment antara tas perlengkapan dan loadout.
class EquipmentService {
  EquipmentService({required this.inventory, required this.loadout});

  final Inventory inventory;
  final EquipmentLoadout loadout;

  /// Memasang equipment dari tas. Equipment lama di slot yang sama
  /// dikembalikan ke tas. Mengembalikan false jika id tidak ada di tas atau
  /// definisi/slot item tidak valid.
  bool equip(String instanceId) {
    final candidate = inventory.equipmentById(instanceId);
    if (candidate == null) return false;
    final definition = inventory.definitionOf(candidate.definitionId);
    if (definition == null ||
        !definition.isEquipment ||
        definition.equipment?.slot != candidate.slot) {
      return false;
    }

    final instance = inventory.takeEquipment(instanceId);
    if (instance == null) return false;
    final previous = loadout.equip(instance);
    if (previous != null) inventory.addEquipment(previous);
    return true;
  }

  /// Melepas equipment dari [slot] ke tas. Mengembalikan false jika slot
  /// kosong atau kapasitas tas perlengkapan sudah penuh.
  bool unequip(EquipmentSlot slot) {
    if (loadout.instanceIn(slot) == null) return false;
    if (!inventory.hasEquipmentSpace) return false;
    final removed = loadout.unequip(slot);
    if (removed == null) return false;
    inventory.addEquipment(removed);
    return true;
  }

  /// Mengubah status favorit (favorite / unfavorite) pada equipment di tas atau loadout.
  /// Mengembalikan `true` jika status berhasil diubah.
  bool toggleFavorite(String instanceId) {
    final inBag = inventory.equipmentById(instanceId);
    if (inBag != null) {
      final updated = inBag.copyWith(isFavorite: !inBag.isFavorite);
      return inventory.updateEquipment(updated);
    }
    for (final entry in loadout.equipped.entries) {
      if (entry.value.id == instanceId) {
        final updated = entry.value.copyWith(
          isFavorite: !entry.value.isFavorite,
        );
        return loadout.updateEquipment(updated);
      }
    }
    return false;
  }
}
