import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/echoes_theme.dart';
import 'artwork/biome_artwork.dart';
import 'biome_style.dart';
import 'locked_badge.dart';
import 'panel_frame.dart';
import 'primary_button.dart';
import 'secondary_button.dart';

/// Kartu Dungeon / Biome bergaya Living Aether Camp untuk Adventure & Town Hub.
class DungeonCard extends StatelessWidget {
  const DungeonCard({
    super.key,
    required this.name,
    required this.biomeId,
    required this.recommendedLevel,
    required this.clearedRooms,
    required this.totalRooms,
    this.isAscension = false,
    this.isUnlocked = true,
    this.isCleared = false,
    this.isSelected = false,
    this.lockedReason,
    this.areaLabel,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.artworkHeight = 96,
  });

  final String name;
  final String biomeId;
  final int recommendedLevel;
  final int clearedRooms;
  final int totalRooms;
  final bool isAscension;
  final bool isUnlocked;
  final bool isCleared;
  final bool isSelected;
  final String? lockedReason;
  final String? areaLabel;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final double artworkHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    final biome = BiomeStyle.resolve(biomeId, isAscension: isAscension);
    final safeTotal = totalRooms <= 0 ? 1 : totalRooms;
    final safeCleared = clearedRooms.clamp(0, safeTotal);
    final progress = (safeCleared / safeTotal).clamp(0.0, 1.0);
    final borderColor = !isUnlocked
        ? ext.locked.withValues(alpha: 0.45)
        : isSelected
        ? ext.gold
        : biome.accentColor.withValues(alpha: 0.65);

    return PanelFrame(
      borderColor: borderColor,
      showCornerOrnaments: isSelected || isAscension,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          BiomeArtwork(
            biomeId: biomeId,
            isAscension: isAscension,
            height: artworkHeight,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs - 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.midnightForest.withValues(
                              alpha: 0.85,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: biome.accentColor.withValues(alpha: 0.55),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                biome.icon,
                                size: 13,
                                color: biome.accentColor,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Flexible(
                                child: Text(
                                  biome.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: biome.accentColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _StatusChip(
                        isUnlocked: isUnlocked,
                        isCleared: isCleared,
                        isSelected: isSelected,
                      ),
                    ],
                  ),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.headingSerif(
                      theme.textTheme.titleMedium,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Rec. Lv.$recommendedLevel',
                style: AppTypography.numeric(
                  theme.textTheme.labelMedium,
                  color: AppColors.antiqueGold,
                ),
              ),
              Text(
                '$safeCleared / $totalRooms Room',
                style: AppTypography.numeric(
                  theme.textTheme.labelMedium,
                  color: AppColors.aetherBlue,
                ),
              ),
              if (areaLabel != null && areaLabel!.isNotEmpty)
                Text(
                  areaLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.deepForest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCleared ? AppColors.success : biome.accentColor,
                ),
              ),
            ),
          ),
          if (!isUnlocked &&
              lockedReason != null &&
              lockedReason!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            LockedBadge(label: lockedReason!),
          ],
          if (primaryActionLabel != null || secondaryActionLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final stackButtons =
                    constraints.maxWidth < 280 &&
                    primaryActionLabel != null &&
                    secondaryActionLabel != null;

                if (stackButtons) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PrimaryButton(
                        label: primaryActionLabel!,
                        expand: true,
                        onPressed: isUnlocked ? onPrimaryAction : null,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      SecondaryButton(
                        label: secondaryActionLabel!,
                        expand: true,
                        onPressed: onSecondaryAction,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    if (secondaryActionLabel != null) ...[
                      Expanded(
                        child: SecondaryButton(
                          label: secondaryActionLabel!,
                          expand: true,
                          onPressed: onSecondaryAction,
                        ),
                      ),
                      if (primaryActionLabel != null)
                        const SizedBox(width: AppSpacing.sm),
                    ],
                    if (primaryActionLabel != null)
                      Expanded(
                        child: PrimaryButton(
                          label: primaryActionLabel!,
                          expand: true,
                          onPressed: isUnlocked ? onPrimaryAction : null,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.isUnlocked,
    required this.isCleared,
    required this.isSelected,
  });

  final bool isUnlocked;
  final bool isCleared;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String text;
    if (!isUnlocked) {
      color = AppColors.locked;
      text = 'Terkunci';
    } else if (isSelected) {
      color = AppColors.antiqueGold;
      text = 'Aktif';
    } else if (isCleared) {
      color = AppColors.success;
      text = 'Selesai';
    } else {
      color = AppColors.aetherBlue;
      text = 'Terbuka';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 2,
        vertical: AppSpacing.xs - 1,
      ),
      decoration: BoxDecoration(
        color: AppColors.midnightForest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
