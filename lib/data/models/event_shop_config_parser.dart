import 'dart:convert';

import '../../core/errors/config_exception.dart';
import '../../domain/entities/event_shop_config.dart';
import '../../domain/entities/shop_config.dart';
import 'shop_config_parser.dart';

/// Parser JSON untuk `assets/data/event_shop.json` (M13 Stage 2).
class EventShopConfigParser {
  const EventShopConfigParser();

  static const String _file = 'event_shop.json';
  static const Set<String> _rootKeys = {
    'pool',
    'weekly_purchase_limit',
    'currency_id',
  };
  static const Set<String> _entryKeys = {
    'id',
    'item_id',
    'tier',
    'price',
    'requirements',
  };

  EventShopCatalog parse(String jsonSource) {
    Object? decoded;
    try {
      decoded = jsonDecode(jsonSource);
    } on FormatException catch (e) {
      throw ConfigException('$_file bukan JSON valid: ${e.message}');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ConfigException('$_file: root harus berupa object.');
    }
    ShopConfigParser.rejectUnknownKeys(decoded, _rootKeys, _file);

    final rawPool = decoded['pool'];
    if (rawPool is! List) {
      throw const ConfigException('$_file: "pool" harus berupa array.');
    }

    final seenIds = <String>{};
    final pool = <EventShopEntry>[];
    for (var i = 0; i < rawPool.length; i++) {
      final raw = rawPool[i];
      if (raw is! Map<String, dynamic>) {
        throw ConfigException('$_file: pool[$i] harus berupa object.');
      }
      final entry = _parseEntry(raw, 'pool[$i]');
      if (!seenIds.add(entry.id)) {
        throw ConfigException(
          '$_file: id entri duplikat "${entry.id}" pada pool[$i].',
        );
      }
      pool.add(entry);
    }

    var weeklyLimit = 1;
    if (decoded.containsKey('weekly_purchase_limit')) {
      final rawLimit = decoded['weekly_purchase_limit'];
      if (rawLimit is! int || rawLimit <= 0) {
        throw const ConfigException(
          '$_file: "weekly_purchase_limit" harus berupa integer >= 1.',
        );
      }
      weeklyLimit = rawLimit;
    }

    var currencyId = 'aether_shard';
    if (decoded.containsKey('currency_id')) {
      currencyId = ShopConfigParser.requireNonEmptyString(
        decoded['currency_id'],
        'currency_id',
        fileName: _file,
      );
    }

    return EventShopCatalog(
      pool: pool,
      weeklyPurchaseLimit: weeklyLimit,
      currencyId: currencyId,
    );
  }

  EventShopEntry _parseEntry(Map<String, dynamic> map, String path) {
    ShopConfigParser.rejectUnknownKeys(map, _entryKeys, '$_file: $path');

    final id = ShopConfigParser.requireNonEmptyString(
      map['id'],
      '$path.id',
      fileName: _file,
    );
    final itemId = ShopConfigParser.requireNonEmptyString(
      map['item_id'],
      '$path.item_id',
      fileName: _file,
    );
    final tier = _parseTier(map['tier'], '$path.tier');

    final rawPrice = map['price'];
    if (rawPrice is! int || rawPrice <= 0) {
      throw ConfigException('$_file: $path.price harus berupa integer > 0.');
    }

    final requirements = <PurchaseRequirement>[];
    if (map.containsKey('requirements')) {
      final rawReqs = map['requirements'];
      if (rawReqs is! List) {
        throw ConfigException('$_file: $path.requirements harus berupa array.');
      }
      for (var i = 0; i < rawReqs.length; i++) {
        final rawReq = rawReqs[i];
        if (rawReq is! Map<String, dynamic>) {
          throw ConfigException(
            '$_file: $path.requirements[$i] harus berupa object.',
          );
        }
        requirements.add(
          ShopConfigParser.parseRequirement(
            rawReq,
            '$path.requirements[$i]',
            fileName: _file,
          ),
        );
      }
    }

    return EventShopEntry(
      id: id,
      itemId: itemId,
      tier: tier,
      price: rawPrice,
      requirements: List<PurchaseRequirement>.unmodifiable(requirements),
    );
  }

  EventItemTier _parseTier(Object? value, String path) {
    if (value is! String) {
      throw ConfigException('$_file: $path harus berupa string.');
    }
    switch (value) {
      case 'epic':
        return EventItemTier.epic;
      case 'legendary':
        return EventItemTier.legendary;
      default:
        throw ConfigException(
          '$_file: $path tidak dikenal ("$value"); gunakan "epic" atau "legendary".',
        );
    }
  }
}
