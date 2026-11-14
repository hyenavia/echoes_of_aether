import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/providers/database_provider.dart';
import 'package:echoes_of_aether/application/providers/game_config_provider.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:echoes_of_aether/features/dungeon/dungeon_completed_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/dungeon_screen.dart';
import 'package:echoes_of_aether/features/dungeon/town_hub_view.dart';
import 'package:echoes_of_aether/game/components/enemies/enemy_component.dart';
import 'package:echoes_of_aether/game/echoes_game.dart';
import 'package:echoes_of_aether/game/hud/hud_state.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:echoes_of_aether/game/systems/combat_system.dart';
import 'package:echoes_of_aether/game/visuals/pixel_sprite_atlas.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealConfig({ProgressionConfig? progressionOverride}) {
  const parser = GameConfigParser();
  final settings = _readAsset('game_config.json');
  final difficulty = parser.parseDifficulty(settings);
  final config = GameConfig(
    monsters: const MonsterConfigParser().parse(_readAsset('monsters.json')),
    damage: parser.parseDamage(settings),
    difficulty: difficulty,
    farming: parser.parseFarming(settings),
    revive: parser.parseRevive(settings),
    progression: progressionOverride ?? parser.parseProgression(settings),
    equipment: parser.parseEquipment(settings),
    dungeonCompletion: parser.parseDungeonCompletion(settings),
    items: const ItemConfigParser().parse(_readAsset('items.json')),
    lootTables: const LootConfigParser().parse(_readAsset('loot_tables.json')),
    skills: const SkillConfigParser().parse(_readAsset('skills.json')),
    specializations: const SpecializationConfigParser().parse(
      _readAsset('specializations.json'),
    ),
    dungeons: const DungeonConfigParser().parse(
      _readAsset('dungeons.json'),
      ascensionMultiplier: difficulty.ascensionMultiplier,
    ),
  );
  const GameConfigValidator().validate(config);
  return config;
}

Future<void> _flushDb() async {
  await Future<void>.delayed(const Duration(milliseconds: 60));
}

void main() {
  group('M8 Stage 5 — PixelSpriteAtlas spriteRef & spriteTint', () {
    test('resolveEnemySpecies memetakan spriteRef, fallback ke definitionId, dan fallback akhir enemy_generic', () {
      expect(
        PixelSpriteAtlas.resolveEnemySpecies(
          spriteRef: 'aether_slime',
          definitionId: 'crystal_slime',
        ),
        'aether_slime',
      );
      expect(
        PixelSpriteAtlas.resolveEnemySpecies(
          spriteRef: 'forest_wolf',
          definitionId: 'bone_hound',
        ),
        'forest_wolf',
      );
      expect(
        PixelSpriteAtlas.resolveEnemySpecies(
          spriteRef: 'corrupted_treant',
          definitionId: 'slag_colossus',
        ),
        'corrupted_treant',
      );
      expect(
        PixelSpriteAtlas.resolveEnemySpecies(
          spriteRef: 'corrupted_guardian',
          definitionId: 'sanctum_guardian',
        ),
        'corrupted_guardian',
      );
      expect(
        PixelSpriteAtlas.resolveEnemySpecies(
          spriteRef: 'ancient_heart_guardian',
          definitionId: 'aether_sovereign',
        ),
        'ancient_heart_guardian',
      );

      // Fallback ketika spriteRef null / kosong -> pakai perilaku lama definitionId.
      expect(
        PixelSpriteAtlas.resolveEnemySpecies(
          spriteRef: null,
          definitionId: 'forest_slime',
        ),
        'aether_slime',
      );
      expect(
        PixelSpriteAtlas.resolveEnemySpecies(
          spriteRef: '   ',
          definitionId: 'corrupted_guardian',
        ),
        'corrupted_guardian',
      );
      expect(
        PixelSpriteAtlas.resolveEnemySpecies(
          spriteRef: null,
          definitionId: 'unknown_monster',
        ),
        'enemy_generic',
      );
      expect(
        PixelSpriteAtlas.resolveEnemySpecies(
          spriteRef: 'unknown_ref',
          definitionId: 'unknown_monster',
        ),
        'enemy_generic',
      );
    });

    test('seluruh monster aktif di dungeons.json terpetakan ke species non-generic, monster baru bertint valid, dan legacy fallback terjaga', () {
      final config = _loadRealConfig();
      final spawnedMonsterIds = <String>{
        for (final dungeon in config.dungeons.values)
          for (final room in dungeon.rooms.values)
            for (final spawn in room.spawns) spawn.monsterId,
      };
      for (final monsterId in spawnedMonsterIds) {
        final monster = config.monsters[monsterId]!;
        final species = PixelSpriteAtlas.resolveEnemySpecies(
          spriteRef: monster.spriteRef,
          definitionId: monster.id,
        );
        expect(
          species,
          isNot('enemy_generic'),
          reason: 'Monster "$monsterId" harus terpetakan ke sprite valid.',
        );
        if (monster.spriteRef != null) {
          expect(
            PixelSpriteAtlas.parseHexTintColor(monster.spriteTint),
            isNotNull,
            reason: 'Monster "$monsterId" perlu sprite_tint valid.',
          );
        }
      }

      // Perilaku fallback lama: monster tanpa spriteRef yang tidak terdaftar di
      // map species tetap memetakan ke enemy_generic.
      expect(
        PixelSpriteAtlas.resolveEnemySpecies(
          spriteRef: config.monsters['forest_goblin']!.spriteRef,
          definitionId: 'forest_goblin',
        ),
        'enemy_generic',
      );
    });

    test('parseHexTintColor mem-parse #RRGGBB dan #AARRGGBB serta mengabaikan input invalid', () {
      expect(
        PixelSpriteAtlas.parseHexTintColor('#7FD8FF'),
        const Color(0xFF7FD8FF),
      );
      expect(
        PixelSpriteAtlas.parseHexTintColor('#ccB39DDB'),
        const Color(0xCCB39DDB),
      );
      expect(PixelSpriteAtlas.parseHexTintColor(null), isNull);
      expect(PixelSpriteAtlas.parseHexTintColor('invalid'), isNull);
      expect(PixelSpriteAtlas.parseHexTintColor('#123'), isNull);
    });

    test('combatantSprite berbagi cache image dengan species target dan render EnemyComponent menerapkan ColorFilter tint bersih', () async {
      final atlas = PixelSpriteAtlas.instance;
      final base = atlas.combatantSprite(
        isPlayer: false,
        definitionId: 'aether_slime',
        pose: 'idle0',
      );
      final viaRef = atlas.combatantSprite(
        isPlayer: false,
        definitionId: 'crystal_slime',
        spriteRef: 'aether_slime',
        pose: 'idle0',
      );
      expect(identical(base, viaRef), isTrue);

      // Verifikasi sinkronisasi EnemyComponent via CombatSystem + render piksel bertint.
      final config = _loadRealConfig();
      final grid = NavigationGrid.fromAscii(const [
        '#######',
        '#.....#',
        '#######',
      ]);
      final player = Combatant(
        id: 'player',
        team: Team.player,
        stats: config.progression.baseStats,
        cell: const GridPoint(1, 1),
      );
      final sim = CombatSimulation(
        grid: grid,
        pathfinder: AStarPathfinder(),
        player: player,
        seed: 7,
      );
      final slimeDef = config.monsters['crystal_slime']!;
      sim.spawnEnemy(slimeDef, const GridPoint(4, 1));

      final character = PlayerCharacter(config: config.progression);
      final inventory = Inventory(definitions: config.items);
      final container = PositionComponent();
      final combatSystem = CombatSystem(
        simulation: sim,
        config: config,
        character: character,
        views: InventoryViews(inventory: inventory, character: character),
        hud: ValueNotifier(
          HudState.fromCharacter(character, hp: 100, maxHp: 100),
        ),
        autoSkill: ValueNotifier(true),
        random: math.Random(7),
        tileSize: 16,
        viewParent: container,
      );
      combatSystem.syncEnemyViews();
      final views = container.children.whereType<EnemyComponent>().toList();
      expect(views, hasLength(1));
      final enemyView = views.single;
      expect(enemyView.spriteRef, 'aether_slime');
      expect(enemyView.spriteTint, const Color(0xFF7FD8FF));
      expect(
        enemyView.spriteTintColorFilter,
        const ui.ColorFilter.mode(Color(0xFF7FD8FF), ui.BlendMode.modulate),
      );

      Future<ui.Image> rasterize(EnemyComponent view) async {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        view.render(canvas);
        final picture = recorder.endRecording();
        final img = picture.toImageSync(16, 16);
        picture.dispose();
        return img;
      }

      final untintedView = EnemyComponent(
        combatant: sim.aliveEnemies.single,
        tileSize: 16,
        atlas: atlas,
        spriteRef: 'aether_slime',
      );
      final untintedImg = await rasterize(untintedView);
      final tintedImg = await rasterize(enemyView);

      final untintedBytes = (await untintedImg.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      final tintedBytes = (await tintedImg.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      untintedImg.dispose();
      tintedImg.dispose();

      // Sudut (0,0) tetap transparan, dan piksel tengah (8,8) berubah warna karena modulate tint.
      expect(tintedBytes[3], 0);
      final centerIdx = (8 * 16 + 8) * 4;
      expect(tintedBytes[centerIdx + 3], greaterThan(0));
      final differs =
          tintedBytes[centerIdx] != untintedBytes[centerIdx] ||
          tintedBytes[centerIdx + 1] != untintedBytes[centerIdx + 1] ||
          tintedBytes[centerIdx + 2] != untintedBytes[centerIdx + 2];
      expect(differs, isTrue);
    });
  });

  group('M8 Stage 5 — Label Final Boss di Overlay Hasil', () {
    testWidgets(
      'DungeonCompletedOverlay hanya menampilkan label Final Boss jika isFinalBoss == true',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DungeonCompletedOverlay(
                dungeonName: 'Forgotten Forest',
                clearedRoomsCount: 5,
                onRetry: () {},
                onReturnToTown: () {},
              ),
            ),
          ),
        );
        expect(find.text('Dungeon Selesai!'), findsOneWidget);
        expect(find.text('Final Boss'), findsNothing);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DungeonCompletedOverlay(
                dungeonName: 'Aether Sanctum',
                clearedRoomsCount: 5,
                isFinalBoss: true,
                onRetry: () {},
                onReturnToTown: () {},
              ),
            ),
          ),
        );
        expect(find.text('Dungeon Selesai!'), findsOneWidget);
        expect(find.text('Final Boss'), findsOneWidget);
      },
    );

    testWidgets(
      'Integrasi DungeonScreen: menyelesaikan Dungeon 5 (Aether Sanctum) memunculkan label Final Boss',
      (tester) async {
        final config = _loadRealConfig(
          progressionOverride: const ProgressionConfig(
            maxLevel: 99,
            expBase: 10000,
            expGrowth: 1.5,
            baseStats: CombatStats(
              maxHp: 5000,
              atk: 800,
              def: 150,
              attackSpeed: 5.0,
              critRate: 0.2,
              critDamage: 1.5,
              moveSpeed: 9.0,
              attackRange: 3.0,
            ),
            perLevel: LevelGrowth(hp: 20, atk: 5, def: 2),
          ),
        );

        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        await tester.runAsync(() async {
          await db.initialize();
          final repo = DriftPlayerSaveRepository(db: db, config: config);
          await repo.saveSnapshot(
            PlayerSaveSnapshot(
              character: const PlayerCharacterSnapshot(
                progress: PlayerProgress(level: 35, gold: 500),
              ),
              inventory: const InventorySnapshot(),
              cycleProgress: const CycleProgress(
                ascensionRank: 0,
                lastNormalDungeonId: 'aether_sanctum',
              ),
              dungeon: const DungeonProgressSnapshot(
                currentDungeonId: 'aether_sanctum',
              ),
              dungeonProgresses: const {
                'forgotten_forest': DungeonProgressSnapshot(
                  currentDungeonId: 'forgotten_forest',
                  clearsCount: 1,
                  clearedInCycleRank: 0,
                ),
                'crystal_cavern': DungeonProgressSnapshot(
                  currentDungeonId: 'crystal_cavern',
                  clearsCount: 1,
                  clearedInCycleRank: 0,
                ),
                'ancient_crypt': DungeonProgressSnapshot(
                  currentDungeonId: 'ancient_crypt',
                  clearsCount: 1,
                  clearedInCycleRank: 0,
                ),
                'ashen_wasteland': DungeonProgressSnapshot(
                  currentDungeonId: 'ashen_wasteland',
                  clearsCount: 1,
                  clearedInCycleRank: 0,
                ),
                'aether_sanctum': DungeonProgressSnapshot(
                  currentDungeonId: 'aether_sanctum',
                  clearsCount: 0,
                  clearedInCycleRank: -1,
                ),
              },
              offlineActivity: const OfflineActivitySnapshot.paused(),
            ),
          );
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              gameConfigProvider.overrideWith((ref) async => config),
              playerSaveRepositoryProvider.overrideWith(
                (ref) async =>
                    DriftPlayerSaveRepository(db: db, config: config),
              ),
            ],
            child: const MaterialApp(
              home: DungeonScreen(roomTransitionDelaySeconds: 0.05),
            ),
          ),
        );

        for (var i = 0; i < 20; i++) {
          await tester.pump();
          await tester.runAsync(_flushDb);
          await tester.pump();
          if (find.byType(TownHubView).evaluate().isNotEmpty) break;
        }
        expect(find.byType(TownHubView), findsOneWidget);

        await tester.ensureVisible(find.text('Masuk Aether Sanctum'));
        await tester.tap(find.text('Masuk Aether Sanctum'));
        await tester.pump();
        await tester.pump();
        expect(find.byType(GameWidget<EchoesGame>), findsOneWidget);

        final game = tester
            .widget<GameWidget<EchoesGame>>(find.byType(GameWidget<EchoesGame>))
            .game!;

        for (var i = 0; i < 400; i++) {
          game.update(0.2);
          await tester.pump();
          final pending = game.world.pendingRoomLoad;
          if (pending != null) {
            await pending;
            await tester.pump();
          }
          if (find.byType(DungeonCompletedOverlay).evaluate().isNotEmpty) {
            break;
          }
        }

        expect(find.byType(DungeonCompletedOverlay), findsOneWidget);
        expect(find.text('Final Boss'), findsOneWidget);
        expect(
          find.textContaining('Aether Sanctum ditaklukkan'),
          findsOneWidget,
        );
        await tester.runAsync(_flushDb);
      },
    );
  });
}
