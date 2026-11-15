import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../../domain/entities/inventory.dart';
import '../../domain/entities/item_definition.dart';
import '../shared/widgets/shared_widgets.dart';
import 'item_filter_widgets.dart';

enum _InventorySort { defaultOrder, rarityDesc, nameAsc }

/// Daftar isi inventory (stack material dan consumable).
class InventoryOverlay extends StatefulWidget {
  const InventoryOverlay({
    super.key,
    required this.entries,
    required this.onClose,
  });

  final ValueListenable<List<InventoryEntry>> entries;
  final VoidCallback onClose;

  @override
  State<InventoryOverlay> createState() => _InventoryOverlayState();
}

class _InventoryOverlayState extends State<InventoryOverlay> {
  ItemCategoryFilter _categoryFilter = ItemCategoryFilter.all;
  ItemRarity? _rarityFilter;
  _InventorySort _sort = _InventorySort.defaultOrder;

  List<InventoryEntry> _applySort(List<InventoryEntry> items) {
    final sorted = [...items];
    switch (_sort) {
      case _InventorySort.defaultOrder:
        return sorted;
      case _InventorySort.rarityDesc:
        sorted.sort((a, b) {
          final byRarity = b.definition.rarity.index.compareTo(
            a.definition.rarity.index,
          );
          return byRarity != 0
              ? byRarity
              : a.definition.name.compareTo(b.definition.name);
        });
        return sorted;
      case _InventorySort.nameAsc:
        sorted.sort((a, b) => a.definition.name.compareTo(b.definition.name));
        return sorted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 520),
          child: PanelFrame(
            showCornerOrnaments: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm + 2,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: ValueListenableBuilder<List<InventoryEntry>>(
              valueListenable: widget.entries,
              builder: (context, list, _) {
                final filtered = _applySort([
                  for (final e in list)
                    if (matchesItemFilters(
                      e.definition,
                      _categoryFilter,
                      _rarityFilter,
                    ))
                      e,
                ]);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 18,
                          color: ext.gold,
                        ),
                        const SizedBox(width: AppSpacing.xs + 2),
                        Expanded(
                          child: Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Tas',
                                style: AppTypography.headingSerif(
                                  theme.textTheme.titleMedium,
                                  color: ext.gold,
                                ),
                              ),
                              ResourceChip(
                                icon: Icons.layers_outlined,
                                label: 'Item',
                                value: '${list.length}',
                                accentColor: ext.expBar,
                              ),
                            ],
                          ),
                        ),
                        AppIconButton(
                          icon: Icons.close,
                          semanticLabel: 'Tutup',
                          tooltip: 'Tutup',
                          onPressed: widget.onClose,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    buildItemFilterBar(
                      categories: const [
                        ItemCategoryFilter.all,
                        ItemCategoryFilter.material,
                        ItemCategoryFilter.consumable,
                        ItemCategoryFilter.quest,
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
                        Text('Urut:', style: theme.textTheme.labelSmall),
                        ChoiceChip(
                          label: const Text('Default'),
                          selected: _sort == _InventorySort.defaultOrder,
                          onSelected: (_) => setState(
                            () => _sort = _InventorySort.defaultOrder,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('Rarity'),
                          selected: _sort == _InventorySort.rarityDesc,
                          onSelected: (_) =>
                              setState(() => _sort = _InventorySort.rarityDesc),
                        ),
                        ChoiceChip(
                          label: const Text('Nama'),
                          selected: _sort == _InventorySort.nameAsc,
                          onSelected: (_) =>
                              setState(() => _sort = _InventorySort.nameAsc),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SectionHeader(
                      title: 'Isi Tas',
                      useSerif: true,
                      trailing: Text(
                        '${filtered.length} jenis',
                        style: AppTypography.numeric(
                          theme.textTheme.labelSmall,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Flexible(
                      child: list.isEmpty
                          ? const SingleChildScrollView(
                              child: EmptyState(
                                icon: Icons.inventory_2_outlined,
                                title: 'Belum ada item.',
                                subtitle: 'Material dan item dari dungeon akan tersimpan di sini.',
                              ),
                            )
                          : filtered.isEmpty
                          ? const SingleChildScrollView(
                              child: EmptyState(
                                icon: Icons.filter_alt_off_outlined,
                                title: 'Tidak ada item yang sesuai filter.',
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.xs),
                              itemBuilder: (context, index) {
                                final e = filtered[index];
                                return ItemCard(
                                  name: e.definition.name,
                                  rarity: e.definition.rarity,
                                  category: e.definition.category,
                                  subtitle: itemCategoryBadgeLabel(
                                    e.definition,
                                  ),
                                  trailing: Text(
                                    'x${e.quantity}',
                                    style: AppTypography.numeric(
                                      theme.textTheme.titleSmall,
                                      color: ext.gold,
                                    ),
                                  ),
                                );
                              },
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
}
