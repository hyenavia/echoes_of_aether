import '../../domain/entities/player_character.dart';

/// Snapshot data HUD. Immutable dengan `==` agar `ValueNotifier` hanya
/// memberi tahu UI ketika nilainya benar-benar berubah.
class HudState {
  const HudState({
    required this.level,
    required this.currentExp,
    required this.expToNext,
    required this.gold,
    required this.hp,
    required this.maxHp,
    this.lastLoot = '',
    this.lastSkill = '',
    this.dungeonName = '',
    this.roomName = '',
    this.roomStatus = '',
    this.exitUnlocked = false,
    this.exitRequired = false,
    this.transitionMessage = '',
    this.activeEnemies = 0,
    this.totalEnemies = 0,
    this.bossName = '',
    this.bossHp = 0,
    this.bossMaxHp = 0,
    this.isElite = false,
    this.isFinalBoss = false,
    this.skillCooldownText = '',
  });

  factory HudState.fromCharacter(
    PlayerCharacter character, {
    required int hp,
    required int maxHp,
    String lastLoot = '',
    String lastSkill = '',
    String dungeonName = '',
    String roomName = '',
    String roomStatus = '',
    bool exitUnlocked = false,
    bool exitRequired = false,
    String transitionMessage = '',
    int activeEnemies = 0,
    int totalEnemies = 0,
    String bossName = '',
    int bossHp = 0,
    int bossMaxHp = 0,
    bool isElite = false,
    bool isFinalBoss = false,
    String skillCooldownText = '',
  }) {
    return HudState(
      level: character.level,
      currentExp: character.currentExp,
      expToNext: character.expToNext,
      gold: character.gold,
      hp: hp,
      maxHp: maxHp,
      lastLoot: lastLoot,
      lastSkill: lastSkill,
      dungeonName: dungeonName,
      roomName: roomName,
      roomStatus: roomStatus,
      exitUnlocked: exitUnlocked,
      exitRequired: exitRequired,
      transitionMessage: transitionMessage,
      activeEnemies: activeEnemies,
      totalEnemies: totalEnemies,
      bossName: bossName,
      bossHp: bossHp,
      bossMaxHp: bossMaxHp,
      isElite: isElite,
      isFinalBoss: isFinalBoss,
      skillCooldownText: skillCooldownText,
    );
  }

  final int level;
  final int currentExp;

  /// 0 jika sudah level maksimum.
  final int expToNext;
  final int gold;
  final int hp;
  final int maxHp;

  /// Ringkasan drop terakhir (kosong jika tidak ada).
  final String lastLoot;

  /// Nama skill yang baru dipakai (kosong jika tidak ada).
  final String lastSkill;

  /// Nama dungeon dan room aktif (kosong di mode non-dungeon).
  final String dungeonName;
  final String roomName;

  /// Status progres room, indikator exit, dan feedback perpindahan room.
  final String roomStatus;
  final bool exitUnlocked;
  final bool exitRequired;
  final String transitionMessage;

  /// Ringkasan encounter aktif dan status HP boss (opsional untuk HUD).
  final int activeEnemies;
  final int totalEnemies;
  final String bossName;
  final int bossHp;
  final int bossMaxHp;
  final bool isElite;
  final bool isFinalBoss;
  final String skillCooldownText;

  bool get isMaxLevel => expToNext <= 0;

  double get expFraction =>
      isMaxLevel ? 1.0 : (currentExp / expToNext).clamp(0.0, 1.0);

  double get hpFraction => maxHp <= 0 ? 0.0 : (hp / maxHp).clamp(0.0, 1.0);

  double get bossHpFraction =>
      bossMaxHp <= 0 ? 0.0 : (bossHp / bossMaxHp).clamp(0.0, 1.0);

  @override
  bool operator ==(Object other) =>
      other is HudState &&
      other.level == level &&
      other.currentExp == currentExp &&
      other.expToNext == expToNext &&
      other.gold == gold &&
      other.hp == hp &&
      other.maxHp == maxHp &&
      other.lastLoot == lastLoot &&
      other.lastSkill == lastSkill &&
      other.dungeonName == dungeonName &&
      other.roomName == roomName &&
      other.roomStatus == roomStatus &&
      other.exitUnlocked == exitUnlocked &&
      other.exitRequired == exitRequired &&
      other.transitionMessage == transitionMessage &&
      other.activeEnemies == activeEnemies &&
      other.totalEnemies == totalEnemies &&
      other.bossName == bossName &&
      other.bossHp == bossHp &&
      other.bossMaxHp == bossMaxHp &&
      other.isElite == isElite &&
      other.isFinalBoss == isFinalBoss &&
      other.skillCooldownText == skillCooldownText;

  @override
  int get hashCode => Object.hashAll([
    level,
    currentExp,
    expToNext,
    gold,
    hp,
    maxHp,
    lastLoot,
    lastSkill,
    dungeonName,
    roomName,
    roomStatus,
    exitUnlocked,
    exitRequired,
    transitionMessage,
    activeEnemies,
    totalEnemies,
    bossName,
    bossHp,
    bossMaxHp,
    isElite,
    isFinalBoss,
    skillCooldownText,
  ]);
}
