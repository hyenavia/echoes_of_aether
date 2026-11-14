import 'dart:io';
import 'dart:math' as math;

import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/combat_event.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/player_status.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/dungeon_manager.dart';
import 'package:echoes_of_aether/domain/services/dungeon_reward_settlement_service.dart';
import 'package:echoes_of_aether/domain/services/encounter_tracker.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/offline_dungeon_runner.dart';
import 'package:echoes_of_aether/domain/services/offline_time_calculator.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealGameConfig() {
  const parser = GameConfigParser();
  final settings = _readAsset('game_config.json');
  final config = GameConfig(
    monsters: const MonsterConfigParser().parse(_readAsset('monsters.json')),
    revive: parser.parseRevive(settings),
    progression: parser.parseProgression(settings),
    equipment: parser.parseEquipment(settings),
    dungeonCompletion: parser.parseDungeonCompletion(settings),
    items: const ItemConfigParser().parse(_readAsset('items.json')),
    lootTables: const LootConfigParser().parse(_readAsset('loot_tables.json')),
    skills: const SkillConfigParser().parse(_readAsset('skills.json')),
    specializations: const SpecializationConfigParser().parse(
      _readAsset('specializations.json'),
    ),
    dungeons: const DungeonConfigParser().parse(_readAsset('dungeons.json')),
  );
  const GameConfigValidator().validate(config);
  return config;
}

({
  bool completed,
  int roomsCleared,
  int kills,
  int expGained,
  int goldGained,
  int finalLevel,
  int ticks,
})
_runOnlineSingleRun({
  required GameConfig config,
  required int startLevel,
  String? specializationId,
  required int seed,
}) {
  final character = PlayerCharacter(
    config: config.progression,
    progress: PlayerProgress(level: startLevel),
    skillCatalog: config.skills,
    specializationConfig: config.specializations,
  );
  if (specializationId != null) {
    character.chooseSpecialization(specializationId);
  }
  final inventory = Inventory(definitions: config.items);
  final rewardProcessor = RewardProcessor(
    character: character,
    inventory: inventory,
    items: config.items,
    lootTables: config.lootTables,
    equipmentFactory: EquipmentFactory(config.equipment),
  );
  final tracker = EncounterTracker(monsterCatalog: config.monsters);
  final manager = DungeonManager(
    dungeons: config.dungeons,
    encounterTracker: tracker,
  );
  const settlement = DungeonRewardSettlementService();
  final rng = math.Random(seed);

  manager.startDungeon('forgotten_forest', runId: 'online_run');
  final startRoom = manager.activeRoom!;
  final sim =
      CombatSimulation(
        grid: manager.activeGrid!,
        pathfinder: const AStarPathfinder(),
        player: Combatant(
          id: 'player',
          team: Team.player,
          stats: character.stats,
          cell: startRoom.entryPosition,
        ),
        reviveConfig: config.revive,
        seed: seed,
      )..setPlayerSkills(
        character.activeSkills,
        runtimeStates: {
          for (final s in character.activeSkills)
            s.id: character.skillRuntimeState(s.id),
        },
        skillAffinities: character.activeSkillAffinities,
      );

  tracker.onRoomLoaded(sim, grid: sim.grid);
  manager.activateRoom();
  tracker.onRoomActivated(sim, grid: sim.grid);

  var expGained = 0;
  var goldGained = 0;
  var kills = 0;
  var totalTicks = 0;
  var appliedLevel = character.level;

  for (var i = 0; i < 8000; i++) {
    final cur = manager.session!;
    if (cur.isTerminal) break;

    if (cur.roomLifecycle == RoomLifecycleState.completed) {
      manager.transitionToNextRoom();
      if (manager.hasActiveSession && manager.activeRoom != null) {
        final nextRoom = manager.activeRoom!;
        final nextGrid = manager.activeGrid!;
        sim.loadRoom(nextGrid, entryCell: nextRoom.entryPosition);
        tracker.onRoomLoaded(sim, grid: nextGrid);
        manager.activateRoom();
        tracker.onRoomActivated(sim, grid: nextGrid);
      }
      continue;
    }

    sim.tick();
    totalTicks++;

    for (final ev in sim.drainEvents()) {
      if (ev is EnemyDefeatedEvent) {
        final reward = rewardProcessor.processEnemyDefeated(
          eventId: 'online_kill:${cur.runId}:${ev.enemyId}',
          definition: ev.definition,
          random: rng,
        );
        if (!reward.alreadyClaimed) {
          kills++;
          expGained += reward.expGranted;
          goldGained += reward.goldGranted;
        }
        tracker.onEnemyDefeated(ev.enemyId, simulation: sim, grid: sim.grid);
      } else if (ev is RunEndedEvent) {
        tracker.onRunFailed();
        manager.endRun(
          finalStatus: DungeonSessionStatus.failed,
          reason: DungeonEndReason.defeated,
        );
      }
    }

    if (character.level != appliedLevel) {
      appliedLevel = character.level;
      sim.player.applyStats(character.stats);
      sim.setPlayerSkills(
        character.activeSkills,
        runtimeStates: {
          for (final s in character.activeSkills)
            s.id: character.skillRuntimeState(s.id),
        },
        skillAffinities: character.activeSkillAffinities,
      );
    }

    if (manager.hasActiveSession &&
        manager.session!.roomLifecycle == RoomLifecycleState.active &&
        sim.playerStatus == PlayerStatus.alive) {
      final cell = sim.player.follower.currentCell;
      final eval = manager.evaluateCurrentRoom(playerCell: cell);
      if (eval.isCompleted) {
        final room = manager.activeRoom!;
        if (manager.tryCompleteActiveRoom(
          playerCell: cell,
          expectedRunId: cur.runId,
          expectedRoomId: room.id,
        )) {
          final roomReward = settlement.settleRoomCompleted(
            session: manager.session!,
            room: room,
            rewardProcessor: rewardProcessor,
            random: rng,
          );
          if (roomReward != null && !roomReward.alreadyClaimed) {
            expGained += roomReward.expGranted;
            goldGained += roomReward.goldGranted;
          }
          if (manager.session!.status == DungeonSessionStatus.completed) {
            final endEvent = DungeonEndedEvent(
              manager.session!,
              DungeonSessionStatus.completed,
              reason: DungeonEndReason.completed,
              dungeon: config.dungeons['forgotten_forest'],
            );
            final cleared = settlement.settleDungeonCompleted(
              event: endEvent,
              config: config,
              rewardProcessor: rewardProcessor,
              random: rng,
              dungeonManager: manager,
            );
            if (cleared.granted != null && !cleared.granted!.alreadyClaimed) {
              expGained += cleared.granted!.expGranted;
              goldGained += cleared.granted!.goldGranted;
            }
          }
        }
      }
    }
  }

  final finalSession = manager.session!;
  return (
    completed: finalSession.status == DungeonSessionStatus.completed,
    roomsCleared: finalSession.clearedRoomIds.length,
    kills: kills,
    expGained: expGained,
    goldGained: goldGained,
    finalLevel: character.level,
    ticks: totalTicks,
  );
}

void main() {
  group('Offline vs Online Combat & Reward Parity (Forgotten Forest Real Config)', () {
    test('Lv4 hero & specialization builds menghasilkan clear, kills, EXP, Gold, dan timing setara antara online & headless runner', () {
      final config = _loadRealGameConfig();
      final dungeon = config.dungeons['forgotten_forest']!;
      const runner = OfflineDungeonRunner();
      final window = const OfflineTimeCalculator().calculate(
        session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
        nowMs: 1000000 + const Duration(minutes: 10).inMilliseconds,
      );

      for (final specId in <String?>[null, 'vanguard', 'arcanist', 'ranger']) {
        final online = _runOnlineSingleRun(
          config: config,
          startLevel: 5,
          specializationId: specId,
          seed: 123,
        );

        final offChar = PlayerCharacter(
          config: config.progression,
          progress: const PlayerProgress(level: 5),
          skillCatalog: config.skills,
          specializationConfig: config.specializations,
        );
        if (specId != null) {
          offChar.chooseSpecialization(specId);
        }
        final offInv = Inventory(definitions: config.items);
        final offRp = RewardProcessor(
          character: offChar,
          inventory: offInv,
          items: config.items,
          lootTables: config.lootTables,
          equipmentFactory: EquipmentFactory(config.equipment),
        );

        final offline = runner.runBatch(
          OfflineDungeonRunRequest(
            mode: OfflineActivityMode.continueDungeon,
            character: offChar,
            inventory: offInv,
            config: config,
            rewardProcessor: offRp,
            dungeonId: 'forgotten_forest',
            dungeonProgress: const DungeonProgressSnapshot(
              currentDungeonId: 'forgotten_forest',
            ),
            activeDungeonSession: ActiveDungeonSessionSnapshot(
              runId: 'parity_run_${specId ?? "none"}',
              dungeonId: 'forgotten_forest',
              currentRoomId: dungeon.startRoomId,
              currentRoomIndex: 0,
              status: DungeonSessionStatus.inProgress,
            ),
            timeWindow: window,
            simulationSeed: 123,
          ),
        );

        expect(
          online.completed,
          isTrue,
          reason: 'Online clear for spec=$specId',
        );
        expect(offline.stopReason, OfflineDungeonStopReason.dungeonCompleted);
        expect(offline.runsCompleted, 1);
        expect(offline.roomsCleared, online.roomsCleared);
        expect(offline.encountersCleared, online.kills);
        expect(offline.expGained, online.expGained);
        expect(offline.goldGained, online.goldGained);
        expect(offChar.level, online.finalLevel);

        // Coarse jump menjaga kesetaraan timeline simulasi (selisih sangat kecil).
        expect(
          (offline.ticksSimulated - online.ticks).abs(),
          lessThanOrEqualTo(300),
          reason:
              'Simulasi coarse vs 20 TPS tidak boleh menyimpang jauh (spec=$specId)',
        );
      }
    });

    test('defeat parity: boss jauh di atas level hero menggagalkan baik online maupun offline setelah auto-revive', () {
      final config = _loadRealGameConfig();
      const runner = OfflineDungeonRunner();
      final window = const OfflineTimeCalculator().calculate(
        session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
        nowMs: 1000000 + const Duration(minutes: 10).inMilliseconds,
      );

      // Mulai langsung di Ancient Heart (Boss Lv1 vs Hero Lv1) agar mengetes defeat setelah revive.
      final weakOnlineChar = PlayerCharacter(config: config.progression);
      final tracker = EncounterTracker(monsterCatalog: config.monsters);
      final manager = DungeonManager(
        dungeons: config.dungeons,
        encounterTracker: tracker,
      );
      final restored = manager.restoreSession(
        const ActiveDungeonSessionSnapshot(
          runId: 'boss_defeat_online',
          dungeonId: 'forgotten_forest',
          currentRoomId: 'ancient_heart',
          currentRoomIndex: 4,
          status: DungeonSessionStatus.inProgress,
          clearedRoomIds: {
            'forest_entrance',
            'ancient_path',
            'ruined_shrine',
            'hidden_chamber',
          },
        ),
      )!;
      final onlineSim = CombatSimulation(
        grid: manager.activeGrid!,
        pathfinder: const AStarPathfinder(),
        player: Combatant(
          id: 'player',
          team: Team.player,
          stats: weakOnlineChar.stats,
          cell: manager.activeRoom!.entryPosition,
        ),
        reviveConfig: config.revive,
        seed: 7,
      );
      tracker.onRoomLoaded(onlineSim, grid: onlineSim.grid);
      manager.activateRoom();
      tracker.onRoomActivated(onlineSim, grid: onlineSim.grid);
      for (var t = 0; t < 4000; t++) {
        onlineSim.tick();
        if (onlineSim.playerStatus == PlayerStatus.runEnded) {
          manager.endRun(
            finalStatus: DungeonSessionStatus.failed,
            reason: DungeonEndReason.defeated,
          );
          break;
        }
        final eval = manager.evaluateCurrentRoom(
          playerCell: onlineSim.player.follower.currentCell,
        );
        if (eval.isCompleted) break;
      }

      final weakOfflineChar = PlayerCharacter(config: config.progression);
      final offInv = Inventory(definitions: config.items);
      final offRp = RewardProcessor(
        character: weakOfflineChar,
        inventory: offInv,
        items: config.items,
        lootTables: config.lootTables,
        equipmentFactory: EquipmentFactory(config.equipment),
      );
      final offlineOutcome = runner.runBatch(
        OfflineDungeonRunRequest(
          mode: OfflineActivityMode.continueDungeon,
          character: weakOfflineChar,
          inventory: offInv,
          config: config,
          rewardProcessor: offRp,
          dungeonId: 'forgotten_forest',
          dungeonProgress: const DungeonProgressSnapshot(
            currentDungeonId: 'forgotten_forest',
            currentRoomId: 'ancient_heart',
            currentRoomIndex: 4,
          ),
          activeDungeonSession: ActiveDungeonSessionSnapshot(
            runId: restored.runId,
            dungeonId: 'forgotten_forest',
            currentRoomId: 'ancient_heart',
            currentRoomIndex: 4,
            status: DungeonSessionStatus.inProgress,
            clearedRoomIds: const {
              'forest_entrance',
              'ancient_path',
              'ruined_shrine',
              'hidden_chamber',
            },
          ),
          timeWindow: window,
          simulationSeed: 7,
        ),
      );

      expect(manager.session!.status, DungeonSessionStatus.failed);
      expect(
        offlineOutcome.stopReason,
        OfflineDungeonStopReason.playerDefeated,
      );
      expect(offlineOutcome.runsFailed, 1);
      expect(offlineOutcome.runsCompleted, 0);
    });
  });
}
