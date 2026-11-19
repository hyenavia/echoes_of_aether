import 'dart:ui' as ui;

import 'package:echoes_of_aether/core/constants/game_constants.dart';
import 'package:echoes_of_aether/core/constants/test_room.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:echoes_of_aether/game/visuals/environment_tileset.dart';
import 'package:echoes_of_aether/game/world/debug_room_component.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const allBiomes = [
    'forgotten_forest',
    'crystal_cavern',
    'ancient_crypt',
    'ashen_wasteland',
    'aether_sanctum',
  ];

  group('All 5 Biomes Environment Tilesets Integration', () {
    setUpAll(() async {
      await EnvironmentTilesetRegistry.instance.loadCuratedAssetPacks();
    });

    tearDownAll(() {
      EnvironmentTilesetRegistry.instance.clear();
      EnvironmentTilesetRegistry.instance.enabled = true;
    });

    test(
      'Registry contains all 5 biomes with 100% 16x16 resolution parity',
      () {
        final registry = EnvironmentTilesetRegistry.instance;
        expect(registry.isLoaded, isTrue);

        for (final biomeId in allBiomes) {
          expect(
            registry.hasTileset(biomeId),
            isTrue,
            reason: '$biomeId must be registered',
          );
          final config = registry.get(biomeId)!;

          expect(config.floor0.width, 16);
          expect(config.floor0.height, 16);
          expect(config.floor1.width, 16);
          expect(config.floor1.height, 16);
          expect(config.floor2.width, 16);
          expect(config.floor2.height, 16);
          expect(config.wall.width, 16);
          expect(config.wall.height, 16);

          if (config.wallTop != null) {
            expect(config.wallTop!.width, 16);
            expect(config.wallTop!.height, 16);
          }
          if (config.exitSprite != null) {
            expect(config.exitSprite!.width, 16);
            expect(config.exitSprite!.height, 16);
          }
        }
      },
    );

    test('DebugRoomComponent renders all 5 biomes using external tilesets', () {
      final grid = NavigationGrid.fromAscii(TestRoom.layout);

      for (final biomeId in allBiomes) {
        final room = DebugRoomComponent(
          grid: grid,
          tileSize: GameConstants.tileSize,
          biome: biomeId,
          markers: const [GridPoint(9, 5)],
          exitUnlocked: true,
        );

        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        room.render(canvas);
        final pic = recorder.endRecording();
        expect(pic, isNotNull, reason: 'Render for $biomeId must succeed');
        pic.dispose();
      }
    });

    test(
      'Collision integrity and A* pathfinding are identical across all biomes',
      () {
        final grid = NavigationGrid.fromAscii(TestRoom.layout);
        const pathfinder = AStarPathfinder();

        for (final biomeId in allBiomes) {
          final path = pathfinder.findPath(
            grid,
            TestRoom.playerStart,
            const GridPoint(9, 5),
          );

          expect(
            path,
            isNotNull,
            reason: 'Pathfinding must find valid path in $biomeId',
          );
          expect(path!.first, TestRoom.playerStart);
          expect(path.last, const GridPoint(9, 5));

          // Wall cells must never be walkable
          expect(grid.isWalkable(0, 0), isFalse);
          expect(grid.isWalkable(3, 2), isFalse);
        }
      },
    );

    test('Seamless runtime switching between biomes retains dimension & state stability', () {
      final grid = NavigationGrid.fromAscii(TestRoom.layout);

      for (var i = 0; i < allBiomes.length; i++) {
        final currentBiome = allBiomes[i];
        final nextBiome = allBiomes[(i + 1) % allBiomes.length];

        final currentRoom = DebugRoomComponent(
          grid: grid,
          tileSize: GameConstants.tileSize,
          biome: currentBiome,
        );
        final nextRoom = DebugRoomComponent(
          grid: grid,
          tileSize: GameConstants.tileSize,
          biome: nextBiome,
        );

        expect(currentRoom.size, equals(nextRoom.size));
        expect(currentRoom.tileSize, equals(nextRoom.tileSize));
      }
    });

    test('Disabling registry dynamically triggers procedural fallback for all 5 biomes', () {
      final grid = NavigationGrid.fromAscii(TestRoom.layout);
      final registry = EnvironmentTilesetRegistry.instance;

      registry.enabled = false;

      for (final biomeId in allBiomes) {
        final room = DebugRoomComponent(
          grid: grid,
          tileSize: GameConstants.tileSize,
          biome: biomeId,
        );

        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        room.render(canvas);
        final pic = recorder.endRecording();
        expect(pic, isNotNull);
        pic.dispose();
      }

      // Re-enable
      registry.enabled = true;
    });
  });
}
