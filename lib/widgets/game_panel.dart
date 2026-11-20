import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Gaya visual 9-slice untuk [GamePanel].
enum GamePanelStyle {
  /// Bingkai emas mewah berornamen tinggi (paling cocok untuk kartu hero, dialog, pop-up selesai).
  goldOrnate(
    assetPath: 'assets/ui/frame_gold_ornate.png',
    centerSlice: Rect.fromLTRB(24, 24, 72, 99),
    minWidth: 48,
    minHeight: 48,
    contentPadding: EdgeInsets.all(16),
    defaultGlow: AppTheme.gold,
  ),

  /// Bingkai batu gelap khas dungeon (cocok untuk log pertempuran, slot sekunder, action bar).
  darkStone(
    assetPath: 'assets/ui/frame_stone_dark.png',
    centerSlice: Rect.fromLTRB(10, 10, 50, 50),
    minWidth: 20,
    minHeight: 20,
    contentPadding: EdgeInsets.all(12),
    defaultGlow: AppTheme.cyanGlow,
  ),

  /// Bingkai perkamen antik (cocok untuk lore, deskripsi item, dialog NPC).
  parchment(
    assetPath: 'assets/ui/frame_parchment.png',
    centerSlice: Rect.fromLTRB(16, 16, 80, 107),
    minWidth: 32,
    minHeight: 32,
    contentPadding: EdgeInsets.all(14),
    defaultGlow: AppTheme.gold,
  ),

  /// Bingkai banner emas biru (cocok untuk header status, rank banner).
  goldBlueBanner(
    assetPath: 'assets/ui/banner_gold_blue.png',
    centerSlice: Rect.fromLTRB(16, 10, 48, 22),
    minWidth: 32,
    minHeight: 16,
    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    defaultGlow: AppTheme.gold,
  );

  const GamePanelStyle({
    required this.assetPath,
    required this.centerSlice,
    required this.minWidth,
    required this.minHeight,
    required this.contentPadding,
    required this.defaultGlow,
  });

  final String assetPath;
  final Rect centerSlice;
  final double minWidth;
  final double minHeight;
  final EdgeInsets contentPadding;
  final Color defaultGlow;
}

/// Container RPG dengan latar belakang gambar 9-slice (border berornamen).
///
/// Mendukung:
/// - Border 9-slice pixel/ornate presisi tanpa distorsi pada sudut.
/// - Tinting latar belakang semi-transparan (misal opacity 0.85 untuk floating HUD).
/// - Efek glow luar lembut (emas, arcane purple, atau cyan).
/// - Header banner judul fantasi opsional.
class GamePanel extends StatelessWidget {
  const GamePanel({
    super.key,
    required this.child,
    this.style = GamePanelStyle.goldOrnate,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.opacity = 1.0,
    this.showGlow = false,
    this.glowColor,
    this.title,
    this.titleWidget,
  });

  /// Pintasan untuk panel emas mewah.
  const GamePanel.goldOrnate({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.opacity = 1.0,
    this.showGlow = false,
    this.glowColor,
    this.title,
    this.titleWidget,
  }) : style = GamePanelStyle.goldOrnate;

  /// Pintasan untuk panel batu gelap khas dungeon.
  const GamePanel.darkStone({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.opacity = 1.0,
    this.showGlow = false,
    this.glowColor,
    this.title,
    this.titleWidget,
  }) : style = GamePanelStyle.darkStone;

  /// Pintasan untuk panel floating overlay HUD semi-transparan (opacity 0.85).
  const GamePanel.hudOverlay({
    super.key,
    required this.child,
    this.style = GamePanelStyle.darkStone,
    this.width,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    this.margin,
    this.backgroundColor = const Color(0xD90B0E17), // 85% opacity Deep Navy
    this.opacity = 0.88,
    this.showGlow = false,
    this.glowColor,
    this.title,
    this.titleWidget,
  });

  final Widget child;
  final GamePanelStyle style;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double opacity;
  final bool showGlow;
  final Color? glowColor;
  final String? title;
  final Widget? titleWidget;

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? style.contentPadding;
    final effectiveGlowColor = glowColor ?? style.defaultGlow;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (titleWidget != null)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: titleWidget)
        else if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Center(
              child: Text(
                title!,
                style: AppTheme.headingFantasy(
                  fontSize: 15,
                  letterSpacing: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        child,
      ],
    );

    Widget panelBody = Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // 1. Lapisan dasar warna/gradient latar belakang (bila ditentukan)
          if (backgroundColor != null)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),

          // 2. Lapisan 9-slice border berornamen
          Positioned.fill(
            child: Image.asset(
              style.assetPath,
              centerSlice: style.centerSlice,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            ),
          ),

          // 3. Lapisan konten di dalam padding
          Padding(padding: effectivePadding, child: content),
        ],
      ),
    );

    // Tambahkan outer glow jika diaktifkan
    if (showGlow) {
      panelBody = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: effectiveGlowColor.withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: panelBody,
      );
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: panelBody,
    );
  }
}
