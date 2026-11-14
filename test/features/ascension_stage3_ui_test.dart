import 'dart:io';

import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/providers/database_provider.dart';
import 'package:echoes_of_aether/application/providers/game_config_provider.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
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
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
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

GameConfig _loadStage3Config({
  CombatStats? baseStatsOverride,
  ReviveConfig? reviveOverride,
}) {
  const parser = GameConfigParser();
  final settings = _readAsset('game_config.json');
  final difficulty = parser.parseDifficulty(settings);
  final baseProg = parser.parseProgression(settings);
  final progression = baseStatsOverride == null
      ? baseProg
      : ProgressionConfig(
          maxLevel: baseProg.maxLevel,
          expCurve: baseProg.expCurve,
          baseStats: baseStatsOverride,
          perLevel: baseStatsOverride.maxHp <= 1
              ? const LevelGrowth(hp: 0, atk: 0, def: 0)
              : baseProg.perLevel,
        );
  final config = GameConfig(
    monsters: const MonsterConfigParser().parse(_readAsset('monsters.json')),
    damage: parser.parseDamage(settings),
    difficulty: difficulty,
    farming: parser.parseFarming(settings),
    revive: reviveOverride ?? parser.parseRevive(settings),
    progression: progression,
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

Future<void> _flushDb() =>
    Future<void>.delayed(const Duration(milliseconds: 25));

Future<void> _mountDungeonApp(
  WidgetTester tester,
  AppDatabase db,
  GameConfig config, {
  Key? screenKey,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: screenKey != null ? ValueKey('scope_$screenKey') : UniqueKey(),
      overrides: [
        gameConfigProvider.overrideWith((ref) async => config),
        playerSaveRepositoryProvider.overrideWith(
          (ref) async => DriftPlayerSaveRepository(db: db, config: config),
        ),
      ],
      child: MaterialApp(
        home: DungeonScreen(key: screenKey, roomTransitionDelaySeconds: 0.05),
      ),
    ),
  );
  for (var i = 0; i < 20; i++) {
    await tester.pump();
    await tester.runAsync(_flushDb);
    await tester.pump();
    if (find.byType(TownHubView).evaluate().isNotEmpty ||
        find.byType(HudOverlay).evaluate().isNotEmpty) {
      break;
    }
  }
  await tester.pump();
}

Future<void> _seedCycleWithAllNormalsCleared(
  AppDatabase db,
  GameConfig config, {
  required int level,
  required int gold,
  String lastNormalDungeonId = 'aether_sanctum',
  int rank = 0,
}) async {
  final repo = DriftPlayerSaveRepository(db: db, config: config);
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final char = PlayerCharacter(
    config: config.progression,
    progress: PlayerProgress(level: level, gold: gold),
    skillCatalog: config.skills,
    specializationConfig: config.specializations,
    initialSpecializationId: level >= config.specializations.unlockLevel
        ? 'vanguard'
        : null,
  );
  final inv = Inventory(definitions: config.items);
  inv.add('small_potion', 2);
  final coord = GameSessionCoordinator(
    repository: repo,
    config: config,
    nowMs: () => nowMs,
  );
  final progresses = <String, DungeonProgressSnapshot>{
    for (final d in config.dungeons.values.where((d) => d.isNormal))
      d.id: DungeonProgressSnapshot(
        currentDungeonId: d.id,
        clearsCount: 1,
        clearedInCycleRank: rank,
        highestClearedRoomIndex: 4,
      ),
  };
  await coord.saveFromRuntime(
    character: char,
    inventory: inv,
    dungeon: progresses[lastNormalDungeonId]!,
    dungeonProgresses: progresses,
    cycleProgress: CycleProgress(
      ascensionRank: rank,
      lastNormalDungeonId: lastNormalDungeonId,
    ),
    rewardProcessor: RewardProcessor(
      character: char,
      inventory: inv,
      items: config.items,
      lootTables: config.lootTables,
      equipmentFactory: EquipmentFactory(config.equipment),
    ),
    autoSkillEnabled: true,
    lastOfflineClaimAtMs: nowMs,
  );
}

Future<void> _runGameUntilOverlay<T extends Widget>(
  WidgetTester tester, {
  int maxSteps = 500,
}) async {
  final game = tester
      .widget<GameWidget<EchoesGame>>(find.byType(GameWidget<EchoesGame>))
      .game!;
  for (var i = 0; i < maxSteps; i++) {
    game.update(0.1);
    await tester.pump();
    final pending = game.world.pendingRoomLoad;
    if (pending != null) {
      await pending;
      await tester.pump();
    }
    if (find.byType(T).evaluate().isNotEmpty) {
      await tester.pump();
      return;
    }
  }
  await tester.pump();
  if (find.byType(T).evaluate().isEmpty) {
    final world = game.world;
    final sim = world.simulation;
    final manager = world.dungeonManager;
    fail(
      'Overlay $T tidak muncul setelah $maxSteps langkah '
      '(dungeon=${manager?.activeDungeon?.id}, '
      'room=${manager?.activeRoom?.id}, '
      'session=${manager?.session?.status}/${manager?.session?.roomLifecycle}, '
      'paused=${game.paused}, '
      'playerStatus=${sim.playerStatus}, '
      'hp=${sim.player.hp}/${sim.player.stats.maxHp}, '
      'pos=(${sim.player.x.toStringAsFixed(1)}, ${sim.player.y.toStringAsFixed(1)}), '
      'enemies=${sim.aliveEnemies.length}/${sim.enemies.length}, '
      'encounters=${manager?.encounterTracker?.encounters.map((e) => '${e.spawnConfigId}:${e.status.name}:${e.lastError}').toList()}, '
      'overlays=${game.overlays.activeOverlays}).',
    );
  }
}

void main() {
  group('M9 Stage 3 — UI Ascension, Respawn & Death Loop', () {
    testWidgets(
      'penyelesaian Ascension di DungeonScreen menaikkan rank 1x, menampilkan rank baru di overlay, mereset ke Dungeon 1, dan restart tepat di overlay tidak menaikkan rank dua kali',
      (tester) async {
        final strongConfig = _loadStage3Config(
          baseStatsOverride: const CombatStats(
            maxHp: 50000,
            atk: 25000,
            def: 10000,
            attackSpeed: 5.0,
            moveSpeed: 10.0,
            attackRange: 6.0,
          ),
        );
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => tester.runAsync(db.close));
        await tester.runAsync(db.initialize);
        await tester.runAsync(
          () => _seedCycleWithAllNormalsCleared(
            db,
            strongConfig,
            level: 50,
            gold: 250,
            lastNormalDungeonId: 'aether_sanctum',
            rank: 0,
          ),
        );

        await _mountDungeonApp(
          tester,
          db,
          strongConfig,
          screenKey: const ValueKey('asc_complete_1'),
        );
        expect(find.byType(TownHubView), findsOneWidget);
        expect(find.textContaining('Siklus Rank 0'), findsAtLeastNWidgets(1));

        await tester.ensureVisible(
          find.byKey(const Key('dungeon_enter_ascension_sanctum')),
        );
        await tester.tap(
          find.byKey(const Key('dungeon_enter_ascension_sanctum')),
        );
        await tester.pump();
        await tester.pump();
        expect(find.byType(GameWidget<EchoesGame>), findsOneWidget);

        await _runGameUntilOverlay<DungeonCompletedOverlay>(tester);
        // Tangkap jumlah small_potion setelah clear (termasuk drop loot selama run).
        final repoBeforeRestart = DriftPlayerSaveRepository(
          db: db,
          config: strongConfig,
        );
        final overlayFinder = find.byType(DungeonCompletedOverlay);
        expect(overlayFinder, findsOneWidget);
        expect(
          find.descendant(
            of: overlayFinder,
            matching: find.text('Ascension Selesai!'),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const Key('ascension_rank_result')), findsOneWidget);
        expect(find.text('Ascension Rank 0 → Rank 1'), findsOneWidget);
        expect(
          find.descendant(of: overlayFinder, matching: find.text('Run baru')),
          findsNothing,
        );
        expect(
          find.descendant(
            of: overlayFinder,
            matching: find.text('Kembali ke Town'),
          ),
          findsOneWidget,
        );

        await tester.runAsync(_flushDb);
        final beforeRestart = await tester.runAsync(
          repoBeforeRestart.loadSnapshot,
        );
        final potionsBeforeRestart =
            beforeRestart!.inventory.stacks['small_potion'] ?? 0;
        expect(potionsBeforeRestart, greaterThanOrEqualTo(2));

        // Tutup lalu buka ulang aplikasi TEPAT saat DungeonCompletedOverlay masih terbuka.
        await _mountDungeonApp(
          tester,
          db,
          strongConfig,
          screenKey: const ValueKey('asc_reopened_at_overlay'),
        );
        expect(find.byType(TownHubView), findsOneWidget);
        expect(find.textContaining('Siklus Rank 1'), findsAtLeastNWidgets(1));
        expect(find.textContaining('Siklus Rank 2'), findsNothing);
        // Farm Dungeon / target terpilih direset ke Dungeon 1 (Forgotten Forest).
        expect(find.text('Masuk Forgotten Forest'), findsOneWidget);
        expect(
          find.byKey(const Key('dungeon_enter_crystal_cavern')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('dungeon_enter_ascension_sanctum')),
          findsNothing,
        );

        // Verifikasi juga tombol 'Kembali ke Town' dari overlay pada transisi normal kembali ke Dungeon 1.
        final repo = DriftPlayerSaveRepository(db: db, config: strongConfig);
        final saved = await tester.runAsync(repo.loadSnapshot);
        expect(saved, isNotNull);
        expect(saved!.cycleProgress.ascensionRank, 1);
        expect(saved.cycleProgress.lastNormalDungeonId, 'forgotten_forest');
        expect(saved.character.specializationId, 'vanguard');
        expect(saved.inventory.stacks['small_potion'], potionsBeforeRestart);
        expect(saved.dungeonProgresses['forgotten_forest']?.clearsCount, 1);
        expect(
          saved.dungeonProgresses['forgotten_forest']?.clearedInCycleRank,
          -1,
        );
        expect(saved.character.progress.gold, greaterThan(250));
      },
    );

    testWidgets(
      'kalah di Ascension kembali ke dungeon normal terakhir tanpa mengubah rank; kalah di dungeon normal kembali ke dungeon itu',
      (tester) async {
        final weakConfig = _loadStage3Config(
          baseStatsOverride: const CombatStats(
            maxHp: 1,
            atk: 1,
            def: 0,
            attackSpeed: 0.5,
            moveSpeed: 3.0,
            attackRange: 1.0,
          ),
          reviveOverride: const ReviveConfig(
            delaySeconds: 0.05,
            hpPercent: 0.3,
            invulnerabilitySeconds: 0.05,
            cooldownSeconds: 90.0,
          ),
        );
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => tester.runAsync(db.close));
        await tester.runAsync(db.initialize);
        await tester.runAsync(
          () => _seedCycleWithAllNormalsCleared(
            db,
            weakConfig,
            level: 49,
            gold: 150,
            lastNormalDungeonId: 'ancient_crypt',
            rank: 0,
          ),
        );

        await _mountDungeonApp(
          tester,
          db,
          weakConfig,
          screenKey: const ValueKey('defeat_flow_screen'),
        );
        expect(find.text('Masuk Ancient Crypt'), findsOneWidget);

        // 1) Kalah di Ascension Dungeon.
        await tester.ensureVisible(
          find.byKey(const Key('dungeon_enter_ascension_sanctum')),
        );
        await tester.tap(
          find.byKey(const Key('dungeon_enter_ascension_sanctum')),
        );
        await tester.pump();
        await tester.pump();

        await _runGameUntilOverlay<RunEndedOverlay>(tester);
        expect(find.byType(RunEndedOverlay), findsOneWidget);
        expect(
          find.textContaining('Ascension Rank tidak berubah'),
          findsOneWidget,
        );
        await tester.runAsync(_flushDb);

        // Kembali ke Town -> harus memilih Ancient Crypt (lastNormalDungeonId), Rank tetap 0.
        await tester.tap(
          find.descendant(
            of: find.byType(RunEndedOverlay),
            matching: find.text('Kembali ke Town'),
          ),
        );
        await tester.pump();
        await tester.runAsync(_flushDb);
        await tester.pumpAndSettle();

        expect(find.byType(TownHubView), findsOneWidget);
        expect(find.text('Masuk Ancient Crypt'), findsOneWidget);
        expect(find.textContaining('Siklus Rank 0'), findsAtLeastNWidgets(1));

        // 2) Kalah di Normal Dungeon (Ancient Crypt) -> kembali ke Ancient Crypt.
        await tester.ensureVisible(find.text('Masuk Ancient Crypt'));
        await tester.tap(find.text('Masuk Ancient Crypt'));
        await tester.pump();
        await tester.pump();

        await _runGameUntilOverlay<RunEndedOverlay>(tester);
        expect(find.byType(RunEndedOverlay), findsOneWidget);

        await tester.tap(
          find.descendant(
            of: find.byType(RunEndedOverlay),
            matching: find.text('Kembali ke Town'),
          ),
        );
        await tester.pump();
        await tester.runAsync(_flushDb);
        await tester.pumpAndSettle();

        expect(find.byType(TownHubView), findsOneWidget);
        expect(find.text('Masuk Ancient Crypt'), findsOneWidget);

        final repo = DriftPlayerSaveRepository(db: db, config: weakConfig);
        final saved = await tester.runAsync(repo.loadSnapshot);
        expect(saved!.cycleProgress.ascensionRank, 0);
        expect(saved.cycleProgress.lastNormalDungeonId, 'ancient_crypt');
        expect(saved.session.consecutiveDefeats['ascension_sanctum'], 1);
        expect(saved.session.consecutiveDefeats['ancient_crypt'], 1);
      },
    );

    testWidgets(
      'penghitung kekalahan beruntun menampilkan saran turun dungeon setelah ambang 3 di Town dan reset setelah menang',
      (tester) async {
        final weakConfig = _loadStage3Config(
          baseStatsOverride: const CombatStats(
            maxHp: 1,
            atk: 1,
            def: 0,
            attackSpeed: 0.5,
            moveSpeed: 3.0,
            attackRange: 1.0,
          ),
          reviveOverride: const ReviveConfig(
            delaySeconds: 0.05,
            hpPercent: 0.3,
            invulnerabilitySeconds: 0.05,
            cooldownSeconds: 90.0,
          ),
        );
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => tester.runAsync(db.close));
        await tester.runAsync(db.initialize);
        await tester.runAsync(
          () => _seedCycleWithAllNormalsCleared(
            db,
            weakConfig,
            level: 16,
            gold: 100,
            lastNormalDungeonId: 'ancient_crypt',
            rank: 0,
          ),
        );

        await _mountDungeonApp(
          tester,
          db,
          weakConfig,
          screenKey: const ValueKey('death_loop_weak'),
        );

        // Kalah 2x -> belum ada saran.
        for (var attempt = 1; attempt <= 2; attempt++) {
          await tester.ensureVisible(find.text('Masuk Ancient Crypt'));
          await tester.tap(find.text('Masuk Ancient Crypt'));
          await tester.pump();
          await tester.pump();
          await _runGameUntilOverlay<RunEndedOverlay>(tester);
          await tester.tap(
            find.descendant(
              of: find.byType(RunEndedOverlay),
              matching: find.text('Kembali ke Town'),
            ),
          );
          await tester.pump();
          await tester.runAsync(_flushDb);
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('death_loop_suggestion')), findsNothing);
        }

        // Kalah ke-3 -> saran turun dungeon ke Crystal Cavern muncul.
        await tester.ensureVisible(find.text('Masuk Ancient Crypt'));
        await tester.tap(find.text('Masuk Ancient Crypt'));
        await tester.pump();
        await tester.pump();
        await _runGameUntilOverlay<RunEndedOverlay>(tester);
        await tester.tap(
          find.descendant(
            of: find.byType(RunEndedOverlay),
            matching: find.text('Kembali ke Town'),
          ),
        );
        await tester.pump();
        await tester.runAsync(_flushDb);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('death_loop_suggestion')), findsOneWidget);
        expect(find.textContaining('3 kali beruntun'), findsOneWidget);
        expect(find.text('Pilih Crystal Cavern'), findsOneWidget);

        // Klik tombol saran memilih Crystal Cavern.
        await tester.tap(find.byKey(const Key('death_loop_select_lower')));
        await tester.pump();
        await tester.runAsync(_flushDb);
        expect(find.text('Masuk Crystal Cavern'), findsOneWidget);

        // Buka ulang app dengan hero kuat & menang di Ancient Crypt -> hitungan direset ke 0.
        final strongConfig = _loadStage3Config(
          baseStatsOverride: const CombatStats(
            maxHp: 50000,
            atk: 25000,
            def: 10000,
            attackSpeed: 5.0,
            moveSpeed: 10.0,
            attackRange: 6.0,
          ),
        );
        await _mountDungeonApp(
          tester,
          db,
          strongConfig,
          screenKey: const ValueKey('death_loop_win'),
        );
        // Pilih kembali Ancient Crypt untuk membuktikan kemenangan mereset hitungan kekalahannya.
        await tester.ensureVisible(
          find.byKey(const Key('dungeon_select_ancient_crypt')),
        );
        await tester.tap(find.byKey(const Key('dungeon_select_ancient_crypt')));
        await tester.pump();
        expect(find.byKey(const Key('death_loop_suggestion')), findsOneWidget);

        await tester.ensureVisible(find.text('Masuk Ancient Crypt'));
        await tester.tap(find.text('Masuk Ancient Crypt'));
        await tester.pump();
        await tester.pump();
        await _runGameUntilOverlay<DungeonCompletedOverlay>(tester);

        await tester.tap(
          find.descendant(
            of: find.byType(DungeonCompletedOverlay),
            matching: find.text('Kembali ke Town'),
          ),
        );
        await tester.pump();
        await tester.runAsync(_flushDb);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('death_loop_suggestion')), findsNothing);
        final repo = DriftPlayerSaveRepository(db: db, config: strongConfig);
        final afterWinSnap = await tester.runAsync(repo.loadSnapshot);
        expect(
          afterWinSnap!.session.consecutiveDefeats.containsKey('ancient_crypt'),
          false,
        );
      },
    );
  });
}
