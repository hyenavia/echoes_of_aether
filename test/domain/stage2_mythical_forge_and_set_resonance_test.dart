import 'dart:io';

import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/mythical_forge_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/equipment_loadout.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/mythical_forge_config.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/specialization.dart';
import 'package:echoes_of_aether/domain/services/blacksmith_service.dart';
import 'package:echoes_of_aether/domain/services/derived_stats_calculator.dart';
import 'package:echoes_of_aether/domain/services/set_resonance_service.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

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
  late Map<String, ItemDefinition> items;
  late MythicalForgeConfig forgeConfig;
  late SpecializationConfig specConfig;
  late dynamic progression;
  late DerivedStatsCalculator calculator;

  setUpAll(() {
    const gameParser = GameConfigParser();
    final settings = _readAsset('game_config.json');
    progression = gameParser.parseProgression(settings);
    calculator = DerivedStatsCalculator(
      pctCaps: gameParser.parseEquipment(settings).pctCaps,
    );
    items = const ItemConfigParser().parse(_readAsset('items.json'));
    forgeConfig = const MythicalForgeConfigParser().parse(
      _readAsset('mythical_forge.json'),
    );
    specConfig = const SpecializationConfigParser().parse(
      _readAsset('specializations.json'),
    );
  });

  group('Stage 2 — SetResonanceService & PlayerCharacter integration', () {
    const service = SetResonanceService();

    test(
      '0 atau 1 piece set tidak mengaktifkan bonus 2-piece maupun 4-piece',
      () {
        final loadout = EquipmentLoadout({
          EquipmentSlot.weapon: _fixedInstance(
            'w1',
            'dawns_aegis_blade',
            items,
          ),
        });

        final state = service.evaluate(
          loadout: loadout,
          itemCatalog: items,
          forgeConfig: forgeConfig,
          specializationId: 'paladin',
        );

        expect(state.piecesCountFor('dawns_aegis'), 1);
        expect(state.activeTwoPieceSetIds, isEmpty);
        expect(state.twoPieceBonus.isEmpty, isTrue);
        expect(state.activeFourPieceSetId, isNull);
        expect(state.activeFourPieceClassId, isNull);
      },
    );

    test('2-piece berlaku universal lintas class dan mendukung kombinasi hybrid 2+2', () {
      final loadout = EquipmentLoadout({
        EquipmentSlot.head: _fixedInstance('h1', 'dawns_aegis_helm', items),
        EquipmentSlot.body: _fixedInstance('b1', 'dawns_aegis_cuirass', items),
        EquipmentSlot.weapon: _fixedInstance(
          'w1',
          'shadowfang_twinblade',
          items,
        ),
        EquipmentSlot.accessory: _fixedInstance('a1', 'shadowfang_ring', items),
      });

      final state = service.evaluate(
        loadout: loadout,
        itemCatalog: items,
        forgeConfig: forgeConfig,
        specializationId: 'vanguard',
      );

      expect(state.activeTwoPieceSetIds, {'dawns_aegis', 'shadowfang_umbra'});
      expect(state.twoPieceBonus.defPct, closeTo(0.25, 1e-9));
      expect(state.twoPieceBonus.hpPct, closeTo(0.20, 1e-9));
      expect(state.twoPieceBonus.critRate, closeTo(0.20, 1e-9));
      expect(state.twoPieceBonus.critDamage, closeTo(0.35, 1e-9));
      expect(state.activeFourPieceSetId, isNull);
      expect(state.activeFourPieceClassId, isNull);
    });

    test('4-piece hanya aktif jika class specialization sesuai dengan set', () {
      final loadout = EquipmentLoadout({
        EquipmentSlot.weapon: _fixedInstance('w1', 'dawns_aegis_blade', items),
        EquipmentSlot.head: _fixedInstance('h1', 'dawns_aegis_helm', items),
        EquipmentSlot.body: _fixedInstance('b1', 'dawns_aegis_cuirass', items),
        EquipmentSlot.accessory: _fixedInstance(
          'a1',
          'dawns_aegis_signet',
          items,
        ),
      });

      final paladinState = service.evaluate(
        loadout: loadout,
        itemCatalog: items,
        forgeConfig: forgeConfig,
        specializationId: 'paladin',
      );
      expect(paladinState.isTwoPieceActive('dawns_aegis'), isTrue);
      expect(paladinState.isFourPieceActive('dawns_aegis'), isTrue);
      expect(paladinState.activeFourPieceClassId, 'paladin');

      final wrongClassState = service.evaluate(
        loadout: loadout,
        itemCatalog: items,
        forgeConfig: forgeConfig,
        specializationId: 'vanguard',
      );
      expect(wrongClassState.isTwoPieceActive('dawns_aegis'), isTrue);
      expect(wrongClassState.isFourPieceActive('dawns_aegis'), isFalse);
      expect(wrongClassState.activeFourPieceClassId, isNull);
    });

    test('PlayerCharacter.stats menghitung bonus 2-piece dan tambahan stat 4-piece Gunslinger/Necromancer', () {
      final gunOnePiece = PlayerCharacter(
        config: progression,
        progress: const PlayerProgress(level: 50),
        specializationConfig: specConfig,
        itemCatalog: items,
        mythicalForgeConfig: forgeConfig,
        statsCalculator: calculator,
        initialSpecializationId: 'gunslinger',
        loadout: EquipmentLoadout({
          EquipmentSlot.weapon: _fixedInstance('w1', 'aether_railgun', items),
        }),
      );
      final gunFourPiece = PlayerCharacter(
        config: progression,
        progress: const PlayerProgress(level: 50),
        specializationConfig: specConfig,
        itemCatalog: items,
        mythicalForgeConfig: forgeConfig,
        statsCalculator: calculator,
        initialSpecializationId: 'gunslinger',
        loadout: EquipmentLoadout({
          EquipmentSlot.weapon: _fixedInstance('w1', 'aether_railgun', items),
          EquipmentSlot.head: _fixedInstance('h1', 'desperado_visor', items),
          EquipmentSlot.body: _fixedInstance('b1', 'desperado_coat', items),
          EquipmentSlot.accessory: _fixedInstance(
            'a1',
            'desperado_ring',
            items,
          ),
        }),
      );

      expect(gunOnePiece.activeResonanceClassId, 'gunslinger');
      expect(gunOnePiece.activeFourPieceClassId, isNull);
      expect(gunFourPiece.activeFourPieceClassId, 'gunslinger');
      expect(
        gunFourPiece.stats.attackRange - gunOnePiece.stats.attackRange,
        closeTo(1.0, 1e-9),
      );

      final necroFourPiece = PlayerCharacter(
        config: progression,
        progress: const PlayerProgress(level: 50),
        specializationConfig: specConfig,
        itemCatalog: items,
        mythicalForgeConfig: forgeConfig,
        statsCalculator: calculator,
        initialSpecializationId: 'necromancer',
        loadout: EquipmentLoadout({
          EquipmentSlot.weapon: _fixedInstance(
            'w2',
            'scythe_of_the_harvester',
            items,
          ),
          EquipmentSlot.head: _fixedInstance('h2', 'harvester_crown', items),
          EquipmentSlot.body: _fixedInstance('b2', 'harvester_mantle', items),
          EquipmentSlot.accessory: _fixedInstance(
            'a2',
            'harvester_talisman',
            items,
          ),
        }),
      );
      // 0.08 (spec) + 0.06 (weapon) + 0.05 (crown) + 0.06 (mantle) + 0.05 (talisman)
      // + 0.12 (2-piece) + 0.08 (weapon resonance) + 0.04 (4-piece) = 0.54
      expect(necroFourPiece.stats.lifesteal, closeTo(0.54, 1e-9));
    });
  });

  group('Stage 2 — BlacksmithService.craftMythicalEquipment', () {
    const blacksmith = BlacksmithService();

    PlayerCharacter makeHero({int gold = 200000, EquipmentLoadout? loadout}) {
      return PlayerCharacter(
        config: progression,
        progress: PlayerProgress(level: 60, gold: gold),
        specializationConfig: specConfig,
        itemCatalog: items,
        mythicalForgeConfig: forgeConfig,
        statsCalculator: calculator,
        loadout: loadout,
      );
    }

    Inventory makeInventoryWithMaterials({int? maxCapacity}) {
      final inv = Inventory(
        definitions: items,
        maxEquipmentCapacity: maxCapacity,
      );
      inv.add('aether_scrap', 500);
      inv.add('boss_remnant', 50);
      inv.add('abyssal_remnant', 20);
      return inv;
    }

    test('berhasil menempa Mythical dengan katalis terpasang, tumbal +5 dikonsumsi, hasil mulai +0 fixed stats, kapasitas tas penuh tetap aman', () {
      final catalyst = _fixedInstance('cat_1', 'dawns_aegis_blade', items);
      final loadout = EquipmentLoadout({EquipmentSlot.weapon: catalyst});
      final hero = makeHero(gold: 100000, loadout: loadout);
      final inv = makeInventoryWithMaterials(maxCapacity: 1);

      final sacrifice = _fixedInstance(
        'sac_1',
        'void_crown',
        items,
        enhancementLevel: 5,
      );
      expect(inv.addEquipment(sacrifice), isTrue);

      final result = blacksmith.craftMythicalEquipment(
        character: hero,
        inventory: inv,
        forgeConfig: forgeConfig,
        recipeId: 'craft_dawns_aegis_helm',
        sacrificeInstanceId: 'sac_1',
        loadout: loadout,
      );

      expect(result.isSuccess, isTrue);
      expect(result.goldSpent, 50000);
      expect(hero.gold, 50000);
      expect(inv.quantityOf('aether_scrap'), 300);
      expect(inv.quantityOf('boss_remnant'), 35);
      expect(inv.quantityOf('abyssal_remnant'), 15);
      // Katalis tetap aman terpasang
      expect(loadout.instanceIn(EquipmentSlot.weapon)?.id, 'cat_1');
      // Tumbal hilang, hasil masuk menggantikan slot kapasitas
      expect(inv.equipmentById('sac_1'), isNull);
      expect(inv.equipmentCount, 1);

      final crafted = result.craftedInstance!;
      expect(crafted.definitionId, 'dawns_aegis_helm');
      expect(crafted.rarity, ItemRarity.mythical);
      expect(crafted.enhancementLevel, 0);
      expect(
        crafted.rolledStats.def,
        items['dawns_aegis_helm']!.equipment!.baseStats.def,
      );
      expect(inv.equipmentById(crafted.id), isNotNull);
    });

    test('berhasil menempa Mythical dengan katalis di dalam tas (tanpa mengorbankan katalis)', () {
      final hero = makeHero(gold: 100000);
      final inv = makeInventoryWithMaterials();
      final catalyst = _fixedInstance('cat_bag', 'shadowfang_twinblade', items);
      final sacrifice = _fixedInstance('sac_body', 'void_carapace', items);
      inv.addEquipment(catalyst);
      inv.addEquipment(sacrifice);

      final result = blacksmith.craftMythicalEquipment(
        character: hero,
        inventory: inv,
        forgeConfig: forgeConfig,
        recipeId: 'craft_shadowfang_shroud',
        sacrificeInstanceId: 'sac_body',
      );

      expect(result.isSuccess, isTrue);
      expect(inv.equipmentById('cat_bag'), isNotNull);
      expect(inv.equipmentById('sac_body'), isNull);
      expect(result.craftedInstance!.definitionId, 'shadowfang_shroud');
    });

    test('seluruh kasus gagal bersifat atomik tanpa memotong gold, material, atau tumbal', () {
      final hero = makeHero(gold: 100000);
      final inv = makeInventoryWithMaterials();
      final catalyst = _fixedInstance('cat_1', 'dawns_aegis_blade', items);
      final favHelm = _fixedInstance(
        'fav_helm',
        'void_crown',
        items,
        isFavorite: true,
      );
      final epicHelm = _fixedInstance('epic_helm', 'abyssal_cowl', items);
      final wrongSlot = _fixedInstance('wrong_slot', 'void_carapace', items);
      final equippedHelm = _fixedInstance('eq_helm', 'void_crown', items);
      final mythicalHelm = _fixedInstance(
        'myth_helm',
        'dawns_aegis_helm',
        items,
      );
      final loadout = EquipmentLoadout({EquipmentSlot.head: equippedHelm});

      inv.addEquipment(favHelm);
      inv.addEquipment(epicHelm);
      inv.addEquipment(wrongSlot);
      inv.addEquipment(mythicalHelm);

      // 1. Missing catalyst
      expect(
        blacksmith
            .craftMythicalEquipment(
              character: hero,
              inventory: inv,
              forgeConfig: forgeConfig,
              recipeId: 'craft_dawns_aegis_helm',
              sacrificeInstanceId: 'fav_helm',
              loadout: loadout,
            )
            .status,
        BlacksmithCraftMythicalStatus.missingCatalystWeapon,
      );

      inv.addEquipment(catalyst);

      // 2. Unknown recipe
      expect(
        blacksmith
            .craftMythicalEquipment(
              character: hero,
              inventory: inv,
              forgeConfig: forgeConfig,
              recipeId: 'unknown_recipe',
              sacrificeInstanceId: 'fav_helm',
              loadout: loadout,
            )
            .status,
        BlacksmithCraftMythicalStatus.recipeNotFound,
      );

      // 3. Sacrifice equipped
      expect(
        blacksmith
            .craftMythicalEquipment(
              character: hero,
              inventory: inv,
              forgeConfig: forgeConfig,
              recipeId: 'craft_dawns_aegis_helm',
              sacrificeInstanceId: 'eq_helm',
              loadout: loadout,
            )
            .status,
        BlacksmithCraftMythicalStatus.cannotSacrificeEquipped,
      );

      // 4. Sacrifice favorite
      expect(
        blacksmith
            .craftMythicalEquipment(
              character: hero,
              inventory: inv,
              forgeConfig: forgeConfig,
              recipeId: 'craft_dawns_aegis_helm',
              sacrificeInstanceId: 'fav_helm',
              loadout: loadout,
            )
            .status,
        BlacksmithCraftMythicalStatus.cannotSacrificeFavorite,
      );

      // 5. Sacrifice mythical
      expect(
        blacksmith
            .craftMythicalEquipment(
              character: hero,
              inventory: inv,
              forgeConfig: forgeConfig,
              recipeId: 'craft_dawns_aegis_helm',
              sacrificeInstanceId: 'myth_helm',
              loadout: loadout,
            )
            .status,
        BlacksmithCraftMythicalStatus.cannotSacrificeMythical,
      );

      // 6. Wrong slot
      expect(
        blacksmith
            .craftMythicalEquipment(
              character: hero,
              inventory: inv,
              forgeConfig: forgeConfig,
              recipeId: 'craft_dawns_aegis_helm',
              sacrificeInstanceId: 'wrong_slot',
              loadout: loadout,
            )
            .status,
        BlacksmithCraftMythicalStatus.sacrificeSlotMismatch,
      );

      // 7. Rarity too low (epic < legendary)
      expect(
        blacksmith
            .craftMythicalEquipment(
              character: hero,
              inventory: inv,
              forgeConfig: forgeConfig,
              recipeId: 'craft_dawns_aegis_helm',
              sacrificeInstanceId: 'epic_helm',
              loadout: loadout,
            )
            .status,
        BlacksmithCraftMythicalStatus.sacrificeRarityTooLow,
      );

      // 8. Insufficient gold
      final validSac = _fixedInstance('valid_helm', 'void_crown', items);
      inv.addEquipment(validSac);
      final poorHero = makeHero(gold: 1000);
      expect(
        blacksmith
            .craftMythicalEquipment(
              character: poorHero,
              inventory: inv,
              forgeConfig: forgeConfig,
              recipeId: 'craft_dawns_aegis_helm',
              sacrificeInstanceId: 'valid_helm',
              loadout: loadout,
            )
            .status,
        BlacksmithCraftMythicalStatus.insufficientGold,
      );

      // 9. Insufficient materials
      inv.remove('abyssal_remnant', 18); // sisa 2 < 5
      expect(
        blacksmith
            .craftMythicalEquipment(
              character: hero,
              inventory: inv,
              forgeConfig: forgeConfig,
              recipeId: 'craft_dawns_aegis_helm',
              sacrificeInstanceId: 'valid_helm',
              loadout: loadout,
            )
            .status,
        BlacksmithCraftMythicalStatus.insufficientMaterials,
      );

      // Pastikan tidak ada mutasi samping
      expect(hero.gold, 100000);
      expect(inv.quantityOf('aether_scrap'), 500);
      expect(inv.quantityOf('boss_remnant'), 50);
      expect(inv.quantityOf('abyssal_remnant'), 2);
      expect(inv.equipmentById('valid_helm'), isNotNull);

      final candidates = blacksmith.findEligibleSacrificeCandidates(
        recipe: forgeConfig.recipes['craft_dawns_aegis_helm']!,
        targetSlot: EquipmentSlot.head,
        inventory: inv,
        loadout: loadout,
      );
      expect(candidates.map((c) => c.id), ['valid_helm']);
    });
  });
}
