import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../domain/entities/dungeon_definition.dart';
import '../../domain/entities/shop_config.dart';
import '../../domain/services/event_shop_service.dart';
import '../shared/widgets/shared_widgets.dart';
import 'boss_events_overlay.dart';
import 'equipment_text.dart';
import 'item_filter_widgets.dart';

/// Tab fungsional Weekly Event Shop di dalam `ShopOverlay` (M13 Stage 3).
/// Hanya menampilkan state read-only dari domain (`EventShopViewData`) dan
/// mengirim intent pembelian setelah dialog konfirmasi; tidak menyimpan logika
/// harga maupun evaluasi requirement di widget.
class EventShopView extends StatefulWidget {
  const EventShopView({
    super.key,
    required this.data,
    required this.dungeons,
    required this.onBuy,
  });

  final EventShopViewData data;
  final Map<String, DungeonDefinition> dungeons;
  final Future<EventShopBuyResult> Function(String entryId) onBuy;

  @override
  State<EventShopView> createState() => _EventShopViewState();
}

class _EventShopViewState extends State<EventShopView> {
  String? _feedbackMessage;
  bool _feedbackIsError = false;
  bool _busy = false;

  Future<void> _handleBuy(EventShopOfferView offer) async {
    if (_busy || !offer.canAttemptBuy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Pembelian Event'),
        content: Text(
          'Beli ${offer.item.name} seharga '
          '${NumberFormatter.format(offer.entry.price)} Aether Shard?\n'
          'Item event memiliki stat tetap dan tidak dapat dijual kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('event_shop_confirm_buy'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Konfirmasi Beli'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final result = await widget.onBuy(offer.entry.id);
      if (!mounted) return;
      setState(() {
        switch (result) {
          case EventShopBuySuccess(:final currencySpent):
            _feedbackIsError = false;
            _feedbackMessage =
                'Berhasil membeli ${offer.item.name} (${NumberFormatter.format(currencySpent)} Aether Shard).';
          case EventShopBuyInsufficientCurrency(
            :final requiredAmount,
            :final currentBalance,
          ):
            _feedbackIsError = true;
            _feedbackMessage =
                'Aether Shard tidak cukup (butuh ${NumberFormatter.format(requiredAmount)}, '
                'dimiliki ${NumberFormatter.format(currentBalance)}).';
          case EventShopBuyRequirementNotMet(:final failedRequirements):
            _feedbackIsError = true;
            _feedbackMessage =
                'Syarat belum terpenuhi: ${failedRequirements.map(_describeRequirement).join(', ')}.';
          case EventShopBuyInventoryFull():
            _feedbackIsError = true;
            _feedbackMessage = 'Tas penuh! Kosongkan ruang terlebih dahulu.';
          case EventShopBuyLimitReached(:final limit):
            _feedbackIsError = true;
            _feedbackMessage = 'Batas mingguan tercapai ($limit/$limit).';
          case EventShopBuyNotInRotation():
            _feedbackIsError = true;
            _feedbackMessage = 'Item tidak masuk rotasi minggu ini.';
          case EventShopBuyNotFound():
            _feedbackIsError = true;
            _feedbackMessage = 'Item event tidak ditemukan.';
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    final countdown = BossEventsOverlay.formatCountdown(
      widget.data.remainingToReset,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ResourceChip.aetherShard(
                widget.data.balance,
                key: const Key('event_shop_shard_balance'),
              ),
              Text(
                'Pergantian minggu: $countdown',
                key: const Key('event_shop_reset_countdown'),
                style: AppTypography.numeric(
                  theme.textTheme.labelMedium,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (_feedbackMessage != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Container(
            key: const Key('event_shop_feedback'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: (_feedbackIsError ? theme.colorScheme.error : ext.success)
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color:
                    (_feedbackIsError ? theme.colorScheme.error : ext.success)
                        .withValues(alpha: 0.45),
              ),
            ),
            child: Text(
              _feedbackMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _feedbackIsError ? theme.colorScheme.error : ext.success,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: widget.data.offers.isEmpty
              ? const Center(
                  child: SingleChildScrollView(
                    child: EmptyState(
                      icon: Icons.event_busy_outlined,
                      title: 'Event Shop minggu ini belum tersedia.',
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: widget.data.offers.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final offer = widget.data.offers[index];
                    final def = offer.item;
                    final statText = def.equipment != null
                        ? '${slotLabel(def.equipment!.slot)} • '
                              '${describeEquipmentStats(def.equipment!.baseStats)}'
                        : def.category.name;
                    final requirementSummary = offer.entry.requirements
                        .map(_describeRequirement)
                        .join(', ');

                    return PanelFrame(
                      key: Key('event_shop_card_${offer.entry.id}'),
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
                                    buildItemCategoryBadge(
                                      theme,
                                      itemCategoryBadgeLabel(def),
                                    ),
                                    buildItemRarityBadge(theme, def.rarity),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  statText,
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Harga: ${NumberFormatter.format(offer.entry.price)} Aether Shard'
                                  ' • Batas: ${offer.purchasedCount}/${offer.weeklyLimit}'
                                  ' • Tidak dapat dijual',
                                  style: AppTypography.numeric(
                                    theme.textTheme.labelMedium?.copyWith(
                                      color: offer.canAfford
                                          ? ext.gold
                                          : theme.colorScheme.error,
                                    ),
                                  ),
                                ),
                                if (!offer.requirementsMet)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: LockedBadge(
                                      label:
                                          'Syarat belum terpenuhi: '
                                          '${offer.requirementCheck.failedRequirements.map(_describeRequirement).join(', ')}',
                                    ),
                                  )
                                else if (offer.entry.requirements.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Syarat terpenuhi: $requirementSummary',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: ext.success),
                                    ),
                                  ),
                                if (offer.limitReached)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: LockedBadge(
                                      label:
                                          'Sudah dibeli minggu ini (${offer.purchasedCount}/${offer.weeklyLimit})',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            key: Key('event_shop_buy_${offer.entry.id}'),
                            onPressed: !_busy && offer.canAttemptBuy
                                ? () => _handleBuy(offer)
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
}
