import 'dart:ui' show Color;

import '../combatant_component.dart';
import '../../visuals/pixel_sprite_atlas.dart';

/// Tampilan musuh (GDD 12.4). Atribut tempur tetap di domain (Combatant).
class EnemyComponent extends CombatantComponent {
  EnemyComponent({
    required super.combatant,
    required super.tileSize,
    super.atlas,
    super.spriteRef,
    String? spriteTintHex,
    Color? spriteTint,
  }) : super(
         colorArgb: 0xFFEF5350,
         spriteTint:
             spriteTint ?? PixelSpriteAtlas.parseHexTintColor(spriteTintHex),
       );
}
