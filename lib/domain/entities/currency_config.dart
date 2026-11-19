/// ID default mata uang event di `game_config.json`.
const String kAetherShardCurrencyId = 'aether_shard';

/// ID default mata uang hasil konversi duplikat gacha di `game_config.json`.
const String kSoulPrismCurrencyId = 'soul_prism';

/// ID mata uang / penanda level upgrade kapasitas tas di `game_config.json`.
const String kBagExpansionCurrencyId = 'bag_expansion';

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
    kSoulPrismCurrencyId: CurrencyDefinition(
      id: kSoulPrismCurrencyId,
      name: 'Soul Prism',
      maxAmount: 9999,
    ),
    'altar_might': CurrencyDefinition(
      id: 'altar_might',
      name: 'Blessing of Might',
      maxAmount: 20,
    ),
    'altar_vitality': CurrencyDefinition(
      id: 'altar_vitality',
      name: 'Blessing of Vitality',
      maxAmount: 20,
    ),
    'altar_aegis': CurrencyDefinition(
      id: 'altar_aegis',
      name: 'Blessing of Aegis',
      maxAmount: 20,
    ),
    'altar_fortune': CurrencyDefinition(
      id: 'altar_fortune',
      name: 'Blessing of Fortune',
      maxAmount: 20,
    ),
    kBagExpansionCurrencyId: CurrencyDefinition(
      id: kBagExpansionCurrencyId,
      name: 'Bag Expansion',
      maxAmount: 10,
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
