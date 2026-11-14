import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/echoes_theme.dart';
import '../../../core/utils/number_formatter.dart';

enum StatBarKind { hp, exp, custom }

/// Bar progres stat (HP / EXP) dengan label, angka terformat, dan proteksi
/// overflow pada lebar kecil maupun angka sangat besar.
class StatBar extends StatelessWidget {
  const StatBar({
    super.key,
    required this.label,
    required this.current,
    required this.max,
    this.kind = StatBarKind.custom,
    this.barColor,
    this.height = 8,
  });

  factory StatBar.hp({
    Key? key,
    required num current,
    required num max,
    String label = 'HP',
  }) => StatBar(
    key: key,
    label: label,
    current: current,
    max: max,
    kind: StatBarKind.hp,
  );

  factory StatBar.exp({
    Key? key,
    required num current,
    required num max,
    String label = 'EXP',
  }) => StatBar(
    key: key,
    label: label,
    current: current,
    max: max,
    kind: StatBarKind.exp,
  );

  final String label;
  final num current;
  final num max;
  final StatBarKind kind;
  final Color? barColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final ext = EchoesTheme.of(context);
    final theme = Theme.of(context);
    final fillColor =
        barColor ??
        switch (kind) {
          StatBarKind.hp => ext.hpBar,
          StatBarKind.exp => ext.expBar,
          StatBarKind.custom => theme.colorScheme.primary,
        };
    final ratio = max <= 0 ? 0.0 : (current / max).clamp(0.0, 1.0).toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                '${NumberFormatter.format(current)} / ${NumberFormatter.format(max)}',
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: SizedBox(
            height: height,
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: AppColors.deepForest,
              valueColor: AlwaysStoppedAnimation<Color>(fillColor),
            ),
          ),
        ),
      ],
    );
  }
}
