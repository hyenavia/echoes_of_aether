import 'dart:io';

import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/providers/cloud_sync_provider.dart';
import 'package:echoes_of_aether/application/providers/database_provider.dart';
import 'package:echoes_of_aether/application/providers/game_config_provider.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
import 'package:echoes_of_aether/data/cloud/firebase_bootstrap.dart';
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
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:echoes_of_aether/features/dungeon/dungeon_screen.dart';
import 'package:echoes_of_aether/features/dungeon/town_hub_view.dart';
import 'package:echoes_of_aether/features/shared/widgets/echoes_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

Future<void> _flushAsyncDb() async {
  await Future<void>.delayed(const Duration(milliseconds: 60));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GameConfig config;

  setUpAll(() {
    config = _loadRealGameConfig();
  });

  group('Exit Confirmation Modal Box Tests', () {
    testWidgets(
      'Menekan tombol Back menampilkan EchoesDialog konfirmasi keluar; Lanjut Main membatalkan',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => tester.runAsync(db.close));
        await tester.runAsync(db.initialize);

        final repo = DriftPlayerSaveRepository(db: db, config: config);
        final nowMs = DateTime.now().millisecondsSinceEpoch;

        await tester.runAsync(() async {
          final char = PlayerCharacter(
            config: config.progression,
            progress: const PlayerProgress(level: 1, currentExp: 0, gold: 500),
          );
          final inv = Inventory(definitions: config.items);
          final setupCoord = GameSessionCoordinator(
            repository: repo,
            config: config,
            nowMs: () => nowMs,
          );
          await setupCoord.saveFromRuntime(
            character: char,
            inventory: inv,
            dungeon: const DungeonProgressSnapshot(
              currentDungeonId: 'forgotten_forest',
              clearsCount: 1,
              clearedInCycleRank: 0,
              highestClearedRoomIndex: 4,
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
        });

        final failedBootstrap = FirebaseBootstrap(
          initializeFirebase: () async =>
              throw StateError('No Play Services on test device'),
        );
        await failedBootstrap.initialize();

        var exitCalled = false;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              gameConfigProvider.overrideWith((ref) async => config),
              playerSaveRepositoryProvider.overrideWith((ref) async => repo),
              firebaseBootstrapProvider.overrideWithValue(failedBootstrap),
            ],
            child: MaterialApp(
              home: DungeonScreen(
                roomTransitionDelaySeconds: 0.1,
                onExitConfirmed: () => exitCalled = true,
              ),
            ),
          ),
        );

        // Tunggu hingga TownHubView muncul.
        for (var i = 0; i < 30; i++) {
          await tester.pump();
          await tester.runAsync(_flushAsyncDb);
          await tester.pump();
          if (find.byType(TownHubView).evaluate().isNotEmpty) {
            break;
          }
        }
        expect(find.byType(TownHubView), findsOneWidget);

        // Simulasikan tombol fisik Back / Back gesture.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        // Dialog konfirmasi harus muncul.
        expect(find.byType(EchoesDialog), findsOneWidget);
        expect(find.text('Keluar Permainan?'), findsOneWidget);
        expect(
          find.text(
            'Progres permainan Anda akan disimpan otomatis ke database sebelum keluar.',
          ),
          findsOneWidget,
        );
        expect(find.text('Lanjut Main'), findsOneWidget);
        expect(find.text('Simpan & Keluar'), findsOneWidget);

        // Tekan 'Lanjut Main' -> dialog tertutup, exit tidak dipanggil.
        await tester.tap(find.text('Lanjut Main'));
        await tester.pumpAndSettle();

        expect(find.byType(EchoesDialog), findsNothing);
        expect(exitCalled, isFalse);
      },
    );

    testWidgets(
      'Tekan Simpan & Keluar menyimpan data ke database dan memanggil exit callback',
      (tester) async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => tester.runAsync(db.close));
        await tester.runAsync(db.initialize);

        final repo = DriftPlayerSaveRepository(db: db, config: config);
        final nowMs = DateTime.now().millisecondsSinceEpoch;

        await tester.runAsync(() async {
          final char = PlayerCharacter(
            config: config.progression,
            progress: const PlayerProgress(
              level: 5,
              currentExp: 100,
              gold: 999,
            ),
          );
          final inv = Inventory(definitions: config.items);
          final setupCoord = GameSessionCoordinator(
            repository: repo,
            config: config,
            nowMs: () => nowMs,
          );
          await setupCoord.saveFromRuntime(
            character: char,
            inventory: inv,
            dungeon: const DungeonProgressSnapshot(
              currentDungeonId: 'forgotten_forest',
              clearsCount: 1,
              clearedInCycleRank: 0,
              highestClearedRoomIndex: 4,
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
        });

        final failedBootstrap = FirebaseBootstrap(
          initializeFirebase: () async =>
              throw StateError('No Play Services on test device'),
        );
        await failedBootstrap.initialize();

        var exitCalled = false;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              gameConfigProvider.overrideWith((ref) async => config),
              playerSaveRepositoryProvider.overrideWith((ref) async => repo),
              firebaseBootstrapProvider.overrideWithValue(failedBootstrap),
            ],
            child: MaterialApp(
              home: DungeonScreen(
                roomTransitionDelaySeconds: 0.1,
                onExitConfirmed: () => exitCalled = true,
              ),
            ),
          ),
        );

        for (var i = 0; i < 30; i++) {
          await tester.pump();
          await tester.runAsync(_flushAsyncDb);
          await tester.pump();
          if (find.byType(TownHubView).evaluate().isNotEmpty) {
            break;
          }
        }
        expect(find.byType(TownHubView), findsOneWidget);

        // Simulasikan tombol Back.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(find.text('Keluar Permainan?'), findsOneWidget);

        // Tekan 'Simpan & Keluar'.
        await tester.tap(find.text('Simpan & Keluar'));
        await tester.pump();

        for (var i = 0; i < 30 && !exitCalled; i++) {
          await tester.pump(const Duration(milliseconds: 50));
          await tester.runAsync(_flushAsyncDb);
        }
        await tester.pumpAndSettle();

        expect(exitCalled, isTrue);

        // Verifikasi bahwa database memiliki data yang valid & persisten.
        final snapshot = (await tester.runAsync(repo.loadSnapshot))!;
        expect(snapshot.character.progress.level, 5);
        expect(snapshot.character.progress.gold, 999);
      },
    );
  });
}
