import 'package:flutter/foundation.dart' show ValueNotifier;

import '../../domain/entities/combat_stats.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/entities/hero_ascension.dart';
import '../../domain/entities/inventory.dart';
import '../../domain/entities/mythical_forge_config.dart';
import '../../domain/entities/player_character.dart';
import '../../domain/entities/skill_definition.dart';
import '../../domain/entities/specialization.dart';
import '../../domain/services/set_resonance_service.dart';

/// Snapshot tampilan equipment: yang terpasang, isi tas, dan stat akhir.
class EquipmentSnapshot {
  const EquipmentSnapshot({
    required this.equipped,
    required this.bag,
    required this.stats,
    this.maxCapacity,
  });

  factory EquipmentSnapshot.from(Inventory inventory, PlayerCharacter c) {
    return EquipmentSnapshot(
      equipped: Map.of(c.loadout.equipped),
      bag: inventory.equipmentSnapshot(),
      stats: c.stats,
      maxCapacity: inventory.maxEquipmentCapacity,
    );
  }

  final Map<EquipmentSlot, EquipmentInstance> equipped;
  final List<EquipmentInstance> bag;
  final CombatStats stats;
  final int? maxCapacity;
}

class SkillEntry {
  const SkillEntry(
    this.definition, {
    required this.unlocked,
    this.level = 1,
    this.nextUpgradeCost = 0,
    this.canUpgrade = false,
  });

  final SkillDefinition definition;
  final bool unlocked;
  final int level;
  final int nextUpgradeCost;
  final bool canUpgrade;
}

/// Snapshot tampilan karakter: specialization, saldo gold, dan daftar skill.
class CharacterSnapshot {
  const CharacterSnapshot({
    required this.level,
    this.gold = 0,
    this.stats,
    required this.specializationId,
    required this.canChooseSpecialization,
    required this.specializationUnlockLevel,
    required this.specializations,
    required this.skills,
    this.skillNames = const {},
    this.unlockedSpecializations = const {},
    this.ascensionPhase = 0,
    this.isAscendReady = false,
    this.effectiveLevelCap = 20,
    this.heroAscensionConfig = const HeroAscensionConfig(),
    this.hasGoldenAura = false,
    this.setResonanceState = SetResonanceState.empty,
    this.mythicalForgeConfig = const MythicalForgeConfig(),
  });

  factory CharacterSnapshot.from(
    PlayerCharacter c, {
    Set<String> unlockedSpecializations = const {},
  }) {
    // Tampilkan skill umum dan skill milik specialization yang dipilih.
    final visible =
        c.skillCatalog.values
            .where(
              (s) =>
                  s.specializationId == null ||
                  s.specializationId == c.specializationId,
            )
            .toList()
          ..sort((a, b) {
            final byLevel = a.unlockLevel.compareTo(b.unlockLevel);
            return byLevel != 0 ? byLevel : a.id.compareTo(b.id);
          });

    final specs = c.specializationConfig.definitions.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    return CharacterSnapshot(
      level: c.level,
      gold: c.gold,
      stats: c.stats,
      specializationId: c.specializationId,
      canChooseSpecialization: c.canChooseSpecialization,
      specializationUnlockLevel: c.specializationConfig.unlockLevel,
      specializations: specs,
      skills: [
        for (final s in visible)
          () {
            final unlocked = c.isSkillUnlocked(s);
            final lvl = c.skillLevel(s.id);
            final cost = s.upgradeCostForNextLevel(lvl);
            final canUpgrade =
                unlocked && lvl < s.maxLevel && cost > 0 && c.gold >= cost;
            return SkillEntry(
              s,
              unlocked: unlocked,
              level: lvl,
              nextUpgradeCost: cost,
              canUpgrade: canUpgrade,
            );
          }(),
      ],
      skillNames: {for (final s in c.skillCatalog.values) s.id: s.name},
      unlockedSpecializations: Set<String>.unmodifiable(
        unlockedSpecializations,
      ),
      ascensionPhase: c.ascensionPhase,
      isAscendReady: c.isAscendReady,
      effectiveLevelCap: c.effectiveLevelCap,
      heroAscensionConfig: c.heroAscensionConfig,
      hasGoldenAura: c.heroAscensionConfig.hasGoldenAuraForPhase(
        c.ascensionPhase,
      ),
      setResonanceState: c.setResonanceState,
      mythicalForgeConfig: c.mythicalForgeConfig,
    );
  }

  final int level;
  final int gold;
  final CombatStats? stats;
  final String? specializationId;
  final bool canChooseSpecialization;
  final int specializationUnlockLevel;
  final List<SpecializationDefinition> specializations;
  final List<SkillEntry> skills;
  final Map<String, String> skillNames;
  final Set<String> unlockedSpecializations;
  final int ascensionPhase;
  final bool isAscendReady;
  final int effectiveLevelCap;
  final HeroAscensionConfig heroAscensionConfig;
  final bool hasGoldenAura;
  final SetResonanceState setResonanceState;
  final MythicalForgeConfig mythicalForgeConfig;
}

/// Jembatan antara domain (Inventory, PlayerCharacter) dan overlay Flutter.
/// Panggil [refresh] setiap kali isi inventory, stat, atau build berubah.
class InventoryViews {
  InventoryViews({
    required this.inventory,
    required this.character,
    Set<String> unlockedSpecializations = const {},
  }) : _unlockedSpecializations = Set<String>.from(unlockedSpecializations),
       stacks = ValueNotifier(inventory.snapshot()),
       equipment = ValueNotifier(EquipmentSnapshot.from(inventory, character)),
       characterView = ValueNotifier(
         CharacterSnapshot.from(
           character,
           unlockedSpecializations: unlockedSpecializations,
         ),
       );

  final Inventory inventory;
  final PlayerCharacter character;
  Set<String> _unlockedSpecializations;
  final ValueNotifier<List<InventoryEntry>> stacks;
  final ValueNotifier<EquipmentSnapshot> equipment;
  final ValueNotifier<CharacterSnapshot> characterView;

  void setUnlockedSpecializations(Set<String> unlocked) {
    _unlockedSpecializations = Set<String>.from(unlocked);
    refresh();
  }

  void refresh() {
    stacks.value = inventory.snapshot();
    equipment.value = EquipmentSnapshot.from(inventory, character);
    characterView.value = CharacterSnapshot.from(
      character,
      unlockedSpecializations: _unlockedSpecializations,
    );
  }
}
