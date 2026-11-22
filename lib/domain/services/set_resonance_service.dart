import '../entities/equipment.dart';
import '../entities/equipment_loadout.dart';
import '../entities/item_definition.dart';
import '../entities/mythical_forge_config.dart';

/// Ringkasan aktivasi Set Resonance dari perlengkapan yang sedang terpasang.
class SetResonanceState {
  const SetResonanceState({
    this.equippedPiecesBySet = const {},
    this.activeTwoPieceSetIds = const {},
    this.twoPieceBonus = EquipmentStats.zero,
    this.activeFourPieceSetId,
    this.activeFourPieceClassId,
  });

  static const SetResonanceState empty = SetResonanceState();

  /// Jumlah piece terpasang per `setId`.
  final Map<String, int> equippedPiecesBySet;

  /// Daftar `setId` yang memiliki >= 2 piece terpasang (berlaku lintas class).
  final Set<String> activeTwoPieceSetIds;

  /// Akumulasi bonus stat dari seluruh set yang mencapai >= 2 piece.
  final EquipmentStats twoPieceBonus;

  /// ID set yang mencapai 4/4 piece sekaligus cocok dengan specialization aktif.
  final String? activeFourPieceSetId;

  /// ID class specialization yang memperoleh evolusi efek 4-piece, atau null.
  final String? activeFourPieceClassId;

  int piecesCountFor(String setId) => equippedPiecesBySet[setId] ?? 0;

  bool isTwoPieceActive(String setId) => activeTwoPieceSetIds.contains(setId);

  bool isFourPieceActive(String setId) => activeFourPieceSetId == setId;
}

/// Service domain murni untuk mengevaluasi Set Resonance (2-piece universal +
/// 4-piece class-locked) berdasarkan [EquipmentLoadout] dan [MythicalForgeConfig].
class SetResonanceService {
  const SetResonanceService();

  static const int twoPieceThreshold = 2;
  static const int fourPieceThreshold = 4;

  SetResonanceState evaluate({
    required EquipmentLoadout loadout,
    required Map<String, ItemDefinition> itemCatalog,
    required MythicalForgeConfig forgeConfig,
    String? specializationId,
  }) {
    if (forgeConfig.sets.isEmpty) {
      return SetResonanceState.empty;
    }

    final counts = <String, int>{};
    for (final slot in EquipmentSlot.values) {
      final instance = loadout.instanceIn(slot);
      if (instance == null) continue;
      final setId = itemCatalog[instance.definitionId]?.equipment?.setId;
      if (setId == null || !forgeConfig.sets.containsKey(setId)) continue;
      counts[setId] = (counts[setId] ?? 0) + 1;
    }

    if (counts.isEmpty) {
      return SetResonanceState.empty;
    }

    final twoPieceIds = <String>{};
    var totalTwoPieceBonus = EquipmentStats.zero;
    String? fourPieceSetId;
    String? fourPieceClassId;

    for (final entry in counts.entries) {
      final setDef = forgeConfig.sets[entry.key];
      if (setDef == null) continue;

      if (entry.value >= twoPieceThreshold) {
        twoPieceIds.add(setDef.id);
        totalTwoPieceBonus = totalTwoPieceBonus + setDef.twoPieceBonus;
      }

      if (entry.value >= fourPieceThreshold &&
          specializationId != null &&
          specializationId == setDef.signatureClassId) {
        fourPieceSetId = setDef.id;
        fourPieceClassId = setDef.signatureClassId;
      }
    }

    return SetResonanceState(
      equippedPiecesBySet: Map<String, int>.unmodifiable(counts),
      activeTwoPieceSetIds: Set<String>.unmodifiable(twoPieceIds),
      twoPieceBonus: totalTwoPieceBonus,
      activeFourPieceSetId: fourPieceSetId,
      activeFourPieceClassId: fourPieceClassId,
    );
  }
}
