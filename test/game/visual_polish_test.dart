import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/dungeon_manager.dart';
import 'package:echoes_of_aether/domain/services/encounter_tracker.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:echoes_of_aether/game/components/effects/room_transition_curtain.dart';
import 'package:echoes_of_aether/game/components/effects/skill_vfx_component.dart';
import 'package:echoes_of_aether/game/components/enemies/enemy_component.dart';
import 'package:echoes_of_aether/game/components/player/player_component.dart';
import 'package:echoes_of_aether/game/echoes_game.dart';
import 'package:echoes_of_aether/game/hud/hud_state.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:echoes_of_aether/game/systems/combat_system.dart';
import 'package:echoes_of_aether/game/visuals/pixel_sprite_atlas.dart';
import 'package:echoes_of_aether/game/world/debug_room_component.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PixelSpriteAtlas', () {
    test('menghasilkan seluruh sprite hero, monster MVP, dan tile dengan FilterQuality.none', () {
      final atlas = PixelSpriteAtlas.instance;
      expect(PixelSpriteAtlas.pixelPaint.filterQuality, ui.FilterQuality.none);
      expect(PixelSpriteAtlas.pixelPaint.isAntiAlias, isFalse);

      const poses = ['idle0', 'idle1', 'walk0', 'walk1', 'attack', 'downed'];
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

      for (final monster in [
        'aether_slime',
        'forest_wolf',
        'corrupted_treant',
        'corrupted_guardian',
        'ancient_heart_guardian',
        'unknown_monster',
      ]) {
        for (final pose in poses) {
          final img = atlas.combatantSprite(
            isPlayer: false,
            definitionId: monster,
            pose: pose,
          );
          expect(img.width, PixelSpriteAtlas.gridSize);
          expect(img.height, PixelSpriteAtlas.gridSize);
        }
      }

      for (final tile in [
        'floor0',
        'floor1',
        'floor2',
        'wall_tree',
        'exit_locked',
        'exit_unlocked',
      ]) {
        final img = atlas.tileSprite(tile);
        expect(img.width, PixelSpriteAtlas.gridSize);
        expect(img.height, PixelSpriteAtlas.gridSize);
      }

      // Verifikasi cache mengembalikan instance yang sama.
      final first = atlas.combatantSprite(
        isPlayer: true,
        specializationId: 'vanguard',
        pose: 'idle0',
      );
      final second = atlas.combatantSprite(
        isPlayer: true,
        specializationId: 'vanguard',
        pose: 'idle0',
      );
      expect(identical(first, second), isTrue);
    });
  });

  group('CombatantComponent & DebugRoomComponent polish', () {
    test('facing flip, siklus animasi, specialization sprite, dan render berjalan aman', () {
      String? activeSpec = 'vanguard';
      final player = Combatant(
        id: 'player',
        team: Team.player,
        stats: const CombatStats(maxHp: 100, atk: 12, def: 3),
        cell: const GridPoint(5, 5),
      );
      final playerView = PlayerComponent(
        combatant: player,
        tileSize: 16,
        specializationIdProvider: () => activeSpec,
      );

      expect(playerView.spriteSpecializationId, 'vanguard');
      expect(playerView.activePose, 'idle0');
      playerView.update(0.30);
      expect(playerView.activePose, 'idle1');

      activeSpec = 'arcanist';
      expect(playerView.spriteSpecializationId, 'arcanist');

      // Bergerak ke kiri membalik sprite ke kiri; faceToward ke kanan membalik kembali.
      player.follower.setPath([const GridPoint(5, 5), const GridPoint(4, 5)]);
      player.follower.advance(0.5);
      playerView.update(0.05);
      expect(playerView.facingLeft, isTrue);

      playerView.faceToward(7.0);
      expect(playerView.facingLeft, isFalse);

      // Render player + boss + elite + room tilemap ke Canvas nyata untuk verifikasi tanpa error.
      final boss = Combatant(
        id: 'boss_1',
        team: Team.enemy,
        stats: const CombatStats(maxHp: 300, atk: 20, def: 5),
        cell: const GridPoint(7, 5),
        definitionId: 'ancient_heart_guardian',
        isBoss: true,
      );
      final bossView = EnemyComponent(combatant: boss, tileSize: 16);
      bossView.triggerHitFlash(0.15);

      final grid = NavigationGrid.fromAscii([
        '######',
        '#....#',
        '#....#',
        '######',
      ]);
      final room = DebugRoomComponent(
        grid: grid,
        tileSize: 16,
        markers: const [GridPoint(4, 2)],
        exitUnlocked: true,
      );

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      room.update(0.1);
      room.render(canvas);
      playerView.render(canvas);
      bossView.render(canvas);
      boss.hp = 0;
      bossView.render(canvas);
      final picture = recorder.endRecording();
      picture.dispose();

      playerView.resetVisualTransient();
      expect(playerView.activePose, 'walk0');
      player.follower.advance(0.6);
      playerView.update(0.05);
      expect(playerView.activePose, 'idle0');
    });
  });

  group('SkillVfxComponent & RoomTransitionCurtain', () {
    testWidgets(
      'SkillVfxComponent dan RoomTransitionCurtain terhapus otomatis setelah durasi',
      (tester) async {
        final game = FlameGame();
        await tester.pumpWidget(GameWidget(game: game));
        await tester.pump();

        final slash = SkillVfxComponent.slash(position: Vector2(24, 24));
        final arcane = SkillVfxComponent.arcaneBurst(position: Vector2(32, 32));
        final heal = SkillVfxComponent.healPulse(position: Vector2(40, 40));
        final crit = SkillVfxComponent.critSpark(position: Vector2(48, 48));
        final curtain = RoomTransitionCurtain(worldWidth: 160, worldHeight: 96);

        await game.addAll([slash, arcane, heal, crit, curtain]);
        await tester.pump();

        expect(game.children.whereType<SkillVfxComponent>(), hasLength(4));
        expect(game.children.whereType<RoomTransitionCurtain>(), hasLength(1));

        game.update(0.5);
        game.update(0);

        expect(game.children.whereType<SkillVfxComponent>(), isEmpty);
        expect(game.children.whereType<RoomTransitionCurtain>(), isEmpty);
      },
    );

    test('CombatSystem memunculkan SkillVfxComponent untuk magic skill dan cleanup antar-room bersih', () async {
      const slime = EnemyDefinition(
        id: 'aether_slime',
        name: 'Aether Slime',
        level: 1,
        detectionRange: 10,
        stats: CombatStats(
          maxHp: 50,
          atk: 1,
          def: 0,
          attackSpeed: 1,
          moveSpeed: 2,
          attackRange: 1,
        ),
      );
      const aetherBurst = SkillDefinition(
        id: 'aether_burst',
        name: 'Aether Burst',
        type: SkillType.active,
        effect: SkillEffectType.damage,
        damageType: SkillDamageType.magic,
        cooldownSeconds: 4,
        baseValue: 1.6,
        valuePerLevel: 0.2,
        maxLevel: 5,
        unlockLevel: 1,
        targetType: SkillTarget.single,
      );
      const progression = ProgressionConfig(
        maxLevel: 10,
        expBase: 50,
        expGrowth: 1.4,
        baseStats: CombatStats(
          maxHp: 100,
          atk: 20,
          def: 2,
          attackSpeed: 1,
          moveSpeed: 4,
          attackRange: 1.5,
        ),
        perLevel: LevelGrowth(hp: 10, atk: 2, def: 1),
      );
      final config = GameConfig(
        monsters: const {'aether_slime': slime},
        revive: const ReviveConfig(),
        progression: progression,
        items: const {},
        lootTables: const {},
        skills: const {'aether_burst': aetherBurst},
      );
      final character = PlayerCharacter(
        config: progression,
        skillCatalog: config.skills,
      );
      final inventory = Inventory(definitions: const {});
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
      )..setPlayerSkills([aetherBurst]);

      final container = Component();
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
        playerView: PlayerComponent(combatant: player, tileSize: 16),
      );

      sim.spawnEnemy(slime, const GridPoint(2, 1));
      system.update(CombatSimulation.tickSeconds);

      final vfxList = container.children
          .whereType<SkillVfxComponent>()
          .toList();
      expect(vfxList, isNotEmpty);
      expect(vfxList.any((v) => v.type == SkillVfxType.arcaneBurst), isTrue);
    });

    testWidgets(
      'DungeonWorld memasang RoomTransitionCurtain saat transisi dan tidak menyisakan komponen usai dungeon berakhir',
      (tester) async {
        List<String> layout(int cols, int rows) => List.generate(rows, (y) {
          if (y == 0 || y == rows - 1) return '#' * cols;
          return '#${'.' * (cols - 2)}#';
        });
        const progression = ProgressionConfig(
          maxLevel: 10,
          expBase: 50,
          expGrowth: 1.4,
          baseStats: CombatStats(
            maxHp: 200,
            atk: 40,
            def: 5,
            attackSpeed: 2,
            moveSpeed: 5,
            attackRange: 2,
          ),
          perLevel: LevelGrowth(hp: 20, atk: 4, def: 2),
        );
        const boss = EnemyDefinition(
          id: 'ancient_heart_guardian',
          name: 'Ancient Heart Guardian',
          level: 3,
          detectionRange: 10,
          isBoss: true,
          stats: CombatStats(maxHp: 200, atk: 2, def: 0, attackRange: 1),
        );
        final r1 = RoomDefinition(
          id: 'r1',
          dungeonId: 'd1',
          name: 'Room 1',
          type: RoomType.normal,
          mapRef: 'r1',
          layout: layout(8, 5),
          entryPosition: const GridPoint(1, 2),
          exitPosition: const GridPoint(6, 2),
          spawns: const [],
          completionCondition: const RoomCompletionCondition(
            type: RoomCompletionConditionType.reachExit,
          ),
          nextRoomIds: const ['r2'],
        );
        final r2 = RoomDefinition(
          id: 'r2',
          dungeonId: 'd1',
          name: 'Boss Room',
          type: RoomType.boss,
          mapRef: 'r2',
          layout: layout(8, 5),
          entryPosition: const GridPoint(1, 2),
          exitPosition: const GridPoint(6, 2),
          spawns: const [
            RoomSpawnConfig(
              id: 'boss_spawn',
              monsterId: 'ancient_heart_guardian',
              position: GridPoint(4, 2),
              isBoss: true,
            ),
          ],
          completionCondition: const RoomCompletionCondition(
            type: RoomCompletionConditionType.defeatBoss,
          ),
          nextRoomIds: const [],
        );
        final config = GameConfig(
          monsters: const {'ancient_heart_guardian': boss},
          revive: const ReviveConfig(),
          progression: progression,
          items: const {},
          lootTables: const {},
          dungeons: {
            'd1': DungeonDefinition(
              id: 'd1',
              name: 'Forest',
              biome: 'Forest',
              startRoomId: 'r1',
              rooms: {'r1': r1, 'r2': r2},
              roomOrder: const ['r1', 'r2'],
            ),
          },
        );
        final character = PlayerCharacter(config: progression);
        final manager = DungeonManager(
          dungeons: config.dungeons,
          encounterTracker: EncounterTracker(monsterCatalog: config.monsters),
        )..startDungeon('d1');
        final game = EchoesGame(
          config: config,
          character: character,
          inventory: Inventory(definitions: const {}),
          autoSkill: ValueNotifier(true),
          dungeonManager: manager,
          roomTransitionDelaySeconds: 0.05,
          simulationSeed: 7,
        );

        await tester.pumpWidget(GameWidget(game: game));
        await tester.pump();
        await tester.pump();

        var sawCurtain = false;
        for (var i = 0; i < 80; i++) {
          game.update(0.15);
          await tester.pump();
          final pending = game.world.pendingRoomLoad;
          if (pending != null) {
            await pending;
            await tester.pump();
          }
          while (game.hasLifecycleEvents) {
            game.processLifecycleEvents();
          }
          if (game.world.children
              .whereType<RoomTransitionCurtain>()
              .isNotEmpty) {
            sawCurtain = true;
          }
          if (manager.session?.isTerminal ?? false) break;
        }

        expect(manager.session?.status, DungeonSessionStatus.completed);
        expect(sawCurtain, isTrue);
        while (game.hasLifecycleEvents) {
          game.processLifecycleEvents();
        }
        await tester.pump();
        expect(game.world.children.whereType<SkillVfxComponent>(), isEmpty);
        expect(game.world.children.whereType<RoomTransitionCurtain>(), isEmpty);
      },
    );
  });
}
