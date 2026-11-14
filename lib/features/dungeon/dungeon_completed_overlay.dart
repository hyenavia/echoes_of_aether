import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../domain/services/reward_processor.dart';
import '../shared/widgets/shared_widgets.dart';

/// Ditampilkan saat seluruh room dungeon berhasil diselesaikan (Stage 4–5).
class DungeonCompletedOverlay extends StatelessWidget {
  const DungeonCompletedOverlay({
    super.key,
    required this.dungeonName,
    required this.clearedRoomsCount,
    this.isFinalBoss = false,
    this.isAscension = false,
    this.previousAscensionRank,
    this.newAscensionRank,
    this.completionReward,
    this.onRetry,
    required this.onReturnToTown,
  });

  final String dungeonName;
  final int clearedRoomsCount;
  final bool isFinalBoss;
  final bool isAscension;
  final int? previousAscensionRank;
  final int? newAscensionRank;
  final GrantedReward? completionReward;
  final VoidCallback? onRetry;
  final VoidCallback onReturnToTown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    final reward = completionReward;
    final rankLabel = newAscensionRank != null
        ? (previousAscensionRank != null &&
                  newAscensionRank! > previousAscensionRank!
              ? 'Ascension Rank $previousAscensionRank → Rank $newAscensionRank'
              : 'Ascension Rank $newAscensionRank')
        : null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: PanelFrame(
            padding: const EdgeInsets.all(AppSpacing.xl),
            borderColor: isAscension ? ext.rank : ext.gold,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAscension
                      ? Icons.auto_awesome_outlined
                      : Icons.emoji_events_outlined,
                  size: 36,
                  color: isAscension ? ext.rank : ext.gold,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  isAscension ? 'Ascension Selesai!' : 'Dungeon Selesai!',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: isAscension ? ext.rank : ext.gold,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (isFinalBoss) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: ext.hpBar.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: ext.hpBar.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      'Final Boss',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: ext.hpBar,
                      ),
                    ),
                  ),
                ],
                if (rankLabel != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    rankLabel,
                    key: const Key('ascension_rank_result'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: ext.rank,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Siklus baru dimulai — Farm Dungeon direset ke Dungeon 1.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '$dungeonName ditaklukkan ($clearedRoomsCount room selesai).',
                  textAlign: TextAlign.center,
                ),
                if (reward != null && !reward.alreadyClaimed) ...[
                  const SizedBox(height: AppSpacing.md),
                  PanelFrame(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    backgroundColor: AppColors.surfaceDark,
                    child: Column(
                      children: [
                        Text(
                          '+${NumberFormatter.format(reward.expGranted)} EXP • '
                          '+${NumberFormatter.format(reward.goldGranted)} Gold'
                          '${reward.levelsGained > 0 ? ' • Naik ${NumberFormatter.format(reward.levelsGained)} Level!' : ''}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: ext.gold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (reward.displayParts.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Hadiah: ${reward.displayParts.join(', ')}',
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    if (onRetry == null)
                      PrimaryButton(
                        label: 'Kembali ke Town',
                        onPressed: onReturnToTown,
                      )
                    else ...[
                      SecondaryButton(
                        label: 'Kembali ke Town',
                        onPressed: onReturnToTown,
                      ),
                      PrimaryButton(label: 'Run baru', onPressed: onRetry),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
