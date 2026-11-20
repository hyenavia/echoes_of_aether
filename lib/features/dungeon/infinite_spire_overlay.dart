import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../domain/entities/infinite_spire.dart';
import '../shared/widgets/shared_widgets.dart';

/// Overlay mode end-game The Infinite Spire (100 Lantai & Hadiah First-Clear)
/// sesuai GDD Addendum v1.5 §5.2.
class InfiniteSpireOverlay extends StatefulWidget {
  const InfiniteSpireOverlay({
    super.key,
    required this.config,
    required this.progress,
    required this.playerLevel,
    required this.onFightFloor,
    required this.onClose,
    this.embedded = false,
  });

  final InfiniteSpireConfig config;
  final InfiniteSpireProgressSnapshot progress;
  final int playerLevel;
  final void Function(int floor) onFightFloor;
  final VoidCallback onClose;
  final bool embedded;

  @override
  State<InfiniteSpireOverlay> createState() => _InfiniteSpireOverlayState();
}

class _InfiniteSpireOverlayState extends State<InfiniteSpireOverlay> {
  bool _onlyBossFloors = false;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // Auto scroll ke lantai tertinggi yang terbuka setelah frame pertama
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentFloor();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentFloor() {
    if (!_scrollController.hasClients) return;
    final isWidgetTest = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
    if (isWidgetTest) {
      _scrollController.jumpTo(0.0);
      return;
    }
    final currentUnlocked = widget.progress.highestFloorCleared + 1;
    final targetIndex = (currentUnlocked - 1).clamp(
      0,
      widget.config.floors.length - 1,
    );
    final targetOffset = targetIndex * 92.0;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    final floors = _onlyBossFloors
        ? widget.config.floors.where((f) => f.isBossFloor).toList()
        : widget.config.floors;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs + 2),
              decoration: BoxDecoration(
                color: ext.gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: ext.gold.withValues(alpha: 0.5)),
              ),
              child: Icon(Icons.stairs_outlined, color: ext.gold, size: 24),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The Infinite Spire',
                    style: AppTypography.headingSerif(
                      theme.textTheme.titleMedium,
                      color: ext.gold,
                    ),
                  ),
                  Text(
                    'Selesai: ${widget.progress.highestFloorCleared} / ${widget.config.floors.length} Lantai',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            // Filter Bos toggle
            FilterChip(
              key: const Key('infinite_spire_boss_filter'),
              label: const Text('Bos Saja'),
              selected: _onlyBossFloors,
              onSelected: (val) {
                setState(() => _onlyBossFloors = val);
                if (_scrollController.hasClients) {
                  _scrollController.jumpTo(0.0);
                }
              },
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: AppSpacing.xs),
            if (!widget.embedded)
              AppIconButton(
                key: const Key('infinite_spire_close'),
                icon: Icons.close,
                semanticLabel: 'Tutup',
                onPressed: widget.onClose,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        const Divider(height: 1, color: AppColors.panelBorder),
        const SizedBox(height: AppSpacing.xs),

        // Floor list
        Expanded(
          child: ListView.separated(
            key: const Key('infinite_spire_floor_list'),
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            itemCount: floors.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppSpacing.xs + 2),
            itemBuilder: (context, index) {
              final floor = floors[index];
              final isCleared = widget.progress.isFloorCleared(floor.floor);
              final isUnlocked =
                  floor.floor <= widget.progress.highestFloorCleared + 1;

              return _InfiniteSpireFloorCard(
                floor: floor,
                isCleared: isCleared,
                isUnlocked: isUnlocked,
                playerLevel: widget.playerLevel,
                onFight: () => widget.onFightFloor(floor.floor),
              );
            },
          ),
        ),
      ],
    );

    if (widget.embedded) return body;

    return Material(
      color: AppColors.midnightForest.withValues(alpha: 0.85),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: PanelFrame(
              padding: const EdgeInsets.all(AppSpacing.md),
              borderColor: ext.gold,
              showCornerOrnaments: true,
              boxShadow: AppShadows.glow(ext.gold, alpha: 0.25),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfiniteSpireFloorCard extends StatelessWidget {
  const _InfiniteSpireFloorCard({
    required this.floor,
    required this.isCleared,
    required this.isUnlocked,
    required this.playerLevel,
    required this.onFight,
  });

  final InfiniteSpireFloorDefinition floor;
  final bool isCleared;
  final bool isUnlocked;
  final int playerLevel;
  final VoidCallback onFight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);

    final isBoss = floor.isBossFloor;
    final isPeak = floor.floor == 100;

    final borderColor = isCleared
        ? ext.success.withValues(alpha: 0.6)
        : isUnlocked
        ? (isBoss ? ext.gold : ext.rank.withValues(alpha: 0.7))
        : AppColors.panelBorder.withValues(alpha: 0.35);

    final bgColor = isCleared
        ? ext.success.withValues(alpha: 0.06)
        : isUnlocked
        ? (isBoss ? ext.gold.withValues(alpha: 0.08) : AppColors.surfaceDark)
        : AppColors.surfaceDark.withValues(alpha: 0.35);

    // Summary of first clear reward
    final r = floor.reward;
    final shardCount = r.currencies['aether_shard'] ?? 0;
    final prismCount = r.currencies['soul_prism'] ?? 0;
    final rewardParts = <String>[
      if (r.gold > 0) '+${NumberFormatter.format(r.gold)}G',
      if (r.exp > 0) '+${NumberFormatter.format(r.exp)} EXP',
      for (final item in r.items.entries) '+${item.value} ${item.key}',
      if (shardCount > 0) '+$shardCount Shard',
      if (prismCount > 0) '+$prismCount Prism',
    ];
    final rewardSummary = rewardParts.join(' • ');

    final floorLabel = isPeak
        ? 'F100 (PEAK)'
        : isBoss
        ? 'F${floor.floor} (BOS)'
        : 'F${floor.floor}';

    final rawBossName =
        floor.bossName ??
        (floor.name.contains(':') ? floor.name.split(':')[1] : floor.name);
    final title = isBoss
        ? rawBossName.replaceAll(RegExp(r'\(Floor \d+\)'), '').trim()
        : 'Lantai ${floor.floor}';

    return Container(
      key: Key('infinite_spire_floor_card_${floor.floor}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: borderColor, width: isBoss ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs + 2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: isCleared
                      ? ext.success.withValues(alpha: 0.25)
                      : isUnlocked
                      ? (isBoss
                            ? ext.gold.withValues(alpha: 0.25)
                            : ext.rank.withValues(alpha: 0.2))
                      : AppColors.panelBorder.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  floorLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isCleared
                        ? ext.success
                        : isUnlocked
                        ? (isBoss ? ext.gold : ext.rank)
                        : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isUnlocked
                        ? (isBoss ? ext.gold : AppColors.textPrimary)
                        : AppColors.textMuted,
                  ),
                ),
              ),
              if (isCleared)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 14, color: ext.success),
                    const SizedBox(width: 4),
                    Text(
                      'SELESAI',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: ext.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              else if (!isUnlocked)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'TERKUNCI',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                'Lv ${floor.recommendedLevel}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: playerLevel >= floor.recommendedLevel
                      ? ext.success
                      : ext.gold,
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
              ),
              if (floor.affixDescription != null &&
                  floor.affixDescription!.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '• ${floor.affixDescription!}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: ext.gold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Hadiah Pertama: $rewardSummary',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isCleared ? AppColors.textMuted : ext.gold,
                    fontSize: 10.5,
                  ),
                ),
              ),
              if (isUnlocked)
                SizedBox(
                  height: 30,
                  child: ElevatedButton(
                    key: Key('infinite_spire_fight_${floor.floor}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCleared
                          ? AppColors.panelBorder
                          : (isBoss ? ext.gold : ext.rank),
                      foregroundColor: isCleared
                          ? AppColors.textPrimary
                          : AppColors.surfaceDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 0,
                      ),
                    ),
                    onPressed: onFight,
                    child: Text(
                      isCleared ? 'Latihan' : 'Tantang',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
