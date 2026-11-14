import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../shared/widgets/shared_widgets.dart';

/// Ditampilkan saat dungeon run berakhir (GDD 5.2).
class RunEndedOverlay extends StatelessWidget {
  const RunEndedOverlay({
    super.key,
    required this.onRetry,
    this.onReturnToTown,
    this.subtitle,
  });

  final VoidCallback onRetry;
  final VoidCallback? onReturnToTown;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: PanelFrame(
            padding: const EdgeInsets.all(AppSpacing.xl),
            borderColor: ext.hpBar,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.heart_broken_outlined, size: 36, color: ext.hpBar),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Run berakhir',
                  style: theme.textTheme.titleLarge?.copyWith(color: ext.hpBar),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Kamu kalah saat revive masih cooldown.',
                  textAlign: TextAlign.center,
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    if (onReturnToTown != null)
                      SecondaryButton(
                        label: 'Kembali ke Town',
                        onPressed: onReturnToTown,
                      ),
                    PrimaryButton(label: 'Run baru', onPressed: onRetry),
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
