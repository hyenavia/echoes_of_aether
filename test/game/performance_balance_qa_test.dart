import 'dart:io';
import 'dart:math' as math;

import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:echoes_of_aether/domain/services/offline_progression_service.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:echoes_of_aether/game/components/effects/floating_text_component.dart';
import 'package:echoes_of_aether/game/components/effects/skill_vfx_component.dart';
import 'package:echoes_of_aether/game/components/enemies/enemy_component.dart';
import 'package:echoes_of_aether/game/components/player/player_component.dart';
import 'package:echoes_of_aether/game/hud/hud_state.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:echoes_of_aether/game/systems/combat_system.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealGameConfig() {
  const parser = GameConfigParser();
  final settings = _readAsset('game_config.json');
  final config = GameConfig(
    monsters: const MonsterConfigParser().parse(_readAsset('monsters.json')),
    revive: parser.parseRevive(settings),
    progression: parser.parseProgression(settings),
    equipment: parser.parseEquipment(settings),
    dungeonCompletion: parser.parseDungeonCompletion(settings),
    items: const ItemConfigParser().parse(_readAsset('items.json')),
    lootTables: const LootConfigParser().parse(_readAsset('loot_tables.json')),
    skills: const SkillConfigParser().parse(_readAsset('skills.json')),
    specializations: const SpecializationConfigParser().parse(
      _readAsset('specializations.json'),
    ),
    dungeons: const DungeonConfigParser().parse(_readAsset('dungeons.json')),
  );
  const GameConfigValidator().validate(config);
  return config;
}

void main() {
  group('M7 Stage 3 — Performance & Large-Encounter Stress Tests', () {
    test('CombatSimulation dengan 24 musuh simultan + AoE skill selesai cepat dan deterministik', () {
      const progression = ProgressionConfig(
        maxLevel: 20,
        expBase: 50,
        expGrowth: 1.4,
        baseStats: CombatStats(
          maxHp: 500,
          atk: 30,
          def: 8,
          attackSpeed: 2.0,
          moveSpeed: 5.0,
          attackRange: 4.0,
        ),
        perLevel: LevelGrowth(hp: 20, atk: 3, def: 1),
      );
      const aoe = SkillDefinition(
        id: 'aether_burst',
        name: 'Aether Burst',
        type: SkillType.active,
        effect: SkillEffectType.damage,
        damageType: SkillDamageType.magic,
        cooldownSeconds: 3.0,
        baseValue: 1.5,
        valuePerLevel: 0.2,
        maxLevel: 5,
        unlockLevel: 1,
        targetType: SkillTarget.area,
        radius: 3.0,
        range: 4.0,
        minEnemies: 2,
      );
      const mob = EnemyDefinition(
        id: 'forest_wolf',
        name: 'Forest Wolf',
        level: 2,
        detectionRange: 10,
        stats: CombatStats(maxHp: 60, atk: 6, def: 1, attackRange: 1.0),
      );

      final player = Combatant(
        id: 'player',
        team: Team.player,
        stats: progression.baseStats,
        cell: const GridPoint(12, 8),
      );
      final sim = CombatSimulation(
        grid: NavigationGrid.open(columns: 24, rows: 16),
        pathfinder: const AStarPathfinder(),
        player: player,
        seed: 99,
      )..setPlayerSkills([aoe]);

      for (var i = 0; i < 24; i++) {
        final gx = 4 + (i % 6) * 3;
        final gy = 2 + (i ~/ 6) * 3;
        sim.spawnEnemy(mob, GridPoint(gx, gy));
      }

      final sw = Stopwatch()..start();
      for (var t = 0; t < 400; t++) {
        sim.tick();
        if (sim.aliveEnemies.isEmpty) break;
      }
      sw.stop();

      expect(sw.elapsedMilliseconds, lessThan(1500));
      expect(player.hp, greaterThan(0));
      expect(sim.aliveEnemies.length, lessThan(24));
    });

    testWidgets(
      'CombatSystem & Flame components pada 20 musuh simultan membersihkan transient VFX & view dengan bersih',
      (tester) async {
        const mob = EnemyDefinition(
          id: 'aether_slime',
          name: 'Aether Slime',
          level: 1,
          detectionRange: 12,
          stats: CombatStats(maxHp: 45, atk: 3, def: 0, attackRange: 1),
        );
        const progression = ProgressionConfig(
          maxLevel: 20,
          expBase: 50,
          expGrowth: 1.4,
          baseStats: CombatStats(
            maxHp: 400,
            atk: 25,
            def: 5,
            attackSpeed: 2.0,
            moveSpeed: 5.0,
            attackRange: 2.0,
          ),
          perLevel: LevelGrowth(hp: 20, atk: 3, def: 1),
        );
        const config = GameConfig(
          monsters: {'aether_slime': mob},
          revive: ReviveConfig(),
          progression: progression,
          items: {},
          lootTables: {},
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
          cell: const GridPoint(2, 5),
        );
        final sim = CombatSimulation(
          grid: NavigationGrid.open(columns: 16, rows: 12),
          pathfinder: const AStarPathfinder(),
          player: player,
          seed: 5,
        );

        final game = FlameGame();
        await tester.pumpWidget(GameWidget(game: game));
        await tester.pump();

        final container = Component();
        final playerView = PlayerComponent(combatant: player, tileSize: 16);
        final system = CombatSystem(
          simulation: sim,
          config: config,
          character: character,
          views: views,
          hud: ValueNotifier(
            HudState.fromCharacter(character, hp: 400, maxHp: 400),
          ),
          autoSkill: ValueNotifier(true),
          random: math.Random(5),
          tileSize: 16,
          viewParent: container,
          playerView: playerView,
          enableDebugWaveRespawn: false,
        );
        await game.addAll([container, playerView, system]);
        await tester.pump();

        for (var i = 0; i < 20; i++) {
          sim.spawnEnemy(mob, GridPoint(3 + (i % 5) * 2, 2 + (i ~/ 5) * 2));
        }
        system.syncEnemyViews();
        await tester.pump();

        expect(container.children.whereType<EnemyComponent>(), hasLength(20));

        for (var i = 0; i < 30; i++) {
          game.update(0.1);
        }

        // Bersihkan seluruh room view dan pastikan tidak ada Enemy/VFX/FloatingText tertinggal.
        system.clearRoomViews();
        game.update(0);
        while (game.hasLifecycleEvents) {
          game.processLifecycleEvents();
        }

        expect(container.children.whereType<EnemyComponent>(), isEmpty);
        expect(container.children.whereType<SkillVfxComponent>(), isEmpty);
        expect(container.children.whereType<FloatingTextComponent>(), isEmpty);
      },
    );
  });

  group('M7 Stage 3 — Balance & Offline Economy QA (Config Nyata)', () {
    test('8-jam Mode B Auto Farming pada Forgotten Forest menghasilkan progres seimbang dan batas level aman', () {
      final config = _loadRealGameConfig();
      final character = PlayerCharacter(
        config: config.progression,
        skillCatalog: config.skills,
        specializationConfig: config.specializations,
      )..receiveReward(exp: 800, gold: 200); // ~Lv 5
      character.chooseSpecialization('arcanist');
      final inventory = Inventory(definitions: config.items);
      const startTime = 1700000000000;
      final elapsed8Hours =
          OfflineProgressionService.maxOfflineDuration.inMilliseconds;

      const forestProgress = DungeonProgressSnapshot(
        currentDungeonId: 'forgotten_forest',
        currentRoomId: 'forest_entrance',
        currentRoomIndex: 0,
        highestClearedRoomIndex: 4,
        clearsCount: 1,
        clearedInCycleRank: 0,
      );
      final activity = const OfflineActivitySnapshot.paused().withAutoFarming(
        dungeonId: 'forgotten_forest',
        checkpointAtMs: startTime,
        simulationSeed: 42,
      );
      final rp = RewardProcessor(
        character: character,
        inventory: inventory,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: EquipmentFactory(config.equipment),
      );

      const service = OfflineProgressionService();
      final res = service.process(
        character: character,
        inventory: inventory,
        config: config,
        session: const GameSessionSnapshot(
          lastActiveAtMs: startTime,
          lastSavedAtMs: startTime,
          lastOfflineClaimAtMs: startTime,
        ),
        offlineActivity: activity,
        dungeonProgress: forestProgress,
        dungeonProgresses: const {'forgotten_forest': forestProgress},
        rewardProcessor: rp,
        nowMs: startTime + elapsed8Hours + 3600000, // 9 jam -> di-cap 8 jam
        simulationSeed: 42,
        maxIterations: 200000,
      );

      expect(res.status, OfflineProgressionStatus.applied);
      expect(res.cappedAtMaxDuration, isTrue);
      expect(res.effectiveElapsed.inMilliseconds, elapsed8Hours);
      expect(res.runsAttempted, greaterThan(0));
      expect(res.runsCompleted, greaterThan(0));
      expect(res.expGained, greaterThan(0));
      expect(res.goldGained, greaterThan(0));
      if (config.progression.maxLevel != null) {
        expect(
          character.level,
          lessThanOrEqualTo(config.progression.maxLevel!),
        );
      } else {
        expect(
          character.level,
          lessThanOrEqualTo(ProgressionConfig.kTechnicalMaxLevel),
        );
      }
      expect(character.gold, greaterThanOrEqualTo(200 + res.goldGained));
    });
  });
}
