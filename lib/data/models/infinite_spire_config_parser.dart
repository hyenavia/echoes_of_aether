import '../../core/errors/config_exception.dart';
import '../../domain/entities/infinite_spire.dart';
import 'json_reader.dart';

/// Membaca dan memvalidasi `assets/data/infinite_spire.json`.
class InfiniteSpireConfigParser {
  const InfiniteSpireConfigParser();

  static const String _file = 'infinite_spire.json';
  static const JsonReader _r = JsonReader(_file);

  static const Set<String> _rootKeys = {
    'spire_id',
    'name',
    'total_floors',
    'floors',
  };

  static const Set<String> _floorKeys = {
    'floor',
    'name',
    'recommended_level',
    'is_boss_floor',
    'enemy_ids',
    'boss_id',
    'boss_name',
    'affix_description',
    'first_clear_reward',
  };

  static const Set<String> _rewardKeys = {'exp', 'gold', 'items', 'currencies'};

  InfiniteSpireConfig parse(String source) {
    final root = _r.decodeRoot(source);
    _r.ensureKnownKeys(root, 'root', _rootKeys);

    final spireId = _r.string(root, 'root', 'spire_id');
    final name = _r.string(root, 'root', 'name');
    final totalFloors = _r.number(root, 'root', 'total_floors', min: 1).toInt();

    final rawFloors = root['floors'];
    if (rawFloors is! List) {
      throw const ConfigException('$_file: "floors" harus berupa list.');
    }
    if (rawFloors.isEmpty) {
      throw const ConfigException('$_file: "floors" tidak boleh kosong.');
    }

    final floors = <InfiniteSpireFloorDefinition>[];
    for (var i = 0; i < rawFloors.length; i++) {
      final path = 'floors[$i]';
      final item = rawFloors[i];
      if (item is! Map<String, dynamic>) {
        throw ConfigException('$_file: $path harus berupa map.');
      }
      _r.ensureKnownKeys(item, path, _floorKeys);

      final floorNum = _r.number(item, path, 'floor', min: 1).toInt();
      if (floorNum != i + 1) {
        throw ConfigException(
          '$_file: $path."floor" harus urut (ekspektasi ${i + 1}, didapat $floorNum).',
        );
      }

      final floorName = _r.string(item, path, 'name');
      final recommendedLevel = _r
          .number(item, path, 'recommended_level', min: 1)
          .toInt();
      final isBossFloor = item['is_boss_floor'] as bool? ?? false;

      final rawEnemyIds = item['enemy_ids'];
      final List<String> enemyIds;
      if (rawEnemyIds is List) {
        enemyIds = rawEnemyIds.map((e) => e.toString()).toList();
      } else {
        enemyIds = const [];
      }

      final bossId = item['boss_id'] as String?;
      final bossName = item['boss_name'] as String?;
      final affix = item['affix_description'] as String?;

      // Reward
      final rawReward = item['first_clear_reward'];
      final InfiniteSpireReward reward;
      if (rawReward is Map<String, dynamic>) {
        _r.ensureKnownKeys(rawReward, '$path.first_clear_reward', _rewardKeys);
        final exp = (rawReward['exp'] as num?)?.toInt() ?? 0;
        final gold = (rawReward['gold'] as num?)?.toInt() ?? 0;

        final rawItems = rawReward['items'];
        final Map<String, int> items = {};
        if (rawItems is Map) {
          for (final entry in rawItems.entries) {
            items[entry.key.toString()] = (entry.value as num).toInt();
          }
        }

        final rawCurr = rawReward['currencies'];
        final Map<String, int> currencies = {};
        if (rawCurr is Map) {
          for (final entry in rawCurr.entries) {
            currencies[entry.key.toString()] = (entry.value as num).toInt();
          }
        }

        reward = InfiniteSpireReward(
          exp: exp,
          gold: gold,
          items: Map.unmodifiable(items),
          currencies: Map.unmodifiable(currencies),
        );
      } else {
        reward = const InfiniteSpireReward();
      }

      floors.add(
        InfiniteSpireFloorDefinition(
          floor: floorNum,
          name: floorName,
          recommendedLevel: recommendedLevel,
          isBossFloor: isBossFloor,
          enemyIds: List.unmodifiable(enemyIds),
          bossId: bossId,
          bossName: bossName,
          affixDescription: affix,
          reward: reward,
        ),
      );
    }

    return InfiniteSpireConfig(
      spireId: spireId,
      name: name,
      totalFloors: totalFloors,
      floors: List.unmodifiable(floors),
    );
  }
}
