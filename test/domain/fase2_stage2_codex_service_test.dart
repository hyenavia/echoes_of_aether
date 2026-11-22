import 'dart:io';

import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/services/codex_service.dart';
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
  );
}

void main() {
  late GameConfig config;
  const service = CodexService();

  setUpAll(() {
    config = _loadRealConfig();
  });

  group('Fase 2 Stage 2 — CodexService (Data-Driven JSON)', () {
    test('buildResonanceEntries lists all 6 Mythical Signature Weapon Resonances with unlock status', () {
      final entries = service.buildResonanceEntries(
        config: config,
        unlockedSpecializations: const {'vanguard', 'paladin', 'voidblade'},
      );

      expect(entries.length, 6);
      final bySpec = {for (final e in entries) e.specializationId: e};
      expect(bySpec.keys, {
        'paladin',
        'voidblade',
        'chronomancer',
        'gunslinger',
        'necromancer',
        'stormcaller',
      });

      expect(bySpec['paladin']!.isUnlocked, isTrue);
      expect(bySpec['voidblade']!.isUnlocked, isTrue);
      expect(bySpec['chronomancer']!.isUnlocked, isFalse);

      for (final entry in entries) {
        expect(entry.signatureWeaponName, isNotEmpty);
        expect(entry.resonanceDescription, isNotEmpty);
      }
    });

    test('buildMaterialEntries maps Ascension materials to exact dungeon/boss drop sources and salvage note', () {
      final entries = service.buildMaterialEntries(
        config: config,
        ownedQuantities: const {
          'abyssal_remnant': 4,
          'void_essence': 2,
          'aether_scrap': 15,
        },
      );

      final byId = {for (final e in entries) e.itemId: e};
      expect(byId['abyssal_remnant'], isNotNull);
      expect(byId['void_essence'], isNotNull);
      expect(byId['aether_scrap'], isNotNull);

      final remnant = byId['abyssal_remnant']!;
      expect(remnant.ownedQuantity, 4);
      expect(remnant.isAscensionMaterial, isTrue);
      expect(remnant.usedInAscensionPhases, contains(5));
      expect(
        remnant.dropSources.any(
          (s) => s.sourceLabel.contains('The Abyssal Rift (Clear)'),
        ),
        isTrue,
      );

      final voidEssence = byId['void_essence']!;
      expect(voidEssence.ownedQuantity, 2);
      expect(voidEssence.usedInAscensionPhases, contains(6));
      expect(voidEssence.dropSources, isNotEmpty);

      final scrap = byId['aether_scrap']!;
      expect(scrap.ownedQuantity, 15);
      expect(scrap.dropSources, isNotEmpty);
    });
  });
}
