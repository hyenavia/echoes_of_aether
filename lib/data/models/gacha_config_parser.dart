import '../../core/errors/config_exception.dart';
import '../../domain/entities/gacha_config.dart';
import 'json_reader.dart';

/// Parser untuk `gacha_banners.json`.
class GachaConfigParser {
  const GachaConfigParser();

  static const JsonReader _r = JsonReader('gacha_banners.json');

  GachaConfig parse(String source) {
    final root = _r.decodeRoot(source);
    _r.ensureKnownKeys(root, 'root', {
      'cycle_days',
      'cost_per_pull',
      'cost_per_ten_pull',
      'currency_id',
      'duplicate_currency_id',
      'duplicate_granted_amount',
      'banners',
      'sanctuary_exchange',
    });

    final cycleDays = _r.integer(root, 'root', 'cycle_days', min: 1);
    final costPerPull = _r.integer(root, 'root', 'cost_per_pull', min: 1);
    final costPerTenPull = _r.integer(
      root,
      'root',
      'cost_per_ten_pull',
      min: costPerPull,
    );
    final currencyId = _r.string(root, 'root', 'currency_id');
    final duplicateCurrencyId = _r.string(
      root,
      'root',
      'duplicate_currency_id',
    );
    final duplicateGrantedAmount = _r.integer(
      root,
      'root',
      'duplicate_granted_amount',
      min: 1,
    );

    final rawBanners = _r.list(root, 'root', 'banners');
    final banners = <String, GachaBannerDefinition>{};

    for (var i = 0; i < rawBanners.length; i++) {
      final where = 'banners[$i]';
      final bMap = _r.asMap(rawBanners[i], where);
      _r.ensureKnownKeys(bMap, where, {
        'id',
        'name',
        'type',
        'hard_pity',
        'base_rate',
        'rate_up_share',
        'featured_pool',
        'standard_pool',
      });

      final id = _r.string(bMap, where, 'id');
      if (banners.containsKey(id)) {
        throw ConfigException('gacha_banners.json: banner id ganda "$id".');
      }

      final typeStr = _r.string(bMap, where, 'type');
      final type = GachaBannerType.fromString(typeStr);
      final hardPity = _r.integer(bMap, where, 'hard_pity', min: 1);
      final baseRate = _r.number(
        bMap,
        where,
        'base_rate',
        min: 0.0001,
        max: 1.0,
      );
      final rateUpShare = bMap['rate_up_share'] == null
          ? 0.5
          : _r.number(bMap, where, 'rate_up_share', min: 0.0, max: 1.0);

      final featuredList = _parseStringList(bMap, where, 'featured_pool');
      final standardList = _parseStringList(bMap, where, 'standard_pool');

      banners[id] = GachaBannerDefinition(
        id: id,
        name: _r.string(bMap, where, 'name'),
        type: type,
        hardPity: hardPity,
        baseRate: baseRate,
        rateUpShare: rateUpShare,
        featuredPool: featuredList,
        standardPool: standardList,
      );
    }

    final sMap = _r.asMap(
      root['sanctuary_exchange'],
      'root.sanctuary_exchange',
    );
    _r.ensureKnownKeys(sMap, 'root.sanctuary_exchange', {
      'currency_id',
      'class_cost',
      'weapon_cost',
    });

    final sanctuaryExchange = SanctuaryExchangeConfig(
      currencyId: _r.string(sMap, 'root.sanctuary_exchange', 'currency_id'),
      classCost: _r.integer(
        sMap,
        'root.sanctuary_exchange',
        'class_cost',
        min: 1,
      ),
      weaponCost: _r.integer(
        sMap,
        'root.sanctuary_exchange',
        'weapon_cost',
        min: 1,
      ),
    );

    return GachaConfig(
      cycleDays: cycleDays,
      costPerPull: costPerPull,
      costPerTenPull: costPerTenPull,
      currencyId: currencyId,
      duplicateCurrencyId: duplicateCurrencyId,
      duplicateGrantedAmount: duplicateGrantedAmount,
      banners: banners,
      sanctuaryExchange: sanctuaryExchange,
    );
  }

  List<String> _parseStringList(
    Map<String, dynamic> map,
    String where,
    String key,
  ) {
    final list = _r.list(map, where, key);
    final result = <String>[];
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is! String || item.trim().isEmpty) {
        throw ConfigException(
          'gacha_banners.json: $where.$key[$i] harus berupa string tidak kosong.',
        );
      }
      result.add(item);
    }
    return List.unmodifiable(result);
  }
}
