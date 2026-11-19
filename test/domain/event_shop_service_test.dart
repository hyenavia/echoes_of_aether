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
import 'package:echoes_of_aether/domain/entities/clock_state.dart';
import 'package:echoes_of_aether/domain/entities/currency_config.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/event_shop_config.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/services/clock_guard.dart';
import 'package:echoes_of_aether/domain/services/currency_service.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/event_shop_service.dart';
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
  late EventShopService service;
  late Inventory inventory;
  late CurrencyService currencyService;
  late PlayerCharacter character;

  PlayerCharacter createCharacter({int gold = 0}) => PlayerCharacter(
    config: config.progression,
    specializationConfig: config.specializations,
    skillCatalog: config.skills,
    progress: PlayerProgress(level: 30, gold: gold),
    initialSpecializationId: 'vanguard',
  );

  final week1MondayMs = DateTime.utc(
    2026,
    11,
    16,
    10,
    0,
  ).millisecondsSinceEpoch;
  final week2MondayMs = DateTime.utc(
    2026,
    11,
    23,
    10,
    0,
  ).millisecondsSinceEpoch;

  ShopPlayerContext fullAccessContext({
    Map<(String, String), int> eventPurchases = const {},
    int ascensionRank = 1,
    int? highestAscensionRank,
    int ancientCryptClears = 1,
    int ancientCryptCycleRank = 0,
  }) {
    return ShopPlayerContext(
      playerLevel: 30,
      cycleProgress: CycleProgress(
        ascensionRank: ascensionRank,
        highestAscensionRank: highestAscensionRank ?? ascensionRank,
      ),
      dungeonProgresses: {
        'ancient_crypt': DungeonProgressSnapshot(
          currentDungeonId: 'ancient_crypt',
          clearsCount: ancientCryptClears,
          clearedInCycleRank: ancientCryptCycleRank,
        ),
      },
      eventShopPurchases: eventPurchases,
    );
  }

  setUp(() {
    config = _loadRealConfig();
    service = EventShopService(
      catalog: config.eventShop!,
      items: config.items,
      equipmentFactory: EquipmentFactory(config.equipment),
    );
    inventory = Inventory(definitions: config.items);
    currencyService = CurrencyService(definitions: config.currencies);
    character = createCharacter();
  });

  group('EventShopService — M13 Stage 3 & M15 Stage 4 Barter', () {
    test('seluruh sealed error (NotFound, NotInRotation, RequirementNotMet, InsufficientCurrency, InventoryFull, LimitReached) tidak memutasi saldo, tas, maupun hitungan', () {
      final active = service.activeEntriesAt(
        week1MondayMs,
        offset: Duration.zero,
      );
      expect(active, hasLength(2));
      final activeEpic = active.firstWhere((e) => e.tier == EventItemTier.epic);
      final activeLeg = active.firstWhere(
        (e) => e.tier == EventItemTier.legendary,
      );
      final inactiveEntry = config.eventShop!.pool.firstWhere(
        (e) => active.every((a) => a.id != e.id),
      );

      final purchaseCounts = <(String, String), int>{};
      character.addGold(activeEpic.goldPrice - 1);
      final initialGold = character.gold;

      // 1. NotFound
      final notFound = service.buy(
        entryId: 'event_unknown_entry',
        effectiveNowMs: week1MondayMs,
        inventory: inventory,
        currencyService: currencyService,
        character: character,
        context: fullAccessContext(),
        purchaseCounts: purchaseCounts,
        timeZoneOffset: Duration.zero,
      );
      expect(notFound, isA<EventShopBuyNotFound>());

      // 2. NotInRotation
      final notInRotation = service.buy(
        entryId: inactiveEntry.id,
        effectiveNowMs: week1MondayMs,
        inventory: inventory,
        currencyService: currencyService,
        character: character,
        context: fullAccessContext(),
        purchaseCounts: purchaseCounts,
        timeZoneOffset: Duration.zero,
      );
      expect(notInRotation, isA<EventShopBuyNotInRotation>());

      // 3. RequirementNotMet (ancient_crypt belum clear -> epic gagal; rank 0 -> legendary gagal)
      final lockedEpic = service.buy(
        entryId: activeEpic.id,
        effectiveNowMs: week1MondayMs,
        inventory: inventory,
        currencyService: currencyService,
        character: character,
        context: fullAccessContext(ancientCryptClears: 0, ascensionRank: 0),
        purchaseCounts: purchaseCounts,
        timeZoneOffset: Duration.zero,
      );
      expect(lockedEpic, isA<EventShopBuyRequirementNotMet>());

      final lockedLeg = service.buy(
        entryId: activeLeg.id,
        effectiveNowMs: week1MondayMs,
        inventory: inventory,
        currencyService: currencyService,
        character: character,
        context: fullAccessContext(ascensionRank: 0, highestAscensionRank: 0),
        purchaseCounts: purchaseCounts,
        timeZoneOffset: Duration.zero,
      );
      expect(lockedLeg, isA<EventShopBuyRequirementNotMet>());

      // 4. InsufficientCurrency (kurang 1 Gold)
      final poorGold = service.buy(
        entryId: activeEpic.id,
        effectiveNowMs: week1MondayMs,
        inventory: inventory,
        currencyService: currencyService,
        character: character,
        context: fullAccessContext(),
        purchaseCounts: purchaseCounts,
        timeZoneOffset: Duration.zero,
      );
      expect(
        poorGold,
        isA<EventShopBuyInsufficientCurrency>()
            .having((r) => r.currencyId, 'currencyId', 'gold')
            .having((r) => r.requiredAmount, 'required', activeEpic.goldPrice)
            .having(
              (r) => r.currentBalance,
              'balance',
              activeEpic.goldPrice - 1,
            ),
      );
      expect(character.gold, initialGold);
      expect(inventory.equipmentCount, 0);
      expect(purchaseCounts, isEmpty);

      // 4b. InsufficientCurrency (Gold cukup, Boss Remnant kurang)
      character.addGold(100000);
      final poorMat = service.buy(
        entryId: activeEpic.id,
        effectiveNowMs: week1MondayMs,
        inventory: inventory,
        currencyService: currencyService,
        character: character,
        context: fullAccessContext(),
        purchaseCounts: purchaseCounts,
        timeZoneOffset: Duration.zero,
      );
      expect(
        poorMat,
        isA<EventShopBuyInsufficientCurrency>().having(
          (r) => r.currencyId,
          'currencyId',
          'boss_remnant',
        ),
      );

      // 5. InventoryFull (Gold & Material cukup, tapi tas penuh 0 slot)
      final richGold = character.gold;
      final fullBag = Inventory(
        definitions: config.items,
        maxEquipmentCapacity: 0,
      );
      for (final mat in activeEpic.materialCosts.entries) {
        fullBag.add(mat.key, mat.value);
      }
      final invFull = service.buy(
        entryId: activeEpic.id,
        effectiveNowMs: week1MondayMs,
        inventory: fullBag,
        currencyService: currencyService,
        character: character,
        context: fullAccessContext(),
        purchaseCounts: purchaseCounts,
        timeZoneOffset: Duration.zero,
      );
      expect(invFull, isA<EventShopBuyInventoryFull>());
      expect(character.gold, richGold);
      expect(purchaseCounts, isEmpty);
    });

    test('barter dengan Gold & Material pas berhasil tanpa menyentuh Aether Shard, double-tap & beli ulang minggu sama diblokir', () {
      final activeW1 = service.activeEntriesAt(
        week1MondayMs,
        offset: Duration.zero,
      );
      final epicW1 = activeW1.firstWhere((e) => e.tier == EventItemTier.epic);
      final purchaseCounts = <(String, String), int>{};

      currencyService.grant(kAetherShardCurrencyId, 50, claimId: 'shard_safe');
      character.addGold(epicW1.goldPrice);
      for (final mat in epicW1.materialCosts.entries) {
        inventory.add(mat.key, mat.value);
      }

      // Beli pertama dengan barter pas
      final first = service.buy(
        entryId: epicW1.id,
        effectiveNowMs: week1MondayMs,
        inventory: inventory,
        currencyService: currencyService,
        character: character,
        context: fullAccessContext(),
        purchaseCounts: purchaseCounts,
        timeZoneOffset: Duration.zero,
        actionId: 'tap_1',
      );
      expect(first, isA<EventShopBuySuccess>());
      final ok = first as EventShopBuySuccess;
      expect(ok.currencySpent, 0);
      expect(ok.goldSpent, epicW1.goldPrice);
      expect(ok.remainingGold, 0);
      expect(currencyService.balance(kAetherShardCurrencyId), 50);
      expect(ok.newPurchaseCount, 1);
      expect(ok.purchasedEquipment, isNotNull);
      expect(ok.wasDuplicate, isFalse);
      expect(inventory.equipmentCount, 1);

      // Top up lagi untuk memastikan pemblokiran datang dari batas/idempotency, bukan saldo.
      character.addGold(500000);
      inventory.add('boss_remnant', 50);
      inventory.add('aether_scrap', 500);

      // Double-tap dengan actionId sama -> idempotent duplicate (goldSpent: 0).
      final dupAction = service.buy(
        entryId: epicW1.id,
        effectiveNowMs: week1MondayMs,
        inventory: inventory,
        currencyService: currencyService,
        character: character,
        context: fullAccessContext(eventPurchases: purchaseCounts),
        purchaseCounts: purchaseCounts,
        timeZoneOffset: Duration.zero,
        actionId: 'tap_1',
      );
      expect(
        dupAction,
        isA<EventShopBuySuccess>().having(
          (r) => r.wasDuplicate,
          'wasDuplicate',
          isTrue,
        ),
      );
      expect(character.gold, 500000);
      expect(inventory.equipmentCount, 1);

      // Tap kedua dengan actionId berbeda di minggu yang sama -> LimitReached.
      final secondInSameWeek = service.buy(
        entryId: epicW1.id,
        effectiveNowMs: week1MondayMs,
        inventory: inventory,
        currencyService: currencyService,
        character: character,
        context: fullAccessContext(eventPurchases: purchaseCounts),
        purchaseCounts: purchaseCounts,
        timeZoneOffset: Duration.zero,
        actionId: 'tap_2',
      );
      expect(secondInSameWeek, isA<EventShopBuyLimitReached>());
      expect(character.gold, 500000);
      expect(inventory.equipmentCount, 1);

      // Jam mundur via ClockGuard tidak membuka kembali minggu lama.
      const guard = ClockGuard();
      final reading = guard.resolve(
        current: ClockState(lastSeenAtMs: week1MondayMs + 3600000),
        rawNowMs: week1MondayMs - 10 * 24 * 3600 * 1000,
      );
      expect(reading.wentBack, isTrue);
      final afterBackwardClock = service.buy(
        entryId: epicW1.id,
        effectiveNowMs: reading.effectiveMs,
        inventory: inventory,
        currencyService: currencyService,
        character: character,
        context: fullAccessContext(eventPurchases: purchaseCounts),
        purchaseCounts: purchaseCounts,
        timeZoneOffset: Duration.zero,
        actionId: 'tap_back',
      );
      expect(afterBackwardClock, isA<EventShopBuyLimitReached>());

      // Minggu berikutnya (Senin berikut) merotasi entri berbeda & mengizinkan beli.
      final activeW2 = service.activeEntriesAt(
        week2MondayMs,
        offset: Duration.zero,
      );
      expect(
        activeW2.map((e) => e.id).toSet(),
        isNot(activeW1.map((e) => e.id).toSet()),
      );
      final epicW2 = activeW2.firstWhere((e) => e.tier == EventItemTier.epic);
      final nextWeekBuy = service.buy(
        entryId: epicW2.id,
        effectiveNowMs: week2MondayMs,
        inventory: inventory,
        currencyService: currencyService,
        character: character,
        context: fullAccessContext(eventPurchases: purchaseCounts),
        purchaseCounts: purchaseCounts,
        timeZoneOffset: Duration.zero,
        actionId: 'tap_w2',
      );
      expect(nextWeekBuy, isA<EventShopBuySuccess>());
      expect(inventory.equipmentCount, 2);
    });

    test('periode berbeda untuk entryId yang sama tetap memakai batas terpisah (entryId, periodKey)', () {
      final purchaseCounts = <(String, String), int>{};
      character.addGold(500000);
      inventory.add('boss_remnant', 50);
      inventory.add('aether_scrap', 500);

      final activeW1 = service.activeEntriesAt(
        week1MondayMs,
        offset: Duration.zero,
      );
      final targetEntry = activeW1.firstWhere(
        (e) => e.tier == EventItemTier.epic,
      );

      final r1 = service.buy(
        entryId: targetEntry.id,
        effectiveNowMs: week1MondayMs,
        inventory: inventory,
        currencyService: currencyService,
        character: character,
        context: fullAccessContext(),
        purchaseCounts: purchaseCounts,
        timeZoneOffset: Duration.zero,
      );
      expect(r1, isA<EventShopBuySuccess>());

      final r2SameWeek = service.buy(
        entryId: targetEntry.id,
        effectiveNowMs: week1MondayMs + 86400000,
        inventory: inventory,
        currencyService: currencyService,
        character: character,
        context: fullAccessContext(eventPurchases: purchaseCounts),
        purchaseCounts: purchaseCounts,
        timeZoneOffset: Duration.zero,
      );
      expect(r2SameWeek, isA<EventShopBuyLimitReached>());

      // Cari minggu di siklus berikutnya tempat entryId yang sama muncul kembali.
      const weekMs = 7 * 24 * 60 * 60 * 1000;
      var nextOccurrenceMs = week1MondayMs + 4 * weekMs;
      for (var offsetWeeks = 4; offsetWeeks <= 8; offsetWeeks++) {
        final candidateMs = week1MondayMs + offsetWeeks * weekMs;
        final entries = service.activeEntriesAt(
          candidateMs,
          offset: Duration.zero,
        );
        if (entries.any((e) => e.id == targetEntry.id)) {
          nextOccurrenceMs = candidateMs;
          break;
        }
      }

      final r3NextCycle = service.buy(
        entryId: targetEntry.id,
        effectiveNowMs: nextOccurrenceMs,
        inventory: inventory,
        currencyService: currencyService,
        character: character,
        context: fullAccessContext(eventPurchases: purchaseCounts),
        purchaseCounts: purchaseCounts,
        timeZoneOffset: Duration.zero,
      );
      expect(r3NextCycle, isA<EventShopBuySuccess>());
    });

    test('requirement seumur hidup: dungeon_cleared tetap lolos pasca-ascension dan min_ascension_rank membaca highestAscensionRank', () {
      final active = service.activeEntriesAt(
        week1MondayMs,
        offset: Duration.zero,
      );
      final epic = active.firstWhere((e) => e.tier == EventItemTier.epic);
      final leg = active.firstWhere((e) => e.tier == EventItemTier.legendary);

      // clearedInCycleRank == -1 tapi clearsCount == 1, dan ascensionRank turun ke 0 namun highestAscensionRank == 1.
      final ctx = fullAccessContext(
        ascensionRank: 0,
        highestAscensionRank: 1,
        ancientCryptClears: 1,
        ancientCryptCycleRank: -1,
      );

      expect(service.check(epic, ctx).isMet, isTrue);
      expect(service.check(leg, ctx).isMet, isTrue);
    });

    test('item event hasil pembelian memakai fixed_stats (bebas roll acak) dan ditolak oleh ShopService.sellEquipment/sellBatch', () {
      final active = service.activeEntriesAt(
        week1MondayMs,
        offset: Duration.zero,
      );
      final leg = active.firstWhere((e) => e.tier == EventItemTier.legendary);
      final expectedStats = config.items[leg.itemId]!.equipment!.baseStats;

      final invA = Inventory(definitions: config.items)
        ..add('boss_remnant', 10)
        ..add('aether_scrap', 100);
      final invB = Inventory(definitions: config.items)
        ..add('boss_remnant', 10)
        ..add('aether_scrap', 100);
      final currA = CurrencyService(definitions: config.currencies);
      final currB = CurrencyService(definitions: config.currencies);
      final charA = createCharacter(gold: 500000);
      final charB = createCharacter(gold: 500000);

      final resA = service.buy(
        entryId: leg.id,
        effectiveNowMs: week1MondayMs,
        inventory: invA,
        currencyService: currA,
        character: charA,
        context: fullAccessContext(),
        random: math.Random(1),
        timeZoneOffset: Duration.zero,
      ) as EventShopBuySuccess;
      final resB = service.buy(
        entryId: leg.id,
        effectiveNowMs: week1MondayMs,
        inventory: invB,
        currencyService: currB,
        character: charB,
        context: fullAccessContext(),
        random: math.Random(999),
        timeZoneOffset: Duration.zero,
      ) as EventShopBuySuccess;

      final eqA = resA.purchasedEquipment!;
      final eqB = resB.purchasedEquipment!;
      expect(eqA.rolledStats, expectedStats);
      expect(eqB.rolledStats, expectedStats);

      // Jalur jual shop biasa menolak item event dengan sellable == false.
      final character = PlayerCharacter(
        config: config.progression,
        specializationConfig: config.specializations,
        skillCatalog: config.skills,
        progress: const PlayerProgress(level: 30, gold: 0),
        initialSpecializationId: 'vanguard',
      );
      final shopService = ShopService(
        catalog: config.shop,
        items: config.items,
        equipmentFactory: EquipmentFactory(config.equipment),
      );

      final sellSingle = shopService.sellEquipment(
        instanceId: eqA.id,
        character: character,
        inventory: invA,
      );
      expect(sellSingle, isA<ShopSellNotSellable>());
      expect(invA.equipmentById(eqA.id), isNotNull);

      final sellBatch = shopService.sellBatch(
        equipmentInstanceIds: [eqA.id],
        materialQuantities: const {},
        character: character,
        inventory: invA,
      );
      expect(sellBatch, isA<ShopSellNotSellable>());
      expect(invA.equipmentById(eqA.id), isNotNull);
      expect(character.gold, 0);
    });
  });
}
