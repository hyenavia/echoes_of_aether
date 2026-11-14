import 'dart:math' as math;

import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_reward.dart';
import 'package:echoes_of_aether/domain/entities/equipment_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/progression_service.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const endlessConfig = ProgressionConfig(
    maxLevel: null,
    expCurve: ExpCurveConfig.polynomial(base: 60.0, exponent: 1.8),
    baseStats: CombatStats(
      maxHp: 100,
      atk: 12,
      def: 2,
      attackSpeed: 1.5,
      critRate: 0.1,
      critDamage: 1.5,
      moveSpeed: 4.0,
      attackRange: 1.5,
    ),
    perLevel: LevelGrowth(hp: 15, atk: 2, def: 0.5),
  );

  const legacyCappedConfig = ProgressionConfig(
    maxLevel: 30,
    expCurve: ExpCurveConfig.exponential(base: 50.0, growth: 1.4),
    baseStats: CombatStats(
      maxHp: 100,
      atk: 12,
      def: 2,
      attackSpeed: 1.5,
      critRate: 0.1,
      critDamage: 1.5,
      moveSpeed: 4.0,
      attackRange: 1.5,
    ),
    perLevel: LevelGrowth(hp: 15, atk: 2, def: 0.5),
  );

  group('M8 Stage 2: Endless Leveling (ProgressionConfig)', () {
    test(
      'expToNext level 1..4 mengikuti kurva polinomial baseline 60 * L^1.8',
      () {
        // 60 * 1^1.8 = 60
        expect(endlessConfig.expToNext(1), 60);
        // 60 * 2^1.8 = 60 * 3.4822 = 209
        expect(endlessConfig.expToNext(2), 209);
        // 60 * 3^1.8 = 60 * 7.2246 = 433
        expect(endlessConfig.expToNext(3), 433);
        // 60 * 4^1.8 = 60 * 12.1257 = 728
        expect(endlessConfig.expToNext(4), 728);
      },
    );

    test('level 31, 100, 1000 dihitung benar dan tanpa overflow', () {
      final exp31 = endlessConfig.expToNext(31);
      final exp100 = endlessConfig.expToNext(100);
      final exp1000 = endlessConfig.expToNext(1000);

      expect(exp31, greaterThan(27000));
      expect(exp100, greaterThan(200000));
      expect(exp1000, greaterThan(15000000));
      expect(exp1000, lessThan(ProgressionConfig.kMaxExpToNext));

      // Stats linear per level tumbuh konsisten tanpa overflow
      final stats31 = endlessConfig.statsAt(31);
      expect(stats31.maxHp, 100 + 15 * 30);
      expect(stats31.atk, 12 + 2 * 30);
      expect(stats31.def, 2 + (0.5 * 30).round());

      final stats1000 = endlessConfig.statsAt(1000);
      expect(stats1000.maxHp, 100 + 15 * 999);
      expect(stats1000.atk, 12 + 2 * 999);
      expect(stats1000.def, 2 + (0.5 * 999).round());
    });

    test(
      'expToNext aman dari level non-positif dan di-clamp ke kMaxExpToNext',
      () {
        expect(endlessConfig.expToNext(0), 60);
        expect(endlessConfig.expToNext(-5), 60);

        // Level raksasa di-clamp ke kMaxExpToNext
        expect(
          endlessConfig.expToNext(ProgressionConfig.kTechnicalMaxLevel),
          lessThanOrEqualTo(ProgressionConfig.kMaxExpToNext),
        );
      },
    );
  });

  group('M8 Stage 2: ProgressionService Endless & Carry Forward', () {
    const service = ProgressionService(endlessConfig);

    test('karakter dapat melewati level 30 dan terus naik level', () {
      final start = PlayerProgress(level: 30, currentExp: 0, gold: 100);
      final expForLevel30 = endlessConfig.expToNext(30);

      final result = service.grant(start, exp: expForLevel30 + 50);
      expect(result.progress.level, 31);
      expect(result.progress.currentExp, 50);
      expect(result.levelsGained, 1);
    });

    test(
      'reward EXP sangat besar naik banyak level tanpa hang dan carry EXP aman',
      () {
        const start = PlayerProgress(level: 1, currentExp: 0, gold: 0);
        // Berikan 50.000 EXP
        final result = service.grant(start, exp: 50000);

        expect(result.levelsGained, greaterThan(10));
        expect(result.progress.level, 1 + result.levelsGained);
        expect(result.progress.currentExp, greaterThanOrEqualTo(0));
        expect(
          result.progress.currentExp,
          lessThan(endlessConfig.expToNext(result.progress.level)),
        );
      },
    );

    test('batas iterasi kMaxLevelUpIterations mencegah hang dan menyimpan sisa EXP', () {
      const start = PlayerProgress(level: 1, currentExp: 0, gold: 0);
      // Batasi iterasi max ke 5
      final result = service.grant(start, exp: 1000000, maxIterations: 5);

      expect(result.levelsGained, 5);
      expect(result.progress.level, 6);
      // Sisa EXP yang belum diproses tidak hilang!
      expect(result.progress.currentExp, greaterThan(0));

      // Panggilan berikutnya melanjutkan dari sisa EXP
      final nextResult = service.grant(
        result.progress,
        exp: 0,
        maxIterations: 5,
      );
      expect(nextResult.levelsGained, 5);
      expect(nextResult.progress.level, 11);
    });
  });

  group('M8 Stage 2: PlayerCharacter & Snapshot Compatibility', () {
    test('isMaxLevel bernilai false saat maxLevel == null', () {
      final hero = PlayerCharacter(config: endlessConfig);
      expect(hero.isMaxLevel, isFalse);

      hero.receiveReward(exp: 100000);
      expect(hero.isMaxLevel, isFalse);
      expect(hero.expToNext, greaterThan(0));
    });

    test(
      'save lama di level 30 dengan EXP 0 termuat dan bisa lanjut naik level',
      () {
        final hero = PlayerCharacter(config: endlessConfig);
        const oldSnapshot = PlayerCharacterSnapshot(
          progress: PlayerProgress(level: 30, currentExp: 0, gold: 500),
          specializationId: null,
          skillLevels: {},
          equipped: {},
        );

        hero.restoreSnapshot(oldSnapshot);
        expect(hero.level, 30);
        expect(hero.currentExp, 0);
        expect(hero.isMaxLevel, isFalse);

        // Beri reward EXP, hero harus naik ke level 31
        final expNeeded = endlessConfig.expToNext(30);
        hero.receiveReward(exp: expNeeded + 120);

        expect(hero.level, 31);
        expect(hero.currentExp, 120);
      },
    );

    test(
      'restoreSnapshot menghormati kTechnicalMaxLevel untuk data corrupt',
      () {
        final hero = PlayerCharacter(config: endlessConfig);
        const corruptSnapshot = PlayerCharacterSnapshot(
          progress: PlayerProgress(level: 5000000, currentExp: 100, gold: 0),
          specializationId: null,
          skillLevels: {},
          equipped: {},
        );

        hero.restoreSnapshot(corruptSnapshot);
        expect(hero.level, ProgressionConfig.kTechnicalMaxLevel);
        expect(hero.currentExp, 100);
      },
    );
  });

  group('M8 Stage 2: Regresi Mode Exponential + maxLevel', () {
    const legacyService = ProgressionService(legacyCappedConfig);

    test(
      'mode exponential + max_level: 30 berperilaku identik dengan legacy',
      () {
        expect(legacyCappedConfig.expToNext(1), 50);
        expect(legacyCappedConfig.expToNext(2), 70); // 50 * 1.4^1 = 70

        final hero = PlayerCharacter(config: legacyCappedConfig);
        hero.restoreSnapshot(
          const PlayerCharacterSnapshot(
            progress: PlayerProgress(level: 29, currentExp: 0, gold: 0),
            specializationId: null,
            skillLevels: {},
            equipped: {},
          ),
        );

        hero.receiveReward(exp: 10000000);
        expect(hero.level, 30);
        expect(hero.isMaxLevel, isTrue);
        expect(
          hero.currentExp,
          0,
        ); // Di-reset ke 0 pada level max saat maxLevel != null
        expect(hero.expToNext, 0);
      },
    );

    test(
      'ProgressionService me-reset currentExp = 0 saat mencapai maxLevel',
      () {
        const start = PlayerProgress(level: 29, currentExp: 0, gold: 0);
        final result = legacyService.grant(start, exp: 9999999);
        expect(result.progress.level, 30);
        expect(result.progress.currentExp, 0);
        expect(result.levelsGained, 1);
      },
    );
  });

  group('M8 Stage 2: Offline Pathway & Large Levels Gained', () {
    test('reward processor dan character mencatat levelsGained besar secara akurat di jalur offline', () {
      final hero = PlayerCharacter(config: endlessConfig);
      final inventory = Inventory(definitions: const {});
      final processor = RewardProcessor(
        character: hero,
        inventory: inventory,
        items: const {},
        lootTables: const {},
        equipmentFactory: const EquipmentFactory(EquipmentConfig()),
      );

      // Simulasikan akumulasi reward offline yang sangat besar (mis. 50.000 EXP)
      final grant = processor.processDungeonCompletion(
        eventId: 'dungeon_completion:offline_run_batch_test',
        reward: const DungeonCompletionReward(
          expReward: 50000,
          goldReward: 10000,
        ),
        random: math.Random(42),
      );

      expect(grant.levelsGained, greaterThan(10));
      expect(grant.levelsGained, hero.level - 1);
      expect(grant.expGranted, 50000);
      expect(grant.goldGranted, 10000);
      expect(hero.isMaxLevel, isFalse);
    });
  });
}
