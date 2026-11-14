import 'package:echoes_of_aether/core/constants/game_constants.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/game/echoes_game.dart';
import 'package:echoes_of_aether/game/hud/hud_state.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:echoes_of_aether/game/world/dungeon_world.dart';
import 'package:flame/camera.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';

void main() {
  EnemyDefinition makeEnemy(String id) => EnemyDefinition(
    id: id,
    name: id,
    level: 1,
    detectionRange: 10,
    stats: const CombatStats(
      maxHp: 50,
      atk: 5,
      def: 0,
      attackSpeed: 1,
      moveSpeed: 2,
      attackRange: 1,
    ),
  );

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

  GameConfig makeConfig() => GameConfig(
    monsters: {
      'forest_slime': makeEnemy('forest_slime'),
      'forest_goblin': makeEnemy('forest_goblin'),
    },
    revive: const ReviveConfig(),
    progression: progression,
    items: const {},
    lootTables: const {},
  );

  List<String> makeOpenRoom(int cols, int rows) => List.generate(rows, (y) {
    if (y == 0 || y == rows - 1) return '#' * cols;
    return '#${'.' * (cols - 2)}#';
  });

  group('Camera follow & world bounds', () {
    testWidgets('EchoesGame menjaga kamera di dalam world bounds 20x11', (
      tester,
    ) async {
      final config = makeConfig();
      final character = PlayerCharacter(config: progression);
      final inventory = Inventory(definitions: const {});
      final game = EchoesGame(
        config: config,
        character: character,
        inventory: inventory,
        autoSkill: ValueNotifier(true),
      );

      await tester.pumpWidget(GameWidget(game: game));
      await tester.pump();
      await tester.pump();
      game.update(0.05);

      expect(game.world.worldWidth, GameConstants.viewWidth);
      expect(game.world.worldHeight, GameConstants.viewHeight);
      expect(
        game.camera.viewfinder.position.x,
        closeTo(GameConstants.viewWidth / 2, 1e-3),
      );
      expect(
        game.camera.viewfinder.position.y,
        closeTo(GameConstants.viewHeight / 2, 1e-3),
      );
    });

    testWidgets(
      'room lebih besar dari viewport: kamera mengikuti player dan ter-clamp di tepi world',
      (tester) async {
        final config = makeConfig();
        final character = PlayerCharacter(config: progression);
        final inventory = Inventory(definitions: const {});
        final views = InventoryViews(
          inventory: inventory,
          character: character,
        );
        final hud = ValueNotifier(
          HudState.fromCharacter(character, hp: 100, maxHp: 100),
        );

        final world = DungeonWorld(
          config: config,
          character: character,
          views: views,
          hud: hud,
          autoSkill: ValueNotifier(false),
          roomLayout: makeOpenRoom(30, 20),
          playerStart: const GridPoint(15, 10),
        );
        final game = FlameGame<DungeonWorld>(
          world: world,
          camera: CameraComponent.withFixedResolution(
            width: GameConstants.viewWidth,
            height: GameConstants.viewHeight,
          ),
        );

        await tester.pumpWidget(GameWidget(game: game));
        await tester.pump();
        await tester.pump();
        game.update(0.05);

        // Kamera mengikuti posisi playerView saat ini.
        expect(
          game.camera.viewfinder.position.x,
          closeTo(world.playerView.position.x, 1e-3),
        );
        expect(
          game.camera.viewfinder.position.y,
          closeTo(world.playerView.position.y, 1e-3),
        );

        // Pindah ke sudut kiri-atas (1, 1) -> kamera ter-clamp di (160, 88).
        world.simulation.player.follower
          ..walkToCenterOf(const GridPoint(1, 1))
          ..advance(100);
        game.update(0.01);
        expect(
          game.camera.viewfinder.position.x,
          closeTo(GameConstants.viewWidth / 2, 1e-3),
        );
        expect(
          game.camera.viewfinder.position.y,
          closeTo(GameConstants.viewHeight / 2, 1e-3),
        );

        // Pindah ke sudut kanan-bawah (28, 18) -> ter-clamp di (480-160, 320-88).
        world.simulation.player.follower
          ..walkToCenterOf(const GridPoint(28, 18))
          ..advance(100);
        game.update(0.01);
        expect(
          game.camera.viewfinder.position.x,
          closeTo(world.worldWidth - GameConstants.viewWidth / 2, 1e-3),
        );
        expect(
          game.camera.viewfinder.position.y,
          closeTo(world.worldHeight - GameConstants.viewHeight / 2, 1e-3),
        );
      },
    );
  });
}
