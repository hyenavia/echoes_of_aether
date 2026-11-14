import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/loot_table.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:echoes_of_aether/game/components/combatant_component.dart';
import 'package:echoes_of_aether/game/components/effects/floating_text_component.dart';
import 'package:echoes_of_aether/game/components/player/player_component.dart';
import 'package:echoes_of_aether/game/hud/hud_state.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:echoes_of_aether/game/systems/combat_system.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CombatantComponent visual states', () {
    Combatant makeCombatant({GridPoint cell = const GridPoint(1, 1)}) =>
        Combatant(
          id: 'player',
          team: Team.player,
          stats: const CombatStats(maxHp: 100, atk: 10, def: 2),
          cell: cell,
        );

    test(
      'animationState mengikuti gameplay state (idle, walk, attack, downed)',
      () {
        final c = makeCombatant();
        final view = PlayerComponent(combatant: c, tileSize: 16);

        expect(view.animationState, CombatantAnimationState.idle);

        c.follower.setPath([const GridPoint(1, 1), const GridPoint(3, 1)]);
        expect(view.animationState, CombatantAnimationState.walk);

        view.triggerAttackAnimation(0.2);
        expect(view.animationState, CombatantAnimationState.attack);

        view.update(0.25);
        expect(view.animationState, CombatantAnimationState.walk);

        c.hp = 0;
        expect(view.animationState, CombatantAnimationState.downed);
      },
    );

    test('triggerHitFlash aktif lalu mati setelah durasi selesai', () {
      final view = PlayerComponent(combatant: makeCombatant(), tileSize: 16);
      expect(view.isHitFlashing, isFalse);

      view.triggerHitFlash(0.12);
      expect(view.isHitFlashing, isTrue);

      view.update(0.15);
      expect(view.isHitFlashing, isFalse);
    });
  });

  group('FloatingTextComponent', () {
    testWidgets('naik ke atas lalu terhapus setelah durasi selesai', (
      tester,
    ) async {
      final game = FlameGame();
      await tester.pumpWidget(GameWidget(game: game));
      await tester.pump();

      final text = FloatingTextComponent(
        text: '25',
        position: Vector2(32, 32),
        color: const Color(0xFFFFFFFF),
        duration: 0.5,
        riseSpeed: 20,
      );

      await game.add(text);
      await tester.pump();
      expect(text.parent, game);

      game.update(0.25);
      expect(text.position.y, closeTo(27, 1e-6));
      expect(game.children.contains(text), isTrue);

      game.update(0.3);
      game.update(0);
      expect(game.children.contains(text), isFalse);
    });
  });

  group('CombatSystem feedback dari CombatEvent', () {
    test(
      'AttackEvent memunculkan FloatingTextComponent dan animasi attack',
      () async {
        const slime = EnemyDefinition(
          id: 'forest_slime',
          name: 'Slime',
          level: 1,
          detectionRange: 10,
          stats: CombatStats(
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
        final config = GameConfig(
          monsters: const {'forest_slime': slime},
          revive: const ReviveConfig(),
          progression: progression,
          items: const {},
          lootTables: const {},
        );
        final character = PlayerCharacter(config: progression);
        final inventory = Inventory(definitions: const {});
        final views = InventoryViews(
          inventory: inventory,
          character: character,
        );
        final player = Combatant(
          id: 'player',
          team: Team.player,
          stats: character.stats,
          cell: const GridPoint(1, 1),
        );
        final playerView = PlayerComponent(combatant: player, tileSize: 16);
        final sim = CombatSimulation(
          grid: NavigationGrid.open(columns: 10, rows: 5),
          pathfinder: const AStarPathfinder(),
          player: player,
          seed: 1,
        );

        final game = FlameGame()..onGameResize(Vector2(320, 176));
        await game.onLoad();
        game.onMount();
        final container = Component();
        await game.add(container);
        game.update(0);

        final system = CombatSystem(
          simulation: sim,
          config: config,
          character: character,
          views: views,
          hud: ValueNotifier(
            HudState.fromCharacter(character, hp: 100, maxHp: 100),
          ),
          autoSkill: ValueNotifier(true),
          random: math.Random(1),
          tileSize: 16,
          viewParent: container,
          playerView: playerView,
        );

        // Spawn satu musuh dalam jangkauan serang player lalu jalankan 1 tick.
        sim.spawnEnemy(slime, const GridPoint(2, 1));
        system.update(CombatSimulation.tickSeconds);
        game.update(0);

        final floating = container.children.whereType<FloatingTextComponent>();
        expect(floating, isNotEmpty);
        expect(playerView.animationState, CombatantAnimationState.attack);
      },
    );

    test('EnemyDefeatedEvent diproses lewat RewardProcessor ke character, inventory, dan HUD', () async {
      const slime = EnemyDefinition(
        id: 'forest_slime',
        name: 'Slime',
        level: 1,
        detectionRange: 10,
        expReward: 25,
        goldReward: 9,
        lootTableId: 'slime_loot',
        stats: CombatStats(
          maxHp: 10,
          atk: 1,
          def: 0,
          attackSpeed: 1,
          moveSpeed: 2,
          attackRange: 1,
        ),
      );
      const items = {
        'slime_gel': ItemDefinition(
          id: 'slime_gel',
          name: 'Slime Gel',
          category: ItemCategory.material,
        ),
      };
      const tables = {
        'slime_loot': LootTable(
          id: 'slime_loot',
          entries: [
            LootEntry(
              itemId: 'slime_gel',
              chance: 1.0,
              minQuantity: 2,
              maxQuantity: 2,
            ),
          ],
        ),
      };
      const progression = ProgressionConfig(
        maxLevel: 10,
        expBase: 50,
        expGrowth: 1.4,
        baseStats: CombatStats(
          maxHp: 100,
          atk: 25,
          def: 2,
          attackSpeed: 1,
          moveSpeed: 4,
          attackRange: 1.5,
        ),
        perLevel: LevelGrowth(hp: 10, atk: 2, def: 1),
      );
      const config = GameConfig(
        monsters: {'forest_slime': slime},
        revive: ReviveConfig(),
        progression: progression,
        items: items,
        lootTables: tables,
      );
      final character = PlayerCharacter(config: progression);
      final inventory = Inventory(definitions: items);
      final views = InventoryViews(inventory: inventory, character: character);
      final player = Combatant(
        id: 'player',
        team: Team.player,
        stats: character.stats,
        cell: const GridPoint(1, 1),
      );
      final sim = CombatSimulation(
        grid: NavigationGrid.open(columns: 10, rows: 5),
        pathfinder: const AStarPathfinder(),
        player: player,
        seed: 1,
      );
      final hud = ValueNotifier(
        HudState.fromCharacter(character, hp: 100, maxHp: 100),
      );
      final container = Component();
      final system = CombatSystem(
        simulation: sim,
        config: config,
        character: character,
        views: views,
        hud: hud,
        autoSkill: ValueNotifier(true),
        random: math.Random(1),
        tileSize: 16,
        viewParent: container,
      );

      sim.spawnEnemy(slime, const GridPoint(2, 1));
      system.update(CombatSimulation.tickSeconds);

      expect(character.currentExp, 25);
      expect(character.gold, 9);
      expect(inventory.quantityOf('slime_gel'), 2);
      expect(hud.value.gold, 9);
      expect(hud.value.lastLoot, contains('Slime Gel x2'));
    });
  });
}
