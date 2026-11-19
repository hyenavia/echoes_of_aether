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

  group('EnvironmentTilesetRegistry Unit & Fallback Tests', () {
    late EnvironmentTilesetRegistry registry;

    setUp(() {
      registry = EnvironmentTilesetRegistry.instance;
      registry.clear();
      registry.enabled = true;
    });

    tearDown(() {
      registry.clear();
      registry.enabled = true;
    });

    test(
      'Registry returns null when no tileset is registered (fallback mode)',
      () {
        expect(registry.get('forgotten_forest'), isNull);
        expect(registry.hasTileset('forgotten_forest'), isFalse);
        expect(
          registry.tileSprite('floor0', biome: 'forgotten_forest'),
          isNull,
        );
        expect(registry.tileSprite('wall', biome: 'forgotten_forest'), isNull);
      },
    );

    test('Registry returns registered 16x16 tiles when enabled', () {
      final f0 = EnvironmentTilesetRegistry.bakeSolidColorTile(0xFF334455);
      final f1 = EnvironmentTilesetRegistry.bakeSolidColorTile(0xFF445566);
      final f2 = EnvironmentTilesetRegistry.bakeSolidColorTile(0xFF556677);
      final wall = EnvironmentTilesetRegistry.bakeSolidColorTile(0xFF112233);
      final exit = EnvironmentTilesetRegistry.bakeSolidColorTile(0xFFEEDD88);

      final config = EnvironmentTilesetConfig(
        biomeId: 'forgotten_forest',
        name: 'Mock Test Fantasy Dreamland',
        sourcePack: 'fantasy_dreamland',
        floor0: f0,
        floor1: f1,
        floor2: f2,
        wall: wall,
        exitSprite: exit,
      );

      registry.register(config);

      expect(registry.hasTileset('forgotten_forest'), isTrue);
      expect(
        registry.tileSprite('floor0', biome: 'forgotten_forest'),
        equals(f0),
      );
      expect(
        registry.tileSprite('floor1', biome: 'forgotten_forest'),
        equals(f1),
      );
      expect(
        registry.tileSprite('floor2', biome: 'forgotten_forest'),
        equals(f2),
      );
      expect(
        registry.tileSprite('wall', biome: 'forgotten_forest'),
        equals(wall),
      );
      expect(
        registry.tileSprite('wall_tree', biome: 'forgotten_forest'),
        equals(wall),
      );
      expect(
        registry.tileSprite('exit_locked', biome: 'forgotten_forest'),
        equals(exit),
      );
      expect(
        registry.tileSprite('exit_unlocked', biome: 'forgotten_forest'),
        equals(exit),
      );
    });

    test('Toggle enabled = false forces fallback to null', () {
      final f0 = EnvironmentTilesetRegistry.bakeSolidColorTile(0xFF334455);
      final f1 = EnvironmentTilesetRegistry.bakeSolidColorTile(0xFF445566);
      final f2 = EnvironmentTilesetRegistry.bakeSolidColorTile(0xFF556677);
      final wall = EnvironmentTilesetRegistry.bakeSolidColorTile(0xFF112233);

      registry.register(
        EnvironmentTilesetConfig(
          biomeId: 'crystal_cavern',
          name: 'Mock Mines Caves',
          sourcePack: 'mines_caves',
          floor0: f0,
          floor1: f1,
          floor2: f2,
          wall: wall,
        ),
      );

      expect(registry.tileSprite('floor0', biome: 'crystal_cavern'), isNotNull);

      // Disable registry (return to legacy/procedural view)
      registry.enabled = false;
      expect(registry.tileSprite('floor0', biome: 'crystal_cavern'), isNull);

      // Re-enable
      registry.enabled = true;
      expect(
        registry.tileSprite('floor0', biome: 'crystal_cavern'),
        equals(f0),
      );
    });

    test('Normalizes biome aliases correctly', () {
      final f0 = EnvironmentTilesetRegistry.bakeSolidColorTile(0xFF123456);
      final f1 = EnvironmentTilesetRegistry.bakeSolidColorTile(0xFF234567);
      final f2 = EnvironmentTilesetRegistry.bakeSolidColorTile(0xFF345678);
      final wall = EnvironmentTilesetRegistry.bakeSolidColorTile(0xFF456789);

      registry.register(
        EnvironmentTilesetConfig(
          biomeId: 'aether_sanctum',
          name: 'Sanctum Mock',
          sourcePack: 'hybrid',
          floor0: f0,
          floor1: f1,
          floor2: f2,
          wall: wall,
        ),
      );

      expect(
        registry.tileSprite('floor0', biome: 'ascension_sanctum'),
        equals(f0),
      );
    });
  });

  group('Curated Asset Packs Loading & Resolution Test', () {
    setUp(() {
      EnvironmentTilesetRegistry.instance.clear();
      EnvironmentTilesetRegistry.instance.enabled = true;
    });

    tearDown(() {
      EnvironmentTilesetRegistry.instance.clear();
      EnvironmentTilesetRegistry.instance.enabled = true;
    });

    test(
      'Loads curated Fantasy Dreamland & Mines Caves PNG files into registry',
      () async {
        final loaded = await EnvironmentTilesetRegistry.instance
            .loadCuratedAssetPacks();
        expect(
          loaded,
          isTrue,
          reason:
              'Curated asset packs should load successfully from asset bundle',
        );

        // 1. Prototype 1: Fantasy Dreamland (Forgotten Forest)
        expect(
          EnvironmentTilesetRegistry.instance.hasTileset('forgotten_forest'),
          isTrue,
        );
        final fdConfig = EnvironmentTilesetRegistry.instance.get(
          'forgotten_forest',
        )!;
        expect(fdConfig.sourcePack, 'fantasy_dreamland');
        expect(fdConfig.floor0.width, 16);
        expect(fdConfig.floor0.height, 16);
        expect(fdConfig.floor1.width, 16);
        expect(fdConfig.floor1.height, 16);
        expect(fdConfig.floor2.width, 16);
        expect(fdConfig.floor2.height, 16);
        expect(fdConfig.wall.width, 16);
        expect(fdConfig.wall.height, 16);
        expect(fdConfig.decorPillar?.width, 16);
        expect(fdConfig.exitSprite?.width, 16);

        // 2. Prototype 2: Mines & Caves (Crystal Cavern)
        expect(
          EnvironmentTilesetRegistry.instance.hasTileset('crystal_cavern'),
          isTrue,
        );
        final mcConfig = EnvironmentTilesetRegistry.instance.get(
          'crystal_cavern',
        )!;
        expect(mcConfig.sourcePack, 'mines_caves');
        expect(mcConfig.floor0.width, 16);
        expect(mcConfig.floor0.height, 16);
        expect(mcConfig.floor1.width, 16);
        expect(mcConfig.floor1.height, 16);
        expect(mcConfig.floor2.width, 16);
        expect(mcConfig.floor2.height, 16);
        expect(mcConfig.wall.width, 16);
        expect(mcConfig.wall.height, 16);
        expect(mcConfig.decorPillar?.width, 16);
        expect(mcConfig.exitSprite?.width, 16);
      },
    );
  });

  group('Prototypes Integration with DebugRoomComponent & NavigationGrid', () {
    late NavigationGrid testGrid;
    const pathfinder = AStarPathfinder();

    setUp(() async {
      testGrid = NavigationGrid.fromAscii(TestRoom.layout);
      await EnvironmentTilesetRegistry.instance.loadCuratedAssetPacks();
    });

    tearDown(() {
      EnvironmentTilesetRegistry.instance.clear();
      EnvironmentTilesetRegistry.instance.enabled = true;
    });

    test('Prototype 1: Fantasy Dreamland renders static picture and preserves pathfinding', () {
      final room = DebugRoomComponent(
        grid: testGrid,
        tileSize: GameConstants.tileSize,
        biome: 'forgotten_forest',
        markers: const [GridPoint(9, 5)],
      );

      // 1. Dimensions match grid columns and rows (20 x 11 * 16 = 320 x 176)
      expect(room.size.x, GameConstants.viewWidth);
      expect(room.size.y, GameConstants.viewHeight);

      // 2. Render static picture
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      room.render(canvas);
      final pic = recorder.endRecording();
      expect(pic, isNotNull);
      pic.dispose();

      // 3. Navigation grid & collision integrity
      expect(
        testGrid.isWalkable(0, 0),
        isFalse,
        reason: 'Outer wall must not be walkable',
      );
      expect(
        testGrid.isWalkable(TestRoom.playerStart.x, TestRoom.playerStart.y),
        isTrue,
      );

      // 4. A* Pathfinding executes correctly on the room
      final path = pathfinder.findPath(
        testGrid,
        TestRoom.playerStart,
        const GridPoint(9, 5),
      );
      expect(path, isNotNull);
      expect(path!.last, const GridPoint(9, 5));
    });

    test('Prototype 2: Mines & Caves renders static picture and preserves pathfinding', () {
      final room = DebugRoomComponent(
        grid: testGrid,
        tileSize: GameConstants.tileSize,
        biome: 'crystal_cavern',
        markers: const [GridPoint(9, 5)],
      );

      // 1. Dimensions match exact same virtual camera viewport
      expect(room.size.x, GameConstants.viewWidth);
      expect(room.size.y, GameConstants.viewHeight);

      // 2. Render static picture
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      room.render(canvas);
      final pic = recorder.endRecording();
      expect(pic, isNotNull);
      pic.dispose();

      // 3. Collision and pathfinding are identical
      final path = pathfinder.findPath(
        testGrid,
        TestRoom.playerStart,
        const GridPoint(9, 5),
      );
      expect(path, isNotNull);
      expect(path!.first, TestRoom.playerStart);
      expect(path.last, const GridPoint(9, 5));
    });

    test('Dynamically switching biomes preserves resolution scale and navigation state', () {
      final forestRoom = DebugRoomComponent(
        grid: testGrid,
        tileSize: GameConstants.tileSize,
        biome: 'forgotten_forest',
      );
      final cavernRoom = DebugRoomComponent(
        grid: testGrid,
        tileSize: GameConstants.tileSize,
        biome: 'crystal_cavern',
      );

      expect(forestRoom.size, equals(cavernRoom.size));
      expect(forestRoom.tileSize, equals(cavernRoom.tileSize));
      expect(forestRoom.grid.columns, equals(cavernRoom.grid.columns));
      expect(forestRoom.grid.rows, equals(cavernRoom.grid.rows));

      // Test fallback toggle retains stability
      EnvironmentTilesetRegistry.instance.enabled = false;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      cavernRoom.render(canvas);
      final fallbackPic = recorder.endRecording();
      expect(fallbackPic, isNotNull);
      fallbackPic.dispose();
    });
  });
}
