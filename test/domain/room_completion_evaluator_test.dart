import 'dart:io';

import 'package:echoes_of_aether/core/errors/config_exception.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/room_encounter.dart';
import 'package:echoes_of_aether/domain/services/room_completion_evaluator.dart';
import 'package:flutter_test/flutter_test.dart';

String _asset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadConfigWithDungeons(String dungeonsJson) {
  const parser = GameConfigParser();
  final settings = _asset('game_config.json');
  return GameConfig(
    monsters: const MonsterConfigParser().parse(_asset('monsters.json')),
    revive: parser.parseRevive(settings),
    progression: parser.parseProgression(settings),
    equipment: parser.parseEquipment(settings),
    dungeonCompletion: parser.parseDungeonCompletion(settings),
    items: const ItemConfigParser().parse(_asset('items.json')),
    lootTables: const LootConfigParser().parse(_asset('loot_tables.json')),
    skills: const SkillConfigParser().parse(_asset('skills.json')),
    specializations: const SpecializationConfigParser().parse(
      _asset('specializations.json'),
    ),
    dungeons: const DungeonConfigParser().parse(dungeonsJson),
  );
}

void main() {
  const evaluator = RoomCompletionEvaluator();
  const layout = <String>['#########', '#.......#', '#.......#', '#########'];

  RoomDefinition makeRoom({
    String id = 'room_1',
    RoomType type = RoomType.normal,
    List<RoomSpawnConfig> spawns = const [],
    RoomCompletionCondition condition = const RoomCompletionCondition(),
  }) {
    return RoomDefinition(
      id: id,
      dungeonId: 'test_dungeon',
      name: 'Room',
      type: type,
      mapRef: 'm',
      layout: layout,
      entryPosition: const GridPoint(1, 1),
      exitPosition: const GridPoint(7, 1),
      spawns: spawns,
      completionCondition: condition,
    );
  }

  RoomEncounterState makeEncounter({
    required String spawnId,
    String group = 'default',
    EncounterType type = EncounterType.normal,
    bool requiredForCompletion = true,
    int planned = 1,
    int spawned = 1,
    int defeated = 0,
    EncounterStatus? status,
  }) {
    final resolvedStatus =
        status ??
        (defeated >= planned
            ? EncounterStatus.completed
            : EncounterStatus.active);
    return RoomEncounterState(
      encounterId: 'room_1:$spawnId',
      roomId: 'room_1',
      spawnConfigId: spawnId,
      spawnGroup: group,
      monsterId: 'aether_slime',
      type: type,
      requiredForCompletion: requiredForCompletion,
      activationState: SpawnActivationState.immediate,
      plannedCount: planned,
      spawnedCount: spawned,
      activeCount: (spawned - defeated).clamp(0, spawned),
      defeatedCount: defeated,
      status: resolvedStatus,
    );
  }

  group('RoomCompletionEvaluator — seluruh condition types', () {
    test(
      'defeatRequiredEnemies mengevaluasi target wajib & mengabaikan opsional',
      () {
        final room = makeRoom();
        final unfinished = [
          makeEncounter(spawnId: 's1', defeated: 0),
          makeEncounter(
            spawnId: 'opt',
            requiredForCompletion: false,
            defeated: 1,
            status: EncounterStatus.completed,
          ),
        ];
        final eval1 = evaluator.evaluate(
          room: room,
          roomLifecycle: RoomLifecycleState.active,
          encounters: unfinished,
        );
        expect(eval1.isCompleted, isFalse);
        expect(eval1.encountersSatisfied, isFalse);

        final finished = [
          makeEncounter(spawnId: 's1', defeated: 1),
          makeEncounter(
            spawnId: 'opt',
            requiredForCompletion: false,
            defeated: 0,
          ),
        ];
        final eval2 = evaluator.evaluate(
          room: room,
          roomLifecycle: RoomLifecycleState.active,
          encounters: finished,
        );
        expect(eval2.isCompleted, isTrue);
        expect(eval2.encountersSatisfied, isTrue);
      },
    );

    test(
      'defeatElite dan defeatBoss memverifikasi jenis encounter yang tepat',
      () {
        final eliteRoom = makeRoom(
          type: RoomType.elite,
          condition: const RoomCompletionCondition(
            type: RoomCompletionConditionType.defeatElite,
            requiredSpawnGroup: 'elite_g',
          ),
        );
        final wrongNormalOnly = [
          makeEncounter(
            spawnId: 's_norm',
            group: 'elite_g',
            type: EncounterType.normal,
            defeated: 1,
          ),
        ];
        expect(
          evaluator
              .evaluate(
                room: eliteRoom,
                roomLifecycle: RoomLifecycleState.active,
                encounters: wrongNormalOnly,
              )
              .isCompleted,
          isFalse,
        );

        final eliteKilled = [
          makeEncounter(
            spawnId: 's_elite',
            group: 'elite_g',
            type: EncounterType.elite,
            defeated: 1,
          ),
        ];
        expect(
          evaluator
              .evaluate(
                room: eliteRoom,
                roomLifecycle: RoomLifecycleState.active,
                encounters: eliteKilled,
              )
              .isCompleted,
          isTrue,
        );

        final bossRoom = makeRoom(
          type: RoomType.boss,
          condition: const RoomCompletionCondition(
            type: RoomCompletionConditionType.defeatBoss,
            requiredSpawnGroup: 'boss_g',
          ),
        );
        expect(
          evaluator
              .evaluate(
                room: bossRoom,
                roomLifecycle: RoomLifecycleState.active,
                encounters: [
                  makeEncounter(
                    spawnId: 's_boss',
                    group: 'boss_g',
                    type: EncounterType.boss,
                    defeated: 0,
                  ),
                ],
              )
              .isCompleted,
          isFalse,
        );
        expect(
          evaluator
              .evaluate(
                room: bossRoom,
                roomLifecycle: RoomLifecycleState.active,
                encounters: [
                  makeEncounter(
                    spawnId: 's_boss',
                    group: 'boss_g',
                    type: EncounterType.boss,
                    defeated: 1,
                  ),
                ],
              )
              .isCompleted,
          isTrue,
        );
      },
    );

    test('reachExit membutuhkan posisi pemain tepat di exitPosition dan tidak bisa melewati syarat combat', () {
      final pureExitRoom = makeRoom(
        condition: const RoomCompletionCondition(
          type: RoomCompletionConditionType.reachExit,
        ),
      );
      final away = evaluator.evaluate(
        room: pureExitRoom,
        roomLifecycle: RoomLifecycleState.active,
        encounters: const [],
        playerCell: const GridPoint(2, 1),
      );
      expect(away.exitRequired, isTrue);
      expect(away.exitUnlocked, isTrue);
      expect(away.exitReached, isFalse);
      expect(away.isCompleted, isFalse);

      final arrived = evaluator.evaluate(
        room: pureExitRoom,
        roomLifecycle: RoomLifecycleState.active,
        encounters: const [],
        playerCell: const GridPoint(7, 1),
      );
      expect(arrived.exitReached, isTrue);
      expect(arrived.isCompleted, isTrue);

      // Room butuh musuh kalah DAN reach exit: berdiri di exit sebelum musuh
      // kalah tidak boleh menyelesaikan room.
      final combatPlusExit = makeRoom(
        condition: const RoomCompletionCondition(
          type: RoomCompletionConditionType.defeatRequiredEnemies,
          requireExit: true,
        ),
      );
      final standingAtExitTooEarly = evaluator.evaluate(
        room: combatPlusExit,
        roomLifecycle: RoomLifecycleState.active,
        encounters: [makeEncounter(spawnId: 's1', defeated: 0)],
        playerCell: const GridPoint(7, 1),
      );
      expect(standingAtExitTooEarly.encountersSatisfied, isFalse);
      expect(standingAtExitTooEarly.exitUnlocked, isFalse);
      expect(standingAtExitTooEarly.isCompleted, isFalse);

      final clearedThenAtExit = evaluator.evaluate(
        room: combatPlusExit,
        roomLifecycle: RoomLifecycleState.active,
        encounters: [makeEncounter(spawnId: 's1', defeated: 1)],
        playerCell: const GridPoint(7, 1),
      );
      expect(clearedThenAtExit.encountersSatisfied, isTrue);
      expect(clearedThenAtExit.exitUnlocked, isTrue);
      expect(clearedThenAtExit.isCompleted, isTrue);
    });

    test('multiple completion conditions mewajibkan seluruh klausa terpenuhi & menolak room non-active', () {
      final multiRoom = makeRoom(
        type: RoomType.elite,
        condition: const RoomCompletionCondition(
          type: RoomCompletionConditionType.defeatRequiredEnemies,
          requiredSpawnGroup: 'guards',
          additionalConditions: [
            RoomCompletionCondition(
              type: RoomCompletionConditionType.defeatElite,
              requiredSpawnGroup: 'commander',
            ),
            RoomCompletionCondition(
              type: RoomCompletionConditionType.reachExit,
            ),
          ],
        ),
      );

      final onlyGuardsDown = [
        makeEncounter(spawnId: 'g1', group: 'guards', defeated: 1),
        makeEncounter(
          spawnId: 'e1',
          group: 'commander',
          type: EncounterType.elite,
          defeated: 0,
        ),
      ];
      expect(
        evaluator
            .evaluate(
              room: multiRoom,
              roomLifecycle: RoomLifecycleState.active,
              encounters: onlyGuardsDown,
              playerCell: const GridPoint(7, 1),
            )
            .isCompleted,
        isFalse,
      );

      final allDead = [
        makeEncounter(spawnId: 'g1', group: 'guards', defeated: 1),
        makeEncounter(
          spawnId: 'e1',
          group: 'commander',
          type: EncounterType.elite,
          defeated: 1,
        ),
      ];
      // Semua musuh kalah tetapi belum di exit -> belum selesai.
      final notAtExit = evaluator.evaluate(
        room: multiRoom,
        roomLifecycle: RoomLifecycleState.active,
        encounters: allDead,
        playerCell: const GridPoint(3, 1),
      );
      expect(notAtExit.encountersSatisfied, isTrue);
      expect(notAtExit.exitUnlocked, isTrue);
      expect(notAtExit.isCompleted, isFalse);

      // Saat state loading / unloaded tidak pernah dianggap selesai.
      for (final invalidState in [
        RoomLifecycleState.loading,
        RoomLifecycleState.ready,
        RoomLifecycleState.completed,
        RoomLifecycleState.unloaded,
      ]) {
        expect(
          evaluator
              .evaluate(
                room: multiRoom,
                roomLifecycle: invalidState,
                encounters: allDead,
                playerCell: const GridPoint(7, 1),
              )
              .isCompleted,
          isFalse,
        );
      }

      // Semua terpenuhi pada state active -> selesai!
      expect(
        evaluator
            .evaluate(
              room: multiRoom,
              roomLifecycle: RoomLifecycleState.active,
              encounters: allDead,
              playerCell: const GridPoint(7, 1),
            )
            .isCompleted,
        isTrue,
      );
    });
  });

  group('DungeonConfigParser & Validator — reach_exit & multi-conditions', () {
    test('menerima reach_exit tanpa spawn dan multi-condition valid', () {
      const json = '''
      {
        "maps": { "m": ["#####", "#...#", "#####"] },
        "dungeons": [
          {
            "id": "d1",
            "name": "D1",
            "biome": "b",
            "start_room_id": "r1",
            "rooms": [
              {
                "id": "r1", "name": "R1", "type": "normal", "map_ref": "m",
                "entry_position": {"x": 1, "y": 1}, "exit_position": {"x": 3, "y": 1},
                "spawns": [],
                "completion_condition": { "type": "reach_exit" },
                "next_room_ids": ["r2"]
              },
              {
                "id": "r2", "name": "R2", "type": "elite", "map_ref": "m",
                "entry_position": {"x": 1, "y": 1}, "exit_position": {"x": 3, "y": 1},
                "spawns": [
                  {
                    "id": "e1", "monster_id": "corrupted_guardian",
                    "position": {"x": 2, "y": 1}, "is_elite": true, "required": true
                  }
                ],
                "completion_condition": {
                  "type": "defeat_elite",
                  "require_exit": true,
                  "conditions": [
                    { "type": "reach_exit" }
                  ]
                },
                "next_room_ids": []
              }
            ]
          }
        ]
      }
      ''';
      final config = _loadConfigWithDungeons(json);
      expect(
        () => const GameConfigValidator().validate(config),
        returnsNormally,
      );
      expect(
        config.dungeons['d1']!.roomById('r1')!.completionCondition.type,
        RoomCompletionConditionType.reachExit,
      );
      expect(
        config.dungeons['d1']!.roomById('r2')!.completionCondition.requiresExit,
        isTrue,
      );
    });

    test('menolak nested conditions lebih dari 1 tingkat', () {
      const nestedJson = '''
      {
        "maps": { "m": ["#####", "#...#", "#####"] },
        "dungeons": [{
          "id": "d1", "name": "D1", "biome": "b", "start_room_id": "r1",
          "rooms": [{
            "id": "r1", "name": "R1", "type": "normal", "map_ref": "m",
            "entry_position": {"x": 1, "y": 1}, "exit_position": {"x": 3, "y": 1},
            "spawns": [],
            "completion_condition": {
              "type": "reach_exit",
              "conditions": [
                {
                  "type": "reach_exit",
                  "conditions": [{ "type": "reach_exit" }]
                }
              ]
            },
            "next_room_ids": []
          }]
        }]
      }
      ''';
      expect(
        () => const DungeonConfigParser().parse(nestedJson),
        throwsA(isA<ConfigException>()),
      );
    });
  });
}
