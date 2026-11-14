import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/utils/number_formatter.dart';
import '../shared/widgets/shared_widgets.dart';

/// Top bar Town Hub (M11 Stage 2) menampilkan level, bar EXP, gold, dan
/// Ascension Rank menggunakan [NumberFormatter] dan komponen bersama Stage 1.
class TownTopBar extends StatelessWidget {
  const TownTopBar({
    super.key,
    required this.level,
    required this.currentExp,
    required this.expToNext,
    required this.gold,
    required this.ascensionRank,
    this.specializationName,
    this.maxHp,
  });

  final int level;
  final int currentExp;
  final int expToNext;
  final int gold;
  final int ascensionRank;
  final String? specializationName;
  final int? maxHp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final specLabel = specializationName ?? 'Petualang';
    final effectiveMaxExp = expToNext > 0 ? expToNext : 1;
    final effectiveCurrentExp = expToNext > 0 ? currentExp : effectiveMaxExp;

    return PanelFrame(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$specLabel • Lv ${NumberFormatter.format(level)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    if (maxHp != null)
                      Text(
                        'HP ${NumberFormatter.format(maxHp!)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
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
                    ResourceChip.rank(
                      ascensionRank,
                      key: const Key('top_bar_rank'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),
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
