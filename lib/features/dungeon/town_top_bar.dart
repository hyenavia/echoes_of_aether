import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../shared/widgets/shared_widgets.dart';

/// Top bar Town Hub menampilkan identitas ringkas, HP, bar EXP, gold, dan
/// Ascension Rank menggunakan token RPG Echoes of Aether.
class TownTopBar extends StatelessWidget {
  const TownTopBar({
    super.key,
    required this.level,
    required this.currentExp,
    required this.expToNext,
    required this.gold,
    this.aetherShard = 0,
    required this.ascensionRank,
    this.specializationName,
    this.maxHp,
  });

  final int level;
  final int currentExp;
  final int expToNext;
  final int gold;
  final int aetherShard;
  final int ascensionRank;
  final String? specializationName;
  final int? maxHp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    final specLabel = specializationName ?? 'Petualang';
    final effectiveMaxExp = expToNext > 0 ? expToNext : 1;
    final effectiveCurrentExp = expToNext > 0 ? currentExp : effectiveMaxExp;

    return PanelFrame(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      backgroundColor: AppColors.surfaceDark,
      borderColor: ext.gold.withValues(alpha: 0.42),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppSpacing.xs + 2,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '$specLabel • Lv ${NumberFormatter.format(level)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.numeric(
                        theme.textTheme.titleSmall,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (maxHp != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: ext.hpBar.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: ext.hpBar.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'HP ${NumberFormatter.format(maxHp!)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.numeric(
                            theme.textTheme.labelSmall,
                            color: ext.hpBar,
                            fontSize: 10,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Wrap(
                  spacing: AppSpacing.xs + 2,
                  runSpacing: AppSpacing.xs,
                  alignment: WrapAlignment.end,
                  children: [
                    ResourceChip.gold(gold, key: const Key('top_bar_gold')),
                    ResourceChip.aetherShard(
                      aetherShard,
                      key: const Key('top_bar_aether_shard'),
                    ),
                    ResourceChip.rank(
                      ascensionRank,
                      key: const Key('top_bar_rank'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          StatBar.exp(
            key: const Key('top_bar_exp'),
            current: effectiveCurrentExp,
            max: effectiveMaxExp,
            label: expToNext > 0 ? 'EXP' : 'EXP (MAX)',
          ),
        ],
      ),
    );
  }
}
