import 'dart:io';

import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/room_encounter.dart';
import 'package:echoes_of_aether/domain/services/dungeon_manager.dart';
import 'package:echoes_of_aether/domain/services/encounter_tracker.dart';
import 'package:echoes_of_aether/game/components/enemies/enemy_component.dart';
import 'package:echoes_of_aether/game/echoes_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealConfig() {
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

void main() {
  group('Forgotten Forest — Spawn & Encounter Tracking Integration', () {
    testWidgets(
      'seluruh 5 room Forgotten Forest men-spawn monster, elite, dan boss sesuai konfigurasi dengan cleanup bersih',
      (tester) async {
        final config = _loadRealConfig();
        final character = PlayerCharacter(
          config: config.progression,
          skillCatalog: config.skills,
          specializationConfig: config.specializations,
        );
        final inventory = Inventory(definitions: config.items);
        final tracker = EncounterTracker(monsterCatalog: config.monsters);
        final manager = DungeonManager(
          dungeons: config.dungeons,
          encounterTracker: tracker,
        );

        manager.startDungeon('forgotten_forest');

        final game = EchoesGame(
          config: config,
          character: character,
          inventory: inventory,
          autoSkill: ValueNotifier(true),
          dungeonManager: manager,
        );

        await tester.pumpWidget(GameWidget(game: game));
        await tester.pump();
        await tester.pump();
        game.update(0.05);

        // Room 1: Forest Entrance (3 Aether Slime)
        expect(manager.activeRoom?.id, 'forest_entrance');
        expect(game.world.simulation.enemies, hasLength(3));
        expect(game.world.children.whereType<EnemyComponent>(), hasLength(3));
        expect(tracker.totalPlannedEnemies, 3);
        expect(tracker.totalActiveEnemies, 3);
        expect(game.hud.value.activeEnemies, 3);
        expect(game.hud.value.totalEnemies, 3);

        // Duplicate activation tidak menggandakan musuh.
        manager.activateRoom();
        await tester.pump();
        expect(game.world.simulation.enemies, hasLength(3));
        expect(game.world.children.whereType<EnemyComponent>(), hasLength(3));

        // Room 2: Ancient Path (2 Slime + 2 Wolf = 4) -> cleanup room 1 tanpa false kill!
        manager.loadRoom('ancient_path');
        await tester.pump();
        await tester.pump();
        await game.world.pendingRoomLoad;
        await tester.pump();
        game.update(0.05);

        expect(manager.activeRoom?.id, 'ancient_path');
        expect(tracker.totalDefeatedEnemies, 0);
        expect(game.world.simulation.enemies, hasLength(4));
        expect(game.world.children.whereType<EnemyComponent>(), hasLength(4));

        // Room 3: Ruined Shrine (2 Wolf + 1 Corrupted Treant = 3)
        manager.loadRoom('ruined_shrine');
        await tester.pump();
        await tester.pump();
        await game.world.pendingRoomLoad;
        await tester.pump();
        game.update(0.05);

        expect(manager.activeRoom?.id, 'ruined_shrine');
        expect(game.world.simulation.enemies, hasLength(3));

        // Room 4: Hidden Chamber (1 Corrupted Guardian Elite)
        manager.loadRoom('hidden_chamber');
        await tester.pump();
        await tester.pump();
        await game.world.pendingRoomLoad;
        await tester.pump();
        game.update(0.05);

        expect(manager.activeRoom?.id, 'hidden_chamber');
        expect(game.world.simulation.enemies, hasLength(1));
        expect(game.world.simulation.enemies.single.isElite, isTrue);
        expect(tracker.hasEliteEncounter, isTrue);
        expect(
          config.monsters['corrupted_guardian']?.lootTableId,
          'elite_loot',
        );

        // Room 5: Ancient Heart (1 Ancient Heart Guardian Boss)
        manager.loadRoom('ancient_heart');
        await tester.pump();
        await tester.pump();
        await game.world.pendingRoomLoad;
        await tester.pump();
        game.update(0.05);

        expect(manager.activeRoom?.id, 'ancient_heart');
        expect(game.world.simulation.enemies, hasLength(1));
        expect(game.world.simulation.enemies.single.isBoss, isTrue);
        expect(tracker.hasBossEncounter, isTrue);
        expect(
          tracker.primaryBossEncounter?.monsterId,
          'ancient_heart_guardian',
        );
        expect(
          config.monsters['ancient_heart_guardian']?.lootTableId,
          'boss_loot',
        );
        expect(game.hud.value.bossName, 'Ancient Heart Guardian');
        expect(game.hud.value.bossHp, 420);
        expect(game.hud.value.bossMaxHp, 420);
      },
    );

    testWidgets(
      'CombatSystem memproses combat hingga musuh mati dan memperbarui EncounterTracker serta EnemyComponent',
      (tester) async {
        final baseConfig = _loadRealConfig();
        // Perkuat stats test agar player cepat mengalahkan boss/slime dalam simulasi singkat.
        final strongConfig = GameConfig(
          monsters: baseConfig.monsters,
          revive: baseConfig.revive,
          progression: const ProgressionConfig(
            maxLevel: 30,
            expBase: 50,
            expGrowth: 1.4,
            baseStats: CombatStats(
              maxHp: 500,
              atk: 200,
              def: 20,
              attackSpeed: 2.5,
              moveSpeed: 8,
              attackRange: 2.0,
            ),
            perLevel: LevelGrowth(hp: 20, atk: 5, def: 2),
          ),
          equipment: baseConfig.equipment,
          dungeonCompletion: baseConfig.dungeonCompletion,
          items: baseConfig.items,
          lootTables: baseConfig.lootTables,
          skills: baseConfig.skills,
          specializations: baseConfig.specializations,
          dungeons: baseConfig.dungeons,
        );

        final character = PlayerCharacter(
          config: strongConfig.progression,
          skillCatalog: strongConfig.skills,
          specializationConfig: strongConfig.specializations,
        );
        final inventory = Inventory(definitions: strongConfig.items);
        final tracker = EncounterTracker(monsterCatalog: strongConfig.monsters);
        final roomDoneEvents = <RoomEncountersCompletedEvent>[];
        tracker.addListener((e) {
          if (e is RoomEncountersCompletedEvent) roomDoneEvents.add(e);
        });

        final manager = DungeonManager(
          dungeons: strongConfig.dungeons,
          encounterTracker: tracker,
        );
        manager.startDungeon('forgotten_forest');

        final game = EchoesGame(
          config: strongConfig,
          character: character,
          inventory: inventory,
          autoSkill: ValueNotifier(true),
          dungeonManager: manager,
        );

        await tester.pumpWidget(GameWidget(game: game));
        await tester.pump();
        await tester.pump();

        // Jalankan beberapa detik waktu simulasi (step 0.2s -> 4 ticks per frame, max 5).
        for (var i = 0; i < 60; i++) {
          game.update(0.2);
          await tester.pump();
          if (tracker.allRequiredEncountersCompleted) break;
        }

        expect(tracker.allRequiredEncountersCompleted, isTrue);
        expect(tracker.totalDefeatedEnemies, 3);
        expect(tracker.totalActiveEnemies, 0);
        expect(game.world.simulation.aliveEnemies, isEmpty);
        expect(game.world.children.whereType<EnemyComponent>(), isEmpty);
        expect(roomDoneEvents, hasLength(1));
        expect(game.hud.value.activeEnemies, 0);
        expect(game.hud.value.totalEnemies, 3);
      },
    );
  });
}
