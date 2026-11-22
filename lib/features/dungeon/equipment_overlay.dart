import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/entities/item_definition.dart';
import '../../domain/entities/loadout_preset.dart';
import '../../domain/services/bag_expansion_service.dart';
import '../../game/hud/inventory_views.dart';
import '../shared/widgets/shared_widgets.dart';
import 'equipment_text.dart';
import 'item_filter_widgets.dart';
import 'loadout_preset_bar.dart';

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
    this.onToggleFavorite,
    this.onOpenBlacksmith,
    this.bagLevelProvider,
    this.playerGoldProvider,
    this.onExpandBag,
    this.loadoutPresets = const [],
    this.onSaveLoadoutPreset,
    this.onApplyLoadoutPreset,
    this.specializationNames = const {},
    this.showEquippedSummary = true,
    this.embedded = false,
    required this.onClose,
  });

  final ValueListenable<EquipmentSnapshot> snapshot;
  final Map<String, ItemDefinition> items;
  final void Function(String instanceId) onEquip;
  final void Function(EquipmentSlot slot) onUnequip;
  final void Function(String instanceId)? onToggleFavorite;
  final void Function(String instanceId)? onOpenBlacksmith;
  final int Function()? bagLevelProvider;
  final int Function()? playerGoldProvider;
  final Future<bool> Function()? onExpandBag;
  final List<LoadoutPreset> loadoutPresets;
  final void Function(int slotIndex)? onSaveLoadoutPreset;
  final void Function(int slotIndex)? onApplyLoadoutPreset;
  final Map<String, String> specializationNames;
  final bool showEquippedSummary;
  final bool embedded;
  final VoidCallback onClose;

  @override
  State<EquipmentOverlay> createState() => _EquipmentOverlayState();
}

class _EquipmentOverlayState extends State<EquipmentOverlay> {
  ItemCategoryFilter _categoryFilter = ItemCategoryFilter.all;
  ItemRarity? _rarityFilter;
  _EquipmentSort _sort = _EquipmentSort.defaultOrder;
  String? _selectedBagId;

  String _name(EquipmentInstance e) {
    final base = widget.items[e.definitionId]?.name ?? e.definitionId;
    return e.enhancementLevel > 0 ? '$base +${e.enhancementLevel}' : base;
  }

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

  Future<void> _showExpandDialog(int currentCap) async {
    const service = BagExpansionService();
    final currentLevel = widget.bagLevelProvider?.call() ?? 0;
    if (currentLevel >= BagExpansionService.maxLevel) return;

    final cost = service.getUpgradeCost(currentLevel) ?? 0;
    final playerGold = widget.playerGoldProvider?.call() ?? 0;
    final nextCap = service.calculateCapacity(currentLevel + 1);
    final canAfford = playerGold >= cost;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        final theme = Theme.of(dialogCtx);
        final ext = EchoesTheme.of(dialogCtx);
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: ext.gold),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text(
                  'Perluas Kapasitas Tas',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tingkatkan kapasitas tas perlengkapan sebesar +20 slot.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Level Upgrade:', style: theme.textTheme.bodySmall),
                  Text(
                    '$currentLevel -> ${currentLevel + 1} / ${BagExpansionService.maxLevel}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Kapasitas Tas:', style: theme.textTheme.bodySmall),
                  Text(
                    '$currentCap -> $nextCap slot',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: ext.gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Biaya:', style: theme.textTheme.bodySmall),
                  Text(
                    '${NumberFormatter.format(cost)} Gold',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: canAfford ? ext.gold : theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Gold Anda:', style: theme.textTheme.bodySmall),
                  Text(
                    '${NumberFormatter.format(playerGold)} Gold',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              if (!canAfford) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Gold tidak mencukupi untuk memperluas tas.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              key: const Key('confirm_expand_bag_button'),
              onPressed: canAfford
                  ? () => Navigator.of(dialogCtx).pop(true)
                  : null,
              child: const Text('Perluas'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      final success = await widget.onExpandBag?.call() ?? false;
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kapasitas tas berhasil diperluas menjadi $nextCap slot!',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    final panel = PanelFrame(
      showCornerOrnaments: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm + 2,
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
            mainAxisSize: widget.embedded ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.embedded) ...[
                Row(
                  children: [
                    const AetherSymbolMark(
                      variant: AetherSymbolVariant.mark,
                      size: 16,
                      glow: true,
                    ),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Expanded(
                      child: Text(
                        'Perlengkapan',
                        style: AppTypography.headingSerif(
                          theme.textTheme.titleMedium,
                          color: ext.gold,
                        ),
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
              ],
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.onSaveLoadoutPreset != null ||
                          widget.onApplyLoadoutPreset != null) ...[
                        LoadoutPresetBar(
                          presets: widget.loadoutPresets,
                          specializationNames: widget.specializationNames,
                          onSavePreset: widget.onSaveLoadoutPreset,
                          onApplyPreset: widget.onApplyLoadoutPreset,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (widget.showEquippedSummary) ...[
                        const SectionHeader(
                          title: 'Stat Tempur',
                          useSerif: true,
                        ),
                        PanelFrame(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          backgroundColor: AppColors.surfaceDark,
                          borderColor: ext.panelInnerBorder,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.xs,
                                children: [
                                  _miniStatPill(
                                    'HP',
                                    '${s.stats.maxHp}',
                                    ext.hpBar,
                                  ),
                                  _miniStatPill(
                                    'ATK',
                                    '${s.stats.atk}',
                                    ext.gold,
                                  ),
                                  _miniStatPill(
                                    'DEF',
                                    '${s.stats.def}',
                                    ext.expBar,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                describeCombatStats(s.stats),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const SectionHeader(title: 'Terpasang', useSerif: true),
                        for (final slot in EquipmentSlot.values)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _equippedTile(
                              context,
                              s.equipped[slot],
                              slot,
                            ),
                          ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      SectionHeader(
                        title: s.maxCapacity != null
                            ? 'Tas perlengkapan (${s.bag.length} / ${s.maxCapacity})'
                            : 'Tas perlengkapan (${s.bag.length})',
                        useSerif: true,
                        trailing:
                            widget.onExpandBag != null &&
                                (widget.bagLevelProvider?.call() ?? 0) <
                                    BagExpansionService.maxLevel
                            ? OutlinedButton.icon(
                                key: const Key('expand_bag_capacity_button'),
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  size: 14,
                                ),
                                label: const Text('+20 Slot'),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () => _showExpandDialog(
                                  s.maxCapacity ??
                                      const BagExpansionService()
                                          .calculateCapacity(
                                            widget.bagLevelProvider?.call() ??
                                                0,
                                          ),
                                ),
                              )
                            : null,
                      ),
                      buildItemFilterBar(
                        categories: const [
                          ItemCategoryFilter.all,
                          ItemCategoryFilter.weapon,
                          ItemCategoryFilter.head,
                          ItemCategoryFilter.body,
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
                          Text('Urut:', style: theme.textTheme.labelSmall),
                          ChoiceChip(
                            label: const Text('Default'),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            selected: _sort == _EquipmentSort.defaultOrder,
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
                            onSelected: (_) =>
                                setState(() => _sort = _EquipmentSort.nameAsc),
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
                        const EmptyState(
                          icon: Icons.shield_outlined,
                          title: 'Belum ada equipment.',
                          subtitle: 'Kalahkan monster atau beli perlengkapan di Toko.',
                        )
                      else if (filteredBag.isEmpty)
                        const EmptyState(
                          icon: Icons.filter_alt_off_outlined,
                          title: 'Tidak ada perlengkapan yang sesuai filter.',
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
    );

    if (widget.embedded) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: panel,
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 600),
          child: panel,
        ),
      ),
    );
  }

  Widget _miniStatPill(String label, String value, Color color) {
    final sprite = ItemSpriteRegistry.spriteForStat(label);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sprite != null) ...[
            Image.asset(
              sprite,
              width: 12,
              height: 12,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            '$label $value',
            style: AppTypography.numeric(
              const TextStyle(fontSize: 11),
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _equippedTile(
    BuildContext context,
    EquipmentInstance? e,
    EquipmentSlot slot,
  ) {
    if (e == null) {
      return EquipmentSlotTile(slot: slot, slotLabel: slotLabel(slot));
    }
    return ItemCard(
      itemId: e.definitionId,
      name: _name(e),
      rarity: e.rarity,
      slot: slot,
      subtitle: slotLabel(slot),
      statsLines: equipmentStatLines(e.effectiveStats),
      statsSummary: describeEquipmentStats(e.effectiveStats),
      isFavorite: e.isFavorite,
      onToggleFavorite: widget.onToggleFavorite != null
          ? () => widget.onToggleFavorite!(e.id)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onOpenBlacksmith != null)
            IconButton(
              icon: const Icon(Icons.hardware_outlined, size: 18),
              tooltip: 'Tempa di Pandai Besi',
              onPressed: () => widget.onOpenBlacksmith!(e.id),
              visualDensity: VisualDensity.compact,
            ),
          TextButton(
            onPressed: () => widget.onUnequip(slot),
            child: const Text('Lepas'),
          ),
        ],
      ),
    );
  }

  Widget _bagTile(BuildContext context, EquipmentInstance e) {
    final selected = e.id == _selectedBagId;
    return ItemCard(
      itemId: e.definitionId,
      name: _name(e),
      rarity: e.rarity,
      slot: e.slot,
      subtitle: selected
          ? '${slotLabel(e.slot)} • Sedang dibandingkan'
          : '${slotLabel(e.slot)} • Ketuk untuk bandingkan',
      statsLines: equipmentStatLines(e.effectiveStats),
      statsSummary: describeEquipmentStats(e.effectiveStats),
      isFavorite: e.isFavorite,
      onToggleFavorite: widget.onToggleFavorite != null
          ? () => widget.onToggleFavorite!(e.id)
          : null,
      onTap: () => setState(() {
        _selectedBagId = selected ? null : e.id;
      }),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onOpenBlacksmith != null)
            IconButton(
              icon: const Icon(Icons.hardware_outlined, size: 18),
              tooltip: 'Tempa di Pandai Besi',
              onPressed: () => widget.onOpenBlacksmith!(e.id),
              visualDensity: VisualDensity.compact,
            ),
          FilledButton.tonal(
            onPressed: () => widget.onEquip(e.id),
            child: const Text('Pakai'),
          ),
        ],
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
      showCornerOrnaments: true,
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
                  style: AppTypography.headingSerif(
                    theme.textTheme.labelLarge,
                    color: ext.gold,
                  ),
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
