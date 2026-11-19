import 'dart:ui' as ui;

import 'package:echoes_of_aether/app/theme/echoes_theme.dart';
import 'package:echoes_of_aether/core/constants/game_constants.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/features/shared/widgets/hero_showcase_card.dart';
import 'package:echoes_of_aether/features/shared/widgets/item_card.dart';
import 'package:echoes_of_aether/features/shared/widgets/item_slot.dart';
import 'package:echoes_of_aether/features/shared/widgets/panel_frame.dart';
import 'package:echoes_of_aether/features/shared/widgets/pixel_ui_box.dart';
import 'package:echoes_of_aether/game/components/effects/skill_vfx_component.dart';
import 'package:echoes_of_aether/game/visuals/pixel_sprite_atlas.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrapWithTheme(
    Widget child, {
    double width = 400,
    double textScale = 1.0,
  }) {
    return MaterialApp(
      theme: EchoesTheme.dark(),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: SizedBox(
            width: width,
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    );
  }

  group('Audit Ketajaman Pixel Art & Scaling (Nearest-Neighbor)', () {
    test(
      'PixelSpriteAtlas mengonfigurasi filterQuality.none dan non-anti-alias',
      () {
        expect(PixelSpriteAtlas.gridSize, 16);
        expect(
          PixelSpriteAtlas.pixelPaint.filterQuality,
          ui.FilterQuality.none,
        );
        expect(PixelSpriteAtlas.pixelPaint.isAntiAlias, isFalse);
      },
    );

    test('Virtual camera resolution & simulation timestep sesuai GDD', () {
      expect(GameConstants.tileSize, 16.0);
      expect(GameConstants.viewWidth, 320.0);
      expect(GameConstants.viewHeight, 176.0);
      expect(GameConstants.simulationStep, const Duration(milliseconds: 50));
    });

    test(
      'Semua 4 class hero dapat diambil dari atlas berukuran tepat 16x16',
      () {
        final atlas = PixelSpriteAtlas.instance;
        const heroClasses = ['base', 'vanguard', 'arcanist', 'ranger'];
        const poses = ['idle0', 'idle1', 'walk0', 'walk1', 'attack', 'downed'];

        for (final cls in heroClasses) {
          for (final pose in poses) {
            final sprite = atlas.combatantSprite(
              isPlayer: true,
              specializationId: cls == 'base' ? null : cls,
              pose: pose,
            );
            expect(sprite.width, 16);
            expect(sprite.height, 16);
          }
        }
      },
    );

    test(
      'Semua 8 species monster dapat diambil dari atlas berukuran tepat 16x16',
      () {
        final atlas = PixelSpriteAtlas.instance;
        const monsterSpecies = [
          'slime',
          'goblin',
          'skelly',
          'mummy',
          'orc',
          'wraith',
          'zombie',
          'fire_skull',
        ];
        const poses = ['idle0', 'idle1', 'walk0', 'walk1', 'attack', 'downed'];

        for (final species in monsterSpecies) {
          for (final pose in poses) {
            final sprite = atlas.combatantSprite(
              isPlayer: false,
              definitionId: species,
              pose: pose,
            );
            expect(sprite.width, 16);
            expect(sprite.height, 16);
          }
        }
      },
    );

    test('Semua 5 biome memiliki tile floor0, floor1, floor2, dan wall berukuran 16x16', () {
      final atlas = PixelSpriteAtlas.instance;
      const biomes = [
        'forgotten_forest',
        'crystal_cavern',
        'ancient_crypt',
        'ashen_wasteland',
        'aether_sanctum',
      ];
      const tileKeys = ['floor0', 'floor1', 'floor2', 'wall'];

      for (final biome in biomes) {
        for (final key in tileKeys) {
          final tile = atlas.tileSprite(key, biome: biome);
          expect(tile.width, 16);
          expect(tile.height, 16);
        }
      }
    });

    test(
      'Atlas caching mengembalikan instance yang sama tanpa re-baking berlebih',
      () {
        final atlas = PixelSpriteAtlas.instance;
        final tile1 = atlas.tileSprite('floor0', biome: 'crystal_cavern');
        final tile2 = atlas.tileSprite('floor0', biome: 'crystal_cavern');
        expect(identical(tile1, tile2), isTrue);

        final hero1 = atlas.combatantSprite(
          isPlayer: true,
          specializationId: 'vanguard',
          pose: 'idle0',
        );
        final hero2 = atlas.combatantSprite(
          isPlayer: true,
          specializationId: 'vanguard',
          pose: 'idle0',
        );
        expect(identical(hero1, hero2), isTrue);
      },
    );
  });

  group('VFX Lifecycle, Rendering, & Cleanup Audit', () {
    test('Semua 10 tipe VFX dapat di-render tanpa exception', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final vfxList = <SkillVfxComponent>[
        SkillVfxComponent.slash(position: Vector2.zero()),
        SkillVfxComponent.heavySlash(position: Vector2.zero()),
        SkillVfxComponent.arcaneBurst(position: Vector2.zero()),
        SkillVfxComponent.meteorFall(position: Vector2.zero()),
        SkillVfxComponent.arrowShot(position: Vector2.zero()),
        SkillVfxComponent.lifeSiphon(position: Vector2.zero()),
        SkillVfxComponent.groundSlam(position: Vector2.zero()),
        SkillVfxComponent.healPulse(position: Vector2.zero()),
        SkillVfxComponent.critSpark(position: Vector2.zero()),
        SkillVfxComponent.defeatBurst(position: Vector2.zero()),
      ];

      for (final vfx in vfxList) {
        expect(() => vfx.render(canvas), returnsNormally);
      }
      recorder.endRecording();
    });

    testWidgets('VFX Component lifecycle membersihkan diri saat durasi habis', (
      tester,
    ) async {
      final game = FlameGame();
      await tester.pumpWidget(GameWidget(game: game));

      final vfx = SkillVfxComponent.slash(position: Vector2(20, 20));
      await game.add(vfx);
      game.update(0);
      await tester.pump();

      expect(game.children.whereType<SkillVfxComponent>(), hasLength(1));

      // Advance past duration (0.16s)
      game.update(0.25);
      game.update(0);
      await tester.pump();

      expect(game.children.whereType<SkillVfxComponent>(), isEmpty);
    });
  });

  group('Living Aether Camp & UI Responsive Performance Audit', () {
    testWidgets('HeroShowcaseCard merender mulus pada 320dp dan 720dp tablet', (
      tester,
    ) async {
      const stats = CombatStats(maxHp: 450, atk: 65, def: 30, critRate: 0.20);

      // Uji 1: Narrow viewport (320dp phone)
      await tester.pumpWidget(
        wrapWithTheme(
          width: 320,
          textScale: 1.5,
          const HeroShowcaseCard(
            level: 35,
            ascensionRank: 2,
            specializationId: 'vanguard',
            specializationName: 'Vanguard',
            stats: stats,
          ),
        ),
      );
      expect(find.text('Vanguard'), findsOneWidget);
      expect(find.text('Lv 35'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Uji 2: Wide viewport (720dp tablet portrait)
      await tester.pumpWidget(
        wrapWithTheme(
          width: 720,
          textScale: 1.0,
          const HeroShowcaseCard(
            level: 35,
            ascensionRank: 2,
            specializationId: 'vanguard',
            specializationName: 'Vanguard',
            stats: stats,
          ),
        ),
      );
      expect(find.text('Vanguard'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Hierarki visual slot item dan kartu item tetap tajam di 320dp @ 1.5x',
      (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            width: 320,
            textScale: 1.5,
            Column(
              children: [
                const PanelFrame.pixel(
                  pixelStyle: PixelUiBoxStyle.darkStoneFrame,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ItemSlot(
                        rarity: ItemRarity.common,
                        slot: EquipmentSlot.weapon,
                      ),
                      ItemSlot(
                        rarity: ItemRarity.rare,
                        slot: EquipmentSlot.head,
                      ),
                      ItemSlot(
                        rarity: ItemRarity.legendary,
                        slot: EquipmentSlot.accessory,
                        quantity: 50,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ItemCard(
                  name: 'Blade of the Aether Dawn',
                  rarity: ItemRarity.legendary,
                  slot: EquipmentSlot.weapon,
                  statsSummary: 'ATK +120, CRIT +18%',
                  trailing: ElevatedButton(
                    onPressed: () {},
                    child: const Text('Gunakan'),
                  ),
                ),
              ],
            ),
          ),
        );

        expect(find.text('Blade of the Aether Dawn'), findsOneWidget);
        expect(find.text('x50'), findsOneWidget);
        expect(find.byType(ItemSlot), findsNWidgets(3));
        expect(find.byType(PanelFrame), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
