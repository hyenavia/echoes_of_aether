import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import 'panel_frame.dart';
import 'primary_button.dart';
import 'secondary_button.dart';

/// Dialog bergaya Living Aether Camp dengan frame ornamen dan tombol standar.
class EchoesDialog extends StatelessWidget {
  const EchoesDialog({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.accentColor = AppColors.antiqueGold,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Color accentColor;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: PanelFrame(
          showCornerOrnaments: true,
          backgroundColor: AppColors.deepTeal,
          borderColor: accentColor.withValues(alpha: 0.65),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 22, color: accentColor),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headingSerif(
                        theme.textTheme.titleLarge,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(child: SingleChildScrollView(child: child)),
              if (primaryLabel != null || secondaryLabel != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    if (secondaryLabel != null) ...[
                      Expanded(
                        child: SecondaryButton(
                          label: secondaryLabel!,
                          expand: true,
                          onPressed:
                              onSecondary ??
                              () => Navigator.of(context).pop(false),
                        ),
                      ),
                      if (primaryLabel != null)
                        const SizedBox(width: AppSpacing.sm),
                    ],
                    if (primaryLabel != null)
                      Expanded(
                        child: PrimaryButton(
                          label: primaryLabel!,
                          expand: true,
                          onPressed:
                              onPrimary ??
                              () => Navigator.of(context).pop(true),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper terpusat untuk menampilkan [EchoesDialog].
Future<T?> showEchoesDialog<T>({
  required BuildContext context,
  required String title,
  required Widget child,
  IconData? icon,
  Color accentColor = AppColors.antiqueGold,
  String? primaryLabel,
  VoidCallback? onPrimary,
  String? secondaryLabel,
  VoidCallback? onSecondary,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => EchoesDialog(
      title: title,
      icon: icon,
      accentColor: accentColor,
      primaryLabel: primaryLabel,
      onPrimary: onPrimary,
      secondaryLabel: secondaryLabel,
      onSecondary: onSecondary,
      child: child,
    ),
  );
}
