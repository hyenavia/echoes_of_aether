import 'dart:io';

import 'package:echoes_of_aether/features/shared/assets/game_assets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CharacterVisualSpec & 10 Classes Asset Integration', () {
    const classExpectations = <String, Map<String, String>>{
      'base': {
        'classId': 'base',
        'title': 'Adventurer',
        'subtitle': 'New Player Starting Class (Adventurer)',
      },
      'vanguard': {
        'classId': 'vanguard',
        'title': 'Vanguard',
        'subtitle': 'Frontline Warrior',
      },
      'arcanist': {
        'classId': 'arcanist',
        'title': 'Arcanist',
        'subtitle': 'Arcane Mage',
      },
      'ranger': {
        'classId': 'ranger',
        'title': 'Ranger',
        'subtitle': 'Precision Archer',
      },
      'paladin': {
        'classId': 'paladin',
        'title': 'Paladin',
        'subtitle': 'Holy Knight',
      },
      'voidblade': {
        'classId': 'voidblade',
        'title': 'Voidblade',
        'subtitle': 'Shadow Assassin',
      },
      'chronomancer': {
        'classId': 'chronomancer',
        'title': 'Chronomancer',
        'subtitle': 'Time Mage',
      },
      'gunslinger': {
        'classId': 'gunslinger',
        'title': 'Gunslinger',
        'subtitle': 'Aether Gunner',
      },
      'necromancer': {
        'classId': 'necromancer',
        'title': 'Necromancer',
        'subtitle': 'Soul Summoner',
      },
      'stormcaller': {
        'classId': 'stormcaller',
        'title': 'Stormcaller',
        'subtitle': 'Lightning Mage',
      },
    };

    for (final entry in classExpectations.entries) {
      test(
        'CharacterVisualSpec.resolve memetakan "${entry.key}" dengan benar',
        () {
          final spec = CharacterVisualSpec.resolve(entry.key);
          expect(spec.classId, entry.value['classId']);
          expect(spec.title, entry.value['title']);
          expect(spec.subtitle, entry.value['subtitle']);
        },
      );
    }

    test(
      'Semua 10 class memiliki 6 frame PNG lengkap di assets/char/frames',
      () {
        const poses = ['idle0', 'idle1', 'walk0', 'walk1', 'attack', 'downed'];
        const heroIds = [
          'hero_base',
          'hero_vanguard',
          'hero_arcanist',
          'hero_ranger',
          'hero_paladin',
          'hero_voidblade',
          'hero_chronomancer',
          'hero_gunslinger',
          'hero_necromancer',
          'hero_stormcaller',
        ];

        for (final hero in heroIds) {
          for (final pose in poses) {
            final framePath = 'assets/char/frames/${hero}_$pose.png';
            final file = File(framePath);
            expect(
              file.existsSync(),
              isTrue,
              reason: 'File frame $framePath harus ada di disk.',
            );
          }
        }
      },
    );

    test('Semua 10 class memiliki file portrait di assets/char', () {
      const heroIds = [
        'hero_base',
        'hero_vanguard',
        'hero_arcanist',
        'hero_ranger',
        'hero_paladin',
        'hero_voidblade',
        'hero_chronomancer',
        'hero_gunslinger',
        'hero_necromancer',
        'hero_stormcaller',
      ];

      for (final hero in heroIds) {
        final portraitPath = 'assets/char/$hero.png';
        final file = File(portraitPath);
        expect(
          file.existsSync(),
          isTrue,
          reason: 'File portrait $portraitPath harus ada di disk.',
        );
      }
    });
  });
}
