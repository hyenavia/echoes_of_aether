import 'dart:convert';

import '../../core/errors/config_exception.dart';
import '../../domain/entities/item_definition.dart';
import '../../domain/entities/shop_config.dart';

/// Parser JSON untuk `assets/data/shop.json` (M10 Stage 1).
class ShopConfigParser {
  const ShopConfigParser();

  static const Set<String> _rootKeys = {'entries', 'sell'};
  static const Set<String> _entryKeys = {
    'id',
    'item_id',
    'price',
    'purchase_limit',
    'requirements',
  };
  static const Set<String> _sellKeys = {
    'sellable_categories',
    'confirm_min_rarity',
    'equipped_sellable',
    'max_sell_ratio',
  };

  ShopCatalog parse(String jsonSource) {
    final decoded = jsonDecode(jsonSource);
    if (decoded is! Map<String, dynamic>) {
      throw const ConfigException('shop.json: root harus berupa object.');
    }
    _rejectUnknownKeys(decoded, _rootKeys, 'shop.json');

    final rawEntries = decoded['entries'];
    if (rawEntries is! List) {
      throw const ConfigException('shop.json: "entries" harus berupa array.');
    }

    final seenIds = <String>{};
    final entries = <ShopEntry>[];
    for (var i = 0; i < rawEntries.length; i++) {
      final raw = rawEntries[i];
      if (raw is! Map<String, dynamic>) {
        throw ConfigException('shop.json: entries[$i] harus berupa object.');
      }
      final entry = _parseEntry(raw, 'entries[$i]');
      if (!seenIds.add(entry.id)) {
        throw ConfigException(
          'shop.json: id entri duplikat "${entry.id}" pada entries[$i].',
        );
      }
      entries.add(entry);
    }

    final sell = decoded.containsKey('sell')
        ? _parseSellRules(decoded['sell'])
        : const SellRules();

    return ShopCatalog(entries: entries, sell: sell);
  }

  ShopEntry _parseEntry(Map<String, dynamic> map, String path) {
    _rejectUnknownKeys(map, _entryKeys, 'shop.json: $path');

    final id = _requireNonEmptyString(map['id'], '$path.id');
    final itemId = _requireNonEmptyString(map['item_id'], '$path.item_id');

    final rawPrice = map['price'];
    if (rawPrice is! int || rawPrice <= 0) {
      throw ConfigException('shop.json: $path.price harus berupa integer > 0.');
    }

    int? purchaseLimit;
    final rawLimit = map['purchase_limit'];
    if (rawLimit != null) {
      if (rawLimit is! int || rawLimit <= 0) {
        throw ConfigException(
          'shop.json: $path.purchase_limit harus null atau integer > 0.',
        );
      }
      purchaseLimit = rawLimit;
    }

    final requirements = <PurchaseRequirement>[];
    if (map.containsKey('requirements')) {
      final rawReqs = map['requirements'];
      if (rawReqs is! List) {
        throw ConfigException(
          'shop.json: $path.requirements harus berupa array.',
        );
      }
      for (var i = 0; i < rawReqs.length; i++) {
        final rawReq = rawReqs[i];
        if (rawReq is! Map<String, dynamic>) {
          throw ConfigException(
            'shop.json: $path.requirements[$i] harus berupa object.',
          );
        }
        requirements.add(_parseRequirement(rawReq, '$path.requirements[$i]'));
      }
    }

    return ShopEntry(
      id: id,
      itemId: itemId,
      price: rawPrice,
      purchaseLimit: purchaseLimit,
      requirements: List<PurchaseRequirement>.unmodifiable(requirements),
    );
  }

  PurchaseRequirement _parseRequirement(Map<String, dynamic> map, String path) {
    final type = _requireNonEmptyString(map['type'], '$path.type');
    switch (type) {
      case 'min_level':
        _rejectUnknownKeys(map, const {'type', 'value'}, 'shop.json: $path');
        final value = map['value'];
        if (value is! int || value < 1) {
          throw ConfigException(
            'shop.json: $path.value (min_level) harus integer >= 1.',
          );
        }
        return MinLevelRequirement(value);
      case 'dungeon_cleared':
        _rejectUnknownKeys(map, const {
          'type',
          'dungeon_id',
        }, 'shop.json: $path');
        final dungeonId = _requireNonEmptyString(
          map['dungeon_id'],
          '$path.dungeon_id',
        );
        return DungeonClearedRequirement(dungeonId);
      case 'min_ascension_rank':
        _rejectUnknownKeys(map, const {'type', 'value'}, 'shop.json: $path');
        final value = map['value'];
        if (value is! int || value < 0) {
          throw ConfigException(
            'shop.json: $path.value (min_ascension_rank) harus integer >= 0.',
          );
        }
        return MinAscensionRankRequirement(value);
      default:
        throw ConfigException('shop.json: $path.type tidak dikenal ("$type").');
    }
  }

  SellRules _parseSellRules(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const ConfigException('shop.json: "sell" harus berupa object.');
    }
    _rejectUnknownKeys(raw, _sellKeys, 'shop.json: sell');

    final categories = <ItemCategory>{};
    if (raw.containsKey('sellable_categories')) {
      final rawCats = raw['sellable_categories'];
      if (rawCats is! List) {
        throw const ConfigException(
          'shop.json: sell.sellable_categories harus berupa array.',
        );
      }
      for (var i = 0; i < rawCats.length; i++) {
        final name = rawCats[i];
        if (name is! String) {
          throw ConfigException(
            'shop.json: sell.sellable_categories[$i] harus string.',
          );
        }
        categories.add(_parseCategory(name, 'sell.sellable_categories[$i]'));
      }
    } else {
      categories.addAll(const {ItemCategory.equipment, ItemCategory.material});
    }

    final confirmMinRarity = raw.containsKey('confirm_min_rarity')
        ? _parseRarity(raw['confirm_min_rarity'], 'sell.confirm_min_rarity')
        : ItemRarity.rare;

    final equippedSellable = raw['equipped_sellable'] ?? false;
    if (equippedSellable is! bool) {
      throw const ConfigException(
        'shop.json: sell.equipped_sellable harus boolean.',
      );
    }

    final rawRatio = raw['max_sell_ratio'] ?? 0.4;
    if (rawRatio is! num ||
        !rawRatio.isFinite ||
        rawRatio <= 0 ||
        rawRatio > 1) {
      throw const ConfigException(
        'shop.json: sell.max_sell_ratio harus angka pada rentang (0, 1].',
      );
    }

    return SellRules(
      sellableCategories: Set<ItemCategory>.unmodifiable(categories),
      confirmMinRarity: confirmMinRarity,
      equippedSellable: equippedSellable,
      maxSellRatio: rawRatio.toDouble(),
    );
  }

  ItemCategory _parseCategory(String value, String path) {
    switch (value) {
      case 'equipment':
        return ItemCategory.equipment;
      case 'material':
        return ItemCategory.material;
      case 'consumable':
        return ItemCategory.consumable;
      case 'quest_item':
        return ItemCategory.questItem;
      default:
        throw ConfigException('shop.json: $path tidak dikenal ("$value").');
    }
  }

  ItemRarity _parseRarity(Object? value, String path) {
    if (value is! String) {
      throw ConfigException('shop.json: $path harus string.');
    }
    switch (value) {
      case 'common':
        return ItemRarity.common;
      case 'uncommon':
        return ItemRarity.uncommon;
      case 'rare':
        return ItemRarity.rare;
      case 'epic':
        return ItemRarity.epic;
      case 'legendary':
        return ItemRarity.legendary;
      default:
        throw ConfigException('shop.json: $path tidak dikenal ("$value").');
    }
  }

  String _requireNonEmptyString(Object? value, String path) {
    if (value is! String || value.trim().isEmpty) {
      throw ConfigException(
        'shop.json: $path harus berupa string tidak kosong.',
      );
    }
    return value.trim();
  }

  void _rejectUnknownKeys(
    Map<String, dynamic> map,
    Set<String> allowed,
    String context,
  ) {
    for (final key in map.keys) {
      if (!allowed.contains(key)) {
        throw ConfigException('$context: field tidak dikenal "$key".');
      }
    }
  }
}
