import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:echoes_of_aether/game/components/effects/floating_text_component.dart';
import 'package:echoes_of_aether/game/components/effects/skill_vfx_component.dart';
import 'package:echoes_of_aether/game/components/enemies/enemy_component.dart';
import 'package:echoes_of_aether/game/components/player/player_component.dart';
import 'package:echoes_of_aether/game/hud/hud_state.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:echoes_of_aether/game/systems/combat_system.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SkillVfxComponent Comprehensive Suite', () {
    test('all factory constructors create valid components with distinct properties', () {
      final pos = Vector2(32, 32);

      final slash = SkillVfxComponent.slash(position: pos);
      expect(slash.type, SkillVfxType.slash);

      final heavySlash = SkillVfxComponent.heavySlash(position: pos);
      expect(heavySlash.type, SkillVfxType.heavySlash);

      final arcane = SkillVfxComponent.arcaneBurst(position: pos);
      expect(arcane.type, SkillVfxType.arcaneBurst);

      final meteor = SkillVfxComponent.meteorFall(position: pos);
      expect(meteor.type, SkillVfxType.meteorFall);

      final arrow = SkillVfxComponent.arrowShot(position: pos);
      expect(arrow.type, SkillVfxType.arrowShot);

      final siphon = SkillVfxComponent.lifeSiphon(position: pos);
      expect(siphon.type, SkillVfxType.lifeSiphon);

      final slam = SkillVfxComponent.groundSlam(position: pos);
      expect(slam.type, SkillVfxType.groundSlam);

      final heal = SkillVfxComponent.healPulse(position: pos);
      expect(heal.type, SkillVfxType.healPulse);

      final crit = SkillVfxComponent.critSpark(position: pos);
      expect(crit.type, SkillVfxType.critSpark);

      final defeatNormal = SkillVfxComponent.defeatBurst(position: pos);
      expect(defeatNormal.type, SkillVfxType.defeatBurst);

      final defeatElite = SkillVfxComponent.defeatBurst(
        position: pos,
        isElite: true,
      );
      expect(defeatElite.type, SkillVfxType.defeatBurst);
      expect(defeatElite.radius, greaterThan(defeatNormal.radius));

      final defeatBoss = SkillVfxComponent.defeatBurst(
        position: pos,
        isBoss: true,
      );
      expect(defeatBoss.type, SkillVfxType.defeatBurst);
      expect(defeatBoss.radius, greaterThan(defeatElite.radius));
      expect(defeatBoss.duration, greaterThan(defeatNormal.duration));
    });

    test(
      'all VFX types render to Canvas without error across full lifecycle',
      () {
        final pos = Vector2(24, 24);
        final effects = [
          SkillVfxComponent.slash(position: pos),
          SkillVfxComponent.heavySlash(position: pos),
          SkillVfxComponent.arcaneBurst(position: pos),
          SkillVfxComponent.meteorFall(position: pos),
          SkillVfxComponent.arrowShot(position: pos),
          SkillVfxComponent.lifeSiphon(position: pos),
          SkillVfxComponent.groundSlam(position: pos),
          SkillVfxComponent.healPulse(position: pos),
          SkillVfxComponent.critSpark(position: pos),
          SkillVfxComponent.defeatBurst(position: pos, isBoss: true),
        ];

        for (final fx in effects) {
          for (var step = 0; step < 5; step++) {
            fx.update(fx.duration * 0.2);
            final recorder = ui.PictureRecorder();
            final canvas = ui.Canvas(recorder);
            fx.render(canvas);
            final picture = recorder.endRecording();
            picture.dispose();
          }
        }
      },
    );

    testWidgets('auto-removes from parent after duration expires', (
      tester,
    ) async {
      final game = FlameGame();
      await tester.pumpWidget(GameWidget(game: game));

      final vfx = SkillVfxComponent.heavySlash(position: Vector2(20, 20));
      await game.add(vfx);
      game.update(0);
      await tester.pump();

      expect(game.children.whereType<SkillVfxComponent>(), hasLength(1));

      // Advance past duration (0.28s)
      game.update(0.35);
      game.update(0);

      expect(game.children.whereType<SkillVfxComponent>(), isEmpty);
    });
  });

  group('FloatingTextComponent Pop & Crit Enhancements', () {
    test('renders normal, heal, and crit text with scale pop and shadows', () {
      final normalText = FloatingTextComponent(
        text: '45',
        position: Vector2(20, 20),
        color: const ui.Color(0xFFFFFFFF),
      );

      final critText = FloatingTextComponent(
        text: '120!',
        position: Vector2(20, 20),
        color: const ui.Color(0xFFFFD54F),
        isBold: true,
        isCrit: true,
        fontSize: 9,
      );

      expect(critText.isCrit, isTrue);

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // Render normal
      normalText.render(canvas);

      // Render crit at early pop (< 20% duration)
      critText.render(canvas);
      critText.update(0.05);
      critText.render(canvas);

      // Render crit at late progress (> 20% duration)
      critText.update(0.30);
      critText.render(canvas);

      final picture = recorder.endRecording();
      picture.dispose();

      normalText.onRemove();
      critText.onRemove();
    });
  });

  group('CombatantComponent Telegraph & Hit Feedback', () {
    test('renders attack telegraph gleam for elite and boss during attack animation', () {
      final boss = Combatant(
        id: 'boss_test',
        team: Team.enemy,
        stats: const CombatStats(maxHp: 200, atk: 25, def: 5),
        cell: const GridPoint(5, 5),
        isBoss: true,
      );
      final bossView = EnemyComponent(combatant: boss, tileSize: 16);
      bossView.triggerAttackAnimation(0.25);

      final elite = Combatant(
        id: 'elite_test',
        team: Team.enemy,
        stats: const CombatStats(maxHp: 100, atk: 15, def: 3),
        cell: const GridPoint(6, 5),
        isElite: true,
      );
      final eliteView = EnemyComponent(combatant: elite, tileSize: 16);
      eliteView.triggerAttackAnimation(0.25);

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      bossView.render(canvas);
      eliteView.render(canvas);

      final picture = recorder.endRecording();
      picture.dispose();
    });
  });

  group('CombatSystem VFX Dispatch & Death Motes Integration', () {
    const progression = ProgressionConfig(
      maxLevel: 10,
      expBase: 50,
      expGrowth: 1.4,
      baseStats: CombatStats(
        maxHp: 100,
        atk: 50,
        def: 5,
        attackSpeed: 2,
        moveSpeed: 4,
        attackRange: 1.5,
      ),
      perLevel: LevelGrowth(hp: 10, atk: 2, def: 1),
    );

    const testEnemyDef = EnemyDefinition(
      id: 'test_enemy',
      name: 'Test Enemy',
      level: 1,
      detectionRange: 10,
      stats: CombatStats(
        maxHp: 20,
        atk: 2,
        def: 0,
        attackSpeed: 1,
        moveSpeed: 2,
        attackRange: 1,
      ),
    );

    test('CombatSystem memunculkan floating text, attack VFX, dan defeat burst saat musuh mati', () async {
      final config = GameConfig(
        monsters: const {'test_enemy': testEnemyDef},
        revive: const ReviveConfig(),
        progression: progression,
        items: const {},
        lootTables: const {},
      );

      final character = PlayerCharacter(config: progression);
      final inventory = Inventory(definitions: const {});
      final views = InventoryViews(inventory: inventory, character: character);
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

      // Spawn musuh tepat di samping player agar langsung diserang
      final enemy = sim.spawnEnemy(testEnemyDef, const GridPoint(2, 1));
      expect(enemy.isAlive, isTrue);

      // Jalankan beberapa tick combat hingga musuh diserang dan mati
      for (var i = 0; i < 20; i++) {
        system.update(CombatSimulation.tickSeconds);
        game.update(0);
        if (!enemy.isAlive) break;
      }

      // Verifikasi floating text muncul
      final floating = container.children.whereType<FloatingTextComponent>();
      expect(floating, isNotEmpty);

      // Verifikasi attack VFX / defeat burst terpancarkan
      final allVfx = container.children.whereType<SkillVfxComponent>();
      expect(allVfx, isNotEmpty);

      // Musuh harus sudah mati karena ATK player 50 vs HP musuh 20
      expect(enemy.isAlive, isFalse);

      // Verifikasi terdapat defeat burst VFX
      final defeatBursts = allVfx.where(
        (vfx) => vfx.type == SkillVfxType.defeatBurst,
      );
      expect(defeatBursts, isNotEmpty);
    });
  });
}
