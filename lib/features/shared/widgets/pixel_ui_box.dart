import 'package:flutter/material.dart';

/// Gaya 9-slice untuk elemen UI pixel art.
enum PixelUiBoxStyle {
  goldOrnateFrame(
    assetPath: 'assets/ui/frame_gold_ornate.png',
    centerSlice: Rect.fromLTRB(24, 24, 72, 99),
    contentPadding: EdgeInsets.all(16),
  ),
  parchmentFrame(
    assetPath: 'assets/ui/frame_parchment.png',
    centerSlice: Rect.fromLTRB(16, 16, 80, 107),
    contentPadding: EdgeInsets.all(14),
  ),
  darkStoneFrame(
    assetPath: 'assets/ui/frame_stone_dark.png',
    centerSlice: Rect.fromLTRB(10, 10, 50, 50),
    contentPadding: EdgeInsets.all(10),
  ),
  embossedStoneFrame(
    assetPath: 'assets/ui/frame_stone_embossed.png',
    centerSlice: Rect.fromLTRB(10, 10, 50, 50),
    contentPadding: EdgeInsets.all(10),
  ),
  darkSlot(
    assetPath: 'assets/ui/slot_dark.png',
    centerSlice: Rect.fromLTRB(6, 4, 22, 23),
    contentPadding: EdgeInsets.all(4),
  ),
  stoneSlot(
    assetPath: 'assets/ui/slot_stone.png',
    centerSlice: Rect.fromLTRB(6, 4, 22, 23),
    contentPadding: EdgeInsets.all(4),
  ),
  goldBlueSlot(
    assetPath: 'assets/ui/slot_gold_blue.png',
    centerSlice: Rect.fromLTRB(8, 8, 24, 24),
    contentPadding: EdgeInsets.all(6),
  ),
  darkBanner(
    assetPath: 'assets/ui/banner_dark.png',
    centerSlice: Rect.fromLTRB(16, 4, 48, 13),
    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
  ),
  goldBlueBanner(
    assetPath: 'assets/ui/banner_gold_blue.png',
    centerSlice: Rect.fromLTRB(16, 10, 48, 22),
    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
  ),
  smallParchmentCard(
    assetPath: 'assets/ui/card_parchment_small.png',
    centerSlice: Rect.fromLTRB(12, 10, 52, 22),
    contentPadding: EdgeInsets.all(8),
  );

  const PixelUiBoxStyle({
    required this.assetPath,
    required this.centerSlice,
    required this.contentPadding,
  });

  final String assetPath;
  final Rect centerSlice;
  final EdgeInsets contentPadding;
}

/// Kotak/container 9-slice berbasis pixel art retro dengan nearest-neighbor scaling.
class PixelUiBox extends StatelessWidget {
  const PixelUiBox({
    super.key,
    required this.style,
    this.child,
    this.width,
    this.height,
    this.padding,
  });

  final PixelUiBoxStyle style;
  final Widget? child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final effectivePadding = padding ?? style.contentPadding;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: Image.asset(
              style.assetPath,
              centerSlice: style.centerSlice,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.none,
            ),
          ),
          if (child != null) Padding(padding: effectivePadding, child: child),
        ],
      ),
    );
  }
}
