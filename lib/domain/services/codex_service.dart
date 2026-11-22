import '../entities/dungeon_definition.dart';
import '../entities/game_config.dart';
import '../entities/item_definition.dart';
import 'weapon_resonance_service.dart';

/// Entri Codex untuk sinergi Signature Weapon Resonance per class.
class CodexResonanceEntry {
  const CodexResonanceEntry({
    required this.specializationId,
    required this.specializationName,
    required this.specializationRarity,
    required this.signatureWeaponId,
    required this.signatureWeaponName,
    required this.resonanceDescription,
    required this.isUnlocked,
    this.setId,
    this.setName,
    this.twoPieceDescription,
    this.fourPieceDescription,
  });

  final String specializationId;
  final String specializationName;
  final ItemRarity specializationRarity;
  final String signatureWeaponId;
  final String signatureWeaponName;
  final String resonanceDescription;
  final bool isUnlocked;
  final String? setId;
  final String? setName;
  final String? twoPieceDescription;
  final String? fourPieceDescription;
}

/// Sumber drop atau perolehan untuk satu material di Codex.
class CodexDropSource {
  const CodexDropSource({
    required this.sourceLabel,
    required this.chance,
    this.isBossOrClear = false,
  });

  final String sourceLabel;
  final double chance;
  final bool isBossOrClear;
}

/// Entri Codex untuk material Ascension & material penting yang drop di dungeon.
class CodexMaterialEntry {
  const CodexMaterialEntry({
    required this.itemId,
    required this.itemName,
    required this.rarity,
    required this.usedInAscensionPhases,
    required this.dropSources,
    this.ownedQuantity = 0,
  });

  final String itemId;
  final String itemName;
  final ItemRarity rarity;
  final List<int> usedInAscensionPhases;
  final List<CodexDropSource> dropSources;
  final int ownedQuantity;

  bool get isAscensionMaterial => usedInAscensionPhases.isNotEmpty;
}

class _LootSourceTag {
  const _LootSourceTag({required this.label, required this.isBossOrClear});

  final String label;
  final bool isBossOrClear;
}

/// Service domain murni untuk menyusun data Codex / Galeri Panduan
/// (daftar Signature Weapon Resonance dan sumber drop material) langsung dari [GameConfig].
class CodexService {
  const CodexService();

  static const String _salvageScrapId = 'aether_scrap';

  /// Menyusun daftar seluruh Signature Weapon Resonance yang terdaftar di [config].
  List<CodexResonanceEntry> buildResonanceEntries({
    required GameConfig config,
    Set<String> unlockedSpecializations = const {},
  }) {
    const resonanceService = WeaponResonanceService();
    final weaponByClassId = <String, ItemDefinition>{};
    for (final item in config.items.values) {
      final sigClass = item.equipment?.signatureClassId;
      if (sigClass != null && sigClass.trim().isNotEmpty) {
        weaponByClassId.putIfAbsent(sigClass, () => item);
      }
    }

    final specs = config.specializations.definitions.values.toList()
      ..sort((a, b) {
        final rarityCmp = b.rarity.index.compareTo(a.rarity.index);
        return rarityCmp != 0 ? rarityCmp : a.name.compareTo(b.name);
      });

    final entries = <CodexResonanceEntry>[];
    for (final spec in specs) {
      final explicitWeaponId = spec.signatureWeaponId;
      final weapon =
          (explicitWeaponId != null ? config.items[explicitWeaponId] : null) ??
          weaponByClassId[spec.id];
      if (weapon == null) continue;

      final eqDesc = weapon.equipment?.resonanceDescription?.trim();
      final resolvedDesc = (eqDesc != null && eqDesc.isNotEmpty)
          ? eqDesc
          : (resonanceService.getResonanceDescription(spec.id) ?? '');
      final weaponSetId = weapon.equipment?.setId;
      final setDef = weaponSetId != null
          ? config.mythicalForge.sets[weaponSetId]
          : config.mythicalForge.sets.values
                .where((s) => s.signatureClassId == spec.id)
                .firstOrNull;

      entries.add(
        CodexResonanceEntry(
          specializationId: spec.id,
          specializationName: spec.name,
          specializationRarity: spec.rarity,
          signatureWeaponId: weapon.id,
          signatureWeaponName: weapon.name,
          resonanceDescription: resolvedDesc,
          isUnlocked: unlockedSpecializations.contains(spec.id),
          setId: setDef?.id,
          setName: setDef?.name,
          twoPieceDescription: setDef?.twoPieceDescription,
          fourPieceDescription: setDef?.fourPieceDescription,
        ),
      );
    }
    return List<CodexResonanceEntry>.unmodifiable(entries);
  }

  /// Menyusun daftar material Ascension beserta material droppable lain dan
  /// seluruh sumber drop terdeteksi di [config].
  List<CodexMaterialEntry> buildMaterialEntries({
    required GameConfig config,
    Map<String, int> ownedQuantities = const {},
  }) {
    final ascensionPhasesByItem = <String, Set<int>>{};
    for (final phase in config.heroAscension.phases) {
      for (final itemId in phase.cost.items.keys) {
        ascensionPhasesByItem
            .putIfAbsent(itemId, () => <int>{})
            .add(phase.phase);
      }
    }

    final lootSourcesByTableId = _indexLootTableSources(config);

    // Kumpulkan semua material yang muncul di Ascension cost atau loot tables.
    final droppableMaterialIds = <String>{};
    for (final table in config.lootTables.values) {
      for (final entry in table.entries) {
        final def = config.items[entry.itemId];
        if (def != null && def.category == ItemCategory.material) {
          droppableMaterialIds.add(def.id);
        }
      }
    }

    final targetIds = <String>{
      ...ascensionPhasesByItem.keys,
      ...droppableMaterialIds,
    };

    final entries = <CodexMaterialEntry>[];
    for (final itemId in targetIds) {
      final def = config.items[itemId];
      if (def == null) continue;

      final sourceMap = <String, CodexDropSource>{};
      for (final table in config.lootTables.values) {
        for (final lootEntry in table.entries) {
          if (lootEntry.itemId != itemId) continue;
          final tags = lootSourcesByTableId[table.id] ?? const [];
          for (final tag in tags) {
            final existing = sourceMap[tag.label];
            if (existing == null || lootEntry.chance > existing.chance) {
              sourceMap[tag.label] = CodexDropSource(
                sourceLabel: tag.label,
                chance: lootEntry.chance,
                isBossOrClear: tag.isBossOrClear,
              );
            }
          }
        }
      }

      if (config.infiniteSpire != null) {
        final spireFloors = <int>[
          for (final floor in config.infiniteSpire!.floors)
            if ((floor.reward.items[itemId] ?? 0) > 0) floor.floor,
        ];
        if (spireFloors.isNotEmpty) {
          spireFloors.sort();
          final rangeLabel = spireFloors.length == 1
              ? 'Infinite Spire (Lt ${spireFloors.first})'
              : 'Infinite Spire (${spireFloors.length} lantai)';
          sourceMap[rangeLabel] = CodexDropSource(
            sourceLabel: rangeLabel,
            chance: 1.0,
            isBossOrClear: true,
          );
        }
      }

      if (itemId == _salvageScrapId && sourceMap.isEmpty) {
        sourceMap['Blacksmith (Bongkar / Salvage Gear)'] =
            const CodexDropSource(
              sourceLabel: 'Blacksmith (Bongkar / Salvage Gear)',
              chance: 1.0,
            );
      }

      final sortedSources = sourceMap.values.toList()
        ..sort((a, b) {
          final bossCmp = (b.isBossOrClear ? 1 : 0).compareTo(
            a.isBossOrClear ? 1 : 0,
          );
          if (bossCmp != 0) return bossCmp;
          final chanceCmp = b.chance.compareTo(a.chance);
          return chanceCmp != 0
              ? chanceCmp
              : a.sourceLabel.compareTo(b.sourceLabel);
        });

      final phases = (ascensionPhasesByItem[itemId]?.toList() ?? <int>[])
        ..sort();

      entries.add(
        CodexMaterialEntry(
          itemId: def.id,
          itemName: def.name,
          rarity: def.rarity,
          usedInAscensionPhases: List<int>.unmodifiable(phases),
          dropSources: List<CodexDropSource>.unmodifiable(sortedSources),
          ownedQuantity: ownedQuantities[def.id] ?? 0,
        ),
      );
    }

    entries.sort((a, b) {
      final ascCmp = (b.isAscensionMaterial ? 1 : 0).compareTo(
        a.isAscensionMaterial ? 1 : 0,
      );
      if (ascCmp != 0) return ascCmp;
      final rarityCmp = b.rarity.index.compareTo(a.rarity.index);
      return rarityCmp != 0 ? rarityCmp : a.itemName.compareTo(b.itemName);
    });

    return List<CodexMaterialEntry>.unmodifiable(entries);
  }

  Map<String, List<_LootSourceTag>> _indexLootTableSources(GameConfig config) {
    final result = <String, List<_LootSourceTag>>{};
    final dungeons = config.dungeons.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    for (final dungeon in dungeons) {
      final clearLootId = dungeon.completionReward?.lootTableId;
      if (clearLootId != null && clearLootId.isNotEmpty) {
        result
            .putIfAbsent(clearLootId, () => [])
            .add(
              _LootSourceTag(
                label: '${dungeon.name} (Clear)',
                isBossOrClear: true,
              ),
            );
      }

      for (final room in dungeon.rooms.values) {
        final roomLootId = room.reward?.lootTableId;
        if (roomLootId != null && roomLootId.isNotEmpty) {
          result
              .putIfAbsent(roomLootId, () => [])
              .add(
                _LootSourceTag(
                  label: '${dungeon.name} — ${room.name}',
                  isBossOrClear: room.type == RoomType.boss,
                ),
              );
        }

        for (final spawn in room.spawns) {
          final monster = config.monsters[spawn.monsterId];
          final mLootId = monster?.lootTableId;
          if (monster != null && mLootId != null && mLootId.isNotEmpty) {
            final tierTag = monster.isBoss
                ? ' (Boss)'
                : (monster.isElite ? ' (Elite)' : '');
            result
                .putIfAbsent(mLootId, () => [])
                .add(
                  _LootSourceTag(
                    label: '${monster.name}$tierTag — ${dungeon.name}',
                    isBossOrClear: monster.isBoss,
                  ),
                );
          }
        }
      }
    }

    // Fallback untuk monster (misal boss event/spire) yang lootTableId-nya
    // belum tercakup oleh dungeon reguler.
    for (final monster in config.monsters.values) {
      final mLootId = monster.lootTableId;
      if (mLootId == null || mLootId.isEmpty) continue;
      if (result.containsKey(mLootId)) continue;
      final tierTag = monster.isBoss
          ? ' (Boss)'
          : (monster.isElite ? ' (Elite)' : '');
      result
          .putIfAbsent(mLootId, () => [])
          .add(
            _LootSourceTag(
              label: '${monster.name}$tierTag',
              isBossOrClear: monster.isBoss,
            ),
          );
    }

    return result;
  }
}
