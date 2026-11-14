import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/echoes_theme.dart';

/// Bingkai panel bergaya RPG/pixel dengan border ganda dan aksen sudut opsional.
class PanelFrame extends StatelessWidget {
  const PanelFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.borderColor,
    this.backgroundColor,
    this.gradient,
    this.showCornerOrnaments = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? backgroundColor;
  final Gradient? gradient;
  final bool showCornerOrnaments;

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
      clipBehavior: Clip.antiAlias,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: ext.panelInnerBorder, width: 1),
        ),
        child: showCornerOrnaments
            ? CustomPaint(
                painter: _CornerOrnamentPainter(
                  color: outerBorder.withValues(alpha: 0.65),
                ),
                child: Padding(padding: padding, child: child),
              )
            : Padding(padding: padding, child: child),
      ),
    );
  }
}

class _CornerOrnamentPainter extends CustomPainter {
  const _CornerOrnamentPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const tick = 5.0;
    const inset = 3.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Top-left
    canvas.drawLine(
      const Offset(inset, inset + tick),
      const Offset(inset, inset),
      paint,
    );
    canvas.drawLine(
      const Offset(inset, inset),
      const Offset(inset + tick, inset),
      paint,
    );
    // Top-right
    canvas.drawLine(
      Offset(size.width - inset - tick, inset),
      Offset(size.width - inset, inset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset, inset),
      Offset(size.width - inset, inset + tick),
      paint,
    );
    // Bottom-left
    canvas.drawLine(
      Offset(inset, size.height - inset - tick),
      Offset(inset, size.height - inset),
      paint,
    );
    canvas.drawLine(
      Offset(inset, size.height - inset),
      Offset(inset + tick, size.height - inset),
      paint,
    );
    // Bottom-right
    canvas.drawLine(
      Offset(size.width - inset - tick, size.height - inset),
      Offset(size.width - inset, size.height - inset),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - inset, size.height - inset - tick),
      Offset(size.width - inset, size.height - inset),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerOrnamentPainter oldDelegate) =>
      oldDelegate.color != color;
}
