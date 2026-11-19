import 'dart:io';
import 'dart:ui' as ui;

import 'package:echoes_of_aether/core/constants/game_constants.dart';
import 'package:echoes_of_aether/core/constants/test_room.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:echoes_of_aether/game/components/enemies/enemy_component.dart';
import 'package:echoes_of_aether/game/components/player/player_component.dart';
import 'package:echoes_of_aether/game/visuals/environment_tileset.dart';
import 'package:echoes_of_aether/game/world/debug_room_component.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Visual Prototype Rendering & Screenshot Export', () {
    setUpAll(() async {
      await EnvironmentTilesetRegistry.instance.loadCuratedAssetPacks();
    });

    tearDownAll(() {
      EnvironmentTilesetRegistry.instance.clear();
      EnvironmentTilesetRegistry.instance.enabled = true;
    });

    test(
      'Renders and saves Prototype 1: Fantasy Dreamland (Forgotten Forest)',
      () async {
        final grid = NavigationGrid.fromAscii(TestRoom.layout);
        const width = GameConstants.viewWidth; // 320
        const height = GameConstants.viewHeight; // 176

        final room = DebugRoomComponent(
          grid: grid,
          tileSize: GameConstants.tileSize,
          biome: 'forgotten_forest',
          markers: const [GridPoint(18, 9)],
          exitUnlocked: true,
        );

        final player = Combatant(
          id: 'player',
          team: Team.player,
          stats: const CombatStats(maxHp: 150, atk: 25, def: 10),
          cell: const GridPoint(3, 3),
        );
        final playerView = PlayerComponent(
          combatant: player,
          tileSize: GameConstants.tileSize,
          specializationIdProvider: () => 'vanguard',
        );

        final enemy = Combatant(
          id: 'slime_1',
          team: Team.enemy,
          stats: const CombatStats(maxHp: 60, atk: 12, def: 2),
          cell: const GridPoint(14, 3),
        );
        final enemyView = EnemyComponent(
          combatant: enemy,
          tileSize: GameConstants.tileSize,
        );

        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);

        // Background black fill
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, width, height),
          ui.Paint()..color = const ui.Color(0xFF000000),
        );

        // Render room tiles
        room.render(canvas);

        // Render combatants
        canvas.save();
        canvas.translate(
          player.x * GameConstants.tileSize,
          player.y * GameConstants.tileSize,
        );
        playerView.render(canvas);
        canvas.restore();

        canvas.save();
        canvas.translate(
          enemy.x * GameConstants.tileSize,
          enemy.y * GameConstants.tileSize,
        );
        enemyView.render(canvas);
        canvas.restore();

        final picture = recorder.endRecording();
        final image = await picture.toImage(width.toInt(), height.toInt());
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        expect(byteData, isNotNull);

        final outFile = File(
          'assets/environment/prototypes/prototype_fantasy_dreamland.png',
        );
        await outFile.writeAsBytes(byteData!.buffer.asUint8List());
        expect(await outFile.exists(), isTrue);
        expect(await outFile.length(), greaterThan(100));

        picture.dispose();
        image.dispose();
      },
    );

    test(
      'Renders and saves Prototype 2: Mines & Caves (Crystal Cavern)',
      () async {
        final grid = NavigationGrid.fromAscii(TestRoom.layout);
        const width = GameConstants.viewWidth; // 320
        const height = GameConstants.viewHeight; // 176

        final room = DebugRoomComponent(
          grid: grid,
          tileSize: GameConstants.tileSize,
          biome: 'crystal_cavern',
          markers: const [GridPoint(18, 9)],
          exitUnlocked: true,
        );

        final player = Combatant(
          id: 'player',
          team: Team.player,
          stats: const CombatStats(maxHp: 150, atk: 25, def: 10),
          cell: const GridPoint(3, 3),
        );
        final playerView = PlayerComponent(
          combatant: player,
          tileSize: GameConstants.tileSize,
          specializationIdProvider: () => 'vanguard',
        );

        final enemy = Combatant(
          id: 'crystal_enemy',
          team: Team.enemy,
          stats: const CombatStats(maxHp: 80, atk: 15, def: 5),
          cell: const GridPoint(14, 3),
        );
        final enemyView = EnemyComponent(
          combatant: enemy,
          tileSize: GameConstants.tileSize,
        );

        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);

        // Background black fill
        canvas.drawRect(
          const ui.Rect.fromLTWH(0, 0, width, height),
          ui.Paint()..color = const ui.Color(0xFF000000),
        );

        // Render room tiles
        room.render(canvas);

        // Render combatants
        canvas.save();
        canvas.translate(
          player.x * GameConstants.tileSize,
          player.y * GameConstants.tileSize,
        );
        playerView.render(canvas);
        canvas.restore();

        canvas.save();
        canvas.translate(
          enemy.x * GameConstants.tileSize,
          enemy.y * GameConstants.tileSize,
        );
        enemyView.render(canvas);
        canvas.restore();

        final picture = recorder.endRecording();
        final image = await picture.toImage(width.toInt(), height.toInt());
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        expect(byteData, isNotNull);

        final outFile = File(
          'assets/environment/prototypes/prototype_mines_caves.png',
        );
        await outFile.writeAsBytes(byteData!.buffer.asUint8List());
        expect(await outFile.exists(), isTrue);
        expect(await outFile.length(), greaterThan(100));

        picture.dispose();
        image.dispose();
      },
    );
  });
}
