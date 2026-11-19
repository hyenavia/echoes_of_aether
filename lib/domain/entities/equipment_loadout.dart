import 'equipment.dart';

/// Equipment yang sedang dipakai (satu instance per slot).
class EquipmentLoadout {
  EquipmentLoadout([Map<EquipmentSlot, EquipmentInstance>? initial]) {
    if (initial != null) {
      for (final entry in initial.entries) {
        if (entry.value.slot != entry.key) {
          throw ArgumentError(
            'Slot loadout ${entry.key.name} tidak cocok dengan equipment '
            '"${entry.value.id}" (${entry.value.slot.name}).',
          );
        }
        _equipped[entry.key] = entry.value;
      }
    }
  }

  final Map<EquipmentSlot, EquipmentInstance> _equipped = {};

  /// Bertambah setiap kali isi loadout berubah, sehingga pihak lain bisa
  /// mendeteksi perubahan stat tanpa membandingkan seluruh isi.
  int revision = 0;

  Map<EquipmentSlot, EquipmentInstance> get equipped =>
      Map.unmodifiable(_equipped);

  EquipmentInstance? instanceIn(EquipmentSlot slot) => _equipped[slot];

  /// Memasang [instance] pada slot-nya dan mengembalikan instance
  /// sebelumnya di slot itu (jika ada).
  EquipmentInstance? equip(EquipmentInstance instance) {
    final previous = _equipped[instance.slot];
    _equipped[instance.slot] = instance;
    revision++;
    return previous;
  }

  EquipmentInstance? unequip(EquipmentSlot slot) {
    final removed = _equipped.remove(slot);
    if (removed != null) revision++;
    return removed;
  }

  /// Memperbarui instance equipment yang sedang dipakai di loadout (misalnya status favorit).
  /// Mengembalikan `true` jika instance ditemukan dan diperbarui.
  bool updateEquipment(EquipmentInstance updated) {
    if (_equipped[updated.slot]?.id == updated.id) {
      _equipped[updated.slot] = updated;
      revision++;
      return true;
    }
    return false;
  }

  /// Memulihkan isi loadout dari data save (mengganti seluruh slot saat ini).
  void restore(Map<EquipmentSlot, EquipmentInstance> saved) {
    for (final entry in saved.entries) {
      if (entry.value.slot != entry.key) {
        throw ArgumentError(
          'Slot loadout ${entry.key.name} tidak cocok dengan equipment '
          '"${entry.value.id}" (${entry.value.slot.name}).',
        );
      }
    }
    _equipped
      ..clear()
      ..addAll(saved);
    revision++;
  }

  /// Jumlah bonus stat dari semua equipment yang terpasang (termasuk enhancement).
  EquipmentStats get totalBonus {
    var total = EquipmentStats.zero;
    for (final slot in EquipmentSlot.values) {
      final item = _equipped[slot];
      if (item != null) total = total + item.effectiveStats;
    }
    return total;
  }
}
