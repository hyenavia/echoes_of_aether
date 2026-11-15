import 'dart:io';

import 'package:echoes_of_aether/app/theme/echoes_theme.dart';
import 'package:echoes_of_aether/application/providers/database_provider.dart';
import 'package:echoes_of_aether/application/providers/game_config_provider.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/repositories/player_progress_repository.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:echoes_of_aether/features/dungeon/dungeon_completed_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/dungeon_screen.dart';
import 'package:echoes_of_aether/features/dungeon/hud_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/inventory_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/run_ended_overlay.dart';
import 'package:echoes_of_aether/game/hud/hud_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySaveRepository implements PlayerSaveRepository {
  PlayerSaveSnapshot? stored;

  @override
  Future<PlayerSaveSnapshot?> loadSnapshot() async => stored;

  @override
  Future<void> saveSnapshot(PlayerSaveSnapshot snapshot) async {
    stored = snapshot;
  }
}

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealConfig() {
  const parser = GameConfigParser();
  final settings = _readAsset('game_config.json');
  final difficulty = parser.parseDifficulty(settings);
  return GameConfig(
    monsters: const MonsterConfigParser().parse(_readAsset('monsters.json')),
    damage: parser.parseDamage(settings),
    difficulty: difficulty,
    farming: parser.parseFarming(settings),
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
    dungeons: const DungeonConfigParser().parse(
      _readAsset('dungeons.json'),
      ascensionMultiplier: difficulty.ascensionMultiplier,
    ),
    shop: const ShopConfigParser().parse(_readAsset('shop.json')),
  );
}

void main() {
  testWidgets(
    'Stage 3: HudOverlay menampilkan Hero Panel, Boss Encounter Plate, dan Combat Feed tanpa overflow di phone/tablet',
    (tester) async {
      final hud = ValueNotifier<HudState>(
        const HudState(
          level: 28,
          currentExp: 640,
          expToNext: 1000,
          gold: 18450,
          hp: 410,
          maxHp: 560,
          dungeonName: 'Forgotten Forest',
          roomName: 'Ancient Heart',
          roomStatus: 'Pertempuran Boss berlangsung',
          exitRequired: true,
          exitUnlocked: false,
          activeEnemies: 1,
          totalEnemies: 1,
          isElite: true,
          isFinalBoss: true,
          bossName: 'Ancient Heart Guardian',
          bossHp: 1450,
          bossMaxHp: 2400,
          lastSkill: 'Arcane Surge',
          skillCooldownText: 'CD 1.8s',
          lastLoot: 'Forest Essence x2',
          transitionMessage: 'Memasuki Ancient Heart...',
        ),
      );

      final profiles = <({Size size, double scale})>[
        (size: const Size(320, 568), scale: 1.5),
        (size: const Size(390, 844), scale: 1.0),
        (size: const Size(960, 720), scale: 1.0),
      ];
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      for (final profile in profiles) {
        tester.view.physicalSize = profile.size;
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = profile.scale;

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(body: HudOverlay(state: hud)),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey<String>('hud_hero_panel')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('hud_boss_panel')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('hud_combat_feed')),
          findsOneWidget,
        );
        expect(find.text('Forgotten Forest • Ancient Heart'), findsOneWidget);
        expect(find.text('FINAL BOSS: Ancient Heart Guardian'), findsOneWidget);
        expect(find.text('Skill: Arcane Surge • CD 1.8s'), findsOneWidget);
        expect(find.text('+ Forest Essence x2'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      // Saat boss tidak ada, hud_boss_panel tersembunyi rapi
      hud.value = const HudState(
        level: 28,
        currentExp: 700,
        expToNext: 1000,
        gold: 18600,
        hp: 560,
        maxHp: 560,
        dungeonName: 'Forgotten Forest',
        roomName: 'Forest Entrance',
        activeEnemies: 0,
        totalEnemies: 3,
        exitRequired: true,
        exitUnlocked: true,
        roomStatus: 'Menuju Exit',
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('hud_boss_panel')),
        findsNothing,
      );
      expect(find.text('Exit: Terbuka'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Stage 3: DungeonCompletedOverlay dan RunEndedOverlay tampil rapi di 320dp..960dp serta menjaga aksi tombol',
    (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      var retried = false;
      var returned = false;

      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;

      // 1. Normal Dungeon Completion with Retry + Return
      await tester.pumpWidget(
        MaterialApp(
          theme: EchoesTheme.dark(),
          home: Scaffold(
            body: DungeonCompletedOverlay(
              dungeonName: 'Forgotten Forest',
              clearedRoomsCount: 5,
              completionReward: const GrantedReward(
                eventId: 'evt_stage3_normal',
                alreadyClaimed: false,
                expGranted: 1200,
                goldGranted: 640,
                levelsGained: 1,
                displayParts: ['Aether Shard', 'Oak Charm'],
              ),
              onRetry: () => retried = true,
              onReturnToTown: () => returned = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Dungeon Selesai!'), findsOneWidget);
      expect(find.text('HADIAH PENYELESAIAN'), findsOneWidget);
      expect(
        find.textContaining('+1.2K EXP • +640 Gold • Naik 1 Level!'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Run baru'));
      await tester.tap(find.text('Run baru'));
      await tester.pump();
      expect(retried, isTrue);

      await tester.ensureVisible(find.text('Kembali ke Town'));
      await tester.tap(find.text('Kembali ke Town'));
      await tester.pump();
      expect(returned, isTrue);

      // 2. Ascension Final Boss Completion on Tablet
      tester.view.physicalSize = const Size(960, 720);
      tester.platformDispatcher.textScaleFactorTestValue = 1.0;
      await tester.pumpWidget(
        MaterialApp(
          theme: EchoesTheme.dark(),
          home: Scaffold(
            body: DungeonCompletedOverlay(
              dungeonName: 'Ascension: Aether Sanctum',
              clearedRoomsCount: 5,
              isFinalBoss: true,
              isAscension: true,
              previousAscensionRank: 1,
              newAscensionRank: 2,
              onReturnToTown: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Ascension Selesai!'), findsOneWidget);
      expect(find.text('Final Boss'), findsOneWidget);
      expect(find.text('Ascension Rank 1 → Rank 2'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 3. RunEndedOverlay on narrow 320dp @ 1.5x
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      var runRetried = false;
      var runReturned = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: EchoesTheme.dark(),
          home: Scaffold(
            body: RunEndedOverlay(
              subtitle: 'Terkalahkan di Hidden Chamber',
              onRetry: () => runRetried = true,
              onReturnToTown: () => runReturned = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Run berakhir'), findsOneWidget);
      expect(
        find.text('Kamu kalah saat revive masih cooldown.'),
        findsOneWidget,
      );
      expect(find.text('Terkalahkan di Hidden Chamber'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Kembali ke Town'));
      await tester.tap(find.text('Kembali ke Town'));
      await tester.pump();
      expect(runReturned, isTrue);

      await tester.ensureVisible(find.text('Run baru'));
      await tester.tap(find.text('Run baru'));
      await tester.pump();
      expect(runRetried, isTrue);
    },
  );

  testWidgets(
    'Stage 3: Action deck dan Menu Dungeon di DungeonScreen berfungsi menjaga alur combat -> overlay -> Town',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final config = _loadRealConfig();
      final repo = _MemorySaveRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameConfigProvider.overrideWith((ref) async => config),
            playerSaveRepositoryProvider.overrideWith((ref) async => repo),
          ],
          child: MaterialApp(
            theme: EchoesTheme.dark(),
            home: const DungeonScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Masuk Forgotten Forest'));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('hud_auto_skill_button')), findsOneWidget);
      expect(find.byKey(const Key('hud_offline_button')), findsOneWidget);
      expect(find.byKey(const Key('hud_menu_toggle_button')), findsOneWidget);

      // Toggle Auto Skill
      expect(find.text('Auto Skill: ON'), findsOneWidget);
      await tester.tap(find.byKey(const Key('hud_auto_skill_button')));
      await tester.pump();
      expect(find.text('Auto Skill: OFF'), findsOneWidget);

      // Buka Menu Drawer dan buka Tas (InventoryOverlay)
      await tester.tap(find.byKey(const Key('hud_menu_toggle_button')));
      await tester.pump();
      expect(find.byKey(const Key('hud_menu_drawer')), findsOneWidget);
      expect(find.text('Menu Dungeon'), findsOneWidget);
      expect(find.text('Tas'), findsOneWidget);
      expect(find.text('Perlengkapan'), findsOneWidget);
      expect(find.text('Karakter'), findsOneWidget);
      expect(find.text('Pengaturan'), findsOneWidget);
      expect(find.text('Kembali ke Town'), findsOneWidget);

      await tester.tap(find.text('Tas'));
      await tester.pump();
      expect(find.byType(InventoryOverlay), findsOneWidget);

      // Tutup InventoryOverlay, buka Menu lagi, dan kembali ke Town
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(find.byType(InventoryOverlay), findsNothing);

      await tester.tap(find.byKey(const Key('hud_menu_toggle_button')));
      await tester.pump();
      await tester.tap(find.text('Kembali ke Town'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Town / Camp'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
