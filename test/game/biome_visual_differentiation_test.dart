import 'package:echoes_of_aether/core/constants/game_constants.dart';
import 'package:echoes_of_aether/core/constants/test_room.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:echoes_of_aether/game/hud/hud_state.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:echoes_of_aether/game/visuals/pixel_sprite_atlas.dart';
import 'package:echoes_of_aether/game/world/debug_room_component.dart';
import 'package:echoes_of_aether/game/world/dungeon_world.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const progression = ProgressionConfig(
    maxLevel: 10,
    expBase: 50,
    expGrowth: 1.4,
    baseStats: CombatStats(
      maxHp: 100,
      atk: 15,
      def: 2,
      attackSpeed: 1,
      moveSpeed: 4,
      attackRange: 1.5,
    ),
    perLevel: LevelGrowth(hp: 10, atk: 2, def: 1),
  );

  group('PixelSpriteAtlas Biome Normalization & Palettes', () {
    test('normalizeBiome handles all canon biomes and aliases correctly', () {
      expect(
        PixelSpriteAtlas.normalizeBiome('forgotten_forest'),
        'forgotten_forest',
      );
      expect(
        PixelSpriteAtlas.normalizeBiome('crystal_cavern'),
        'crystal_cavern',
      );
      expect(PixelSpriteAtlas.normalizeBiome('ancient_crypt'), 'ancient_crypt');
      expect(
        PixelSpriteAtlas.normalizeBiome('ashen_wasteland'),
        'ashen_wasteland',
      );
      expect(
        PixelSpriteAtlas.normalizeBiome('aether_sanctum'),
        'aether_sanctum',
      );
      expect(
        PixelSpriteAtlas.normalizeBiome('ascension_sanctum'),
        'aether_sanctum',
      );
      expect(PixelSpriteAtlas.normalizeBiome(null), 'forgotten_forest');
      expect(
        PixelSpriteAtlas.normalizeBiome('unknown_realm'),
        'forgotten_forest',
      );
    });

    test(
      'paletteForBiome returns distinct thematic palettes for all 5 biomes',
      () {
        final forest = PixelSpriteAtlas.paletteForBiome('forgotten_forest');
        final cavern = PixelSpriteAtlas.paletteForBiome('crystal_cavern');
        final crypt = PixelSpriteAtlas.paletteForBiome('ancient_crypt');
        final wasteland = PixelSpriteAtlas.paletteForBiome('ashen_wasteland');
        final sanctum = PixelSpriteAtlas.paletteForBiome('aether_sanctum');

        // Forest has deep forest greens
        expect(forest['g'], 0xFF355B45);

        // Cavern has deep cave slate & cyan crystal
        expect(cavern['d'], 0xFF0E1B24);
        expect(cavern['a'], 0xFF9DE2FF);

        // Crypt has dark sepulcher & arcane purple
        expect(crypt['d'], 0xFF171322);
        expect(crypt['b'], 0xFFA88AD5);

        // Wasteland has volcanic ash & molten magma orange
        expect(wasteland['d'], 0xFF1C1110);
        expect(wasteland['a'], 0xFFE6683B);

        // Sanctum has celestial navy & antique gold
        expect(sanctum['d'], 0xFF131926);
        expect(sanctum['b'], 0xFFE6BD68);

        // All 5 biome base dark colors are distinct
        final baseDarkColors = {
          forest['d'],
          cavern['d'],
          crypt['d'],
          wasteland['d'],
          sanctum['d'],
        };
        expect(baseDarkColors.length, 5);
      },
    );
  });

  group('PixelSpriteAtlas Biome Tile Generation & Caching', () {
    const biomes = [
      'forgotten_forest',
      'crystal_cavern',
      'ancient_crypt',
      'ashen_wasteland',
      'aether_sanctum',
    ];
    const tileKeys = ['floor0', 'floor1', 'floor2', 'wall'];

    test(
      'generates valid 16x16 images for all 5 biomes and all tile types',
      () {
        final atlas = PixelSpriteAtlas.instance;

        for (final biome in biomes) {
          for (final key in tileKeys) {
            final img = atlas.tileSprite(key, biome: biome);
            expect(
              img.width,
              16,
              reason: 'Tile $key for $biome width must be 16',
            );
            expect(
              img.height,
              16,
              reason: 'Tile $key for $biome height must be 16',
            );
          }
        }
      },
    );

    test('caches tile sprites identically for identical biome and key', () {
      final atlas = PixelSpriteAtlas.instance;
      final img1 = atlas.tileSprite('floor1', biome: 'crystal_cavern');
      final img2 = atlas.tileSprite('floor1', biome: 'crystal_cavern');
      expect(identical(img1, img2), isTrue);

      final img3 = atlas.tileSprite('floor1', biome: 'ancient_crypt');
      expect(identical(img1, img3), isFalse);
    });

    test('maintains backward compatibility for legacy keys and null biome', () {
      final atlas = PixelSpriteAtlas.instance;

      final wallTree = atlas.tileSprite('wall_tree');
      expect(wallTree.width, 16);
      expect(wallTree.height, 16);

      final exitLocked = atlas.tileSprite('exit_locked');
      expect(exitLocked.width, 16);
      expect(exitLocked.height, 16);

      final exitUnlocked = atlas.tileSprite('exit_unlocked');
      expect(exitUnlocked.width, 16);
      expect(exitUnlocked.height, 16);

      final defaultFloor = atlas.tileSprite('floor0');
      expect(defaultFloor.width, 16);
      expect(defaultFloor.height, 16);
    });
  });

  group('DebugRoomComponent Biome Support', () {
    test('instantiates with custom biome and defaults to forgotten_forest', () {
      final grid = NavigationGrid.fromAscii(TestRoom.layout);

      final defaultComponent = DebugRoomComponent(
        grid: grid,
        tileSize: GameConstants.tileSize,
      );
      expect(defaultComponent.biome, 'forgotten_forest');

      final cavernComponent = DebugRoomComponent(
        grid: grid,
        tileSize: GameConstants.tileSize,
        biome: 'crystal_cavern',
      );
      expect(cavernComponent.biome, 'crystal_cavern');
    });

    test('builds static room picture for each biome without error', () {
      final grid = NavigationGrid.fromAscii(TestRoom.layout);
      const biomes = [
        'forgotten_forest',
        'crystal_cavern',
        'ancient_crypt',
        'ashen_wasteland',
        'aether_sanctum',
      ];

      for (final biome in biomes) {
        final component = DebugRoomComponent(
          grid: grid,
          tileSize: GameConstants.tileSize,
          biome: biome,
          markers: [const GridPoint(1, 1)],
        );
        expect(component.biome, biome);
      }
    });
  });

  group('DungeonWorld Biome Integration', () {
    test('DungeonWorld accepts dungeonBiome parameter', () async {
      final character = PlayerCharacter(config: progression);
      final inventory = Inventory(definitions: const {});
      final views = InventoryViews(inventory: inventory, character: character);
      final hud = ValueNotifier<HudState>(
        HudState.fromCharacter(character, hp: 100, maxHp: 100),
      );
      final autoSkill = ValueNotifier<bool>(true);
      final config = GameConfig(
        monsters: const {},
        revive: const ReviveConfig(),
        progression: progression,
        items: const {},
        lootTables: const {},
      );

      final world = DungeonWorld(
        config: config,
        character: character,
        views: views,
        hud: hud,
        autoSkill: autoSkill,
        dungeonBiome: 'ancient_crypt',
      );

      expect(world.dungeonBiome, 'ancient_crypt');
    });
  });
}
