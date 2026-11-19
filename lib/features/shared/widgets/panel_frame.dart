import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/echoes_theme.dart';
import 'pixel_ui_box.dart';

/// Bingkai panel bergaya RPG/pixel dengan border ganda, aksen sudut opsional,
/// atau gaya 9-slice pixel art retro terintegrasi.
class PanelFrame extends StatelessWidget {
  const PanelFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.borderColor,
    this.backgroundColor,
    this.gradient,
    this.showCornerOrnaments = false,
    this.borderRadius = AppRadius.md,
    this.elevation = AppElevation.panel,
    this.boxShadow,
    this.pixelStyle,
  });

  /// Varian panel berbasis 9-slice pixel art retro (misal: frame batu atau emas).
  const PanelFrame.pixel({
    super.key,
    required this.child,
    this.pixelStyle = PixelUiBoxStyle.darkStoneFrame,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.boxShadow,
  }) : borderColor = null,
       backgroundColor = null,
       gradient = null,
       showCornerOrnaments = false,
       borderRadius = AppRadius.md,
       elevation = AppElevation.panel;

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? backgroundColor;
  final Gradient? gradient;
  final bool showCornerOrnaments;
  final double borderRadius;
  final double elevation;
  final List<BoxShadow>? boxShadow;
  final PixelUiBoxStyle? pixelStyle;

  @override
  Widget build(BuildContext context) {
    if (pixelStyle != null) {
      final pixelPanel = PixelUiBox(
        style: pixelStyle!,
        padding: padding,
        child: child,
      );
      if (boxShadow == null || boxShadow!.isEmpty) return pixelPanel;
      return DecoratedBox(
        decoration: BoxDecoration(boxShadow: boxShadow),
        child: pixelPanel,
      );
    }

    final ext = EchoesTheme.of(context);
    final outerBorder = borderColor ?? ext.panelBorder;
    final panel = Material(
      color: backgroundColor ?? ext.panelBackground,
      elevation: elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: AppBorders.panel(color: outerBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(
            (borderRadius - 4).clamp(AppRadius.sm, AppRadius.xl),
          ),
          border: Border.fromBorderSide(
            AppBorders.inner(color: ext.panelInnerBorder),
          ),
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

    if (boxShadow == null || boxShadow!.isEmpty) return panel;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow,
      ),
      child: panel,
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
