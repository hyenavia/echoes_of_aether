import 'dart:io';

import 'package:echoes_of_aether/app/theme/echoes_theme.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/mythical_forge_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/services/blacksmith_service.dart';
import 'package:echoes_of_aether/features/dungeon/blacksmith_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/character_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/codex_overlay.dart';
import 'package:echoes_of_aether/game/hud/inventory_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealConfig() {
  const parser = GameConfigParser();
  final settings = _readAsset('game_config.json');
  final difficulty = parser.parseDifficulty(settings);
  return GameConfig(
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
}

EquipmentInstance _fixedInstance(
  String id,
  String defId,
  Map<String, ItemDefinition> items, {
  int enhancementLevel = 0,
  bool isFavorite = false,
}) {
  final def = items[defId]!;
  final eq = def.equipment!;
  return EquipmentInstance(
    id: id,
    definitionId: defId,
    slot: eq.slot,
    rarity: def.rarity,
    rolledStats: eq.baseStats,
    enhancementLevel: enhancementLevel,
    isFavorite: isFavorite,
  );
}

void main() {
  late GameConfig config;

  setUpAll(() {
    config = _loadRealConfig();
  });

  group('Stage 4 — Mythical Forge & Set Resonance UI', () {
    testWidgets(
      'BlacksmithOverlay tab Tempa Mythical menampilkan status katalis, memfilter tumbal, dan mengeksekusi penempaan setelah konfirmasi (360x640)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final inv = Inventory(definitions: config.items);
        final char = PlayerCharacter(
          config: config.progression,
          progress: const PlayerProgress(level: 60, gold: 100000),
          specializationConfig: config.specializations,
          itemCatalog: config.items,
          mythicalForgeConfig: config.mythicalForge,
        );
        inv.add('aether_scrap', 300);
        inv.add('boss_remnant', 30);
        inv.add('abyssal_remnant', 10);

        final favSacrifice = _fixedInstance(
          'fav_sac',
          'void_crown',
          config.items,
          isFavorite: true,
        );
        final validSacrifice = _fixedInstance(
          'valid_sac',
          'void_crown',
          config.items,
          enhancementLevel: 3,
        );
        final epicHelm = _fixedInstance(
          'epic_helm',
          'abyssal_cowl',
          config.items,
        );
        inv.addEquipment(favSacrifice);
        inv.addEquipment(validSacrifice);
        inv.addEquipment(epicHelm);

        final views = InventoryViews(inventory: inv, character: char);
        const service = BlacksmithService();

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: BlacksmithOverlay(
                snapshot: views.equipment,
                items: config.items,
                inventoryEntries: views.stacks,
                characterSnapshot: views.characterView,
                forgeConfig: config.mythicalForge,
                onEnhanceEquipment: (id) => service.enhanceEquipment(
                  character: char,
                  inventory: inv,
                  instanceId: id,
                  loadout: char.loadout,
                ),
                onReforgeEquipment: (id) => const BlacksmithReforgeResult(
                  status: BlacksmithReforgeStatus.fixedStatsNotReforgeable,
                ),
                onCraftMythicalEquipment: (recipeId, sacrificeId) {
                  final res = service.craftMythicalEquipment(
                    character: char,
                    inventory: inv,
                    forgeConfig: config.mythicalForge,
                    recipeId: recipeId,
                    sacrificeInstanceId: sacrificeId,
                    loadout: char.loadout,
                  );
                  if (res.isSuccess) views.refresh();
                  return res;
                },
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Tempa Mythical'));
        await tester.pumpAndSettle();

        // Tanpa katalis -> terkunci
        expect(
          find.text("Butuh Katalis: Dawn's Aegis Blade (Tidak Dikonsumsi)"),
          findsOneWidget,
        );
        // Tumbal favorit & epic tidak boleh muncul sebagai kandidat
        expect(find.byKey(const Key('forge_sacrifice_fav_sac')), findsNothing);
        expect(
          find.byKey(const Key('forge_sacrifice_epic_helm')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('forge_sacrifice_valid_sac')),
          findsOneWidget,
        );

        // Pasang katalis di loadout
        char.loadout.equip(
          _fixedInstance('cat_blade', 'dawns_aegis_blade', config.items),
        );
        views.refresh();
        await tester.pumpAndSettle();

        expect(
          find.text("Katalis Tersedia: Dawn's Aegis Blade (Tidak Dikonsumsi)"),
          findsOneWidget,
        );

        final craftBtn = find.byKey(
          const Key('forge_craft_button_craft_dawns_aegis_helm'),
        );
        await tester.ensureVisible(craftBtn);
        await tester.tap(craftBtn);
        await tester.pumpAndSettle();

        expect(find.text('Konfirmasi Tempa Mythical'), findsOneWidget);
        await tester.tap(find.text('Konfirmasi Tempa'));
        await tester.pumpAndSettle();

        expect(
          find.text("Sukses! Dawn's Radiant Greathelm berhasil ditempa (+0)."),
          findsOneWidget,
        );
        expect(inv.equipmentById('valid_sac'), isNull);
        expect(char.loadout.instanceIn(EquipmentSlot.weapon)?.id, 'cat_blade');
        expect(
          inv.equipmentSnapshot().any(
            (e) => e.definitionId == 'dawns_aegis_helm',
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'CharacterOverlay menampilkan indikator Set Resonance (2/4 dan 4/4) & CodexOverlay menampilkan info Set 2P/4P',
      (tester) async {
        final inv = Inventory(definitions: config.items);
        final char = PlayerCharacter(
          config: config.progression,
          progress: const PlayerProgress(level: 50),
          specializationConfig: config.specializations,
          itemCatalog: config.items,
          mythicalForgeConfig: config.mythicalForge,
          initialSpecializationId: 'paladin',
        );
        char.loadout.equip(
          _fixedInstance('w1', 'dawns_aegis_blade', config.items),
        );
        char.loadout.equip(
          _fixedInstance('h1', 'dawns_aegis_helm', config.items),
        );
        final views = InventoryViews(
          inventory: inv,
          character: char,
          unlockedSpecializations: const {'paladin'},
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: CharacterOverlay(
                snapshot: views.characterView,
                equipmentSnapshot: views.equipment,
                items: config.items,
                onChooseSpecialization: (_) {},
                sectionMode: CharacterSectionMode.profileAndGear,
                embedded: true,
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('character_set_resonance_summary')),
          findsOneWidget,
        );
        expect(find.text('Set Resonance Aktif'), findsOneWidget);
        expect(find.text('2/4'), findsOneWidget);

        // Pasang sisa 2 piece -> 4/4
        char.loadout.equip(
          _fixedInstance('b1', 'dawns_aegis_cuirass', config.items),
        );
        char.loadout.equip(
          _fixedInstance('a1', 'dawns_aegis_signet', config.items),
        );
        views.refresh();
        await tester.pumpAndSettle();
        expect(find.text('4/4'), findsOneWidget);

        // Verifikasi CodexOverlay menampilkan ringkasan 2-Piece & 4-Piece
        await tester.pumpWidget(
          MaterialApp(
            theme: EchoesTheme.dark(),
            home: Scaffold(
              body: CodexOverlay(
                config: config,
                unlockedSpecializations: const {'paladin'},
                embedded: true,
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text("Set Mythical: Dawn's Aegis"),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(find.text("Set Mythical: Dawn's Aegis"), findsOneWidget);
        expect(
          find.textContaining('2-Piece (Semua Class):'),
          findsAtLeastNWidgets(1),
        );
        expect(find.textContaining('4-Piece (Paladin):'), findsOneWidget);
      },
    );
  });
}
