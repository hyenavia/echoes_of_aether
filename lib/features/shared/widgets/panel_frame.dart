import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/echoes_theme.dart';

/// Bingkai panel bergaya RPG/pixel sederhana dengan border ganda.
class PanelFrame extends StatelessWidget {
  const PanelFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.borderColor,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final ext = EchoesTheme.of(context);
    final outerBorder = borderColor ?? ext.panelBorder;
    return Material(
      color: backgroundColor ?? ext.panelBackground,
      elevation: AppElevation.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: outerBorder, width: 1.5),
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: ext.panelInnerBorder, width: 1),
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}
