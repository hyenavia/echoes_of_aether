import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/skill_definition.dart';
import 'package:echoes_of_aether/features/dungeon/skill_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('skill damage tunggal', () {
    const s = SkillDefinition(
      id: 'p',
      name: 'P',
      type: SkillType.active,
      cooldownSeconds: 5,
      damageMultiplier: 1.5,
    );
    expect(describeSkill(s), 'Cooldown 5s, DMG x1.5');
  });

  test('skill damage area menyebut radius dan jumlah musuh minimum', () {
    const s = SkillDefinition(
      id: 'b',
      name: 'B',
      type: SkillType.active,
      cooldownSeconds: 7,
      damageMultiplier: 1.3,
      targetType: SkillTarget.area,
      radius: 2.5,
      minEnemies: 2,
    );
    expect(describeSkill(s), 'Cooldown 7s, DMG x1.3, area r2.5 (min 2 musuh)');
  });

  test('skill healing menyebut ambang HP', () {
    const s = SkillDefinition(
      id: 'h',
      name: 'H',
      type: SkillType.active,
      cooldownSeconds: 25,
      effect: SkillEffectType.healing,
      targetType: SkillTarget.self,
      healPercent: 0.35,
      useWhenHpBelow: 0.4,
    );
    expect(
      describeSkill(s),
      'Cooldown 25s, pulihkan 35% HP (otomatis saat HP < 40%)',
    );
  });

  test('skill pasif menampilkan bonus stat', () {
    const s = SkillDefinition(
      id: 'i',
      name: 'I',
      type: SkillType.passive,
      passiveStats: EquipmentStats(hp: 30, def: 3),
    );
    expect(describeSkill(s), 'Pasif: HP +30, DEF +3');
  });
}
