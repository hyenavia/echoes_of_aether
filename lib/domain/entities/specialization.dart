import 'equipment.dart';
import 'item_definition.dart';

/// Definisi class specialization (GDD 4), dari specializations.json.
class SpecializationDefinition {
  const SpecializationDefinition({
    required this.id,
    required this.name,
    required this.bonus,
    this.description = '',
    this.attackRange,
    this.unlockLevel,
    this.skillAffinities = const {},
    this.rarity = ItemRarity.legendary,
    this.signatureWeaponId,
  });

  final String id;
  final String name;
  final String description;

  /// Kasta rarity class: Legendary untuk 3 class dasar, Mythical untuk class gacha.
  final ItemRarity rarity;

  /// Senjata signature yang bersinergi dengan class ini (jika ada).
  final String? signatureWeaponId;

  /// Bonus stat yang selalu aktif selama specialization dipilih.
  final EquipmentStats bonus;

  /// Jika terisi, menggantikan attack range dasar (melee vs ranged).
  final double? attackRange;

  /// Override level minimum untuk membuka specialization ini; null memakai
  /// [SpecializationConfig.unlockLevel].
  final int? unlockLevel;

  /// Bonus efektivitas aditif per skill id (mis. 0.2 = +20% efek skill).
  final Map<String, double> skillAffinities;

  double affinityFor(String skillId) => skillAffinities[skillId] ?? 0.0;
}

class SpecializationConfig {
  const SpecializationConfig({
    this.unlockLevel = 5,
    this.definitions = const {},
  });

  /// Level karakter minimum default untuk memilih specialization.
  final int unlockLevel;
  final Map<String, SpecializationDefinition> definitions;

  int unlockLevelFor(String specializationId) =>
      definitions[specializationId]?.unlockLevel ?? unlockLevel;
}
