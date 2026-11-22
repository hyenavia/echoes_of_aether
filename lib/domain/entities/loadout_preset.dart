import 'package:flutter/foundation.dart' show mapEquals;

import 'equipment.dart';

/// Preset kombinasi specialization dan perlengkapan per slot milik pemain.
/// Hanya menyimpan ID instance perlengkapan (bukan salinan item atau derived stats).
class LoadoutPreset {
  const LoadoutPreset({
    required this.slotIndex,
    required this.name,
    this.specializationId,
    this.equipmentInstanceIds = const {},
  });

  static const int maxSlots = 3;

  static String defaultNameForSlot(int slotIndex) => 'Preset ${slotIndex + 1}';

  final int slotIndex;
  final String name;
  final String? specializationId;
  final Map<EquipmentSlot, String> equipmentInstanceIds;

  bool get isEmpty =>
      (specializationId == null || specializationId!.trim().isEmpty) &&
      equipmentInstanceIds.isEmpty;

  LoadoutPreset copyWith({
    int? slotIndex,
    String? name,
    String? specializationId,
    bool clearSpecializationId = false,
    Map<EquipmentSlot, String>? equipmentInstanceIds,
  }) {
    return LoadoutPreset(
      slotIndex: slotIndex ?? this.slotIndex,
      name: name ?? this.name,
      specializationId: clearSpecializationId
          ? null
          : (specializationId ?? this.specializationId),
      equipmentInstanceIds: equipmentInstanceIds ?? this.equipmentInstanceIds,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LoadoutPreset &&
        other.slotIndex == slotIndex &&
        other.name == name &&
        other.specializationId == specializationId &&
        mapEquals(other.equipmentInstanceIds, equipmentInstanceIds);
  }

  @override
  int get hashCode => Object.hash(
    slotIndex,
    name,
    specializationId,
    Object.hashAllUnordered([
      for (final e in equipmentInstanceIds.entries) Object.hash(e.key, e.value),
    ]),
  );
}
