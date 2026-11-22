import 'dart:math' as math;

import '../services/derived_stats_calculator.dart';
import '../services/progression_service.dart';
import '../services/set_resonance_service.dart';
import 'combat_stats.dart';
import 'equipment.dart';
import 'equipment_loadout.dart';
import 'hero_ascension.dart';
import 'item_definition.dart';
import 'mythical_forge_config.dart';
import 'player_progress.dart';
import 'player_save_snapshot.dart';
import 'progression_config.dart';
import 'skill_definition.dart';
import 'skill_runtime_state.dart';
import 'specialization.dart';

enum SkillUpgradeStatus {
  upgraded,
  unknownSkill,
  locked,
  maxLevelReached,
  insufficientGold,
}

class SkillUpgradeResult {
  const SkillUpgradeResult({
    required this.status,
    required this.newLevel,
    required this.goldSpent,
    required this.remainingGold,
  });

  final SkillUpgradeStatus status;
  final int newLevel;
  final int goldSpent;
  final int remainingGold;

  bool get succeeded => status == SkillUpgradeStatus.upgraded;
}

/// Karakter utama (GDD 3.1). Menyimpan progres, equipment, specialization,
/// dan skill, serta menghitung stat tempur. Instance ini hidup lebih lama
/// daripada satu dungeon run.
class PlayerCharacter {
  PlayerCharacter({
    required this.config,
    PlayerProgress? progress,
    EquipmentLoadout? loadout,
    this.skillCatalog = const {},
    this.specializationConfig = const SpecializationConfig(),
    this.statsCalculator = const DerivedStatsCalculator(),
    this.heroAscensionConfig = const HeroAscensionConfig(),
    Map<String, ItemDefinition> itemCatalog = const {},
    MythicalForgeConfig mythicalForgeConfig = const MythicalForgeConfig(),
    String? initialSpecializationId,
    Map<String, int> skillLevels = const {},
  }) : _service = ProgressionService(config, heroAscensionConfig),
       _progress = progress ?? const PlayerProgress(),
       loadout = loadout ?? EquipmentLoadout(),
       _itemCatalog = itemCatalog, // ignore: prefer_initializing_formals
       // ignore: prefer_initializing_formals
       _mythicalForgeConfig = mythicalForgeConfig,
       _specializationId = initialSpecializationId,
       _skillLevels = {
         for (final entry in skillLevels.entries)
           entry.key: math.max(1, entry.value),
       };

  static const SetResonanceService _setResonanceService = SetResonanceService();

  final ProgressionConfig config;
  final HeroAscensionConfig heroAscensionConfig;
  final ProgressionService _service;
  final EquipmentLoadout loadout;
  Map<String, ItemDefinition> _itemCatalog;
  MythicalForgeConfig _mythicalForgeConfig;

  Map<String, ItemDefinition> get itemCatalog => Map.unmodifiable(_itemCatalog);

  set itemCatalog(Map<String, ItemDefinition> catalog) {
    _itemCatalog = catalog;
    buildRevision++;
  }

  MythicalForgeConfig get mythicalForgeConfig => _mythicalForgeConfig;

  set mythicalForgeConfig(MythicalForgeConfig forgeConfig) {
    _mythicalForgeConfig = forgeConfig;
    buildRevision++;
  }

  /// Mengembalikan id class yang sedang aktif resonansi senjatanya, atau null jika tidak aktif.
  String? get activeResonanceClassId {
    final specId = _specializationId;
    if (specId == null) return null;
    final weaponInstance = loadout.instanceIn(EquipmentSlot.weapon);
    if (weaponInstance == null) return null;
    final itemDef = _itemCatalog[weaponInstance.definitionId];
    if (itemDef?.equipment?.signatureClassId == specId) {
      return specId;
    }
    return null;
  }

  /// Status aktivasi Set Resonance (2-piece universal + 4-piece class-locked).
  SetResonanceState get setResonanceState => _setResonanceService.evaluate(
    loadout: loadout,
    itemCatalog: _itemCatalog,
    forgeConfig: _mythicalForgeConfig,
    specializationId: _specializationId,
  );

  /// Akumulasi stat bonus 2-piece Set Resonance yang aktif saat ini.
  EquipmentStats get setBonus => setResonanceState.twoPieceBonus;

  /// ID class specialization yang memperoleh evolusi efek 4-piece, atau null.
  String? get activeFourPieceClassId =>
      setResonanceState.activeFourPieceClassId;

  /// Seluruh definisi skill dan specialization yang ada di game.
  final Map<String, SkillDefinition> skillCatalog;
  final SpecializationConfig specializationConfig;
  final DerivedStatsCalculator statsCalculator;

  PlayerProgress _progress;
  String? _specializationId;
  final Map<String, int> _skillLevels;
  EquipmentStats _altarBonus = EquipmentStats.zero;

  /// Bertambah setiap kali specialization atau altar blessing berubah
  /// (untuk mendeteksi perubahan stat/skill tanpa membandingkan seluruh isi).
  int buildRevision = 0;

  EquipmentStats get altarBonus => _altarBonus;

  /// Memperbarui bonus stat dari Camp Altar.
  void updateAltarBonus(EquipmentStats bonus) {
    _altarBonus = bonus;
    buildRevision++;
  }

  PlayerProgress get progress => _progress;
  int get level => _progress.level;
  int get gold => _progress.gold;
  int get currentExp => _progress.currentExp;
  bool get isMaxLevel => config.maxLevel != null && level >= config.maxLevel!;

  /// EXP untuk naik ke level berikutnya; 0 jika sudah level maksimum.
  int get expToNext => isMaxLevel ? 0 : config.expToNext(level);

  // ---- Specialization ----

  String? get specializationId => _specializationId;

  SpecializationDefinition? get specialization =>
      specializationConfig.definitions[_specializationId];

  bool get canChooseSpecialization => level >= specializationConfig.unlockLevel;

  bool canChooseSpecializationFor(String id) =>
      specializationConfig.definitions.containsKey(id) &&
      level >= specializationConfig.unlockLevelFor(id);

  /// Memilih specialization. Mengembalikan false (tanpa perubahan) jika level
  /// belum cukup, id tidak dikenal, atau specialization itu sudah dipilih.
  /// Keputusan MVP (GDD 4.5): pergantian specialization (respec) tidak
  /// dikenai biaya gold atau cooldown sampai aturan respec lanjutan disetujui.
  bool chooseSpecialization(String id) {
    if (!canChooseSpecializationFor(id)) return false;
    if (id == _specializationId) return false;
    _specializationId = id;
    buildRevision++;
    return true;
  }

  /// Menghapus active specialization dan mengembalikan state ke netral.
  bool clearSpecialization() {
    if (_specializationId == null) return false;
    _specializationId = null;
    buildRevision++;
    return true;
  }

  Map<String, double> get activeSkillAffinities =>
      Map.unmodifiable(specialization?.skillAffinities ?? const {});

  double skillAffinityFor(String skillId) =>
      specialization?.affinityFor(skillId) ?? 0.0;

  // ---- Skill ----

  int skillLevel(String skillId) => _skillLevels[skillId] ?? 1;

  Map<String, int> get skillLevelsSnapshot => Map.unmodifiable(_skillLevels);

  bool isSkillUnlocked(SkillDefinition skill) =>
      level >= skill.unlockLevel &&
      (skill.specializationId == null ||
          skill.specializationId == _specializationId);

  SkillRuntimeState skillRuntimeState(String skillId) {
    final skill = skillCatalog[skillId];
    return SkillRuntimeState(
      skillId: skillId,
      level: skillLevel(skillId),
      unlocked: skill != null && isSkillUnlocked(skill),
    );
  }

  List<SkillRuntimeState> get skillRuntimeStates {
    final ids = skillCatalog.keys.toList()..sort();
    return [for (final id in ids) skillRuntimeState(id)];
  }

  /// Upgrade level skill menggunakan gold secara atomik:
  /// seluruh validasi (skill ada, unlocked, belum max level, saldo gold cukup)
  /// diperiksa sebelum saldo gold atau level skill diubah.
  SkillUpgradeResult upgradeSkill(String skillId) {
    final def = skillCatalog[skillId];
    if (def == null) {
      return SkillUpgradeResult(
        status: SkillUpgradeStatus.unknownSkill,
        newLevel: 1,
        goldSpent: 0,
        remainingGold: gold,
      );
    }

    final currentLevel = skillLevel(skillId);
    if (!isSkillUnlocked(def)) {
      return SkillUpgradeResult(
        status: SkillUpgradeStatus.locked,
        newLevel: currentLevel,
        goldSpent: 0,
        remainingGold: gold,
      );
    }

    if (currentLevel >= def.maxLevel) {
      return SkillUpgradeResult(
        status: SkillUpgradeStatus.maxLevelReached,
        newLevel: currentLevel,
        goldSpent: 0,
        remainingGold: gold,
      );
    }

    final cost = def.upgradeCostForNextLevel(currentLevel);
    final nextProgress = _service.spendGold(_progress, cost);
    if (nextProgress == null) {
      return SkillUpgradeResult(
        status: SkillUpgradeStatus.insufficientGold,
        newLevel: currentLevel,
        goldSpent: 0,
        remainingGold: gold,
      );
    }

    final nextLevel = currentLevel + 1;
    _progress = nextProgress;
    _skillLevels[skillId] = nextLevel;
    buildRevision++;
    return SkillUpgradeResult(
      status: SkillUpgradeStatus.upgraded,
      newLevel: nextLevel,
      goldSpent: cost,
      remainingGold: gold,
    );
  }

  /// Skill yang sudah terbuka, diurutkan berdasarkan id agar stabil.
  List<SkillDefinition> get unlockedSkills {
    final result = skillCatalog.values.where(isSkillUnlocked).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return result;
  }

  List<SkillDefinition> get activeSkills =>
      unlockedSkills.where((s) => s.isActive).toList();

  List<SkillDefinition> get passiveSkills =>
      unlockedSkills.where((s) => s.isPassive).toList();

  // ---- Stat ----

  int get ascensionPhase => _progress.ascensionPhase;

  ProgressionService get progressionService => _service;

  bool get isAscendReady => _service.isAscendReady(_progress);

  int get effectiveLevelCap =>
      _service.effectiveLevelCap(_progress.ascensionPhase);

  EquipmentStats get ascensionBonus =>
      heroAscensionConfig.cumulativeStatBoostForPhase(_progress.ascensionPhase);

  /// Stat tempur saat ini (single source of truth melalui
  /// [DerivedStatsCalculator]):
  /// Base Stats (level) + Equipment Modifiers + Altar Modifiers
  /// + Ascension Modifiers + Specialization Modifiers + Passive Skill Modifiers
  /// (beserta affinity specialization).
  CombatStats get stats {
    final setState = setResonanceState;
    return statsCalculator.calculate(
      baseStats: config.statsAt(level),
      equipmentBonus: loadout.totalBonus,
      setBonus: setState.twoPieceBonus,
      altarBonus: _altarBonus,
      ascensionBonus: ascensionBonus,
      specialization: specialization,
      passiveSkills: passiveSkills,
      skillLevelOf: skillLevel,
      activeResonanceClassId: activeResonanceClassId,
      activeFourPieceClassId: setState.activeFourPieceClassId,
    );
  }

  /// Memperbarui fase Ascension pemain dan memicu pembaruan build stats.
  void updateAscensionPhase(int newPhase) {
    _progress = _progress.copyWith(ascensionPhase: math.max(0, newPhase));
    buildRevision++;
  }

  /// Menambahkan reward dan mengembalikan jumlah level yang naik.
  int receiveReward({int exp = 0, int gold = 0}) {
    final result = _service.grant(_progress, exp: exp, gold: gold);
    _progress = result.progress;
    return result.levelsGained;
  }

  bool canAfford(int amount) => amount >= 0 && gold >= amount;

  /// Mengurangi gold sebesar [amount] bila valid dan saldo mencukupi.
  /// Mengembalikan false (tanpa perubahan) jika [amount] negatif atau saldo
  /// tidak cukup.
  bool spendGold(int amount) {
    final nextProgress = _service.spendGold(_progress, amount);
    if (nextProgress == null) return false;
    _progress = nextProgress;
    return true;
  }

  /// Menambahkan gold hasil penjualan secara aman (tervalidasi & ter-clamp)
  /// tanpa melewati jalur reward. Mengembalikan jumlah gold yang benar-benar
  /// ditambahkan.
  int addGold(int amount) {
    final before = _progress.gold;
    _progress = _service.addGold(_progress, amount);
    return _progress.gold - before;
  }

  /// Menghasilkan snapshot state karakter yang siap dipersistensikan (Phase F).
  PlayerCharacterSnapshot toSnapshot() => PlayerCharacterSnapshot(
    progress: _progress,
    specializationId: _specializationId,
    skillLevels: Map<String, int>.unmodifiable(_skillLevels),
    equipped: loadout.equipped,
  );

  /// Memulihkan state karakter dari snapshot tersimpan.
  void restoreSnapshot(PlayerCharacterSnapshot snapshot) {
    final maxLvl = config.maxLevel ?? ProgressionConfig.kTechnicalMaxLevel;
    final clampedLevel = math.min(maxLvl, math.max(1, snapshot.progress.level));
    final safeExp =
        (config.maxLevel != null && clampedLevel >= config.maxLevel!)
        ? 0
        : math.max(0, snapshot.progress.currentExp);
    final safeGold = math.max(0, snapshot.progress.gold);
    _progress = PlayerProgress(
      level: clampedLevel,
      currentExp: safeExp,
      gold: safeGold,
      ascensionPhase: snapshot.progress.ascensionPhase,
    );

    final specId = snapshot.specializationId;
    if (specId != null &&
        specializationConfig.definitions.containsKey(specId) &&
        clampedLevel >= specializationConfig.unlockLevelFor(specId)) {
      _specializationId = specId;
    } else {
      _specializationId = null;
    }

    _skillLevels.clear();
    for (final entry in snapshot.skillLevels.entries) {
      final def = skillCatalog[entry.key];
      if (def == null) continue;
      _skillLevels[entry.key] = math.min(
        def.maxLevel,
        math.max(1, entry.value),
      );
    }

    loadout.restore(snapshot.equipped);
    buildRevision++;
  }
}
