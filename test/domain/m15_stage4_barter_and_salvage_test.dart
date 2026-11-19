import 'dart:io';

import 'package:drift/native.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/data/models/boss_events_config_parser.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/event_shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/currency_config.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/event_shop_config.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/event_shop_purchase.dart';
import 'package:echoes_of_aether/domain/services/blacksmith_service.dart';
import 'package:echoes_of_aether/domain/services/currency_service.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/event_shop_service.dart';
import 'package:echoes_of_aether/domain/services/shop_service.dart';
import 'package:echoes_of_aether/features/dungeon/blacksmith_overlay.dart';
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
    bossEvents: const BossEventsConfigParser().parse(
      _readAsset('boss_events.json'),
    ),
    shop: const ShopConfigParser().parse(_readAsset('shop.json')),
    eventShop: const EventShopConfigParser().parse(
      _readAsset('event_shop.json'),
    ),
  );
}

void main() {
  late GameConfig config;
  const blacksmith = BlacksmithService();

  setUpAll(() {
    config = _loadRealConfig();
  });

  group('M15 Stage 4 — Salvage System (BlacksmithService)', () {
    test('kalkulasi hasil Aether Scrap sesuai rarity dan enhancementLevel', () {
      EquipmentInstance eq(String defId, ItemRarity rarity, {int enh = 0}) =>
          EquipmentInstance(
            id: 'eq_test_$defId',
            definitionId: defId,
            slot: EquipmentSlot.weapon,
            rarity: rarity,
            rolledStats: const EquipmentStats(atk: 10),
            enhancementLevel: enh,
          );

      expect(
        blacksmith.getSalvageScrapYield(eq('rusty_sword', ItemRarity.common)),
        2,
      );
      expect(
        blacksmith.getSalvageScrapYield(eq('hunters_bow', ItemRarity.uncommon)),
        5,
      );
      expect(
        blacksmith.getSalvageScrapYield(eq('ranger_blade', ItemRarity.rare)),
        12,
      );
      expect(
        blacksmith.getSalvageScrapYield(
          eq('event_dawn_blade', ItemRarity.epic),
        ),
        25,
      );
      expect(
        blacksmith.getSalvageScrapYield(
          eq('aether_blade', ItemRarity.legendary),
        ),
        50,
      );
      expect(
        blacksmith.getSalvageScrapYield(
          eq('aether_blade', ItemRarity.legendary, enh: 5),
        ),
        60,
      );
      expect(
        blacksmith.getSalvageScrapYield(
          eq('dawns_aegis_blade', ItemRarity.mythical, enh: 10),
        ),
        0,
      );
    });

    test('salvageEquipment menukar equipment tas menjadi aether_scrap secara atomik dan menolak item terpasang / Mythical / penuh', () {
      final char = PlayerCharacter(
        config: config.progression,
        specializationConfig: config.specializations,
        skillCatalog: config.skills,
        progress: const PlayerProgress(level: 20),
        initialSpecializationId: 'vanguard',
      );
      final inv = Inventory(definitions: config.items);

      final equippedSword = const EquipmentInstance(
        id: 'eq_equipped',
        definitionId: 'rusty_sword',
        slot: EquipmentSlot.weapon,
        rarity: ItemRarity.common,
        rolledStats: EquipmentStats(atk: 4),
      );
      char.loadout.equip(equippedSword);

      final bagRare = const EquipmentInstance(
        id: 'eq_bag_rare',
        definitionId: 'ranger_blade',
        slot: EquipmentSlot.weapon,
        rarity: ItemRarity.rare,
        rolledStats: EquipmentStats(atk: 9),
        enhancementLevel: 3,
      );
      final bagMythical = const EquipmentInstance(
        id: 'eq_bag_mythical',
        definitionId: 'dawns_aegis_blade',
        slot: EquipmentSlot.weapon,
        rarity: ItemRarity.mythical,
        rolledStats: EquipmentStats(atk: 45),
      );
      inv.addEquipment(bagRare);
      inv.addEquipment(bagMythical);

      // 1. Menolak equipment yang sedang dipakai
      final resEquipped = blacksmith.salvageEquipment(
        inventory: inv,
        instanceId: 'eq_equipped',
        loadout: char.loadout,
      );
      expect(resEquipped.status, BlacksmithSalvageStatus.cannotSalvageEquipped);
      expect(inv.quantityOf('aether_scrap'), 0);

      // 2. Menolak equipment Mythical
      final resMythical = blacksmith.salvageEquipment(
        inventory: inv,
        instanceId: 'eq_bag_mythical',
        loadout: char.loadout,
      );
      expect(resMythical.status, BlacksmithSalvageStatus.cannotSalvageMythical);
      expect(inv.equipmentById('eq_bag_mythical'), isNotNull);
      expect(inv.quantityOf('aether_scrap'), 0);

      // 3. Menolak jika tidak ada slot stack tersisa
      final fullStackInv = Inventory(
        definitions: config.items,
        maxStackSlots: 1,
      );
      fullStackInv.add('slime_gel', 1);
      fullStackInv.addEquipment(bagRare);
      final resFull = blacksmith.salvageEquipment(
        inventory: fullStackInv,
        instanceId: 'eq_bag_rare',
        loadout: char.loadout,
      );
      expect(resFull.status, BlacksmithSalvageStatus.inventoryFull);
      expect(fullStackInv.equipmentById('eq_bag_rare'), isNotNull);

      // 4. Sukses membongkar rare +3 -> 12 + 6 = 18 Aether Scrap
      final resOk = blacksmith.salvageEquipment(
        inventory: inv,
        instanceId: 'eq_bag_rare',
        loadout: char.loadout,
      );
      expect(resOk.isSuccess, isTrue);
      expect(resOk.aetherScrapGained, 18);
      expect(inv.equipmentById('eq_bag_rare'), isNull);
      expect(inv.quantityOf('aether_scrap'), 18);
    });
  });

  group('M15 Stage 4 — Boss Remnant Drops, Barter & Migrasi Kuota', () {
    test('boss_remnant tersedia di items.json dan seluruh boss loot tables dungeon', () {
      expect(config.items['boss_remnant'], isNotNull);
      expect(config.items['aether_scrap'], isNotNull);

      const bossTableIds = [
        'boss_loot',
        'crystal_boss_loot',
        'crypt_boss_loot',
        'ashen_boss_loot',
        'sanctum_boss_loot',
      ];
      for (final tableId in bossTableIds) {
        final table = config.lootTables[tableId];
        expect(table, isNotNull, reason: 'Loot table $tableId harus ada');
        expect(
          table!.entries.any((e) => e.itemId == 'boss_remnant'),
          isTrue,
          reason: '$tableId harus menjatuhkan boss_remnant',
        );
      }
    });

    test('kuota Weekly Shop lama dari Drift save tetap terbaca dan berlaku di sistem Barter baru', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DriftPlayerSaveRepository(db: db, config: config);

      final week1MondayMs = DateTime.utc(
        2026,
        11,
        16,
        10,
        0,
      ).millisecondsSinceEpoch;
      final eventService = EventShopService(
        catalog: config.eventShop!,
        items: config.items,
        equipmentFactory: EquipmentFactory(config.equipment),
      );
      final activeW1 = eventService.activeEntriesAt(
        week1MondayMs,
        offset: Duration.zero,
      );
      final epicEntry = activeW1.firstWhere(
        (e) => e.tier == EventItemTier.epic,
      );
      final periodKey = eventService.periodKeyAt(
        week1MondayMs,
        offset: Duration.zero,
      );

      final char = PlayerCharacter(
        config: config.progression,
        specializationConfig: config.specializations,
        skillCatalog: config.skills,
        progress: const PlayerProgress(level: 30, gold: 500000),
        initialSpecializationId: 'vanguard',
      );
      final inv = Inventory(definitions: config.items)
        ..add('boss_remnant', 50)
        ..add('aether_scrap', 500);

      // Simpan snapshot pemain yang sudah menghabiskan kuota 1/1 di Weekly Shop lama
      await repo.saveSnapshot(
        PlayerSaveSnapshot(
          character: char.toSnapshot(),
          inventory: inv.toSnapshot(),
          cycleProgress: const CycleProgress(
            ascensionRank: 1,
            highestAscensionRank: 1,
          ),
          dungeonProgresses: const {
            'ancient_crypt': DungeonProgressSnapshot(
              currentDungeonId: 'ancient_crypt',
              clearsCount: 1,
            ),
          },
          eventShopPurchases: [
            EventShopPurchaseRecord(
              entryId: epicEntry.id,
              periodKey: periodKey,
              purchasedCount: 1,
            ),
          ],
        ),
      );

      final loaded = await repo.loadSnapshot();
      expect(loaded, isNotNull);
      final loadedCounts = {
        for (final r in loaded!.eventShopPurchases)
          (r.entryId, r.periodKey): r.purchasedCount,
      };
      expect(loadedCounts[(epicEntry.id, periodKey)], 1);

      final currencies = CurrencyService(
        definitions: config.currencies,
        initialBalances: {kAetherShardCurrencyId: 100},
      );
      final ctx = ShopPlayerContext(
        playerLevel: 30,
        cycleProgress: loaded.cycleProgress,
        dungeonProgresses: loaded.dungeonProgresses,
        eventShopPurchases: loadedCounts,
      );

      final attempt = eventService.buy(
        entryId: epicEntry.id,
        effectiveNowMs: week1MondayMs,
        inventory: inv,
        currencyService: currencies,
        character: char,
        context: ctx,
        purchaseCounts: loadedCounts,
        timeZoneOffset: Duration.zero,
      );
      expect(attempt, isA<EventShopBuyLimitReached>());
      expect(currencies.balance(kAetherShardCurrencyId), 100);
      expect(char.gold, 500000);
    });
  });

  group('M15 Stage 4 — BlacksmithOverlay Salvage UI', () {
    testWidgets(
      'tab Bongkar menampilkan hasil scrap dan memanggil onSalvageEquipment',
      (tester) async {
        final char = PlayerCharacter(
          config: config.progression,
          specializationConfig: config.specializations,
          skillCatalog: config.skills,
          progress: const PlayerProgress(level: 10, gold: 1000),
          initialSpecializationId: 'vanguard',
        );
        final inv = Inventory(definitions: config.items);
        inv.addEquipment(
          const EquipmentInstance(
            id: 'eq_salvage_1',
            definitionId: 'rusty_sword',
            slot: EquipmentSlot.weapon,
            rarity: ItemRarity.common,
            rolledStats: EquipmentStats(atk: 4),
          ),
        );
        final views = InventoryViews(inventory: inv, character: char);

        String? salvagedId;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BlacksmithOverlay(
                snapshot: views.equipment,
                items: config.items,
                inventoryEntries: views.stacks,
                characterSnapshot: views.characterView,
                onEnhanceEquipment: (_) => const BlacksmithEnhanceResult(
                  status: BlacksmithEnhanceStatus.itemNotFound,
                ),
                onReforgeEquipment: (_) => const BlacksmithReforgeResult(
                  status: BlacksmithReforgeStatus.itemNotFound,
                ),
                onSalvageEquipment: (id) {
                  salvagedId = id;
                  final res = blacksmith.salvageEquipment(
                    inventory: inv,
                    instanceId: id,
                    loadout: char.loadout,
                  );
                  views.refresh();
                  return res;
                },
                onClose: () {},
              ),
            ),
          ),
        );

        await tester.tap(find.text('Bongkar'));
        await tester.pumpAndSettle();

        expect(find.text('+2 Aether Scrap'), findsOneWidget);
        await tester.tap(find.byKey(const Key('blacksmith_salvage_button')));
        await tester.pumpAndSettle();

        expect(salvagedId, 'eq_salvage_1');
        expect(inv.quantityOf('aether_scrap'), 2);
        expect(find.textContaining('Berhasil membongkar'), findsOneWidget);
      },
    );
  });
}
