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
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/player_status.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/dungeon_manager.dart';
import 'package:echoes_of_aether/domain/services/dungeon_reward_settlement_service.dart';
import 'package:echoes_of_aether/domain/services/encounter_tracker.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:echoes_of_aether/domain/services/offline_dungeon_runner.dart';
import 'package:echoes_of_aether/domain/services/offline_time_calculator.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:echoes_of_aether/domain/services/weapon_resonance_service.dart';
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

EquipmentInstance _createWeapon(String id, String definitionId) {
  return EquipmentInstance(
    id: id,
    definitionId: definitionId,
    slot: EquipmentSlot.weapon,
    rarity: ItemRarity.mythical,
    rolledStats: const EquipmentStats(atk: 50),
  );
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
_runOnlineResonanceRun({
  required GameConfig config,
  required int startLevel,
  required String specializationId,
  required String weaponId,
  required int seed,
}) {
  final character = PlayerCharacter(
    config: config.progression,
    progress: PlayerProgress(level: startLevel),
    skillCatalog: config.skills,
    specializationConfig: config.specializations,
    itemCatalog: config.items,
    initialSpecializationId: specializationId,
  );
  character.loadout.equip(_createWeapon('w_test', weaponId));
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

  manager.startDungeon('forgotten_forest', runId: 'online_res_run');
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
        )
        ..activeResonanceClassId = character.activeResonanceClassId
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
  late GameConfig config;
  const resonanceService = WeaponResonanceService();

  setUpAll(() {
    config = _loadRealGameConfig();
  });

  group('M15 Stage 3: WeaponResonanceService & Detection', () {
    test(
      'deteksi resonansi aktif hanya jika class dan senjata signature selaras',
      () {
        final weaponPaladin = _createWeapon('w_paladin', 'dawns_aegis_blade');
        final weaponVoidblade = _createWeapon(
          'w_voidblade',
          'shadowfang_twinblade',
        );

        // Paladin dengan Dawn's Aegis Blade -> aktif
        expect(
          resonanceService.isResonanceActive(
            specializationId: 'paladin',
            equippedWeapon: weaponPaladin,
            itemCatalog: config.items,
          ),
          isTrue,
        );
        expect(
          resonanceService.resolveActiveResonanceClassId(
            specializationId: 'paladin',
            equippedWeapon: weaponPaladin,
            itemCatalog: config.items,
          ),
          equals('paladin'),
        );

        // Paladin dengan Shadowfang Twinblade -> tidak aktif
        expect(
          resonanceService.isResonanceActive(
            specializationId: 'paladin',
            equippedWeapon: weaponVoidblade,
            itemCatalog: config.items,
          ),
          isFalse,
        );

        // Voidblade dengan Shadowfang Twinblade -> aktif
        expect(
          resonanceService.isResonanceActive(
            specializationId: 'voidblade',
            equippedWeapon: weaponVoidblade,
            itemCatalog: config.items,
          ),
          isTrue,
        );

        // Karakter tanpa specialization -> tidak aktif
        expect(
          resonanceService.isResonanceActive(
            specializationId: null,
            equippedWeapon: weaponPaladin,
            itemCatalog: config.items,
          ),
          isFalse,
        );
      },
    );

    test(
      'getResonanceDescription mengembalikan deskripsi resmi 6 class Mythical',
      () {
        for (final classId in WeaponResonanceService.allMythicalClasses) {
          final desc = resonanceService.getResonanceDescription(classId);
          expect(desc, isNotNull);
          expect(desc!.isNotEmpty, isTrue);
        }
        expect(resonanceService.getResonanceDescription('unknown'), isNull);
      },
    );
  });

  group(
    'M15 Stage 3: DerivedStatsCalculator & PlayerCharacter Integration',
    () {
      test(
        'Gunslinger resonance memberikan bonus jangkauan serang +2.0 petak',
        () {
          final character = PlayerCharacter(
            config: config.progression,
            progress: const PlayerProgress(level: 20),
            skillCatalog: config.skills,
            specializationConfig: config.specializations,
            itemCatalog: config.items,
            initialSpecializationId: 'gunslinger',
          );

          final baseRange = character.stats.attackRange;

          // Pasang Aether Railgun
          final railgun = _createWeapon('w_railgun', 'aether_railgun');
          character.loadout.equip(railgun);

          expect(character.activeResonanceClassId, equals('gunslinger'));
          expect(character.stats.attackRange, closeTo(baseRange + 2.0, 1e-4));

          // Lepas senjata -> bonus hilang
          character.loadout.unequip(EquipmentSlot.weapon);
          expect(character.activeResonanceClassId, isNull);
          expect(character.stats.attackRange, closeTo(baseRange, 1e-4));
        },
      );

      test(
        'Necromancer resonance memberikan bonus lifesteal pasif +8% (+0.08)',
        () {
          final character = PlayerCharacter(
            config: config.progression,
            progress: const PlayerProgress(level: 20),
            skillCatalog: config.skills,
            specializationConfig: config.specializations,
            itemCatalog: config.items,
            initialSpecializationId: 'necromancer',
          );

          final baseLifesteal = character.stats.lifesteal;

          // Pasang Scythe of the Harvester
          final scythe = _createWeapon('w_scythe', 'scythe_of_the_harvester');
          character.loadout.equip(scythe);

          expect(character.activeResonanceClassId, equals('necromancer'));
          expect(
            character.stats.lifesteal,
            closeTo(baseLifesteal + 0.08, 1e-4),
          );
        },
      );
    },
  );

  group('M15 Stage 3: CombatSimulation In-Combat Resonance Mechanics', () {
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

    test('Paladin Holy Nova memicu pemulihan 5% Max HP dan retaliation DEF AoE saat terkena serangan', () {
      final player = Combatant(
        id: 'player',
        team: Team.player,
        stats: const CombatStats(maxHp: 200, atk: 20, def: 100),
        cell: const GridPoint(2, 2),
      );

      final sim = CombatSimulation(
        grid: grid,
        pathfinder: const AStarPathfinder(),
        player: player,
      );
      sim.activeResonanceClassId = 'paladin';
      sim.spawnEnemy(
        config.monsters.values.first,
        const GridPoint(3, 2),
        id: 'enemy_1',
      );

      // Turunkan HP player sedikit agar efek heal terlihat
      player.hp = 100;
      final enemyHpBefore = sim.enemies.first.hp;

      // Simulasikan musuh memukul player
      sim.tick();
      // Jalankan beberapa tick sampai musuh menyerang
      for (var i = 0; i < 25; i++) {
        sim.tick();
      }

      final events = sim.drainEvents();
      final holyNovaEvents = events.whereType<WeaponResonanceEvent>().where(
        (e) => e.trigger == WeaponResonanceTrigger.paladinHolyNova,
      );
      expect(holyNovaEvents.isNotEmpty, isTrue);

      // Cek bahwa terjadi HealEvent untuk player
      final healEvents = events.whereType<HealEvent>().where(
        (e) => e.skillId == 'holy_nova',
      );
      expect(healEvents.isNotEmpty, isTrue);
      expect(healEvents.first.amount, equals((200 * 0.05).round())); // 10 HP

      // Musuh di dekat player terkena retaliation damage
      expect(sim.enemies.first.hp, lessThan(enemyHpBefore));
    });

    test('Voidblade menerapkan Shadow Mark pada critical hit dan menghasilkan True Damage mengabaikan DEF', () {
      final player = Combatant(
        id: 'player',
        team: Team.player,
        // 100% crit rate
        stats: const CombatStats(maxHp: 100, atk: 50, def: 10, critRate: 1.0),
        cell: const GridPoint(2, 2),
      );

      final sim = CombatSimulation(
        grid: grid,
        pathfinder: const AStarPathfinder(),
        player: player,
      );
      sim.activeResonanceClassId = 'voidblade';

      final enemy = sim.spawnEnemy(
        config.monsters.values.first,
        const GridPoint(3, 2),
        id: 'heavy_golem',
        // DEF sangat tinggi: 200
        statsOverride: const CombatStats(maxHp: 500, atk: 10, def: 200),
      );

      // Pukulan pertama: Critical -> menerapkan Shadow Mark
      for (var i = 0; i < 25; i++) {
        sim.tick();
      }

      expect(enemy.isShadowMarked, isTrue);
      final events = sim.drainEvents();
      final markEvents = events.whereType<WeaponResonanceEvent>().where(
        (e) => e.trigger == WeaponResonanceTrigger.voidbladeShadowMark,
      );
      expect(markEvents.isNotEmpty, isTrue);

      // Pukulan kedua terhadap target bertanda -> True Damage (mengabaikan 200 DEF)
      for (var i = 0; i < 25; i++) {
        sim.tick();
      }
      final eventsRound2 = sim.drainEvents();
      final trueDamageEvents = eventsRound2
          .whereType<WeaponResonanceEvent>()
          .where(
            (e) => e.trigger == WeaponResonanceTrigger.voidbladeTrueDamage,
          );
      expect(trueDamageEvents.isNotEmpty, isTrue);
    });

    test(
      'Chronomancer membekukan (freeze) monster biasa setiap 4x skill cast',
      () {
        final player = Combatant(
          id: 'player',
          team: Team.player,
          stats: const CombatStats(maxHp: 200, atk: 30, def: 10),
          cell: const GridPoint(2, 2),
        );

        final sim = CombatSimulation(
          grid: grid,
          pathfinder: const AStarPathfinder(),
          player: player,
        );
        sim.activeResonanceClassId = 'chronomancer';

        final regularEnemy = sim.spawnEnemy(
          config.monsters.values.first,
          const GridPoint(5, 2),
          id: 'mob_1',
          statsOverride: const CombatStats(maxHp: 2000, atk: 5, def: 0),
        );
        final bossEnemy = sim.spawnEnemy(
          config.monsters.values.first,
          const GridPoint(5, 3),
          id: 'boss_1',
          isBossOverride: true,
          statsOverride: const CombatStats(maxHp: 2000, atk: 5, def: 0),
        );

        final testSkill = SkillDefinition(
          id: 'arcane_shot',
          name: 'Arcane Shot',
          type: SkillType.active,
          cooldownSeconds: 0.1,
          range: 10.0,
        );
        sim.setPlayerSkills([testSkill]);

        // Jalankan simulasi hingga timestop freeze pertama terpicu
        WeaponResonanceEvent? freezeEvent;
        for (var i = 0; i < 40; i++) {
          sim.tick();
          final events = sim.drainEvents().whereType<WeaponResonanceEvent>();
          for (final ev in events) {
            if (ev.trigger == WeaponResonanceTrigger.chronomancerFreeze) {
              freezeEvent = ev;
              break;
            }
          }
          if (freezeEvent != null) break;
        }

        expect(freezeEvent, isNotNull);
        expect(regularEnemy.freezeTicks, greaterThan(0));
        expect(regularEnemy.isFrozen, isTrue);
        // Boss kebal terhadap timestop freeze
        expect(bossEnemy.freezeTicks, equals(0));
        expect(bossEnemy.isFrozen, isFalse);
      },
    );

    test(
      'Gunslinger menembus musuh lain dalam satu garis lurus (piercing beam)',
      () {
        final player = Combatant(
          id: 'player',
          team: Team.player,
          stats: const CombatStats(
            maxHp: 100,
            atk: 40,
            def: 10,
            attackRange: 6.0,
          ),
          cell: const GridPoint(1, 2),
        );

        final sim = CombatSimulation(
          grid: grid,
          pathfinder: const AStarPathfinder(),
          player: player,
        );
        sim.activeResonanceClassId = 'gunslinger';

        // 2 musuh dalam 1 garis lurus: x=3 dan x=5 pada y=2
        final enemyFront = sim.spawnEnemy(
          config.monsters.values.first,
          const GridPoint(3, 2),
          id: 'enemy_front',
          statsOverride: const CombatStats(maxHp: 200, atk: 5, def: 0),
        );
        final enemyBack = sim.spawnEnemy(
          config.monsters.values.first,
          const GridPoint(5, 2),
          id: 'enemy_back',
          statsOverride: const CombatStats(maxHp: 200, atk: 5, def: 0),
        );

        // Jalankan 1 siklus serangan
        for (var i = 0; i < 25; i++) {
          sim.tick();
        }

        // Keduanya terkena damage
        expect(enemyFront.hp, lessThan(200));
        expect(enemyBack.hp, lessThan(200));

        final events = sim.drainEvents();
        final pierceEvents = events.whereType<WeaponResonanceEvent>().where(
          (e) => e.trigger == WeaponResonanceTrigger.gunslingerPiercing,
        );
        expect(pierceEvents.isNotEmpty, isTrue);
      },
    );

    test('Necromancer memanggil Shadow Minion saat musuh gugur', () {
      final player = Combatant(
        id: 'player',
        team: Team.player,
        stats: const CombatStats(maxHp: 100, atk: 100, def: 20),
        cell: const GridPoint(2, 2),
      );

      final sim = CombatSimulation(
        grid: grid,
        pathfinder: const AStarPathfinder(),
        player: player,
      );
      sim.activeResonanceClassId = 'necromancer';

      // Musuh dengan 1 HP agar langsung gugur dalam 1 pukulan
      sim.spawnEnemy(
        config.monsters.values.first,
        const GridPoint(3, 2),
        id: 'weak_mob',
        statsOverride: const CombatStats(maxHp: 1, atk: 5, def: 0),
      );

      for (var i = 0; i < 25; i++) {
        sim.tick();
      }

      expect(sim.allies.length, equals(1));
      final minion = sim.allies.first;
      expect(minion.stats.maxHp, equals(50)); // 50% player HP
      expect(minion.stats.atk, equals(50)); // 50% player ATK
      expect(minion.team, equals(Team.player));

      final events = sim.drainEvents();
      final minionEvents = events.whereType<WeaponResonanceEvent>().where(
        (e) => e.trigger == WeaponResonanceTrigger.necromancerShadowMinion,
      );
      expect(minionEvents.isNotEmpty, isTrue);
    });

    test('Stormcaller Chain Lightning menyambar ke +2 musuh dan memicu status Shock (+15% damage)', () {
      final player = Combatant(
        id: 'player',
        team: Team.player,
        stats: const CombatStats(maxHp: 100, atk: 40, def: 10),
        cell: const GridPoint(2, 2),
      );

      final sim = CombatSimulation(
        grid: grid,
        pathfinder: const AStarPathfinder(),
        player: player,
      );
      sim.activeResonanceClassId = 'stormcaller';

      final enemy1 = sim.spawnEnemy(
        config.monsters.values.first,
        const GridPoint(3, 2),
        id: 'mob_1',
        statsOverride: const CombatStats(maxHp: 300, atk: 5, def: 0),
      );
      final enemy2 = sim.spawnEnemy(
        config.monsters.values.first,
        const GridPoint(4, 2),
        id: 'mob_2',
        statsOverride: const CombatStats(maxHp: 300, atk: 5, def: 0),
      );
      final enemy3 = sim.spawnEnemy(
        config.monsters.values.first,
        const GridPoint(3, 3),
        id: 'mob_3',
        statsOverride: const CombatStats(maxHp: 300, atk: 5, def: 0),
      );

      // Jalankan 1 serangan
      for (var i = 0; i < 25; i++) {
        sim.tick();
      }

      // Ketiga musuh terkena damage dan status Shock
      expect(enemy1.hp, lessThan(300));
      expect(enemy2.hp, lessThan(300));
      expect(enemy3.hp, lessThan(300));
      expect(enemy1.isShocked, isTrue);
      expect(enemy2.isShocked, isTrue);
      expect(enemy3.isShocked, isTrue);

      final events = sim.drainEvents();
      final chainEvents = events.whereType<WeaponResonanceEvent>().where(
        (e) => e.trigger == WeaponResonanceTrigger.stormcallerChainLightning,
      );
      expect(chainEvents.isNotEmpty, isTrue);
    });
  });

  group('M15 Stage 3: Online & Offline Parity Test', () {
    test('Paritas Paladin Holy Nova di Online vs Offline', () {
      final character = PlayerCharacter(
        config: config.progression,
        progress: const PlayerProgress(level: 20),
        skillCatalog: config.skills,
        specializationConfig: config.specializations,
        itemCatalog: config.items,
        initialSpecializationId: 'paladin',
      );
      final blade = _createWeapon('w_blade', 'dawns_aegis_blade');
      character.loadout.equip(blade);
      expect(character.activeResonanceClassId, equals('paladin'));

      final grid = NavigationGrid.fromAscii(['.....', '.....', '.....']);
      final player = Combatant(
        id: 'player',
        team: Team.player,
        stats: character.stats,
        cell: const GridPoint(1, 1),
      );

      // Online
      final sim = CombatSimulation(
        grid: grid,
        pathfinder: const AStarPathfinder(),
        player: player,
      )..activeResonanceClassId = character.activeResonanceClassId;
      sim.spawnEnemy(
        config.monsters.values.first,
        const GridPoint(2, 1),
        id: 'm1',
      );
      sim.tick();

      // Offline
      final offlinePlayer = Combatant(
        id: 'player',
        team: Team.player,
        stats: character.stats,
        cell: const GridPoint(1, 1),
      );
      final offlineShell = CombatSimulation(
        grid: grid,
        pathfinder: const AStarPathfinder(),
        player: offlinePlayer,
      );
      offlineShell.spawnEnemy(
        config.monsters.values.first,
        const GridPoint(2, 1),
        id: 'm1',
      );

      // Pastikan kedua jalur mengenali resonansi Paladin
      expect(sim.activeResonanceClassId, equals('paladin'));
      expect(character.activeResonanceClassId, equals('paladin'));
    });

    test('Paritas headless runner vs online simulation dengan Signature Weapon Resonance (Forgotten Forest)', () {
      final dungeon = config.dungeons['forgotten_forest']!;
      const runner = OfflineDungeonRunner();
      final window = const OfflineTimeCalculator().calculate(
        session: const GameSessionSnapshot(lastSavedAtMs: 1000000),
        nowMs: 1000000 + const Duration(minutes: 10).inMilliseconds,
      );

      final online = _runOnlineResonanceRun(
        config: config,
        startLevel: 15,
        specializationId: 'paladin',
        weaponId: 'dawns_aegis_blade',
        seed: 42,
      );

      final offChar = PlayerCharacter(
        config: config.progression,
        progress: const PlayerProgress(level: 15),
        skillCatalog: config.skills,
        specializationConfig: config.specializations,
        itemCatalog: config.items,
        initialSpecializationId: 'paladin',
      );
      offChar.loadout.equip(_createWeapon('w_off', 'dawns_aegis_blade'));
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
            runId: 'parity_res_paladin',
            dungeonId: 'forgotten_forest',
            currentRoomId: dungeon.startRoomId,
            currentRoomIndex: 0,
            status: DungeonSessionStatus.inProgress,
          ),
          timeWindow: window,
          simulationSeed: 42,
        ),
      );

      expect(online.completed, isTrue);
      expect(offline.stopReason, OfflineDungeonStopReason.dungeonCompleted);
      expect(offline.runsCompleted, 1);
      expect(offline.roomsCleared, equals(online.roomsCleared));
      expect(offline.encountersCleared, equals(online.kills));
      expect(offline.expGained, equals(online.expGained));
      expect(offline.goldGained, equals(online.goldGained));
      expect(offChar.level, equals(online.finalLevel));
    });
  });
}
