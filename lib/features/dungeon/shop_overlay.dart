import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../domain/entities/dungeon_definition.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/entities/inventory.dart';
import '../../domain/entities/item_definition.dart';
import '../../domain/entities/mystery_box.dart';
import '../../domain/entities/shop_config.dart';
import '../../domain/services/event_shop_service.dart';
import '../../domain/services/mystery_box_service.dart';
import '../../domain/services/shop_service.dart';
import '../../game/hud/inventory_views.dart';
import '../shared/widgets/shared_widgets.dart';
import 'equipment_text.dart';
import 'event_shop_view.dart';
import 'item_filter_widgets.dart';

/// Overlay Toko di Town Hub (M10 Stage 3).
/// Hanya menampilkan state dari domain dan mengirim intent beli/jual ke
/// [ShopService] melalui callback; tidak menyimpan state gameplay sendiri.
class ShopOverlay extends StatefulWidget {
  const ShopOverlay({
    super.key,
    required this.catalog,
    required this.items,
    required this.dungeons,
    required this.shopService,
    required this.playerContext,
    required this.playerGold,
    required this.views,
    required this.onBuy,
    required this.onSellEquipment,
    required this.onSellMaterialBulk,
    this.onSellBatch,
    this.eventShopData,
    this.onBuyEventItem,
    this.onOpenMysteryBox,
    required this.onClose,
  });

  final ShopCatalog catalog;
  final Map<String, ItemDefinition> items;
  final Map<String, DungeonDefinition> dungeons;
  final ShopService shopService;
  final ShopPlayerContext playerContext;
  final int playerGold;
  final InventoryViews views;
  final Future<ShopBuyResult> Function(String entryId) onBuy;
  final Future<ShopSellResult> Function(String instanceId) onSellEquipment;
  final Future<ShopSellResult> Function(String itemId, int quantity)
  onSellMaterialBulk;
  final Future<ShopSellResult> Function(
    List<String> equipmentInstanceIds,
    Map<String, int> materialQuantities,
  )?
  onSellBatch;
  final EventShopViewData? eventShopData;
  final Future<EventShopBuyResult> Function(String entryId)? onBuyEventItem;
  final Future<MysteryBoxOpenResult> Function(MysteryBoxTier tier, int count)?
  onOpenMysteryBox;
  final VoidCallback onClose;

  @override
  State<ShopOverlay> createState() => _ShopOverlayState();
}

class _ShopOverlayState extends State<ShopOverlay> {
  String? _feedbackMessage;
  bool _feedbackIsError = false;
  bool _busy = false;
  ItemCategoryFilter _buyCategoryFilter = ItemCategoryFilter.all;
  ItemRarity? _buyRarityFilter;
  ItemCategoryFilter _sellCategoryFilter = ItemCategoryFilter.all;
  ItemRarity? _sellRarityFilter;
  final Set<String> _selectedEquipmentIds = {};
  final Set<String> _selectedMaterialIds = {};

  Future<void> _handleBuy(ShopEntry entry, ItemDefinition def) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await widget.onBuy(entry.id);
      if (!mounted) return;
      setState(() {
        switch (result) {
          case ShopBuySuccess(:final goldSpent):
            _feedbackIsError = false;
            _feedbackMessage =
                'Berhasil membeli ${def.name} (${NumberFormatter.format(goldSpent)} Gold).';
          case ShopBuyInsufficientGold(:final requiredGold, :final currentGold):
            _feedbackIsError = true;
            _feedbackMessage =
                'Gold tidak cukup (butuh ${NumberFormatter.format(requiredGold)}, dimiliki ${NumberFormatter.format(currentGold)}).';
          case ShopBuyRequirementNotMet(:final failedRequirements):
            _feedbackIsError = true;
            _feedbackMessage =
                'Syarat belum terpenuhi: ${failedRequirements.map(_describeRequirement).join(', ')}.';
          case ShopBuyInventoryFull():
            _feedbackIsError = true;
            _feedbackMessage = 'Tas penuh! Kosongkan ruang terlebih dahulu.';
          case ShopBuyLimitReached(:final limit):
            _feedbackIsError = true;
            _feedbackMessage = 'Batas pembelian tercapai ($limit/$limit).';
          case ShopBuyNotFound():
            _feedbackIsError = true;
            _feedbackMessage = 'Barang tidak ditemukan di toko.';
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleOpenMysteryBox(MysteryBoxTier tier, int count) async {
    if (_busy || widget.onOpenMysteryBox == null) return;
    setState(() => _busy = true);
    try {
      final result = await widget.onOpenMysteryBox!(tier, count);
      if (!mounted) return;
      setState(() {
        if (result.isSuccess) {
          _feedbackIsError = false;
          _feedbackMessage =
              'Berhasil membuka ${result.itemsObtained.length}x peti! Perlengkapan tersimpan di tas.';
        } else {
          _feedbackIsError = true;
          switch (result.status) {
            case MysteryBoxOpenStatus.insufficientGold:
              _feedbackMessage = 'Gold tidak mencukupi untuk membuka peti.';
            case MysteryBoxOpenStatus.inventoryFull:
              _feedbackMessage =
                  'Tas perlengkapan penuh! Kosongkan ruang terlebih dahulu.';
            case MysteryBoxOpenStatus.underLevel:
              _feedbackMessage =
                  'Level karakter belum mencukupi untuk membuka peti ini.';
            case MysteryBoxOpenStatus.noEligibleItems:
            case MysteryBoxOpenStatus.unknownTier:
            default:
              _feedbackMessage = 'Gagal membuka peti misteri.';
          }
        }
      });
      if (result.isSuccess && result.itemsObtained.isNotEmpty && mounted) {
        await _showMysteryBoxRevealDialog(result.itemsObtained);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showMysteryBoxRevealDialog(
    List<EquipmentInstance> itemsObtained,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.panelDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: const BorderSide(color: AppColors.antiqueGold, width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.antiqueGold, size: 20),
              SizedBox(width: AppSpacing.sm),
              Text(
                'Hasil Peti Misteri',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < itemsObtained.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.sm),
                      _buildRevealedEquipmentItem(itemsObtained[i]),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.antiqueGold,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Simpan ke Tas'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRevealedEquipmentItem(EquipmentInstance item) {
    final def = widget.items[item.definitionId];
    final itemName = def?.name ?? item.definitionId;
    final rarityColor = AppColors.colorForRarity(item.rarity);
    final slot = slotLabel(item.slot);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.panelElevated,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: rarityColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs + 2),
            decoration: BoxDecoration(
              color: rarityColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: PixelItemIcon(
              itemId: item.definitionId,
              size: 20,
              fallbackIcon: _slotIcon(item.slot),
              fallbackColor: rarityColor,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemName,
                  style: TextStyle(
                    color: rarityColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$slot • ${_rarityLabel(item.rarity)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  describeEquipmentStats(item.effectiveStats),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _slotIcon(EquipmentSlot slot) => switch (slot) {
    EquipmentSlot.weapon => Icons.colorize,
    EquipmentSlot.head => Icons.face,
    EquipmentSlot.body => Icons.shield_outlined,
    EquipmentSlot.accessory => Icons.all_inclusive,
  };

  Future<void> _handleSellEquipment(
    EquipmentInstance instance,
    ItemDefinition def,
    int sellPrice,
  ) async {
    if (_busy) return;
    if (_requiresConfirmation(def.rarity)) {
      final confirmed = await _confirmRareSale(
        itemName: def.name,
        rarity: def.rarity,
        quantity: 1,
        totalGold: sellPrice,
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _busy = true);
    try {
      final result = await widget.onSellEquipment(instance.id);
      if (!mounted) return;
      _applySellFeedback(result, def.name);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleSellMaterialBulk(InventoryEntry entry) async {
    if (_busy) return;
    final unitPrice = widget.shopService.effectiveSellUnitPrice(
      entry.definition,
    );
    final selectedQty = await _showBulkSellDialog(
      itemName: entry.definition.name,
      rarity: entry.definition.rarity,
      maxQuantity: entry.quantity,
      unitPrice: unitPrice,
    );
    if (selectedQty == null || selectedQty <= 0 || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await widget.onSellMaterialBulk(
        entry.definition.id,
        selectedQty,
      );
      if (!mounted) return;
      _applySellFeedback(result, entry.definition.name);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _applySellFeedback(ShopSellResult result, String itemName) {
    setState(() {
      switch (result) {
        case ShopSellSuccess(:final goldEarned, :final quantitySold):
          _feedbackIsError = false;
          _feedbackMessage =
              'Menjual ${quantitySold}x $itemName (+${NumberFormatter.format(goldEarned)} Gold).';
        case ShopSellNotFound():
          _feedbackIsError = true;
          _feedbackMessage = '$itemName tidak ditemukan di tas.';
        case ShopSellNotSellable(:final reason):
          _feedbackIsError = true;
          _feedbackMessage = reason;
      }
    });
  }

  bool _requiresConfirmation(ItemRarity rarity) =>
      rarity.index >= widget.catalog.sell.confirmMinRarity.index;

  Future<bool?> _confirmBatchSale({
    required String title,
    required int totalUnits,
    required int totalGold,
    required List<String> epicPlusNames,
    required bool hasRare,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Jual $totalUnits item dengan total '
              '${NumberFormatter.format(totalGold)} Gold?',
            ),
            if (epicPlusNames.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: AppColors.emberRed.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.emberRed.withValues(alpha: 0.65),
                  ),
                ),
                child: Text(
                  'PERINGATAN Epic+: Termasuk ${epicPlusNames.length} item '
                  'Epic/Legendary (${epicPlusNames.take(5).join(', ')}'
                  '${epicPlusNames.length > 5 ? ', ...' : ''}).',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: AppColors.emberRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ] else if (hasRare) ...[
              const SizedBox(height: 8),
              Text(
                'Catatan: Termasuk item Rare.',
                style: TextStyle(
                  color: _rarityColor(ItemRarity.rare),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Jual'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeBatchSell({
    required List<EquipmentInstance> equipments,
    required List<InventoryEntry> materials,
    required bool alwaysConfirm,
    required String confirmTitle,
  }) async {
    if (_busy || (equipments.isEmpty && materials.isEmpty)) return;
    var totalGold = 0;
    var totalUnits = 0;
    var hasRare = false;
    final epicPlusNames = <String>[];

    for (final instance in equipments) {
      final def = widget.items[instance.definitionId];
      if (def == null) continue;
      totalGold += widget.shopService.effectiveSellUnitPrice(def);
      totalUnits += 1;
      if (def.rarity.index >= ItemRarity.epic.index) {
        epicPlusNames.add('${def.name} (${_rarityLabel(def.rarity)})');
      } else if (_requiresConfirmation(def.rarity)) {
        hasRare = true;
      }
    }
    for (final entry in materials) {
      final def = entry.definition;
      totalGold +=
          widget.shopService.effectiveSellUnitPrice(def) * entry.quantity;
      totalUnits += entry.quantity;
      if (def.rarity.index >= ItemRarity.epic.index) {
        epicPlusNames.add(
          '${entry.quantity}x ${def.name} (${_rarityLabel(def.rarity)})',
        );
      } else if (_requiresConfirmation(def.rarity)) {
        hasRare = true;
      }
    }

    if (alwaysConfirm || epicPlusNames.isNotEmpty || hasRare) {
      final confirmed = await _confirmBatchSale(
        title: confirmTitle,
        totalUnits: totalUnits,
        totalGold: totalGold,
        epicPlusNames: epicPlusNames,
        hasRare: hasRare,
      );
      if (confirmed != true || !mounted) return;
    }

    final eqIds = [for (final e in equipments) e.id];
    final matQtys = {for (final m in materials) m.definition.id: m.quantity};

    setState(() => _busy = true);
    try {
      final ShopSellResult result;
      if (widget.onSellBatch != null) {
        result = await widget.onSellBatch!(eqIds, matQtys);
      } else {
        result = await _sellBatchFallback(eqIds, matQtys);
      }
      if (!mounted) return;
      if (result is ShopSellSuccess) {
        _selectedEquipmentIds.removeAll(eqIds);
        _selectedMaterialIds.removeAll(matQtys.keys);
      }
      _applySellFeedback(result, '$totalUnits item');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<ShopSellResult> _sellBatchFallback(
    List<String> eqIds,
    Map<String, int> matQtys,
  ) async {
    var totalEarned = 0;
    var totalSold = 0;
    var lastGold = widget.playerGold;
    for (final id in eqIds) {
      final res = await widget.onSellEquipment(id);
      if (res is! ShopSellSuccess) return res;
      totalEarned += res.goldEarned;
      totalSold += res.quantitySold;
      lastGold = res.remainingGold;
    }
    for (final entry in matQtys.entries) {
      final res = await widget.onSellMaterialBulk(entry.key, entry.value);
      if (res is! ShopSellSuccess) return res;
      totalEarned += res.goldEarned;
      totalSold += res.quantitySold;
      lastGold = res.remainingGold;
    }
    return ShopSellSuccess(
      goldEarned: totalEarned,
      remainingGold: lastGold,
      quantitySold: totalSold,
      itemId: 'batch',
    );
  }

  Future<bool?> _confirmRareSale({
    required String itemName,
    required ItemRarity rarity,
    required int quantity,
    required int totalGold,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Penjualan'),
        content: Text(
          'Jual ${quantity}x $itemName (${_rarityLabel(rarity)}) '
          'seharga ${NumberFormatter.format(totalGold)} Gold?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Jual'),
          ),
        ],
      ),
    );
  }

  Future<int?> _showBulkSellDialog({
    required String itemName,
    required ItemRarity rarity,
    required int maxQuantity,
    required int unitPrice,
  }) {
    var qty = maxQuantity;
    return showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final totalGold = unitPrice * qty;
          final isRare = _requiresConfirmation(rarity);
          return AlertDialog(
            title: Text('Jual $itemName'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${_rarityLabel(rarity)} • ${NumberFormatter.format(unitPrice)} Gold / item',
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: qty > 1
                          ? () => setDialogState(() => qty--)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '$qty / $maxQuantity',
                        style: AppTypography.numeric(
                          Theme.of(ctx).textTheme.titleMedium,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: qty < maxQuantity
                          ? () => setDialogState(() => qty++)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => setDialogState(() => qty = 1),
                      child: const Text('1'),
                    ),
                    OutlinedButton(
                      onPressed: maxQuantity >= 2
                          ? () => setDialogState(
                              () => qty = math.max(1, maxQuantity ~/ 2),
                            )
                          : null,
                      child: const Text('1/2'),
                    ),
                    OutlinedButton(
                      onPressed: () => setDialogState(() => qty = maxQuantity),
                      child: const Text('Semua'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Total: ${NumberFormatter.format(totalGold)} Gold',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.titleSmall,
                ),
                if (isRare) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Item langka (${_rarityLabel(rarity)}): pastikan sebelum menjual.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _rarityColor(rarity), fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(qty),
                child: const Text('Konfirmasi Jual'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _describeRequirement(PurchaseRequirement req) => switch (req) {
    MinLevelRequirement(:final minLevel) =>
      'Min Lv ${NumberFormatter.format(minLevel)}',
    DungeonClearedRequirement(:final dungeonId) =>
      'Selesaikan ${widget.dungeons[dungeonId]?.name ?? dungeonId}',
    MinAscensionRankRequirement(:final minRank) =>
      'Min Ascension Rank $minRank',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    final hasEventTab =
        widget.eventShopData != null && widget.onBuyEventItem != null;
    final hasMysteryBoxTab = widget.onOpenMysteryBox != null;
    final tabCount = 2 + (hasMysteryBoxTab ? 1 : 0) + (hasEventTab ? 1 : 0);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
          child: PanelFrame(
            showCornerOrnaments: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: DefaultTabController(
              length: tabCount,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const AetherSymbolMark(
                        variant: AetherSymbolVariant.mark,
                        size: 18,
                        glow: true,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Toko',
                              style: AppTypography.headingSerif(
                                theme.textTheme.titleLarge,
                                color: ext.gold,
                              ),
                            ),
                            ResourceChip.gold(widget.playerGold),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      AppIconButton(
                        icon: Icons.close,
                        semanticLabel: 'Tutup Toko',
                        tooltip: 'Tutup',
                        size: 36,
                        iconSize: 18,
                        onPressed: widget.onClose,
                      ),
                    ],
                  ),
                  TabBar(
                    indicatorColor: ext.gold,
                    labelColor: ext.gold,
                    unselectedLabelColor: AppColors.textSecondary,
                    dividerColor: AppColors.panelBorder,
                    tabs: [
                      const Tab(text: 'Beli'),
                      const Tab(text: 'Jual'),
                      if (hasMysteryBoxTab) const Tab(text: 'Peti Misteri'),
                      if (hasEventTab) const Tab(text: 'Event'),
                    ],
                  ),
                  if (_feedbackMessage != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (_feedbackIsError
                                    ? theme.colorScheme.error
                                    : ext.success)
                                .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color:
                              (_feedbackIsError
                                      ? theme.colorScheme.error
                                      : ext.success)
                                  .withValues(alpha: 0.45),
                        ),
                      ),
                      child: Text(
                        _feedbackMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _feedbackIsError
                              ? theme.colorScheme.error
                              : ext.success,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Flexible(
                    child: TabBarView(
                      children: [
                        _buildBuyTab(theme, ext),
                        _buildSellTab(theme),
                        if (hasMysteryBoxTab) _buildMysteryBoxTab(theme, ext),
                        if (hasEventTab)
                          EventShopView(
                            data: widget.eventShopData!,
                            dungeons: widget.dungeons,
                            onBuy: widget.onBuyEventItem!,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar({
    required ItemCategoryFilter categoryFilter,
    required ItemRarity? rarityFilter,
    required bool includeMaterial,
    required ValueChanged<ItemCategoryFilter> onCategoryChanged,
    required ValueChanged<ItemRarity?> onRarityChanged,
  }) {
    return buildItemFilterBar(
      categories: [
        ItemCategoryFilter.all,
        ItemCategoryFilter.weapon,
        ItemCategoryFilter.head,
        ItemCategoryFilter.body,
        ItemCategoryFilter.accessory,
        if (includeMaterial) ItemCategoryFilter.material,
      ],
      categoryFilter: categoryFilter,
      rarityFilter: rarityFilter,
      onCategoryChanged: onCategoryChanged,
      onRarityChanged: onRarityChanged,
    );
  }

  Widget _buildMysteryBoxTab(ThemeData theme, EchoesThemeExtension ext) {
    const definitions = MysteryBoxDefinition.defaults;
    final playerLevel = widget.playerContext.playerLevel;
    final playerGold = widget.playerGold;

    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.panelDark.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.panelBorder),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: AppColors.antiqueGold,
                size: 16,
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Expanded(
                child: Text(
                  'Undi perlengkapan acak dengan statistik acak menggunakan Gold!',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (final def in definitions.values)
          _buildMysteryBoxCard(def, playerLevel, playerGold, theme, ext),
      ],
    );
  }

  Widget _buildMysteryBoxCard(
    MysteryBoxDefinition def,
    int playerLevel,
    int playerGold,
    ThemeData theme,
    EchoesThemeExtension ext,
  ) {
    final isLevelMet = playerLevel >= def.minLevel;
    final canAfford1 = playerGold >= def.goldCost;
    final canAfford5 = playerGold >= def.goldCost * 5;

    final Color tierColor = switch (def.tier) {
      MysteryBoxTier.novice => AppColors.rarityUncommon,
      MysteryBoxTier.warrior => AppColors.rarityRare,
      MysteryBoxTier.aether => AppColors.antiqueGold,
    };

    final IconData tierIcon = switch (def.tier) {
      MysteryBoxTier.novice => Icons.inventory_2_outlined,
      MysteryBoxTier.warrior => Icons.military_tech_outlined,
      MysteryBoxTier.aether => Icons.auto_awesome,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.panelElevated.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isLevelMet
              ? tierColor.withValues(alpha: 0.5)
              : AppColors.panelBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs + 2),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                ),
                child: Icon(tierIcon, color: tierColor, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      def.name,
                      style: TextStyle(
                        color: tierColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      def.description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: isLevelMet
                      ? AppColors.panelDark
                      : AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: isLevelMet
                        ? AppColors.panelBorder
                        : AppColors.danger.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'Syarat: Lv. ${def.minLevel}+',
                  style: TextStyle(
                    color: isLevelMet
                        ? AppColors.textSecondary
                        : AppColors.danger,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            def.describeProbabilities(),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                key: Key('mystery_box_open_1_${def.tier.name}'),
                onPressed: (isLevelMet && canAfford1 && !_busy)
                    ? () => _handleOpenMysteryBox(def.tier, 1)
                    : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 2,
                    vertical: AppSpacing.xs,
                  ),
                  side: BorderSide(
                    color: (isLevelMet && canAfford1)
                        ? tierColor.withValues(alpha: 0.8)
                        : AppColors.panelBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Buka 1x (', style: TextStyle(fontSize: 11)),
                    const Icon(
                      Icons.monetization_on,
                      size: 11,
                      color: AppColors.antiqueGold,
                    ),
                    Text(
                      '${NumberFormatter.format(def.goldCost)})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton(
                key: Key('mystery_box_open_5_${def.tier.name}'),
                onPressed: (isLevelMet && canAfford5 && !_busy)
                    ? () => _handleOpenMysteryBox(def.tier, 5)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: tierColor,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppColors.panelDark,
                  disabledForegroundColor: AppColors.textMuted,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 2,
                    vertical: AppSpacing.xs,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Buka 5x (',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Icon(
                      Icons.monetization_on,
                      size: 11,
                      color: Colors.black87,
                    ),
                    Text(
                      '${NumberFormatter.format(def.goldCost * 5)})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBuyTab(ThemeData theme, EchoesThemeExtension ext) {
    final entries = widget.catalog.entries;
    if (entries.isEmpty) {
      return const Center(
        child: SingleChildScrollView(
          child: EmptyState(
            icon: Icons.storefront_outlined,
            title: 'Toko belum memiliki barang.',
          ),
        ),
      );
    }
    final filtered = [
      for (final entry in entries)
        if (widget.items[entry.itemId] case final def?)
          if (_matchesFilters(def, _buyCategoryFilter, _buyRarityFilter)) entry,
    ];
    return Column(
      children: [
        _buildFilterBar(
          categoryFilter: _buyCategoryFilter,
          rarityFilter: _buyRarityFilter,
          includeMaterial: entries.any(
            (e) => widget.items[e.itemId]?.category == ItemCategory.material,
          ),
          onCategoryChanged: (next) =>
              setState(() => _buyCategoryFilter = next),
          onRarityChanged: (next) => setState(() => _buyRarityFilter = next),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: SingleChildScrollView(
                    child: EmptyState(
                      icon: Icons.filter_list_off,
                      title: 'Tidak ada barang yang sesuai filter.',
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    final def = widget.items[entry.itemId]!;
                    final reqCheck = widget.shopService.check(
                      entry,
                      widget.playerContext,
                    );
                    final purchasedCount = widget.playerContext
                        .purchasedCountFor(entry.id);
                    final limitReached =
                        entry.purchaseLimit != null &&
                        purchasedCount >= entry.purchaseLimit!;
                    final canPressBuy =
                        !_busy && reqCheck.isMet && !limitReached;

                    final statSummary = def.equipment != null
                        ? '${slotLabel(def.equipment!.slot)} • ${describeEquipmentStats(def.equipment!.baseStats)}'
                        : def.category.name;

                    return PanelFrame(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      backgroundColor: AppColors.surfaceDark,
                      borderColor: ext
                          .colorForRarity(def.rarity)
                          .withValues(alpha: 0.55),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      def.name,
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    _buildCategoryBadge(theme, def),
                                    _buildRarityBadge(theme, def.rarity),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  statSummary,
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Harga: ${NumberFormatter.format(entry.price)} Gold'
                                  '${entry.purchaseLimit != null ? ' • Batas: $purchasedCount/${entry.purchaseLimit}' : ''}',
                                  style: AppTypography.numeric(
                                    theme.textTheme.labelMedium?.copyWith(
                                      color: ext.gold,
                                    ),
                                  ),
                                ),
                                if (!reqCheck.isMet)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: LockedBadge(
                                      label:
                                          'Syarat belum terpenuhi: '
                                          '${reqCheck.failedRequirements.map(_describeRequirement).join(', ')}',
                                    ),
                                  )
                                else if (limitReached)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: LockedBadge(
                                      label: 'Batas pembelian tercapai',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: canPressBuy
                                ? () => _handleBuy(entry, def)
                                : null,
                            child: const Text('Beli'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSellTab(ThemeData theme) {
    return ValueListenableBuilder<EquipmentSnapshot>(
      valueListenable: widget.views.equipment,
      builder: (context, equipSnap, _) {
        return ValueListenableBuilder<List<InventoryEntry>>(
          valueListenable: widget.views.stacks,
          builder: (context, stackEntries, _) {
            final sellableBagEquipment = [
              for (final instance in equipSnap.bag)
                if (widget.items[instance.definitionId] case final def?)
                  if (def.sellable &&
                      widget.shopService.effectiveSellUnitPrice(def) > 0)
                    instance,
            ];
            final nonSellableBagEquipment = [
              for (final instance in equipSnap.bag)
                if (widget.items[instance.definitionId] case final def?)
                  if (!def.sellable ||
                      widget.shopService.effectiveSellUnitPrice(def) <= 0)
                    instance,
            ];
            final sellableStacks = [
              for (final s in stackEntries)
                if (s.definition.sellable &&
                    widget.catalog.sell.sellableCategories.contains(
                      s.definition.category,
                    ) &&
                    widget.shopService.effectiveSellUnitPrice(s.definition) > 0)
                  s,
            ];
            final equippedList = equipSnap.equipped.values.toList();
            if (equipSnap.bag.isEmpty &&
                sellableStacks.isEmpty &&
                equippedList.isEmpty) {
              return const Center(
                child: SingleChildScrollView(
                  child: EmptyState(
                    icon: Icons.sell_outlined,
                    title: 'Belum ada item untuk dijual.',
                  ),
                ),
              );
            }

            final filteredEquipment = [
              for (final instance in sellableBagEquipment)
                if (_matchesFilters(
                  widget.items[instance.definitionId]!,
                  _sellCategoryFilter,
                  _sellRarityFilter,
                ))
                  instance,
            ];
            final filteredNonSellableEquipment = [
              for (final instance in nonSellableBagEquipment)
                if (_matchesFilters(
                  widget.items[instance.definitionId]!,
                  _sellCategoryFilter,
                  _sellRarityFilter,
                ))
                  instance,
            ];
            final filteredMaterials = [
              for (final entry in sellableStacks)
                if (_matchesFilters(
                  entry.definition,
                  _sellCategoryFilter,
                  _sellRarityFilter,
                ))
                  entry,
            ];

            final selectedEquipments = [
              for (final instance in sellableBagEquipment)
                if (_selectedEquipmentIds.contains(instance.id)) instance,
            ];
            final selectedMaterials = [
              for (final entry in sellableStacks)
                if (_selectedMaterialIds.contains(entry.definition.id)) entry,
            ];
            final selectedCount =
                selectedEquipments.length + selectedMaterials.length;
            final selectedGold = _estimateBatchGold(
              selectedEquipments,
              selectedMaterials,
            );

            final junkEquipment = [
              for (final instance in sellableBagEquipment)
                if (!instance.isFavorite &&
                    (instance.rarity == ItemRarity.common ||
                        instance.rarity == ItemRarity.uncommon))
                  instance,
            ];
            final junkGold = _estimateBatchGold(junkEquipment, const []);

            final nonFavoriteFilteredEquipment = filteredEquipment
                .where((e) => !e.isFavorite)
                .toList();
            final allVisibleSelected =
                (nonFavoriteFilteredEquipment.isNotEmpty ||
                    filteredMaterials.isNotEmpty) &&
                nonFavoriteFilteredEquipment.every(
                  (e) => _selectedEquipmentIds.contains(e.id),
                ) &&
                filteredMaterials.every(
                  (m) => _selectedMaterialIds.contains(m.definition.id),
                );

            final hasVisibleSellables =
                nonFavoriteFilteredEquipment.isNotEmpty ||
                filteredMaterials.isNotEmpty;
            final hasAnySellables =
                sellableBagEquipment.isNotEmpty || sellableStacks.isNotEmpty;

            return Column(
              children: [
                _buildFilterBar(
                  categoryFilter: _sellCategoryFilter,
                  rarityFilter: _sellRarityFilter,
                  includeMaterial: widget.catalog.sell.sellableCategories
                      .contains(ItemCategory.material),
                  onCategoryChanged: (next) =>
                      setState(() => _sellCategoryFilter = next),
                  onRarityChanged: (next) =>
                      setState(() => _sellRarityFilter = next),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child:
                      (!hasVisibleSellables &&
                          filteredNonSellableEquipment.isEmpty &&
                          equippedList.isEmpty)
                      ? const Center(
                          child: SingleChildScrollView(
                            child: EmptyState(
                              icon: Icons.filter_list_off,
                              title: 'Tidak ada item yang sesuai filter.',
                            ),
                          ),
                        )
                      : CustomScrollView(
                          slivers: [
                            if (filteredEquipment.isNotEmpty) ...[
                              const SliverToBoxAdapter(
                                child: SectionHeader(
                                  title: 'Equipment di Tas',
                                  useSerif: true,
                                ),
                              ),
                              SliverList.builder(
                                itemCount: filteredEquipment.length,
                                itemBuilder: (context, index) =>
                                    _buildBagEquipmentTile(
                                      theme,
                                      filteredEquipment[index],
                                    ),
                              ),
                            ],
                            if (filteredMaterials.isNotEmpty) ...[
                              const SliverToBoxAdapter(
                                child: SectionHeader(
                                  title: 'Material',
                                  useSerif: true,
                                ),
                              ),
                              SliverList.builder(
                                itemCount: filteredMaterials.length,
                                itemBuilder: (context, index) =>
                                    _buildMaterialTile(
                                      theme,
                                      filteredMaterials[index],
                                    ),
                              ),
                            ],
                            if (filteredNonSellableEquipment.isNotEmpty) ...[
                              const SliverToBoxAdapter(
                                child: SectionHeader(
                                  title: 'Tidak Dapat Dijual',
                                  useSerif: true,
                                ),
                              ),
                              SliverList.builder(
                                itemCount: filteredNonSellableEquipment.length,
                                itemBuilder: (context, index) =>
                                    _buildNonSellableBagTile(
                                      theme,
                                      filteredNonSellableEquipment[index],
                                    ),
                              ),
                            ],
                            if (equippedList.isNotEmpty) ...[
                              const SliverToBoxAdapter(
                                child: SectionHeader(
                                  title: 'Sedang Dipakai (Tidak Bisa Dijual)',
                                  useSerif: true,
                                ),
                              ),
                              SliverList.builder(
                                itemCount: equippedList.length,
                                itemBuilder: (context, index) =>
                                    _buildEquippedReadOnlyTile(
                                      theme,
                                      equippedList[index],
                                    ),
                              ),
                            ],
                          ],
                        ),
                ),
                if (hasAnySellables) ...[
                  const Divider(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        onPressed: !_busy && hasVisibleSellables
                            ? () => setState(() {
                                if (allVisibleSelected) {
                                  for (final e in filteredEquipment) {
                                    _selectedEquipmentIds.remove(e.id);
                                  }
                                  for (final m in filteredMaterials) {
                                    _selectedMaterialIds.remove(
                                      m.definition.id,
                                    );
                                  }
                                } else {
                                  for (final e in filteredEquipment) {
                                    if (!e.isFavorite) {
                                      _selectedEquipmentIds.add(e.id);
                                    }
                                  }
                                  for (final m in filteredMaterials) {
                                    _selectedMaterialIds.add(m.definition.id);
                                  }
                                }
                              })
                            : null,
                        child: Text(
                          allVisibleSelected ? 'Batal Pilih' : 'Pilih Semua',
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const Key('sell_junk_equipment_button'),
                        icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                        label: Text(
                          junkEquipment.isNotEmpty
                              ? 'Jual Sampah (${junkEquipment.length} • +${NumberFormatter.format(junkGold)})'
                              : 'Jual Sampah (0)',
                        ),
                        onPressed: !_busy && junkEquipment.isNotEmpty
                            ? () => _executeBatchSell(
                                equipments: junkEquipment,
                                materials: const [],
                                alwaysConfirm: true,
                                confirmTitle:
                                    'Jual Semua Sampah (Common & Uncommon)',
                              )
                            : null,
                      ),
                      FilledButton.tonal(
                        onPressed: !_busy && selectedCount > 0
                            ? () => _executeBatchSell(
                                equipments: selectedEquipments,
                                materials: selectedMaterials,
                                alwaysConfirm: false,
                                confirmTitle: 'Jual Item Terpilih',
                              )
                            : null,
                        child: Text(
                          selectedCount > 0
                              ? 'Jual Terpilih ($selectedCount • +${NumberFormatter.format(selectedGold)})'
                              : 'Jual Terpilih',
                        ),
                      ),
                      FilledButton(
                        onPressed: !_busy && hasVisibleSellables
                            ? () => _executeBatchSell(
                                equipments: nonFavoriteFilteredEquipment,
                                materials: filteredMaterials,
                                alwaysConfirm: true,
                                confirmTitle:
                                    _sellCategoryFilter ==
                                            ItemCategoryFilter.all &&
                                        _sellRarityFilter == null
                                    ? 'Jual Semua Item'
                                    : 'Jual Semua (Terfilter)',
                              )
                            : null,
                        child: const Text('Jual Semua'),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  int _estimateBatchGold(
    List<EquipmentInstance> equipments,
    List<InventoryEntry> materials,
  ) {
    var total = 0;
    for (final instance in equipments) {
      final def = widget.items[instance.definitionId];
      if (def != null) {
        total += widget.shopService.effectiveSellUnitPrice(def);
      }
    }
    for (final entry in materials) {
      total +=
          widget.shopService.effectiveSellUnitPrice(entry.definition) *
          entry.quantity;
    }
    return total;
  }

  Widget _buildBagEquipmentTile(ThemeData theme, EquipmentInstance instance) {
    final def = widget.items[instance.definitionId];
    if (def == null) return const SizedBox.shrink();
    final ext = EchoesTheme.of(context);
    final sellPrice = widget.shopService.effectiveSellUnitPrice(def);
    final selected = _selectedEquipmentIds.contains(instance.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: PanelFrame(
        backgroundColor: AppColors.surfaceDark,
        borderColor: ext.colorForRarity(def.rarity).withValues(alpha: 0.45),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 2,
        ),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Checkbox(
            value: selected,
            onChanged: _busy || instance.isFavorite
                ? null
                : (val) => setState(() {
                    if (val == true) {
                      _selectedEquipmentIds.add(instance.id);
                    } else {
                      _selectedEquipmentIds.remove(instance.id);
                    }
                  }),
          ),
          title: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(def.name),
              _buildCategoryBadge(theme, def),
              _buildRarityBadge(theme, def.rarity),
              if (instance.isFavorite)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 14, color: ext.gold),
                    const SizedBox(width: 2),
                    Text(
                      'Favorit',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: ext.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final line in equipmentStatLines(instance.rolledStats))
                Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Text(
                    '• $line',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                'Jual: ${NumberFormatter.format(sellPrice)} Gold',
                style: AppTypography.numeric(theme.textTheme.bodySmall),
              ),
            ],
          ),
          isThreeLine: true,
          trailing: OutlinedButton(
            onPressed: !_busy && sellPrice > 0 && !instance.isFavorite
                ? () => _handleSellEquipment(instance, def, sellPrice)
                : null,
            child: Text(instance.isFavorite ? 'Favorit' : 'Jual'),
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialTile(ThemeData theme, InventoryEntry entry) {
    final ext = EchoesTheme.of(context);
    final unitPrice = widget.shopService.effectiveSellUnitPrice(
      entry.definition,
    );
    final selected = _selectedMaterialIds.contains(entry.definition.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: PanelFrame(
        backgroundColor: AppColors.surfaceDark,
        borderColor: ext
            .colorForRarity(entry.definition.rarity)
            .withValues(alpha: 0.45),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 2,
        ),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Checkbox(
            value: selected,
            onChanged: _busy
                ? null
                : (val) => setState(() {
                    if (val == true) {
                      _selectedMaterialIds.add(entry.definition.id);
                    } else {
                      _selectedMaterialIds.remove(entry.definition.id);
                    }
                  }),
          ),
          title: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('${entry.definition.name} (x${entry.quantity})'),
              _buildCategoryBadge(theme, entry.definition),
              _buildRarityBadge(theme, entry.definition.rarity),
            ],
          ),
          subtitle: Text(
            '${NumberFormatter.format(unitPrice)} Gold / item',
            style: AppTypography.numeric(theme.textTheme.bodySmall),
          ),
          trailing: OutlinedButton(
            onPressed: !_busy ? () => _handleSellMaterialBulk(entry) : null,
            child: const Text('Jual...'),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBadge(ThemeData theme, ItemDefinition def) =>
      buildItemCategoryBadge(theme, itemCategoryBadgeLabel(def));

  Widget _buildRarityBadge(ThemeData theme, ItemRarity rarity) =>
      buildItemRarityBadge(theme, rarity);

  bool _matchesFilters(
    ItemDefinition def,
    ItemCategoryFilter categoryFilter,
    ItemRarity? rarityFilter,
  ) => matchesItemFilters(def, categoryFilter, rarityFilter);

  Widget _buildEquippedReadOnlyTile(
    ThemeData theme,
    EquipmentInstance instance,
  ) => _buildReadOnlySellTile(
    theme: theme,
    instance: instance,
    reason: 'Sedang dipakai — tidak bisa dijual',
    buttonLabel: 'Dipakai',
  );

  Widget _buildNonSellableBagTile(ThemeData theme, EquipmentInstance instance) {
    final def = widget.items[instance.definitionId];
    final reason = (def != null && !def.sellable)
        ? 'Item tidak dapat dijual.'
        : 'Item tidak memiliki nilai jual.';
    return _buildReadOnlySellTile(
      theme: theme,
      instance: instance,
      reason: reason,
      buttonLabel: 'Tidak Dijual',
    );
  }

  Widget _buildReadOnlySellTile({
    required ThemeData theme,
    required EquipmentInstance instance,
    required String reason,
    required String buttonLabel,
  }) {
    final def = widget.items[instance.definitionId];
    final name = def?.name ?? instance.definitionId;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: PanelFrame(
        backgroundColor: AppColors.surfaceDark.withValues(alpha: 0.65),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 2,
        ),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Text(name, style: TextStyle(color: theme.colorScheme.outline)),
          subtitle: Text(reason),
          trailing: OutlinedButton(onPressed: null, child: Text(buttonLabel)),
        ),
      ),
    );
  }
}

String _rarityLabel(ItemRarity rarity) => itemRarityLabel(rarity);

Color _rarityColor(ItemRarity rarity) => itemRarityColor(rarity);
