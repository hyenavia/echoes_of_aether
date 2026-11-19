import 'dart:io';
import 'dart:math' as math;

import 'package:echoes_of_aether/core/utils/number_formatter.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/shop_config.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/shop_service.dart';
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

void main() {
  late GameConfig config;
  late PlayerCharacter character;
  late Inventory inventory;
  late InventoryViews views;
  late ShopService shopService;
  late Map<String, int> purchases;

  setUp(() {
    config = _loadRealConfig();
    character = PlayerCharacter(
      config: config.progression,
      specializationConfig: config.specializations,
      skillCatalog: config.skills,
      progress: const PlayerProgress(level: 5, currentExp: 0, gold: 2000),
      initialSpecializationId: 'vanguard',
    );
    inventory = Inventory(definitions: config.items);
    views = InventoryViews(inventory: inventory, character: character);
    shopService = ShopService(
      catalog: config.shop,
      items: config.items,
      equipmentFactory: EquipmentFactory(config.equipment),
    );
    purchases = {};
  });

  testWidgets(
    'ShopOverlay dibuka dari TownHubView, menonaktifkan item yang syaratnya belum terpenuhi dan menampilkan alasannya',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TownHubView(
              character: character,
              views: views,
              items: config.items,
              dungeonProgress: const DungeonProgressSnapshot(),
              dungeonDefinition: config.dungeons['forgotten_forest'],
              availableDungeons: config.dungeons,
              onEnterDungeon: () {},
              onEquip: (_) {},
              onUnequip: (_) {},
              onChooseSpecialization: (_) {},
              shopCatalog: config.shop,
              shopService: shopService,
              shopContext: ShopPlayerContext(
                playerLevel: character.level,
                shopPurchases: purchases,
              ),
              onShopBuy: (entryId) async {
                final res = shopService.buy(
                  entryId: entryId,
                  character: character,
                  inventory: inventory,
                  context: ShopPlayerContext(
                    playerLevel: character.level,
                    shopPurchases: purchases,
                  ),
                  random: math.Random(1),
                  purchaseCounts: purchases,
                );
                views.refresh();
                return res;
              },
              onShopSellEquipment: (id) async => shopService.sellEquipment(
                instanceId: id,
                character: character,
                inventory: inventory,
              ),
              onShopSellMaterialBulk: (id, qty) async =>
                  shopService.sellMaterialBulk(
                    itemId: id,
                    quantity: qty,
                    character: character,
                    inventory: inventory,
                  ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Shop'));
      await tester.pumpAndSettle();

      expect(find.byType(ShopOverlay), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Beli'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Jual'), findsOneWidget);

      // Item Rare membutuhkan Min Lv 10; karakter Lv 5 -> tombol Beli nonaktif & alasan tampil
      await tester.scrollUntilVisible(
        find.text('Guardian Amulet'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.textContaining('Min Lv 10'), findsWidgets);

      // Item Epic/Legendary juga menampilkan alasan requirement
      await tester.scrollUntilVisible(
        find.text('Heart of Aether'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.textContaining('Min Ascension Rank 1'), findsOneWidget);

      // Pastikan tombol Beli untuk Heart of Aether nonaktif
      final buyButtons = tester.widgetList<FilledButton>(
        find.widgetWithText(FilledButton, 'Beli'),
      );
      expect(buyButtons.any((b) => b.onPressed == null), isTrue);
    },
  );

  testWidgets(
    'ShopOverlay tidak menyimpan state gameplay sendiri; state gold/tas mencerminkan domain setelah transaksi',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ShopOverlay(
                catalog: config.shop,
                items: config.items,
                dungeons: config.dungeons,
                shopService: shopService,
                playerContext: ShopPlayerContext(
                  playerLevel: character.level,
                  shopPurchases: purchases,
                ),
                playerGold: character.gold,
                views: views,
                onBuy: (entryId) async {
                  final res = shopService.buy(
                    entryId: entryId,
                    character: character,
                    inventory: inventory,
                    context: ShopPlayerContext(
                      playerLevel: character.level,
                      shopPurchases: purchases,
                    ),
                    random: math.Random(2),
                    purchaseCounts: purchases,
                  );
                  views.refresh();
                  setState(() {});
                  return res;
                },
                onSellEquipment: (id) async => shopService.sellEquipment(
                  instanceId: id,
                  character: character,
                  inventory: inventory,
                ),
                onSellMaterialBulk: (id, qty) async =>
                    shopService.sellMaterialBulk(
                      itemId: id,
                      quantity: qty,
                      character: character,
                      inventory: inventory,
                    ),
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Gold ${NumberFormatter.format(2000)}'), findsOneWidget);

      // Beli Rusty Sword
      final swordPrice = config.shop.byId('shop_rusty_sword')!.price;
      await tester.tap(find.widgetWithText(FilledButton, 'Beli').first);
      await tester.pumpAndSettle();

      expect(character.gold, 2000 - swordPrice);
      expect(
        find.textContaining('Berhasil membeli Rusty Sword'),
        findsOneWidget,
      );
      expect(inventory.equipmentCount, 1);
    },
  );

  testWidgets(
    'Tab Jual: konfirmasi item Rare+, equipment terpasang tidak bisa dijual, dan jual massal material',
    (tester) async {
      final rareEq = EquipmentFactory(config.equipment).create(
        instanceId: 'eq_rare_1',
        definition: config.items['guardian_amulet']!,
        random: math.Random(3),
      );
      expect(inventory.addEquipment(rareEq), isTrue);

      final equippedEq = EquipmentFactory(config.equipment).create(
        instanceId: 'eq_equipped_1',
        definition: config.items['rusty_sword']!,
        random: math.Random(4),
      );
      character.loadout.equip(equippedEq);

      final matDef = config.items.values.firstWhere(
        (d) => d.category == ItemCategory.material && d.sellValue > 0,
      );
      inventory.add(matDef.id, 8);
      views.refresh();

      final shopCatalogWithMat = ShopCatalog(
        entries: config.shop.entries,
        sell: const SellRules(
          sellableCategories: {ItemCategory.equipment, ItemCategory.material},
        ),
      );
      final shopServiceWithMat = ShopService(
        catalog: shopCatalogWithMat,
        items: config.items,
        equipmentFactory: EquipmentFactory(config.equipment),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ShopOverlay(
                catalog: shopCatalogWithMat,
                items: config.items,
                dungeons: config.dungeons,
                shopService: shopServiceWithMat,
                playerContext: ShopPlayerContext(
                  playerLevel: character.level,
                  shopPurchases: purchases,
                ),
                playerGold: character.gold,
                views: views,
                onBuy: (entryId) async => ShopBuyNotFound(entryId: entryId),
                onSellEquipment: (id) async {
                  final res = shopServiceWithMat.sellEquipment(
                    instanceId: id,
                    character: character,
                    inventory: inventory,
                  );
                  views.refresh();
                  setState(() {});
                  return res;
                },
                onSellMaterialBulk: (id, qty) async {
                  final res = shopServiceWithMat.sellMaterialBulk(
                    itemId: id,
                    quantity: qty,
                    character: character,
                    inventory: inventory,
                  );
                  views.refresh();
                  setState(() {});
                  return res;
                },
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Jual'));
      await tester.pumpAndSettle();

      // Equipment terpasang ditandai tidak bisa dijual
      await tester.scrollUntilVisible(
        find.text('Sedang dipakai — tidak bisa dijual'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Sedang dipakai — tidak bisa dijual'), findsOneWidget);
      final equippedBtn = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Dipakai'),
      );
      expect(equippedBtn.onPressed, isNull);
      await tester.scrollUntilVisible(
        find.text('Equipment di Tas'),
        -100,
        scrollable: find.byType(Scrollable).last,
      );

      // Jual Rare equipment -> muncul dialog konfirmasi; Batal tidak menjual
      await tester.tap(find.widgetWithText(OutlinedButton, 'Jual').first);
      await tester.pumpAndSettle();
      expect(find.text('Konfirmasi Penjualan'), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(inventory.equipmentById('eq_rare_1'), isNotNull);

      // Jual lagi lalu Konfirmasi
      await tester.tap(find.widgetWithText(OutlinedButton, 'Jual').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Jual'));
      await tester.pumpAndSettle();
      expect(inventory.equipmentById('eq_rare_1'), isNull);
      expect(character.gold, 2000 + config.items['guardian_amulet']!.sellValue);

      // Jual massal material: pilih 1/2 (4 dari 8)
      await tester.tap(find.widgetWithText(OutlinedButton, 'Jual...').first);
      await tester.pumpAndSettle();
      expect(find.text('8 / 8'), findsOneWidget);

      await tester.tap(find.text('1/2'));
      await tester.pumpAndSettle();
      expect(find.text('4 / 8'), findsOneWidget);

      await tester.tap(find.text('Konfirmasi Jual'));
      await tester.pumpAndSettle();
      expect(inventory.quantityOf(matDef.id), 4);
      expect(find.textContaining('Menjual 4x ${matDef.name}'), findsOneWidget);
    },
  );

  testWidgets(
    'ShopOverlay mendukung filter kategori/rarity, multi-select, dan Jual Semua dengan peringatan Epic+',
    (tester) async {
      final swordDef = config.items['rusty_sword']!;
      final armorDef = config.items['padded_vest']!;
      final epicDef = config.items['aether_blade']!;
      final matDef = config.items.values.firstWhere(
        (i) => i.category == ItemCategory.material && i.sellValue > 0,
      );

      inventory.addEquipment(
        EquipmentInstance(
          id: 'eq_common_sword',
          definitionId: swordDef.id,
          slot: swordDef.equipment!.slot,
          rarity: swordDef.rarity,
          rolledStats: swordDef.equipment!.baseStats,
        ),
      );
      inventory.addEquipment(
        EquipmentInstance(
          id: 'eq_common_armor',
          definitionId: armorDef.id,
          slot: armorDef.equipment!.slot,
          rarity: armorDef.rarity,
          rolledStats: armorDef.equipment!.baseStats,
        ),
      );
      inventory.addEquipment(
        EquipmentInstance(
          id: 'eq_epic_blade',
          definitionId: epicDef.id,
          slot: epicDef.equipment!.slot,
          rarity: epicDef.rarity,
          rolledStats: epicDef.equipment!.baseStats,
        ),
      );
      inventory.add(matDef.id, 3);
      views.refresh();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ShopOverlay(
                catalog: config.shop,
                items: config.items,
                dungeons: config.dungeons,
                shopService: shopService,
                playerContext: ShopPlayerContext(
                  playerLevel: character.level,
                  shopPurchases: purchases,
                ),
                playerGold: character.gold,
                views: views,
                onBuy: (entryId) async => ShopBuyNotFound(entryId: entryId),
                onSellEquipment: (id) async => shopService.sellEquipment(
                  instanceId: id,
                  character: character,
                  inventory: inventory,
                ),
                onSellMaterialBulk: (id, qty) async =>
                    shopService.sellMaterialBulk(
                      itemId: id,
                      quantity: qty,
                      character: character,
                      inventory: inventory,
                    ),
                onSellBatch: (eqIds, matQtys) async {
                  final res = shopService.sellBatch(
                    equipmentInstanceIds: eqIds,
                    materialQuantities: matQtys,
                    character: character,
                    inventory: inventory,
                  );
                  views.refresh();
                  setState(() {});
                  return res;
                },
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      // Filter Kategori Senjata di Tab Beli menyembunyikan Armor
      await tester.tap(find.widgetWithText(ChoiceChip, 'Senjata'));
      await tester.pumpAndSettle();
      expect(find.text('Rusty Sword'), findsOneWidget);
      expect(find.text('Padded Vest'), findsNothing);

      // Pindah ke Tab Jual
      await tester.tap(find.text('Jual'));
      await tester.pumpAndSettle();

      // Multi-select 2 item Common (Rusty Sword + Padded Vest) lalu Jual Terpilih
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsAtLeastNWidgets(2));
      await tester.tap(checkboxes.at(0));
      await tester.tap(checkboxes.at(1));
      await tester.pumpAndSettle();

      expect(find.textContaining('Jual Terpilih (2'), findsOneWidget);
      await tester.tap(find.textContaining('Jual Terpilih (2'));
      await tester.pumpAndSettle();

      expect(inventory.equipmentById('eq_common_sword'), isNull);
      expect(inventory.equipmentById('eq_common_armor'), isNull);
      expect(inventory.equipmentById('eq_epic_blade'), isNotNull);

      // Jual Semua -> muncul peringatan Epic+ karena ada Aether Blade (Epic)
      await tester.tap(find.widgetWithText(FilledButton, 'Jual Semua'));
      await tester.pumpAndSettle();
      expect(find.textContaining('PERINGATAN Epic+'), findsOneWidget);
      expect(find.textContaining('Aether Blade'), findsWidgets);

      await tester.tap(find.widgetWithText(FilledButton, 'Jual'));
      await tester.pumpAndSettle();
      expect(inventory.equipmentById('eq_epic_blade'), isNull);
      expect(
        inventory.quantityOf(matDef.id),
        3,
      ); // Material non-sellable tidak terjual
    },
  );

  testWidgets(
    'Tab Jual: tombol Jual Sampah melikuidasi seluruh equipment Common & Uncommon tanpa menyentuh Rare/Epic dan Material',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final eqFactory = EquipmentFactory(config.equipment);
      final commonDef = config.items['rusty_sword']!;
      final uncommonDef = config.items['hunters_bow']!;
      final rareDef = config.items['guardian_amulet']!;
      final epicDef = config.items['aether_blade']!;
      final matDef = config.items['slime_gel']!;

      inventory.addEquipment(
        eqFactory.create(
          instanceId: 'eq_c1',
          definition: commonDef,
          random: math.Random(1),
        ),
      );
      inventory.addEquipment(
        eqFactory.create(
          instanceId: 'eq_u1',
          definition: uncommonDef,
          random: math.Random(2),
        ),
      );
      inventory.addEquipment(
        eqFactory.create(
          instanceId: 'eq_r1',
          definition: rareDef,
          random: math.Random(3),
        ),
      );
      inventory.addEquipment(
        eqFactory.create(
          instanceId: 'eq_e1',
          definition: epicDef,
          random: math.Random(4),
        ),
      );
      inventory.add(matDef.id, 25);
      views.refresh();

      final initialGold = character.gold;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ShopOverlay(
                catalog: config.shop,
                items: config.items,
                dungeons: config.dungeons,
                shopService: shopService,
                playerContext: ShopPlayerContext(
                  playerLevel: character.level,
                  shopPurchases: purchases,
                ),
                playerGold: character.gold,
                views: views,
                onBuy: (entryId) async => ShopBuyNotFound(entryId: entryId),
                onSellEquipment: (id) async => shopService.sellEquipment(
                  instanceId: id,
                  character: character,
                  inventory: inventory,
                ),
                onSellMaterialBulk: (id, qty) async =>
                    shopService.sellMaterialBulk(
                      itemId: id,
                      quantity: qty,
                      character: character,
                      inventory: inventory,
                    ),
                onSellBatch: (eqIds, matQtys) async {
                  final res = shopService.sellBatch(
                    equipmentInstanceIds: eqIds,
                    materialQuantities: matQtys,
                    character: character,
                    inventory: inventory,
                  );
                  views.refresh();
                  setState(() {});
                  return res;
                },
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      // Pindah ke Tab Jual
      await tester.tap(find.text('Jual'));
      await tester.pumpAndSettle();

      final junkBtn = find.byKey(const Key('sell_junk_equipment_button'));
      expect(junkBtn, findsOneWidget);
      expect(find.textContaining('Jual Sampah (2'), findsOneWidget);

      // Ketuk Jual Sampah -> Dialog konfirmasi muncul
      await tester.tap(junkBtn);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Jual Semua Sampah (Common & Uncommon)'),
        findsOneWidget,
      );

      // Konfirmasi Jual
      await tester.tap(find.widgetWithText(FilledButton, 'Jual'));
      await tester.pumpAndSettle();

      // Common dan Uncommon hilang dari tas
      expect(inventory.equipmentById('eq_c1'), isNull);
      expect(inventory.equipmentById('eq_u1'), isNull);

      // Rare, Epic, dan Material TIDAK tersentuh
      expect(inventory.equipmentById('eq_r1'), isNotNull);
      expect(inventory.equipmentById('eq_e1'), isNotNull);
      expect(inventory.quantityOf(matDef.id), 25);

      // Gold pemain bertambah
      expect(character.gold, greaterThan(initialGold));

      // Tombol Jual Sampah sekarang disabled dan menampilkan 0
      expect(find.textContaining('Jual Sampah (0)'), findsOneWidget);
    },
  );

  testWidgets(
    'ShopOverlay Tab Jual melindungi equipment favorit dari single sell, batch sell, dan quick junk sell',
    (tester) async {
      final swordDef = config.items['rusty_sword']!;
      final capDef = config.items['leather_cap']!;
      final factory = EquipmentFactory(config.equipment);

      // eq_fav_common adalah common, tetapi difavoritkan
      final favCommon = factory
          .create(
            instanceId: 'eq_fav_c1',
            definition: swordDef,
            random: math.Random(1),
          )
          .copyWith(isFavorite: true, rarity: ItemRarity.common);

      // eq_normal_common adalah common biasa
      final normalCommon = factory
          .create(
            instanceId: 'eq_norm_c1',
            definition: capDef,
            random: math.Random(2),
          )
          .copyWith(isFavorite: false, rarity: ItemRarity.common);

      inventory.addEquipment(favCommon);
      inventory.addEquipment(normalCommon);
      views.refresh();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ShopOverlay(
                catalog: config.shop,
                items: config.items,
                dungeons: config.dungeons,
                shopService: shopService,
                playerContext: ShopPlayerContext(
                  playerLevel: character.level,
                  shopPurchases: purchases,
                ),
                playerGold: character.gold,
                views: views,
                onBuy: (entryId) async => ShopBuyNotFound(entryId: entryId),
                onSellEquipment: (id) async {
                  final res = shopService.sellEquipment(
                    instanceId: id,
                    character: character,
                    inventory: inventory,
                  );
                  views.refresh();
                  setState(() {});
                  return res;
                },
                onSellMaterialBulk: (id, qty) async =>
                    shopService.sellMaterialBulk(
                      itemId: id,
                      quantity: qty,
                      character: character,
                      inventory: inventory,
                    ),
                onSellBatch: (eqIds, matMap) async {
                  final res = shopService.sellBatch(
                    equipmentInstanceIds: eqIds,
                    materialQuantities: matMap,
                    character: character,
                    inventory: inventory,
                  );
                  views.refresh();
                  setState(() {});
                  return res;
                },
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      // Buka Tab Jual
      await tester.tap(find.text('Jual'));
      await tester.pumpAndSettle();

      // 1. Tombol 'Jual Sampah' hanya menghitung 1 (normalCommon), bukan 2, karena favCommon dikecualikan
      expect(find.textContaining('Jual Sampah (1'), findsOneWidget);

      // 2. Pada item favorit, badge 'Favorit' dan bintang emas muncul
      expect(find.text('Favorit'), findsWidgets);
      expect(find.byIcon(Icons.star), findsOneWidget);

      // 3. Tombol jual per-item untuk item favorit adalah disabled dengan label 'Favorit'
      final favButtonFinder = find.widgetWithText(OutlinedButton, 'Favorit');
      expect(favButtonFinder, findsOneWidget);
      final outlinedBtn = tester.widget<OutlinedButton>(favButtonFinder);
      expect(outlinedBtn.onPressed, isNull); // disabled!

      // 4. Checkbox untuk item favorit disabled
      final checkboxes = tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .toList();
      expect(checkboxes, hasLength(2));
      expect(checkboxes.where((c) => c.onChanged == null), hasLength(1));
      expect(checkboxes.where((c) => c.onChanged != null), hasLength(1));

      // 5. Tombol 'Pilih Semua' hanya memilih item non-favorit
      await tester.tap(find.text('Pilih Semua'));
      await tester.pumpAndSettle();

      // Tombol Jual Terpilih menunjukkan 1 item terpilih (hanya normalCommon)
      expect(find.textContaining('Jual Terpilih (1'), findsOneWidget);

      // Batal Pilih
      await tester.tap(find.text('Batal Pilih'));
      await tester.pumpAndSettle();

      // 6. Jalankan Quick Junk Sell
      await tester.tap(find.byKey(const Key('sell_junk_equipment_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Jual'));
      await tester.pumpAndSettle();

      // normalCommon terjual, favCommon TETAP aman di inventory!
      expect(inventory.equipmentById(normalCommon.id), isNull);
      expect(inventory.equipmentById(favCommon.id), isNotNull);
      expect(inventory.equipmentById(favCommon.id)!.isFavorite, isTrue);
    },
  );
}
