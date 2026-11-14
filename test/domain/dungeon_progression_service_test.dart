import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/difficulty_config.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/services/difficulty_service.dart';
import 'package:echoes_of_aether/domain/services/dungeon_progression_service.dart';
import 'package:flutter_test/flutter_test.dart';

DungeonDefinition _makeDungeon({
  required String id,
  required int order,
  DungeonKind kind = DungeonKind.normal,
  int recommendedLevel = 1,
  String? unlockRequires,
  String? baseDungeonId,
}) => DungeonDefinition(
  id: id,
  name: id,
  biome: 'test',
  startRoomId: 'r1',
  roomOrder: const ['r1'],
  kind: kind,
  order: order,
  recommendedLevel: recommendedLevel,
  unlockRequiresDungeonId: unlockRequires,
  baseDungeonId: baseDungeonId,
  rooms: {
    'r1': RoomDefinition(
      id: 'r1',
      dungeonId: id,
      name: 'R1',
      type: RoomType.normal,
      mapRef: 'm',
      layout: const ['#####', '#...#', '#####'],
      entryPosition: const GridPoint(1, 1),
      exitPosition: const GridPoint(3, 1),
      spawns: const [],
      completionCondition: const RoomCompletionCondition(
        type: RoomCompletionConditionType.defeatRequiredEnemies,
      ),
    ),
  },
);

void main() {
  const progression = DungeonProgressionService();

  final d1 = _makeDungeon(id: 'd1', order: 1, recommendedLevel: 1);
  final d2 = _makeDungeon(
    id: 'd2',
    order: 2,
    recommendedLevel: 8,
    unlockRequires: 'd1',
  );
  final d3 = _makeDungeon(
    id: 'd3',
    order: 3,
    recommendedLevel: 16,
    unlockRequires: 'd2',
  );
  final asc = _makeDungeon(
    id: 'asc',
    order: 4,
    kind: DungeonKind.ascension,
    recommendedLevel: 35,
    baseDungeonId: 'd3',
  );
  final all = [d1, d2, d3, asc];

  group('DungeonProgressionService — cycle clear & unlock', () {
    test('isClearedInCurrentCycle membedakan clearsCount seumur hidup dan clearedInCycleRank', () {
      const rank0 = CycleProgress(ascensionRank: 0);
      const rank1 = CycleProgress(ascensionRank: 1);

      final progresses = {
        'd1': const DungeonProgressSnapshot(
          currentDungeonId: 'd1',
          clearsCount: 5,
          clearedInCycleRank: 0,
        ),
        'd2': const DungeonProgressSnapshot(
          currentDungeonId: 'd2',
          clearsCount: 2,
          clearedInCycleRank: -1,
        ),
      };

      expect(
        progression.isClearedInCurrentCycle('d1', rank0, progresses),
        isTrue,
      );
      expect(
        progression.isClearedInCurrentCycle('d2', rank0, progresses),
        isFalse,
      );
      // Naik ke rank 1: meski clearsCount == 5, tidak otomatis clear di rank 1.
      expect(
        progression.isClearedInCurrentCycle('d1', rank1, progresses),
        isFalse,
      );
    });

    test(
      'isUnlocked mengikuti rantai unlock per siklus termasuk Ascension',
      () {
        const rank0 = CycleProgress(ascensionRank: 0);
        final fresh = <String, DungeonProgressSnapshot>{};

        expect(progression.isUnlocked(d1, rank0, fresh), isTrue);
        expect(progression.isUnlocked(d2, rank0, fresh), isFalse);
        expect(progression.isUnlocked(d3, rank0, fresh), isFalse);
        expect(
          progression.isUnlocked(asc, rank0, fresh, allDungeons: all),
          isFalse,
        );

        final afterD1 = {
          'd1': const DungeonProgressSnapshot(
            currentDungeonId: 'd1',
            clearsCount: 1,
            clearedInCycleRank: 0,
          ),
        };
        expect(progression.isUnlocked(d2, rank0, afterD1), isTrue);
        expect(progression.isUnlocked(d3, rank0, afterD1), isFalse);

        final afterAll = {
          'd1': const DungeonProgressSnapshot(
            currentDungeonId: 'd1',
            clearsCount: 1,
            clearedInCycleRank: 0,
          ),
          'd2': const DungeonProgressSnapshot(
            currentDungeonId: 'd2',
            clearsCount: 1,
            clearedInCycleRank: 0,
          ),
          'd3': const DungeonProgressSnapshot(
            currentDungeonId: 'd3',
            clearsCount: 1,
            clearedInCycleRank: 0,
          ),
        };
        expect(progression.isUnlocked(d3, rank0, afterAll), isTrue);
        expect(
          progression.isUnlocked(asc, rank0, afterAll, allDungeons: all),
          isTrue,
        );

        // Setelah naik ke rank 1, D2..D3 & Ascension kembali terkunci sampai D1 dst. diulang.
        const rank1 = CycleProgress(ascensionRank: 1);
        expect(progression.isUnlocked(d1, rank1, afterAll), isTrue);
        expect(progression.isUnlocked(d2, rank1, afterAll), isFalse);
        expect(
          progression.isUnlocked(asc, rank1, afterAll, allDungeons: all),
          isFalse,
        );
      },
    );
  });

  group(
    'DungeonProgressionService — resolveFarmDungeonId & recommendedLevel',
    () {
      test('resolveFarmDungeonId memilih normal tertinggi yg clear, atau preferred jika sah', () {
        const rank0 = CycleProgress(ascensionRank: 0);
        expect(
          progression.resolveFarmDungeonId(
            dungeons: all,
            cycle: rank0,
            progresses: const {},
          ),
          isNull,
        );

        final progresses = {
          'd1': const DungeonProgressSnapshot(
            currentDungeonId: 'd1',
            clearsCount: 3,
            clearedInCycleRank: 0,
          ),
          'd2': const DungeonProgressSnapshot(
            currentDungeonId: 'd2',
            clearsCount: 1,
            clearedInCycleRank: 0,
          ),
          'asc': const DungeonProgressSnapshot(
            currentDungeonId: 'asc',
            clearsCount: 1,
            clearedInCycleRank: 0,
          ),
        };

        expect(
          progression.resolveFarmDungeonId(
            dungeons: all,
            cycle: rank0,
            progresses: progresses,
          ),
          'd2',
        );

        // Preferred normal & clear dipakai.
        expect(
          progression.resolveFarmDungeonId(
            dungeons: all,
            cycle: rank0,
            progresses: progresses,
            preferredDungeonId: 'd1',
          ),
          'd1',
        );

        // Preferred yang belum clear atau bertipe ascension ditolak -> fallback ke D2.
        expect(
          progression.resolveFarmDungeonId(
            dungeons: all,
            cycle: rank0,
            progresses: progresses,
            preferredDungeonId: 'd3',
          ),
          'd2',
        );
        expect(
          progression.resolveFarmDungeonId(
            dungeons: all,
            cycle: rank0,
            progresses: progresses,
            preferredDungeonId: 'asc',
          ),
          'd2',
        );
      });

      test(
        'recommendedLevel mengikuti rumus logaritmik & aman di rank tinggi',
        () {
          expect(progression.recommendedLevel(d1, 0), 1);
          expect(progression.recommendedLevel(d2, 0), 8);

          // Rank 1 (cyclePerRank 0.4): C(1) = 1.4 -> ceil(8 * ln(1.4)/ln(1.5)) = ceil(6.638) = 7 -> 1 + 7 = 8.
          expect(progression.recommendedLevel(d1, 1), 8);

          // Pangkat eksak 1.5 tidak boleh melonjak +1 akibat noise float.
          const exactStepService = DungeonProgressionService(
            DifficultyConfig(cyclePerRank: 0.5),
          );
          // C(1) = 1.5 -> 1 + 8 = 9
          expect(exactStepService.recommendedLevel(d1, 1), 9);

          const exactSquareService = DungeonProgressionService(
            DifficultyConfig(cyclePerRank: 0.625),
          );
          // C(2) = 1 + 1.25 = 2.25 = 1.5^2 -> 1 + 16 = 17
          expect(exactSquareService.recommendedLevel(d1, 2), 17);

          final extreme = progression.recommendedLevel(d3, 10000);
          expect(extreme, greaterThan(16));
          expect(extreme, lessThanOrEqualTo(DifficultyService.kMaxScaledValue));
        },
      );
    },
  );
}
