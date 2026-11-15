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
    this.bossQuestMessage,
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
  final String? bossQuestMessage;
  final VoidCallback? onRetry;
  final VoidCallback onReturnToTown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    final reward = completionReward;
    final accentColor = isAscension ? ext.rank : ext.gold;
    final rankLabel = newAscensionRank != null
        ? (previousAscensionRank != null &&
                  newAscensionRank! > previousAscensionRank!
              ? 'Ascension Rank $previousAscensionRank → Rank $newAscensionRank'
              : 'Ascension Rank $newAscensionRank')
        : null;

    return ColoredBox(
      color: AppColors.midnightForest.withValues(alpha: 0.74),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: PanelFrame(
              padding: const EdgeInsets.all(AppSpacing.xl),
              borderColor: accentColor,
              showCornerOrnaments: true,
              boxShadow: AppShadows.glow(accentColor, alpha: 0.28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.28),
                          AppColors.surfaceDark,
                        ],
                      ),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.78),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      isAscension
                          ? Icons.auto_awesome_outlined
                          : Icons.emoji_events_outlined,
                      size: 30,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    isAscension ? 'Ascension Selesai!' : 'Dungeon Selesai!',
                    style: AppTypography.headingSerif(
                      theme.textTheme.headlineSmall ??
                          theme.textTheme.titleLarge,
                      color: accentColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (isFinalBoss) ...[
                    const SizedBox(height: AppSpacing.xs + 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm + 2,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: ext.hpBar.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: ext.hpBar.withValues(alpha: 0.55),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.whatshot_outlined,
                            size: 13,
                            color: ext.hpBar,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Final Boss',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: ext.hpBar,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (rankLabel != null) ...[
                    const SizedBox(height: AppSpacing.sm + 2),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: ext.rank.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: ext.rank.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            rankLabel,
                            key: const Key('ascension_rank_result'),
                            style: AppTypography.numeric(
                              theme.textTheme.titleMedium,
                              color: ext.rank,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Siklus baru dimulai — Farm Dungeon direset ke Dungeon 1.',
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm + 2),
                  Text(
                    '$dungeonName ditaklukkan ($clearedRoomsCount room selesai).',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (reward != null && !reward.alreadyClaimed) ...[
                    const SizedBox(height: AppSpacing.md),
                    PanelFrame(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 2,
                      ),
                      backgroundColor: AppColors.surfaceDark,
                      borderColor: ext.panelInnerBorder,
                      child: Column(
                        children: [
                          Text(
                            'HADIAH PENYELESAIAN',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '+${NumberFormatter.format(reward.expGranted)} EXP • '
                            '+${NumberFormatter.format(reward.goldGranted)} Gold'
                            '${reward.levelsGained > 0 ? ' • Naik ${NumberFormatter.format(reward.levelsGained)} Level!' : ''}',
                            style: AppTypography.numeric(
                              theme.textTheme.labelLarge,
                              color: ext.gold,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (reward.displayParts.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Hadiah: ${reward.displayParts.join(', ')}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: ext.expBar,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (bossQuestMessage != null &&
                      bossQuestMessage!.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    PanelFrame(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm + 2,
                      ),
                      backgroundColor: AppColors.surfaceDark,
                      borderColor: ext.panelInnerBorder,
                      child: Column(
                        children: [
                          Text(
                            'HADIAH BOSS QUEST',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            bossQuestMessage!,
                            key: const Key('boss_quest_result_message'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: ext.gold,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
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
                          icon: Icons.home_outlined,
                          onPressed: onReturnToTown,
                        )
                      else ...[
                        SecondaryButton(
                          label: 'Kembali ke Town',
                          icon: Icons.home_outlined,
                          onPressed: onReturnToTown,
                        ),
                        PrimaryButton(
                          label: 'Run baru',
                          icon: Icons.replay,
                          onPressed: onRetry,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
