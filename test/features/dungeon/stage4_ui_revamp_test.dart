import 'dart:io';

import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:echoes_of_aether/domain/services/shop_service.dart';
import 'package:echoes_of_aether/features/dungeon/dungeon_completed_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/hud_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/offline_summary_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/run_ended_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/shop_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/town_hub_view.dart';
import 'package:echoes_of_aether/features/shared/widgets/shared_widgets.dart';
import 'package:echoes_of_aether/game/hud/hud_state.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

PlayerCharacter _createCharacter(
  GameConfig config, {
  int level = 1,
  int gold = 0,
}) {
  return PlayerCharacter(
    config: config.progression,
    specializationConfig: config.specializations,
    skillCatalog: config.skills,
    progress: PlayerProgress(level: level, currentExp: 0, gold: gold),
  );
}

void main() {
  late GameConfig config;

  setUpAll(() {
    config = _loadRealConfig();
  });

  testWidgets(
    'ShopOverlay menampilkan LockedBadge saat requirement belum terpenuhi',
    (tester) async {
      final character = _createCharacter(config, level: 1, gold: 5000);
      final inventory = Inventory(definitions: config.items);
      final views = InventoryViews(inventory: inventory, character: character);
      final shopService = ShopService(
        catalog: config.shop,
        items: config.items,
        equipmentFactory: EquipmentFactory(config.equipment),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShopOverlay(
              catalog: config.shop,
              items: config.items,
              dungeons: config.dungeons,
              shopService: shopService,
              playerContext: const ShopPlayerContext(playerLevel: 1),
              playerGold: character.gold,
              views: views,
              onBuy: (id) async => ShopBuyNotFound(entryId: id),
              onSellEquipment: (id) async => ShopSellNotFound(targetId: id),
              onSellMaterialBulk: (id, _) async =>
                  ShopSellNotFound(targetId: id),
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ResourceChip), findsOneWidget);
      expect(find.text('Gold 5K'), findsOneWidget);
      // Filter Epic agar item dengan requirement Min Level / Clear Dungeon langsung terlihat.
      final epicChip = find.widgetWithText(ChoiceChip, 'Epic');
      await tester.ensureVisible(epicChip);
      await tester.pumpAndSettle();
      await tester.tap(epicChip);
      await tester.pumpAndSettle();
      expect(find.byType(LockedBadge), findsWidgets);
      expect(find.textContaining('Syarat belum terpenuhi:'), findsWidgets);
    },
  );

  testWidgets(
    'TownHubView menampilkan status dungeon (terkunci/terbuka/selesai), pengali kesulitan, rekomendasi jauh, Ascension manual-only, dan saran kalah beruntun',
    (tester) async {
      final sortedDungeons = config.dungeons.values.toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      final d1 = sortedDungeons[0];
      final d2 = sortedDungeons[1];
      final character = _createCharacter(config, level: d2.recommendedLevel);
      final inventory = Inventory(definitions: config.items);
      final views = InventoryViews(inventory: inventory, character: character);
      String? selectedTarget;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TownHubView(
              character: character,
              dungeonProgress: DungeonProgressSnapshot(
                currentDungeonId: d2.id,
                highestClearedRoomIndex: 0,
                clearsCount: 0,
              ),
              dungeonDefinition: d2,
              availableDungeons: config.dungeons,
              selectedDungeonId: d2.id,
              cycleProgress: const CycleProgress(ascensionRank: 0),
              dungeonProgresses: {
                d1.id: DungeonProgressSnapshot(
                  currentDungeonId: d1.id,
                  highestClearedRoomIndex: d1.roomOrder.length,
                  clearsCount: 1,
                  clearedInCycleRank: 0,
                ),
                d2.id: DungeonProgressSnapshot(
                  currentDungeonId: d2.id,
                  highestClearedRoomIndex: 0,
                  clearsCount: 0,
                ),
              },
              consecutiveDefeats: {d2.id: 3},
              lastFailedDungeonId: d2.id,
              items: config.items,
              views: views,
              difficultyConfig: config.difficulty,
              onEnterDungeon: () {},
              onSelectDungeon: (id) => selectedTarget = id,
              onEquip: (_) {},
              onUnequip: (_) {},
              onChooseSpecialization: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Saran turun dungeon karena kalah beruntun >= 3.
      expect(find.byKey(const Key('death_loop_suggestion')), findsOneWidget);
      expect(find.text('Saran: Pilih Dungeon Lebih Rendah'), findsOneWidget);
      await tester.tap(find.byKey(const Key('death_loop_select_lower')));
      await tester.pumpAndSettle();
      expect(selectedTarget, d1.id);

      // Status Selesai (d1), Terbuka (d2), Terkunci (dungeon selanjutnya + Ascension).
      expect(find.text('Selesai'), findsOneWidget);
      expect(find.text('Terbuka'), findsOneWidget);
      expect(find.text('Terkunci'), findsWidgets);
      expect(find.textContaining('Kesulitan 1.00x'), findsOneWidget);
      expect(
        find.text(
          'Ascension (Manual-only — tidak tersedia untuk Auto Farming).',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'HudOverlay menampilkan HP, EXP, skill cooldown, dan indikator Elite/Boss/Final Boss',
    (tester) async {
      final hudState = ValueNotifier(
        const HudState(
          level: 49,
          currentExp: 450,
          expToNext: 1000,
          gold: 12500,
          hp: 320,
          maxHp: 500,
          dungeonName: 'Ascension Sanctum',
          roomName: 'Throne of Aether',
          isElite: true,
          isFinalBoss: true,
          bossName: 'Aether Sovereign',
          bossHp: 1200,
          bossMaxHp: 2000,
          lastSkill: 'Aether Slash',
          skillCooldownText: 'CD 2.5s',
          lastLoot: 'Aether Shard',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HudOverlay(state: hudState)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ascension Sanctum • Throne of Aether'), findsOneWidget);
      expect(find.text('ELITE'), findsOneWidget);
      expect(find.text('FINAL BOSS'), findsOneWidget);
      expect(find.text('FINAL BOSS: Aether Sovereign'), findsOneWidget);
      expect(find.text('Skill: Aether Slash • CD 2.5s'), findsOneWidget);
      expect(find.text('+ Aether Shard'), findsOneWidget);
    },
  );

  testWidgets(
    'Overlay hasil (DungeonCompletedOverlay, RunEndedOverlay, OfflineSummaryOverlay) tampil konsisten dengan komponen bersama',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DungeonCompletedOverlay(
              dungeonName: 'Ascension Sanctum',
              clearedRoomsCount: 5,
              isFinalBoss: true,
              isAscension: true,
              previousAscensionRank: 0,
              newAscensionRank: 1,
              completionReward: const GrantedReward(
                eventId: 'evt_clear',
                alreadyClaimed: false,
                expGranted: 5000,
                goldGranted: 12000,
                levelsGained: 1,
              ),
              onReturnToTown: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ascension Selesai!'), findsOneWidget);
      expect(find.text('Final Boss'), findsOneWidget);
      expect(find.text('Ascension Rank 0 → Rank 1'), findsOneWidget);
      expect(find.textContaining('+5K EXP'), findsOneWidget);
      expect(find.textContaining('+12K Gold'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RunEndedOverlay(
              onRetry: () {},
              onReturnToTown: () {},
              subtitle: 'Terkalahkan di Room 4',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Run berakhir'), findsOneWidget);
      expect(find.text('Terkalahkan di Room 4'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                OfflineSummaryOverlay(
                  summary: const OfflineSummarySnapshot(
                    eventId: 'evt_stage4',
                    mode: OfflineActivityMode.autoFarming,
                    finalState: OfflineActivityState.completed,
                    effectiveElapsedMs: 3600000,
                    runsAttempted: 4,
                    runsCompleted: 4,
                    roomsCleared: 20,
                    encountersCleared: 40,
                    expGained: 1200,
                    goldGained: 800,
                  ),
                  items: const {},
                  onAcknowledge: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ringkasan Offline'), findsOneWidget);
      expect(find.text('Tutup & Simpan'), findsOneWidget);
    },
  );
}
