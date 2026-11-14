import 'dart:io';

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
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_reward.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/loot_table.dart';
import 'package:echoes_of_aether/domain/entities/player_status.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/features/dungeon/dungeon_completed_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/dungeon_screen.dart';
import 'package:echoes_of_aether/features/dungeon/hud_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/run_ended_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/town_hub_view.dart';
import 'package:echoes_of_aether/game/echoes_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadForgottenForestConfig({required CombatStats playerStats}) {
  const parser = GameConfigParser();
  final settings = _readAsset('game_config.json');
  final base = GameConfig(
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
  const GameConfigValidator().validate(base);

  return GameConfig(
    monsters: base.monsters,
    revive: base.revive,
    progression: ProgressionConfig(
      maxLevel: 30,
      expBase: 10000,
      expGrowth: 1.4,
      baseStats: playerStats,
      perLevel: const LevelGrowth(hp: 20, atk: 5, def: 2),
    ),
    equipment: base.equipment,
    dungeonCompletion: base.dungeonCompletion,
    items: base.items,
    lootTables: base.lootTables,
    skills: base.skills,
    specializations: base.specializations,
    dungeons: base.dungeons,
  );
}

Future<void> _flushAsyncDb() async {
  await Future<void>.delayed(const Duration(milliseconds: 60));
}

Future<void> _mountDungeonApp(
  WidgetTester tester,
  AppDatabase db,
  GameConfig config,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gameConfigProvider.overrideWith((ref) async => config),
        playerSaveRepositoryProvider.overrideWith(
          (ref) async => DriftPlayerSaveRepository(db: db, config: config),
        ),
      ],
      child: const MaterialApp(
        home: DungeonScreen(roomTransitionDelaySeconds: 0.1),
      ),
    ),
  );
  for (var i = 0; i < 20; i++) {
    await tester.pump();
    await tester.runAsync(_flushAsyncDb);
    await tester.pump();
    if (find.byType(TownHubView).evaluate().isNotEmpty ||
        find.byType(HudOverlay).evaluate().isNotEmpty) {
      break;
    }
  }
  await tester.pump();
}

void main() {
  group('Stage 5 End-to-End Integration', () {
    testWidgets(
      '1) Successful dungeon run: menyelesaikan 5 room, menerima completion reward sekali, kembali ke Town, dan restart ke Town tanpa duplikasi',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => tester.runAsync(db.close));
        await tester.runAsync(db.initialize);

        final config = _loadForgottenForestConfig(
          playerStats: const CombatStats(
            maxHp: 2000,
            atk: 450,
            def: 50,
            attackSpeed: 4.0,
            moveSpeed: 10,
            attackRange: 3.0,
          ),
        );

        Future<void> mountApp() => _mountDungeonApp(tester, db, config);

        await mountApp();
        expect(find.byType(TownHubView), findsOneWidget);
        expect(find.text('Total dungeon selesai: 0'), findsOneWidget);

        // Masuk Forgotten Forest.
        await tester.tap(find.text('Masuk Forgotten Forest'));
        await tester.pump();
        await tester.pump();
        expect(find.byType(GameWidget<EchoesGame>), findsOneWidget);

        final game = tester
            .widget<GameWidget<EchoesGame>>(find.byType(GameWidget<EchoesGame>))
            .game!;

        // Jalankan hingga DungeonCompletedOverlay muncul.
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
        expect(find.textContaining('+120 EXP'), findsOneWidget);
        expect(find.textContaining('+50 Gold'), findsOneWidget);

        final goldAfterClear = game.character.gold;
        final expAfterClear = game.character.currentExp;

        // Pastikan update tambahan tidak memicu klaim reward ganda.
        game.update(0.2);
        await tester.pump();
        expect(game.character.gold, goldAfterClear);
        expect(game.character.currentExp, expAfterClear);

        await tester.runAsync(_flushAsyncDb);

        // Kembali ke Town -> progres clear & room tertinggi tercatat.
        await tester.tap(
          find.descendant(
            of: find.byType(DungeonCompletedOverlay),
            matching: find.text('Kembali ke Town'),
          ),
        );
        await tester.pump();
        await tester.runAsync(_flushAsyncDb);
        await tester.pumpAndSettle();

        expect(find.byType(TownHubView), findsOneWidget);
        expect(find.text('Progres room tertinggi: 5 / 5'), findsOneWidget);
        expect(find.text('Total dungeon selesai: 1'), findsOneWidget);

        final savedAfterClear = await tester.runAsync(
          () =>
              DriftPlayerSaveRepository(db: db, config: config).loadSnapshot(),
        );
        expect(savedAfterClear, isNotNull);
        expect(savedAfterClear!.dungeon.clearsCount, 1);
        expect(
          savedAfterClear.activeDungeonSession!.status,
          DungeonSessionStatus.completed,
        );
        expect(
          savedAfterClear.activeDungeonSession!.completionRewardClaimed,
          isTrue,
        );
        final runId = savedAfterClear.activeDungeonSession!.runId;
        expect(
          savedAfterClear.claimedEventIds,
          contains('dungeon_clear:$runId'),
        );

        // Restart aplikasi dengan widget baru pada database yang sama ->
        // langsung masuk ke Town dengan gold & reward sama (tanpa replay dungeon).
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await mountApp();

        expect(find.byType(TownHubView), findsOneWidget);
        expect(find.text('Total dungeon selesai: 1'), findsOneWidget);
        expect(find.textContaining('Gold $goldAfterClear'), findsOneWidget);
      },
    );

    testWidgets(
      '2) Failed dungeon run: Downed -> Auto-revive 30% HP (cooldown 90s) -> kalah saat cooldown -> RunEndedOverlay -> Town dengan loot terkonfirmasi',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => tester.runAsync(db.close));
        await tester.runAsync(db.initialize);

        const twoRoomLayout = <String>[
          '###########',
          '#.........#',
          '#.........#',
          '#.........#',
          '###########',
        ];

        const customConfig = GameConfig(
          monsters: {
            'weak_slime': EnemyDefinition(
              id: 'weak_slime',
              name: 'Weak Slime',
              level: 1,
              expReward: 10,
              goldReward: 25,
              lootTableId: 'slime_loot',
              detectionRange: 10,
              stats: CombatStats(maxHp: 20, atk: 1, def: 0, attackRange: 1.5),
            ),
            'deadly_guardian': EnemyDefinition(
              id: 'deadly_guardian',
              name: 'Deadly Guardian',
              level: 5,
              isBoss: true,
              detectionRange: 12,
              stats: CombatStats(
                maxHp: 5000,
                atk: 200,
                def: 20,
                attackSpeed: 2.0,
                moveSpeed: 5.0,
                attackRange: 2.0,
              ),
            ),
          },
          revive: ReviveConfig(
            delaySeconds: 3.0,
            hpPercent: 0.3,
            invulnerabilitySeconds: 2.0,
            cooldownSeconds: 90.0,
          ),
          progression: ProgressionConfig(
            maxLevel: 30,
            expBase: 10000,
            expGrowth: 1.4,
            baseStats: CombatStats(
              maxHp: 100,
              atk: 30,
              def: 0,
              attackSpeed: 2.0,
              moveSpeed: 6.0,
              attackRange: 2.0,
            ),
            perLevel: LevelGrowth(hp: 20, atk: 5, def: 2),
          ),
          items: {
            'slime_gel': ItemDefinition(
              id: 'slime_gel',
              name: 'Slime Gel',
              category: ItemCategory.material,
              maxStack: 99,
            ),
          },
          lootTables: {
            'slime_loot': LootTable(
              id: 'slime_loot',
              entries: [LootEntry(itemId: 'slime_gel', chance: 1.0)],
            ),
          },
          dungeonCompletion: DungeonCompletionReward(
            expReward: 200,
            goldReward: 999,
          ),
          dungeons: {
            'forgotten_forest': DungeonDefinition(
              id: 'forgotten_forest',
              name: 'Forgotten Forest',
              biome: 'forgotten_forest',
              startRoomId: 'room_1',
              roomOrder: ['room_1', 'room_2'],
              rooms: {
                'room_1': RoomDefinition(
                  id: 'room_1',
                  dungeonId: 'forgotten_forest',
                  name: 'Forest Entrance',
                  type: RoomType.normal,
                  mapRef: 'm1',
                  layout: twoRoomLayout,
                  entryPosition: GridPoint(1, 2),
                  exitPosition: GridPoint(9, 2),
                  spawns: [
                    RoomSpawnConfig(
                      id: 's1',
                      monsterId: 'weak_slime',
                      position: GridPoint(3, 2),
                    ),
                  ],
                  completionCondition: RoomCompletionCondition(),
                  nextRoomIds: ['room_2'],
                ),
                'room_2': RoomDefinition(
                  id: 'room_2',
                  dungeonId: 'forgotten_forest',
                  name: 'Ancient Heart',
                  type: RoomType.boss,
                  mapRef: 'm2',
                  layout: twoRoomLayout,
                  entryPosition: GridPoint(1, 2),
                  exitPosition: GridPoint(9, 2),
                  spawns: [
                    RoomSpawnConfig(
                      id: 'b1',
                      monsterId: 'deadly_guardian',
                      position: GridPoint(3, 2),
                      isBoss: true,
                    ),
                  ],
                  completionCondition: RoomCompletionCondition(
                    type: RoomCompletionConditionType.defeatBoss,
                  ),
                  nextRoomIds: [],
                ),
              },
            ),
          },
        );

        Future<void> mountApp() => _mountDungeonApp(tester, db, customConfig);

        await mountApp();
        await tester.tap(find.text('Masuk Forgotten Forest'));
        await tester.pump();
        await tester.pump();

        final game = tester
            .widget<GameWidget<EchoesGame>>(find.byType(GameWidget<EchoesGame>))
            .game!;

        var sawDowned = false;
        var sawRevived = false;
        var revivedHp = 0;

        for (var i = 0; i < 400; i++) {
          game.update(0.1);
          await tester.pump();
          final pending = game.world.pendingRoomLoad;
          if (pending != null) {
            await pending;
            await tester.pump();
          }
          final sim = game.world.simulation;
          if (sim.playerStatus == PlayerStatus.downed) {
            sawDowned = true;
          }
          if (sawDowned &&
              !sawRevived &&
              sim.playerStatus == PlayerStatus.alive) {
            sawRevived = true;
            revivedHp = sim.player.hp;
            expect(sim.reviveCooldownTicks, greaterThan(0));
            expect(revivedHp, 30); // 30% Max HP (100)
          }
          if (find.byType(RunEndedOverlay).evaluate().isNotEmpty) {
            break;
          }
        }

        expect(sawDowned, isTrue);
        expect(sawRevived, isTrue);
        expect(find.byType(RunEndedOverlay), findsOneWidget);
        expect(find.byType(DungeonCompletedOverlay), findsNothing);

        // Loot & gold dari room_1 bertahan, tidak mendapat clear reward (999 gold).
        expect(game.character.gold, 25);
        expect(game.views.inventory.quantityOf('slime_gel'), 1);

        // Kembali ke Town -> room_2 gagal tidak dihitung sebagai completed.
        await tester.tap(
          find.descendant(
            of: find.byType(RunEndedOverlay),
            matching: find.text('Kembali ke Town'),
          ),
        );
        await tester.pump();
        await tester.runAsync(_flushAsyncDb);
        await tester.pumpAndSettle();

        expect(find.byType(TownHubView), findsOneWidget);
        expect(find.text('Progres room tertinggi: 1 / 2'), findsOneWidget);
        expect(find.text('Total dungeon selesai: 0'), findsOneWidget);

        // Restart -> session failed kembali ke Town dan loot masih ada.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await mountApp();
        expect(find.byType(TownHubView), findsOneWidget);
        expect(find.textContaining('Gold 25'), findsOneWidget);
      },
    );

    testWidgets(
      '3) Application restart saat inProgress memulihkan ke awal room terakhir, mencegah reward ganda, dan menyelesaikan run dengan runId konsisten',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => tester.runAsync(db.close));
        await tester.runAsync(db.initialize);

        final config = _loadForgottenForestConfig(
          playerStats: const CombatStats(
            maxHp: 2000,
            atk: 450,
            def: 50,
            attackSpeed: 4.0,
            moveSpeed: 10,
            attackRange: 3.0,
          ),
        );

        Future<void> mountApp() => _mountDungeonApp(tester, db, config);

        await mountApp();
        await tester.tap(find.text('Masuk Forgotten Forest'));
        await tester.pump();
        await tester.pump();

        final game1 = tester
            .widget<GameWidget<EchoesGame>>(find.byType(GameWidget<EchoesGame>))
            .game!;

        // Jalankan sampai masuk ke room 2 (ancient_path) dan mulai bergerak.
        for (var i = 0; i < 150; i++) {
          game1.update(0.2);
          await tester.pump();
          final pending = game1.world.pendingRoomLoad;
          if (pending != null) {
            await pending;
            await tester.pump();
          }
          if (game1.world.mountedRoomId == 'ancient_path' &&
              game1.world.simulation.player.follower.currentCell !=
                  const GridPoint(1, 5)) {
            break;
          }
        }
        expect(game1.world.mountedRoomId, 'ancient_path');

        // Kurangi HP player dan simpan cooldown/lifecycle pause untuk menguji recovery state.
        game1.world.simulation.player.hp = 1234;
        game1.world.simulation.restoreRunState(
          hp: 1234,
          reviveCooldownTicks: 900,
        );

        // Simulasi app dipause sebelum ditutup agar save tersimpan.
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.runAsync(_flushAsyncDb);

        final savedMidRun = await tester.runAsync(
          () =>
              DriftPlayerSaveRepository(db: db, config: config).loadSnapshot(),
        );
        expect(savedMidRun, isNotNull);
        expect(
          savedMidRun!.activeDungeonSession!.status,
          DungeonSessionStatus.inProgress,
        );
        expect(savedMidRun.activeDungeonSession!.currentRoomId, 'ancient_path');
        expect(savedMidRun.activeDungeonSession!.clearedRoomIds, {
          'forest_entrance',
        });
        expect(savedMidRun.activeDungeonSession!.reviveCooldownTicks, 900);
        final originalRunId = savedMidRun.activeDungeonSession!.runId;

        // Tutup paksa UI & buka ulang aplikasi (resumed) dengan database yang sama.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await mountApp();

        // Langsung masuk ke dungeon (bukan Town) di awal room `ancient_path`!
        expect(find.byType(TownHubView), findsNothing);
        expect(find.byType(GameWidget<EchoesGame>), findsOneWidget);
        expect(find.byType(HudOverlay), findsOneWidget);
        expect(find.text('Forgotten Forest • Ancient Path'), findsOneWidget);

        final game2 = tester
            .widget<GameWidget<EchoesGame>>(find.byType(GameWidget<EchoesGame>))
            .game!;
        expect(game2.world.mountedRoomId, 'ancient_path');
        // Kembali ke entryPosition room terakhir, HP & reviveCooldownTicks dipulihkan.
        expect(
          game2.world.simulation.player.follower.currentCell,
          const GridPoint(1, 5),
        );
        expect(game2.world.simulation.player.hp, 1234);
        expect(game2.world.simulation.reviveCooldownTicks, 900);
        // Klaim reward room 1 tetap tercatat dengan runId asli.
        expect(
          savedMidRun.claimedEventIds,
          contains('room_clear:$originalRunId:forest_entrance'),
        );

        // Lanjutkan menyelesaikan sisa dungeon sampai selesai -> menerima reward clear 1x!
        for (var i = 0; i < 400; i++) {
          game2.update(0.2);
          await tester.pump();
          final pending = game2.world.pendingRoomLoad;
          if (pending != null) {
            await pending;
            await tester.pump();
          }
          if (find.byType(DungeonCompletedOverlay).evaluate().isNotEmpty) {
            break;
          }
        }
        expect(find.byType(DungeonCompletedOverlay), findsOneWidget);
        expect(find.textContaining('+120 EXP'), findsOneWidget);
        expect(find.textContaining('+50 Gold'), findsOneWidget);

        await tester.runAsync(_flushAsyncDb);
        final savedEnd = await tester.runAsync(
          () =>
              DriftPlayerSaveRepository(db: db, config: config).loadSnapshot(),
        );
        expect(savedEnd!.activeDungeonSession!.runId, originalRunId);
        expect(
          savedEnd.claimedEventIds,
          contains('dungeon_clear:$originalRunId'),
        );
      },
    );
  });
}
