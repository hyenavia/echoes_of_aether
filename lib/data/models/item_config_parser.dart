import '../../core/errors/config_exception.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/entities/item_definition.dart';
import 'json_reader.dart';
import 'stat_bonus_parser.dart';

/// Membaca dan memvalidasi items.json.
class ItemConfigParser {
  const ItemConfigParser();

  static const JsonReader _r = JsonReader('items.json');

  Map<String, ItemDefinition> parse(String source) {
    final root = _r.decodeRoot(source);
    final list = _r.list(root, 'root', 'items');

    final result = <String, ItemDefinition>{};
    for (var i = 0; i < list.length; i++) {
      final where = 'items[$i]';
      final map = _r.asMap(list[i], where);
      final id = _r.string(map, where, 'id');
      if (result.containsKey(id)) {
        throw ConfigException('items.json: id ganda "$id".');
      }
      final category = _category(_r.string(map, where, 'category'), where);
      result[id] = ItemDefinition(
        id: id,
        name: _r.string(map, where, 'name'),
        category: category,
        rarity: map['rarity'] == null
            ? ItemRarity.common
            : _rarity(_r.string(map, where, 'rarity'), where),
        maxStack: _r.integer(map, where, 'max_stack', min: 1, fallback: 999),
        sellValue: _r.integer(map, where, 'sell_value', min: 0, fallback: 0),
        equipment: _equipment(map, where, category),
      );
    }
    return result;
  }

  EquipmentData? _equipment(
    Map<String, dynamic> map,
    String where,
    ItemCategory category,
  ) {
    final raw = map['equipment'];
    if (category != ItemCategory.equipment) {
      if (raw != null) {
        throw ConfigException(
          'items.json: $where."equipment" hanya boleh ada pada kategori equipment.',
        );
      }
      return null;
    }
    if (raw == null) {
      throw ConfigException(
        'items.json: $where berkategori equipment, sehingga memerlukan '
        'object "equipment" (slot dan stats).',
      );
    }

    final w = '$where.equipment';
    final data = _r.asMap(raw, w);
    _r.ensureKnownKeys(data, w, {'slot', 'weapon_type', 'stats'});

    final slot = _slot(_r.string(data, w, 'slot'), w);
    final weaponType = data['weapon_type'] == null
        ? null
        : _r.string(data, w, 'weapon_type');
    if (weaponType != null && slot != EquipmentSlot.weapon) {
      throw ConfigException(
        'items.json: $w."weapon_type" hanya berlaku untuk slot weapon.',
      );
    }

    final sw = '$w.stats';
    final stats = StatBonusParser.parse(_r, _r.asMap(data['stats'], sw), sw);
    return EquipmentData(slot: slot, baseStats: stats, weaponType: weaponType);
  }

  EquipmentSlot _slot(String raw, String where) => switch (raw) {
    'weapon' => EquipmentSlot.weapon,
    'head' => EquipmentSlot.head,
    'body' => EquipmentSlot.body,
    'accessory' => EquipmentSlot.accessory,
    _ => throw ConfigException(
      'items.json: $where."slot" tidak dikenal: "$raw" '
      '(pilihan: weapon, head, body, accessory).',
    ),
  };

  ItemCategory _category(String raw, String where) => switch (raw) {
    'equipment' => ItemCategory.equipment,
    'material' => ItemCategory.material,
    'consumable' => ItemCategory.consumable,
    'quest_item' => ItemCategory.questItem,
    _ => throw ConfigException(
      'items.json: $where."category" tidak dikenal: "$raw" '
      '(pilihan: equipment, material, consumable, quest_item).',
    ),
  };

  ItemRarity _rarity(String raw, String where) => switch (raw) {
    'common' => ItemRarity.common,
    'uncommon' => ItemRarity.uncommon,
    'rare' => ItemRarity.rare,
    'epic' => ItemRarity.epic,
    'legendary' => ItemRarity.legendary,
    _ => throw ConfigException(
      'items.json: $where."rarity" tidak dikenal: "$raw" '
      '(pilihan: common, uncommon, rare, epic, legendary).',
    ),
  };
}
