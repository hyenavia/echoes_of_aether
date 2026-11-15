/// ID default mata uang event di `game_config.json`.
const String kAetherShardCurrencyId = 'aether_shard';

/// Definisi statis satu mata uang non-gold dari blok `currencies` pada
/// `game_config.json`.
class CurrencyDefinition {
  const CurrencyDefinition({
    required this.id,
    required this.name,
    required this.maxAmount,
  });

  final String id;
  final String name;
  final int maxAmount;

  static const Map<String, CurrencyDefinition> defaults = {
    kAetherShardCurrencyId: CurrencyDefinition(
      id: kAetherShardCurrencyId,
      name: 'Aether Shard',
      maxAmount: 1000000,
    ),
  };

  @override
  bool operator ==(Object other) =>
      other is CurrencyDefinition &&
      other.id == id &&
      other.name == name &&
      other.maxAmount == maxAmount;

  @override
  int get hashCode => Object.hash(id, name, maxAmount);
}
