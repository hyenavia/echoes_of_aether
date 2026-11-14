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
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/game_settings.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/equipment_service.dart';
import 'package:echoes_of_aether/domain/services/shop_service.dart';
import 'package:echoes_of_aether/features/dungeon/town_hub_view.dart';
import 'package:echoes_of_aether/features/dungeon/town_top_bar.dart';
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
  testWidgets(
    'TownHubView navigasi bawah 5 tab (Adventure, Hero, Bag, Shop, Settings) menjaga state gameplay',
    (tester) async {
      final config = _loadRealConfig();
      final character = PlayerCharacter(
        config: config.progression,
        progress: const PlayerProgress(level: 10, gold: 2500),
        skillCatalog: config.skills,
        specializationConfig: config.specializations,
      );
      final inventory = Inventory(definitions: config.items);
      inventory.add('slime_gel', 4);
      inventory.addEquipment(
        const EquipmentInstance(
          id: 'eq_nav_1',
          definitionId: 'rusty_sword',
          slot: EquipmentSlot.weapon,
          rarity: ItemRarity.common,
          rolledStats: EquipmentStats(atk: 5),
        ),
      );
      final views = InventoryViews(inventory: inventory, character: character);
      final eqService = EquipmentService(
        inventory: inventory,
        loadout: character.loadout,
      );
      final settings = ValueNotifier<GameSettingsData>(
        const GameSettingsData(),
      );
      final shopService = ShopService(
        catalog: config.shop,
        items: config.items,
        equipmentFactory: EquipmentFactory(config.equipment),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: EchoesTheme.dark(),
          home: Scaffold(
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
              cycleProgress: const CycleProgress(ascensionRank: 2),
              onEnterDungeon: () {},
              onEquip: (id) {
                if (eqService.equip(id)) views.refresh();
              },
              onUnequip: (slot) {
                if (eqService.unequip(slot)) views.refresh();
              },
              onChooseSpecialization: (id) {
                if (character.chooseSpecialization(id)) views.refresh();
              },
              settings: settings,
              onSettingsChanged: (next) => settings.value = next,
              shopCatalog: config.shop,
              shopService: shopService,
              shopContext: ShopPlayerContext(playerLevel: character.level),
              onShopBuy: (id) async => ShopBuyNotFound(entryId: id),
              onShopSellEquipment: (id) async => ShopSellNotFound(targetId: id),
              onShopSellMaterialBulk: (id, qty) async =>
                  ShopSellNotFound(targetId: id),
            ),
          ),
        ),
      );

      // Top bar tampil dengan level, gold, rank
      expect(find.byType(TownTopBar), findsOneWidget);
      expect(find.textContaining('Lv 10'), findsWidgets);
      expect(find.textContaining('Rank 2'), findsWidgets);

      // 5 tab navigasi bawah ada
      final nav = find.byKey(const Key('town_bottom_nav'));
      expect(nav, findsOneWidget);

      // Pindah ke Bag -> pasang equipment -> state tetap terjaga saat pindah tab
      await tester.tap(find.descendant(of: nav, matching: find.text('Bag')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Pakai'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Tas perlengkapan (1)'), findsOneWidget);
      await tester.tap(find.text('Pakai'));
      await tester.pumpAndSettle();
      expect(
        character.loadout.instanceIn(EquipmentSlot.weapon)?.id,
        'eq_nav_1',
      );

      // Sub-tab Tas di Bag menampilkan Slime Gel
      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<int>),
          matching: find.text('Tas'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Slime Gel'), findsOneWidget);

      // Pindah ke Hero
      await tester.tap(find.descendant(of: nav, matching: find.text('Hero')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Karakter'), findsWidgets);

      // Pindah ke Shop
      await tester.tap(find.descendant(of: nav, matching: find.text('Shop')));
      await tester.pumpAndSettle();
      expect(find.text('Beli'), findsWidgets);

      // Pindah ke Settings
      await tester.tap(
        find.descendant(of: nav, matching: find.text('Settings')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pengaturan'), findsOneWidget);

      // Kembali ke Adventure -> equipment terpasang tetap ada & Adventure tampil
      await tester.tap(
        find.descendant(of: nav, matching: find.text('Adventure')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Town / Camp'), findsOneWidget);
      expect(
        character.loadout.instanceIn(EquipmentSlot.weapon)?.id,
        'eq_nav_1',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TownTopBar menampilkan angka besar dan rank tinggi tanpa overflow pada lebar 320dp',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: EchoesTheme.dark(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: const Scaffold(
              body: SizedBox(
                width: 320,
                child: TownTopBar(
                  level: 125000,
                  currentExp: 500000,
                  expToNext: 1000000,
                  gold: 9876543210,
                  ascensionRank: 1250,
                  specializationName: 'Arcanist',
                  maxHp: 4500000,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('Arcanist'), findsOneWidget);
      expect(find.textContaining('Lv 125'), findsOneWidget);
      expect(find.byKey(const Key('top_bar_gold')), findsOneWidget);
      expect(find.byKey(const Key('top_bar_rank')), findsOneWidget);
      expect(find.byKey(const Key('top_bar_exp')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
