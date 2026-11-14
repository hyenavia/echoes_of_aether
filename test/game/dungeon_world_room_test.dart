import 'dart:ui' show Color;

import 'package:echoes_of_aether/core/constants/game_constants.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
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
import 'package:echoes_of_aether/domain/services/dungeon_manager.dart';
import 'package:echoes_of_aether/game/components/effects/floating_text_component.dart';
import 'package:echoes_of_aether/game/components/enemies/enemy_component.dart';
import 'package:echoes_of_aether/game/components/player/player_component.dart';
import 'package:echoes_of_aether/game/echoes_game.dart';
import 'package:echoes_of_aether/game/world/debug_room_component.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<String> makeRoomLayout(int cols, int rows) => List.generate(rows, (y) {
    if (y == 0 || y == rows - 1) return '#' * cols;
    return '#${'.' * (cols - 2)}#';
  });

  const progression = ProgressionConfig(
    maxLevel: 10,
    expBase: 50,
    expGrowth: 1.4,
    baseStats: CombatStats(
      maxHp: 120,
      atk: 15,
      def: 3,
      attackSpeed: 1,
      moveSpeed: 4,
      attackRange: 1.5,
    ),
    perLevel: LevelGrowth(hp: 15, atk: 3, def: 1),
  );

  const slime = EnemyDefinition(
    id: 'aether_slime',
    name: 'Aether Slime',
    level: 1,
    detectionRange: 6,
    stats: CombatStats(maxHp: 40, atk: 5, def: 0, attackRange: 1),
  );

  const skill = SkillDefinition(
    id: 'power_strike',
    name: 'Power Strike',
    type: SkillType.active,
    effect: SkillEffectType.damage,
    damageType: SkillDamageType.physical,
    cooldownSeconds: 5.0,
    baseValue: 1.5,
    valuePerLevel: 0.2,
    maxLevel: 5,
    unlockLevel: 1,
    targetType: SkillTarget.single,
  );

  GameConfig makeConfig() {
    final room1 = RoomDefinition(
      id: 'forest_entrance',
      dungeonId: 'forgotten_forest',
      name: 'Forest Entrance',
      type: RoomType.normal,
      mapRef: 'forest_entrance_map',
      layout: makeRoomLayout(20, 11),
      entryPosition: const GridPoint(2, 5),
      exitPosition: const GridPoint(17, 5),
      spawns: const [
        RoomSpawnConfig(
          id: 'fe_1',
          monsterId: 'aether_slime',
          position: GridPoint(10, 5),
        ),
      ],
      completionCondition: const RoomCompletionCondition(),
      nextRoomIds: const ['ancient_path'],
    );
    final room2 = RoomDefinition(
      id: 'ancient_path',
      dungeonId: 'forgotten_forest',
      name: 'Ancient Path',
      type: RoomType.normal,
      mapRef: 'ancient_path_map',
      layout: makeRoomLayout(28, 16),
      entryPosition: const GridPoint(3, 8),
      exitPosition: const GridPoint(24, 8),
      spawns: const [
        RoomSpawnConfig(
          id: 'ap_1',
          monsterId: 'aether_slime',
          position: GridPoint(15, 8),
        ),
      ],
      completionCondition: const RoomCompletionCondition(),
      nextRoomIds: const [],
    );

    return GameConfig(
      monsters: const {'aether_slime': slime},
      revive: const ReviveConfig(),
      progression: progression,
      items: const {},
      lootTables: const {},
      skills: const {'power_strike': skill},
      dungeons: {
        'forgotten_forest': DungeonDefinition(
          id: 'forgotten_forest',
          name: 'Forgotten Forest',
          biome: 'Forest',
          startRoomId: 'forest_entrance',
          rooms: {'forest_entrance': room1, 'ancient_path': room2},
          roomOrder: const ['forest_entrance', 'ancient_path'],
        ),
      },
    );
  }

  group('DungeonWorld & DungeonManager Stage 2 integration', () {
    testWidgets(
      'memuat room awal dari DungeonManager tanpa debug wave respawn dan mengaktifkan room',
      (tester) async {
        final config = makeConfig();
        final character = PlayerCharacter(
          config: progression,
          skillCatalog: config.skills,
        );
        final inventory = Inventory(definitions: const {});
        final manager = DungeonManager(dungeons: config.dungeons);
        manager.startDungeon('forgotten_forest');

        final game = EchoesGame(
          config: config,
          character: character,
          inventory: inventory,
          autoSkill: ValueNotifier(true),
          dungeonManager: manager,
        );

        await tester.pumpWidget(GameWidget(game: game));
        await tester.pump();
        await tester.pump();
        game.update(0.05);

        expect(manager.session?.roomLifecycle, RoomLifecycleState.active);
        expect(game.world.mountedRoomId, 'forest_entrance');
        expect(game.world.preparedSpawns.single.id, 'fe_1');
        expect(
          game.world.simulation.player.follower.currentCell,
          const GridPoint(2, 5),
        );
        // Stage 2: tidak memanggil debug TestRoom wave auto-spawn.
        expect(game.world.simulation.enemies, isEmpty);
        expect(game.hud.value.dungeonName, 'Forgotten Forest');
        expect(game.hud.value.roomName, 'Forest Entrance');

        final roomViews = game.world.children
            .whereType<DebugRoomComponent>()
            .toList();
        expect(roomViews, hasLength(1));
        expect(roomViews.single.markers, const [GridPoint(17, 5)]);
      },
    );

    testWidgets(
      'berpindah ke room baru membersihkan komponen room lama, memperbarui bounds, dan mempertahankan state karakter',
      (tester) async {
        final config = makeConfig();
        final character = PlayerCharacter(
          config: progression,
          skillCatalog: config.skills,
        );
        final inventory = Inventory(definitions: const {});
        final manager = DungeonManager(dungeons: config.dungeons);
        manager.startDungeon('forgotten_forest');

        final game = EchoesGame(
          config: config,
          character: character,
          inventory: inventory,
          autoSkill: ValueNotifier(true),
          dungeonManager: manager,
        );

        await tester.pumpWidget(GameWidget(game: game));
        await tester.pump();
        await tester.pump();
        game.update(0.05);

        final world = game.world;
        final sim = world.simulation;

        // Simulasikan komponen transient & state combat pada room pertama.
        final transientEnemy = sim.spawnEnemy(slime, const GridPoint(8, 5));
        final enemyView = EnemyComponent(
          combatant: transientEnemy,
          tileSize: GameConstants.tileSize,
        );
        final floating = FloatingTextComponent(
          text: '15',
          position: Vector2(32, 32),
          color: const Color(0xFFFFFFFF),
        );
        await world.addAll([enemyView, floating]);
        sim.player.hp = 77;
        sim.player.targetId = transientEnemy.id;
        sim.player.plannedGoal = const GridPoint(7, 5);
        sim.player.follower.setPath(const [GridPoint(2, 5), GridPoint(3, 5)]);
        await tester.pump();
        game.update(0.01);

        expect(world.children.whereType<EnemyComponent>(), hasLength(1));
        expect(world.children.whereType<FloatingTextComponent>(), hasLength(1));

        // Muat room kedua melalui DungeonManager.
        manager.loadRoom('ancient_path');
        await tester.pump();
        await tester.pump();
        await world.pendingRoomLoad;
        await tester.pump();
        game.update(0.05);

        expect(manager.session?.roomLifecycle, RoomLifecycleState.active);
        expect(world.mountedRoomId, 'ancient_path');
        expect(world.preparedSpawns.single.id, 'ap_1');

        // Tidak ada komponen room lama yang tertinggal.
        expect(world.children.whereType<DebugRoomComponent>(), hasLength(1));
        expect(world.children.whereType<PlayerComponent>(), hasLength(1));
        expect(world.children.whereType<EnemyComponent>(), isEmpty);
        expect(world.children.whereType<FloatingTextComponent>(), isEmpty);

        // Penempatan di entry point room baru + dimensi & HUD diperbarui.
        expect(sim.player.follower.currentCell, const GridPoint(3, 8));
        expect(sim.player.follower.isMoving, isFalse);
        expect(sim.player.targetId, isNull);
        expect(sim.player.plannedGoal, isNull);
        expect(world.worldWidth, 28 * GameConstants.tileSize);
        expect(world.worldHeight, 16 * GameConstants.tileSize);
        expect(game.hud.value.roomName, 'Ancient Path');

        // HP & build tetap terjaga lintas-room.
        expect(sim.player.hp, 77);
        expect(
          world.playerView.position.x,
          closeTo(3.5 * GameConstants.tileSize, 1e-3),
        );
        expect(
          world.playerView.position.y,
          closeTo(8.5 * GameConstants.tileSize, 1e-3),
        );

        // Pemanggilan reload room yang sama tidak menggandakan komponen.
        manager.loadRoom('ancient_path');
        await tester.pump();
        game.update(0.01);
        expect(world.children.whereType<DebugRoomComponent>(), hasLength(1));

        // Unmount world melepas listener DungeonManager secara bersih.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(() => manager.exitToTown(), returnsNormally);
      },
    );
  });
}
