import '../../core/errors/config_exception.dart';
import '../../domain/entities/dungeon_definition.dart';
import '../../domain/entities/dungeon_reward.dart';
import '../../domain/entities/grid_point.dart';
import '../../domain/services/navigation_grid.dart';
import 'json_reader.dart';

/// Membaca dan memvalidasi `dungeons.json`.
class DungeonConfigParser {
  const DungeonConfigParser();

  static const JsonReader _r = JsonReader('dungeons.json');

  static const _dungeonKeys = {
    'id',
    'name',
    'biome',
    'kind',
    'order',
    'difficulty_scale',
    'recommended_level',
    'unlock_requires_dungeon_id',
    'base_dungeon_id',
    'start_room_id',
    'completion_reward',
    'rooms',
  };

  static const _roomKeys = {
    'id',
    'name',
    'type',
    'map_ref',
    'layout',
    'entry_position',
    'exit_position',
    'spawns',
    'completion_condition',
    'next_room_ids',
    'reward',
  };

  static const _spawnKeys = {
    'id',
    'monster_id',
    'position',
    'quantity',
    'spawn_group',
    'is_elite',
    'is_boss',
    'required',
    'activation_state',
    'activation_trigger_group',
    'stat_modifier',
  };

  static const _statModifierKeys = {
    'hp_multiplier',
    'atk_multiplier',
    'def_multiplier',
    'hp_bonus',
    'atk_bonus',
    'def_bonus',
  };

  static const _conditionKeys = {
    'type',
    'required_spawn_group',
    'target_count',
    'require_exit',
    'conditions',
  };

  static const _rewardKeys = {'exp_reward', 'gold_reward', 'loot_table_id'};

  /// Mengekstrak peta layout bernama dari section `maps` di `dungeons.json`.
  Map<String, List<String>> parseMaps(String source) {
    final root = _r.decodeRoot(source);
    return Map.unmodifiable(_parseMaps(root['maps']));
  }

  Map<String, DungeonDefinition> parse(
    String source, {
    double ascensionMultiplier = 1.35,
  }) {
    if (!ascensionMultiplier.isFinite || ascensionMultiplier < 0.1) {
      throw ConfigException(
        'dungeons.json: ascensionMultiplier harus >= 0.1 (nilai: $ascensionMultiplier).',
      );
    }
    final root = _r.decodeRoot(source);
    final maps = _parseMaps(root['maps']);
    final list = _r.list(root, 'root', 'dungeons');

    final seenIds = <String>{};
    final normalById = <String, DungeonDefinition>{};
    final resolvedByIndex = List<DungeonDefinition?>.filled(list.length, null);
    final deferredAscension =
        <({int index, String where, Map<String, dynamic> map})>[];

    // Pass 1: parse seluruh dungeon normal terlebih dahulu.
    for (var i = 0; i < list.length; i++) {
      final where = 'dungeons[$i]';
      final m = _r.asMap(list[i], where);
      _r.ensureKnownKeys(m, where, _dungeonKeys);

      final id = _r.string(m, where, 'id');
      if (!seenIds.add(id)) {
        throw ConfigException('dungeons.json: id dungeon ganda "$id".');
      }

      final kind = _parseDungeonKind(m['kind'], '$where.kind');
      if (kind == DungeonKind.ascension) {
        deferredAscension.add((index: i, where: where, map: m));
        continue;
      }

      if (m['base_dungeon_id'] != null) {
        throw ConfigException(
          'dungeons.json: $where."base_dungeon_id" hanya diizinkan untuk kind "ascension".',
        );
      }

      final dungeon = _parseNormalDungeon(m, where, index: i, maps: maps);
      normalById[dungeon.id] = dungeon;
      resolvedByIndex[i] = dungeon;
    }

    // Pass 2: bangun dungeon ascension berdasarkan dungeon normal dasar.
    for (final item in deferredAscension) {
      final dungeon = _parseAscensionDungeon(
        item.map,
        item.where,
        index: item.index,
        normalById: normalById,
        ascensionMultiplier: ascensionMultiplier,
      );
      resolvedByIndex[item.index] = dungeon;
    }

    final result = <String, DungeonDefinition>{};
    for (final dungeon in resolvedByIndex) {
      if (dungeon != null) {
        result[dungeon.id] = dungeon;
      }
    }
    return result;
  }

  Map<String, List<String>> _parseMaps(Object? raw) {
    if (raw == null) return const {};
    final map = _r.asMap(raw, 'maps');
    final result = <String, List<String>>{};
    for (final entry in map.entries) {
      if (entry.key.isEmpty) {
        throw const ConfigException(
          'dungeons.json: id map tidak boleh kosong.',
        );
      }
      result[entry.key] = _parseLayout(entry.value, 'maps."${entry.key}"');
    }
    return result;
  }

  DungeonDefinition _parseNormalDungeon(
    Map<String, dynamic> m,
    String where, {
    required int index,
    required Map<String, List<String>> maps,
  }) {
    final id = _r.string(m, where, 'id');
    final name = _r.string(m, where, 'name');
    final biome = _r.string(m, where, 'biome');
    final startRoomId = _r.string(m, where, 'start_room_id');
    final order = _r.integer(m, where, 'order', min: 1, fallback: index + 1);
    final recommendedLevel = _r.integer(
      m,
      where,
      'recommended_level',
      min: 1,
      fallback: 1,
    );
    final unlockRequiresDungeonId = _optionalNonEmptyString(
      m,
      where,
      'unlock_requires_dungeon_id',
    );
    final difficultyScale = _r.number(
      m,
      where,
      'difficulty_scale',
      min: 0.1,
      fallback: 1.0,
    );
    final completionReward = _parseCompletionReward(
      m['completion_reward'],
      '$where.completion_reward',
    );

    final roomsRaw = _r.list(m, where, 'rooms');
    if (roomsRaw.isEmpty) {
      throw ConfigException(
        'dungeons.json: $where."rooms" tidak boleh kosong.',
      );
    }

    final rooms = <String, RoomDefinition>{};
    final roomOrder = <String>[];
    for (var i = 0; i < roomsRaw.length; i++) {
      final room = _parseRoom(
        roomsRaw[i],
        '$where.rooms[$i]',
        dungeonId: id,
        maps: maps,
      );
      if (rooms.containsKey(room.id)) {
        throw ConfigException(
          'dungeons.json: id room ganda "${room.id}" pada dungeon "$id".',
        );
      }
      rooms[room.id] = room;
      roomOrder.add(room.id);
    }

    if (!rooms.containsKey(startRoomId)) {
      throw ConfigException(
        'dungeons.json: $where.start_room_id "$startRoomId" tidak ditemukan '
        'di daftar rooms.',
      );
    }

    return DungeonDefinition(
      id: id,
      name: name,
      biome: biome,
      startRoomId: startRoomId,
      rooms: Map.unmodifiable(rooms),
      roomOrder: List.unmodifiable(roomOrder),
      kind: DungeonKind.normal,
      order: order,
      recommendedLevel: recommendedLevel,
      unlockRequiresDungeonId: unlockRequiresDungeonId,
      difficultyScale: difficultyScale,
      completionReward: completionReward,
    );
  }

  DungeonDefinition _parseAscensionDungeon(
    Map<String, dynamic> m,
    String where, {
    required int index,
    required Map<String, DungeonDefinition> normalById,
    required double ascensionMultiplier,
  }) {
    final id = _r.string(m, where, 'id');
    final name = _r.string(m, where, 'name');
    final baseDungeonId = _r.string(m, where, 'base_dungeon_id');
    final base = normalById[baseDungeonId];
    if (base == null) {
      throw ConfigException(
        'dungeons.json: $where."base_dungeon_id" merujuk "$baseDungeonId" '
        'yang tidak ditemukan atau bukan dungeon normal.',
      );
    }

    final rawRooms = m['rooms'];
    if (rawRooms != null) {
      if (rawRooms is! List || rawRooms.isNotEmpty) {
        throw ConfigException(
          'dungeons.json: $where (kind "ascension") tidak boleh mendefinisikan '
          'rooms custom; gunakan base_dungeon_id.',
        );
      }
    }

    final biome = _optionalNonEmptyString(m, where, 'biome') ?? base.biome;
    final startRoomId =
        _optionalNonEmptyString(m, where, 'start_room_id') ?? base.startRoomId;
    final order = _r.integer(m, where, 'order', min: 1, fallback: index + 1);
    final recommendedLevel = _r.integer(
      m,
      where,
      'recommended_level',
      min: 1,
      fallback: base.recommendedLevel,
    );
    final unlockRequiresDungeonId = _optionalNonEmptyString(
      m,
      where,
      'unlock_requires_dungeon_id',
    );
    final difficultyScale = m['difficulty_scale'] == null
        ? base.difficultyScale * ascensionMultiplier
        : _r.number(m, where, 'difficulty_scale', min: 0.1) *
              ascensionMultiplier;
    final completionReward = _parseCompletionReward(
      m['completion_reward'],
      '$where.completion_reward',
    );

    final clonedRooms = <String, RoomDefinition>{
      for (final entry in base.rooms.entries)
        entry.key: entry.value.copyWith(dungeonId: id),
    };
    if (!clonedRooms.containsKey(startRoomId)) {
      throw ConfigException(
        'dungeons.json: $where.start_room_id "$startRoomId" tidak ditemukan '
        'pada base dungeon "$baseDungeonId".',
      );
    }

    return DungeonDefinition(
      id: id,
      name: name,
      biome: biome,
      startRoomId: startRoomId,
      rooms: Map.unmodifiable(clonedRooms),
      roomOrder: base.roomOrder,
      kind: DungeonKind.ascension,
      order: order,
      recommendedLevel: recommendedLevel,
      unlockRequiresDungeonId: unlockRequiresDungeonId,
      baseDungeonId: baseDungeonId,
      difficultyScale: difficultyScale,
      completionReward: completionReward,
    );
  }

  DungeonKind _parseDungeonKind(Object? raw, String where) {
    if (raw == null) return DungeonKind.normal;
    if (raw is! String) {
      throw ConfigException('dungeons.json: $where harus berupa teks.');
    }
    switch (raw) {
      case 'normal':
        return DungeonKind.normal;
      case 'ascension':
        return DungeonKind.ascension;
      default:
        throw ConfigException(
          'dungeons.json: $where tidak dikenal "$raw" (valid: normal, ascension).',
        );
    }
  }

  String? _optionalNonEmptyString(
    Map<String, dynamic> map,
    String where,
    String key,
  ) {
    if (map[key] == null) return null;
    return _r.string(map, where, key);
  }

  RoomDefinition _parseRoom(
    Object? raw,
    String where, {
    required String dungeonId,
    required Map<String, List<String>> maps,
  }) {
    final m = _r.asMap(raw, where);
    _r.ensureKnownKeys(m, where, _roomKeys);

    final id = _r.string(m, where, 'id');
    final name = _r.string(m, where, 'name');
    final type = _parseRoomType(m['type'], '$where.type');

    final mapRefRaw = m['map_ref'];
    final layoutRaw = m['layout'];
    late final String mapRef;
    late final List<String> layout;

    if (mapRefRaw != null) {
      if (mapRefRaw is! String || mapRefRaw.isEmpty) {
        throw ConfigException(
          'dungeons.json: $where."map_ref" harus berupa teks tidak kosong.',
        );
      }
      mapRef = mapRefRaw;
      if (layoutRaw != null) {
        layout = _parseLayout(layoutRaw, '$where.layout');
      } else {
        final resolved = maps[mapRef];
        if (resolved == null) {
          throw ConfigException(
            'dungeons.json: $where merujuk map_ref "$mapRef" yang tidak ada di maps.',
          );
        }
        layout = resolved;
      }
    } else if (layoutRaw != null) {
      mapRef = id;
      layout = _parseLayout(layoutRaw, '$where.layout');
    } else {
      throw ConfigException(
        'dungeons.json: $where wajib memiliki "map_ref" atau "layout".',
      );
    }

    final NavigationGrid grid;
    try {
      grid = NavigationGrid.fromAscii(layout);
    } on ArgumentError catch (e) {
      throw ConfigException(
        'dungeons.json: $where layout tidak valid: ${e.message}',
      );
    }

    final entryPosition = _parseGridPoint(
      m['entry_position'],
      '$where.entry_position',
    );
    _ensureWalkable(grid, entryPosition, '$where.entry_position');

    final exitPosition = _parseGridPoint(
      m['exit_position'],
      '$where.exit_position',
    );
    _ensureWalkable(grid, exitPosition, '$where.exit_position');

    final spawnsRaw = _r.list(m, where, 'spawns');
    final spawns = <RoomSpawnConfig>[];
    final seenSpawnIds = <String>{};
    for (var i = 0; i < spawnsRaw.length; i++) {
      final spawn = _parseSpawn(
        spawnsRaw[i],
        '$where.spawns[$i]',
        grid: grid,
        fallbackId: '${id}_spawn_$i',
      );
      if (!seenSpawnIds.add(spawn.id)) {
        throw ConfigException(
          'dungeons.json: id spawn ganda "${spawn.id}" di room "$id".',
        );
      }
      spawns.add(spawn);
    }

    final completionCondition = _parseCondition(
      m['completion_condition'],
      '$where.completion_condition',
    );

    final nextRoomIds = _parseStringList(
      m['next_room_ids'],
      '$where.next_room_ids',
    );

    final reward = _parseRoomReward(m['reward'], '$where.reward');

    return RoomDefinition(
      id: id,
      dungeonId: dungeonId,
      name: name,
      type: type,
      mapRef: mapRef,
      layout: layout,
      entryPosition: entryPosition,
      exitPosition: exitPosition,
      spawns: List.unmodifiable(spawns),
      completionCondition: completionCondition,
      nextRoomIds: List.unmodifiable(nextRoomIds),
      reward: reward,
    );
  }

  RoomSpawnConfig _parseSpawn(
    Object? raw,
    String where, {
    required NavigationGrid grid,
    required String fallbackId,
  }) {
    final m = _r.asMap(raw, where);
    _r.ensureKnownKeys(m, where, _spawnKeys);

    final idRaw = m['id'];
    final String id;
    if (idRaw == null) {
      id = fallbackId;
    } else if (idRaw is String && idRaw.isNotEmpty) {
      id = idRaw;
    } else {
      throw ConfigException(
        'dungeons.json: $where."id" harus berupa teks tidak kosong.',
      );
    }

    final monsterId = _r.string(m, where, 'monster_id');
    final position = _parseGridPoint(m['position'], '$where.position');
    _ensureWalkable(grid, position, '$where.position');

    final quantity = _r.integer(m, where, 'quantity', min: 1, fallback: 1);
    final spawnGroupRaw = m['spawn_group'];
    final spawnGroup = spawnGroupRaw == null
        ? 'default'
        : _nonEmptyString(spawnGroupRaw, '$where.spawn_group');

    final isElite = _bool(m, where, 'is_elite', fallback: false);
    final isBoss = _bool(m, where, 'is_boss', fallback: false);
    if (isElite && isBoss) {
      throw ConfigException(
        'dungeons.json: $where tidak boleh sekaligus is_elite dan is_boss.',
      );
    }

    final requiredSpawn = _bool(m, where, 'required', fallback: true);
    final activationState = _parseActivationState(
      m['activation_state'],
      '$where.activation_state',
    );

    final triggerRaw = m['activation_trigger_group'];
    String? triggerGroup;
    if (triggerRaw != null) {
      triggerGroup = _nonEmptyString(
        triggerRaw,
        '$where.activation_trigger_group',
      );
    }

    final statModifier = _parseStatModifier(
      m['stat_modifier'],
      '$where.stat_modifier',
    );

    return RoomSpawnConfig(
      id: id,
      monsterId: monsterId,
      position: position,
      quantity: quantity,
      spawnGroup: spawnGroup,
      isElite: isElite,
      isBoss: isBoss,
      required: requiredSpawn,
      activationState: activationState,
      activationTriggerGroup: triggerGroup,
      statModifier: statModifier,
    );
  }

  SpawnStatModifier _parseStatModifier(Object? raw, String where) {
    if (raw == null) return const SpawnStatModifier();
    final m = _r.asMap(raw, where);
    _r.ensureKnownKeys(m, where, _statModifierKeys);
    return SpawnStatModifier(
      hpMultiplier: _r.number(
        m,
        where,
        'hp_multiplier',
        min: 0,
        minExclusive: true,
        fallback: 1.0,
      ),
      atkMultiplier: _r.number(
        m,
        where,
        'atk_multiplier',
        min: 0,
        minExclusive: true,
        fallback: 1.0,
      ),
      defMultiplier: _r.number(
        m,
        where,
        'def_multiplier',
        min: 0,
        minExclusive: true,
        fallback: 1.0,
      ),
      hpBonus: _r.integer(m, where, 'hp_bonus', min: 0, fallback: 0),
      atkBonus: _r.integer(m, where, 'atk_bonus', min: 0, fallback: 0),
      defBonus: _r.integer(m, where, 'def_bonus', min: 0, fallback: 0),
    );
  }

  RoomCompletionCondition _parseCondition(
    Object? raw,
    String where, {
    bool allowNested = true,
  }) {
    final m = _r.asMap(raw, where);
    _r.ensureKnownKeys(m, where, _conditionKeys);

    final typeRaw = _r.string(m, where, 'type');
    final RoomCompletionConditionType type;
    switch (typeRaw) {
      case 'defeat_required_enemies':
        type = RoomCompletionConditionType.defeatRequiredEnemies;
      case 'defeat_elite':
        type = RoomCompletionConditionType.defeatElite;
      case 'defeat_boss':
        type = RoomCompletionConditionType.defeatBoss;
      case 'reach_exit':
        type = RoomCompletionConditionType.reachExit;
      default:
        throw ConfigException(
          'dungeons.json: $where."type" tidak dikenal "$typeRaw".',
        );
    }

    final groupRaw = m['required_spawn_group'];
    String? requiredGroup;
    if (groupRaw != null) {
      requiredGroup = _nonEmptyString(groupRaw, '$where.required_spawn_group');
    }

    final targetCount = m['target_count'] == null
        ? null
        : _r.integer(m, where, 'target_count', min: 1);

    final requireExit = _bool(m, where, 'require_exit', fallback: false);

    final additionalRaw = m['conditions'];
    final additional = <RoomCompletionCondition>[];
    if (additionalRaw != null) {
      if (!allowNested) {
        throw ConfigException(
          'dungeons.json: $where."conditions" tidak mendukung kondisi bersarang bertingkat.',
        );
      }
      if (additionalRaw is! List) {
        throw ConfigException(
          'dungeons.json: $where."conditions" harus berupa array.',
        );
      }
      for (var i = 0; i < additionalRaw.length; i++) {
        additional.add(
          _parseCondition(
            additionalRaw[i],
            '$where.conditions[$i]',
            allowNested: false,
          ),
        );
      }
    }

    return RoomCompletionCondition(
      type: type,
      requiredSpawnGroup: requiredGroup,
      targetCount: targetCount,
      requireExit: requireExit,
      additionalConditions: List.unmodifiable(additional),
    );
  }

  RoomRewardConfig? _parseRoomReward(Object? raw, String where) {
    if (raw == null) return null;
    final m = _r.asMap(raw, where);
    _r.ensureKnownKeys(m, where, _rewardKeys);

    final tableRaw = m['loot_table_id'];
    String? lootTableId;
    if (tableRaw != null) {
      lootTableId = _nonEmptyString(tableRaw, '$where.loot_table_id');
    }
    return RoomRewardConfig(
      expReward: _r.integer(m, where, 'exp_reward', min: 0, fallback: 0),
      goldReward: _r.integer(m, where, 'gold_reward', min: 0, fallback: 0),
      lootTableId: lootTableId,
    );
  }

  DungeonCompletionReward? _parseCompletionReward(Object? raw, String where) {
    if (raw == null) return null;
    final m = _r.asMap(raw, where);
    _r.ensureKnownKeys(m, where, _rewardKeys);

    final tableRaw = m['loot_table_id'];
    String? lootTableId;
    if (tableRaw != null) {
      lootTableId = _nonEmptyString(tableRaw, '$where.loot_table_id');
    }
    return DungeonCompletionReward(
      expReward: _r.integer(m, where, 'exp_reward', min: 0, fallback: 0),
      goldReward: _r.integer(m, where, 'gold_reward', min: 0, fallback: 0),
      lootTableId: lootTableId,
    );
  }

  List<String> _parseLayout(Object? raw, String where) {
    if (raw is! List || raw.isEmpty) {
      throw ConfigException(
        'dungeons.json: $where harus berupa array string tidak kosong.',
      );
    }
    final rows = <String>[];
    int? expectedCols;
    for (var i = 0; i < raw.length; i++) {
      final line = raw[i];
      if (line is! String || line.isEmpty) {
        throw ConfigException(
          'dungeons.json: $where[$i] harus berupa baris teks tidak kosong.',
        );
      }
      expectedCols ??= line.length;
      if (line.length != expectedCols) {
        throw ConfigException(
          'dungeons.json: $where[$i] panjang ${line.length}, seharusnya $expectedCols.',
        );
      }
      rows.add(line);
    }
    return List.unmodifiable(rows);
  }

  GridPoint _parseGridPoint(Object? raw, String where) {
    final m = _r.asMap(raw, where);
    _r.ensureKnownKeys(m, where, {'x', 'y'});
    return GridPoint(
      _r.integer(m, where, 'x', min: 0),
      _r.integer(m, where, 'y', min: 0),
    );
  }

  void _ensureWalkable(NavigationGrid grid, GridPoint point, String where) {
    if (!grid.inBounds(point.x, point.y)) {
      throw ConfigException(
        'dungeons.json: $where (${point.x}, ${point.y}) berada di luar ukuran map '
        '(${grid.columns}x${grid.rows}).',
      );
    }
    if (!grid.isWalkable(point.x, point.y)) {
      throw ConfigException(
        'dungeons.json: $where (${point.x}, ${point.y}) berada pada tile terblokir (#).',
      );
    }
  }

  RoomType _parseRoomType(Object? raw, String where) {
    if (raw == null) return RoomType.normal;
    if (raw is! String) {
      throw ConfigException('dungeons.json: $where harus berupa teks.');
    }
    switch (raw) {
      case 'normal':
        return RoomType.normal;
      case 'elite':
        return RoomType.elite;
      case 'boss':
        return RoomType.boss;
      default:
        throw ConfigException(
          'dungeons.json: $where tidak dikenal "$raw" (valid: normal, elite, boss).',
        );
    }
  }

  SpawnActivationState _parseActivationState(Object? raw, String where) {
    if (raw == null) return SpawnActivationState.immediate;
    if (raw is! String) {
      throw ConfigException('dungeons.json: $where harus berupa teks.');
    }
    switch (raw) {
      case 'immediate':
        return SpawnActivationState.immediate;
      case 'on_group_cleared':
        return SpawnActivationState.onGroupCleared;
      case 'manual':
        return SpawnActivationState.manual;
      default:
        throw ConfigException('dungeons.json: $where tidak dikenal "$raw".');
    }
  }

  List<String> _parseStringList(Object? raw, String where) {
    if (raw == null) return const [];
    if (raw is! List) {
      throw ConfigException('dungeons.json: $where harus berupa array.');
    }
    final result = <String>[];
    for (var i = 0; i < raw.length; i++) {
      result.add(_nonEmptyString(raw[i], '$where[$i]'));
    }
    return result;
  }

  String _nonEmptyString(Object? value, String where) {
    if (value is String && value.isNotEmpty) return value;
    throw ConfigException(
      'dungeons.json: $where harus berupa teks tidak kosong.',
    );
  }

  bool _bool(
    Map<String, dynamic> map,
    String where,
    String key, {
    required bool fallback,
  }) {
    final value = map[key];
    if (value == null) return fallback;
    if (value is bool) return value;
    throw ConfigException('dungeons.json: $where."$key" harus berupa boolean.');
  }
}
