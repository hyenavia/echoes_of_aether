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
    return ColoredBox(
      color: AppColors.midnightForest.withValues(alpha: 0.78),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: PanelFrame(
              padding: const EdgeInsets.all(AppSpacing.xl),
              borderColor: ext.hpBar,
              showCornerOrnaments: true,
              boxShadow: AppShadows.glow(ext.hpBar, alpha: 0.25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          ext.hpBar.withValues(alpha: 0.28),
                          AppColors.surfaceDark,
                        ],
                      ),
                      border: Border.all(
                        color: ext.hpBar.withValues(alpha: 0.75),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.heart_broken_outlined,
                      size: 28,
                      color: ext.hpBar,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Run berakhir',
                    style: AppTypography.headingSerif(
                      theme.textTheme.headlineSmall ??
                          theme.textTheme.titleLarge,
                      color: ext.hpBar,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PanelFrame(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    backgroundColor: AppColors.surfaceDark,
                    borderColor: ext.hpBar.withValues(alpha: 0.35),
                    child: Column(
                      children: [
                        Text(
                          'Kamu kalah saat revive masih cooldown.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (subtitle != null &&
                            subtitle!.trim().isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    alignment: WrapAlignment.center,
                    children: [
                      if (onReturnToTown != null)
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
