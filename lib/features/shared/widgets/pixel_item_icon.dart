import 'package:flutter/material.dart';

import '../../../domain/entities/equipment.dart';
import '../../../domain/entities/item_definition.dart';
import '../assets/item_sprite_registry.dart';
import 'pixel_ui_box.dart';

/// Menampilkan ikon item pixel art dari registry atau fallback ke [IconData].
class PixelItemIcon extends StatelessWidget {
  const PixelItemIcon({
    super.key,
    this.itemId,
    this.spritePath,
    this.slot,
    this.category,
    this.skillId,
    this.size = 36.0,
    this.fallbackIcon = Icons.inventory_2_outlined,
    this.fallbackColor,
    this.useSlotFrame = false,
  });

  final String? itemId;
  final String? spritePath;
  final EquipmentSlot? slot;
  final ItemCategory? category;
  final String? skillId;
  final double size;
  final IconData fallbackIcon;
  final Color? fallbackColor;
  final bool useSlotFrame;

  @override
  Widget build(BuildContext context) {
    final path =
        spritePath ??
        ItemSpriteRegistry.spriteForItem(itemId) ??
        ItemSpriteRegistry.spriteForSkill(skillId) ??
        ItemSpriteRegistry.spriteForSlot(slot) ??
        ItemSpriteRegistry.spriteForCategory(category);
    final color = fallbackColor ?? Theme.of(context).colorScheme.primary;

    Widget content;
    if (path != null) {
      content = Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        errorBuilder: (context, error, stackTrace) {
          return Icon(fallbackIcon, size: size * 0.6, color: color);
        },
      );
    } else {
      content = Icon(fallbackIcon, size: size * 0.6, color: color);
    }

    if (!useSlotFrame) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: content),
      );
    }

    return PixelUiBox(
      style: PixelUiBoxStyle.darkSlot,
      width: size + 8,
      height: size + 8,
      child: Center(child: content),
    );
  }
}
