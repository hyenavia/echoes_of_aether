import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
import 'package:echoes_of_aether/data/database/app_database.dart'
    hide ClockState;
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/currency_config.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/entities/shop_config.dart';
import 'package:echoes_of_aether/domain/services/currency_service.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/game_clock.dart';
import 'package:echoes_of_aether/domain/services/shop_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedClock implements GameClock {
  const _FixedClock(this.nowMs);
  @override
  final int nowMs;
}

GameConfig _currencyTestConfig() {
  return GameConfig(
    monsters: const {},
    revive: const ReviveConfig(),
    progression: const ProgressionConfig(
      baseStats: CombatStats(maxHp: 100, atk: 12, def: 2),
      perLevel: LevelGrowth(hp: 15, atk: 2, def: 0.5),
    ),
    items: const {
      'forest_herb': ItemDefinition(
        id: 'forest_herb',
        name: 'Forest Herb',
        category: ItemCategory.material,
        rarity: ItemRarity.common,
        sellValue: 5,
      ),
    },
    lootTables: const {},
    currencies: CurrencyDefinition.defaults,
    shop: ShopCatalog(
      entries: const [
        ShopEntry(id: 'buy_herb', itemId: 'forest_herb', price: 20),
      ],
    ),
  );
}

void main() {
  group('Currency persistence & gold/shop preservation', () {
    test('saldo currency dan claimId dipersistenkan serta dipulihkan lewat snapshot/coordinator', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final config = _currencyTestConfig();
      const clock = _FixedClock(1763251200000);
      final repo = DriftPlayerSaveRepository(
        db: db,
        config: config,
        clock: clock,
      );
      final coordinator = GameSessionCoordinator(
        repository: repo,
        config: config,
        clock: clock,
      );

      final firstBoot = await coordinator.loadAndProcessOffline();
      expect(firstBoot.currencies, isEmpty);

      final currencyService = CurrencyService(
        definitions: config.currencies,
        initialBalances: firstBoot.currencies,
        claimedIds: firstBoot.rewardProcessor.claimedEventIds,
      );
      final granted = currencyService.grant(
        kAetherShardCurrencyId,
        120,
        claimId: 'bossquest:daily_boss:2026-11-16',
      );
      expect(granted.isSuccess, isTrue);

      await coordinator.saveFromRuntime(
        character: firstBoot.character,
        inventory: firstBoot.inventory,
        dungeon: firstBoot.dungeon,
        dungeonProgresses: firstBoot.dungeonProgresses,
        cycleProgress: firstBoot.cycleProgress,
        rewardProcessor: firstBoot.rewardProcessor,
        autoSkillEnabled: firstBoot.session.autoSkillEnabled,
        lastOfflineClaimAtMs: firstBoot.session.lastOfflineClaimAtMs,
        currencyService: currencyService,
      );

      // Pastikan saveCycleProgress & saveShopTransaction tidak menghapus currencies.
      await coordinator.saveCycleProgress(
        const CycleProgress(ascensionRank: 1, highestAscensionRank: 1),
      );

      // Pastikan transaksi gold & shop lama tetap bekerja normal.
      firstBoot.character.addGold(100);
      final shopService = ShopService(
        catalog: config.shop,
        items: config.items,
        equipmentFactory: EquipmentFactory(config.equipment),
      );
      final purchaseCounts = <String, int>{};
      final buyResult = shopService.buy(
        entryId: 'buy_herb',
        character: firstBoot.character,
        inventory: firstBoot.inventory,
        context: const ShopPlayerContext(playerLevel: 1),
        random: math.Random(1),
        purchaseCounts: purchaseCounts,
        actionId: 'buy_1',
      );
      expect(buyResult, isA<ShopBuySuccess>());
      expect(firstBoot.character.gold, 80);
      await coordinator.saveShopTransaction(
        character: firstBoot.character,
        inventory: firstBoot.inventory,
        shopPurchases: purchaseCounts,
        actionId: 'buy_1',
      );

      // Restart coordinator & verifikasi restore penuh.
      final coordinator2 = GameSessionCoordinator(
        repository: repo,
        config: config,
        clock: clock,
      );
      final reboot = await coordinator2.loadAndProcessOffline();
      expect(reboot.currencies[kAetherShardCurrencyId], 120);
      expect(reboot.character.gold, 80);
      expect(reboot.inventory.quantityOf('forest_herb'), 1);

      final restoredCurrency = CurrencyService(
        definitions: config.currencies,
        initialBalances: reboot.currencies,
        claimedIds: reboot.rewardProcessor.claimedEventIds,
      );
      final duplicate = restoredCurrency.grant(
        kAetherShardCurrencyId,
        120,
        claimId: 'bossquest:daily_boss:2026-11-16',
      );
      expect(duplicate.alreadyClaimed, isTrue);
      expect(restoredCurrency.balance(kAetherShardCurrencyId), 120);

      // Spend seluruh saldo -> pastikan 0 terpersistenkan dan tidak kembali 120.
      final spent = restoredCurrency.spend(kAetherShardCurrencyId, 120);
      expect(spent.isSuccess, isTrue);
      expect(restoredCurrency.balance(kAetherShardCurrencyId), 0);

      await coordinator2.saveFromRuntime(
        character: reboot.character,
        inventory: reboot.inventory,
        dungeon: reboot.dungeon,
        dungeonProgresses: reboot.dungeonProgresses,
        cycleProgress: reboot.cycleProgress,
        rewardProcessor: reboot.rewardProcessor,
        autoSkillEnabled: reboot.session.autoSkillEnabled,
        lastOfflineClaimAtMs: reboot.session.lastOfflineClaimAtMs,
        currencyService: restoredCurrency,
      );

      final afterSpend = await repo.loadSnapshot();
      expect(afterSpend?.currencies[kAetherShardCurrencyId], isNull);
    });

    test(
      'saveSnapshot langsung menolak currency negatif atau tidak dikenal',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final config = _currencyTestConfig();
        final repo = DriftPlayerSaveRepository(
          db: db,
          config: config,
          clock: const _FixedClock(1000),
        );
        final char = PlayerCharacter(
          config: config.progression,
          progress: const PlayerProgress(level: 1, gold: 10),
        );
        final inv = Inventory(definitions: config.items);

        await expectLater(
          repo.saveSnapshot(
            PlayerSaveSnapshot(
              character: char.toSnapshot(),
              inventory: inv.toSnapshot(),
              currencies: const {kAetherShardCurrencyId: -5},
            ),
          ),
          throwsStateError,
        );

        await expectLater(
          repo.saveSnapshot(
            PlayerSaveSnapshot(
              character: char.toSnapshot(),
              inventory: inv.toSnapshot(),
              currencies: const {'unknown_coin': 10},
            ),
          ),
          throwsStateError,
        );
      },
    );
  });
}
