import 'dart:io';

import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/difficulty_config.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/hero_ascension.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/services/ascension_service.dart';
import 'package:echoes_of_aether/domain/services/dungeon_progression_service.dart';
import 'package:echoes_of_aether/domain/services/hero_ascension_service.dart';
import 'package:echoes_of_aether/domain/services/progression_service.dart';
import 'package:flutter_test/flutter_test.dart';

HeroAscensionConfig _loadRealHeroAscensionConfig() {
  final source = File('assets/data/game_config.json').readAsStringSync();
  return const GameConfigParser().parseHeroAscension(source);
}

ProgressionConfig _loadRealProgressionConfig() {
  final source = File('assets/data/game_config.json').readAsStringSync();
  return const GameConfigParser().parseProgression(source);
}

DifficultyConfig _loadRealDifficultyConfig() {
  final source = File('assets/data/game_config.json').readAsStringSync();
  return const GameConfigParser().parseDifficulty(source);
}

const _testLayout = <String>['#####', '#...#', '#####'];

DungeonDefinition _makeDungeon({
  required String id,
  required int order,
  int recommendedLevel = 1,
  DungeonKind kind = DungeonKind.normal,
  String? unlockRequiresDungeonId,
  String? baseDungeonId,
}) {
  final roomId = '${id}_r1';
  return DungeonDefinition(
    id: id,
    name: id,
    biome: 'test',
    kind: kind,
    order: order,
    recommendedLevel: recommendedLevel,
    unlockRequiresDungeonId: unlockRequiresDungeonId,
    baseDungeonId: baseDungeonId,
    startRoomId: roomId,
    roomOrder: [roomId],
    rooms: {
      roomId: RoomDefinition(
        id: roomId,
        dungeonId: id,
        name: '$id Room',
        type: kind == DungeonKind.ascension ? RoomType.boss : RoomType.normal,
        mapRef: roomId,
        layout: _testLayout,
        entryPosition: const GridPoint(1, 1),
        exitPosition: const GridPoint(3, 1),
        completionCondition: const RoomCompletionCondition(
          type: RoomCompletionConditionType.reachExit,
        ),
        spawns: const [],
      ),
    },
  );
}

List<DungeonDefinition> _sampleDungeons() {
  return [
    _makeDungeon(id: 'd1_forest', order: 1, recommendedLevel: 1),
    _makeDungeon(
      id: 'd2_catacombs',
      order: 2,
      recommendedLevel: 12,
      unlockRequiresDungeonId: 'd1_forest',
    ),
    _makeDungeon(
      id: 'd3_core',
      order: 3,
      recommendedLevel: 25,
      unlockRequiresDungeonId: 'd2_catacombs',
    ),
    _makeDungeon(
      id: 'd4_spire',
      order: 4,
      recommendedLevel: 38,
      unlockRequiresDungeonId: 'd3_core',
    ),
    _makeDungeon(
      id: 'd5_sanctum',
      order: 5,
      recommendedLevel: 50,
      unlockRequiresDungeonId: 'd4_spire',
    ),
    _makeDungeon(
      id: 'd_ascension',
      order: 99,
      recommendedLevel: 50,
      kind: DungeonKind.ascension,
      unlockRequiresDungeonId: 'd5_sanctum',
      baseDungeonId: 'd5_sanctum',
    ),
  ];
}

void main() {
  late HeroAscensionConfig ascensionConfig;
  late ProgressionConfig progressionConfig;
  late HeroAscensionService ascensionService;

  setUpAll(() {
    ascensionConfig = _loadRealHeroAscensionConfig();
    progressionConfig = _loadRealProgressionConfig();
    ascensionService = HeroAscensionService(ascensionConfig);
  });

  group(
    'M16 Stage 2 — HeroAscensionService Validation & Atomic Transaction',
    () {
      test('canAscend menolak jika level karakter belum mencapai requiredPlayerLevel', () {
        const progress = PlayerProgress(
          level: 15,
          currentExp: 100,
          gold: 10000,
          ascensionPhase: 0,
        );
        final stacks = {'boss_remnant': 10};

        final result = ascensionService.canAscend(
          progress: progress,
          inventoryStacks: stacks,
        );

        expect(result.canAscend, isFalse);
        expect(result.failureReason, HeroAscensionFailureReason.levelTooLow);
        expect(result.nextPhase?.phase, 1);
        expect(result.nextPhase?.requiredPlayerLevel, 20);
      });

      test('canAscend menolak jika saldo gold tidak mencukupi', () {
        const progress = PlayerProgress(
          level: 20,
          currentExp: 250,
          gold: 200, // Butuh 500
          ascensionPhase: 0,
        );
        final stacks = {'boss_remnant': 3};

        final result = ascensionService.canAscend(
          progress: progress,
          inventoryStacks: stacks,
        );

        expect(result.canAscend, isFalse);
        expect(
          result.failureReason,
          HeroAscensionFailureReason.insufficientGold,
        );
        expect(result.missingGold, 300);
      });

      test('canAscend menolak jika material item tidak mencukupi', () {
        const progress = PlayerProgress(
          level: 40,
          currentExp: 500,
          gold: 2000,
          ascensionPhase: 1,
        );
        // Fase 2 butuh 4x boss_remnant dan 10x aether_scrap
        final stacks = {'boss_remnant': 2, 'aether_scrap': 5};

        final result = ascensionService.canAscend(
          progress: progress,
          inventoryStacks: stacks,
        );

        expect(result.canAscend, isFalse);
        expect(
          result.failureReason,
          HeroAscensionFailureReason.insufficientMaterials,
        );
        expect(result.missingItems['boss_remnant'], 2);
        expect(result.missingItems['aether_scrap'], 5);
      });

      test('canAscend menolak jika mata uang khusus tidak mencukupi (Fase A6 butuh Aether Shard)', () {
        const progress = PlayerProgress(
          level: 80,
          currentExp: 1000,
          gold: 20000,
          ascensionPhase: 5,
        );
        // Fase 6 butuh 5x void_essence, 50x aether_scrap, 100x aether_shard
        final stacks = {'void_essence': 5, 'aether_scrap': 50};
        final currencies = {'aether_shard': 40}; // Kurang 60

        final result = ascensionService.canAscend(
          progress: progress,
          inventoryStacks: stacks,
          currencies: currencies,
        );

        expect(result.canAscend, isFalse);
        expect(
          result.failureReason,
          HeroAscensionFailureReason.insufficientCurrencies,
        );
        expect(result.missingCurrencies['aether_shard'], 60);
      });

      test('canAscend menolak jika sudah mencapai maxPhase (A6)', () {
        const progress = PlayerProgress(
          level: 90,
          currentExp: 0,
          gold: 999999,
          ascensionPhase: 6,
        );
        final stacks = {'void_essence': 99, 'aether_scrap': 99};
        final currencies = {'aether_shard': 999};

        final result = ascensionService.canAscend(
          progress: progress,
          inventoryStacks: stacks,
          currencies: currencies,
        );

        expect(result.canAscend, isFalse);
        expect(
          result.failureReason,
          HeroAscensionFailureReason.maxPhaseReached,
        );
      });

      test(
        'ascendHero melakukan mutasi transaksi secara atomik dan idempoten',
        () {
          const progress = PlayerProgress(
            level: 20,
            currentExp: 250,
            gold: 1500,
            ascensionPhase: 0,
          );
          final stacks = {'boss_remnant': 5, 'healing_herb': 20};

          final result = ascensionService.ascendHero(
            progress: progress,
            inventoryStacks: stacks,
          );

          expect(result.succeeded, isTrue);
          expect(result.previousPhase, 0);
          expect(result.newPhase, 1);
          expect(result.updatedProgress?.ascensionPhase, 1);
          expect(result.updatedProgress?.gold, 1000); // 1500 - 500
          expect(result.updatedInventoryStacks['boss_remnant'], 2); // 5 - 3
          expect(result.updatedInventoryStacks['healing_herb'], 20); // Utuh
          expect(result.statBoost.hp, 50);
          expect(result.statBoost.atk, 8);
          expect(result.statBoost.def, 3);
          expect(result.hasGoldenAura, isFalse);

          // Memastikan input awal tidak termutasi (pure domain function)
          expect(progress.gold, 1500);
          expect(stacks['boss_remnant'], 5);
        },
      );

      test('ascendSnapshot memperbarui PlayerSaveSnapshot secara utuh', () {
        const snapshot = PlayerSaveSnapshot(
          character: PlayerCharacterSnapshot(
            progress: PlayerProgress(
              level: 40,
              currentExp: 300,
              gold: 5000,
              ascensionPhase: 1,
            ),
          ),
          inventory: InventorySnapshot(
            stacks: {'boss_remnant': 4, 'aether_scrap': 15, 'iron_ore': 8},
          ),
          currencies: {'aether_shard': 250},
        );

        final (result, updated) = ascensionService.ascendSnapshot(snapshot);

        expect(result.succeeded, isTrue);
        expect(result.newPhase, 2);
        expect(updated.character.progress.ascensionPhase, 2);
        expect(updated.character.progress.gold, 3500); // 5000 - 1500
        expect(
          updated.inventory.stacks.containsKey('boss_remnant'),
          isFalse,
        ); // Habis (4 - 4)
        expect(updated.inventory.stacks['aether_scrap'], 5); // 15 - 10
        expect(updated.inventory.stacks['iron_ore'], 8); // Utuh
        expect(updated.currencies['aether_shard'], 250);
      });
    },
  );

  group('M16 Stage 2 — ProgressionService & Level Capping per Phase', () {
    test('karakter A0 berhenti naik level saat menyentuh level cap 20 dan EXP terhenti di expToNext', () {
      final service = ProgressionService(progressionConfig, ascensionConfig);
      const start = PlayerProgress(level: 19, currentExp: 0, ascensionPhase: 0);

      // Berikan EXP berlimpah yang normalnya bisa menaikkan ke level 25
      final result = service.grant(start, exp: 50000);

      expect(result.progress.level, 20);
      expect(result.levelsGained, 1);
      final capExp = progressionConfig.expToNext(20);
      expect(
        result.progress.currentExp,
        capExp,
      ); // Ter-clamp pada 100% (Ascend Ready)
      expect(service.isAtPhaseCap(result.progress), isTrue);
      expect(service.isAscendReady(result.progress), isTrue);

      // Penambahan EXP selanjutnya saat masih di A0 tidak menambah level maupun EXP
      final extraResult = service.grant(result.progress, exp: 10000);
      expect(extraResult.progress.level, 20);
      expect(extraResult.levelsGained, 0);
      expect(extraResult.progress.currentExp, capExp);
    });

    test('setelah terobosan ke A1, karakter dapat naik level melampaui 20 menuju cap 40', () {
      final service = ProgressionService(progressionConfig, ascensionConfig);
      final capExp = progressionConfig.expToNext(20);
      // Karakter sudah A1 dengan sisa EXP cap dari Lv 20
      final afterAscension = PlayerProgress(
        level: 20,
        currentExp: capExp,
        ascensionPhase: 1,
      );

      expect(service.isAtPhaseCap(afterAscension), isFalse);

      final result = service.grant(afterAscension, exp: 1000);
      expect(result.progress.level, greaterThan(20));
      expect(result.progress.ascensionPhase, 1);
    });

    test('karakter mencapai level 90 (A6) dinyatakan maxLevel dan EXP disetel ke 0', () {
      final service = ProgressionService(progressionConfig, ascensionConfig);
      const nearMax = PlayerProgress(
        level: 89,
        currentExp: 0,
        ascensionPhase: 6,
      );

      final result = service.grant(nearMax, exp: 1000000);
      expect(result.progress.level, 90);
      expect(result.progress.currentExp, 0); // Hard Cap EXP = 0
    });
  });

  group('M16 Stage 2 — DerivedStatsCalculator & PlayerCharacter Breakthrough Stat Boost', () {
    test('bonus terobosan terakumulasi secara benar dari A0 hingga A6', () {
      expect(ascensionConfig.cumulativeStatBoostForPhase(0).hp, 0.0);

      final a1Boost = ascensionConfig.cumulativeStatBoostForPhase(1);
      expect(a1Boost.hp, 50.0);
      expect(a1Boost.atk, 8.0);
      expect(a1Boost.def, 3.0);

      final a2Boost = ascensionConfig.cumulativeStatBoostForPhase(2);
      expect(a2Boost.hp, 125.0); // 50 + 75
      expect(a2Boost.atk, 20.0); // 8 + 12
      expect(a2Boost.def, 8.0); // 3 + 5
      expect(a2Boost.critRate, 0.02);

      final a6Boost = ascensionConfig.cumulativeStatBoostForPhase(6);
      expect(a6Boost.hp, 875.0); // 50 + 75 + 100 + 150 + 200 + 300
      expect(a6Boost.atk, 115.0); // 8 + 12 + 15 + 20 + 25 + 35
      expect(a6Boost.def, 47.0); // 3 + 5 + 6 + 8 + 10 + 15
      expect(a6Boost.critRate, 0.02);
      expect(a6Boost.attackSpeed, 0.03);
      expect(a6Boost.critDamage, 0.05);
      expect(a6Boost.skillHaste, 0.05);
      expect(ascensionConfig.hasGoldenAuraForPhase(6), isTrue);
    });

    test('PlayerCharacter menerapkan bonus terobosan pada stats kalkulasi akhir secara deterministik', () {
      final character = PlayerCharacter(
        config: progressionConfig,
        heroAscensionConfig: ascensionConfig,
        progress: const PlayerProgress(level: 20, ascensionPhase: 0),
      );

      final statsA0 = character.stats;

      character.updateAscensionPhase(1);
      final statsA1 = character.stats;

      expect(statsA1.maxHp, statsA0.maxHp + 50);
      expect(statsA1.atk, statsA0.atk + 8);
      expect(statsA1.def, statsA0.def + 3);

      character.updateAscensionPhase(6);
      final statsA6 = character.stats;
      expect(statsA6.maxHp, statsA0.maxHp + 875);
      expect(statsA6.atk, statsA0.atk + 115);
      expect(statsA6.def, statsA0.def + 47);
      expect(statsA6.critRate, closeTo(statsA0.critRate + 0.02, 1e-5));
      expect(statsA6.attackSpeed, closeTo(statsA0.attackSpeed + 0.03, 1e-5));
      expect(statsA6.critDamage, closeTo(statsA0.critDamage + 0.05, 1e-5));
      expect(statsA6.skillHaste, closeTo(statsA0.skillHaste + 0.05, 1e-5));
    });
  });

  group('M16 Stage 2 — AscensionService & World Rank 5 Peak World Tier', () {
    test(
      'Ascension rank naik normal dari 0 ke 1 dengan reset siklus dungeon',
      () {
        const ascensionSvc = AscensionService();
        final dungeons = _sampleDungeons();
        const cycle0 = CycleProgress(
          ascensionRank: 0,
          lastNormalDungeonId: 'd5_sanctum',
        );
        final progresses = {
          for (final d in dungeons)
            d.id: DungeonProgressSnapshot(
              currentDungeonId: d.id,
              currentRoomId: '${d.id}_r1',
              clearsCount: 1,
              clearedInCycleRank: 0,
            ),
        };

        final result = ascensionSvc.complete(
          runId: 'run_r0_to_r1',
          dungeons: dungeons,
          cycleProgress: cycle0,
          dungeonProgresses: progresses,
        );

        expect(result.previousRank, 0);
        expect(result.newRank, 1);
        expect(result.isPeakWorldTier, isFalse);
        expect(result.cycleProgress.ascensionRank, 1);
        expect(
          result.cycleProgress.lastNormalDungeonId,
          'd1_forest',
        ); // Reset ke D1
        expect(
          result.dungeonProgresses['d1_forest']?.clearedInCycleRank,
          -1,
        ); // Reset
      },
    );

    test('Menamatkan Ascension Dungeon di Rank 5 mengunci pada Peak World Tier tanpa reset dungeon', () {
      const ascensionSvc = AscensionService();
      final dungeons = _sampleDungeons();
      const cycle5 = CycleProgress(
        ascensionRank: 5,
        lastNormalDungeonId: 'd5_sanctum',
      );
      final progresses = {
        for (final d in dungeons)
          d.id: DungeonProgressSnapshot(
            currentDungeonId: d.id,
            currentRoomId: '${d.id}_r1',
            clearsCount: 5,
            clearedInCycleRank: 5,
          ),
      };

      final result = ascensionSvc.complete(
        runId: 'peak_ascension_run',
        dungeons: dungeons,
        cycleProgress: cycle5,
        dungeonProgresses: progresses,
      );

      expect(result.previousRank, 5);
      expect(result.newRank, 5); // Tidak naik ke 6
      expect(result.isPeakWorldTier, isTrue);
      expect(result.isAetherAscendant, isTrue);
      expect(result.cycleProgress.ascensionRank, 5);
      expect(result.cycleProgress.isPeakWorldTier, isTrue);
      // PENTING: Dunia tidak di-reset! Seluruh dungeon tetap mempertahankan status clearedInCycleRank = 5
      expect(result.dungeonProgresses['d5_sanctum']?.clearedInCycleRank, 5);
      expect(result.cycleProgress.lastNormalDungeonId, 'd5_sanctum');
    });

    test('DungeonProgressionService menetapkan kPeakWorldRank = 5 dan menghitung recommended level sesuai cycleLevelStep', () {
      final difficultyConfig = _loadRealDifficultyConfig();
      final progSvc = DungeonProgressionService(difficultyConfig);
      expect(DungeonProgressionService.kPeakWorldRank, 5);
      expect(DungeonProgressionService.kMaxRank, 5);

      final dungeons = _sampleDungeons();
      final d5 = dungeons.firstWhere((d) => d.id == 'd5_sanctum');

      // Pada Rank 0: rec level 50
      expect(progSvc.recommendedLevel(d5, 0), 50);

      // Pada Rank 5 (Peak World Tier) dengan config aktif:
      final expectedRec = 50 + (5 * difficultyConfig.cycleLevelStep!);
      expect(progSvc.recommendedLevel(d5, 5), expectedRec);

      // Kalibrasi kurva step 8 menghasilkan level 90 pas pada Rank 5
      const tunedProgSvc = DungeonProgressionService(
        DifficultyConfig(cycleLevelStep: 8),
      );
      expect(tunedProgSvc.recommendedLevel(d5, 5), 90);
    });
  });
}
