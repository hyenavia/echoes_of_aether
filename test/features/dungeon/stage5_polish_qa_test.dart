import 'dart:io';

import 'package:echoes_of_aether/app/theme/echoes_theme.dart';
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
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/shop_service.dart';
import 'package:echoes_of_aether/features/dungeon/hud_overlay.dart';
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

void main() {
  late GameConfig config;

  setUpAll(() {
    config = _loadRealConfig();
  });

  testWidgets(
    'TownHubView dan semua tab (Adventure, Hero, Bag, Shop) bebas overflow di layar 320dp..800dp dan skala teks 0.85x..1.5x',
    (tester) async {
      final character = PlayerCharacter(
        config: config.progression,
        specializationConfig: config.specializations,
        skillCatalog: config.skills,
        progress: const PlayerProgress(level: 15, gold: 12000),
      );
      final inventory = Inventory(definitions: config.items);
      inventory.add('slime_gel', 5);
      final views = InventoryViews(inventory: inventory, character: character);
      final shopService = ShopService(
        catalog: config.shop,
        items: config.items,
        equipmentFactory: EquipmentFactory(config.equipment),
      );

      final matrix = <({Size size, double scale})>[
        (size: const Size(320, 568), scale: 1.5),
        (size: const Size(390, 844), scale: 1.0),
        (size: const Size(800, 600), scale: 0.85),
      ];

      for (final entry in matrix) {
        await tester.binding.setSurfaceSize(entry.size);
        final loadWatch = Stopwatch()..start();
        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: MediaQuery(
              data: MediaQueryData(
                size: entry.size,
                textScaler: TextScaler.linear(entry.scale),
              ),
              child: Scaffold(
                body: TownHubView(
                  character: character,
                  views: views,
                  items: config.items,
                  dungeonProgress: const DungeonProgressSnapshot(
                    currentDungeonId: 'forgotten_forest',
                    highestClearedRoomIndex: 2,
                    clearsCount: 1,
                  ),
                  dungeonDefinition: config.dungeons['forgotten_forest'],
                  availableDungeons: config.dungeons,
                  cycleProgress: const CycleProgress(ascensionRank: 1),
                  difficultyConfig: config.difficulty,
                  shopCatalog: config.shop,
                  shopService: shopService,
                  shopContext: ShopPlayerContext(playerLevel: character.level),
                  onShopBuy: (id) async => ShopBuyNotFound(entryId: id),
                  onShopSellEquipment: (id) async =>
                      ShopSellNotFound(targetId: id),
                  onShopSellMaterialBulk: (id, _) async =>
                      ShopSellNotFound(targetId: id),
                  onEnterDungeon: () {},
                  onEquip: (_) {},
                  onUnequip: (_) {},
                  onChooseSpecialization: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        loadWatch.stop();

        expect(tester.takeException(), isNull);
        expect(loadWatch.elapsedMilliseconds, lessThan(5000));

        for (final tabLabel in const ['Hero', 'Bag', 'Shop', 'Adventure']) {
          await tester.tap(find.text(tabLabel));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      }
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'Aksesibilitas dasar: PrimaryButton & SecondaryButton memenuhi minHeight 44dp dan memiliki Semantics',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: EchoesTheme.dark(),
          home: Scaffold(
            body: Column(
              children: [
                PrimaryButton(label: 'Mulai Ekspedisi', onPressed: () {}),
                SecondaryButton(label: 'Kembali ke Town', onPressed: () {}),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final primaryBox = tester.getSize(find.byType(PrimaryButton));
      final secondaryBox = tester.getSize(find.byType(SecondaryButton));
      expect(primaryBox.height, greaterThanOrEqualTo(44));
      expect(secondaryBox.height, greaterThanOrEqualTo(44));

      expect(find.bySemanticsLabel('Mulai Ekspedisi'), findsWidgets);
      expect(find.bySemanticsLabel('Kembali ke Town'), findsWidgets);
    },
  );

  testWidgets(
    'Performa HudOverlay pada 60 pembaruan beruntun dengan 25 musuh tetap di bawah anggaran frame 16ms rata-rata',
    (tester) async {
      final hud = ValueNotifier(
        const HudState(
          level: 25,
          currentExp: 100,
          expToNext: 500,
          gold: 50000,
          hp: 400,
          maxHp: 500,
          dungeonName: 'Forgotten Forest',
          roomName: 'Ancient Heart',
          activeEnemies: 25,
          totalEnemies: 25,
          isFinalBoss: true,
          bossName: 'Ancient Heart Guardian',
          bossHp: 1000,
          bossMaxHp: 1500,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: EchoesTheme.dark(),
          home: Scaffold(body: HudOverlay(state: hud)),
        ),
      );
      await tester.pump();

      final watch = Stopwatch()..start();
      for (var i = 1; i <= 60; i++) {
        hud.value = HudState(
          level: 25,
          currentExp: 100 + i,
          expToNext: 500,
          gold: 50000 + i * 10,
          hp: 400 - (i % 50),
          maxHp: 500,
          dungeonName: 'Forgotten Forest',
          roomName: 'Ancient Heart',
          activeEnemies: 25 - (i % 10),
          totalEnemies: 25,
          isFinalBoss: true,
          bossName: 'Ancient Heart Guardian',
          bossHp: 1000 - i * 10,
          bossMaxHp: 1500,
        );
        await tester.pump();
      }
      watch.stop();

      final avgMs = watch.elapsedMilliseconds / 60.0;
      expect(tester.takeException(), isNull);
      expect(avgMs, lessThan(16.6));
    },
  );
}
