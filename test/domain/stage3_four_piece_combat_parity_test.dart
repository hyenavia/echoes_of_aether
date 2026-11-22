import 'dart:io';
import 'dart:math' as math;

import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/mythical_forge_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/combat_event.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/player_status.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/derived_stats_calculator.dart';
import 'package:echoes_of_aether/domain/services/dungeon_manager.dart';
import 'package:echoes_of_aether/domain/services/dungeon_reward_settlement_service.dart';
import 'package:echoes_of_aether/domain/services/encounter_tracker.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:echoes_of_aether/domain/services/offline_dungeon_runner.dart';
import 'package:echoes_of_aether/domain/services/offline_time_calculator.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealConfig() {
  const parser = GameConfigParser();
  final settings = _readAsset('game_config.json');
  final difficulty = parser.parseDifficulty(settings);
  final config = GameConfig(
    monsters: const MonsterConfigParser().parse(_readAsset('monsters.json')),
    damage: parser.parseDamage(settings),
    difficulty: difficulty,
    farming: parser.parseFarming(settings),
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
    dungeons: const DungeonConfigParser().parse(
      _readAsset('dungeons.json'),
      ascensionMultiplier: difficulty.ascensionMultiplier,
    ),
    heroAscension: parser.parseHeroAscension(settings),
    mythicalForge: const MythicalForgeConfigParser().parse(
      _readAsset('mythical_forge.json'),
    ),
  );
  const GameConfigValidator().validate(config);
  return config;
}

void _equipFullSet(
  PlayerCharacter character,
  GameConfig config,
  List<String> itemIds,
) {
  for (var i = 0; i < itemIds.length; i++) {
    final def = config.items[itemIds[i]]!;
    final eq = def.equipment!;
    character.loadout.equip(
      EquipmentInstance(
        id: 'set_${def.id}_$i',
        definitionId: def.id,
        slot: eq.slot,
        rarity: def.rarity,
        rolledStats: eq.baseStats,
      ),
    );
  }
}

({
  bool completed,
  int roomsCleared,
  int kills,
  int expGained,
  int goldGained,
  int finalLevel,
})
_runOnlineFourPiece({
  required GameConfig config,
  required int startLevel,
  required String specializationId,
  required List<String> setItemIds,
  required String dungeonId,
  required int seed,
}) {
  final character = PlayerCharacter(
    config: config.progression,
    progress: PlayerProgress(level: startLevel),
    skillCatalog: config.skills,
    specializationConfig: config.specializations,
    itemCatalog: config.items,
    mythicalForgeConfig: config.mythicalForge,
    statsCalculator: DerivedStatsCalculator(pctCaps: config.equipment.pctCaps),
    initialSpecializationId: specializationId,
  );
  _equipFullSet(character, config, setItemIds);

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

  manager.startDungeon(dungeonId, runId: 'online_4pc_$specializationId');
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
          damageCalculator: config.damage.createCalculator(),
          mechanics: config.difficulty.mechanics,
          seed: seed,
        )
        ..activeResonanceClassId = character.activeResonanceClassId
        ..activeFourPieceClassId = character.activeFourPieceClassId
        ..setPlayerSkills(
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
              dungeon: config.dungeons[dungeonId],
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
  );
}

void main() {
  late GameConfig config;

  setUpAll(() {
    config = _loadRealConfig();
  });

  group('Stage 3 — 4-Piece Set Resonance Combat Evolutions', () {
    late NavigationGrid grid;

    setUp(() {
      grid = NavigationGrid.fromAscii([
        '..........',
        '..........',
        '..........',
        '..........',
        '..........',
      ]);
    });

    test('Paladin 4-Piece: Holy Nova heal 6% Max HP, 60% DEF, dan cooldown 3.0 detik', () {
      final player = Combatant(
        id: 'player',
        team: Team.player,
        stats: const CombatStats(maxHp: 200, atk: 20, def: 100),
        cell: const GridPoint(2, 2),
      )..hp = 100;

      final sim =
          CombatSimulation(
              grid: grid,
              pathfinder: const AStarPathfinder(),
              player: player,
            )
            ..activeResonanceClassId = 'paladin'
            ..activeFourPieceClassId = 'paladin';

      sim.spawnEnemy(
        config.monsters.values.first,
        const GridPoint(3, 2),
        id: 'enemy_1',
        statsOverride: const CombatStats(
          maxHp: 5000,
          atk: 20,
          def: 0,
          attackSpeed: 1.0,
        ),
      );

      // Jalankan 75 tick (~3.75 detik): harus memicu 2x Holy Nova (tick ~1..20 dan tick ~61..75)
      for (var i = 0; i < 75; i++) {
        sim.tick();
      }

      final events = sim.drainEvents();
      final holyNovas = events
          .whereType<WeaponResonanceEvent>()
          .where((e) => e.trigger == WeaponResonanceTrigger.paladinHolyNova)
          .toList();
      final heals = events
          .whereType<HealEvent>()
          .where((e) => e.skillId == 'holy_nova')
          .toList();

      expect(holyNovas.length, 2);
      expect(holyNovas.first.value, (100 * 0.60).round());
      expect(heals.first.amount, (200 * 0.06).round());
    });

    test('Voidblade 4-Piece: Shadow Mark mengabaikan 100% DEF dan memberi Attack Speed frenzy', () {
      int damageWith({required String? fourPiece}) {
        final player = Combatant(
          id: 'player',
          team: Team.player,
          stats: const CombatStats(
            maxHp: 500,
            atk: 80,
            def: 10,
            critRate: 1.0,
            attackSpeed: 1.0,
          ),
          cell: const GridPoint(2, 2),
        );
        final sim =
            CombatSimulation(
                grid: grid,
                pathfinder: const AStarPathfinder(),
                player: player,
              )
              ..activeResonanceClassId = 'voidblade'
              ..activeFourPieceClassId = fourPiece;
        sim.spawnEnemy(
          config.monsters.values.first,
          const GridPoint(3, 2),
          id: 'tank_golem',
          statsOverride: const CombatStats(maxHp: 5000, atk: 5, def: 200),
        );

        // 45 tick -> 1st hit crit (Shadow Mark), 2nd hit True Damage + frenzy
        for (var i = 0; i < 45; i++) {
          sim.tick();
        }
        final trueHits = sim
            .drainEvents()
            .whereType<WeaponResonanceEvent>()
            .where(
              (e) => e.trigger == WeaponResonanceTrigger.voidbladeTrueDamage,
            )
            .toList();
        expect(trueHits, isNotEmpty);
        return trueHits.first.value;
      }

      final dmgOnePiece = damageWith(fourPiece: null);
      final dmgFourPiece = damageWith(fourPiece: 'voidblade');
      expect(dmgFourPiece, greaterThan(dmgOnePiece));
    });

    test('Chronomancer 4-Piece: Freeze tiap 3x skill dan beri +25% damage vulnerability (termasuk Boss)', () {
      final player = Combatant(
        id: 'player',
        team: Team.player,
        stats: const CombatStats(
          maxHp: 500,
          atk: 40,
          def: 20,
          skillHaste: 0.75,
        ),
        cell: const GridPoint(2, 2),
      );
      final sim =
          CombatSimulation(
              grid: grid,
              pathfinder: const AStarPathfinder(),
              player: player,
            )
            ..activeResonanceClassId = 'chronomancer'
            ..activeFourPieceClassId = 'chronomancer';
      final skill = config.skills['time_bolt']!;
      sim.setPlayerSkills([skill]);

      final boss = sim.spawnEnemy(
        config.monsters.values.first,
        const GridPoint(3, 2),
        id: 'boss_1',
        isBossOverride: true,
        statsOverride: const CombatStats(maxHp: 5000, atk: 1, def: 10),
      );

      var skillCasts = 0;
      for (var i = 0; i < 200; i++) {
        sim.tick();
        final events = sim.drainEvents();
        skillCasts += events.whereType<SkillCastEvent>().length;
        if (skillCasts >= 3) break;
      }

      expect(skillCasts, 3);
      // Boss tidak beku, tetapi tetap terkena vulnerability 4-piece!
      expect(boss.isFrozen, isFalse);
      expect(boss.chronoVulnerabilityTicks, greaterThan(0));
    });

    test('Gunslinger 4-Piece: Piercing beam memberi +25% bonus damage pada target kedua', () {
      int secondaryDamageWith({required String? fourPiece}) {
        final player = Combatant(
          id: 'player',
          team: Team.player,
          stats: const CombatStats(
            maxHp: 500,
            atk: 100,
            def: 10,
            attackRange: 6.0,
            critRate: 0.0,
          ),
          cell: const GridPoint(1, 2),
        );
        final sim =
            CombatSimulation(
                grid: grid,
                pathfinder: const AStarPathfinder(),
                player: player,
              )
              ..activeResonanceClassId = 'gunslinger'
              ..activeFourPieceClassId = fourPiece;
        sim.spawnEnemy(
          config.monsters.values.first,
          const GridPoint(3, 2),
          id: 'front',
          statsOverride: const CombatStats(maxHp: 5000, atk: 1, def: 0),
        );
        final back = sim.spawnEnemy(
          config.monsters.values.first,
          const GridPoint(5, 2),
          id: 'back',
          statsOverride: const CombatStats(maxHp: 5000, atk: 1, def: 0),
        );
        final beforeHp = back.hp;
        sim.tick();
        return beforeHp - back.hp;
      }

      final baseSecondary = secondaryDamageWith(fourPiece: null);
      final boostedSecondary = secondaryDamageWith(fourPiece: 'gunslinger');
      expect(boostedSecondary, greaterThan(baseSecondary));
    });

    test('Necromancer 4-Piece: Shadow Minion mewarisi 75% stat player dan bertahan 10 detik', () {
      final player = Combatant(
        id: 'player',
        team: Team.player,
        stats: const CombatStats(maxHp: 400, atk: 200, def: 40),
        cell: const GridPoint(2, 2),
      );
      final sim =
          CombatSimulation(
              grid: grid,
              pathfinder: const AStarPathfinder(),
              player: player,
            )
            ..activeResonanceClassId = 'necromancer'
            ..activeFourPieceClassId = 'necromancer';
      sim.spawnEnemy(
        config.monsters.values.first,
        const GridPoint(3, 2),
        id: 'm1',
        statsOverride: const CombatStats(maxHp: 20, atk: 1, def: 0),
      );

      for (var i = 0; i < 10; i++) {
        sim.tick();
      }
      expect(sim.allies, hasLength(1));
      final minion = sim.allies.first;
      expect(minion.stats.maxHp, (400 * 0.75).round());
      expect(minion.stats.atk, (200 * 0.75).round());
      expect(minion.lifetimeTicks, greaterThan(180));
    });

    test('Stormcaller 4-Piece: Chain Lightning menyambar +4 musuh & Shock +25% damage', () {
      final player = Combatant(
        id: 'player',
        team: Team.player,
        stats: const CombatStats(maxHp: 500, atk: 80, def: 20, critRate: 0.0),
        cell: const GridPoint(2, 2),
      );
      final sim =
          CombatSimulation(
              grid: grid,
              pathfinder: const AStarPathfinder(),
              player: player,
            )
            ..activeResonanceClassId = 'stormcaller'
            ..activeFourPieceClassId = 'stormcaller';

      sim.spawnEnemy(
        config.monsters.values.first,
        const GridPoint(3, 2),
        id: 'primary',
        statsOverride: const CombatStats(maxHp: 5000, atk: 1, def: 0),
      );
      for (var i = 0; i < 4; i++) {
        sim.spawnEnemy(
          config.monsters.values.first,
          GridPoint(4, i),
          id: 'extra_$i',
          statsOverride: const CombatStats(maxHp: 5000, atk: 1, def: 0),
        );
      }

      sim.tick();
      final chainHits = sim
          .drainEvents()
          .whereType<AttackEvent>()
          .where((e) => e.skillId == 'chain_lightning')
          .toList();
      expect(chainHits, hasLength(4));
      for (final enemy in sim.enemies) {
        expect(enemy.isShocked, isTrue);
      }
    });
  });

  group('Stage 3 — Online vs Offline Parity dengan 4-Piece Set', () {
    test('Paritas penuh Online vs Offline untuk 4-Piece Paladin & Voidblade di Forgotten Forest', () {
      final dungeon = config.dungeons['forgotten_forest']!;
      const runner = OfflineDungeonRunner();
      final window = const OfflineTimeCalculator().calculate(
        session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
        nowMs: 1000000 + const Duration(minutes: 10).inMilliseconds,
      );

      final scenarios = [
        (
          specId: 'paladin',
          items: [
            'dawns_aegis_blade',
            'dawns_aegis_helm',
            'dawns_aegis_cuirass',
            'dawns_aegis_signet',
          ],
          seed: 101,
        ),
        (
          specId: 'voidblade',
          items: [
            'shadowfang_twinblade',
            'shadowfang_cowl',
            'shadowfang_shroud',
            'shadowfang_ring',
          ],
          seed: 202,
        ),
      ];

      for (final s in scenarios) {
        final online = _runOnlineFourPiece(
          config: config,
          startLevel: 20,
          specializationId: s.specId,
          setItemIds: s.items,
          dungeonId: 'forgotten_forest',
          seed: s.seed,
        );

        final offChar = PlayerCharacter(
          config: config.progression,
          progress: const PlayerProgress(level: 20),
          skillCatalog: config.skills,
          specializationConfig: config.specializations,
          itemCatalog: config.items,
          mythicalForgeConfig: config.mythicalForge,
          statsCalculator: DerivedStatsCalculator(
            pctCaps: config.equipment.pctCaps,
          ),
          initialSpecializationId: s.specId,
        );
        _equipFullSet(offChar, config, s.items);
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
              runId: 'parity_4pc_${s.specId}',
              dungeonId: 'forgotten_forest',
              currentRoomId: dungeon.startRoomId,
              currentRoomIndex: 0,
              status: DungeonSessionStatus.inProgress,
            ),
            timeWindow: window,
            simulationSeed: s.seed,
          ),
        );

        expect(online.completed, isTrue, reason: s.specId);
        expect(offline.stopReason, OfflineDungeonStopReason.dungeonCompleted);
        expect(offline.runsCompleted, 1);
        expect(offline.roomsCleared, online.roomsCleared, reason: s.specId);
        expect(offline.encountersCleared, online.kills, reason: s.specId);
        expect(offline.expGained, online.expGained, reason: s.specId);
        expect(offline.goldGained, online.goldGained, reason: s.specId);
        expect(offChar.level, online.finalLevel, reason: s.specId);
      }
    });
  });
}
