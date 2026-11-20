import 'equipment.dart';

/// Definisi biaya terobosan (Hero Ascension Breakthrough Cost).
class HeroAscensionCost {
  const HeroAscensionCost({
    this.gold = 0,
    this.items = const {},
    this.currencies = const {},
  });

  final int gold;
  final Map<String, int> items;
  final Map<String, int> currencies;
}

/// Bonus stat permanen yang diperoleh saat melakukan terobosan.
class HeroAscensionStatBoost {
  const HeroAscensionStatBoost({
    this.hp = 0,
    this.atk = 0,
    this.def = 0,
    this.critRate = 0.0,
    this.attackSpeed = 0.0,
    this.critDamage = 0.0,
    this.skillHaste = 0.0,
  });

  final int hp;
  final int atk;
  final int def;
  final double critRate;
  final double attackSpeed;
  final double critDamage;
  final double skillHaste;
}

/// Definisi satu fase Ascension (A0 s/d A6).
class HeroAscensionPhaseDefinition {
  const HeroAscensionPhaseDefinition({
    required this.phase,
    required this.levelCap,
    required this.requiredPlayerLevel,
    this.cost = const HeroAscensionCost(),
    this.statBoost = const HeroAscensionStatBoost(),
    this.hasGoldenAura = false,
  });

  final int phase;
  final int levelCap;
  final int requiredPlayerLevel;
  final HeroAscensionCost cost;
  final HeroAscensionStatBoost statBoost;
  final bool hasGoldenAura;
}

/// Konfigurasi lengkap Hero Ascension dari game_config.json.
class HeroAscensionConfig {
  const HeroAscensionConfig({this.maxPhase = 6, this.phases = const []});

  final int maxPhase;
  final List<HeroAscensionPhaseDefinition> phases;

  HeroAscensionPhaseDefinition? phase(int p) {
    if (p < 0 || p >= phases.length) return null;
    return phases[p];
  }

  int levelCapForPhase(int p) {
    if (p < 0) return 20;
    if (p >= phases.length) {
      return phases.isNotEmpty ? phases.last.levelCap : 90;
    }
    return phases[p].levelCap;
  }

  /// Menghitung akumulasi bonus stat terobosan hingga fase [currentPhase].
  EquipmentStats cumulativeStatBoostForPhase(int currentPhase) {
    if (currentPhase <= 0 || phases.isEmpty) return EquipmentStats.zero;
    var hp = 0;
    var atk = 0;
    var def = 0;
    var critRate = 0.0;
    var attackSpeed = 0.0;
    var critDamage = 0.0;
    var skillHaste = 0.0;

    for (final p in phases) {
      if (p.phase <= currentPhase) {
        hp += p.statBoost.hp;
        atk += p.statBoost.atk;
        def += p.statBoost.def;
        critRate += p.statBoost.critRate;
        attackSpeed += p.statBoost.attackSpeed;
        critDamage += p.statBoost.critDamage;
        skillHaste += p.statBoost.skillHaste;
      }
    }

    return EquipmentStats(
      hp: hp.toDouble(),
      atk: atk.toDouble(),
      def: def.toDouble(),
      critRate: critRate,
      attackSpeed: attackSpeed,
      critDamage: critDamage,
      skillHaste: skillHaste,
    );
  }

  /// Memeriksa apakah fase aktif pemain membuka status aura emas (*Golden Aura*).
  bool hasGoldenAuraForPhase(int currentPhase) {
    if (currentPhase <= 0 || phases.isEmpty) return false;
    for (final p in phases) {
      if (p.phase <= currentPhase && p.hasGoldenAura) {
        return true;
      }
    }
    return false;
  }
}

/// State ascension milik pemain saat runtime/domain.
class HeroAscensionState {
  const HeroAscensionState({this.currentPhase = 0});

  final int currentPhase;
}
