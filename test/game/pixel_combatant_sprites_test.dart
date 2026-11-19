import 'dart:io';

import 'package:echoes_of_aether/game/visuals/pixel_sprite_atlas.dart';
import 'package:echoes_of_aether/game/visuals/pixel_sprite_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Option A — Pixel Sprite Assets & Data Parity', () {
    test('Master spritesheet files exist on disk in assets/char and assets/monster', () {
      final requiredCharSheets = [
        'assets/char/Character-Base.png',
        'assets/char/Warrior-Blue.png',
        'assets/char/Mage-Cyan.png',
        'assets/char/Archer-Green.png',
      ];
      for (final p in requiredCharSheets) {
        expect(
          File(p).existsSync(),
          isTrue,
          reason: 'File $p harus ada di disk.',
        );
      }

      final requiredMonsterSheets = [
        'assets/monster/slime.png',
        'assets/monster/goblin.png',
        'assets/monster/orc.png',
        'assets/monster/skelly.png',
        'assets/monster/mummy.png',
        'assets/monster/wraith.png',
        'assets/monster/zombie.png',
        'assets/monster/fire_skull.png',
      ];
      for (final p in requiredMonsterSheets) {
        expect(
          File(p).existsSync(),
          isTrue,
          reason: 'File $p harus ada di disk.',
        );
      }
    });

    test(
      'Sliced PNG frames exist in assets/char/frames and assets/monster/frames',
      () {
        const poses = ['idle0', 'idle1', 'walk0', 'walk1', 'attack', 'downed'];
        const heroes = [
          'hero_base',
          'hero_vanguard',
          'hero_arcanist',
          'hero_ranger',
        ];
        for (final hero in heroes) {
          for (final pose in poses) {
            final p = 'assets/char/frames/${hero}_$pose.png';
            expect(
              File(p).existsSync(),
              isTrue,
              reason: 'Sliced frame $p harus ada.',
            );
          }
        }

        const monsters = [
          'forest_goblin',
          'corrupted_guardian',
          'forest_wolf',
          'corrupted_treant',
          'ancient_heart_guardian',
          'enemy_generic',
          'aether_slime',
          'fire_skull',
          'skelly',
          'mummy',
          'wraith',
          'zombie',
          'orc',
        ];
        for (final monster in monsters) {
          for (final pose in poses) {
            final p = 'assets/monster/frames/${monster}_$pose.png';
            expect(
              File(p).existsSync(),
              isTrue,
              reason: 'Sliced monster frame $p harus ada.',
            );
          }
        }
      },
    );

    test(
      'PixelSpriteData frames are 16x16 with valid palettes and row dimensions',
      () {
        expect(PixelSpriteData.frames, isNotEmpty);
        for (final entry in PixelSpriteData.frames.entries) {
          final frame = entry.value;
          expect(
            frame.palette,
            isNotEmpty,
            reason: 'Frame ${entry.key} harus punya palette.',
          );
          expect(
            frame.rows.length,
            16,
            reason: 'Frame ${entry.key} harus punya 16 baris.',
          );
          for (var r = 0; r < frame.rows.length; r++) {
            final row = frame.rows[r];
            expect(
              row.length,
              16,
              reason: 'Frame ${entry.key} baris $r harus memiliki 16 karakter.',
            );
          }
        }
      },
    );

    test(
      'PixelSpriteAtlas bakes authentic 16x16 frames with FilterQuality.none',
      () {
        final atlas = PixelSpriteAtlas.instance;
        const poses = ['idle0', 'idle1', 'walk0', 'walk1', 'attack', 'downed'];

        // Player characters
        for (final spec in [null, 'vanguard', 'arcanist', 'ranger']) {
          for (final pose in poses) {
            final img = atlas.combatantSprite(
              isPlayer: true,
              specializationId: spec,
              pose: pose,
            );
            expect(img.width, PixelSpriteAtlas.gridSize);
            expect(img.height, PixelSpriteAtlas.gridSize);
          }
        }

        // Monsters
        const monsterSpecies = [
          'aether_slime',
          'forest_slime',
          'forest_goblin',
          'forest_wolf',
          'corrupted_treant',
          'corrupted_guardian',
          'ancient_heart_guardian',
          'enemy_generic',
          'fire_skull',
          'skelly',
          'mummy',
          'wraith',
          'zombie',
          'orc',
        ];
        for (final m in monsterSpecies) {
          for (final pose in poses) {
            final img = atlas.combatantSprite(
              isPlayer: false,
              definitionId: m,
              pose: pose,
            );
            expect(img.width, PixelSpriteAtlas.gridSize);
            expect(img.height, PixelSpriteAtlas.gridSize);
          }
        }

        // Cache identity
        final first = atlas.combatantSprite(
          isPlayer: true,
          specializationId: 'ranger',
          pose: 'walk0',
        );
        final second = atlas.combatantSprite(
          isPlayer: true,
          specializationId: 'ranger',
          pose: 'walk0',
        );
        expect(identical(first, second), isTrue);
      },
    );
  });
}
