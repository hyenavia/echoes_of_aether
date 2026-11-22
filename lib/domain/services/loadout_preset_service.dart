import '../entities/equipment.dart';
import '../entities/inventory.dart';
import '../entities/loadout_preset.dart';
import '../entities/player_character.dart';
import 'equipment_service.dart';

/// Hasil penerapan [LoadoutPreset] ke karakter & tas pemain.
class LoadoutPresetApplyResult {
  const LoadoutPresetApplyResult({
    this.appliedSpecialization = false,
    this.specializationSkipped = false,
    this.equippedCount = 0,
    this.unequippedCount = 0,
    this.missingItemCount = 0,
    this.skippedDueToBagFull = 0,
  });

  final bool appliedSpecialization;
  final bool specializationSkipped;
  final int equippedCount;
  final int unequippedCount;
  final int missingItemCount;
  final int skippedDueToBagFull;

  bool get hasChanges =>
      appliedSpecialization || equippedCount > 0 || unequippedCount > 0;

  String buildSummaryMessage(String presetName) {
    final notes = <String>[];
    if (missingItemCount > 0) {
      notes.add('$missingItemCount item sudah tidak ada di tas');
    }
    if (specializationSkipped) {
      notes.add('class belum terbuka/level belum cukup');
    }
    if (skippedDueToBagFull > 0) {
      notes.add('$skippedDueToBagFull slot gagal dilepas karena tas penuh');
    }

    if (!hasChanges) {
      if (notes.isNotEmpty) {
        return 'Preset "$presetName" tidak mengubah build (${notes.join('; ')}).';
      }
      return 'Build sudah sesuai dengan "$presetName".';
    }

    if (notes.isNotEmpty) {
      return 'Preset "$presetName" diterapkan (${notes.join('; ')}).';
    }
    return 'Preset "$presetName" berhasil diterapkan!';
  }
}

/// Service domain murni untuk menangkap dan menerapkan preset build
/// (specialization + equipment per slot) secara deterministik.
class LoadoutPresetService {
  const LoadoutPresetService();

  /// Menangkap specialization dan seluruh equipment yang sedang dipakai [character]
  /// ke dalam [LoadoutPreset] pada [slotIndex] (`0..LoadoutPreset.maxSlots - 1`).
  LoadoutPreset captureCurrentBuild({
    required int slotIndex,
    String? name,
    required PlayerCharacter character,
  }) {
    if (slotIndex < 0 || slotIndex >= LoadoutPreset.maxSlots) {
      throw RangeError.range(
        slotIndex,
        0,
        LoadoutPreset.maxSlots - 1,
        'slotIndex',
      );
    }
    final cleanName = name?.trim();
    final resolvedName = (cleanName != null && cleanName.isNotEmpty)
        ? cleanName
        : LoadoutPreset.defaultNameForSlot(slotIndex);

    return LoadoutPreset(
      slotIndex: slotIndex,
      name: resolvedName,
      specializationId: character.specializationId,
      equipmentInstanceIds: Map<EquipmentSlot, String>.unmodifiable({
        for (final entry in character.loadout.equipped.entries)
          entry.key: entry.value.id,
      }),
    );
  }

  /// Menerapkan [preset] ke [character] dan [inventory] secara aman:
  /// - Specialization hanya diubah bila termasuk di [unlockedSpecializations] dan memenuhi syarat level.
  /// - Item yang sudah dibongkar/dijual akan dilewati tanpa error ([missingItemCount]).
  /// - Slot kosong pada preset akan melepas gear aktif jika kapasitas tas mencukupi.
  LoadoutPresetApplyResult applyPreset({
    required LoadoutPreset preset,
    required PlayerCharacter character,
    required Inventory inventory,
    required Set<String> unlockedSpecializations,
  }) {
    var appliedSpec = false;
    var skippedSpec = false;

    final targetSpec = preset.specializationId?.trim();
    if (targetSpec != null &&
        targetSpec.isNotEmpty &&
        targetSpec != character.specializationId) {
      if (unlockedSpecializations.contains(targetSpec) &&
          character.chooseSpecialization(targetSpec)) {
        appliedSpec = true;
      } else {
        skippedSpec = true;
      }
    }

    final equipmentService = EquipmentService(
      inventory: inventory,
      loadout: character.loadout,
    );

    var equippedCount = 0;
    var unequippedCount = 0;
    var missingItemCount = 0;
    var skippedDueToBagFull = 0;

    for (final slot in EquipmentSlot.values) {
      final targetId = preset.equipmentInstanceIds[slot];
      final current = character.loadout.instanceIn(slot);

      if (targetId == null) {
        if (current != null) {
          if (equipmentService.unequip(slot)) {
            unequippedCount++;
          } else {
            skippedDueToBagFull++;
          }
        }
        continue;
      }

      if (current?.id == targetId) {
        continue;
      }

      if (inventory.equipmentById(targetId) != null) {
        if (equipmentService.equip(targetId)) {
          equippedCount++;
        } else {
          missingItemCount++;
        }
      } else {
        missingItemCount++;
      }
    }

    return LoadoutPresetApplyResult(
      appliedSpecialization: appliedSpec,
      specializationSkipped: skippedSpec,
      equippedCount: equippedCount,
      unequippedCount: unequippedCount,
      missingItemCount: missingItemCount,
      skippedDueToBagFull: skippedDueToBagFull,
    );
  }

  /// Menyisipkan atau memperbarui [updated] dalam daftar preset dengan menjaga
  /// keunikan dan urutan `slotIndex` (`0..maxSlots - 1`).
  List<LoadoutPreset> upsertPreset(
    List<LoadoutPreset> existing,
    LoadoutPreset updated,
  ) {
    final bySlot = <int, LoadoutPreset>{
      for (final p in existing)
        if (p.slotIndex >= 0 && p.slotIndex < LoadoutPreset.maxSlots)
          p.slotIndex: p,
    };
    if (updated.slotIndex >= 0 && updated.slotIndex < LoadoutPreset.maxSlots) {
      bySlot[updated.slotIndex] = updated;
    }
    final sortedKeys = bySlot.keys.toList()..sort();
    return List<LoadoutPreset>.unmodifiable([
      for (final k in sortedKeys) bySlot[k]!,
    ]);
  }
}
