import 'dart:io';

import 'package:echoes_of_aether/core/errors/config_exception.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/domain/entities/specialization.dart';
import 'package:flutter_test/flutter_test.dart';

String asset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig loadReal({String? skillsOverride}) {
  const parser = GameConfigParser();
  final settings = asset('game_config.json');
  return GameConfig(
    monsters: const MonsterConfigParser().parse(asset('monsters.json')),
    revive: parser.parseRevive(settings),
    progression: parser.parseProgression(settings),
    equipment: parser.parseEquipment(settings),
    items: const ItemConfigParser().parse(asset('items.json')),
    lootTables: const LootConfigParser().parse(asset('loot_tables.json')),
    skills: const SkillConfigParser().parse(
      skillsOverride ?? asset('skills.json'),
    ),
    specializations: const SpecializationConfigParser().parse(
      asset('specializations.json'),
    ),
  );
}

String skill(String body) => '{"skills":[{"id":"s","name":"S",$body}]}';

void main() {
  const skillParser = SkillConfigParser();
  const specParser = SpecializationConfigParser();

  group('skills.json', () {
    test('membaca skills.json yang dikirim bersama game', () {
      final skills = skillParser.parse(asset('skills.json'));
      final ps = skills['power_strike']!;
      expect(ps.isActive, isTrue);
      expect(ps.effect, SkillEffectType.damage);
      expect(ps.damageType, SkillDamageType.physical);
      expect(ps.cooldownSeconds, 5.0);
      expect(ps.damageMultiplier, 1.5);
      expect(ps.valuePerLevel, 0.2);
      expect(ps.maxLevel, 5);
      expect(ps.upgradeCost, 50);
      expect(ps.targetType, SkillTarget.single);
      expect(ps.specializationId, isNull);

      final heal = skills['healing_pulse']!;
      expect(heal.effect, SkillEffectType.healing);
      expect(heal.damageType, isNull);
      expect(heal.targetType, SkillTarget.self);
      expect(heal.useWhenHpBelow, 0.4);

      final burst = skills['aether_burst']!;
      expect(burst.effect, SkillEffectType.damage);
      expect(burst.damageType, SkillDamageType.magic);
      expect(burst.targetType, SkillTarget.area);
      expect(burst.radius, 2.5);
      expect(burst.specializationId, 'arcanist');

      final vitality = skills['vitality']!;
      expect(vitality.isPassive, isTrue);
      expect(vitality.effect, SkillEffectType.statModifier);
      expect(vitality.damageType, isNull);
      expect(vitality.passiveStats.hp, 30);
      expect(vitality.passiveStats.def, 3);

      final focus = skills['focus']!;
      expect(focus.isPassive, isTrue);
      expect(focus.effect, SkillEffectType.statModifier);
      expect(focus.passiveStats.atk, 4);

      final passive = skills['hawk_eye']!;
      expect(passive.isPassive, isTrue);
      expect(passive.passiveStats.critRate, 0.08);
    });

    test('nilai default untuk skill aktif minimal', () {
      final s = skillParser.parse(
        skill('"type":"active","cooldown":2,"damage_multiplier":1.2'),
      )['s']!;
      expect(s.targetType, SkillTarget.single);
      expect(s.effect, SkillEffectType.damage);
      expect(s.damageType, SkillDamageType.physical);
      expect(s.maxLevel, 5);
      expect(s.upgradeCost, 50);
      expect(s.valuePerLevel, 0);
      expect(s.minEnemies, 2);
      expect(s.range, isNull);
      expect(s.unlockLevel, 1);
    });

    test('skill healing otomatis bertarget self', () {
      final s = skillParser.parse(
        skill(
          '"type":"active","cooldown":10,"effect":"healing","heal_percent":0.3',
        ),
      )['s']!;
      expect(s.targetType, SkillTarget.self);
      expect(s.effect, SkillEffectType.healing);
      expect(s.damageType, isNull);
    });

    test('field wajib hilang atau tidak valid ditolak', () {
      final invalid = <String>[
        '"type":"active","damage_multiplier":1.2', // tanpa cooldown
        '"type":"active","cooldown":0,"damage_multiplier":1.2',
        '"type":"active","cooldown":-1,"damage_multiplier":1.2',
        '"type":"active","cooldown":2', // tanpa damage_multiplier / base_value
        '"type":"active","cooldown":2,"damage_multiplier":1,"target_type":"area"', // tanpa radius
        '"type":"active","cooldown":2,"damage_multiplier":1,"target_type":"self"',
        '"type":"active","cooldown":2,"effect":"heal","heal_percent":0.3,"target_type":"single"',
        '"type":"active","cooldown":2,"effect":"heal","heal_percent":1.5',
        '"type":"active","cooldown":2,"effect":"heal"', // tanpa heal_percent
        '"type":"active","cooldown":2,"effect":"healing","heal_percent":0.3,"damage_type":"magic"',
        '"type":"active","cooldown":2,"effect":"healing","heal_percent":0.8,"max_level":3,"value_per_level":0.2',
        '"type":"active","cooldown":2,"effect":"stat_modifier","damage_multiplier":1',
        '"type":"active","cooldown":2,"effect":"buff","damage_multiplier":1',
        '"type":"active","cooldown":2,"damage_multiplier":1,"damage_type":"fire"',
        '"type":"active","cooldown":2,"damage_multiplier":1,"max_level":0',
        '"type":"active","cooldown":2,"damage_multiplier":1,"upgrade_cost":-10',
        '"type":"active","cooldown":2,"damage_multiplier":1,"value_per_level":-0.1',
        '"type":"sihir","cooldown":2,"damage_multiplier":1',
        '"type":"passive"', // tanpa stats
        '"type":"passive","stats":{}"',
        '"type":"passive","stats":{"atk":1},"effect":"damage"',
        '"type":"passive","stats":{"atk":1},"cooldown":-1',
        '"type":"passive","stats":{"atk":1},"damage_type":"physical"',
        '"type":"passive","stats":{"atk":1},"radius":2', // field aktif pada pasif
      ];
      for (final body in invalid) {
        expect(
          () => skillParser.parse(skill(body)),
          throwsA(isA<ConfigException>()),
          reason: body,
        );
      }
    });

    test('field salah ketik ditolak dan disebut namanya', () {
      expect(
        () => skillParser.parse(
          skill('"type":"active","cooldown":2,"damage_multiplier":1,"dmg":3'),
        ),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('dmg'),
          ),
        ),
      );
    });

    test('id ganda ditolak', () {
      const one =
          '{"id":"s","name":"S","type":"active","cooldown":2,"damage_multiplier":1}';
      expect(
        () => skillParser.parse('{"skills":[$one,$one]}'),
        throwsA(isA<ConfigException>()),
      );
    });
  });

  group('specializations.json', () {
    test('membaca specializations.json yang dikirim bersama game', () {
      final c = specParser.parse(asset('specializations.json'));
      expect(c.unlockLevel, 5);
      expect(c.definitions.keys.toSet(), {
        'vanguard',
        'arcanist',
        'ranger',
        'paladin',
        'voidblade',
        'chronomancer',
        'gunslinger',
        'necromancer',
        'stormcaller',
      });

      final vanguard = c.definitions['vanguard']!;
      expect(vanguard.bonus.hp, 60);
      expect(vanguard.bonus.def, 3);
      expect(vanguard.attackRange, 1.5);
      expect(vanguard.skillAffinities, {'power_strike': 0.2, 'vitality': 0.25});

      final arcanist = c.definitions['arcanist']!;
      expect(arcanist.bonus.atk, 6);
      expect(arcanist.bonus.skillHaste, 0.05);
      expect(arcanist.attackRange, 4.0);
      expect(arcanist.skillAffinities, {
        'aether_burst': 0.25,
        'healing_pulse': 0.15,
      });

      final ranger = c.definitions['ranger']!;
      expect(ranger.bonus.attackSpeed, 0.4);
      expect(ranger.bonus.critRate, 0.05);
      expect(ranger.attackRange, 5.0);
      expect(ranger.skillAffinities, {'power_strike': 0.1, 'focus': 0.25});
    });

    test('unlock_level default 5 dan daftar kosong diterima', () {
      expect(specParser.parse('{"specializations":[]}').unlockLevel, 5);
    });

    test('bonus kosong, id ganda, field asing, affinity invalid, dan range 0 ditolak', () {
      String spec(String body) =>
          '{"specializations":[{"id":"a","name":"A",$body}]}';
      final invalid = <String>[
        '"bonus":{}',
        '"bonus":{"atk":1},"attack_range":0',
        '"bonus":{"atk":1},"warna":"merah"',
        '"bonus":{"skill_haste":0.9}',
        '"bonus":{"hp":1,"gaya":2}',
        '"bonus":{"atk":1},"unlock_level":0',
        '"bonus":{"atk":1},"skill_affinities":{"power_strike":-0.1}',
        '"bonus":{"atk":1},"skill_affinities":{"power_strike":3.0}',
        '"bonus":{"atk":1},"skill_affinities":{"":0.2}',
        '"bonus":{"atk":1},"skill_affinities":[0.2]',
      ];
      for (final body in invalid) {
        expect(
          () => specParser.parse(spec(body)),
          throwsA(isA<ConfigException>()),
          reason: body,
        );
      }
      const one = '{"id":"a","name":"A","bonus":{"atk":1}}';
      expect(
        () => specParser.parse('{"specializations":[$one,$one]}'),
        throwsA(isA<ConfigException>()),
      );
    });
  });

  group('konsistensi data', () {
    test('seluruh konfigurasi asli saling konsisten', () {
      expect(
        () => const GameConfigValidator().validate(loadReal()),
        returnsNormally,
      );
    });

    test('setiap starter specialization punya skill; skill-nya terbuka >= unlock_level', () {
      final c = loadReal();
      final unlock = c.specializations.unlockLevel;
      for (final id in ['vanguard', 'arcanist', 'ranger']) {
        final own = c.skills.values.where((s) => s.specializationId == id);
        expect(own, isNotEmpty, reason: id);
        for (final s in own) {
          expect(s.unlockLevel, greaterThanOrEqualTo(unlock), reason: s.id);
        }
      }
    });

    test('skill yang merujuk specialization tidak ada ditolak', () {
      final broken = loadReal(
        skillsOverride: skill(
          '"type":"active","specialization_id":"hantu","cooldown":2,"damage_multiplier":1',
        ),
      );
      expect(
        () => const GameConfigValidator().validate(broken),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('specialization_id'),
          ),
        ),
      );
    });

    test('validator menolak maxLevel, upgradeCost, atau cooldown negatif', () {
      final base = loadReal();
      final badMaxLevel = GameConfig(
        monsters: base.monsters,
        revive: base.revive,
        progression: base.progression,
        equipment: base.equipment,
        items: base.items,
        lootTables: base.lootTables,
        specializations: base.specializations,
        skills: const {
          'bad': SkillDefinition(
            id: 'bad',
            name: 'Bad',
            type: SkillType.active,
            cooldownSeconds: 2,
            maxLevel: 0,
          ),
        },
      );
      expect(
        () => const GameConfigValidator().validate(badMaxLevel),
        throwsA(isA<ConfigException>()),
      );

      final badUpgradeCost = GameConfig(
        monsters: base.monsters,
        revive: base.revive,
        progression: base.progression,
        equipment: base.equipment,
        items: base.items,
        lootTables: base.lootTables,
        specializations: base.specializations,
        skills: const {
          'bad': SkillDefinition(
            id: 'bad',
            name: 'Bad',
            type: SkillType.active,
            cooldownSeconds: 2,
            upgradeCost: -5,
          ),
        },
      );
      expect(
        () => const GameConfigValidator().validate(badUpgradeCost),
        throwsA(isA<ConfigException>()),
      );
    });

    test('validator menolak specialization yang merujuk skill tidak ada pada skillAffinities', () {
      final base = loadReal();
      final badAffinity = GameConfig(
        monsters: base.monsters,
        revive: base.revive,
        progression: base.progression,
        equipment: base.equipment,
        items: base.items,
        lootTables: base.lootTables,
        skills: base.skills,
        specializations: SpecializationConfig(
          unlockLevel: 5,
          definitions: {
            ...base.specializations.definitions,
            'vanguard': SpecializationDefinition(
              id: 'vanguard',
              name: 'Vanguard',
              bonus: base.specializations.definitions['vanguard']!.bonus,
              skillAffinities: const {'unknown_skill': 0.2},
            ),
          },
        ),
      );
      expect(
        () => const GameConfigValidator().validate(badAffinity),
        throwsA(
          isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains('unknown_skill'),
          ),
        ),
      );
    });

    test('seluruh 6 class Mythical memiliki skill pasif & aktif khusus di skills.json', () {
      final config = loadReal();
      expect(
        () => const GameConfigValidator().validate(config),
        returnsNormally,
      );

      const mythicalIds = [
        'paladin',
        'voidblade',
        'chronomancer',
        'gunslinger',
        'necromancer',
        'stormcaller',
      ];
      for (final specId in mythicalIds) {
        final classSkills = config.skills.values
            .where((s) => s.specializationId == specId)
            .toList();
        expect(
          classSkills.where((s) => s.isPassive),
          hasLength(1),
          reason: '$specId harus memiliki 1 skill pasif khusus',
        );
        expect(
          classSkills.where((s) => s.isActive),
          hasLength(2),
          reason: '$specId harus memiliki 2 skill aktif khusus',
        );
      }
    });
  });
}
