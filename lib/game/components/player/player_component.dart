import '../combatant_component.dart';

/// Tampilan player (GDD 12.3). Stat dan perhitungan damage ada di domain.
class PlayerComponent extends CombatantComponent {
  PlayerComponent({
    required super.combatant,
    required super.tileSize,
    this.specializationIdProvider,
    super.atlas,
  }) : super(colorArgb: 0xFF4FC3F7);

  final String? Function()? specializationIdProvider;

  @override
  String? get spriteSpecializationId => specializationIdProvider?.call();
}
