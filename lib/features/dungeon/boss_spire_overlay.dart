import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../domain/entities/boss_spire.dart';
import '../shared/widgets/shared_widgets.dart';
import 'boss_events_overlay.dart';

/// Layar/overlay untuk melihat dan menantang Menara Bos (Boss Spire Floor 1-20+).
class BossSpireOverlay extends StatelessWidget {
  const BossSpireOverlay({
    super.key,
    required this.config,
    required this.progress,
    required this.playerLevel,
    required this.onFightFloor,
    required this.onClose,
    this.remainingToReset,
    this.embedded = false,
  });

  final BossSpireConfig config;
  final BossSpireProgress progress;
  final int playerLevel;
  final void Function(int floor) onFightFloor;
  final VoidCallback onClose;
  final Duration? remainingToReset;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: ext.rank.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(Icons.castle_outlined, color: ext.rank, size: 24),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.xs,
                    children: [
                      Text(
                        'Selesai: ${progress.clearedFloors.length} / ${config.maxFloor} Lantai',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ext.gold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (remainingToReset != null) ...[
                        const Text(
                          '•',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                        Icon(Icons.timer_outlined, size: 12, color: ext.rank),
                        Text(
                          'Reset: ${BossEventsOverlay.formatCountdown(remainingToReset!)}',
                          style: TextStyle(
                            color: ext.rank,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (!embedded)
              IconButton(
                key: const Key('boss_spire_close'),
                onPressed: onClose,
                icon: const Icon(Icons.close),
                tooltip: 'Tutup',
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        const Divider(height: 1, color: AppColors.panelBorder),
        const SizedBox(height: AppSpacing.sm),

        // Floor list
        Expanded(
          child: ListView.separated(
            key: const Key('boss_spire_floor_list'),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            itemCount: config.floors.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final floor = config.floors[index];
              final isCleared = progress.isFloorCleared(floor.floor);
              final isUnlocked = progress.isFloorUnlocked(floor.floor);

              return _SpireFloorCard(
                floor: floor,
                isCleared: isCleared,
                isUnlocked: isUnlocked,
                playerLevel: playerLevel,
                onFight: () => onFightFloor(floor.floor),
              );
            },
          ),
        ),
      ],
    );

    if (embedded) return body;

    return Material(
      color: AppColors.midnightForest.withValues(alpha: 0.82),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: PanelFrame(
              padding: const EdgeInsets.all(AppSpacing.lg),
              borderColor: ext.rank,
              showCornerOrnaments: true,
              boxShadow: AppShadows.glow(ext.rank, alpha: 0.25),
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

class _SpireFloorCard extends StatelessWidget {
  const _SpireFloorCard({
    required this.floor,
    required this.isCleared,
    required this.isUnlocked,
    required this.playerLevel,
    required this.onFight,
  });

  final BossSpireFloorConfig floor;
  final bool isCleared;
  final bool isUnlocked;
  final int playerLevel;
  final VoidCallback onFight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);

    final borderColor = isCleared
        ? ext.success.withValues(alpha: 0.6)
        : isUnlocked
        ? ext.rank.withValues(alpha: 0.8)
        : AppColors.panelBorder.withValues(alpha: 0.4);

    final bgColor = isCleared
        ? ext.success.withValues(alpha: 0.05)
        : isUnlocked
        ? AppColors.surfaceDark
        : AppColors.surfaceDark.withValues(alpha: 0.4);

    // Format rewards summary
    final shardCount = floor.firstClearReward.currency['aether_shard'] ?? 0;
    final rewardParts = <String>[
      if (floor.firstClearReward.gold > 0)
        '+${NumberFormatter.format(floor.firstClearReward.gold)} Gold',
      if (floor.firstClearReward.exp > 0)
        '+${NumberFormatter.format(floor.firstClearReward.exp)} EXP',
      if (shardCount > 0) '+$shardCount Shard',
    ];
    final rewardSummary = rewardParts.join(' • ');

    return Container(
      key: Key('spire_floor_card_${floor.floor}'),
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: borderColor, width: isUnlocked ? 1.5 : 1),
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
                      ? ext.rank.withValues(alpha: 0.25)
                      : AppColors.panelBorder.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  'F${floor.floor}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isCleared
                        ? ext.success
                        : isUnlocked
                        ? ext.rank
                        : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  floor.bossName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isUnlocked
                        ? AppColors.textPrimary
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
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text(
                'Lv ${floor.recommendedLevel}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: playerLevel >= floor.recommendedLevel
                      ? ext.success
                      : ext.gold,
                  fontWeight: FontWeight.w500,
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
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Hadiah Pertama: $rewardSummary',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isCleared ? AppColors.textMuted : ext.gold,
                    fontSize: 11,
                  ),
                ),
              ),
              if (isUnlocked)
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    key: Key('spire_fight_${floor.floor}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isCleared
                          ? AppColors.panelBorder
                          : ext.rank,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 0,
                      ),
                    ),
                    onPressed: onFight,
                    child: Text(
                      isCleared ? 'Ulang' : 'Tantang',
                      style: const TextStyle(
                        fontSize: 12,
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
