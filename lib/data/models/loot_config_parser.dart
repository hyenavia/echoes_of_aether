import '../../core/errors/config_exception.dart';
import '../../domain/entities/loot_table.dart';
import 'json_reader.dart';

/// Membaca dan memvalidasi loot_tables.json. Kecocokan item_id dengan
/// items.json diperiksa oleh `GameConfigValidator`.
class LootConfigParser {
  const LootConfigParser();

  static const JsonReader _r = JsonReader('loot_tables.json');

  Map<String, LootTable> parse(String source) {
    final root = _r.decodeRoot(source);
    final list = _r.list(root, 'root', 'loot_tables');

    final result = <String, LootTable>{};
    for (var i = 0; i < list.length; i++) {
      final where = 'loot_tables[$i]';
      final map = _r.asMap(list[i], where);
      final id = _r.string(map, where, 'id');
      if (result.containsKey(id)) {
        throw ConfigException('loot_tables.json: id ganda "$id".');
      }
      final rawEntries = _r.list(map, where, 'entries');
      final entries = <LootEntry>[
        for (var j = 0; j < rawEntries.length; j++)
          _parseEntry(rawEntries[j], '$where.entries[$j]'),
      ];
      result[id] = LootTable(id: id, entries: entries);
    }
    return result;
  }

  LootEntry _parseEntry(Object? raw, String where) {
    final map = _r.asMap(raw, where);
    final min = _r.integer(map, where, 'min_quantity', min: 1, fallback: 1);
    final max = _r.integer(map, where, 'max_quantity', min: 1, fallback: min);
    if (max < min) {
      throw ConfigException(
        'loot_tables.json: $where."max_quantity" ($max) < "min_quantity" ($min).',
      );
    }
    return LootEntry(
      itemId: _r.string(map, where, 'item_id'),
      chance: _r.number(
        map,
        where,
        'chance',
        min: 0,
        minExclusive: true,
        max: 1,
      ),
      minQuantity: min,
      maxQuantity: max,
    );
  }
}
