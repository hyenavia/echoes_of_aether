import 'equipment.dart';

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
  });

  final String id;
  final String name;
  final String description;

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
