import 'dart:io';
import 'dart:math' as math;

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
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/shop_config.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/progression_service.dart';
import 'package:echoes_of_aether/domain/services/shop_service.dart';
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
    initialSpecializationId: 'vanguard',
  );
}

void main() {
  late GameConfig config;
  late ShopService service;

  setUp(() {
    config = _loadRealConfig();
    service = ShopService(
      catalog: config.shop,
      items: config.items,
      equipmentFactory: EquipmentFactory(config.equipment),
    );
  });

  group('ProgressionService.addGold & PlayerCharacter.addGold', () {
    test('menolak amount negatif dan menjepit gold ke kMaxGold', () {
      final progService = ProgressionService(config.progression);
      expect(
        () => progService.addGold(
          const PlayerProgress(level: 1, currentExp: 0, gold: 100),
          -1,
        ),
        throwsArgumentError,
      );

      final nearMax = PlayerProgress(
        level: 1,
        currentExp: 0,
        gold: ProgressionService.kMaxGold - 50,
      );
      final clamped = progService.addGold(nearMax, 200);
      expect(clamped.gold, ProgressionService.kMaxGold);

      final character = _createCharacter(config, gold: 25);
      final delta = character.addGold(15);
      expect(delta, 15);
      expect(character.gold, 40);
      expect(character.level, 1);
      expect(character.currentExp, 0);
    });
  });

  group('ShopService.buy — hasil sealed & atomisitas', () {
    test('gold tepat pas berhasil; gold kurang satu gagal tanpa mutasi', () {
      final entry = config.shop.byId('shop_rusty_sword')!;
      final invFullCheck = Inventory(definitions: config.items);

      // Kurang satu gold
      final poorChar = _createCharacter(config, gold: entry.price - 1);
      final purchases = <String, int>{};
      final failRes = service.buy(
        entryId: entry.id,
        character: poorChar,
        inventory: invFullCheck,
        context: ShopPlayerContext(playerLevel: 1, shopPurchases: purchases),
        random: math.Random(42),
        purchaseCounts: purchases,
      );
      expect(failRes, isA<ShopBuyInsufficientGold>());
      expect(poorChar.gold, entry.price - 1);
      expect(invFullCheck.equipmentCount, 0);
      expect(purchases, isEmpty);

      // Gold tepat pas
      final exactChar = _createCharacter(config, gold: entry.price);
      final okRes = service.buy(
        entryId: entry.id,
        character: exactChar,
        inventory: invFullCheck,
        context: ShopPlayerContext(playerLevel: 1, shopPurchases: purchases),
        random: math.Random(42),
        purchaseCounts: purchases,
      );
      expect(okRes, isA<ShopBuySuccess>());
      final success = okRes as ShopBuySuccess;
      expect(success.goldSpent, entry.price);
      expect(success.remainingGold, 0);
      expect(success.newPurchaseCount, 1);
      expect(success.purchasedEquipment, isNotNull);
      expect(success.purchasedEquipment!.definitionId, entry.itemId);
      expect(exactChar.gold, 0);
      expect(invFullCheck.equipmentCount, 1);
      expect(purchases[entry.id], 1);
    });

    test('tas penuh gagal tanpa mengurangi gold atau purchase count', () {
      final entry = config.shop.byId('shop_rusty_sword')!;
      final character = _createCharacter(config, gold: entry.price * 2);
      final inventory = Inventory(
        definitions: config.items,
        maxEquipmentCapacity: 1,
      );
      final filler = EquipmentFactory(config.equipment).create(
        instanceId: inventory.nextEquipmentId(),
        definition: config.items['rusty_sword']!,
        random: math.Random(1),
      );
      expect(inventory.addEquipment(filler), isTrue);

      final purchases = <String, int>{};
      final result = service.buy(
        entryId: entry.id,
        character: character,
        inventory: inventory,
        context: ShopPlayerContext(playerLevel: 1, shopPurchases: purchases),
        random: math.Random(2),
        purchaseCounts: purchases,
      );

      expect(result, isA<ShopBuyInventoryFull>());
      expect(character.gold, entry.price * 2);
      expect(inventory.equipmentCount, 1);
      expect(purchases, isEmpty);
    });

    test('ShopBuyNotFound saat entryId tidak ada tanpa mutasi', () {
      final character = _createCharacter(config, gold: 500);
      final inventory = Inventory(definitions: config.items);
      final result = service.buy(
        entryId: 'non_existent_entry',
        character: character,
        inventory: inventory,
        context: const ShopPlayerContext(playerLevel: 1),
        random: math.Random(3),
      );
      expect(result, isA<ShopBuyNotFound>());
      expect(character.gold, 500);
      expect(inventory.equipmentCount, 0);
    });

    test('ShopBuyLimitReached menegakkan purchase_limit tanpa mutasi', () {
      final limitedCatalog = ShopCatalog(
        entries: const [
          ShopEntry(
            id: 'limited_sword',
            itemId: 'rusty_sword',
            price: 15,
            purchaseLimit: 2,
          ),
        ],
        sell: config.shop.sell,
      );
      final limitedService = ShopService(
        catalog: limitedCatalog,
        items: config.items,
        equipmentFactory: EquipmentFactory(config.equipment),
      );
      final character = _createCharacter(config, gold: 100);
      final inventory = Inventory(definitions: config.items);
      final purchases = <String, int>{'limited_sword': 2};

      final result = limitedService.buy(
        entryId: 'limited_sword',
        character: character,
        inventory: inventory,
        context: ShopPlayerContext(playerLevel: 1, shopPurchases: purchases),
        random: math.Random(4),
        purchaseCounts: purchases,
      );

      expect(result, isA<ShopBuyLimitReached>());
      final reached = result as ShopBuyLimitReached;
      expect(reached.limit, 2);
      expect(reached.purchasedCount, 2);
      expect(character.gold, 100);
      expect(inventory.equipmentCount, 0);
    });

    test('requirement kombinasi Epic (min_level + dungeon_cleared lifetime) & Legendary (min_ascension_rank)', () {
      final epicEntry = config.shop.byId('shop_aether_blade')!;
      final legendaryEntry = config.shop.byId('shop_heart_of_aether')!;
      final character = _createCharacter(config, level: 25, gold: 5000000);
      final inventory = Inventory(definitions: config.items);

      // Epic: gagal level & dungeon_cleared
      final epicFailBoth = service.buy(
        entryId: epicEntry.id,
        character: character,
        inventory: inventory,
        context: const ShopPlayerContext(playerLevel: 10),
        random: math.Random(5),
      );
      expect(epicFailBoth, isA<ShopBuyRequirementNotMet>());
      expect(
        (epicFailBoth as ShopBuyRequirementNotMet).failedRequirements.length,
        2,
      );

      // Epic: level cukup tetapi dungeon belum pernah clear -> tetap gagal
      final epicFailDungeon = service.buy(
        entryId: epicEntry.id,
        character: character,
        inventory: inventory,
        context: const ShopPlayerContext(playerLevel: 25),
        random: math.Random(6),
      );
      expect(epicFailDungeon, isA<ShopBuyRequirementNotMet>());
      expect((epicFailDungeon as ShopBuyRequirementNotMet).failedRequirements, [
        isA<DungeonClearedRequirement>(),
      ]);

      // Epic: clearsCount > 0 (meski clearedInCycleRank == -1 pasca-Ascension) -> lulus!
      final epicPass = service.buy(
        entryId: epicEntry.id,
        character: character,
        inventory: inventory,
        context: const ShopPlayerContext(
          playerLevel: 25,
          dungeonProgresses: {
            'ancient_crypt': DungeonProgressSnapshot(
              currentDungeonId: 'ancient_crypt',
              clearsCount: 1,
              clearedInCycleRank: -1,
            ),
          },
        ),
        random: math.Random(7),
      );
      expect(epicPass, isA<ShopBuySuccess>());

      // Legendary: Rank 0 gagal
      final legFail = service.buy(
        entryId: legendaryEntry.id,
        character: character,
        inventory: inventory,
        context: const ShopPlayerContext(
          playerLevel: 49,
          cycleProgress: CycleProgress(ascensionRank: 0),
        ),
        random: math.Random(8),
      );
      expect(legFail, isA<ShopBuyRequirementNotMet>());
      expect((legFail as ShopBuyRequirementNotMet).failedRequirements, [
        isA<MinAscensionRankRequirement>(),
      ]);

      // Legendary: Rank Switcher aktif di 0 tapi highestAscensionRank == 1 -> lulus!
      final legPass = service.buy(
        entryId: legendaryEntry.id,
        character: character,
        inventory: inventory,
        context: const ShopPlayerContext(
          playerLevel: 49,
          cycleProgress: CycleProgress(
            ascensionRank: 0,
            highestAscensionRank: 1,
          ),
        ),
        random: math.Random(9),
      );
      expect(legPass, isA<ShopBuySuccess>());
    });

    test(
      'idempotensi actionId mencegah transaksi ganda akibat tap berulang',
      () {
        final entry = config.shop.byId('shop_rusty_sword')!;
        final character = _createCharacter(config, gold: entry.price * 2);
        final inventory = Inventory(definitions: config.items);
        final purchases = <String, int>{};

        final first = service.buy(
          entryId: entry.id,
          character: character,
          inventory: inventory,
          context: ShopPlayerContext(playerLevel: 1, shopPurchases: purchases),
          random: math.Random(10),
          purchaseCounts: purchases,
          actionId: 'buy-tap-1',
        );
        final second = service.buy(
          entryId: entry.id,
          character: character,
          inventory: inventory,
          context: ShopPlayerContext(playerLevel: 1, shopPurchases: purchases),
          random: math.Random(10),
          purchaseCounts: purchases,
          actionId: 'buy-tap-1',
        );

        expect(first, isA<ShopBuySuccess>());
        expect((first as ShopBuySuccess).wasDuplicate, isFalse);
        expect(second, isA<ShopBuySuccess>());
        expect((second as ShopBuySuccess).wasDuplicate, isTrue);
        expect(character.gold, entry.price * 2 - entry.price);
        expect(inventory.equipmentCount, 1);
        expect(purchases[entry.id], 1);
      },
    );
  });

  group(
    'ShopService.sell — anti-exploit, equipment terpasang, & bulk material',
    () {
      test('beli lalu jual setiap item shop selalu mengurangi gold bersih', () {
        for (final entry in config.shop.entries) {
          final character = _createCharacter(config, level: 99, gold: 1000000);
          final inventory = Inventory(definitions: config.items);
          final context = ShopPlayerContext(
            playerLevel: 99,
            cycleProgress: const CycleProgress(ascensionRank: 5),
            dungeonProgresses: {
              for (final d in config.dungeons.keys)
                d: DungeonProgressSnapshot(currentDungeonId: d, clearsCount: 1),
            },
          );
          final buyRes = service.buy(
            entryId: entry.id,
            character: character,
            inventory: inventory,
            context: context,
            random: math.Random(11),
          );
          expect(buyRes, isA<ShopBuySuccess>(), reason: 'entry=${entry.id}');
          final boughtEq = (buyRes as ShopBuySuccess).purchasedEquipment!;

          final sellRes = service.sellEquipment(
            instanceId: boughtEq.id,
            character: character,
            inventory: inventory,
          );
          expect(sellRes, isA<ShopSellSuccess>());
          final sold = sellRes as ShopSellSuccess;
          expect(
            sold.goldEarned,
            lessThanOrEqualTo((entry.price * 0.4).floor()),
          );
          expect(character.gold, lessThan(1000000));
          expect(inventory.equipmentCount, 0);
        }
      });

      test('equipment terpasang tidak dapat dijual (ShopSellNotSellable)', () {
        final character = _createCharacter(config, gold: 0);
        final inventory = Inventory(definitions: config.items);
        final eq = EquipmentFactory(config.equipment).create(
          instanceId: 'eq_equipped_1',
          definition: config.items['rusty_sword']!,
          random: math.Random(12),
        );
        character.loadout.equip(eq);

        final result = service.sellEquipment(
          instanceId: eq.id,
          character: character,
          inventory: inventory,
        );
        expect(result, isA<ShopSellNotSellable>());
        expect(character.gold, 0);
        expect(character.loadout.instanceIn(EquipmentSlot.weapon)?.id, eq.id);
      });

      test('sellMaterialBulk menolak material pada katalog default (non-sellable) dan berhasil bila diizinkan', () {
        final character = _createCharacter(config, gold: 10);
        final inventory = Inventory(definitions: config.items);
        final matDef = config.items.values.firstWhere(
          (d) => d.category == ItemCategory.material && d.sellValue > 0,
        );
        inventory.add(matDef.id, 10);

        // Pada katalog default, material tidak dapat dijual
        final blocked = service.sellMaterialBulk(
          itemId: matDef.id,
          quantity: 5,
          character: character,
          inventory: inventory,
        );
        expect(blocked, isA<ShopSellNotSellable>());
        expect(inventory.quantityOf(matDef.id), 10);
        expect(character.gold, 10);

        // Service dengan izin jual material
        final serviceWithMat = ShopService(
          catalog: ShopCatalog(
            entries: config.shop.entries,
            sell: const SellRules(
              sellableCategories: {
                ItemCategory.equipment,
                ItemCategory.material,
              },
            ),
          ),
          items: config.items,
          equipmentFactory: EquipmentFactory(config.equipment),
        );

        // Jual melebihi stok -> ShopSellNotSellable, stok tidak berubah
        final tooMany = serviceWithMat.sellMaterialBulk(
          itemId: matDef.id,
          quantity: 11,
          character: character,
          inventory: inventory,
        );
        expect(tooMany, isA<ShopSellNotSellable>());
        expect(inventory.quantityOf(matDef.id), 10);
        expect(character.gold, 10);

        // Jual 6 sekaligus lewat sell()
        final ok = serviceWithMat.sell(
          itemId: matDef.id,
          quantity: 6,
          character: character,
          inventory: inventory,
          actionId: 'bulk-1',
        );
        expect(ok, isA<ShopSellSuccess>());
        final sold = ok as ShopSellSuccess;
        expect(sold.quantitySold, 6);
        expect(sold.goldEarned, matDef.sellValue * 6);
        expect(inventory.quantityOf(matDef.id), 4);
        expect(character.gold, 10 + matDef.sellValue * 6);

        // Tap ulang actionId sama -> idempoten
        final dup = serviceWithMat.sell(
          itemId: matDef.id,
          quantity: 6,
          character: character,
          inventory: inventory,
          actionId: 'bulk-1',
        );
        expect((dup as ShopSellSuccess).wasDuplicate, isTrue);
        expect(inventory.quantityOf(matDef.id), 4);

        // Tidak ditemukan
        final missing = service.sellEquipment(
          instanceId: 'missing_eq',
          character: character,
          inventory: inventory,
        );
        expect(missing, isA<ShopSellNotFound>());
      });
    },
  );

  test('sellBatch menjual banyak equipment & material secara atomik dan idempoten', () {
    final character = _createCharacter(config, gold: 50);
    final inventory = Inventory(definitions: config.items);
    final swordDef = config.items['rusty_sword']!;
    final capDef = config.items['leather_cap']!;
    final matDef = config.items.values.firstWhere(
      (i) => i.category == ItemCategory.material && i.sellValue > 0,
    );

    final eq1 = EquipmentInstance(
      id: 'batch_eq_1',
      definitionId: swordDef.id,
      slot: swordDef.equipment!.slot,
      rarity: swordDef.rarity,
      rolledStats: swordDef.equipment!.baseStats,
    );
    final eq2 = EquipmentInstance(
      id: 'batch_eq_2',
      definitionId: capDef.id,
      slot: capDef.equipment!.slot,
      rarity: capDef.rarity,
      rolledStats: capDef.equipment!.baseStats,
    );
    final eqEquipped = EquipmentInstance(
      id: 'batch_eq_equipped',
      definitionId: swordDef.id,
      slot: swordDef.equipment!.slot,
      rarity: swordDef.rarity,
      rolledStats: swordDef.equipment!.baseStats,
    );
    inventory.addEquipment(eq1);
    inventory.addEquipment(eq2);
    inventory.addEquipment(eqEquipped);
    character.loadout.equip(eqEquipped);
    inventory.add(matDef.id, 5);

    // Gagal jika ada 1 item yang sedang dipakai -> tidak ada item yang terhapus
    final fail = service.sellBatch(
      equipmentInstanceIds: [eq1.id, eqEquipped.id],
      materialQuantities: {matDef.id: 3},
      character: character,
      inventory: inventory,
      actionId: 'batch-fail',
    );
    expect(fail, isA<ShopSellNotSellable>());
    expect(inventory.equipmentById(eq1.id), isNotNull);
    expect(inventory.quantityOf(matDef.id), 5);
    expect(character.gold, 50);

    // Sukses batch equipment pada katalog default
    final ok = service.sellBatch(
      equipmentInstanceIds: [eq1.id, eq2.id],
      materialQuantities: const {},
      character: character,
      inventory: inventory,
      actionId: 'batch-ok',
    );
    expect(ok, isA<ShopSellSuccess>());
    final sold = ok as ShopSellSuccess;
    final expectedGold =
        service.effectiveSellUnitPrice(swordDef) +
        service.effectiveSellUnitPrice(capDef);
    expect(sold.goldEarned, expectedGold);
    expect(sold.quantitySold, 2);
    expect(inventory.equipmentById(eq1.id), isNull);
    expect(inventory.equipmentById(eq2.id), isNull);
    expect(inventory.quantityOf(matDef.id), 5);
    expect(character.gold, 50 + expectedGold);

    // Katalog default menolak penjualan material pada batch
    final matBlocked = service.sellBatch(
      equipmentInstanceIds: const [],
      materialQuantities: {matDef.id: 3},
      character: character,
      inventory: inventory,
      actionId: 'batch-mat-blocked',
    );
    expect(matBlocked, isA<ShopSellNotSellable>());
    expect(inventory.quantityOf(matDef.id), 5);

    // Service yang mengizinkan material dapat menjual material dalam batch
    final serviceWithMat = ShopService(
      catalog: ShopCatalog(
        entries: config.shop.entries,
        sell: const SellRules(
          sellableCategories: {ItemCategory.equipment, ItemCategory.material},
        ),
      ),
      items: config.items,
      equipmentFactory: EquipmentFactory(config.equipment),
    );
    final okMat = serviceWithMat.sellBatch(
      equipmentInstanceIds: const [],
      materialQuantities: {matDef.id: 3},
      character: character,
      inventory: inventory,
      actionId: 'batch-mat-ok',
    );
    expect(okMat, isA<ShopSellSuccess>());
    expect(inventory.quantityOf(matDef.id), 2);

    // Idempoten untuk actionId yang sama
    final dup = service.sellBatch(
      equipmentInstanceIds: [eq1.id, eq2.id],
      materialQuantities: const {},
      character: character,
      inventory: inventory,
      actionId: 'batch-ok',
    );
    expect((dup as ShopSellSuccess).wasDuplicate, isTrue);
    expect(
      character.gold,
      50 + expectedGold + serviceWithMat.effectiveSellUnitPrice(matDef) * 3,
    );
  });

  test(
    'penjualan equipment favorit ditolak pada sellEquipment dan sellBatch',
    () {
      final config = _loadRealConfig();
      final character = _createCharacter(config, gold: 100);
      final inventory = Inventory(definitions: config.items);
      final service = ShopService(
        catalog: config.shop,
        items: config.items,
        equipmentFactory: EquipmentFactory(config.equipment),
      );

      final factory = EquipmentFactory(config.equipment);
      final swordDef = config.items['rusty_sword']!;
      final capDef = config.items['leather_cap']!;

      final favSword = factory
          .create(
            instanceId: 'fav_sword_1',
            definition: swordDef,
            random: math.Random(1),
          )
          .copyWith(isFavorite: true);
      final normalCap = factory.create(
        instanceId: 'normal_cap_1',
        definition: capDef,
        random: math.Random(2),
      );

      inventory.addEquipment(favSword);
      inventory.addEquipment(normalCap);

      // 1. sellEquipment menolak item favorit
      final singleRes = service.sellEquipment(
        instanceId: favSword.id,
        character: character,
        inventory: inventory,
        actionId: 'sell-fav-single',
      );
      expect(singleRes, isA<ShopSellNotSellable>());
      expect(
        (singleRes as ShopSellNotSellable).reason,
        'Equipment favorit tidak dapat dijual.',
      );
      expect(inventory.equipmentById(favSword.id), isNotNull);
      expect(character.gold, 100);

      // 2. sellBatch menolak bila ada item favorit di dalam list
      final batchRes = service.sellBatch(
        equipmentInstanceIds: [normalCap.id, favSword.id],
        materialQuantities: const {},
        character: character,
        inventory: inventory,
        actionId: 'sell-batch-with-fav',
      );
      expect(batchRes, isA<ShopSellNotSellable>());
      expect(
        (batchRes as ShopSellNotSellable).reason,
        'Equipment favorit tidak dapat dijual.',
      );
      // Transaksi atomik: normalCap juga tidak terjual karena batch dibatalkan
      expect(inventory.equipmentById(normalCap.id), isNotNull);
      expect(inventory.equipmentById(favSword.id), isNotNull);
      expect(character.gold, 100);

      // 3. Normal equipment tanpa favorit berhasil dijual
      final okRes = service.sellEquipment(
        instanceId: normalCap.id,
        character: character,
        inventory: inventory,
        actionId: 'sell-normal-ok',
      );
      expect(okRes, isA<ShopSellSuccess>());
      expect(inventory.equipmentById(normalCap.id), isNull);
      expect(character.gold, greaterThan(100));
    },
  );

  test('penjualan equipment favorit ditolak pada sellEquipment dan sellBatch', () {
    final config = _loadRealConfig();
    final character = _createCharacter(config, gold: 100);
    final inventory = Inventory(definitions: config.items);
    final service = ShopService(
      catalog: config.shop,
      items: config.items,
      equipmentFactory: EquipmentFactory(config.equipment),
    );

    final factory = EquipmentFactory(config.equipment);
    final swordDef = config.items['rusty_sword']!;
    final capDef = config.items['leather_cap']!;

    final favSword = factory
        .create(
          instanceId: 'fav_sword_1',
          definition: swordDef,
          random: math.Random(1),
        )
        .copyWith(isFavorite: true);
    final normalCap = factory.create(
      instanceId: 'normal_cap_1',
      definition: capDef,
      random: math.Random(2),
    );

    inventory.addEquipment(favSword);
    inventory.addEquipment(normalCap);

    // 1. sellEquipment menolak item favorit
    final singleRes = service.sellEquipment(
      instanceId: favSword.id,
      character: character,
      inventory: inventory,
      actionId: 'sell-fav-single',
    );
    expect(singleRes, isA<ShopSellNotSellable>());
    expect(
      (singleRes as ShopSellNotSellable).reason,
      'Equipment favorit tidak dapat dijual.',
    );
    expect(inventory.equipmentById(favSword.id), isNotNull);
    expect(character.gold, 100);

    // 2. sellBatch menolak bila ada item favorit di dalam list
    final batchRes = service.sellBatch(
      equipmentInstanceIds: [normalCap.id, favSword.id],
      materialQuantities: const {},
      character: character,
      inventory: inventory,
      actionId: 'sell-batch-with-fav',
    );
    expect(batchRes, isA<ShopSellNotSellable>());
    expect(
      (batchRes as ShopSellNotSellable).reason,
      'Equipment favorit tidak dapat dijual.',
    );
    // Transaksi atomik: normalCap juga tidak terjual karena batch dibatalkan
    expect(inventory.equipmentById(normalCap.id), isNotNull);
    expect(inventory.equipmentById(favSword.id), isNotNull);
    expect(character.gold, 100);

    // 3. Normal equipment tanpa favorit berhasil dijual
    final okRes = service.sellEquipment(
      instanceId: normalCap.id,
      character: character,
      inventory: inventory,
      actionId: 'sell-normal-ok',
    );
    expect(okRes, isA<ShopSellSuccess>());
    expect(inventory.equipmentById(normalCap.id), isNull);
    expect(character.gold, greaterThan(100));
  });
}
