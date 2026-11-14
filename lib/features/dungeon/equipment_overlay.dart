import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/entities/item_definition.dart';
import '../../game/hud/inventory_views.dart';
import '../shared/widgets/shared_widgets.dart';
import 'equipment_text.dart';
import 'item_filter_widgets.dart';

enum _EquipmentSort { defaultOrder, rarityDesc, nameAsc }

/// Layar perlengkapan: stat akhir, equipment terpasang per slot, perbandingan
/// stat sederhana, dan tas perlengkapan dengan tombol pasang/lepas.
class EquipmentOverlay extends StatefulWidget {
  const EquipmentOverlay({
    super.key,
    required this.snapshot,
    required this.items,
    required this.onEquip,
    required this.onUnequip,
    required this.onClose,
  });

  final ValueListenable<EquipmentSnapshot> snapshot;
  final Map<String, ItemDefinition> items;
  final void Function(String instanceId) onEquip;
  final void Function(EquipmentSlot slot) onUnequip;
  final VoidCallback onClose;

  @override
  State<EquipmentOverlay> createState() => _EquipmentOverlayState();
}

class _EquipmentOverlayState extends State<EquipmentOverlay> {
  ItemCategoryFilter _categoryFilter = ItemCategoryFilter.all;
  ItemRarity? _rarityFilter;
  _EquipmentSort _sort = _EquipmentSort.defaultOrder;
  String? _selectedBagId;

  String _name(EquipmentInstance e) =>
      widget.items[e.definitionId]?.name ?? e.definitionId;

  List<EquipmentInstance> _applySort(List<EquipmentInstance> items) {
    final sorted = [...items];
    switch (_sort) {
      case _EquipmentSort.defaultOrder:
        return sorted;
      case _EquipmentSort.rarityDesc:
        sorted.sort((a, b) {
          final byRarity = b.rarity.index.compareTo(a.rarity.index);
          return byRarity != 0 ? byRarity : _name(a).compareTo(_name(b));
        });
        return sorted;
      case _EquipmentSort.nameAsc:
        sorted.sort((a, b) => _name(a).compareTo(_name(b)));
        return sorted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 600),
          child: PanelFrame(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: ValueListenableBuilder<EquipmentSnapshot>(
              valueListenable: widget.snapshot,
              builder: (context, s, _) {
                final filteredBag = _applySort([
                  for (final e in s.bag)
                    if (matchesEquipmentFilter(
                      e.slot,
                      e.rarity,
                      _categoryFilter,
                      _rarityFilter,
                    ))
                      e,
                ]);
                final selectedItem = _selectedBagId == null
                    ? null
                    : s.bag.where((e) => e.id == _selectedBagId).firstOrNull;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Perlengkapan',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close),
                          tooltip: 'Tutup',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SectionHeader(title: 'Stat Tempur'),
                            PanelFrame(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              backgroundColor: AppColors.surfaceDark,
                              child: Text(
                                describeCombatStats(s.stats),
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            const SectionHeader(title: 'Terpasang'),
                            for (final slot in EquipmentSlot.values)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: _equippedTile(
                                  context,
                                  s.equipped[slot],
                                  slot,
                                ),
                              ),
                            const SizedBox(height: AppSpacing.xs),
                            SectionHeader(
                              title: 'Tas perlengkapan (${s.bag.length})',
                            ),
                            buildItemFilterBar(
                              categories: const [
                                ItemCategoryFilter.all,
                                ItemCategoryFilter.weapon,
                                ItemCategoryFilter.armor,
                                ItemCategoryFilter.accessory,
                              ],
                              categoryFilter: _categoryFilter,
                              rarityFilter: _rarityFilter,
                              onCategoryChanged: (next) =>
                                  setState(() => _categoryFilter = next),
                              onRarityChanged: (next) =>
                                  setState(() => _rarityFilter = next),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xs,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Urut:',
                                  style: theme.textTheme.labelSmall,
                                ),
                                ChoiceChip(
                                  label: const Text('Default'),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  selected:
                                      _sort == _EquipmentSort.defaultOrder,
                                  onSelected: (_) => setState(
                                    () => _sort = _EquipmentSort.defaultOrder,
                                  ),
                                ),
                                ChoiceChip(
                                  label: const Text('Rarity'),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  selected: _sort == _EquipmentSort.rarityDesc,
                                  onSelected: (_) => setState(
                                    () => _sort = _EquipmentSort.rarityDesc,
                                  ),
                                ),
                                ChoiceChip(
                                  label: const Text('Nama'),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  selected: _sort == _EquipmentSort.nameAsc,
                                  onSelected: (_) => setState(
                                    () => _sort = _EquipmentSort.nameAsc,
                                  ),
                                ),
                              ],
                            ),
                            if (selectedItem != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              _comparisonPanel(
                                context,
                                selectedItem,
                                s.equipped[selectedItem.slot],
                              ),
                            ],
                            const SizedBox(height: AppSpacing.xs),
                            if (s.bag.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(AppSpacing.sm),
                                child: Text('Belum ada equipment.'),
                              )
                            else if (filteredBag.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(AppSpacing.sm),
                                child: Text(
                                  'Tidak ada perlengkapan yang sesuai filter.',
                                ),
                              )
                            else
                              for (final e in filteredBag)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.xs,
                                  ),
                                  child: _bagTile(context, e),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _equippedTile(
    BuildContext context,
    EquipmentInstance? e,
    EquipmentSlot slot,
  ) {
    final ext = EchoesTheme.of(context);
    final theme = Theme.of(context);
    if (e == null) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: ext.panelInnerBorder),
        ),
        child: Text(
          '${slotLabel(slot)}: Kosong',
          style: theme.textTheme.bodySmall?.copyWith(color: ext.locked),
        ),
      );
    }
    return ItemCard(
      name: _name(e),
      rarity: e.rarity,
      slot: slot,
      subtitle: slotLabel(slot),
      statsSummary: describeEquipmentStats(e.rolledStats),
      trailing: TextButton(
        onPressed: () => widget.onUnequip(slot),
        child: const Text('Lepas'),
      ),
    );
  }

  Widget _bagTile(BuildContext context, EquipmentInstance e) {
    final selected = e.id == _selectedBagId;
    return ItemCard(
      name: _name(e),
      rarity: e.rarity,
      slot: e.slot,
      subtitle: selected
          ? '${slotLabel(e.slot)} • Sedang dibandingkan'
          : '${slotLabel(e.slot)} • Ketuk untuk bandingkan',
      statsSummary: describeEquipmentStats(e.rolledStats),
      onTap: () => setState(() {
        _selectedBagId = selected ? null : e.id;
      }),
      trailing: FilledButton.tonal(
        onPressed: () => widget.onEquip(e.id),
        child: const Text('Pakai'),
      ),
    );
  }

  Widget _comparisonPanel(
    BuildContext context,
    EquipmentInstance candidate,
    EquipmentInstance? current,
  ) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    final deltas = computeEquipmentStatDeltas(
      candidate.rolledStats,
      current?.rolledStats ?? EquipmentStats.zero,
    );
    return PanelFrame(
      padding: const EdgeInsets.all(AppSpacing.sm),
      borderColor: ext.gold,
      backgroundColor: AppColors.surfaceDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Perbandingan (${slotLabel(candidate.slot)})',
                  style: theme.textTheme.labelLarge?.copyWith(color: ext.gold),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _selectedBagId = null),
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Tutup perbandingan',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          Text(
            'Terpasang: ${current == null ? 'Kosong' : _name(current)} -> Dipilih: ${_name(candidate)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          if (deltas.isEmpty)
            Text('Stat identik.', style: theme.textTheme.bodySmall)
          else
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final d in deltas)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (d.delta >= 0 ? ext.success : theme.colorScheme.error)
                              .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color:
                            (d.delta >= 0
                                    ? ext.success
                                    : theme.colorScheme.error)
                                .withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      '${d.label} ${formatStatDelta(d.delta, isPercent: d.isPercent)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: d.delta >= 0
                            ? ext.success
                            : theme.colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: PrimaryButton(
              label: 'Pakai Item Ini',
              onPressed: () => widget.onEquip(candidate.id),
            ),
          ),
        ],
      ),
    );
  }
}
