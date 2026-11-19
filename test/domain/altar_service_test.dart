import 'dart:math' as math;

import 'package:echoes_of_aether/domain/entities/altar_blessing.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/currency_config.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_reward.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/equipment_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/services/altar_service.dart';
import 'package:echoes_of_aether/domain/services/currency_service.dart';
import 'package:echoes_of_aether/domain/services/derived_stats_calculator.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AltarBlessingDefinition', () {
    test(
      'biaya upgrade bertingkat dan mengembalikan null jika sudah maxLevel',
      () {
        final might =
            AltarBlessingDefinition.defaults[AltarBlessingType.might]!;
        expect(might.upgradeCost(0), 10000); // 0 -> 1: 10k
        expect(might.upgradeCost(1), 25000); // 1 -> 2: 25k
        expect(might.upgradeCost(19), 125000000); // 19 -> 20: 125M
        expect(might.upgradeCost(20), isNull); // Max level
        expect(might.upgradeCost(-1), isNull);
      },
    );

    test('perhitungan stat bonus per jenis berkah', () {
      final might = AltarBlessingDefinition.defaults[AltarBlessingType.might]!;
      final vitality =
          AltarBlessingDefinition.defaults[AltarBlessingType.vitality]!;
      final aegis = AltarBlessingDefinition.defaults[AltarBlessingType.aegis]!;
      final fortune =
          AltarBlessingDefinition.defaults[AltarBlessingType.fortune]!;

      // Might: +2 ATK per level
      expect(might.statBonusAt(0), EquipmentStats.zero);
      expect(might.statBonusAt(5).atk, 10.0);
      expect(might.statBonusAt(20).atk, 40.0);

      // Vitality: +20 HP per level
      expect(vitality.statBonusAt(5).hp, 100.0);
      expect(vitality.statBonusAt(20).hp, 400.0);

      // Aegis: +2 DEF per level
      expect(aegis.statBonusAt(5).def, 10.0);
      expect(aegis.statBonusAt(20).def, 40.0);

      // Fortune: tidak memberikan stat combat
      expect(fortune.statBonusAt(10), EquipmentStats.zero);
      expect(fortune.goldBonusPercentAt(10), 0.10); // +10%
    });
  });

  group('AltarService', () {
    late AltarService altarService;
    late CurrencyService currencyService;
    late PlayerCharacter character;

    final baseConfig = ProgressionConfig(
      baseStats: const CombatStats(
        maxHp: 100,
        atk: 10,
        def: 5,
        attackSpeed: 1.0,
        critRate: 0.05,
        critDamage: 1.5,
        moveSpeed: 3.0,
        attackRange: 1.5,
      ),
      perLevel: const LevelGrowth(hp: 10, atk: 2, def: 1),
    );

    setUp(() {
      altarService = const AltarService();
      currencyService = CurrencyService(
        definitions: CurrencyDefinition.defaults,
      );
      character = PlayerCharacter(
        config: baseConfig,
        progress: const PlayerProgress(level: 1, gold: 1000000), // 1 Juta gold
      );
    });

    test('getBlessingLevel membaca level dari saldo mata uang', () {
      expect(altarService.getBlessingLevel(AltarBlessingType.might, {}), 0);
      expect(
        altarService.getBlessingLevel(AltarBlessingType.might, {
          'altar_might': 3,
        }),
        3,
      );
      expect(
        altarService.getBlessingLevel(AltarBlessingType.might, {
          'altar_might': 25,
        }),
        20,
      ); // Clamped
    });

    test(
      'getAltarStatBonus mengakumulasi stat dari seluruh blessing aktif',
      () {
        final balances = {
          'altar_might': 5, // 5 * 2 = 10 ATK
          'altar_vitality': 3, // 3 * 20 = 60 HP
          'altar_aegis': 2, // 2 * 2 = 4 DEF
          'altar_fortune': 10, // 0 stat
        };
        final bonus = altarService.getAltarStatBonus(balances);
        expect(bonus.atk, 10.0);
        expect(bonus.hp, 60.0);
        expect(bonus.def, 4.0);
      },
    );

    test('getGoldBonusPercent mengembalikan multiplier drop gold fortune', () {
      expect(altarService.getGoldBonusPercent({}), 0.0);
      expect(altarService.getGoldBonusPercent({'altar_fortune': 7}), 0.07);
    });

    test('upgradeBlessing sukses memotong gold, menaikkan level, dan mengupdate stat karakter', () {
      final initialAtk = character.stats.atk;
      final initialGold = character.gold;

      final result = altarService.upgradeBlessing(
        character: character,
        currencyService: currencyService,
        type: AltarBlessingType.might,
      );

      expect(result.isSuccess, isTrue);
      expect(result.status, AltarUpgradeStatus.success);
      expect(result.newLevel, 1);
      expect(result.goldSpent, 10000);
      expect(result.remainingGold, initialGold - 10000);
      expect(character.gold, initialGold - 10000);
      expect(currencyService.balance('altar_might'), 1);

      // Stat tempur karakter langsung bertambah (+2 ATK)
      expect(character.stats.atk, initialAtk + 2);
    });

    test(
      'upgradeBlessing bertingkat membutuhkan gold yang semakin meningkat',
      () {
        // Upgrade ke level 1 (10,000)
        final r1 = altarService.upgradeBlessing(
          character: character,
          currencyService: currencyService,
          type: AltarBlessingType.might,
        );
        expect(r1.newLevel, 1);
        expect(r1.goldSpent, 10000);

        // Upgrade ke level 2 (25,000)
        final r2 = altarService.upgradeBlessing(
          character: character,
          currencyService: currencyService,
          type: AltarBlessingType.might,
        );
        expect(r2.newLevel, 2);
        expect(r2.goldSpent, 25000);

        // Upgrade ke level 3 (50,000)
        final r3 = altarService.upgradeBlessing(
          character: character,
          currencyService: currencyService,
          type: AltarBlessingType.might,
        );
        expect(r3.newLevel, 3);
        expect(r3.goldSpent, 50000);

        expect(character.stats.atk, 10 + 6); // Base 10 + 6 (level 3 might)
        expect(currencyService.balance('altar_might'), 3);
      },
    );

    test('upgradeBlessing gagal jika gold tidak mencukupi', () {
      final poorCharacter = PlayerCharacter(
        config: baseConfig,
        progress: const PlayerProgress(level: 1, gold: 5000), // Butuh 10k
      );

      final result = altarService.upgradeBlessing(
        character: poorCharacter,
        currencyService: currencyService,
        type: AltarBlessingType.might,
      );

      expect(result.isSuccess, isFalse);
      expect(result.status, AltarUpgradeStatus.insufficientGold);
      expect(result.newLevel, 0);
      expect(result.goldSpent, 0);
      expect(poorCharacter.gold, 5000);
      expect(currencyService.balance('altar_might'), 0);
    });

    test('upgradeBlessing gagal jika sudah mencapai level maksimum (20)', () {
      // Set balance currencyService ke 20
      currencyService = CurrencyService(
        definitions: CurrencyDefinition.defaults,
        initialBalances: {'altar_might': 20},
      );
      final richCharacter = PlayerCharacter(
        config: baseConfig,
        progress: const PlayerProgress(level: 1, gold: 999999999),
      );

      final result = altarService.upgradeBlessing(
        character: richCharacter,
        currencyService: currencyService,
        type: AltarBlessingType.might,
      );

      expect(result.isSuccess, isFalse);
      expect(result.status, AltarUpgradeStatus.maxLevelReached);
      expect(result.newLevel, 20);
      expect(result.goldSpent, 0);
      expect(currencyService.balance('altar_might'), 20);
    });
  });

  group('DerivedStatsCalculator & Altar Integration', () {
    test('DerivedStatsCalculator menyertakan altarBonus secara aditif dengan equipment dan passive', () {
      const calculator = DerivedStatsCalculator();
      const baseStats = CombatStats(maxHp: 100, atk: 10, def: 5);

      final stats = calculator.calculate(
        baseStats: baseStats,
        equipmentBonus: const EquipmentStats(atk: 5, hp: 50),
        altarBonus: const EquipmentStats(atk: 10, def: 8),
      );

      expect(stats.atk, 25); // 10 + 5 + 10
      expect(stats.maxHp, 150); // 100 + 50
      expect(stats.def, 13); // 5 + 8
    });
  });

  group('RewardProcessor & Fortune Blessing Integration', () {
    late PlayerCharacter character;
    late Inventory inventory;
    late RewardProcessor rewardProcessor;

    setUp(() {
      character = PlayerCharacter(
        config: const ProgressionConfig(
          baseStats: CombatStats(maxHp: 100, atk: 10, def: 5),
          perLevel: LevelGrowth(hp: 10, atk: 2, def: 1),
        ),
        progress: const PlayerProgress(level: 1, gold: 0),
      );
      inventory = Inventory(definitions: const {});
      rewardProcessor = RewardProcessor(
        character: character,
        inventory: inventory,
        items: const {},
        lootTables: const {},
        equipmentFactory: const EquipmentFactory(EquipmentConfig()),
        goldMultiplier: 1.10, // +10% dari Fortune Lv 10
      );
    });

    test('Enemy defeated reward diskalakan dengan goldMultiplier', () {
      const enemy = EnemyDefinition(
        id: 'test_enemy',
        name: 'Test Enemy',
        level: 1,
        stats: CombatStats(maxHp: 50, atk: 5, def: 2),
        goldReward: 100,
        expReward: 50,
      );

      final reward = rewardProcessor.processEnemyDefeated(
        eventId: 'kill_1',
        definition: enemy,
        random: math.Random(42),
      );

      expect(reward.alreadyClaimed, isFalse);
      // 100 * 1.10 = 110 gold
      expect(reward.goldGranted, 110);
      expect(character.gold, 110);
    });

    test('Dungeon completion reward diskalakan dengan goldMultiplier', () {
      const completionReward = DungeonCompletionReward(
        expReward: 200,
        goldReward: 500,
      );

      final reward = rewardProcessor.processDungeonCompletion(
        eventId: 'clear_1',
        reward: completionReward,
        random: math.Random(42),
      );

      expect(reward.alreadyClaimed, isFalse);
      // 500 * 1.10 = 550 gold
      expect(reward.goldGranted, 550);
      expect(character.gold, 550);
    });
  });
}
