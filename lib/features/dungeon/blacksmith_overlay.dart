import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/entities/inventory.dart';
import '../../domain/entities/item_definition.dart';
import '../../domain/entities/mythical_forge_config.dart';
import '../../domain/services/blacksmith_service.dart';
import '../../game/hud/inventory_views.dart';
import '../shared/widgets/shared_widgets.dart';
import 'equipment_text.dart';
import 'item_filter_widgets.dart';

enum _BlacksmithTab { enhance, reforge, salvage, mythicalForge }

/// Overlay Pandai Besi (Blacksmith) di Town Hub.
/// Memungkinkan pemain menempa perlengkapan (+1 s/d +10) menggunakan Gold dan
/// material monster, me-reforge sub-stat perlengkapan Rare/Epic/Legendary,
/// serta membongkar (salvage) perlengkapan menjadi Aether Scrap.
class BlacksmithOverlay extends StatefulWidget {
  const BlacksmithOverlay({
    super.key,
    required this.snapshot,
    required this.items,
    required this.inventoryEntries,
    required this.characterSnapshot,
    required this.onEnhanceEquipment,
    required this.onReforgeEquipment,
    this.onSalvageEquipment,
    this.onSalvageEquipmentBulk,
    this.forgeConfig = const MythicalForgeConfig(),
    this.onCraftMythicalEquipment,
    this.initialSelectedInstanceId,
    this.embedded = false,
    required this.onClose,
  });

  final ValueListenable<EquipmentSnapshot> snapshot;
  final Map<String, ItemDefinition> items;
  final ValueListenable<List<InventoryEntry>> inventoryEntries;
  final ValueListenable<CharacterSnapshot> characterSnapshot;
  final BlacksmithEnhanceResult Function(String instanceId) onEnhanceEquipment;
  final BlacksmithReforgeResult Function(String instanceId) onReforgeEquipment;
  final BlacksmithSalvageResult Function(String instanceId)? onSalvageEquipment;
  final BlacksmithBulkSalvageResult Function(Set<ItemRarity> rarities)?
  onSalvageEquipmentBulk;
  final MythicalForgeConfig forgeConfig;
  final BlacksmithCraftMythicalResult Function(
    String recipeId,
    String sacrificeInstanceId,
  )?
  onCraftMythicalEquipment;
  final String? initialSelectedInstanceId;
  final bool embedded;
  final VoidCallback onClose;

  @override
  State<BlacksmithOverlay> createState() => _BlacksmithOverlayState();
}

class _BlacksmithOverlayState extends State<BlacksmithOverlay> {
  static const _service = BlacksmithService();

  _BlacksmithTab _currentTab = _BlacksmithTab.enhance;
  ItemCategoryFilter _categoryFilter = ItemCategoryFilter.all;
  String? _selectedId;
  String? _selectedForgeSetId;
  String? _selectedForgeRecipeId;
  String? _selectedSacrificeId;
  String? _feedbackMessage;
  bool _feedbackIsError = false;
  bool _busy = false;

  bool get _showForgeTab =>
      widget.forgeConfig.recipes.isNotEmpty ||
      widget.onCraftMythicalEquipment != null;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialSelectedInstanceId;
  }

  String _name(EquipmentInstance e) {
    final baseName = widget.items[e.definitionId]?.name ?? e.definitionId;
    return e.enhancementLevel > 0
        ? '$baseName +${e.enhancementLevel}'
        : baseName;
  }

  int _materialCount(String itemId, List<InventoryEntry> stacks) {
    for (final entry in stacks) {
      if (entry.definition.id == itemId) return entry.quantity;
    }
    return 0;
  }

  void _handleEnhance(EquipmentInstance item) {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = widget.onEnhanceEquipment(item.id);
      final itemName =
          widget.items[item.definitionId]?.name ?? item.definitionId;
      if (res.isSuccess && res.updatedInstance != null) {
        setState(() {
          _feedbackIsError = false;
          _feedbackMessage =
              'Sukses! $itemName berhasil ditempa ke +${res.updatedInstance!.enhancementLevel}.';
        });
      } else {
        setState(() {
          _feedbackIsError = true;
          switch (res.status) {
            case BlacksmithEnhanceStatus.maxLevelReached:
              _feedbackMessage =
                  'Perlengkapan sudah mencapai level maksimum (+10).';
            case BlacksmithEnhanceStatus.insufficientGold:
              _feedbackMessage = 'Gold tidak mencukupi untuk menempa.';
            case BlacksmithEnhanceStatus.insufficientMaterials:
              _feedbackMessage = 'Material monster belum mencukupi.';
            case BlacksmithEnhanceStatus.itemNotFound:
              _feedbackMessage = 'Perlengkapan tidak ditemukan.';
            case BlacksmithEnhanceStatus.success:
              break;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _handleReforge(EquipmentInstance item) {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = widget.onReforgeEquipment(item.id);
      final itemName =
          widget.items[item.definitionId]?.name ?? item.definitionId;
      if (res.isSuccess && res.updatedInstance != null) {
        setState(() {
          _feedbackIsError = false;
          _feedbackMessage = 'Sukses! Sub-stat $itemName berhasil di-reforge.';
        });
      } else {
        setState(() {
          _feedbackIsError = true;
          switch (res.status) {
            case BlacksmithReforgeStatus.insufficientGold:
              _feedbackMessage = 'Gold tidak mencukupi untuk me-reforge.';
            case BlacksmithReforgeStatus.ineligibleRarity:
              _feedbackMessage =
                  'Hanya gear Rare, Epic, dan Legendary yang dapat di-reforge.';
            case BlacksmithReforgeStatus.fixedStatsNotReforgeable:
              _feedbackMessage =
                  'Gear ini memiliki stat tetap dan tidak dapat di-reforge.';
            case BlacksmithReforgeStatus.definitionNotFound:
            case BlacksmithReforgeStatus.itemNotFound:
              _feedbackMessage = 'Data perlengkapan tidak ditemukan.';
            case BlacksmithReforgeStatus.success:
              break;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);

    final panel = PanelFrame(
      showCornerOrnaments: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm + 2,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: ValueListenableBuilder<EquipmentSnapshot>(
        valueListenable: widget.snapshot,
        builder: (context, eqSnapshot, _) {
          return ValueListenableBuilder<List<InventoryEntry>>(
            valueListenable: widget.inventoryEntries,
            builder: (context, stacks, _) {
              return ValueListenableBuilder<CharacterSnapshot>(
                valueListenable: widget.characterSnapshot,
                builder: (context, charSnapshot, _) {
                  final equippedList = eqSnapshot.equipped.values.toList();
                  final allItems = [...equippedList, ...eqSnapshot.bag];

                  // Filter kategori item
                  final filteredItems = allItems.where((e) {
                    return matchesEquipmentFilter(
                      e.slot,
                      e.rarity,
                      _categoryFilter,
                      null,
                    );
                  }).toList();

                  // Pastikan selected item valid
                  final selectedItem =
                      allItems.where((e) => e.id == _selectedId).firstOrNull ??
                      (filteredItems.isNotEmpty ? filteredItems.first : null);

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(theme, ext, charSnapshot.gold),
                      const SizedBox(height: AppSpacing.xs),
                      _buildModeSelector(),
                      if (_feedbackMessage != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        _buildFeedbackBanner(theme, ext),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      if (_currentTab != _BlacksmithTab.mythicalForge) ...[
                        _buildItemSelector(
                          theme,
                          ext,
                          filteredItems,
                          eqSnapshot.equipped,
                        ),
                        const Divider(height: AppSpacing.md),
                      ],
                      Expanded(
                        child: _currentTab == _BlacksmithTab.mythicalForge
                            ? _buildMythicalForgeView(
                                theme,
                                ext,
                                eqSnapshot,
                                charSnapshot.gold,
                                stacks,
                              )
                            : selectedItem == null
                            ? const Center(
                                child: Text(
                                  'Tidak ada perlengkapan yang dipilih.',
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              )
                            : _currentTab == _BlacksmithTab.enhance
                            ? _buildEnhanceView(
                                theme,
                                ext,
                                selectedItem,
                                charSnapshot.gold,
                                stacks,
                              )
                            : _currentTab == _BlacksmithTab.reforge
                            ? _buildReforgeView(
                                theme,
                                ext,
                                selectedItem,
                                charSnapshot.gold,
                              )
                            : _buildSalvageView(
                                theme,
                                ext,
                                selectedItem,
                                eqSnapshot.equipped,
                                eqSnapshot.bag,
                                stacks,
                              ),
                      ),
                    ],
                  );
                },
              );
            },
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
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 660),
          child: panel,
        ),
      ),
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    EchoesThemeExtension ext,
    int playerGold,
  ) {
    return Row(
      children: [
        Icon(Icons.hardware_outlined, color: ext.gold, size: 22),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            'Pandai Besi',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: ext.gold,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        ResourceChip.gold(playerGold),
        if (!widget.embedded) ...[
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: widget.onClose,
            visualDensity: VisualDensity.compact,
            tooltip: 'Tutup',
          ),
        ],
      ],
    );
  }

  Widget _buildModeSelector() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SegmentedButton<_BlacksmithTab>(
        segments: [
          const ButtonSegment<_BlacksmithTab>(
            value: _BlacksmithTab.enhance,
            icon: Icon(Icons.upgrade),
            label: Text('Tempa (+1..+10)', overflow: TextOverflow.ellipsis),
          ),
          const ButtonSegment<_BlacksmithTab>(
            value: _BlacksmithTab.reforge,
            icon: Icon(Icons.casino_outlined),
            label: Text('Reforge Sub-stat', overflow: TextOverflow.ellipsis),
          ),
          const ButtonSegment<_BlacksmithTab>(
            value: _BlacksmithTab.salvage,
            icon: Icon(Icons.recycling),
            label: Text('Bongkar', overflow: TextOverflow.ellipsis),
          ),
          if (_showForgeTab)
            const ButtonSegment<_BlacksmithTab>(
              value: _BlacksmithTab.mythicalForge,
              icon: Icon(Icons.auto_fix_high),
              label: Text('Tempa Mythical', overflow: TextOverflow.ellipsis),
            ),
        ],
        selected: {_currentTab},
        onSelectionChanged: (next) {
          setState(() {
            _currentTab = next.first;
            _feedbackMessage = null;
          });
        },
      ),
    );
  }

  Widget _buildFeedbackBanner(ThemeData theme, EchoesThemeExtension ext) {
    final color = _feedbackIsError ? theme.colorScheme.error : ext.success;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            _feedbackIsError ? Icons.error_outline : Icons.check_circle_outline,
            size: 16,
            color: color,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              _feedbackMessage!,
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemSelector(
    ThemeData theme,
    EchoesThemeExtension ext,
    List<EquipmentInstance> items,
    Map<EquipmentSlot, EquipmentInstance> equipped,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Pilih Perlengkapan:',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            DropdownButton<ItemCategoryFilter>(
              value: _categoryFilter,
              isDense: true,
              underline: const SizedBox.shrink(),
              style: theme.textTheme.bodySmall?.copyWith(color: ext.gold),
              items: const [
                DropdownMenuItem(
                  value: ItemCategoryFilter.all,
                  child: Text('Semua Slot'),
                ),
                DropdownMenuItem(
                  value: ItemCategoryFilter.weapon,
                  child: Text('Senjata'),
                ),
                DropdownMenuItem(
                  value: ItemCategoryFilter.head,
                  child: Text('Kepala'),
                ),
                DropdownMenuItem(
                  value: ItemCategoryFilter.body,
                  child: Text('Badan'),
                ),
                DropdownMenuItem(
                  value: ItemCategoryFilter.accessory,
                  child: Text('Aksesori'),
                ),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _categoryFilter = val);
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              'Tidak ada item pada kategori ini.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          )
        else
          SizedBox(
            height: 58,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = item.id == _selectedId;
                final isEquipped = equipped.containsValue(item);
                final rarityColor = ext.colorForRarity(item.rarity);

                return InkWell(
                  onTap: () => setState(() {
                    _selectedId = item.id;
                    _feedbackMessage = null;
                  }),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Container(
                    width: 130,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs + 2,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ext.gold.withValues(alpha: 0.16)
                          : AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: isSelected
                            ? ext.gold
                            : rarityColor.withValues(alpha: 0.5),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            if (isEquipped)
                              Container(
                                margin: const EdgeInsets.only(right: 3),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: ext.gold.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: const Text(
                                  'E',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.antiqueGold,
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                _name(item),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? ext.gold : rarityColor,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          slotLabel(item.slot),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEnhanceView(
    ThemeData theme,
    EchoesThemeExtension ext,
    EquipmentInstance item,
    int playerGold,
    List<InventoryEntry> stacks,
  ) {
    final def = widget.items[item.definitionId];
    final isMax =
        item.enhancementLevel >= BlacksmithService.maxEnhancementLevel;
    final req = _service.getEnhanceRequirement(item.enhancementLevel);
    final rarityColor = ext.colorForRarity(item.rarity);

    final canAffordGold = req != null && playerGold >= req.goldCost;
    var canAffordMats = true;
    if (req != null) {
      for (final entry in req.requiredMaterials.entries) {
        if (_materialCount(entry.key, stacks) < entry.value) {
          canAffordMats = false;
          break;
        }
      }
    }

    final canEnhance = !isMax && canAffordGold && canAffordMats && !_busy;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info Item yang dipilih
          PanelFrame(
            padding: const EdgeInsets.all(AppSpacing.sm),
            backgroundColor: AppColors.surfaceDark,
            borderColor: ext.panelInnerBorder,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      def?.name ?? item.definitionId,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: rarityColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    if (item.enhancementLevel > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: ext.gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: ext.gold.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          '+${item.enhancementLevel}',
                          style: TextStyle(
                            color: ext.gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      slotLabel(item.slot),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Stat Saat Ini: ${describeEquipmentStats(item.effectiveStats)}',
                  style: theme.textTheme.bodySmall,
                ),
                if (!isMax) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Stat Target (+${item.enhancementLevel + 1}): ${describeEquipmentStats(item.copyWith(enhancementLevel: item.enhancementLevel + 1).effectiveStats)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: ext.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Prasyarat Penempaan
          if (isMax)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: ext.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: ext.gold.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.workspace_premium, color: ext.gold),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Puncak Penempaan (+10) Tercapai (+50% Stat Flat)!',
                    style: TextStyle(
                      color: ext.gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          else if (req != null) ...[
            Text(
              'Biaya Penempaan (Target +${req.targetLevel}):',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            PanelFrame(
              padding: const EdgeInsets.all(AppSpacing.sm),
              backgroundColor: AppColors.surfaceDark,
              borderColor: ext.panelInnerBorder,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Biaya Gold
                  Row(
                    children: [
                      Icon(
                        canAffordGold ? Icons.check_circle : Icons.cancel,
                        size: 16,
                        color: canAffordGold
                            ? ext.success
                            : theme.colorScheme.error,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Gold: ${NumberFormatter.format(req.goldCost)}',
                        style: TextStyle(
                          color: canAffordGold
                              ? AppColors.textPrimary
                              : theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '(Miliki: ${NumberFormatter.format(playerGold)})',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  // Biaya Material
                  Text(
                    'Material Dibutuhkan:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final entry in req.requiredMaterials.entries) ...[
                        () {
                          final matDef = widget.items[entry.key];
                          final owned = _materialCount(entry.key, stacks);
                          final ok = owned >= entry.value;
                          final matName = matDef?.name ?? entry.key;

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: ok
                                  ? ext.success.withValues(alpha: 0.12)
                                  : theme.colorScheme.error.withValues(
                                      alpha: 0.12,
                                    ),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                color: ok
                                    ? ext.success.withValues(alpha: 0.4)
                                    : theme.colorScheme.error.withValues(
                                        alpha: 0.4,
                                      ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  ok ? Icons.check : Icons.close,
                                  size: 13,
                                  color: ok
                                      ? ext.success
                                      : theme.colorScheme.error,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '$matName: $owned/${entry.value}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: ok
                                        ? ext.success
                                        : theme.colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Tempa (+${item.enhancementLevel + 1})',
              icon: Icons.hardware_outlined,
              expand: true,
              onPressed: canEnhance ? () => _handleEnhance(item) : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReforgeView(
    ThemeData theme,
    EchoesThemeExtension ext,
    EquipmentInstance item,
    int playerGold,
  ) {
    final def = widget.items[item.definitionId];
    final rarityColor = ext.colorForRarity(item.rarity);
    final isFixed = def?.equipment?.fixedStats ?? false;
    final cost = _service.getReforgeCost(item.rarity);

    final isEligibleRarity = cost != null;
    final canAfford = cost != null && playerGold >= cost;
    final canReforge = isEligibleRarity && !isFixed && canAfford && !_busy;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelFrame(
            padding: const EdgeInsets.all(AppSpacing.sm),
            backgroundColor: AppColors.surfaceDark,
            borderColor: ext.panelInnerBorder,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      def?.name ?? item.definitionId,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: rarityColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    if (item.enhancementLevel > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: ext.gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          '+${item.enhancementLevel}',
                          style: TextStyle(
                            color: ext.gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      slotLabel(item.slot),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Sub-stat Saat Ini:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                for (final line in equipmentStatLines(item.rolledStats))
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      '• $line',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          if (!isEligibleRarity)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Hanya perlengkapan Rare, Epic, dan Legendary yang dapat di-reforge sub-statnya.',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (isFixed)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Perlengkapan eksklusif ini memiliki stat tetap dan tidak dapat di-reforge.',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Text(
              'Biaya Reforge Sub-stat:',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            PanelFrame(
              padding: const EdgeInsets.all(AppSpacing.sm),
              backgroundColor: AppColors.surfaceDark,
              borderColor: ext.panelInnerBorder,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        canAfford ? Icons.check_circle : Icons.cancel,
                        size: 16,
                        color: canAfford
                            ? ext.success
                            : theme.colorScheme.error,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Biaya: ${NumberFormatter.format(cost)} Gold',
                        style: TextStyle(
                          color: canAfford
                              ? AppColors.textPrimary
                              : theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Mengacak ulang sub-stat dasar (±15%). Level penempaan (+) tetap aman dan tidak akan hilang.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Reforge Sub-stat (${NumberFormatter.format(cost)} G)',
              icon: Icons.casino_outlined,
              expand: true,
              onPressed: canReforge ? () => _handleReforge(item) : null,
            ),
          ],
        ],
      ),
    );
  }

  void _handleSalvage(EquipmentInstance item) {
    if (_busy || widget.onSalvageEquipment == null) return;
    setState(() => _busy = true);
    try {
      final res = widget.onSalvageEquipment!(item.id);
      final itemName =
          widget.items[item.definitionId]?.name ?? item.definitionId;
      if (res.isSuccess) {
        setState(() {
          _feedbackIsError = false;
          _feedbackMessage =
              'Berhasil membongkar $itemName dan memperoleh +${res.aetherScrapGained} Aether Scrap!';
          _selectedId = null;
        });
      } else {
        setState(() {
          _feedbackIsError = true;
          switch (res.status) {
            case BlacksmithSalvageStatus.cannotSalvageEquipped:
              _feedbackMessage =
                  'Lepas perlengkapan yang sedang dipakai terlebih dahulu.';
            case BlacksmithSalvageStatus.cannotSalvageMythical:
              _feedbackMessage = 'Perlengkapan Mythical tidak dapat dibongkar.';
            case BlacksmithSalvageStatus.inventoryFull:
              _feedbackMessage =
                  'Kapasitas tas untuk Aether Scrap sudah penuh.';
            case BlacksmithSalvageStatus.itemNotFound:
            case BlacksmithSalvageStatus.definitionNotFound:
              _feedbackMessage = 'Perlengkapan tidak ditemukan.';
            case BlacksmithSalvageStatus.success:
              break;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openBulkSalvageDialog(
    List<EquipmentInstance> bagItems,
    Map<EquipmentSlot, EquipmentInstance> equipped,
  ) async {
    if (_busy || widget.onSalvageEquipmentBulk == null) return;
    final equippedIds = {for (final eq in equipped.values) eq.id};
    const presets = <({String label, Set<ItemRarity> rarities})>[
      (label: 'Common', rarities: {ItemRarity.common}),
      (
        label: 'Common + Uncommon',
        rarities: {ItemRarity.common, ItemRarity.uncommon},
      ),
      (
        label: 'Semua ≤ Rare',
        rarities: {ItemRarity.common, ItemRarity.uncommon, ItemRarity.rare},
      ),
    ];

    var selectedIndex = 1;
    final chosenRarities = await showDialog<Set<ItemRarity>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final preset = presets[selectedIndex];
            final candidates = [
              for (final eq in bagItems)
                if (_service.isBulkSalvageCandidate(
                  eq,
                  targetRarities: preset.rarities,
                  equippedIds: equippedIds,
                ))
                  eq,
            ];
            final totalScrap = candidates.fold<int>(
              0,
              (sum, eq) => sum + _service.getSalvageScrapYield(eq),
            );
            final theme = Theme.of(context);
            final ext = EchoesTheme.of(context);

            return AlertDialog(
              title: const Text('Bongkar Massal'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Pilih batas rarity perlengkapan yang akan dibongkar menjadi Aether Scrap:',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    for (var i = 0; i < presets.length; i++) ...[
                      InkWell(
                        key: Key('bulk_salvage_preset_$i'),
                        onTap: () => setDialogState(() => selectedIndex = i),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs + 2,
                          ),
                          decoration: BoxDecoration(
                            color: selectedIndex == i
                                ? ext.gold.withValues(alpha: 0.14)
                                : AppColors.surfaceDark,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: selectedIndex == i
                                  ? ext.gold
                                  : ext.panelInnerBorder,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selectedIndex == i
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                size: 18,
                                color: selectedIndex == i
                                    ? ext.gold
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  presets[i].label,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: selectedIndex == i
                                        ? ext.gold
                                        : AppColors.textPrimary,
                                    fontWeight: selectedIndex == i
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (i < presets.length - 1)
                        const SizedBox(height: AppSpacing.xs),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    PanelFrame(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      backgroundColor: AppColors.surfaceDark,
                      borderColor: ext.panelInnerBorder,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Terpilih: ${candidates.length} perlengkapan',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Estimasi Hasil: +${NumberFormatter.format(totalScrap)} Aether Scrap',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: candidates.isNotEmpty
                                  ? ext.success
                                  : AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Item terpasang, favorit, +1 ke atas, dan Mythical otomatis dilindungi.',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                SecondaryButton(
                  label: 'Batal',
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                PrimaryButton(
                  key: const Key('bulk_salvage_confirm_button'),
                  label: 'Bongkar (${candidates.length})',
                  icon: Icons.delete_sweep_outlined,
                  onPressed: candidates.isEmpty
                      ? null
                      : () =>
                            Navigator.of(dialogContext)
                                .pop(presets[selectedIndex].rarities),
                ),
              ],
            );
          },
        );
      },
    );

    if (chosenRarities == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final res = widget.onSalvageEquipmentBulk!(chosenRarities);
      if (!mounted) return;
      if (res.hasSalvaged) {
        setState(() {
          _feedbackIsError = false;
          _feedbackMessage =
              'Berhasil membongkar ${res.salvagedCount} perlengkapan (+${NumberFormatter.format(res.aetherScrapGained)} Aether Scrap)!${res.stoppedByInventoryFull ? ' Sebagian tertunda karena kapasitas Aether Scrap penuh.' : ''}';
          if (_selectedId != null && res.salvagedIds.contains(_selectedId)) {
            _selectedId = null;
          }
        });
      } else {
        setState(() {
          _feedbackIsError = true;
          _feedbackMessage = res.stoppedByInventoryFull
              ? 'Kapasitas tas untuk Aether Scrap sudah penuh.'
              : 'Tidak ada perlengkapan yang memenuhi syarat untuk dibongkar.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildSalvageView(
    ThemeData theme,
    EchoesThemeExtension ext,
    EquipmentInstance item,
    Map<EquipmentSlot, EquipmentInstance> equipped,
    List<EquipmentInstance> bagItems,
    List<InventoryEntry> stacks,
  ) {
    final isEquipped = equipped.values.any((e) => e.id == item.id);
    final isMythical = item.rarity == ItemRarity.mythical;
    final scrapYield = _service.getSalvageScrapYield(item);
    final ownedScrap = _materialCount(
      BlacksmithService.aetherScrapItemId,
      stacks,
    );
    final canSalvage =
        !_busy &&
        !isEquipped &&
        !isMythical &&
        scrapYield > 0 &&
        widget.onSalvageEquipment != null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelFrame(
            padding: const EdgeInsets.all(AppSpacing.sm),
            backgroundColor: AppColors.surfaceDark,
            borderColor: ext.colorForRarity(item.rarity).withValues(alpha: 0.6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    RarityLabel(rarity: item.rarity, compact: true),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        _name(item),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: ext.colorForRarity(item.rarity),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Aether Scrap Dimiliki: ${NumberFormatter.format(ownedScrap)}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (isEquipped || isMythical)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      isEquipped
                          ? 'Perlengkapan sedang dipakai. Lepas terlebih dahulu untuk membongkarnya.'
                          : 'Perlengkapan Mythical dilindungi dan tidak dapat dibongkar.',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            PanelFrame(
              padding: const EdgeInsets.all(AppSpacing.sm),
              backgroundColor: AppColors.surfaceDark,
              borderColor: ext.panelInnerBorder,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hasil Pembongkaran (Salvage):',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: ext.gold),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        '+${NumberFormatter.format(scrapYield)} Aether Scrap',
                        style: TextStyle(
                          color: ext.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Membongkar perlengkapan akan menghancurkannya secara permanen dan menghasilkan Aether Scrap untuk barter di Dungeon Outpost.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              key: const Key('blacksmith_salvage_button'),
              label: 'Bongkar (+${NumberFormatter.format(scrapYield)} Scrap)',
              icon: Icons.recycling,
              expand: true,
              onPressed: canSalvage ? () => _handleSalvage(item) : null,
            ),
          ],
          if (widget.onSalvageEquipmentBulk != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              key: const Key('blacksmith_bulk_salvage_button'),
              label: 'Bongkar Massal...',
              icon: Icons.delete_sweep_outlined,
              expand: true,
              onPressed: _busy
                  ? null
                  : () => _openBulkSalvageDialog(bagItems, equipped),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmAndCraftMythical({
    required MythicalForgeRecipe recipe,
    required ItemDefinition targetDef,
    required EquipmentInstance sacrifice,
    required String catalystName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => EchoesDialog(
        title: 'Konfirmasi Tempa Mythical',
        icon: Icons.auto_fix_high,
        accentColor: AppColors.rarityMythical,
        primaryLabel: 'Konfirmasi Tempa',
        onPrimary: () => Navigator.of(dialogContext).pop(true),
        secondaryLabel: 'Batal',
        onSecondary: () => Navigator.of(dialogContext).pop(false),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tempa ${targetDef.name} (+0, Stat Tetap)?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Tumbal ${_name(sacrifice)} akan dikonsumsi secara permanen. '
              'Senjata katalis $catalystName tetap aman dan tidak hilang.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      _handleCraftMythical(recipe, sacrifice, targetDef);
    }
  }

  void _handleCraftMythical(
    MythicalForgeRecipe recipe,
    EquipmentInstance sacrifice,
    ItemDefinition targetDef,
  ) {
    if (_busy || widget.onCraftMythicalEquipment == null) return;
    setState(() => _busy = true);
    try {
      final res = widget.onCraftMythicalEquipment!(recipe.id, sacrifice.id);
      if (res.isSuccess && res.craftedInstance != null) {
        setState(() {
          _feedbackIsError = false;
          _feedbackMessage = 'Sukses! ${targetDef.name} berhasil ditempa (+0).';
          _selectedSacrificeId = null;
        });
      } else {
        setState(() {
          _feedbackIsError = true;
          switch (res.status) {
            case BlacksmithCraftMythicalStatus.missingCatalystWeapon:
              _feedbackMessage =
                  'Memerlukan senjata katalis di tas atau sedang terpasang.';
            case BlacksmithCraftMythicalStatus.insufficientGold:
              _feedbackMessage = 'Gold tidak mencukupi untuk menempa Mythical.';
            case BlacksmithCraftMythicalStatus.insufficientMaterials:
              _feedbackMessage = 'Material penempaan belum mencukupi.';
            case BlacksmithCraftMythicalStatus.cannotSacrificeFavorite:
              _feedbackMessage = 'Equipment favorit tidak dapat ditumbalkan.';
            case BlacksmithCraftMythicalStatus.cannotSacrificeEquipped:
              _feedbackMessage = 'Lepas equipment tumbal terlebih dahulu.';
            case BlacksmithCraftMythicalStatus.sacrificeRarityTooLow:
              _feedbackMessage = 'Rarity tumbal minimal Legendary.';
            case BlacksmithCraftMythicalStatus.sacrificeSlotMismatch:
              _feedbackMessage = 'Slot tumbal harus sama dengan target.';
            case BlacksmithCraftMythicalStatus.cannotSacrificeMythical:
              _feedbackMessage = 'Gear Mythical tidak dapat ditumbalkan.';
            case BlacksmithCraftMythicalStatus.recipeNotFound:
            case BlacksmithCraftMythicalStatus.targetDefinitionNotFound:
            case BlacksmithCraftMythicalStatus.sacrificeNotFound:
              _feedbackMessage = 'Resep atau tumbal tidak ditemukan.';
            case BlacksmithCraftMythicalStatus.success:
              break;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildMythicalForgeView(
    ThemeData theme,
    EchoesThemeExtension ext,
    EquipmentSnapshot eqSnapshot,
    int playerGold,
    List<InventoryEntry> stacks,
  ) {
    final recipes = widget.forgeConfig.recipes.values.toList();
    if (recipes.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada resep Tempa Mythical yang tersedia.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    final setIds = <String>{
      for (final s in widget.forgeConfig.sets.values)
        if (recipes.any((r) => r.setId == s.id)) s.id,
      for (final r in recipes)
        if (!widget.forgeConfig.sets.containsKey(r.setId)) r.setId,
    }.toList();

    final activeSetId = setIds.contains(_selectedForgeSetId)
        ? _selectedForgeSetId!
        : setIds.first;
    final setRecipes = recipes.where((r) => r.setId == activeSetId).toList();
    final selectedRecipe =
        setRecipes.where((r) => r.id == _selectedForgeRecipeId).firstOrNull ??
        setRecipes.first;

    final setDef = widget.forgeConfig.sets[activeSetId];
    final targetDef = widget.items[selectedRecipe.targetItemId];
    final targetEq = targetDef?.equipment;
    final catalystName =
        widget.items[selectedRecipe.requiredCatalystWeaponId]?.name ??
        selectedRecipe.requiredCatalystWeaponId;
    final hasCatalyst =
        eqSnapshot.equipped[EquipmentSlot.weapon]?.definitionId ==
            selectedRecipe.requiredCatalystWeaponId ||
        eqSnapshot.bag.any(
          (e) => e.definitionId == selectedRecipe.requiredCatalystWeaponId,
        );

    final equippedIds = {for (final eq in eqSnapshot.equipped.values) eq.id};
    final candidates = targetEq == null
        ? const <EquipmentInstance>[]
        : [
            for (final item in eqSnapshot.bag)
              if (!equippedIds.contains(item.id) &&
                  !item.isFavorite &&
                  item.rarity != ItemRarity.mythical &&
                  item.slot == targetEq.slot &&
                  item.rarity.index >= selectedRecipe.sacrificeMinRarity.index)
                item,
          ];
    final selectedSacrifice =
        candidates.where((c) => c.id == _selectedSacrificeId).firstOrNull ??
        (candidates.isNotEmpty ? candidates.first : null);

    final hasGold = playerGold >= selectedRecipe.goldCost;
    final hasMaterials = selectedRecipe.materials.entries.every(
      (m) => _materialCount(m.key, stacks) >= m.value,
    );
    final canCraft =
        widget.onCraftMythicalEquipment != null &&
        !_busy &&
        targetDef != null &&
        targetEq != null &&
        hasCatalyst &&
        hasGold &&
        hasMaterials &&
        selectedSacrifice != null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pilih Set Mythical:',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: ext.gold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final setId in setIds)
                ChoiceChip(
                  key: Key('forge_set_$setId'),
                  label: Text(
                    widget.forgeConfig.sets[setId]?.name ?? setId,
                    style: const TextStyle(fontSize: 11),
                  ),
                  selected: setId == activeSetId,
                  onSelected: (_) {
                    setState(() {
                      _selectedForgeSetId = setId;
                      _selectedForgeRecipeId = null;
                      _selectedSacrificeId = null;
                      _feedbackMessage = null;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final recipe in setRecipes)
                ChoiceChip(
                  key: Key('forge_recipe_${recipe.id}'),
                  label: Text(
                    widget.items[recipe.targetItemId]?.equipment != null
                        ? slotLabel(
                            widget.items[recipe.targetItemId]!.equipment!.slot,
                          )
                        : recipe.targetItemId,
                    style: const TextStyle(fontSize: 11),
                  ),
                  selected: recipe.id == selectedRecipe.id,
                  onSelected: (_) {
                    setState(() {
                      _selectedForgeRecipeId = recipe.id;
                      _selectedSacrificeId = null;
                      _feedbackMessage = null;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (targetDef != null && targetEq != null) ...[
            PanelFrame(
              padding: const EdgeInsets.all(AppSpacing.sm),
              backgroundColor: AppColors.surfaceDark,
              borderColor: AppColors.rarityMythical.withValues(alpha: 0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PixelItemIcon(itemId: targetDef.id, size: 32),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              targetDef.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: AppColors.rarityMythical,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${slotLabel(targetEq.slot)} • Stat Tetap (+0)',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const RarityLabel(
                        rarity: ItemRarity.mythical,
                        compact: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    equipmentStatLines(targetEq.baseStats).join(' • '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (setDef != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Set ${setDef.name} • 2P: ${setDef.twoPieceDescription}',
                      style: TextStyle(fontSize: 11, color: ext.gold),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(
                        hasCatalyst ? Icons.check_circle : Icons.lock_outline,
                        size: 15,
                        color: hasCatalyst
                            ? ext.success
                            : theme.colorScheme.error,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          hasCatalyst
                              ? 'Katalis Tersedia: $catalystName (Tidak Dikonsumsi)'
                              : 'Butuh Katalis: $catalystName (Tidak Dikonsumsi)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: hasCatalyst
                                ? ext.success
                                : theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            PanelFrame(
              padding: const EdgeInsets.all(AppSpacing.sm),
              backgroundColor: AppColors.surfaceDark,
              borderColor: ext.panelInnerBorder,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Biaya & Material Penempaan:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _costRow(
                    label: 'Gold',
                    owned: playerGold,
                    requiredCount: selectedRecipe.goldCost,
                    okColor: ext.success,
                    errColor: theme.colorScheme.error,
                  ),
                  for (final mat in selectedRecipe.materials.entries)
                    _costRow(
                      label: widget.items[mat.key]?.name ?? mat.key,
                      owned: _materialCount(mat.key, stacks),
                      requiredCount: mat.value,
                      okColor: ext.success,
                      errColor: theme.colorScheme.error,
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Pilih Tumbal (${selectedRecipe.sacrificeMinRarity.name.toUpperCase()} ${slotLabel(targetEq.slot)}, Non-Favorit):',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (candidates.isEmpty)
                    Text(
                      'Tidak ada tumbal ${selectedRecipe.sacrificeMinRarity.name.toUpperCase()} (${slotLabel(targetEq.slot)}) non-favorit di tas.',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.error,
                      ),
                    )
                  else
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final cand in candidates)
                          ChoiceChip(
                            key: Key('forge_sacrifice_${cand.id}'),
                            label: Text(
                              _name(cand),
                              style: const TextStyle(fontSize: 11),
                            ),
                            selected: cand.id == selectedSacrifice?.id,
                            onSelected: (_) =>
                                setState(() => _selectedSacrificeId = cand.id),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              key: Key('forge_craft_button_${selectedRecipe.id}'),
              label: 'Tempa Mythical',
              icon: Icons.auto_fix_high,
              expand: true,
              onPressed: canCraft
                  ? () => _confirmAndCraftMythical(
                      recipe: selectedRecipe,
                      targetDef: targetDef,
                      sacrifice: selectedSacrifice,
                      catalystName: catalystName,
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _costRow({
    required String label,
    required int owned,
    required int requiredCount,
    required Color okColor,
    required Color errColor,
  }) {
    final ok = owned >= requiredCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Text(
            '${NumberFormatter.format(owned)} / ${NumberFormatter.format(requiredCount)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: ok ? okColor : errColor,
            ),
          ),
        ],
      ),
    );
  }
}
