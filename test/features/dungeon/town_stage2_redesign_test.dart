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
import 'package:echoes_of_aether/features/dungeon/character_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/equipment_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/inventory_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/settings_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/shop_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/town_hub_view.dart';
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

Widget _buildTownHarness({
  required GameConfig config,
  required PlayerCharacter character,
  required InventoryViews views,
  required ShopService shopService,
  required ValueNotifier<GameSettingsData> settings,
  String? selectedDungeonId,
  Map<String, DungeonProgressSnapshot>? dungeonProgresses,
  CycleProgress cycleProgress = const CycleProgress(),
  ValueChanged<String>? onSelectDungeon,
  ValueChanged<String>? onEnterDungeonById,
  VoidCallback? onEnterDungeon,
}) {
  final effectiveSelected = selectedDungeonId ?? 'forgotten_forest';
  final resolvedProgresses =
      dungeonProgresses ??
      const {
        'forgotten_forest': DungeonProgressSnapshot(
          currentDungeonId: 'forgotten_forest',
          highestClearedRoomIndex: 4,
          clearsCount: 1,
          clearedInCycleRank: 0,
        ),
        'crystal_cavern': DungeonProgressSnapshot(
          currentDungeonId: 'crystal_cavern',
          highestClearedRoomIndex: 2,
        ),
      };
  return MaterialApp(
    theme: EchoesTheme.dark(),
    home: Scaffold(
      body: TownHubView(
        character: character,
        views: views,
        items: config.items,
        dungeonProgress:
            resolvedProgresses[effectiveSelected] ??
            const DungeonProgressSnapshot(
              currentDungeonId: 'forgotten_forest',
              highestClearedRoomIndex: 4,
              clearsCount: 1,
              clearedInCycleRank: 0,
            ),
        dungeonDefinition: config.dungeons[effectiveSelected],
        availableDungeons: config.dungeons,
        dungeonProgresses: resolvedProgresses,
        cycleProgress: cycleProgress,
        selectedDungeonId: effectiveSelected,
        onSelectDungeon: onSelectDungeon,
        onEnterDungeonById: onEnterDungeonById,
        onEnterDungeon: onEnterDungeon ?? () {},
        onEquip: (_) {},
        onUnequip: (_) {},
        onChooseSpecialization: (id) {
          if (character.chooseSpecialization(id)) views.refresh();
        },
        settings: settings,
        onSettingsChanged: (next) => settings.value = next,
        shopCatalog: config.shop,
        shopService: shopService,
        shopContext: ShopPlayerContext(
          playerLevel: character.level,
          cycleProgress: cycleProgress,
          dungeonProgresses:
              dungeonProgresses ??
              const {
                'forgotten_forest': DungeonProgressSnapshot(
                  currentDungeonId: 'forgotten_forest',
                  highestClearedRoomIndex: 4,
                  clearsCount: 1,
                  clearedInCycleRank: 0,
                ),
              },
        ),
        onShopBuy: (id) async => ShopBuyNotFound(entryId: id),
        onShopSellEquipment: (id) async => ShopSellSuccess(
          goldEarned: 0,
          remainingGold: character.gold,
          quantitySold: 0,
          itemId: id,
        ),
        onShopSellMaterialBulk: (id, qty) async => ShopSellSuccess(
          goldEarned: 0,
          remainingGold: character.gold,
          quantitySold: 0,
          itemId: id,
        ),
        onShopSellBatch: (_, _) async => ShopSellSuccess(
          goldEarned: 0,
          remainingGold: character.gold,
          quantitySold: 0,
          itemId: '',
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'Stage 2: HeroShowcaseCard menampilkan CampBackdrop dan ilustrasi sesuai class aktif (Base, Vanguard, Arcanist, Ranger)',
    (tester) async {
      final config = _loadRealConfig();
      final settings = ValueNotifier<GameSettingsData>(
        const GameSettingsData(),
      );
      final shopService = ShopService(
        catalog: config.shop,
        items: config.items,
        equipmentFactory: EquipmentFactory(config.equipment),
      );

      final specExpectations =
          <({String? specId, String visualId, String label})>[
            (specId: null, visualId: 'base', label: 'Adventurer'),
            (specId: 'vanguard', visualId: 'vanguard', label: 'Vanguard'),
            (specId: 'arcanist', visualId: 'arcanist', label: 'Arcanist'),
            (specId: 'ranger', visualId: 'ranger', label: 'Ranger'),
          ];

      for (final entry in specExpectations) {
        final character = PlayerCharacter(
          config: config.progression,
          progress: const PlayerProgress(level: 14, gold: 1800),
          initialSpecializationId: entry.specId,
          skillCatalog: config.skills,
          specializationConfig: config.specializations,
        );
        final inventory = Inventory(definitions: config.items);
        final views = InventoryViews(
          inventory: inventory,
          character: character,
        );

        await tester.pumpWidget(
          _buildTownHarness(
            config: config,
            character: character,
            views: views,
            shopService: shopService,
            settings: settings,
          ),
        );
        await tester.pump();

        expect(find.byKey(const Key('hero_showcase_card')), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('camp_backdrop')),
          findsOneWidget,
        );
        expect(
          find.byKey(
            ValueKey<String>('character_illustration_${entry.visualId}'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining(entry.label), findsWidgets);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'Stage 2: Quick Access Strip dan EchoesBottomNavigation mengarahkan ke tab/sub-tab yang tepat tanpa regresi',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final config = _loadRealConfig();
      final character = PlayerCharacter(
        config: config.progression,
        progress: const PlayerProgress(level: 12, gold: 2000),
        initialSpecializationId: 'arcanist',
        skillCatalog: config.skills,
        specializationConfig: config.specializations,
      );
      final inventory = Inventory(definitions: config.items);
      inventory.add('slime_gel', 3);
      inventory.addEquipment(
        const EquipmentInstance(
          id: 'eq_s2_1',
          definitionId: 'rusty_sword',
          slot: EquipmentSlot.weapon,
          rarity: ItemRarity.common,
          rolledStats: EquipmentStats(atk: 5),
        ),
      );
      final views = InventoryViews(inventory: inventory, character: character);
      EquipmentService(inventory: inventory, loadout: character.loadout);
      final settings = ValueNotifier<GameSettingsData>(
        const GameSettingsData(),
      );
      final shopService = ShopService(
        catalog: config.shop,
        items: config.items,
        equipmentFactory: EquipmentFactory(config.equipment),
      );

      await tester.pumpWidget(
        _buildTownHarness(
          config: config,
          character: character,
          views: views,
          shopService: shopService,
          settings: settings,
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('town_bottom_nav')), findsOneWidget);

      // Quick Access Strip tidak lagi menumpuk shortcut duplikat Bottom Nav
      expect(find.byKey(const Key('quick_access_hero')), findsNothing);
      expect(find.byKey(const Key('quick_access_equipment')), findsNothing);
      expect(find.byKey(const Key('quick_access_bag')), findsNothing);
      expect(find.byKey(const Key('quick_access_skills')), findsNothing);
      expect(find.byKey(const Key('quick_access_shop')), findsNothing);

      // Bottom nav -> Hero (Profil & Gear + Kelas & Skill)
      await tester.tap(find.text('Hero'));
      await tester.pump();
      expect(find.byType(CharacterOverlay), findsOneWidget);
      expect(find.text('Profil & Gear'), findsOneWidget);
      expect(find.text('Perlengkapan Terpasang'), findsOneWidget);

      await tester.tap(find.text('Kelas & Skill'));
      await tester.pump();
      expect(find.text('Spesialisasi'), findsOneWidget);

      // Bottom nav -> Bag (Equipment & Item)
      await tester.tap(find.text('Bag'));
      await tester.pump();
      expect(find.byType(EquipmentOverlay), findsOneWidget);

      await tester.tap(find.text('Item'));
      await tester.pump();
      expect(find.byType(InventoryOverlay), findsOneWidget);

      // Bottom nav -> Shop
      await tester.tap(find.text('Shop'));
      await tester.pump();
      expect(find.byType(ShopOverlay), findsOneWidget);

      // Bottom nav Settings tab tetap berjalan
      await tester.tap(find.text('Settings'));
      await tester.pump();
      expect(find.byType(SettingsOverlay), findsOneWidget);

      // Kembali ke Adventure
      await tester.tap(find.text('Adventure'));
      await tester.pump();
      expect(find.text('Town / Camp'), findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Stage 2: Illustrated Biome Cards menampilkan seluruh biome, room progress, status kunci, dan layout tablet tanpa overflow',
    (tester) async {
      tester.view.physicalSize = const Size(960, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final config = _loadRealConfig();
      final character = PlayerCharacter(
        config: config.progression,
        progress: const PlayerProgress(level: 16, gold: 3400),
        initialSpecializationId: 'ranger',
        skillCatalog: config.skills,
        specializationConfig: config.specializations,
      );
      final inventory = Inventory(definitions: config.items);
      final views = InventoryViews(inventory: inventory, character: character);
      final settings = ValueNotifier<GameSettingsData>(
        const GameSettingsData(),
      );
      final shopService = ShopService(
        catalog: config.shop,
        items: config.items,
        equipmentFactory: EquipmentFactory(config.equipment),
      );

      String? selectedDungeon;
      String? enteredDungeon;

      await tester.pumpWidget(
        _buildTownHarness(
          config: config,
          character: character,
          views: views,
          shopService: shopService,
          settings: settings,
          selectedDungeonId: 'crystal_cavern',
          cycleProgress: const CycleProgress(ascensionRank: 0),
          onSelectDungeon: (id) => selectedDungeon = id,
          onEnterDungeonById: (id) => enteredDungeon = id,
        ),
      );
      await tester.pump();

      const expectedBiomes = <String>[
        'forgotten_forest',
        'crystal_cavern',
        'ancient_crypt',
        'ashen_wasteland',
        'aether_sanctum',
        'ascension_sanctum',
      ];
      for (final biomeId in expectedBiomes) {
        final artworkFinder = find.descendant(
          of: find.byKey(Key('dungeon_row_$biomeId')),
          matching: find.byKey(ValueKey<String>('biome_artwork_$biomeId')),
        );
        await tester.scrollUntilVisible(
          artworkFinder,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(artworkFinder, findsOneWidget);
      }

      // Pastikan Active Adventure & Daftar Dungeon menampilkan status + progress ruangan
      expect(find.text('Target Aktif'), findsOneWidget);
      expect(find.text('Progres room tertinggi: 3 / 6'), findsOneWidget);
      expect(find.text('3 / 6'), findsOneWidget);
      expect(find.text('5 / 5'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);
      expect(find.text('Terbuka'), findsWidgets);
      expect(find.text('Terkunci'), findsWidgets);

      // Verifikasi aksi pilih dan masuk dungeon tetap berjalan
      final selectForest = find.byKey(
        const Key('dungeon_select_forgotten_forest'),
      );
      await tester.ensureVisible(selectForest);
      await tester.tap(selectForest);
      await tester.pump();
      expect(selectedDungeon, 'forgotten_forest');

      final enterCrystal = find.byKey(
        const Key('dungeon_enter_crystal_cavern'),
      );
      await tester.ensureVisible(enterCrystal);
      await tester.tap(enterCrystal);
      await tester.pump();
      expect(enteredDungeon, 'crystal_cavern');

      // Pastikan juga layout smartphone sempit dengan aksi Pilih Target + Masuk bebas overflow
      tester.view.physicalSize = const Size(320, 568);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
