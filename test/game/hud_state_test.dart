import 'package:echoes_of_aether/game/hud/hud_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const a = HudState(
    level: 2,
    currentExp: 25,
    expToNext: 100,
    gold: 7,
    hp: 50,
    maxHp: 100,
  );

  test('nilai sama dianggap sama (mencegah rebuild UI yang tidak perlu)', () {
    const b = HudState(
      level: 2,
      currentExp: 25,
      expToNext: 100,
      gold: 7,
      hp: 50,
      maxHp: 100,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('fraksi HP dan EXP', () {
    expect(a.hpFraction, 0.5);
    expect(a.expFraction, 0.25);
  });

  test('level maksimum menampilkan bar EXP penuh', () {
    const max = HudState(
      level: 30,
      currentExp: 0,
      expToNext: 0,
      gold: 0,
      hp: 1,
      maxHp: 1,
    );
    expect(max.isMaxLevel, isTrue);
    expect(max.expFraction, 1.0);
  });
}
