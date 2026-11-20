import 'dart:io';

import 'package:echoes_of_aether/data/models/boss_events_config_parser.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/boss_event.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/services/boss_event_service.dart';
import 'package:echoes_of_aether/domain/services/difficulty_service.dart';
import 'package:echoes_of_aether/domain/services/dungeon_progression_service.dart';
import 'package:echoes_of_aether/domain/services/period_service.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

void main() {
  final bossEvents = const BossEventsConfigParser().parse(
    _readAsset('boss_events.json'),
  );
  final dungeonsJson = _readAsset('dungeons.json');
  final dungeons = const DungeonConfigParser().parse(dungeonsJson);
  final maps = const DungeonConfigParser().parseMaps(dungeonsJson);
  final difficultyConfig = const GameConfigParser().parseDifficulty(
    _readAsset('game_config.json'),
  );
  final bossService = BossEventService(bossEvents);
  final difficultyService = DifficultyService(difficultyConfig);

  group('BossEventService', () {
    test(
      'bossFor deterministik, berputar lintas batas pool, dan indeks besar',
      () {
        // Daily pool memiliki 3 boss
        final d0 = bossService.bossFor(Period.daily, 0);
        final d1 = bossService.bossFor(Period.daily, 1);
        final d2 = bossService.bossFor(Period.daily, 2);
        final d3 = bossService.bossFor(Period.daily, 3);
        final dLarge = bossService.bossFor(Period.daily, 1000002);

        expect(d0.id, bossEvents.daily.pool[0].id);
        expect(d1.id, bossEvents.daily.pool[1].id);
        expect(d2.id, bossEvents.daily.pool[2].id);
        expect(d3.id, d0.id);
        expect(dLarge.id, d0.id);
        expect(bossService.bossFor(Period.daily, 1).id, d1.id);

        // Weekly pool memiliki 2 boss
        final w0 = bossService.bossFor(Period.weekly, 0);
        final w1 = bossService.bossFor(Period.weekly, 1);
        final w2 = bossService.bossFor(Period.weekly, 2);
        expect(w0.id, bossEvents.weekly.pool[0].id);
        expect(w1.id, bossEvents.weekly.pool[1].id);
        expect(w2.id, w0.id);
      },
    );

    test('resolveReference: awal siklus -> Dungeon 1; clear Dungeon 3 -> Dungeon 3; rank terpilih < tertinggi', () {
      final normalSorted = dungeons.values.where((d) => d.isNormal).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      final d1 = normalSorted[0];
      final d3 = normalSorted[2];
      final d5 = normalSorted[4];

      // Awal siklus: belum ada dungeon cleared -> Dungeon 1
      final refInitial = bossService.resolveReference(
        const CycleProgress(ascensionRank: 0, highestAscensionRank: 0),
        const {},
        dungeons,
      );
      expect(refInitial.dungeon.id, d1.id);
      expect(refInitial.cycleRank, 0);

      // Setelah clear Dungeon 3 pada rank 0 -> Dungeon 3
      final refD3 = bossService.resolveReference(
        const CycleProgress(ascensionRank: 0, highestAscensionRank: 0),
        {
          d1.id: DungeonProgressSnapshot(
            currentDungeonId: d1.id,
            clearsCount: 1,
            clearedInCycleRank: 0,
          ),
          d3.id: DungeonProgressSnapshot(
            currentDungeonId: d3.id,
            clearsCount: 1,
            clearedInCycleRank: 0,
          ),
        },
        dungeons,
      );
      expect(refD3.dungeon.id, d3.id);
      expect(refD3.cycleRank, 0);

      // Rank terpilih (1) lebih rendah dari tertinggi (3), walau rank 3 sudah clear Dungeon 5:
      // acuan harus memakai progress pada rank terpilih (rank 1 -> Dungeon 3).
      final refLowerRank = bossService.resolveReference(
        const CycleProgress(ascensionRank: 1, highestAscensionRank: 3),
        {
          d3.id: DungeonProgressSnapshot(
            currentDungeonId: d3.id,
            clearsCount: 2,
            clearedInCycleRank: 1,
          ),
          d5.id: DungeonProgressSnapshot(
            currentDungeonId: d5.id,
            clearsCount: 1,
            clearedInCycleRank: 3,
          ),
        },
        dungeons,
      );
      expect(refLowerRank.dungeon.id, d3.id);
      expect(refLowerRank.cycleRank, 1);
    });

    test(
      'DifficultyService.profileForBoss mengalikan power_factor pada stat saja',
      () {
        final normalSorted = dungeons.values.where((d) => d.isNormal).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
        final ref = BossReference(dungeon: normalSorted[2], cycleRank: 2);
        final base = difficultyService.profileFor(ref.dungeon, ref.cycleRank);
        final weeklyProfile = difficultyService.profileForBoss(ref, 1.5);

        expect(
          weeklyProfile.hpMultiplier,
          closeTo(base.hpMultiplier * 1.5, 1e-9),
        );
        expect(
          weeklyProfile.atkMultiplier,
          closeTo(base.atkMultiplier * 1.5, 1e-9),
        );
        expect(
          weeklyProfile.defMultiplier,
          closeTo(base.defMultiplier * 1.5, 1e-9),
        );
        expect(weeklyProfile.rewardMultiplier, base.rewardMultiplier);
        expect(
          weeklyProfile.rareDropChanceMultiplier,
          base.rareDropChanceMultiplier,
        );
        expect(weeklyProfile.equipmentRollBonus, base.equipmentRollBonus);
      },
    );

    test('buildBossDungeon membuat satu ruangan boss dan menangani semua DungeonKind', () {
      final ref = bossService.resolveReference(
        const CycleProgress(),
        const {},
        dungeons,
      );
      final boss = bossService.bossFor(Period.daily, 0);
      final arenaLayout = maps[bossEvents.arenaMapRef]!;
      final bossDungeon = bossService.buildBossDungeon(
        boss: boss,
        period: Period.daily,
        reference: ref,
        arenaLayout: arenaLayout,
      );

      expect(bossDungeon.kind, DungeonKind.bossDaily);
      expect(bossDungeon.isBossEvent, isTrue);
      expect(bossDungeon.isNormal, isFalse);
      expect(bossDungeon.isAscension, isFalse);
      expect(bossDungeon.roomOrder.length, 1);
      final room = bossDungeon.rooms.values.single;
      expect(room.type, RoomType.boss);
      expect(room.spawns.length, 1);
      expect(room.spawns.single.isBoss, isTrue);
      expect(room.spawns.single.monsterId, boss.id);
      expect(
        room.completionCondition.type,
        RoomCompletionConditionType.defeatBoss,
      );

      // Pastikan semua enum DungeonKind ditangani & boss ditolak oleh unlock normal.
      final progService = DungeonProgressionService(difficultyConfig);
      for (final kind in DungeonKind.values) {
        final label = switch (kind) {
          DungeonKind.normal => 'normal',
          DungeonKind.ascension => 'ascension',
          DungeonKind.bossDaily => 'bossDaily',
          DungeonKind.bossWeekly => 'bossWeekly',
          DungeonKind.bossSpire => 'bossSpire',
          DungeonKind.infiniteSpire => 'infiniteSpire',
        };
        expect(label, isNotEmpty);
      }
      expect(
        progService.isUnlocked(
          bossDungeon,
          const CycleProgress(),
          const {},
          allDungeons: dungeons.values,
          playerLevel: 999,
        ),
        isFalse,
      );
    });
  });
}
