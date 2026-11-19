import 'dart:io';
import 'dart:math' as math;

import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/event_shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/currency_config.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/event_shop_config.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/services/currency_service.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/event_shop_service.dart';
import 'package:echoes_of_aether/domain/services/shop_service.dart';
import 'package:echoes_of_aether/features/dungeon/event_shop_view.dart';
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
    time: parser.parseTime(settings),
    claimedRewards: parser.parseClaimedRewards(settings),
    currencies: parser.parseCurrencies(settings),
    notifications: parser.parseNotifications(settings),
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
    eventShop: const EventShopConfigParser().parse(
      _readAsset('event_shop.json'),
    ),
  );
}

void main() {
  late GameConfig config;
  late PlayerCharacter character;
  late Inventory inventory;
  late InventoryViews views;
  late ShopService shopService;
  late EventShopService eventShopService;
  late CurrencyService currencyService;
  late Map<(String, String), int> eventPurchases;
  final week1MondayMs = DateTime.utc(
    2026,
    11,
    16,
    10,
    0,
  ).millisecondsSinceEpoch;

  setUp(() {
    config = _loadRealConfig();
    character = PlayerCharacter(
      config: config.progression,
      specializationConfig: config.specializations,
      skillCatalog: config.skills,
      progress: const PlayerProgress(level: 30, gold: 100000),
      initialSpecializationId: 'vanguard',
    );
    inventory = Inventory(definitions: config.items)
      ..add('boss_remnant', 20)
      ..add('aether_scrap', 200);
    views = InventoryViews(inventory: inventory, character: character);
    shopService = ShopService(
      catalog: config.shop,
      items: config.items,
      equipmentFactory: EquipmentFactory(config.equipment),
    );
    eventShopService = EventShopService(
      catalog: config.eventShop!,
      items: config.items,
      equipmentFactory: EquipmentFactory(config.equipment),
    );
    currencyService = CurrencyService(
      definitions: config.currencies,
      initialBalances: {kAetherShardCurrencyId: 250},
    );
    eventPurchases = {};
  });

  ShopPlayerContext buildCtx({bool unlocked = true}) => ShopPlayerContext(
    playerLevel: character.level,
    cycleProgress: unlocked
        ? const CycleProgress(ascensionRank: 1, highestAscensionRank: 1)
        : const CycleProgress(),
    dungeonProgresses: unlocked
        ? const {
            'ancient_crypt': DungeonProgressSnapshot(
              currentDungeonId: 'ancient_crypt',
              clearsCount: 1,
            ),
          }
        : const {},
    eventShopPurchases: eventPurchases,
  );

  EventShopViewData buildViewData({bool unlocked = true}) =>
      eventShopService.buildViewData(
        effectiveNowMs: week1MondayMs,
        context: buildCtx(unlocked: unlocked),
        currencyBalance: currencyService.balance(kAetherShardCurrencyId),
        goldBalance: character.gold,
        inventory: inventory,
        hasInventorySpace: inventory.hasEquipmentSpace,
        purchaseCounts: eventPurchases,
        offset: Duration.zero,
      );

  testWidgets(
    'tab Event menampilkan 2 item mingguan, alasan syarat terkunci, dialog konfirmasi, dan item hasil beli tampil tidak dapat dijual di tab Jual',
    (tester) async {
      var unlocked = false;
      var buyCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return TownHubView(
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
                  shopContext: buildCtx(unlocked: unlocked),
                  onShopBuy: (entryId) async =>
                      ShopBuyNotFound(entryId: entryId),
                  onShopSellEquipment: (id) async =>
                      ShopSellNotFound(targetId: id),
                  onShopSellMaterialBulk: (id, qty) async =>
                      ShopSellNotFound(targetId: id),
                  aetherShard: currencyService.balance(kAetherShardCurrencyId),
                  eventShopData: buildViewData(unlocked: unlocked),
                  onEventShopBuy: (entryId) async {
                    buyCalls += 1;
                    final res = eventShopService.buy(
                      entryId: entryId,
                      effectiveNowMs: week1MondayMs,
                      inventory: inventory,
                      currencyService: currencyService,
                      character: character,
                      context: buildCtx(unlocked: unlocked),
                      random: math.Random(1),
                      purchaseCounts: eventPurchases,
                      timeZoneOffset: Duration.zero,
                    );
                    views.refresh();
                    setState(() {});
                    return res;
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Shop'));
      await tester.pumpAndSettle();

      expect(find.byType(ShopOverlay), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Event'), findsOneWidget);

      await tester.tap(find.widgetWithText(Tab, 'Event'));
      await tester.pumpAndSettle();

      expect(find.byType(EventShopView), findsOneWidget);
      final active = eventShopService.activeEntriesAt(
        week1MondayMs,
        offset: Duration.zero,
      );
      expect(active, hasLength(2));
      final epicOffer = active.firstWhere((e) => e.tier == EventItemTier.epic);
      final legOffer = active.firstWhere(
        (e) => e.tier == EventItemTier.legendary,
      );

      // Kedua item aktif tampil bersama alasan terkunci & countdown reset.
      expect(find.text(config.items[epicOffer.itemId]!.name), findsOneWidget);
      expect(find.textContaining('Pergantian minggu:'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(config.items[legOffer.itemId]!.name),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(config.items[legOffer.itemId]!.name), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(config.items[epicOffer.itemId]!.name),
        -100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.textContaining('Syarat belum terpenuhi:'),
        findsAtLeastNWidgets(1),
      );

      // Tombol beli nonaktif saat syarat belum terpenuhi.
      final lockedBtn = tester.widget<FilledButton>(
        find.byKey(Key('event_shop_buy_${epicOffer.id}')),
      );
      expect(lockedBtn.onPressed, isNull);

      // Buka akses requirement -> tombol aktif, buka dialog konfirmasi lalu batalkan dulu.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                unlocked = true;
                return TownHubView(
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
                  shopContext: buildCtx(unlocked: true),
                  onShopBuy: (entryId) async =>
                      ShopBuyNotFound(entryId: entryId),
                  onShopSellEquipment: (id) async =>
                      ShopSellNotFound(targetId: id),
                  onShopSellMaterialBulk: (id, qty) async =>
                      ShopSellNotFound(targetId: id),
                  aetherShard: currencyService.balance(kAetherShardCurrencyId),
                  eventShopData: buildViewData(unlocked: true),
                  onEventShopBuy: (entryId) async {
                    buyCalls += 1;
                    final res = eventShopService.buy(
                      entryId: entryId,
                      effectiveNowMs: week1MondayMs,
                      inventory: inventory,
                      currencyService: currencyService,
                      character: character,
                      context: buildCtx(unlocked: true),
                      random: math.Random(1),
                      purchaseCounts: eventPurchases,
                      timeZoneOffset: Duration.zero,
                    );
                    views.refresh();
                    setState(() {});
                    return res;
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Shop'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Event'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(Key('event_shop_buy_${epicOffer.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Konfirmasi Barter Outpost'), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(buyCalls, 0);

      // Konfirmasi beli -> saldo berkurang, item masuk tas, tombol menjadi nonaktif 1/1.
      await tester.tap(find.byKey(Key('event_shop_buy_${epicOffer.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('event_shop_confirm_buy')));
      await tester.pumpAndSettle();

      expect(buyCalls, 1);
      expect(currencyService.balance(kAetherShardCurrencyId), 250);
      expect(character.gold, 100000 - epicOffer.goldPrice);
      expect(inventory.quantityOf('boss_remnant'), 17);
      expect(inventory.quantityOf('aether_scrap'), 170);
      expect(find.textContaining('Berhasil barter'), findsOneWidget);
      expect(find.text('Sudah dibeli minggu ini (1/1)'), findsOneWidget);
      final afterBuyBtn = tester.widget<FilledButton>(
        find.byKey(Key('event_shop_buy_${epicOffer.id}')),
      );
      expect(afterBuyBtn.onPressed, isNull);

      // Pindah ke tab Jual -> item event tampil di bagian 'Tidak Dapat Dijual' beserta alasannya.
      await tester.tap(find.widgetWithText(Tab, 'Jual'));
      await tester.pumpAndSettle();
      expect(find.text('Tidak Dapat Dijual'), findsOneWidget);
      expect(find.text(config.items[epicOffer.itemId]!.name), findsOneWidget);
      expect(find.text('Item tidak dapat dijual.'), findsOneWidget);
      expect(find.text('Tidak Dijual'), findsOneWidget);
    },
  );
}
