import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/combatant.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/room_encounter.dart';
import 'package:echoes_of_aether/domain/services/astar_pathfinder.dart';
import 'package:echoes_of_aether/domain/services/combat_simulation.dart';
import 'package:echoes_of_aether/domain/services/dungeon_manager.dart';
import 'package:echoes_of_aether/domain/services/encounter_tracker.dart';
import 'package:echoes_of_aether/domain/services/navigation_grid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const layout = <String>[
    '###########',
    '#.........#',
    '#.........#',
    '#.........#',
    '#.........#',
    '###########',
  ];

  const monsters = <String, EnemyDefinition>{
    'aether_slime': EnemyDefinition(
      id: 'aether_slime',
      name: 'Aether Slime',
      level: 1,
      detectionRange: 8,
      stats: CombatStats(maxHp: 50, atk: 5, def: 1, attackRange: 1),
      expReward: 12,
      goldReward: 4,
      lootTableId: 'aether_slime_loot',
    ),
    'forest_wolf': EnemyDefinition(
      id: 'forest_wolf',
      name: 'Forest Wolf',
      level: 2,
      detectionRange: 9,
      stats: CombatStats(maxHp: 75, atk: 9, def: 1, attackRange: 1),
      expReward: 20,
      goldReward: 7,
      lootTableId: 'forest_wolf_loot',
    ),
    'corrupted_guardian': EnemyDefinition(
      id: 'corrupted_guardian',
      name: 'Corrupted Guardian',
      level: 4,
      isElite: true,
      detectionRange: 9,
      stats: CombatStats(maxHp: 180, atk: 14, def: 4, attackRange: 1.2),
      expReward: 55,
      goldReward: 20,
      lootTableId: 'elite_loot',
    ),
    'ancient_heart_guardian': EnemyDefinition(
      id: 'ancient_heart_guardian',
      name: 'Ancient Heart Guardian',
      level: 6,
      isBoss: true,
      detectionRange: 10,
      stats: CombatStats(maxHp: 420, atk: 20, def: 6, attackRange: 1.5),
      expReward: 180,
      goldReward: 75,
      lootTableId: 'boss_loot',
    ),
  };

  CombatSimulation makeSim(NavigationGrid grid) {
    final player = Combatant(
      id: 'player',
      team: Team.player,
      stats: const CombatStats(
        maxHp: 300,
        atk: 60,
        def: 10,
        attackSpeed: 2,
        moveSpeed: 5,
        attackRange: 1.5,
      ),
      cell: const GridPoint(1, 2),
    );
    return CombatSimulation(
      grid: grid,
      pathfinder: const AStarPathfinder(),
      player: player,
      seed: 1,
    );
  }

  group('EncounterTracker — Spawn & Activation', () {
    test('spawn group valid menghasilkan jumlah, ID unik, posisi valid, dan menerapkan SpawnStatModifier', () {
      const room = RoomDefinition(
        id: 'forest_entrance',
        dungeonId: 'forgotten_forest',
        name: 'Forest Entrance',
        type: RoomType.normal,
        mapRef: 'fe_map',
        layout: layout,
        entryPosition: GridPoint(1, 2),
        exitPosition: GridPoint(9, 2),
        spawns: [
          RoomSpawnConfig(
            id: 'slime_pack',
            monsterId: 'aether_slime',
            position: GridPoint(5, 2),
            quantity: 3,
            spawnGroup: 'wave_1',
            statModifier: SpawnStatModifier(
              hpMultiplier: 1.5,
              atkBonus: 3,
              defBonus: 2,
            ),
          ),
        ],
        completionCondition: RoomCompletionCondition(),
      );

      final grid = room.createNavigationGrid();
      final sim = makeSim(grid);
      final tracker = EncounterTracker(monsterCatalog: monsters);
      tracker.prepareRoom(room);

      // Sebelum room diaktifkan, immediate (onRoomActivated) tidak spawn.
      expect(tracker.onRoomLoaded(sim, grid: grid), isEmpty);
      expect(sim.enemies, isEmpty);
      expect(tracker.encounters.single.status, EncounterStatus.pending);

      final spawned = tracker.onRoomActivated(sim, grid: grid);
      expect(spawned, hasLength(3));
      expect(sim.enemies, hasLength(3));

      final ids = sim.enemies.map((e) => e.id).toSet();
      expect(ids, {
        'forest_entrance__slime_pack__0',
        'forest_entrance__slime_pack__1',
        'forest_entrance__slime_pack__2',
      });

      // Posisi tidak menumpuk pada satu sel dan seluruhnya walkable.
      final cells = sim.enemies.map((e) => e.follower.currentCell).toSet();
      expect(cells, hasLength(3));
      for (final cell in cells) {
        expect(grid.isWalkable(cell.x, cell.y), isTrue);
      }

      // Modifier diterapkan ke stat enemy tanpa mengubah definisi asal.
      for (final enemy in sim.enemies) {
        expect(enemy.stats.maxHp, 75); // 50 * 1.5
        expect(enemy.stats.atk, 8); // 5 + 3
        expect(enemy.stats.def, 3); // 1 + 2
      }
      expect(monsters['aether_slime']!.stats.maxHp, 50);

      // Duplicate activation tidak menghasilkan monster tambahan.
      expect(tracker.onRoomActivated(sim, grid: grid), isEmpty);
      expect(sim.enemies, hasLength(3));
    });

    test('mendukung policy immediate onRoomLoaded, trigger on_group_cleared, dan manual secara idempotent', () {
      const room = RoomDefinition(
        id: 'ruined_shrine',
        dungeonId: 'forgotten_forest',
        name: 'Ruined Shrine',
        type: RoomType.normal,
        mapRef: 'rs_map',
        layout: layout,
        entryPosition: GridPoint(1, 2),
        exitPosition: GridPoint(9, 2),
        spawns: [
          RoomSpawnConfig(
            id: 'wave_a',
            monsterId: 'aether_slime',
            position: GridPoint(4, 2),
            spawnGroup: 'alpha',
            activationState: SpawnActivationState.immediate,
          ),
          RoomSpawnConfig(
            id: 'wave_b',
            monsterId: 'forest_wolf',
            position: GridPoint(7, 2),
            spawnGroup: 'beta',
            activationState: SpawnActivationState.onGroupCleared,
            activationTriggerGroup: 'alpha',
          ),
          RoomSpawnConfig(
            id: 'ambush_manual',
            monsterId: 'forest_wolf',
            position: GridPoint(8, 3),
            spawnGroup: 'ambush',
            required: false,
            activationState: SpawnActivationState.manual,
          ),
        ],
        completionCondition: RoomCompletionCondition(),
      );

      final grid = room.createNavigationGrid();
      final sim = makeSim(grid);
      final tracker = EncounterTracker(
        monsterCatalog: monsters,
        immediateSpawnPhase: ImmediateSpawnPhase.onRoomLoaded,
      );
      final events = <EncounterEvent>[];
      tracker.addListener(events.add);

      tracker.prepareRoom(room);
      final onLoad = tracker.onRoomLoaded(sim, grid: grid);
      expect(onLoad, hasLength(1));
      expect(onLoad.single.monsterId, 'aether_slime');
      expect(tracker.onRoomActivated(sim, grid: grid), isEmpty);

      // Wave B & manual masih pending.
      expect(
        tracker.encounterForSpawnConfig('wave_b')?.status,
        EncounterStatus.pending,
      );
      expect(
        tracker.encounterForSpawnConfig('ambush_manual')?.status,
        EncounterStatus.pending,
      );

      // Mengalahkan wave_a memicu wave_b otomatis sekali.
      final triggered = tracker.onEnemyDefeated(
        onLoad.single.enemyId,
        simulation: sim,
        grid: grid,
      );
      expect(triggered, hasLength(1));
      expect(triggered.single.monsterId, 'forest_wolf');
      expect(events.whereType<SpawnGroupCompletedEvent>(), hasLength(1));
      expect(
        tracker.encounterForSpawnConfig('wave_b')?.status,
        EncounterStatus.active,
      );

      // Trigger manual berjalan sekali lalu idempotent.
      final manualSpawned = tracker.triggerManualSpawn(
        'ambush_manual',
        simulation: sim,
        grid: grid,
      );
      expect(manualSpawned, hasLength(1));
      expect(
        tracker.triggerManualSpawn(
          'ambush_manual',
          simulation: sim,
          grid: grid,
        ),
        isEmpty,
      );
    });

    test('spawn gagal (monster tidak ditemukan / posisi tidak walkable) ditangani aman tanpa merusak encounter lain', () {
      const room = RoomDefinition(
        id: 'bad_room',
        dungeonId: 'forgotten_forest',
        name: 'Bad Room',
        type: RoomType.normal,
        mapRef: 'bad_map',
        layout: layout,
        entryPosition: GridPoint(1, 2),
        exitPosition: GridPoint(9, 2),
        spawns: [
          RoomSpawnConfig(
            id: 'missing_monster',
            monsterId: 'ghost_nonexistent',
            position: GridPoint(5, 2),
          ),
          RoomSpawnConfig(
            id: 'wall_spawn',
            monsterId: 'aether_slime',
            position: GridPoint(0, 0),
          ),
          RoomSpawnConfig(
            id: 'valid_slime',
            monsterId: 'aether_slime',
            position: GridPoint(6, 2),
          ),
        ],
        completionCondition: RoomCompletionCondition(),
      );

      final grid = room.createNavigationGrid();
      final sim = makeSim(grid);
      final tracker = EncounterTracker(monsterCatalog: monsters);
      final failedEvents = <EncounterSpawnFailedEvent>[];
      tracker.addListener((e) {
        if (e is EncounterSpawnFailedEvent) failedEvents.add(e);
      });

      tracker.prepareRoom(room);
      final spawned = tracker.onRoomActivated(sim, grid: grid);

      expect(spawned, hasLength(1));
      expect(spawned.single.monsterId, 'aether_slime');
      expect(sim.enemies, hasLength(1));
      expect(failedEvents, hasLength(2));

      final missingEnc = tracker.encounterForSpawnConfig('missing_monster')!;
      expect(missingEnc.status, EncounterStatus.failed);
      expect(missingEnc.spawnedCount, 0);
      expect(missingEnc.activeCount, 0);
      expect(missingEnc.defeatedCount, 0);
      expect(missingEnc.lastError, isNotNull);

      final wallEnc = tracker.encounterForSpawnConfig('wall_spawn')!;
      expect(wallEnc.status, EncounterStatus.failed);
    });
  });

  group('EncounterTracker — Tracking, Duplicate Guard & Cleanup Safety', () {
    test('duplicate death event, unspawned enemy, cleanup room, dan onRunFailed tidak menggandakan defeatedCount', () {
      const room = RoomDefinition(
        id: 'forest_entrance',
        dungeonId: 'forgotten_forest',
        name: 'Forest Entrance',
        type: RoomType.normal,
        mapRef: 'fe_map',
        layout: layout,
        entryPosition: GridPoint(1, 2),
        exitPosition: GridPoint(9, 2),
        spawns: [
          RoomSpawnConfig(
            id: 'group_1',
            monsterId: 'aether_slime',
            position: GridPoint(4, 2),
            quantity: 2,
            spawnGroup: 'g1',
          ),
          RoomSpawnConfig(
            id: 'group_2',
            monsterId: 'forest_wolf',
            position: GridPoint(7, 2),
            spawnGroup: 'g2',
            activationState: SpawnActivationState.manual,
          ),
        ],
        completionCondition: RoomCompletionCondition(),
      );

      final grid = room.createNavigationGrid();
      final sim = makeSim(grid);
      final tracker = EncounterTracker(monsterCatalog: monsters);
      final events = <EncounterEvent>[];
      tracker.addListener(events.add);

      tracker.prepareRoom(room);
      final spawned = tracker.onRoomActivated(sim, grid: grid);
      expect(spawned, hasLength(2));

      // Musuh yang belum di-spawn atau ID asing tidak dihitung sebagai defeated.
      tracker.onEnemyDefeated('forest_entrance__group_2__0');
      tracker.onEnemyDefeated('unknown_enemy');
      expect(tracker.totalDefeatedEnemies, 0);
      expect(tracker.totalActiveEnemies, 2);

      // Kematian pertama valid; event duplikat untuk enemyId sama diabaikan.
      tracker.onEnemyDefeated(spawned.first.enemyId);
      tracker.onEnemyDefeated(spawned.first.enemyId);
      expect(tracker.totalDefeatedEnemies, 1);
      expect(tracker.totalActiveEnemies, 1);
      expect(
        tracker.encounterForSpawnConfig('group_1')!.status,
        EncounterStatus.active,
      );

      // onRunFailed menandai encounter tersisa sebagai failed tanpa menambah kill.
      tracker.onRunFailed();
      expect(tracker.totalDefeatedEnemies, 1);
      expect(
        tracker.encounterForSpawnConfig('group_1')!.status,
        EncounterStatus.failed,
      );
      expect(
        tracker.encounterForSpawnConfig('group_2')!.status,
        EncounterStatus.failed,
      );

      // Cleanup room tidak memicu EncounterCompletedEvent atau RoomEncountersCompletedEvent.
      tracker.clearRoom();
      expect(events.whereType<EncounterCompletedEvent>(), isEmpty);
      expect(events.whereType<RoomEncountersCompletedEvent>(), isEmpty);
      expect(tracker.encounters, isEmpty);
    });

    test('RoomEncountersCompletedEvent dikirim sekali saat seluruh encounter wajib selesai', () {
      const room = RoomDefinition(
        id: 'ancient_path',
        dungeonId: 'forgotten_forest',
        name: 'Ancient Path',
        type: RoomType.normal,
        mapRef: 'ap_map',
        layout: layout,
        entryPosition: GridPoint(1, 2),
        exitPosition: GridPoint(9, 2),
        spawns: [
          RoomSpawnConfig(
            id: 'req_1',
            monsterId: 'aether_slime',
            position: GridPoint(4, 2),
            spawnGroup: 'main',
            required: true,
          ),
          RoomSpawnConfig(
            id: 'opt_1',
            monsterId: 'forest_wolf',
            position: GridPoint(7, 2),
            spawnGroup: 'optional',
            required: false,
          ),
        ],
        completionCondition: RoomCompletionCondition(),
      );

      final grid = room.createNavigationGrid();
      final sim = makeSim(grid);
      final tracker = EncounterTracker(monsterCatalog: monsters);
      final roomDoneEvents = <RoomEncountersCompletedEvent>[];
      tracker.addListener((e) {
        if (e is RoomEncountersCompletedEvent) roomDoneEvents.add(e);
      });

      tracker.prepareRoom(room);
      tracker.onRoomActivated(sim, grid: grid);

      expect(tracker.allRequiredEncountersCompleted, isFalse);
      tracker.onEnemyDefeated('ancient_path__req_1__0');

      expect(tracker.allRequiredEncountersCompleted, isTrue);
      expect(tracker.allEncountersCompleted, isFalse);
      expect(roomDoneEvents, hasLength(1));

      // Mengalahkan enemy opsional tidak mengirim event penyelesaian room dua kali.
      tracker.onEnemyDefeated('ancient_path__opt_1__0');
      expect(roomDoneEvents, hasLength(1));
      expect(tracker.allEncountersCompleted, isTrue);
    });
  });

  group('EncounterTracker — Elite & Boss Encounter Setup', () {
    test('Corrupted Guardian teridentifikasi sebagai elite dan tidak di-spawn melebihi konfigurasi', () {
      const eliteRoom = RoomDefinition(
        id: 'hidden_chamber',
        dungeonId: 'forgotten_forest',
        name: 'Hidden Chamber',
        type: RoomType.elite,
        mapRef: 'hc_map',
        layout: layout,
        entryPosition: GridPoint(1, 2),
        exitPosition: GridPoint(9, 2),
        spawns: [
          RoomSpawnConfig(
            id: 'hc_elite_guardian',
            monsterId: 'corrupted_guardian',
            position: GridPoint(7, 2),
            quantity: 1,
            spawnGroup: 'elite_guardian',
            isElite: true,
            required: true,
          ),
        ],
        completionCondition: RoomCompletionCondition(
          type: RoomCompletionConditionType.defeatElite,
          requiredSpawnGroup: 'elite_guardian',
        ),
      );

      final grid = eliteRoom.createNavigationGrid();
      final sim = makeSim(grid);
      final tracker = EncounterTracker(monsterCatalog: monsters);
      final manager = DungeonManager(
        dungeons: {
          'forgotten_forest': const DungeonDefinition(
            id: 'forgotten_forest',
            name: 'Forgotten Forest',
            biome: 'forgotten_forest',
            startRoomId: 'hidden_chamber',
            rooms: {'hidden_chamber': eliteRoom},
            roomOrder: ['hidden_chamber'],
          ),
        },
        encounterTracker: tracker,
      );

      manager.startDungeon('forgotten_forest');
      manager.activateRoom();
      tracker.onRoomActivated(sim, grid: grid);
      tracker.onRoomActivated(sim, grid: grid);

      expect(sim.enemies, hasLength(1));
      final elite = sim.enemies.single;
      expect(elite.isElite, isTrue);
      expect(elite.isBoss, isFalse);
      expect(tracker.hasEliteEncounter, isTrue);
      expect(tracker.hasBossEncounter, isFalse);
      expect(tracker.eliteEncounters, hasLength(1));
      expect(tracker.allRequiredElitesDefeated, isFalse);

      tracker.onEnemyDefeated(elite.id);
      expect(tracker.allRequiredElitesDefeated, isTrue);
      expect(tracker.allRequiredEncountersCompleted, isTrue);
    });

    test('Ancient Heart Guardian teridentifikasi sebagai boss, terpisah dari monster normal, dan tidak terduplikasi saat reload', () {
      const bossRoom = RoomDefinition(
        id: 'ancient_heart',
        dungeonId: 'forgotten_forest',
        name: 'Ancient Heart',
        type: RoomType.boss,
        mapRef: 'ah_map',
        layout: layout,
        entryPosition: GridPoint(1, 2),
        exitPosition: GridPoint(9, 2),
        spawns: [
          RoomSpawnConfig(
            id: 'ah_adds',
            monsterId: 'aether_slime',
            position: GridPoint(5, 2),
            spawnGroup: 'boss_adds',
            required: false,
          ),
          RoomSpawnConfig(
            id: 'ah_boss_guardian',
            monsterId: 'ancient_heart_guardian',
            position: GridPoint(8, 2),
            quantity: 1,
            spawnGroup: 'boss_ancient_heart',
            isBoss: true,
            required: true,
          ),
        ],
        completionCondition: RoomCompletionCondition(
          type: RoomCompletionConditionType.defeatBoss,
          requiredSpawnGroup: 'boss_ancient_heart',
        ),
      );

      final grid = bossRoom.createNavigationGrid();
      final sim = makeSim(grid);
      final tracker = EncounterTracker(monsterCatalog: monsters);
      final manager = DungeonManager(
        dungeons: {
          'forgotten_forest': const DungeonDefinition(
            id: 'forgotten_forest',
            name: 'Forgotten Forest',
            biome: 'forgotten_forest',
            startRoomId: 'ancient_heart',
            rooms: {'ancient_heart': bossRoom},
            roomOrder: ['ancient_heart'],
          ),
        },
        encounterTracker: tracker,
      );

      manager.startDungeon('forgotten_forest');
      // Idempotent reload room yang sama tidak meng-reset atau menggandakan boss.
      manager.loadRoom('ancient_heart');
      manager.activateRoom();
      tracker.onRoomActivated(sim, grid: grid);
      tracker.onRoomActivated(sim, grid: grid);

      expect(sim.enemies, hasLength(2));
      final bossCombatant = sim.enemies.firstWhere(
        (e) => e.id.contains('ah_boss_guardian'),
      );
      expect(bossCombatant.isBoss, isTrue);
      expect(bossCombatant.isElite, isFalse);

      expect(tracker.hasBossEncounter, isTrue);
      expect(tracker.bossEncounters, hasLength(1));
      expect(tracker.primaryBossEncounter?.monsterId, 'ancient_heart_guardian');
      expect(tracker.primaryBossEncounter?.type, EncounterType.boss);

      // Mengalahkan add normal belum menyelesaikan kondisi defeat_boss.
      tracker.onEnemyDefeated('ancient_heart__ah_adds__0');
      expect(tracker.allRequiredBossesDefeated, isFalse);
      expect(tracker.allRequiredEncountersCompleted, isFalse);

      // Mengalahkan boss menyelesaikan boss encounter & syarat room.
      tracker.onEnemyDefeated(bossCombatant.id);
      expect(tracker.allRequiredBossesDefeated, isTrue);
      expect(tracker.allRequiredEncountersCompleted, isTrue);
    });
  });
}
