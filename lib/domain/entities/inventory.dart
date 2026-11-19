import 'dart:math' as math;

import 'equipment.dart';
import 'item_definition.dart';
import 'player_save_snapshot.dart';

class InventoryEntry {
  const InventoryEntry(this.definition, this.quantity);

  final ItemDefinition definition;
  final int quantity;
}

class InventoryAddResult {
  const InventoryAddResult({required this.added, required this.overflow});

  /// Jumlah yang berhasil masuk ke inventory.
  final int added;

  /// Jumlah yang tidak muat karena melewati batas stack atau kapasitas slot.
  final int overflow;
}

/// Inventory pemain (GDD bagian 7):
/// - Material, consumable, dan quest item sebagai stack (satu stack per jenis,
///   dibatasi `maxStack`).
/// - Equipment sebagai instance terpisah di "tas perlengkapan".
class Inventory {
  Inventory({
    required this._definitions,
    this.maxStackSlots,
    this.maxEquipmentCapacity,
  }) {
    if (maxStackSlots != null && maxStackSlots! < 0) {
      throw ArgumentError.value(maxStackSlots, 'maxStackSlots', 'harus >= 0');
    }
    if (maxEquipmentCapacity != null && maxEquipmentCapacity! < 0) {
      throw ArgumentError.value(
        maxEquipmentCapacity,
        'maxEquipmentCapacity',
        'harus >= 0',
      );
    }
  }

  final Map<String, ItemDefinition> _definitions;
  final int? maxStackSlots;

  /// Kapasitas maksimum tas perlengkapan, dapat diperluas secara dinamis melalui upgrade.
  int? maxEquipmentCapacity;

  final Map<String, int> _quantities = {};
  final Map<String, EquipmentInstance> _equipment = {};
  int _equipmentCounter = 0;

  ItemDefinition? definitionOf(String itemId) => _definitions[itemId];

  // ---- Stack ----

  int quantityOf(String itemId) => _quantities[itemId] ?? 0;

  int get stackSlotCount => _quantities.length;

  /// Menambah item bertumpuk. Jumlah melebihi `maxStack` atau kapasitas slot
  /// ditolak dan dilaporkan sebagai overflow (tidak ada yang hilang diam-diam).
  InventoryAddResult add(String itemId, int quantity) {
    final definition = _definitions[itemId];
    if (definition == null) {
      throw ArgumentError('Item tidak dikenal: "$itemId".');
    }
    if (definition.isEquipment) {
      throw ArgumentError(
        'Item "$itemId" adalah equipment; gunakan addEquipment().',
      );
    }
    if (quantity <= 0) {
      return const InventoryAddResult(added: 0, overflow: 0);
    }
    if (!_quantities.containsKey(itemId) &&
        maxStackSlots != null &&
        _quantities.length >= maxStackSlots!) {
      return InventoryAddResult(added: 0, overflow: quantity);
    }
    final space = math.max<int>(0, definition.maxStack - quantityOf(itemId));
    final added = math.min<int>(quantity, space);
    if (added > 0) _quantities[itemId] = quantityOf(itemId) + added;
    return InventoryAddResult(added: added, overflow: quantity - added);
  }

  /// Mengurangi item. Mengembalikan false (tanpa perubahan) jika jumlahnya
  /// negatif atau tidak mencukupi stok saat ini.
  bool remove(String itemId, int quantity) {
    if (quantity < 0) return false;
    if (quantity == 0) return true;
    final current = quantityOf(itemId);
    if (current < quantity) return false;
    if (current == quantity) {
      _quantities.remove(itemId);
    } else {
      _quantities[itemId] = current - quantity;
    }
    return true;
  }

  /// Daftar stack, diurutkan berdasarkan id item agar urutannya stabil.
  List<InventoryEntry> snapshot() {
    final ids = _quantities.keys.toList()..sort();
    return [
      for (final id in ids) InventoryEntry(_definitions[id]!, _quantities[id]!),
    ];
  }

  // ---- Equipment ----

  int get equipmentCount => _equipment.length;

  bool get hasEquipmentSpace =>
      maxEquipmentCapacity == null || _equipment.length < maxEquipmentCapacity!;

  EquipmentInstance? equipmentById(String instanceId) => _equipment[instanceId];

  /// Id unik untuk instance equipment baru.
  String nextEquipmentId() => 'eq_${++_equipmentCounter}';

  /// Menambahkan instance equipment ke tas perlengkapan. Mengembalikan false
  /// jika kapasitas tas penuh atau id instance sudah ada di tas.
  bool addEquipment(EquipmentInstance instance) {
    final definition = _definitions[instance.definitionId];
    if (definition == null || !definition.isEquipment) {
      throw ArgumentError(
        'Definisi equipment tidak valid atau tidak dikenal: '
        '"${instance.definitionId}".',
      );
    }
    if (!hasEquipmentSpace || _equipment.containsKey(instance.id)) {
      return false;
    }
    _equipment[instance.id] = instance;
    return true;
  }

  /// Mengambil (menghapus) equipment dari tas; null jika id tidak ada.
  EquipmentInstance? takeEquipment(String instanceId) =>
      _equipment.remove(instanceId);

  /// Memperbarui instance equipment yang sudah ada di inventory.
  /// Mengembalikan `false` jika instance id tidak ditemukan di inventory.
  bool updateEquipment(EquipmentInstance updated) {
    if (!_equipment.containsKey(updated.id)) {
      return false;
    }
    _equipment[updated.id] = updated;
    return true;
  }

  /// Menghapus equipment berdasarkan id; mengembalikan false jika tidak ditemukan.
  bool removeEquipment(String instanceId) =>
      _equipment.remove(instanceId) != null;

  /// Equipment di tas, sesuai urutan masuk.
  List<EquipmentInstance> equipmentSnapshot() =>
      List.unmodifiable(_equipment.values);

  // ---- Snapshot Persistence ----

  InventorySnapshot toSnapshot() => InventorySnapshot(
    stacks: Map<String, int>.unmodifiable(_quantities),
    equipment: List<EquipmentInstance>.unmodifiable(_equipment.values),
    equipmentCounter: _equipmentCounter,
  );

  /// Memulihkan state inventory dari snapshot yang tersimpan (Phase F).
  void restore(InventorySnapshot saved) {
    _quantities.clear();
    _equipment.clear();
    var restoredCounter = math.max<int>(0, saved.equipmentCounter);

    for (final entry in saved.stacks.entries) {
      final def = _definitions[entry.key];
      if (def == null || def.isEquipment || entry.value <= 0) continue;
      if (maxStackSlots != null && _quantities.length >= maxStackSlots!) break;
      _quantities[entry.key] = math.min<int>(entry.value, def.maxStack);
    }

    for (final item in saved.equipment) {
      final def = _definitions[item.definitionId];
      if (def == null || !def.isEquipment) continue;
      if (maxEquipmentCapacity != null &&
          _equipment.length >= maxEquipmentCapacity!) {
        break;
      }
      _equipment[item.id] = item;
      if (item.id.startsWith('eq_')) {
        final parsed = int.tryParse(item.id.substring(3));
        if (parsed != null && parsed > restoredCounter) {
          restoredCounter = parsed;
        }
      }
    }

    _equipmentCounter = restoredCounter;
  }
}
