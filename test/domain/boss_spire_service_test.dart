import 'dart:io';

import 'package:echoes_of_aether/data/models/boss_spire_config_parser.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/boss_spire.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/services/boss_spire_service.dart';
import 'package:echoes_of_aether/domain/services/currency_service.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

void main() {
  group('BossSpireService & Progression', () {
    late BossSpireConfig spireConfig;
    late BossSpireService service;

    setUp(() {
      spireConfig = const BossSpireConfigParser().parse(
        _readAsset('boss_spire.json'),
      );
      service = BossSpireService(spireConfig);
    });

    test(
      'BossSpireProgress menghitung lantai terbuka dan selesai dengan benar',
      () {
        // 1. Awal permainan (belum ada yang clear)
        final initialProgress = service.getProgress({});
        expect(initialProgress.highestClearedFloor, 0);
        expect(initialProgress.clearedFloors, isEmpty);
        expect(initialProgress.isFloorUnlocked(1), isTrue);
        expect(initialProgress.isFloorUnlocked(2), isFalse);
        expect(initialProgress.isFloorCleared(1), isFalse);

        // 2. Setelah lantai 1 dan 2 selesai
        final clearedProgress = service.getProgress({
          'boss_spire:floor_1',
          'boss_spire:floor_2',
        });
        expect(clearedProgress.highestClearedFloor, 2);
        expect(clearedProgress.clearedFloors, {1, 2});
        expect(clearedProgress.isFloorCleared(1), isTrue);
        expect(clearedProgress.isFloorCleared(2), isTrue);
        expect(clearedProgress.isFloorCleared(3), isFalse);
        expect(clearedProgress.isFloorUnlocked(3), isTrue);
        expect(clearedProgress.isFloorUnlocked(4), isFalse);
      },
    );

    test(
      'buildFloorDungeon membangun definisi 1-room arena bertipe bossSpire',
      () {
        final floor1 = spireConfig.floorFor(1)!;
        final arenaLayout = [
          '########################',
          '#......................#',
          '#......................#',
          '#......................#',
          '#......................#',
          '#......................#',
          '#......................#',
          '#......................#',
          '#......................#',
          '#......................#',
          '#......................#',
          '#......................#',
          '########################',
        ];

        final dungeon = service.buildFloorDungeon(
          floor: floor1,
          arenaLayout: arenaLayout,
        );

        expect(dungeon.id, floor1.dungeonId);
        expect(dungeon.kind, DungeonKind.bossSpire);
        expect(dungeon.order, 1);
        expect(dungeon.rooms.length, 1);
        final room = dungeon.rooms.values.first;
        expect(room.type, RoomType.boss);
        expect(room.spawns.length, 1);
        expect(room.spawns.first.monsterId, floor1.bossId);
        expect(room.spawns.first.isBoss, isTrue);
        expect(room.spawns.first.required, isTrue);
      },
    );

    test('settleFloorVictory memberikan hadiah pertama secara idempoten', () {
      const parser = GameConfigParser();
      final settings = _readAsset('game_config.json');
      final progConfig = parser.parseProgression(settings);
      final specConfig = const SpecializationConfigParser().parse(
        _readAsset('specializations.json'),
      );

      final character = PlayerCharacter(
        config: progConfig,
        specializationConfig: specConfig,
      );
      final currencyService = CurrencyService(
        definitions: parser.parseCurrencies(settings),
      );
      final claimedEventIds = <String>{};

      final initialGold = character.gold;
      final initialExp = character.currentExp;
      final initialShards = currencyService.balance('aether_shard');

      // 1. Klaim kemenangan pertama lantai 1
      final result1 = service.settleFloorVictory(
        floorNumber: 1,
        character: character,
        currencyService: currencyService,
        claimedEventIds: claimedEventIds,
      );

      expect(result1.isFirstClear, isTrue);
      expect(claimedEventIds.contains('boss_spire:floor_1'), isTrue);
      expect(character.gold, greaterThan(initialGold));
      expect(character.currentExp, greaterThan(initialExp));
      expect(
        currencyService.balance('aether_shard'),
        greaterThan(initialShards),
      );

      final goldAfterFirst = character.gold;
      final expAfterFirst = character.currentExp;
      final shardsAfterFirst = currencyService.balance('aether_shard');

      // 2. Settle ulang lantai 1 (tantangan ulang)
      final result2 = service.settleFloorVictory(
        floorNumber: 1,
        character: character,
        currencyService: currencyService,
        claimedEventIds: claimedEventIds,
      );

      expect(result2.isFirstClear, isFalse);
      // Hadiah tidak diduplikasi
      expect(character.gold, goldAfterFirst);
      expect(character.currentExp, expAfterFirst);
      expect(currencyService.balance('aether_shard'), shardsAfterFirst);
    });

    test('resolveArenaLayout menemukan layout dari GameConfig', () {
      const parser = GameConfigParser();
      const dungeonParser = DungeonConfigParser();
      final settings = _readAsset('game_config.json');
      final dungeonsJson = _readAsset('dungeons.json');

      final gameConfig = GameConfig(
        monsters: const MonsterConfigParser().parse(
          _readAsset('monsters.json'),
        ),
        damage: parser.parseDamage(settings),
        difficulty: parser.parseDifficulty(settings),
        farming: parser.parseFarming(settings),
        revive: parser.parseRevive(settings),
        progression: parser.parseProgression(settings),
        equipment: parser.parseEquipment(settings),
        time: parser.parseTime(settings),
        claimedRewards: parser.parseClaimedRewards(settings),
        currencies: parser.parseCurrencies(settings),
        items: const ItemConfigParser().parse(_readAsset('items.json')),
        lootTables: const LootConfigParser().parse(
          _readAsset('loot_tables.json'),
        ),
        dungeons: dungeonParser.parse(
          dungeonsJson,
          ascensionMultiplier: parser
              .parseDifficulty(settings)
              .ascensionMultiplier,
        ),
        mapLayouts: dungeonParser.parseMaps(dungeonsJson),
        bossSpire: spireConfig,
      );

      final layout = BossSpireService.resolveArenaLayout(gameConfig);
      expect(layout, isNotNull);
      expect(layout!.isNotEmpty, isTrue);
    });

    test(
      'reset 2-mingguan: progres lantai dan hadiah di-reset pada siklus baru',
      () {
        const parser = GameConfigParser();
        final settings = _readAsset('game_config.json');
        final progConfig = parser.parseProgression(settings);
        final specConfig = const SpecializationConfigParser().parse(
          _readAsset('specializations.json'),
        );

        final character = PlayerCharacter(
          config: progConfig,
          specializationConfig: specConfig,
        );
        final currencyService = CurrencyService(
          definitions: parser.parseCurrencies(settings),
        );
        final claimedEventIds = <String>{};

        const cycle1 = '2026-11-16';
        const cycle2 = '2026-11-30';

        // 1. Pada Siklus 1: pemain menyelesaikan Lantai 1
        final res1 = service.settleFloorVictory(
          floorNumber: 1,
          character: character,
          currencyService: currencyService,
          claimedEventIds: claimedEventIds,
          cycleKey: cycle1,
        );
        expect(res1.isFirstClear, isTrue);
        expect(claimedEventIds, contains('boss_spire:$cycle1:floor_1'));
        expect(currencyService.balance('aether_shard'), 5);

        final progressCycle1 = service.getProgress(
          claimedEventIds,
          cycleKey: cycle1,
        );
        expect(progressCycle1.isFloorCleared(1), isTrue);
        expect(progressCycle1.isFloorUnlocked(2), isTrue);

        // 2. Pada Siklus 2 (2 minggu kemudian): progres lantai 1 di-reset!
        final progressCycle2 = service.getProgress(
          claimedEventIds,
          cycleKey: cycle2,
        );
        expect(progressCycle2.isFloorCleared(1), isFalse);
        expect(progressCycle2.isFloorUnlocked(1), isTrue);
        expect(progressCycle2.isFloorUnlocked(2), isFalse);
        expect(progressCycle2.highestClearedFloor, 0);

        // 3. Pemain dapat menyelesaikan Lantai 1 lagi di Siklus 2 dan mendapat reward lagi!
        final res2 = service.settleFloorVictory(
          floorNumber: 1,
          character: character,
          currencyService: currencyService,
          claimedEventIds: claimedEventIds,
          cycleKey: cycle2,
        );
        expect(res2.isFirstClear, isTrue);
        expect(claimedEventIds, contains('boss_spire:$cycle2:floor_1'));
        expect(
          currencyService.balance('aether_shard'),
          10,
        ); // bertambah 5 lagi!

        final progressCycle2After = service.getProgress(
          claimedEventIds,
          cycleKey: cycle2,
        );
        expect(progressCycle2After.isFloorCleared(1), isTrue);
        expect(progressCycle2After.isFloorUnlocked(2), isTrue);
      },
    );
  });
}
