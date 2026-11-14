import 'package:echoes_of_aether/application/providers/database_provider.dart';
import 'package:echoes_of_aether/application/providers/game_config_provider.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_definition.dart';
import 'package:echoes_of_aether/domain/entities/enemy_definition.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/grid_point.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/domain/entities/specialization.dart';
import 'package:echoes_of_aether/domain/repositories/player_progress_repository.dart';
import 'package:echoes_of_aether/domain/services/equipment_service.dart';
import 'package:echoes_of_aether/features/dungeon/dungeon_screen.dart';
import 'package:echoes_of_aether/features/dungeon/town_hub_view.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemorySaveRepository implements PlayerSaveRepository {
  PlayerSaveSnapshot? stored;

  @override
  Future<PlayerSaveSnapshot?> loadSnapshot() async => stored;

  @override
  Future<void> saveSnapshot(PlayerSaveSnapshot snapshot) async {
    stored = snapshot;
  }
}

void main() {
  const openLayout = <String>[
    '####################',
    '#..................#',
    '#..................#',
    '#..................#',
    '#..................#',
    '#..................#',
    '#..................#',
    '#..................#',
    '#..................#',
    '#..................#',
    '####################',
  ];

  const progression = ProgressionConfig(
    maxLevel: 30,
    expBase: 50,
    expGrowth: 1.4,
    baseStats: CombatStats(
      maxHp: 120,
      atk: 15,
      def: 3,
      attackSpeed: 1,
      moveSpeed: 4,
      attackRange: 1.5,
    ),
    perLevel: LevelGrowth(hp: 15, atk: 3, def: 1),
  );

  const items = <String, ItemDefinition>{
    'slime_gel': ItemDefinition(
      id: 'slime_gel',
      name: 'Slime Gel',
      category: ItemCategory.material,
    ),
    'wooden_sword': ItemDefinition(
      id: 'wooden_sword',
      name: 'Wooden Sword',
      category: ItemCategory.equipment,
      equipment: EquipmentData(
        slot: EquipmentSlot.weapon,
        baseStats: EquipmentStats(atk: 5),
      ),
    ),
  };

  final config = GameConfig(
    monsters: const {
      'aether_slime': EnemyDefinition(
        id: 'aether_slime',
        name: 'Aether Slime',
        level: 1,
        detectionRange: 6,
        stats: CombatStats(maxHp: 40, atk: 5, def: 0, attackRange: 1),
      ),
    },
    revive: const ReviveConfig(),
    progression: progression,
    items: items,
    lootTables: const {},
    skills: const {
      'power_strike': SkillDefinition(
        id: 'power_strike',
        name: 'Power Strike',
        type: SkillType.active,
        effect: SkillEffectType.damage,
        damageType: SkillDamageType.physical,
        cooldownSeconds: 5,
        baseValue: 1.5,
        valuePerLevel: 0.2,
        maxLevel: 5,
        unlockLevel: 1,
        targetType: SkillTarget.single,
      ),
    },
    specializations: const SpecializationConfig(
      unlockLevel: 5,
      definitions: {
        'vanguard': SpecializationDefinition(
          id: 'vanguard',
          name: 'Vanguard',
          description: 'Tank garis depan',
          bonus: EquipmentStats(hp: 50, def: 4),
          attackRange: 1.5,
        ),
      },
    ),
    dungeons: const {
      'forgotten_forest': DungeonDefinition(
        id: 'forgotten_forest',
        name: 'Forgotten Forest',
        biome: 'Forest',
        startRoomId: 'forest_entrance',
        rooms: {
          'forest_entrance': RoomDefinition(
            id: 'forest_entrance',
            dungeonId: 'forgotten_forest',
            name: 'Forest Entrance',
            type: RoomType.normal,
            mapRef: 'forest_entrance_map',
            layout: openLayout,
            entryPosition: GridPoint(2, 5),
            exitPosition: GridPoint(17, 5),
            spawns: [
              RoomSpawnConfig(
                id: 'fe_1',
                monsterId: 'aether_slime',
                position: GridPoint(10, 5),
              ),
            ],
            completionCondition: RoomCompletionCondition(),
          ),
        },
        roomOrder: ['forest_entrance'],
      ),
    },
  );

  group('TownHubView & DungeonScreen navigation flow', () {
    testWidgets(
      'TownHubView menampilkan progres dungeon serta membuka overlay Tas, Perlengkapan, dan Karakter',
      (tester) async {
        final character = PlayerCharacter(
          config: progression,
          progress: const PlayerProgress(level: 5, gold: 40),
          skillCatalog: config.skills,
          specializationConfig: config.specializations,
        );
        final inventory = Inventory(definitions: items);
        inventory.add('slime_gel', 3);
        inventory.addEquipment(
          const EquipmentInstance(
            id: 'eq_1',
            definitionId: 'wooden_sword',
            slot: EquipmentSlot.weapon,
            rarity: ItemRarity.common,
            rolledStats: EquipmentStats(atk: 5),
          ),
        );
        final views = InventoryViews(
          inventory: inventory,
          character: character,
        );
        final eqService = EquipmentService(
          inventory: inventory,
          loadout: character.loadout,
        );
        var entered = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TownHubView(
                character: character,
                views: views,
                items: items,
                dungeonProgress: const DungeonProgressSnapshot(
                  highestClearedRoomIndex: 1,
                  clearsCount: 2,
                ),
                dungeonDefinition: config.dungeons['forgotten_forest'],
                onEnterDungeon: () => entered = true,
                onEquip: (id) {
                  if (eqService.equip(id)) views.refresh();
                },
                onUnequip: (slot) {
                  if (eqService.unequip(slot)) views.refresh();
                },
                onChooseSpecialization: (id) {
                  if (character.chooseSpecialization(id)) views.refresh();
                },
              ),
            ),
          ),
        );

        expect(find.text('Town / Camp'), findsOneWidget);
        expect(find.text('Forgotten Forest'), findsOneWidget);
        expect(find.text('Progres room tertinggi: 1 / 1'), findsOneWidget);
        expect(find.text('Total dungeon selesai: 2'), findsOneWidget);

        // Buka Tas (InventoryOverlay)
        await tester.tap(find.text('Tas'));
        await tester.pump();
        expect(find.text('Slime Gel'), findsOneWidget);
        await tester.tap(find.byTooltip('Tutup'));
        await tester.pump();
        expect(find.text('Slime Gel'), findsNothing);

        // Buka Perlengkapan (EquipmentOverlay) dan pasang equipment
        await tester.tap(find.text('Perlengkapan'));
        await tester.pump();
        expect(find.text('Tas perlengkapan (1)'), findsOneWidget);
        await tester.tap(find.text('Pakai'));
        await tester.pump();
        expect(character.loadout.instanceIn(EquipmentSlot.weapon)?.id, 'eq_1');
        await tester.tap(find.byTooltip('Tutup'));
        await tester.pump();

        // Buka Karakter (CharacterOverlay) dan pilih spesialisasi
        await tester.tap(find.text('Karakter'));
        await tester.pump();
        await tester.tap(find.text('Pilih'));
        await tester.pump();
        expect(character.specializationId, 'vanguard');
        await tester.tap(find.byTooltip('Tutup'));
        await tester.pump();

        // Masuk dungeon
        await tester.tap(find.text('Masuk Forgotten Forest'));
        await tester.pump();
        expect(entered, isTrue);
      },
    );

    testWidgets(
      'DungeonScreen alur penuh Town -> Forgotten Forest -> Kembali ke Town',
      (tester) async {
        final repo = _MemorySaveRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              gameConfigProvider.overrideWith((ref) async => config),
              playerSaveRepositoryProvider.overrideWith((ref) async => repo),
            ],
            child: const MaterialApp(home: DungeonScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // Dimulai di Town.
        expect(find.text('Town / Camp'), findsOneWidget);
        expect(find.text('Masuk Forgotten Forest'), findsOneWidget);

        // Masuk ke Forgotten Forest.
        await tester.tap(find.text('Masuk Forgotten Forest'));
        await tester.pump();
        await tester.pump();

        expect(find.text('Town / Camp'), findsNothing);
        expect(find.text('Forgotten Forest • Forest Entrance'), findsOneWidget);
        expect(find.text('Kembali ke Town'), findsOneWidget);

        // Kembali ke Town.
        await tester.tap(find.text('Kembali ke Town'));
        await tester.pump();
        await tester.pump();

        expect(find.text('Town / Camp'), findsOneWidget);
        expect(find.text('Masuk Forgotten Forest'), findsOneWidget);
      },
    );
  });
}
