import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/currency_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/services/bag_expansion_service.dart';
import 'package:echoes_of_aether/domain/services/currency_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const progression = ProgressionConfig(
    baseStats: CombatStats(maxHp: 100, atk: 12, def: 2),
    perLevel: LevelGrowth(hp: 15, atk: 2, def: 0.5),
  );

  const currencies = {
    kBagExpansionCurrencyId: CurrencyDefinition(
      id: kBagExpansionCurrencyId,
      name: 'Bag Expansion',
      maxAmount: 10,
    ),
  };

  group('BagExpansionService Domain Tests', () {
    const service = BagExpansionService();

    test('Konstanta kapasitas dan level dasar benar', () {
      expect(BagExpansionService.baseCapacity, 100);
      expect(BagExpansionService.slotsPerLevel, 20);
      expect(BagExpansionService.maxLevel, 10);
      expect(BagExpansionService.maxCapacity, 300);
      expect(BagExpansionService.upgradeCosts, hasLength(10));
      expect(BagExpansionService.upgradeCosts.first, 10000);
      expect(BagExpansionService.upgradeCosts.last, 1600000);
    });

    test('calculateCapacity menghitung kapasitas sesuai level dan clamp ke maxLevel', () {
      expect(service.calculateCapacity(0), 100);
      expect(service.calculateCapacity(1), 120);
      expect(service.calculateCapacity(5), 200);
      expect(service.calculateCapacity(10), 300);
      expect(service.calculateCapacity(15), 300); // clamped
      expect(service.calculateCapacity(-1), 100); // clamped
    });

    test(
      'getUpgradeCost mengembalikan biaya upgrade dan null bila maxLevel',
      () {
        expect(service.getUpgradeCost(0), 10000);
        expect(service.getUpgradeCost(1), 25000);
        expect(service.getUpgradeCost(9), 1600000);
        expect(service.getUpgradeCost(10), isNull);
        expect(service.getUpgradeCost(11), isNull);
        expect(service.getUpgradeCost(-1), isNull);
      },
    );

    test('upgrade gagal jika Gold tidak mencukupi', () {
      final character = PlayerCharacter(config: progression);
      character.addGold(5000); // Biaya lv 1 adalah 10.000
      final currencyService = CurrencyService(definitions: currencies);
      final inventory = Inventory(definitions: const {});

      final result = service.upgrade(
        character: character,
        currencyService: currencyService,
        inventory: inventory,
      );

      expect(result.isSuccess, isFalse);
      expect(result.status, BagExpansionUpgradeStatus.insufficientGold);
      expect(character.gold, 5000); // Gold tidak terpotong
      expect(currencyService.balance(kBagExpansionCurrencyId), 0);
      expect(inventory.maxEquipmentCapacity, isNull);
    });

    test('upgrade berhasil memotong Gold, menambah level, dan memperluas kapasitas', () {
      final character = PlayerCharacter(config: progression);
      character.addGold(50000);
      final currencyService = CurrencyService(definitions: currencies);
      final inventory = Inventory(
        definitions: const {},
        maxEquipmentCapacity: 100,
      );

      // Upgrade ke Level 1 (biaya: 10.000)
      final res1 = service.upgrade(
        character: character,
        currencyService: currencyService,
        inventory: inventory,
      );

      expect(res1.isSuccess, isTrue);
      expect(res1.status, BagExpansionUpgradeStatus.success);
      expect(res1.newLevel, 1);
      expect(res1.newCapacity, 120);
      expect(res1.goldSpent, 10000);
      expect(character.gold, 40000);
      expect(currencyService.balance(kBagExpansionCurrencyId), 1);
      expect(inventory.maxEquipmentCapacity, 120);

      // Upgrade ke Level 2 (biaya: 25.000)
      final res2 = service.upgrade(
        character: character,
        currencyService: currencyService,
        inventory: inventory,
      );

      expect(res2.isSuccess, isTrue);
      expect(res2.newLevel, 2);
      expect(res2.newCapacity, 140);
      expect(res2.goldSpent, 25000);
      expect(character.gold, 15000);
      expect(currencyService.balance(kBagExpansionCurrencyId), 2);
      expect(inventory.maxEquipmentCapacity, 140);
    });

    test('upgrade berhenti dan menolak ketika sudah mencapai maxLevel 10', () {
      final character = PlayerCharacter(config: progression);
      character.addGold(10000000); // 10 juta gold
      final currencyService = CurrencyService(
        definitions: currencies,
        initialBalances: {kBagExpansionCurrencyId: 10},
      );
      final inventory = Inventory(
        definitions: const {},
        maxEquipmentCapacity: 300,
      );

      final result = service.upgrade(
        character: character,
        currencyService: currencyService,
        inventory: inventory,
      );

      expect(result.isSuccess, isFalse);
      expect(result.status, BagExpansionUpgradeStatus.maxLevelReached);
      expect(result.newLevel, 10);
      expect(result.newCapacity, 300);
      expect(character.gold, 10000000); // Gold utuh
    });
  });
}
