import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/repositories/player_progress_repository.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/shop_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/src/balance_simulator.dart';

class _FailingShopRepository
    implements PlayerSaveRepository, ShopPurchaseRepository {
  @override
  Future<PlayerSaveSnapshot?> loadSnapshot() async => null;

  @override
  Future<void> saveSnapshot(PlayerSaveSnapshot snapshot) async {
    throw StateError('Simulated persistence failure');
  }

  @override
  Future<Map<String, int>> loadShopPurchases() async => const {};

  @override
  Future<void> saveShopTransaction({
    required PlayerProgress progress,
    required InventorySnapshot inventory,
    required Map<EquipmentSlot, EquipmentInstance> equipped,
    required Map<String, int> shopPurchases,
    String? actionId,
    int? updatedAtMs,
  }) async {
    throw StateError('Simulated shop persistence failure');
  }
}

void main() {
  late BalanceSimulator sim;

  setUpAll(() {
    sim = BalanceSimulator(BalanceSimulator.loadRealConfig());
  });

  group('M10 Stage 4 — Simulator Ekonomi & Anti-Exploit', () {
    test('gold/jam online & 8-jam Auto Farming + likuidasi loot tetap bounded dan wajar di Rank 0, 1, 5, 10', () {
      final rarePrice = sim.config.shop.byId('shop_guardian_amulet')!.price;
      final epicPrice = sim.config.shop.byId('shop_aether_blade')!.price;
      final legendaryPrice = sim.config.shop
          .byId('shop_heart_of_aether')!
          .price;

      for (final rank in [0, 1, 5, 10]) {
        final rows = sim.simulateEconomyForRank(
          cycleRank: rank,
          onlineSeedCount: 5,
        );
        final expectedDungeonCount = sim.config.dungeons.values
            .where((d) => d.isNormal && !d.isAscension)
            .length;
        expect(rows.length, expectedDungeonCount);
        for (final r in rows) {
          expect(r.onlineGoldPerHour.isFinite, isTrue);
          expect(r.onlineGoldPerHour, greaterThan(0));
          expect(r.offlineDirectGold8h, greaterThan(0));
          expect(r.offlineLootSellGold8h, greaterThanOrEqualTo(0));
          expect(r.offlineTotalGoldPerHour.isFinite, isTrue);

          // Likuidasi drop material+equipment dari Auto Farming 8 jam tidak boleh
          // melebihi 1x gold langsung dari dungeon (mencegah exploit sell_value).
          expect(
            r.offlineLootSellGold8h,
            lessThanOrEqualTo(r.offlineDirectGold8h),
            reason: '${r.dungeonId} rank=$rank',
          );

          // Waktu beli tidak mustahil (< 100 jam) dan di Rank 0 D1 tidak instan (< 0.05 jam untuk Epic/Leg).
          expect(r.hoursForPriceOnline(rarePrice), lessThan(100));
          expect(r.hoursForPriceOnline(epicPrice), lessThan(100));
          expect(r.hoursForPriceOnline(legendaryPrice), lessThan(100));
        }

        if (rank == 0) {
          final d1 = rows.first;
          expect(d1.hoursForPriceOnline(epicPrice), greaterThan(1.0));
          expect(d1.hoursForPriceOnline(legendaryPrice), greaterThan(5.0));
        }
      }
    });

    test('simulasi error persistensi di tengah transaksi menjaga DB Drift konsisten & coordinator tetap bersih', () async {
      final config = sim.config;
      final failingCoordinator = GameSessionCoordinator(
        config: config,
        repository: _FailingShopRepository(),
      );
      final character = PlayerCharacter(
        config: config.progression,
        specializationConfig: config.specializations,
        skillCatalog: config.skills,
        progress: const PlayerProgress(level: 10, currentExp: 0, gold: 5000),
        initialSpecializationId: 'vanguard',
      );
      final inventory = Inventory(definitions: config.items);

      await expectLater(
        failingCoordinator.saveShopTransaction(
          character: character,
          inventory: inventory,
          shopPurchases: const {'shop_rusty_sword': 1},
          actionId: 'fail-tx-1',
        ),
        throwsStateError,
      );

      // Uji rollback transaksi Drift saat error validasi terjadi (unknown item)
      final db = AppDatabase(NativeDatabase.memory());
      try {
        final repo = DriftPlayerSaveRepository(db: db, config: config);
        await repo.saveShopTransaction(
          progress: const PlayerProgress(level: 10, currentExp: 0, gold: 5000),
          inventory: inventory.toSnapshot(),
          equipped: const {},
          shopPurchases: const {'shop_rusty_sword': 1},
          actionId: 'baseline-1',
        );

        await expectLater(
          repo.saveShopTransaction(
            progress: const PlayerProgress(level: 10, currentExp: 0, gold: 100),
            inventory: const InventorySnapshot(stacks: {'invalid_item_id': 5}),
            equipped: const {},
            shopPurchases: const {'shop_rusty_sword': 99},
            actionId: 'bad-tx-1',
          ),
          throwsStateError,
        );

        final afterFail = await repo.loadSnapshot();
        expect(afterFail, isNotNull);
        expect(afterFail!.character.progress.gold, 5000);
        expect(afterFail.shopPurchases['shop_rusty_sword'], 1);
      } finally {
        await db.close();
      }
    });

    test(
      'beli-jual berulang, batas pembelian, dan tas penuh selalu konsisten',
      () {
        final config = sim.config;
        final shop = ShopService(
          catalog: config.shop,
          items: config.items,
          equipmentFactory: EquipmentFactory(config.equipment),
        );
        final character = PlayerCharacter(
          config: config.progression,
          specializationConfig: config.specializations,
          skillCatalog: config.skills,
          progress: const PlayerProgress(
            level: 50,
            currentExp: 0,
            gold: 2000000,
          ),
          initialSpecializationId: 'vanguard',
        );
        final inventory = Inventory(
          definitions: config.items,
          maxEquipmentCapacity: 2,
        );
        final purchases = <String, int>{};

        // Beli-jual berulang 5x pada entry shop -> gold selalu turun
        for (var i = 0; i < 5; i++) {
          final before = character.gold;
          final buyRes = shop.buy(
            entryId: 'shop_rusty_sword',
            character: character,
            inventory: inventory,
            context: ShopPlayerContext(
              playerLevel: 50,
              cycleProgress: const CycleProgress(ascensionRank: 1),
              shopPurchases: purchases,
            ),
            random: math.Random(i),
            purchaseCounts: purchases,
          );
          expect(buyRes, isA<ShopBuySuccess>());
          final bought = (buyRes as ShopBuySuccess).purchasedEquipment!;
          final sellRes = shop.sellEquipment(
            instanceId: bought.id,
            character: character,
            inventory: inventory,
          );
          expect(sellRes, isA<ShopSellSuccess>());
          expect(character.gold, lessThan(before));
        }

        // Isi penuh tas (2/2) -> pembelian ke-3 ditolak ShopBuyInventoryFull
        expect(
          shop.buy(
            entryId: 'shop_rusty_sword',
            character: character,
            inventory: inventory,
            context: ShopPlayerContext(
              playerLevel: 50,
              shopPurchases: purchases,
            ),
            random: math.Random(10),
          ),
          isA<ShopBuySuccess>(),
        );
        expect(
          shop.buy(
            entryId: 'shop_rusty_sword',
            character: character,
            inventory: inventory,
            context: ShopPlayerContext(
              playerLevel: 50,
              shopPurchases: purchases,
            ),
            random: math.Random(11),
          ),
          isA<ShopBuySuccess>(),
        );
        final goldBeforeFull = character.gold;
        final fullRes = shop.buy(
          entryId: 'shop_rusty_sword',
          character: character,
          inventory: inventory,
          context: ShopPlayerContext(playerLevel: 50, shopPurchases: purchases),
          random: math.Random(12),
        );
        expect(fullRes, isA<ShopBuyInventoryFull>());
        expect(character.gold, goldBeforeFull);
        expect(inventory.equipmentCount, 2);
      },
    );
  });
}
