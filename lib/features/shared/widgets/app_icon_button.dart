import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/echoes_theme.dart';

/// Tombol ikon bergaya Living Aether Camp dengan target sentuh minimal 44dp
/// serta label aksesibilitas & tooltip opsional.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.tooltip,
    this.isActive = false,
    this.accentColor,
    this.size = 44,
    this.iconSize = 20,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool isActive;
  final Color? accentColor;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final ext = EchoesTheme.of(context);
    final effectiveSize = size < 44 ? 44.0 : size;
    final tint = accentColor ?? (isActive ? ext.gold : AppColors.textPrimary);
    final borderColor = isActive
        ? tint.withValues(alpha: 0.75)
        : ext.panelBorder;
    final bgColor = isActive
        ? tint.withValues(alpha: 0.16)
        : AppColors.surfaceDark.withValues(alpha: 0.92);

    Widget button = Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: effectiveSize,
          minHeight: effectiveSize,
        ),
        child: Material(
          color: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            side: BorderSide(color: borderColor, width: AppBorders.thin),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: Icon(
                icon,
                size: iconSize,
                color: onPressed == null ? AppColors.textMuted : tint,
              ),
            ),
          ),
        ),
      ),
    );

    final effectiveTooltip = tooltip ?? semanticLabel;
    if (effectiveTooltip.isNotEmpty) {
      button = Tooltip(message: effectiveTooltip, child: button);
    }
    return button;
  }
}
