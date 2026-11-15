// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $GameSettingsTable extends GameSettings
    with TableInfo<$GameSettingsTable, GameSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GameSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'game_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<GameSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  GameSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GameSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $GameSettingsTable createAlias(String alias) {
    return $GameSettingsTable(attachedDatabase, alias);
  }
}

class GameSetting extends DataClass implements Insertable<GameSetting> {
  final String key;
  final String value;
  const GameSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  GameSettingsCompanion toCompanion(bool nullToAbsent) {
    return GameSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory GameSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GameSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  GameSetting copyWith({String? key, String? value}) =>
      GameSetting(key: key ?? this.key, value: value ?? this.value);
  GameSetting copyWithCompanion(GameSettingsCompanion data) {
    return GameSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GameSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class GameSettingsCompanion extends UpdateCompanion<GameSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const GameSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GameSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<GameSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GameSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return GameSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GameSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlayersTable extends Players with TableInfo<$PlayersTable, Player> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentExpMeta = const VerificationMeta(
    'currentExp',
  );
  @override
  late final GeneratedColumn<int> currentExp = GeneratedColumn<int>(
    'current_exp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _goldMeta = const VerificationMeta('gold');
  @override
  late final GeneratedColumn<int> gold = GeneratedColumn<int>(
    'gold',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentHpMeta = const VerificationMeta(
    'currentHp',
  );
  @override
  late final GeneratedColumn<int> currentHp = GeneratedColumn<int>(
    'current_hp',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeSpecializationIdMeta =
      const VerificationMeta('activeSpecializationId');
  @override
  late final GeneratedColumn<String> activeSpecializationId =
      GeneratedColumn<String>(
        'active_specialization_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _baseStatsJsonMeta = const VerificationMeta(
    'baseStatsJson',
  );
  @override
  late final GeneratedColumn<String> baseStatsJson = GeneratedColumn<String>(
    'base_stats_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _equipmentCounterMeta = const VerificationMeta(
    'equipmentCounter',
  );
  @override
  late final GeneratedColumn<int> equipmentCounter = GeneratedColumn<int>(
    'equipment_counter',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSavedAtMsMeta = const VerificationMeta(
    'lastSavedAtMs',
  );
  @override
  late final GeneratedColumn<int> lastSavedAtMs = GeneratedColumn<int>(
    'last_saved_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    level,
    currentExp,
    gold,
    currentHp,
    activeSpecializationId,
    baseStatsJson,
    equipmentCounter,
    lastSavedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'players';
  @override
  VerificationContext validateIntegrity(
    Insertable<Player> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('current_exp')) {
      context.handle(
        _currentExpMeta,
        currentExp.isAcceptableOrUnknown(data['current_exp']!, _currentExpMeta),
      );
    } else if (isInserting) {
      context.missing(_currentExpMeta);
    }
    if (data.containsKey('gold')) {
      context.handle(
        _goldMeta,
        gold.isAcceptableOrUnknown(data['gold']!, _goldMeta),
      );
    } else if (isInserting) {
      context.missing(_goldMeta);
    }
    if (data.containsKey('current_hp')) {
      context.handle(
        _currentHpMeta,
        currentHp.isAcceptableOrUnknown(data['current_hp']!, _currentHpMeta),
      );
    }
    if (data.containsKey('active_specialization_id')) {
      context.handle(
        _activeSpecializationIdMeta,
        activeSpecializationId.isAcceptableOrUnknown(
          data['active_specialization_id']!,
          _activeSpecializationIdMeta,
        ),
      );
    }
    if (data.containsKey('base_stats_json')) {
      context.handle(
        _baseStatsJsonMeta,
        baseStatsJson.isAcceptableOrUnknown(
          data['base_stats_json']!,
          _baseStatsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_baseStatsJsonMeta);
    }
    if (data.containsKey('equipment_counter')) {
      context.handle(
        _equipmentCounterMeta,
        equipmentCounter.isAcceptableOrUnknown(
          data['equipment_counter']!,
          _equipmentCounterMeta,
        ),
      );
    }
    if (data.containsKey('last_saved_at_ms')) {
      context.handle(
        _lastSavedAtMsMeta,
        lastSavedAtMs.isAcceptableOrUnknown(
          data['last_saved_at_ms']!,
          _lastSavedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSavedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Player map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Player(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level'],
      )!,
      currentExp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_exp'],
      )!,
      gold: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gold'],
      )!,
      currentHp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_hp'],
      ),
      activeSpecializationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}active_specialization_id'],
      ),
      baseStatsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_stats_json'],
      )!,
      equipmentCounter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}equipment_counter'],
      )!,
      lastSavedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_saved_at_ms'],
      )!,
    );
  }

  @override
  $PlayersTable createAlias(String alias) {
    return $PlayersTable(attachedDatabase, alias);
  }
}

class Player extends DataClass implements Insertable<Player> {
  final String id;
  final int level;
  final int currentExp;
  final int gold;
  final int? currentHp;
  final String? activeSpecializationId;
  final String baseStatsJson;
  final int equipmentCounter;
  final int lastSavedAtMs;
  const Player({
    required this.id,
    required this.level,
    required this.currentExp,
    required this.gold,
    this.currentHp,
    this.activeSpecializationId,
    required this.baseStatsJson,
    required this.equipmentCounter,
    required this.lastSavedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['level'] = Variable<int>(level);
    map['current_exp'] = Variable<int>(currentExp);
    map['gold'] = Variable<int>(gold);
    if (!nullToAbsent || currentHp != null) {
      map['current_hp'] = Variable<int>(currentHp);
    }
    if (!nullToAbsent || activeSpecializationId != null) {
      map['active_specialization_id'] = Variable<String>(
        activeSpecializationId,
      );
    }
    map['base_stats_json'] = Variable<String>(baseStatsJson);
    map['equipment_counter'] = Variable<int>(equipmentCounter);
    map['last_saved_at_ms'] = Variable<int>(lastSavedAtMs);
    return map;
  }

  PlayersCompanion toCompanion(bool nullToAbsent) {
    return PlayersCompanion(
      id: Value(id),
      level: Value(level),
      currentExp: Value(currentExp),
      gold: Value(gold),
      currentHp: currentHp == null && nullToAbsent
          ? const Value.absent()
          : Value(currentHp),
      activeSpecializationId: activeSpecializationId == null && nullToAbsent
          ? const Value.absent()
          : Value(activeSpecializationId),
      baseStatsJson: Value(baseStatsJson),
      equipmentCounter: Value(equipmentCounter),
      lastSavedAtMs: Value(lastSavedAtMs),
    );
  }

  factory Player.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Player(
      id: serializer.fromJson<String>(json['id']),
      level: serializer.fromJson<int>(json['level']),
      currentExp: serializer.fromJson<int>(json['currentExp']),
      gold: serializer.fromJson<int>(json['gold']),
      currentHp: serializer.fromJson<int?>(json['currentHp']),
      activeSpecializationId: serializer.fromJson<String?>(
        json['activeSpecializationId'],
      ),
      baseStatsJson: serializer.fromJson<String>(json['baseStatsJson']),
      equipmentCounter: serializer.fromJson<int>(json['equipmentCounter']),
      lastSavedAtMs: serializer.fromJson<int>(json['lastSavedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'level': serializer.toJson<int>(level),
      'currentExp': serializer.toJson<int>(currentExp),
      'gold': serializer.toJson<int>(gold),
      'currentHp': serializer.toJson<int?>(currentHp),
      'activeSpecializationId': serializer.toJson<String?>(
        activeSpecializationId,
      ),
      'baseStatsJson': serializer.toJson<String>(baseStatsJson),
      'equipmentCounter': serializer.toJson<int>(equipmentCounter),
      'lastSavedAtMs': serializer.toJson<int>(lastSavedAtMs),
    };
  }

  Player copyWith({
    String? id,
    int? level,
    int? currentExp,
    int? gold,
    Value<int?> currentHp = const Value.absent(),
    Value<String?> activeSpecializationId = const Value.absent(),
    String? baseStatsJson,
    int? equipmentCounter,
    int? lastSavedAtMs,
  }) => Player(
    id: id ?? this.id,
    level: level ?? this.level,
    currentExp: currentExp ?? this.currentExp,
    gold: gold ?? this.gold,
    currentHp: currentHp.present ? currentHp.value : this.currentHp,
    activeSpecializationId: activeSpecializationId.present
        ? activeSpecializationId.value
        : this.activeSpecializationId,
    baseStatsJson: baseStatsJson ?? this.baseStatsJson,
    equipmentCounter: equipmentCounter ?? this.equipmentCounter,
    lastSavedAtMs: lastSavedAtMs ?? this.lastSavedAtMs,
  );
  Player copyWithCompanion(PlayersCompanion data) {
    return Player(
      id: data.id.present ? data.id.value : this.id,
      level: data.level.present ? data.level.value : this.level,
      currentExp: data.currentExp.present
          ? data.currentExp.value
          : this.currentExp,
      gold: data.gold.present ? data.gold.value : this.gold,
      currentHp: data.currentHp.present ? data.currentHp.value : this.currentHp,
      activeSpecializationId: data.activeSpecializationId.present
          ? data.activeSpecializationId.value
          : this.activeSpecializationId,
      baseStatsJson: data.baseStatsJson.present
          ? data.baseStatsJson.value
          : this.baseStatsJson,
      equipmentCounter: data.equipmentCounter.present
          ? data.equipmentCounter.value
          : this.equipmentCounter,
      lastSavedAtMs: data.lastSavedAtMs.present
          ? data.lastSavedAtMs.value
          : this.lastSavedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Player(')
          ..write('id: $id, ')
          ..write('level: $level, ')
          ..write('currentExp: $currentExp, ')
          ..write('gold: $gold, ')
          ..write('currentHp: $currentHp, ')
          ..write('activeSpecializationId: $activeSpecializationId, ')
          ..write('baseStatsJson: $baseStatsJson, ')
          ..write('equipmentCounter: $equipmentCounter, ')
          ..write('lastSavedAtMs: $lastSavedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    level,
    currentExp,
    gold,
    currentHp,
    activeSpecializationId,
    baseStatsJson,
    equipmentCounter,
    lastSavedAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Player &&
          other.id == this.id &&
          other.level == this.level &&
          other.currentExp == this.currentExp &&
          other.gold == this.gold &&
          other.currentHp == this.currentHp &&
          other.activeSpecializationId == this.activeSpecializationId &&
          other.baseStatsJson == this.baseStatsJson &&
          other.equipmentCounter == this.equipmentCounter &&
          other.lastSavedAtMs == this.lastSavedAtMs);
}

class PlayersCompanion extends UpdateCompanion<Player> {
  final Value<String> id;
  final Value<int> level;
  final Value<int> currentExp;
  final Value<int> gold;
  final Value<int?> currentHp;
  final Value<String?> activeSpecializationId;
  final Value<String> baseStatsJson;
  final Value<int> equipmentCounter;
  final Value<int> lastSavedAtMs;
  final Value<int> rowid;
  const PlayersCompanion({
    this.id = const Value.absent(),
    this.level = const Value.absent(),
    this.currentExp = const Value.absent(),
    this.gold = const Value.absent(),
    this.currentHp = const Value.absent(),
    this.activeSpecializationId = const Value.absent(),
    this.baseStatsJson = const Value.absent(),
    this.equipmentCounter = const Value.absent(),
    this.lastSavedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlayersCompanion.insert({
    required String id,
    required int level,
    required int currentExp,
    required int gold,
    this.currentHp = const Value.absent(),
    this.activeSpecializationId = const Value.absent(),
    required String baseStatsJson,
    this.equipmentCounter = const Value.absent(),
    required int lastSavedAtMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       level = Value(level),
       currentExp = Value(currentExp),
       gold = Value(gold),
       baseStatsJson = Value(baseStatsJson),
       lastSavedAtMs = Value(lastSavedAtMs);
  static Insertable<Player> custom({
    Expression<String>? id,
    Expression<int>? level,
    Expression<int>? currentExp,
    Expression<int>? gold,
    Expression<int>? currentHp,
    Expression<String>? activeSpecializationId,
    Expression<String>? baseStatsJson,
    Expression<int>? equipmentCounter,
    Expression<int>? lastSavedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (level != null) 'level': level,
      if (currentExp != null) 'current_exp': currentExp,
      if (gold != null) 'gold': gold,
      if (currentHp != null) 'current_hp': currentHp,
      if (activeSpecializationId != null)
        'active_specialization_id': activeSpecializationId,
      if (baseStatsJson != null) 'base_stats_json': baseStatsJson,
      if (equipmentCounter != null) 'equipment_counter': equipmentCounter,
      if (lastSavedAtMs != null) 'last_saved_at_ms': lastSavedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlayersCompanion copyWith({
    Value<String>? id,
    Value<int>? level,
    Value<int>? currentExp,
    Value<int>? gold,
    Value<int?>? currentHp,
    Value<String?>? activeSpecializationId,
    Value<String>? baseStatsJson,
    Value<int>? equipmentCounter,
    Value<int>? lastSavedAtMs,
    Value<int>? rowid,
  }) {
    return PlayersCompanion(
      id: id ?? this.id,
      level: level ?? this.level,
      currentExp: currentExp ?? this.currentExp,
      gold: gold ?? this.gold,
      currentHp: currentHp ?? this.currentHp,
      activeSpecializationId:
          activeSpecializationId ?? this.activeSpecializationId,
      baseStatsJson: baseStatsJson ?? this.baseStatsJson,
      equipmentCounter: equipmentCounter ?? this.equipmentCounter,
      lastSavedAtMs: lastSavedAtMs ?? this.lastSavedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (currentExp.present) {
      map['current_exp'] = Variable<int>(currentExp.value);
    }
    if (gold.present) {
      map['gold'] = Variable<int>(gold.value);
    }
    if (currentHp.present) {
      map['current_hp'] = Variable<int>(currentHp.value);
    }
    if (activeSpecializationId.present) {
      map['active_specialization_id'] = Variable<String>(
        activeSpecializationId.value,
      );
    }
    if (baseStatsJson.present) {
      map['base_stats_json'] = Variable<String>(baseStatsJson.value);
    }
    if (equipmentCounter.present) {
      map['equipment_counter'] = Variable<int>(equipmentCounter.value);
    }
    if (lastSavedAtMs.present) {
      map['last_saved_at_ms'] = Variable<int>(lastSavedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayersCompanion(')
          ..write('id: $id, ')
          ..write('level: $level, ')
          ..write('currentExp: $currentExp, ')
          ..write('gold: $gold, ')
          ..write('currentHp: $currentHp, ')
          ..write('activeSpecializationId: $activeSpecializationId, ')
          ..write('baseStatsJson: $baseStatsJson, ')
          ..write('equipmentCounter: $equipmentCounter, ')
          ..write('lastSavedAtMs: $lastSavedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SkillProgressesTable extends SkillProgresses
    with TableInfo<$SkillProgressesTable, SkillProgressesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SkillProgressesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playerIdMeta = const VerificationMeta(
    'playerId',
  );
  @override
  late final GeneratedColumn<String> playerId = GeneratedColumn<String>(
    'player_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES players (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _skillIdMeta = const VerificationMeta(
    'skillId',
  );
  @override
  late final GeneratedColumn<String> skillId = GeneratedColumn<String>(
    'skill_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _skillLevelMeta = const VerificationMeta(
    'skillLevel',
  );
  @override
  late final GeneratedColumn<int> skillLevel = GeneratedColumn<int>(
    'skill_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unlockedMeta = const VerificationMeta(
    'unlocked',
  );
  @override
  late final GeneratedColumn<bool> unlocked = GeneratedColumn<bool>(
    'unlocked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("unlocked" IN (0, 1))',
    ),
  );
  static const VerificationMeta _cooldownTicksRemainingMeta =
      const VerificationMeta('cooldownTicksRemaining');
  @override
  late final GeneratedColumn<int> cooldownTicksRemaining = GeneratedColumn<int>(
    'cooldown_ticks_remaining',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    playerId,
    skillId,
    skillLevel,
    unlocked,
    cooldownTicksRemaining,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'skill_progresses';
  @override
  VerificationContext validateIntegrity(
    Insertable<SkillProgressesData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('player_id')) {
      context.handle(
        _playerIdMeta,
        playerId.isAcceptableOrUnknown(data['player_id']!, _playerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playerIdMeta);
    }
    if (data.containsKey('skill_id')) {
      context.handle(
        _skillIdMeta,
        skillId.isAcceptableOrUnknown(data['skill_id']!, _skillIdMeta),
      );
    } else if (isInserting) {
      context.missing(_skillIdMeta);
    }
    if (data.containsKey('skill_level')) {
      context.handle(
        _skillLevelMeta,
        skillLevel.isAcceptableOrUnknown(data['skill_level']!, _skillLevelMeta),
      );
    } else if (isInserting) {
      context.missing(_skillLevelMeta);
    }
    if (data.containsKey('unlocked')) {
      context.handle(
        _unlockedMeta,
        unlocked.isAcceptableOrUnknown(data['unlocked']!, _unlockedMeta),
      );
    } else if (isInserting) {
      context.missing(_unlockedMeta);
    }
    if (data.containsKey('cooldown_ticks_remaining')) {
      context.handle(
        _cooldownTicksRemainingMeta,
        cooldownTicksRemaining.isAcceptableOrUnknown(
          data['cooldown_ticks_remaining']!,
          _cooldownTicksRemainingMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playerId, skillId};
  @override
  SkillProgressesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SkillProgressesData(
      playerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_id'],
      )!,
      skillId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skill_id'],
      )!,
      skillLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}skill_level'],
      )!,
      unlocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}unlocked'],
      )!,
      cooldownTicksRemaining: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cooldown_ticks_remaining'],
      )!,
    );
  }

  @override
  $SkillProgressesTable createAlias(String alias) {
    return $SkillProgressesTable(attachedDatabase, alias);
  }
}

class SkillProgressesData extends DataClass
    implements Insertable<SkillProgressesData> {
  final String playerId;
  final String skillId;
  final int skillLevel;
  final bool unlocked;
  final int cooldownTicksRemaining;
  const SkillProgressesData({
    required this.playerId,
    required this.skillId,
    required this.skillLevel,
    required this.unlocked,
    required this.cooldownTicksRemaining,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['player_id'] = Variable<String>(playerId);
    map['skill_id'] = Variable<String>(skillId);
    map['skill_level'] = Variable<int>(skillLevel);
    map['unlocked'] = Variable<bool>(unlocked);
    map['cooldown_ticks_remaining'] = Variable<int>(cooldownTicksRemaining);
    return map;
  }

  SkillProgressesCompanion toCompanion(bool nullToAbsent) {
    return SkillProgressesCompanion(
      playerId: Value(playerId),
      skillId: Value(skillId),
      skillLevel: Value(skillLevel),
      unlocked: Value(unlocked),
      cooldownTicksRemaining: Value(cooldownTicksRemaining),
    );
  }

  factory SkillProgressesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SkillProgressesData(
      playerId: serializer.fromJson<String>(json['playerId']),
      skillId: serializer.fromJson<String>(json['skillId']),
      skillLevel: serializer.fromJson<int>(json['skillLevel']),
      unlocked: serializer.fromJson<bool>(json['unlocked']),
      cooldownTicksRemaining: serializer.fromJson<int>(
        json['cooldownTicksRemaining'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playerId': serializer.toJson<String>(playerId),
      'skillId': serializer.toJson<String>(skillId),
      'skillLevel': serializer.toJson<int>(skillLevel),
      'unlocked': serializer.toJson<bool>(unlocked),
      'cooldownTicksRemaining': serializer.toJson<int>(cooldownTicksRemaining),
    };
  }

  SkillProgressesData copyWith({
    String? playerId,
    String? skillId,
    int? skillLevel,
    bool? unlocked,
    int? cooldownTicksRemaining,
  }) => SkillProgressesData(
    playerId: playerId ?? this.playerId,
    skillId: skillId ?? this.skillId,
    skillLevel: skillLevel ?? this.skillLevel,
    unlocked: unlocked ?? this.unlocked,
    cooldownTicksRemaining:
        cooldownTicksRemaining ?? this.cooldownTicksRemaining,
  );
  SkillProgressesData copyWithCompanion(SkillProgressesCompanion data) {
    return SkillProgressesData(
      playerId: data.playerId.present ? data.playerId.value : this.playerId,
      skillId: data.skillId.present ? data.skillId.value : this.skillId,
      skillLevel: data.skillLevel.present
          ? data.skillLevel.value
          : this.skillLevel,
      unlocked: data.unlocked.present ? data.unlocked.value : this.unlocked,
      cooldownTicksRemaining: data.cooldownTicksRemaining.present
          ? data.cooldownTicksRemaining.value
          : this.cooldownTicksRemaining,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SkillProgressesData(')
          ..write('playerId: $playerId, ')
          ..write('skillId: $skillId, ')
          ..write('skillLevel: $skillLevel, ')
          ..write('unlocked: $unlocked, ')
          ..write('cooldownTicksRemaining: $cooldownTicksRemaining')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    playerId,
    skillId,
    skillLevel,
    unlocked,
    cooldownTicksRemaining,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SkillProgressesData &&
          other.playerId == this.playerId &&
          other.skillId == this.skillId &&
          other.skillLevel == this.skillLevel &&
          other.unlocked == this.unlocked &&
          other.cooldownTicksRemaining == this.cooldownTicksRemaining);
}

class SkillProgressesCompanion extends UpdateCompanion<SkillProgressesData> {
  final Value<String> playerId;
  final Value<String> skillId;
  final Value<int> skillLevel;
  final Value<bool> unlocked;
  final Value<int> cooldownTicksRemaining;
  final Value<int> rowid;
  const SkillProgressesCompanion({
    this.playerId = const Value.absent(),
    this.skillId = const Value.absent(),
    this.skillLevel = const Value.absent(),
    this.unlocked = const Value.absent(),
    this.cooldownTicksRemaining = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SkillProgressesCompanion.insert({
    required String playerId,
    required String skillId,
    required int skillLevel,
    required bool unlocked,
    this.cooldownTicksRemaining = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : playerId = Value(playerId),
       skillId = Value(skillId),
       skillLevel = Value(skillLevel),
       unlocked = Value(unlocked);
  static Insertable<SkillProgressesData> custom({
    Expression<String>? playerId,
    Expression<String>? skillId,
    Expression<int>? skillLevel,
    Expression<bool>? unlocked,
    Expression<int>? cooldownTicksRemaining,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playerId != null) 'player_id': playerId,
      if (skillId != null) 'skill_id': skillId,
      if (skillLevel != null) 'skill_level': skillLevel,
      if (unlocked != null) 'unlocked': unlocked,
      if (cooldownTicksRemaining != null)
        'cooldown_ticks_remaining': cooldownTicksRemaining,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SkillProgressesCompanion copyWith({
    Value<String>? playerId,
    Value<String>? skillId,
    Value<int>? skillLevel,
    Value<bool>? unlocked,
    Value<int>? cooldownTicksRemaining,
    Value<int>? rowid,
  }) {
    return SkillProgressesCompanion(
      playerId: playerId ?? this.playerId,
      skillId: skillId ?? this.skillId,
      skillLevel: skillLevel ?? this.skillLevel,
      unlocked: unlocked ?? this.unlocked,
      cooldownTicksRemaining:
          cooldownTicksRemaining ?? this.cooldownTicksRemaining,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playerId.present) {
      map['player_id'] = Variable<String>(playerId.value);
    }
    if (skillId.present) {
      map['skill_id'] = Variable<String>(skillId.value);
    }
    if (skillLevel.present) {
      map['skill_level'] = Variable<int>(skillLevel.value);
    }
    if (unlocked.present) {
      map['unlocked'] = Variable<bool>(unlocked.value);
    }
    if (cooldownTicksRemaining.present) {
      map['cooldown_ticks_remaining'] = Variable<int>(
        cooldownTicksRemaining.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SkillProgressesCompanion(')
          ..write('playerId: $playerId, ')
          ..write('skillId: $skillId, ')
          ..write('skillLevel: $skillLevel, ')
          ..write('unlocked: $unlocked, ')
          ..write('cooldownTicksRemaining: $cooldownTicksRemaining, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InventoryEntriesTable extends InventoryEntries
    with TableInfo<$InventoryEntriesTable, InventoryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InventoryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playerIdMeta = const VerificationMeta(
    'playerId',
  );
  @override
  late final GeneratedColumn<String> playerId = GeneratedColumn<String>(
    'player_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES players (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [playerId, itemId, quantity];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inventory_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<InventoryEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('player_id')) {
      context.handle(
        _playerIdMeta,
        playerId.isAcceptableOrUnknown(data['player_id']!, _playerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playerIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playerId, itemId};
  @override
  InventoryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InventoryEntry(
      playerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
    );
  }

  @override
  $InventoryEntriesTable createAlias(String alias) {
    return $InventoryEntriesTable(attachedDatabase, alias);
  }
}

class InventoryEntry extends DataClass implements Insertable<InventoryEntry> {
  final String playerId;
  final String itemId;
  final int quantity;
  const InventoryEntry({
    required this.playerId,
    required this.itemId,
    required this.quantity,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['player_id'] = Variable<String>(playerId);
    map['item_id'] = Variable<String>(itemId);
    map['quantity'] = Variable<int>(quantity);
    return map;
  }

  InventoryEntriesCompanion toCompanion(bool nullToAbsent) {
    return InventoryEntriesCompanion(
      playerId: Value(playerId),
      itemId: Value(itemId),
      quantity: Value(quantity),
    );
  }

  factory InventoryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InventoryEntry(
      playerId: serializer.fromJson<String>(json['playerId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      quantity: serializer.fromJson<int>(json['quantity']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playerId': serializer.toJson<String>(playerId),
      'itemId': serializer.toJson<String>(itemId),
      'quantity': serializer.toJson<int>(quantity),
    };
  }

  InventoryEntry copyWith({String? playerId, String? itemId, int? quantity}) =>
      InventoryEntry(
        playerId: playerId ?? this.playerId,
        itemId: itemId ?? this.itemId,
        quantity: quantity ?? this.quantity,
      );
  InventoryEntry copyWithCompanion(InventoryEntriesCompanion data) {
    return InventoryEntry(
      playerId: data.playerId.present ? data.playerId.value : this.playerId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InventoryEntry(')
          ..write('playerId: $playerId, ')
          ..write('itemId: $itemId, ')
          ..write('quantity: $quantity')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playerId, itemId, quantity);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InventoryEntry &&
          other.playerId == this.playerId &&
          other.itemId == this.itemId &&
          other.quantity == this.quantity);
}

class InventoryEntriesCompanion extends UpdateCompanion<InventoryEntry> {
  final Value<String> playerId;
  final Value<String> itemId;
  final Value<int> quantity;
  final Value<int> rowid;
  const InventoryEntriesCompanion({
    this.playerId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InventoryEntriesCompanion.insert({
    required String playerId,
    required String itemId,
    required int quantity,
    this.rowid = const Value.absent(),
  }) : playerId = Value(playerId),
       itemId = Value(itemId),
       quantity = Value(quantity);
  static Insertable<InventoryEntry> custom({
    Expression<String>? playerId,
    Expression<String>? itemId,
    Expression<int>? quantity,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playerId != null) 'player_id': playerId,
      if (itemId != null) 'item_id': itemId,
      if (quantity != null) 'quantity': quantity,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InventoryEntriesCompanion copyWith({
    Value<String>? playerId,
    Value<String>? itemId,
    Value<int>? quantity,
    Value<int>? rowid,
  }) {
    return InventoryEntriesCompanion(
      playerId: playerId ?? this.playerId,
      itemId: itemId ?? this.itemId,
      quantity: quantity ?? this.quantity,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playerId.present) {
      map['player_id'] = Variable<String>(playerId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InventoryEntriesCompanion(')
          ..write('playerId: $playerId, ')
          ..write('itemId: $itemId, ')
          ..write('quantity: $quantity, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EquipmentInstancesTable extends EquipmentInstances
    with TableInfo<$EquipmentInstancesTable, EquipmentInstanceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EquipmentInstancesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playerIdMeta = const VerificationMeta(
    'playerId',
  );
  @override
  late final GeneratedColumn<String> playerId = GeneratedColumn<String>(
    'player_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES players (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _instanceIdMeta = const VerificationMeta(
    'instanceId',
  );
  @override
  late final GeneratedColumn<String> instanceId = GeneratedColumn<String>(
    'instance_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _definitionIdMeta = const VerificationMeta(
    'definitionId',
  );
  @override
  late final GeneratedColumn<String> definitionId = GeneratedColumn<String>(
    'definition_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<String> slot = GeneratedColumn<String>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rarityMeta = const VerificationMeta('rarity');
  @override
  late final GeneratedColumn<String> rarity = GeneratedColumn<String>(
    'rarity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rolledStatsJsonMeta = const VerificationMeta(
    'rolledStatsJson',
  );
  @override
  late final GeneratedColumn<String> rolledStatsJson = GeneratedColumn<String>(
    'rolled_stats_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enhancementLevelMeta = const VerificationMeta(
    'enhancementLevel',
  );
  @override
  late final GeneratedColumn<int> enhancementLevel = GeneratedColumn<int>(
    'enhancement_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    playerId,
    instanceId,
    definitionId,
    slot,
    rarity,
    rolledStatsJson,
    enhancementLevel,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'equipment_instances';
  @override
  VerificationContext validateIntegrity(
    Insertable<EquipmentInstanceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('player_id')) {
      context.handle(
        _playerIdMeta,
        playerId.isAcceptableOrUnknown(data['player_id']!, _playerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playerIdMeta);
    }
    if (data.containsKey('instance_id')) {
      context.handle(
        _instanceIdMeta,
        instanceId.isAcceptableOrUnknown(data['instance_id']!, _instanceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_instanceIdMeta);
    }
    if (data.containsKey('definition_id')) {
      context.handle(
        _definitionIdMeta,
        definitionId.isAcceptableOrUnknown(
          data['definition_id']!,
          _definitionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_definitionIdMeta);
    }
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    } else if (isInserting) {
      context.missing(_slotMeta);
    }
    if (data.containsKey('rarity')) {
      context.handle(
        _rarityMeta,
        rarity.isAcceptableOrUnknown(data['rarity']!, _rarityMeta),
      );
    } else if (isInserting) {
      context.missing(_rarityMeta);
    }
    if (data.containsKey('rolled_stats_json')) {
      context.handle(
        _rolledStatsJsonMeta,
        rolledStatsJson.isAcceptableOrUnknown(
          data['rolled_stats_json']!,
          _rolledStatsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rolledStatsJsonMeta);
    }
    if (data.containsKey('enhancement_level')) {
      context.handle(
        _enhancementLevelMeta,
        enhancementLevel.isAcceptableOrUnknown(
          data['enhancement_level']!,
          _enhancementLevelMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playerId, instanceId};
  @override
  EquipmentInstanceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EquipmentInstanceRow(
      playerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_id'],
      )!,
      instanceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instance_id'],
      )!,
      definitionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}definition_id'],
      )!,
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot'],
      )!,
      rarity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rarity'],
      )!,
      rolledStatsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rolled_stats_json'],
      )!,
      enhancementLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}enhancement_level'],
      )!,
    );
  }

  @override
  $EquipmentInstancesTable createAlias(String alias) {
    return $EquipmentInstancesTable(attachedDatabase, alias);
  }
}

class EquipmentInstanceRow extends DataClass
    implements Insertable<EquipmentInstanceRow> {
  final String playerId;
  final String instanceId;
  final String definitionId;
  final String slot;
  final String rarity;
  final String rolledStatsJson;
  final int enhancementLevel;
  const EquipmentInstanceRow({
    required this.playerId,
    required this.instanceId,
    required this.definitionId,
    required this.slot,
    required this.rarity,
    required this.rolledStatsJson,
    required this.enhancementLevel,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['player_id'] = Variable<String>(playerId);
    map['instance_id'] = Variable<String>(instanceId);
    map['definition_id'] = Variable<String>(definitionId);
    map['slot'] = Variable<String>(slot);
    map['rarity'] = Variable<String>(rarity);
    map['rolled_stats_json'] = Variable<String>(rolledStatsJson);
    map['enhancement_level'] = Variable<int>(enhancementLevel);
    return map;
  }

  EquipmentInstancesCompanion toCompanion(bool nullToAbsent) {
    return EquipmentInstancesCompanion(
      playerId: Value(playerId),
      instanceId: Value(instanceId),
      definitionId: Value(definitionId),
      slot: Value(slot),
      rarity: Value(rarity),
      rolledStatsJson: Value(rolledStatsJson),
      enhancementLevel: Value(enhancementLevel),
    );
  }

  factory EquipmentInstanceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EquipmentInstanceRow(
      playerId: serializer.fromJson<String>(json['playerId']),
      instanceId: serializer.fromJson<String>(json['instanceId']),
      definitionId: serializer.fromJson<String>(json['definitionId']),
      slot: serializer.fromJson<String>(json['slot']),
      rarity: serializer.fromJson<String>(json['rarity']),
      rolledStatsJson: serializer.fromJson<String>(json['rolledStatsJson']),
      enhancementLevel: serializer.fromJson<int>(json['enhancementLevel']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playerId': serializer.toJson<String>(playerId),
      'instanceId': serializer.toJson<String>(instanceId),
      'definitionId': serializer.toJson<String>(definitionId),
      'slot': serializer.toJson<String>(slot),
      'rarity': serializer.toJson<String>(rarity),
      'rolledStatsJson': serializer.toJson<String>(rolledStatsJson),
      'enhancementLevel': serializer.toJson<int>(enhancementLevel),
    };
  }

  EquipmentInstanceRow copyWith({
    String? playerId,
    String? instanceId,
    String? definitionId,
    String? slot,
    String? rarity,
    String? rolledStatsJson,
    int? enhancementLevel,
  }) => EquipmentInstanceRow(
    playerId: playerId ?? this.playerId,
    instanceId: instanceId ?? this.instanceId,
    definitionId: definitionId ?? this.definitionId,
    slot: slot ?? this.slot,
    rarity: rarity ?? this.rarity,
    rolledStatsJson: rolledStatsJson ?? this.rolledStatsJson,
    enhancementLevel: enhancementLevel ?? this.enhancementLevel,
  );
  EquipmentInstanceRow copyWithCompanion(EquipmentInstancesCompanion data) {
    return EquipmentInstanceRow(
      playerId: data.playerId.present ? data.playerId.value : this.playerId,
      instanceId: data.instanceId.present
          ? data.instanceId.value
          : this.instanceId,
      definitionId: data.definitionId.present
          ? data.definitionId.value
          : this.definitionId,
      slot: data.slot.present ? data.slot.value : this.slot,
      rarity: data.rarity.present ? data.rarity.value : this.rarity,
      rolledStatsJson: data.rolledStatsJson.present
          ? data.rolledStatsJson.value
          : this.rolledStatsJson,
      enhancementLevel: data.enhancementLevel.present
          ? data.enhancementLevel.value
          : this.enhancementLevel,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EquipmentInstanceRow(')
          ..write('playerId: $playerId, ')
          ..write('instanceId: $instanceId, ')
          ..write('definitionId: $definitionId, ')
          ..write('slot: $slot, ')
          ..write('rarity: $rarity, ')
          ..write('rolledStatsJson: $rolledStatsJson, ')
          ..write('enhancementLevel: $enhancementLevel')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    playerId,
    instanceId,
    definitionId,
    slot,
    rarity,
    rolledStatsJson,
    enhancementLevel,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EquipmentInstanceRow &&
          other.playerId == this.playerId &&
          other.instanceId == this.instanceId &&
          other.definitionId == this.definitionId &&
          other.slot == this.slot &&
          other.rarity == this.rarity &&
          other.rolledStatsJson == this.rolledStatsJson &&
          other.enhancementLevel == this.enhancementLevel);
}

class EquipmentInstancesCompanion
    extends UpdateCompanion<EquipmentInstanceRow> {
  final Value<String> playerId;
  final Value<String> instanceId;
  final Value<String> definitionId;
  final Value<String> slot;
  final Value<String> rarity;
  final Value<String> rolledStatsJson;
  final Value<int> enhancementLevel;
  final Value<int> rowid;
  const EquipmentInstancesCompanion({
    this.playerId = const Value.absent(),
    this.instanceId = const Value.absent(),
    this.definitionId = const Value.absent(),
    this.slot = const Value.absent(),
    this.rarity = const Value.absent(),
    this.rolledStatsJson = const Value.absent(),
    this.enhancementLevel = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EquipmentInstancesCompanion.insert({
    required String playerId,
    required String instanceId,
    required String definitionId,
    required String slot,
    required String rarity,
    required String rolledStatsJson,
    this.enhancementLevel = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : playerId = Value(playerId),
       instanceId = Value(instanceId),
       definitionId = Value(definitionId),
       slot = Value(slot),
       rarity = Value(rarity),
       rolledStatsJson = Value(rolledStatsJson);
  static Insertable<EquipmentInstanceRow> custom({
    Expression<String>? playerId,
    Expression<String>? instanceId,
    Expression<String>? definitionId,
    Expression<String>? slot,
    Expression<String>? rarity,
    Expression<String>? rolledStatsJson,
    Expression<int>? enhancementLevel,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playerId != null) 'player_id': playerId,
      if (instanceId != null) 'instance_id': instanceId,
      if (definitionId != null) 'definition_id': definitionId,
      if (slot != null) 'slot': slot,
      if (rarity != null) 'rarity': rarity,
      if (rolledStatsJson != null) 'rolled_stats_json': rolledStatsJson,
      if (enhancementLevel != null) 'enhancement_level': enhancementLevel,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EquipmentInstancesCompanion copyWith({
    Value<String>? playerId,
    Value<String>? instanceId,
    Value<String>? definitionId,
    Value<String>? slot,
    Value<String>? rarity,
    Value<String>? rolledStatsJson,
    Value<int>? enhancementLevel,
    Value<int>? rowid,
  }) {
    return EquipmentInstancesCompanion(
      playerId: playerId ?? this.playerId,
      instanceId: instanceId ?? this.instanceId,
      definitionId: definitionId ?? this.definitionId,
      slot: slot ?? this.slot,
      rarity: rarity ?? this.rarity,
      rolledStatsJson: rolledStatsJson ?? this.rolledStatsJson,
      enhancementLevel: enhancementLevel ?? this.enhancementLevel,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playerId.present) {
      map['player_id'] = Variable<String>(playerId.value);
    }
    if (instanceId.present) {
      map['instance_id'] = Variable<String>(instanceId.value);
    }
    if (definitionId.present) {
      map['definition_id'] = Variable<String>(definitionId.value);
    }
    if (slot.present) {
      map['slot'] = Variable<String>(slot.value);
    }
    if (rarity.present) {
      map['rarity'] = Variable<String>(rarity.value);
    }
    if (rolledStatsJson.present) {
      map['rolled_stats_json'] = Variable<String>(rolledStatsJson.value);
    }
    if (enhancementLevel.present) {
      map['enhancement_level'] = Variable<int>(enhancementLevel.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EquipmentInstancesCompanion(')
          ..write('playerId: $playerId, ')
          ..write('instanceId: $instanceId, ')
          ..write('definitionId: $definitionId, ')
          ..write('slot: $slot, ')
          ..write('rarity: $rarity, ')
          ..write('rolledStatsJson: $rolledStatsJson, ')
          ..write('enhancementLevel: $enhancementLevel, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EquippedItemsTable extends EquippedItems
    with TableInfo<$EquippedItemsTable, EquippedItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EquippedItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playerIdMeta = const VerificationMeta(
    'playerId',
  );
  @override
  late final GeneratedColumn<String> playerId = GeneratedColumn<String>(
    'player_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES players (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<String> slot = GeneratedColumn<String>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _equipmentInstanceIdMeta =
      const VerificationMeta('equipmentInstanceId');
  @override
  late final GeneratedColumn<String> equipmentInstanceId =
      GeneratedColumn<String>(
        'equipment_instance_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [playerId, slot, equipmentInstanceId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'equipped_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<EquippedItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('player_id')) {
      context.handle(
        _playerIdMeta,
        playerId.isAcceptableOrUnknown(data['player_id']!, _playerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playerIdMeta);
    }
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    } else if (isInserting) {
      context.missing(_slotMeta);
    }
    if (data.containsKey('equipment_instance_id')) {
      context.handle(
        _equipmentInstanceIdMeta,
        equipmentInstanceId.isAcceptableOrUnknown(
          data['equipment_instance_id']!,
          _equipmentInstanceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_equipmentInstanceIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playerId, slot};
  @override
  EquippedItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EquippedItem(
      playerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_id'],
      )!,
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot'],
      )!,
      equipmentInstanceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}equipment_instance_id'],
      )!,
    );
  }

  @override
  $EquippedItemsTable createAlias(String alias) {
    return $EquippedItemsTable(attachedDatabase, alias);
  }
}

class EquippedItem extends DataClass implements Insertable<EquippedItem> {
  final String playerId;
  final String slot;
  final String equipmentInstanceId;
  const EquippedItem({
    required this.playerId,
    required this.slot,
    required this.equipmentInstanceId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['player_id'] = Variable<String>(playerId);
    map['slot'] = Variable<String>(slot);
    map['equipment_instance_id'] = Variable<String>(equipmentInstanceId);
    return map;
  }

  EquippedItemsCompanion toCompanion(bool nullToAbsent) {
    return EquippedItemsCompanion(
      playerId: Value(playerId),
      slot: Value(slot),
      equipmentInstanceId: Value(equipmentInstanceId),
    );
  }

  factory EquippedItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EquippedItem(
      playerId: serializer.fromJson<String>(json['playerId']),
      slot: serializer.fromJson<String>(json['slot']),
      equipmentInstanceId: serializer.fromJson<String>(
        json['equipmentInstanceId'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playerId': serializer.toJson<String>(playerId),
      'slot': serializer.toJson<String>(slot),
      'equipmentInstanceId': serializer.toJson<String>(equipmentInstanceId),
    };
  }

  EquippedItem copyWith({
    String? playerId,
    String? slot,
    String? equipmentInstanceId,
  }) => EquippedItem(
    playerId: playerId ?? this.playerId,
    slot: slot ?? this.slot,
    equipmentInstanceId: equipmentInstanceId ?? this.equipmentInstanceId,
  );
  EquippedItem copyWithCompanion(EquippedItemsCompanion data) {
    return EquippedItem(
      playerId: data.playerId.present ? data.playerId.value : this.playerId,
      slot: data.slot.present ? data.slot.value : this.slot,
      equipmentInstanceId: data.equipmentInstanceId.present
          ? data.equipmentInstanceId.value
          : this.equipmentInstanceId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EquippedItem(')
          ..write('playerId: $playerId, ')
          ..write('slot: $slot, ')
          ..write('equipmentInstanceId: $equipmentInstanceId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playerId, slot, equipmentInstanceId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EquippedItem &&
          other.playerId == this.playerId &&
          other.slot == this.slot &&
          other.equipmentInstanceId == this.equipmentInstanceId);
}

class EquippedItemsCompanion extends UpdateCompanion<EquippedItem> {
  final Value<String> playerId;
  final Value<String> slot;
  final Value<String> equipmentInstanceId;
  final Value<int> rowid;
  const EquippedItemsCompanion({
    this.playerId = const Value.absent(),
    this.slot = const Value.absent(),
    this.equipmentInstanceId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EquippedItemsCompanion.insert({
    required String playerId,
    required String slot,
    required String equipmentInstanceId,
    this.rowid = const Value.absent(),
  }) : playerId = Value(playerId),
       slot = Value(slot),
       equipmentInstanceId = Value(equipmentInstanceId);
  static Insertable<EquippedItem> custom({
    Expression<String>? playerId,
    Expression<String>? slot,
    Expression<String>? equipmentInstanceId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playerId != null) 'player_id': playerId,
      if (slot != null) 'slot': slot,
      if (equipmentInstanceId != null)
        'equipment_instance_id': equipmentInstanceId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EquippedItemsCompanion copyWith({
    Value<String>? playerId,
    Value<String>? slot,
    Value<String>? equipmentInstanceId,
    Value<int>? rowid,
  }) {
    return EquippedItemsCompanion(
      playerId: playerId ?? this.playerId,
      slot: slot ?? this.slot,
      equipmentInstanceId: equipmentInstanceId ?? this.equipmentInstanceId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playerId.present) {
      map['player_id'] = Variable<String>(playerId.value);
    }
    if (slot.present) {
      map['slot'] = Variable<String>(slot.value);
    }
    if (equipmentInstanceId.present) {
      map['equipment_instance_id'] = Variable<String>(
        equipmentInstanceId.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EquippedItemsCompanion(')
          ..write('playerId: $playerId, ')
          ..write('slot: $slot, ')
          ..write('equipmentInstanceId: $equipmentInstanceId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DungeonProgressesTable extends DungeonProgresses
    with TableInfo<$DungeonProgressesTable, DungeonProgressesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DungeonProgressesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playerIdMeta = const VerificationMeta(
    'playerId',
  );
  @override
  late final GeneratedColumn<String> playerId = GeneratedColumn<String>(
    'player_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES players (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dungeonIdMeta = const VerificationMeta(
    'dungeonId',
  );
  @override
  late final GeneratedColumn<String> dungeonId = GeneratedColumn<String>(
    'dungeon_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentRoomIdMeta = const VerificationMeta(
    'currentRoomId',
  );
  @override
  late final GeneratedColumn<String> currentRoomId = GeneratedColumn<String>(
    'current_room_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentRoomIndexMeta = const VerificationMeta(
    'currentRoomIndex',
  );
  @override
  late final GeneratedColumn<int> currentRoomIndex = GeneratedColumn<int>(
    'current_room_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _highestClearedRoomIndexMeta =
      const VerificationMeta('highestClearedRoomIndex');
  @override
  late final GeneratedColumn<int> highestClearedRoomIndex =
      GeneratedColumn<int>(
        'highest_cleared_room_index',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _clearsCountMeta = const VerificationMeta(
    'clearsCount',
  );
  @override
  late final GeneratedColumn<int> clearsCount = GeneratedColumn<int>(
    'clears_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clearedInCycleRankMeta =
      const VerificationMeta('clearedInCycleRank');
  @override
  late final GeneratedColumn<int> clearedInCycleRank = GeneratedColumn<int>(
    'cleared_in_cycle_rank',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(-1),
  );
  static const VerificationMeta _rewardStateJsonMeta = const VerificationMeta(
    'rewardStateJson',
  );
  @override
  late final GeneratedColumn<String> rewardStateJson = GeneratedColumn<String>(
    'reward_state_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    playerId,
    dungeonId,
    currentRoomId,
    currentRoomIndex,
    highestClearedRoomIndex,
    clearsCount,
    clearedInCycleRank,
    rewardStateJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dungeon_progresses';
  @override
  VerificationContext validateIntegrity(
    Insertable<DungeonProgressesData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('player_id')) {
      context.handle(
        _playerIdMeta,
        playerId.isAcceptableOrUnknown(data['player_id']!, _playerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playerIdMeta);
    }
    if (data.containsKey('dungeon_id')) {
      context.handle(
        _dungeonIdMeta,
        dungeonId.isAcceptableOrUnknown(data['dungeon_id']!, _dungeonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_dungeonIdMeta);
    }
    if (data.containsKey('current_room_id')) {
      context.handle(
        _currentRoomIdMeta,
        currentRoomId.isAcceptableOrUnknown(
          data['current_room_id']!,
          _currentRoomIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentRoomIdMeta);
    }
    if (data.containsKey('current_room_index')) {
      context.handle(
        _currentRoomIndexMeta,
        currentRoomIndex.isAcceptableOrUnknown(
          data['current_room_index']!,
          _currentRoomIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentRoomIndexMeta);
    }
    if (data.containsKey('highest_cleared_room_index')) {
      context.handle(
        _highestClearedRoomIndexMeta,
        highestClearedRoomIndex.isAcceptableOrUnknown(
          data['highest_cleared_room_index']!,
          _highestClearedRoomIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_highestClearedRoomIndexMeta);
    }
    if (data.containsKey('clears_count')) {
      context.handle(
        _clearsCountMeta,
        clearsCount.isAcceptableOrUnknown(
          data['clears_count']!,
          _clearsCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clearsCountMeta);
    }
    if (data.containsKey('cleared_in_cycle_rank')) {
      context.handle(
        _clearedInCycleRankMeta,
        clearedInCycleRank.isAcceptableOrUnknown(
          data['cleared_in_cycle_rank']!,
          _clearedInCycleRankMeta,
        ),
      );
    }
    if (data.containsKey('reward_state_json')) {
      context.handle(
        _rewardStateJsonMeta,
        rewardStateJson.isAcceptableOrUnknown(
          data['reward_state_json']!,
          _rewardStateJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playerId, dungeonId};
  @override
  DungeonProgressesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DungeonProgressesData(
      playerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_id'],
      )!,
      dungeonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dungeon_id'],
      )!,
      currentRoomId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_room_id'],
      )!,
      currentRoomIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_room_index'],
      )!,
      highestClearedRoomIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}highest_cleared_room_index'],
      )!,
      clearsCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}clears_count'],
      )!,
      clearedInCycleRank: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cleared_in_cycle_rank'],
      )!,
      rewardStateJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reward_state_json'],
      )!,
    );
  }

  @override
  $DungeonProgressesTable createAlias(String alias) {
    return $DungeonProgressesTable(attachedDatabase, alias);
  }
}

class DungeonProgressesData extends DataClass
    implements Insertable<DungeonProgressesData> {
  final String playerId;
  final String dungeonId;
  final String currentRoomId;
  final int currentRoomIndex;
  final int highestClearedRoomIndex;
  final int clearsCount;
  final int clearedInCycleRank;
  final String rewardStateJson;
  const DungeonProgressesData({
    required this.playerId,
    required this.dungeonId,
    required this.currentRoomId,
    required this.currentRoomIndex,
    required this.highestClearedRoomIndex,
    required this.clearsCount,
    required this.clearedInCycleRank,
    required this.rewardStateJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['player_id'] = Variable<String>(playerId);
    map['dungeon_id'] = Variable<String>(dungeonId);
    map['current_room_id'] = Variable<String>(currentRoomId);
    map['current_room_index'] = Variable<int>(currentRoomIndex);
    map['highest_cleared_room_index'] = Variable<int>(highestClearedRoomIndex);
    map['clears_count'] = Variable<int>(clearsCount);
    map['cleared_in_cycle_rank'] = Variable<int>(clearedInCycleRank);
    map['reward_state_json'] = Variable<String>(rewardStateJson);
    return map;
  }

  DungeonProgressesCompanion toCompanion(bool nullToAbsent) {
    return DungeonProgressesCompanion(
      playerId: Value(playerId),
      dungeonId: Value(dungeonId),
      currentRoomId: Value(currentRoomId),
      currentRoomIndex: Value(currentRoomIndex),
      highestClearedRoomIndex: Value(highestClearedRoomIndex),
      clearsCount: Value(clearsCount),
      clearedInCycleRank: Value(clearedInCycleRank),
      rewardStateJson: Value(rewardStateJson),
    );
  }

  factory DungeonProgressesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DungeonProgressesData(
      playerId: serializer.fromJson<String>(json['playerId']),
      dungeonId: serializer.fromJson<String>(json['dungeonId']),
      currentRoomId: serializer.fromJson<String>(json['currentRoomId']),
      currentRoomIndex: serializer.fromJson<int>(json['currentRoomIndex']),
      highestClearedRoomIndex: serializer.fromJson<int>(
        json['highestClearedRoomIndex'],
      ),
      clearsCount: serializer.fromJson<int>(json['clearsCount']),
      clearedInCycleRank: serializer.fromJson<int>(json['clearedInCycleRank']),
      rewardStateJson: serializer.fromJson<String>(json['rewardStateJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playerId': serializer.toJson<String>(playerId),
      'dungeonId': serializer.toJson<String>(dungeonId),
      'currentRoomId': serializer.toJson<String>(currentRoomId),
      'currentRoomIndex': serializer.toJson<int>(currentRoomIndex),
      'highestClearedRoomIndex': serializer.toJson<int>(
        highestClearedRoomIndex,
      ),
      'clearsCount': serializer.toJson<int>(clearsCount),
      'clearedInCycleRank': serializer.toJson<int>(clearedInCycleRank),
      'rewardStateJson': serializer.toJson<String>(rewardStateJson),
    };
  }

  DungeonProgressesData copyWith({
    String? playerId,
    String? dungeonId,
    String? currentRoomId,
    int? currentRoomIndex,
    int? highestClearedRoomIndex,
    int? clearsCount,
    int? clearedInCycleRank,
    String? rewardStateJson,
  }) => DungeonProgressesData(
    playerId: playerId ?? this.playerId,
    dungeonId: dungeonId ?? this.dungeonId,
    currentRoomId: currentRoomId ?? this.currentRoomId,
    currentRoomIndex: currentRoomIndex ?? this.currentRoomIndex,
    highestClearedRoomIndex:
        highestClearedRoomIndex ?? this.highestClearedRoomIndex,
    clearsCount: clearsCount ?? this.clearsCount,
    clearedInCycleRank: clearedInCycleRank ?? this.clearedInCycleRank,
    rewardStateJson: rewardStateJson ?? this.rewardStateJson,
  );
  DungeonProgressesData copyWithCompanion(DungeonProgressesCompanion data) {
    return DungeonProgressesData(
      playerId: data.playerId.present ? data.playerId.value : this.playerId,
      dungeonId: data.dungeonId.present ? data.dungeonId.value : this.dungeonId,
      currentRoomId: data.currentRoomId.present
          ? data.currentRoomId.value
          : this.currentRoomId,
      currentRoomIndex: data.currentRoomIndex.present
          ? data.currentRoomIndex.value
          : this.currentRoomIndex,
      highestClearedRoomIndex: data.highestClearedRoomIndex.present
          ? data.highestClearedRoomIndex.value
          : this.highestClearedRoomIndex,
      clearsCount: data.clearsCount.present
          ? data.clearsCount.value
          : this.clearsCount,
      clearedInCycleRank: data.clearedInCycleRank.present
          ? data.clearedInCycleRank.value
          : this.clearedInCycleRank,
      rewardStateJson: data.rewardStateJson.present
          ? data.rewardStateJson.value
          : this.rewardStateJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DungeonProgressesData(')
          ..write('playerId: $playerId, ')
          ..write('dungeonId: $dungeonId, ')
          ..write('currentRoomId: $currentRoomId, ')
          ..write('currentRoomIndex: $currentRoomIndex, ')
          ..write('highestClearedRoomIndex: $highestClearedRoomIndex, ')
          ..write('clearsCount: $clearsCount, ')
          ..write('clearedInCycleRank: $clearedInCycleRank, ')
          ..write('rewardStateJson: $rewardStateJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    playerId,
    dungeonId,
    currentRoomId,
    currentRoomIndex,
    highestClearedRoomIndex,
    clearsCount,
    clearedInCycleRank,
    rewardStateJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DungeonProgressesData &&
          other.playerId == this.playerId &&
          other.dungeonId == this.dungeonId &&
          other.currentRoomId == this.currentRoomId &&
          other.currentRoomIndex == this.currentRoomIndex &&
          other.highestClearedRoomIndex == this.highestClearedRoomIndex &&
          other.clearsCount == this.clearsCount &&
          other.clearedInCycleRank == this.clearedInCycleRank &&
          other.rewardStateJson == this.rewardStateJson);
}

class DungeonProgressesCompanion
    extends UpdateCompanion<DungeonProgressesData> {
  final Value<String> playerId;
  final Value<String> dungeonId;
  final Value<String> currentRoomId;
  final Value<int> currentRoomIndex;
  final Value<int> highestClearedRoomIndex;
  final Value<int> clearsCount;
  final Value<int> clearedInCycleRank;
  final Value<String> rewardStateJson;
  final Value<int> rowid;
  const DungeonProgressesCompanion({
    this.playerId = const Value.absent(),
    this.dungeonId = const Value.absent(),
    this.currentRoomId = const Value.absent(),
    this.currentRoomIndex = const Value.absent(),
    this.highestClearedRoomIndex = const Value.absent(),
    this.clearsCount = const Value.absent(),
    this.clearedInCycleRank = const Value.absent(),
    this.rewardStateJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DungeonProgressesCompanion.insert({
    required String playerId,
    required String dungeonId,
    required String currentRoomId,
    required int currentRoomIndex,
    required int highestClearedRoomIndex,
    required int clearsCount,
    this.clearedInCycleRank = const Value.absent(),
    this.rewardStateJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : playerId = Value(playerId),
       dungeonId = Value(dungeonId),
       currentRoomId = Value(currentRoomId),
       currentRoomIndex = Value(currentRoomIndex),
       highestClearedRoomIndex = Value(highestClearedRoomIndex),
       clearsCount = Value(clearsCount);
  static Insertable<DungeonProgressesData> custom({
    Expression<String>? playerId,
    Expression<String>? dungeonId,
    Expression<String>? currentRoomId,
    Expression<int>? currentRoomIndex,
    Expression<int>? highestClearedRoomIndex,
    Expression<int>? clearsCount,
    Expression<int>? clearedInCycleRank,
    Expression<String>? rewardStateJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playerId != null) 'player_id': playerId,
      if (dungeonId != null) 'dungeon_id': dungeonId,
      if (currentRoomId != null) 'current_room_id': currentRoomId,
      if (currentRoomIndex != null) 'current_room_index': currentRoomIndex,
      if (highestClearedRoomIndex != null)
        'highest_cleared_room_index': highestClearedRoomIndex,
      if (clearsCount != null) 'clears_count': clearsCount,
      if (clearedInCycleRank != null)
        'cleared_in_cycle_rank': clearedInCycleRank,
      if (rewardStateJson != null) 'reward_state_json': rewardStateJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DungeonProgressesCompanion copyWith({
    Value<String>? playerId,
    Value<String>? dungeonId,
    Value<String>? currentRoomId,
    Value<int>? currentRoomIndex,
    Value<int>? highestClearedRoomIndex,
    Value<int>? clearsCount,
    Value<int>? clearedInCycleRank,
    Value<String>? rewardStateJson,
    Value<int>? rowid,
  }) {
    return DungeonProgressesCompanion(
      playerId: playerId ?? this.playerId,
      dungeonId: dungeonId ?? this.dungeonId,
      currentRoomId: currentRoomId ?? this.currentRoomId,
      currentRoomIndex: currentRoomIndex ?? this.currentRoomIndex,
      highestClearedRoomIndex:
          highestClearedRoomIndex ?? this.highestClearedRoomIndex,
      clearsCount: clearsCount ?? this.clearsCount,
      clearedInCycleRank: clearedInCycleRank ?? this.clearedInCycleRank,
      rewardStateJson: rewardStateJson ?? this.rewardStateJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playerId.present) {
      map['player_id'] = Variable<String>(playerId.value);
    }
    if (dungeonId.present) {
      map['dungeon_id'] = Variable<String>(dungeonId.value);
    }
    if (currentRoomId.present) {
      map['current_room_id'] = Variable<String>(currentRoomId.value);
    }
    if (currentRoomIndex.present) {
      map['current_room_index'] = Variable<int>(currentRoomIndex.value);
    }
    if (highestClearedRoomIndex.present) {
      map['highest_cleared_room_index'] = Variable<int>(
        highestClearedRoomIndex.value,
      );
    }
    if (clearsCount.present) {
      map['clears_count'] = Variable<int>(clearsCount.value);
    }
    if (clearedInCycleRank.present) {
      map['cleared_in_cycle_rank'] = Variable<int>(clearedInCycleRank.value);
    }
    if (rewardStateJson.present) {
      map['reward_state_json'] = Variable<String>(rewardStateJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DungeonProgressesCompanion(')
          ..write('playerId: $playerId, ')
          ..write('dungeonId: $dungeonId, ')
          ..write('currentRoomId: $currentRoomId, ')
          ..write('currentRoomIndex: $currentRoomIndex, ')
          ..write('highestClearedRoomIndex: $highestClearedRoomIndex, ')
          ..write('clearsCount: $clearsCount, ')
          ..write('clearedInCycleRank: $clearedInCycleRank, ')
          ..write('rewardStateJson: $rewardStateJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CycleProgressesTable extends CycleProgresses
    with TableInfo<$CycleProgressesTable, CycleProgressesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CycleProgressesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playerIdMeta = const VerificationMeta(
    'playerId',
  );
  @override
  late final GeneratedColumn<String> playerId = GeneratedColumn<String>(
    'player_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES players (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _ascensionRankMeta = const VerificationMeta(
    'ascensionRank',
  );
  @override
  late final GeneratedColumn<int> ascensionRank = GeneratedColumn<int>(
    'ascension_rank',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _highestAscensionRankMeta =
      const VerificationMeta('highestAscensionRank');
  @override
  late final GeneratedColumn<int> highestAscensionRank = GeneratedColumn<int>(
    'highest_ascension_rank',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastNormalDungeonIdMeta =
      const VerificationMeta('lastNormalDungeonId');
  @override
  late final GeneratedColumn<String> lastNormalDungeonId =
      GeneratedColumn<String>(
        'last_normal_dungeon_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    playerId,
    ascensionRank,
    highestAscensionRank,
    lastNormalDungeonId,
    updatedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cycle_progresses';
  @override
  VerificationContext validateIntegrity(
    Insertable<CycleProgressesData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('player_id')) {
      context.handle(
        _playerIdMeta,
        playerId.isAcceptableOrUnknown(data['player_id']!, _playerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playerIdMeta);
    }
    if (data.containsKey('ascension_rank')) {
      context.handle(
        _ascensionRankMeta,
        ascensionRank.isAcceptableOrUnknown(
          data['ascension_rank']!,
          _ascensionRankMeta,
        ),
      );
    }
    if (data.containsKey('highest_ascension_rank')) {
      context.handle(
        _highestAscensionRankMeta,
        highestAscensionRank.isAcceptableOrUnknown(
          data['highest_ascension_rank']!,
          _highestAscensionRankMeta,
        ),
      );
    }
    if (data.containsKey('last_normal_dungeon_id')) {
      context.handle(
        _lastNormalDungeonIdMeta,
        lastNormalDungeonId.isAcceptableOrUnknown(
          data['last_normal_dungeon_id']!,
          _lastNormalDungeonIdMeta,
        ),
      );
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playerId};
  @override
  CycleProgressesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CycleProgressesData(
      playerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_id'],
      )!,
      ascensionRank: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ascension_rank'],
      )!,
      highestAscensionRank: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}highest_ascension_rank'],
      )!,
      lastNormalDungeonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_normal_dungeon_id'],
      ),
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
    );
  }

  @override
  $CycleProgressesTable createAlias(String alias) {
    return $CycleProgressesTable(attachedDatabase, alias);
  }
}

class CycleProgressesData extends DataClass
    implements Insertable<CycleProgressesData> {
  final String playerId;
  final int ascensionRank;
  final int highestAscensionRank;
  final String? lastNormalDungeonId;
  final int updatedAtMs;
  const CycleProgressesData({
    required this.playerId,
    required this.ascensionRank,
    required this.highestAscensionRank,
    this.lastNormalDungeonId,
    required this.updatedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['player_id'] = Variable<String>(playerId);
    map['ascension_rank'] = Variable<int>(ascensionRank);
    map['highest_ascension_rank'] = Variable<int>(highestAscensionRank);
    if (!nullToAbsent || lastNormalDungeonId != null) {
      map['last_normal_dungeon_id'] = Variable<String>(lastNormalDungeonId);
    }
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    return map;
  }

  CycleProgressesCompanion toCompanion(bool nullToAbsent) {
    return CycleProgressesCompanion(
      playerId: Value(playerId),
      ascensionRank: Value(ascensionRank),
      highestAscensionRank: Value(highestAscensionRank),
      lastNormalDungeonId: lastNormalDungeonId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastNormalDungeonId),
      updatedAtMs: Value(updatedAtMs),
    );
  }

  factory CycleProgressesData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CycleProgressesData(
      playerId: serializer.fromJson<String>(json['playerId']),
      ascensionRank: serializer.fromJson<int>(json['ascensionRank']),
      highestAscensionRank: serializer.fromJson<int>(
        json['highestAscensionRank'],
      ),
      lastNormalDungeonId: serializer.fromJson<String?>(
        json['lastNormalDungeonId'],
      ),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playerId': serializer.toJson<String>(playerId),
      'ascensionRank': serializer.toJson<int>(ascensionRank),
      'highestAscensionRank': serializer.toJson<int>(highestAscensionRank),
      'lastNormalDungeonId': serializer.toJson<String?>(lastNormalDungeonId),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
    };
  }

  CycleProgressesData copyWith({
    String? playerId,
    int? ascensionRank,
    int? highestAscensionRank,
    Value<String?> lastNormalDungeonId = const Value.absent(),
    int? updatedAtMs,
  }) => CycleProgressesData(
    playerId: playerId ?? this.playerId,
    ascensionRank: ascensionRank ?? this.ascensionRank,
    highestAscensionRank: highestAscensionRank ?? this.highestAscensionRank,
    lastNormalDungeonId: lastNormalDungeonId.present
        ? lastNormalDungeonId.value
        : this.lastNormalDungeonId,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
  );
  CycleProgressesData copyWithCompanion(CycleProgressesCompanion data) {
    return CycleProgressesData(
      playerId: data.playerId.present ? data.playerId.value : this.playerId,
      ascensionRank: data.ascensionRank.present
          ? data.ascensionRank.value
          : this.ascensionRank,
      highestAscensionRank: data.highestAscensionRank.present
          ? data.highestAscensionRank.value
          : this.highestAscensionRank,
      lastNormalDungeonId: data.lastNormalDungeonId.present
          ? data.lastNormalDungeonId.value
          : this.lastNormalDungeonId,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CycleProgressesData(')
          ..write('playerId: $playerId, ')
          ..write('ascensionRank: $ascensionRank, ')
          ..write('highestAscensionRank: $highestAscensionRank, ')
          ..write('lastNormalDungeonId: $lastNormalDungeonId, ')
          ..write('updatedAtMs: $updatedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    playerId,
    ascensionRank,
    highestAscensionRank,
    lastNormalDungeonId,
    updatedAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CycleProgressesData &&
          other.playerId == this.playerId &&
          other.ascensionRank == this.ascensionRank &&
          other.highestAscensionRank == this.highestAscensionRank &&
          other.lastNormalDungeonId == this.lastNormalDungeonId &&
          other.updatedAtMs == this.updatedAtMs);
}

class CycleProgressesCompanion extends UpdateCompanion<CycleProgressesData> {
  final Value<String> playerId;
  final Value<int> ascensionRank;
  final Value<int> highestAscensionRank;
  final Value<String?> lastNormalDungeonId;
  final Value<int> updatedAtMs;
  final Value<int> rowid;
  const CycleProgressesCompanion({
    this.playerId = const Value.absent(),
    this.ascensionRank = const Value.absent(),
    this.highestAscensionRank = const Value.absent(),
    this.lastNormalDungeonId = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CycleProgressesCompanion.insert({
    required String playerId,
    this.ascensionRank = const Value.absent(),
    this.highestAscensionRank = const Value.absent(),
    this.lastNormalDungeonId = const Value.absent(),
    required int updatedAtMs,
    this.rowid = const Value.absent(),
  }) : playerId = Value(playerId),
       updatedAtMs = Value(updatedAtMs);
  static Insertable<CycleProgressesData> custom({
    Expression<String>? playerId,
    Expression<int>? ascensionRank,
    Expression<int>? highestAscensionRank,
    Expression<String>? lastNormalDungeonId,
    Expression<int>? updatedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playerId != null) 'player_id': playerId,
      if (ascensionRank != null) 'ascension_rank': ascensionRank,
      if (highestAscensionRank != null)
        'highest_ascension_rank': highestAscensionRank,
      if (lastNormalDungeonId != null)
        'last_normal_dungeon_id': lastNormalDungeonId,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CycleProgressesCompanion copyWith({
    Value<String>? playerId,
    Value<int>? ascensionRank,
    Value<int>? highestAscensionRank,
    Value<String?>? lastNormalDungeonId,
    Value<int>? updatedAtMs,
    Value<int>? rowid,
  }) {
    return CycleProgressesCompanion(
      playerId: playerId ?? this.playerId,
      ascensionRank: ascensionRank ?? this.ascensionRank,
      highestAscensionRank: highestAscensionRank ?? this.highestAscensionRank,
      lastNormalDungeonId: lastNormalDungeonId ?? this.lastNormalDungeonId,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playerId.present) {
      map['player_id'] = Variable<String>(playerId.value);
    }
    if (ascensionRank.present) {
      map['ascension_rank'] = Variable<int>(ascensionRank.value);
    }
    if (highestAscensionRank.present) {
      map['highest_ascension_rank'] = Variable<int>(highestAscensionRank.value);
    }
    if (lastNormalDungeonId.present) {
      map['last_normal_dungeon_id'] = Variable<String>(
        lastNormalDungeonId.value,
      );
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CycleProgressesCompanion(')
          ..write('playerId: $playerId, ')
          ..write('ascensionRank: $ascensionRank, ')
          ..write('highestAscensionRank: $highestAscensionRank, ')
          ..write('lastNormalDungeonId: $lastNormalDungeonId, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GameSessionsTable extends GameSessions
    with TableInfo<$GameSessionsTable, GameSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GameSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playerIdMeta = const VerificationMeta(
    'playerId',
  );
  @override
  late final GeneratedColumn<String> playerId = GeneratedColumn<String>(
    'player_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES players (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _lastActiveAtMsMeta = const VerificationMeta(
    'lastActiveAtMs',
  );
  @override
  late final GeneratedColumn<int> lastActiveAtMs = GeneratedColumn<int>(
    'last_active_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSavedAtMsMeta = const VerificationMeta(
    'lastSavedAtMs',
  );
  @override
  late final GeneratedColumn<int> lastSavedAtMs = GeneratedColumn<int>(
    'last_saved_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastOfflineClaimAtMsMeta =
      const VerificationMeta('lastOfflineClaimAtMs');
  @override
  late final GeneratedColumn<int> lastOfflineClaimAtMs = GeneratedColumn<int>(
    'last_offline_claim_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _autoSkillEnabledMeta = const VerificationMeta(
    'autoSkillEnabled',
  );
  @override
  late final GeneratedColumn<bool> autoSkillEnabled = GeneratedColumn<bool>(
    'auto_skill_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_skill_enabled" IN (0, 1))',
    ),
  );
  static const VerificationMeta _sessionDataJsonMeta = const VerificationMeta(
    'sessionDataJson',
  );
  @override
  late final GeneratedColumn<String> sessionDataJson = GeneratedColumn<String>(
    'session_data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    playerId,
    lastActiveAtMs,
    lastSavedAtMs,
    lastOfflineClaimAtMs,
    autoSkillEnabled,
    sessionDataJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'game_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<GameSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('player_id')) {
      context.handle(
        _playerIdMeta,
        playerId.isAcceptableOrUnknown(data['player_id']!, _playerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playerIdMeta);
    }
    if (data.containsKey('last_active_at_ms')) {
      context.handle(
        _lastActiveAtMsMeta,
        lastActiveAtMs.isAcceptableOrUnknown(
          data['last_active_at_ms']!,
          _lastActiveAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastActiveAtMsMeta);
    }
    if (data.containsKey('last_saved_at_ms')) {
      context.handle(
        _lastSavedAtMsMeta,
        lastSavedAtMs.isAcceptableOrUnknown(
          data['last_saved_at_ms']!,
          _lastSavedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSavedAtMsMeta);
    }
    if (data.containsKey('last_offline_claim_at_ms')) {
      context.handle(
        _lastOfflineClaimAtMsMeta,
        lastOfflineClaimAtMs.isAcceptableOrUnknown(
          data['last_offline_claim_at_ms']!,
          _lastOfflineClaimAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastOfflineClaimAtMsMeta);
    }
    if (data.containsKey('auto_skill_enabled')) {
      context.handle(
        _autoSkillEnabledMeta,
        autoSkillEnabled.isAcceptableOrUnknown(
          data['auto_skill_enabled']!,
          _autoSkillEnabledMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_autoSkillEnabledMeta);
    }
    if (data.containsKey('session_data_json')) {
      context.handle(
        _sessionDataJsonMeta,
        sessionDataJson.isAcceptableOrUnknown(
          data['session_data_json']!,
          _sessionDataJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GameSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GameSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      playerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_id'],
      )!,
      lastActiveAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_active_at_ms'],
      )!,
      lastSavedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_saved_at_ms'],
      )!,
      lastOfflineClaimAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_offline_claim_at_ms'],
      )!,
      autoSkillEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_skill_enabled'],
      )!,
      sessionDataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_data_json'],
      )!,
    );
  }

  @override
  $GameSessionsTable createAlias(String alias) {
    return $GameSessionsTable(attachedDatabase, alias);
  }
}

class GameSession extends DataClass implements Insertable<GameSession> {
  final String id;
  final String playerId;
  final int lastActiveAtMs;
  final int lastSavedAtMs;
  final int lastOfflineClaimAtMs;
  final bool autoSkillEnabled;
  final String sessionDataJson;
  const GameSession({
    required this.id,
    required this.playerId,
    required this.lastActiveAtMs,
    required this.lastSavedAtMs,
    required this.lastOfflineClaimAtMs,
    required this.autoSkillEnabled,
    required this.sessionDataJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['player_id'] = Variable<String>(playerId);
    map['last_active_at_ms'] = Variable<int>(lastActiveAtMs);
    map['last_saved_at_ms'] = Variable<int>(lastSavedAtMs);
    map['last_offline_claim_at_ms'] = Variable<int>(lastOfflineClaimAtMs);
    map['auto_skill_enabled'] = Variable<bool>(autoSkillEnabled);
    map['session_data_json'] = Variable<String>(sessionDataJson);
    return map;
  }

  GameSessionsCompanion toCompanion(bool nullToAbsent) {
    return GameSessionsCompanion(
      id: Value(id),
      playerId: Value(playerId),
      lastActiveAtMs: Value(lastActiveAtMs),
      lastSavedAtMs: Value(lastSavedAtMs),
      lastOfflineClaimAtMs: Value(lastOfflineClaimAtMs),
      autoSkillEnabled: Value(autoSkillEnabled),
      sessionDataJson: Value(sessionDataJson),
    );
  }

  factory GameSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GameSession(
      id: serializer.fromJson<String>(json['id']),
      playerId: serializer.fromJson<String>(json['playerId']),
      lastActiveAtMs: serializer.fromJson<int>(json['lastActiveAtMs']),
      lastSavedAtMs: serializer.fromJson<int>(json['lastSavedAtMs']),
      lastOfflineClaimAtMs: serializer.fromJson<int>(
        json['lastOfflineClaimAtMs'],
      ),
      autoSkillEnabled: serializer.fromJson<bool>(json['autoSkillEnabled']),
      sessionDataJson: serializer.fromJson<String>(json['sessionDataJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'playerId': serializer.toJson<String>(playerId),
      'lastActiveAtMs': serializer.toJson<int>(lastActiveAtMs),
      'lastSavedAtMs': serializer.toJson<int>(lastSavedAtMs),
      'lastOfflineClaimAtMs': serializer.toJson<int>(lastOfflineClaimAtMs),
      'autoSkillEnabled': serializer.toJson<bool>(autoSkillEnabled),
      'sessionDataJson': serializer.toJson<String>(sessionDataJson),
    };
  }

  GameSession copyWith({
    String? id,
    String? playerId,
    int? lastActiveAtMs,
    int? lastSavedAtMs,
    int? lastOfflineClaimAtMs,
    bool? autoSkillEnabled,
    String? sessionDataJson,
  }) => GameSession(
    id: id ?? this.id,
    playerId: playerId ?? this.playerId,
    lastActiveAtMs: lastActiveAtMs ?? this.lastActiveAtMs,
    lastSavedAtMs: lastSavedAtMs ?? this.lastSavedAtMs,
    lastOfflineClaimAtMs: lastOfflineClaimAtMs ?? this.lastOfflineClaimAtMs,
    autoSkillEnabled: autoSkillEnabled ?? this.autoSkillEnabled,
    sessionDataJson: sessionDataJson ?? this.sessionDataJson,
  );
  GameSession copyWithCompanion(GameSessionsCompanion data) {
    return GameSession(
      id: data.id.present ? data.id.value : this.id,
      playerId: data.playerId.present ? data.playerId.value : this.playerId,
      lastActiveAtMs: data.lastActiveAtMs.present
          ? data.lastActiveAtMs.value
          : this.lastActiveAtMs,
      lastSavedAtMs: data.lastSavedAtMs.present
          ? data.lastSavedAtMs.value
          : this.lastSavedAtMs,
      lastOfflineClaimAtMs: data.lastOfflineClaimAtMs.present
          ? data.lastOfflineClaimAtMs.value
          : this.lastOfflineClaimAtMs,
      autoSkillEnabled: data.autoSkillEnabled.present
          ? data.autoSkillEnabled.value
          : this.autoSkillEnabled,
      sessionDataJson: data.sessionDataJson.present
          ? data.sessionDataJson.value
          : this.sessionDataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GameSession(')
          ..write('id: $id, ')
          ..write('playerId: $playerId, ')
          ..write('lastActiveAtMs: $lastActiveAtMs, ')
          ..write('lastSavedAtMs: $lastSavedAtMs, ')
          ..write('lastOfflineClaimAtMs: $lastOfflineClaimAtMs, ')
          ..write('autoSkillEnabled: $autoSkillEnabled, ')
          ..write('sessionDataJson: $sessionDataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    playerId,
    lastActiveAtMs,
    lastSavedAtMs,
    lastOfflineClaimAtMs,
    autoSkillEnabled,
    sessionDataJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameSession &&
          other.id == this.id &&
          other.playerId == this.playerId &&
          other.lastActiveAtMs == this.lastActiveAtMs &&
          other.lastSavedAtMs == this.lastSavedAtMs &&
          other.lastOfflineClaimAtMs == this.lastOfflineClaimAtMs &&
          other.autoSkillEnabled == this.autoSkillEnabled &&
          other.sessionDataJson == this.sessionDataJson);
}

class GameSessionsCompanion extends UpdateCompanion<GameSession> {
  final Value<String> id;
  final Value<String> playerId;
  final Value<int> lastActiveAtMs;
  final Value<int> lastSavedAtMs;
  final Value<int> lastOfflineClaimAtMs;
  final Value<bool> autoSkillEnabled;
  final Value<String> sessionDataJson;
  final Value<int> rowid;
  const GameSessionsCompanion({
    this.id = const Value.absent(),
    this.playerId = const Value.absent(),
    this.lastActiveAtMs = const Value.absent(),
    this.lastSavedAtMs = const Value.absent(),
    this.lastOfflineClaimAtMs = const Value.absent(),
    this.autoSkillEnabled = const Value.absent(),
    this.sessionDataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GameSessionsCompanion.insert({
    required String id,
    required String playerId,
    required int lastActiveAtMs,
    required int lastSavedAtMs,
    required int lastOfflineClaimAtMs,
    required bool autoSkillEnabled,
    this.sessionDataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       playerId = Value(playerId),
       lastActiveAtMs = Value(lastActiveAtMs),
       lastSavedAtMs = Value(lastSavedAtMs),
       lastOfflineClaimAtMs = Value(lastOfflineClaimAtMs),
       autoSkillEnabled = Value(autoSkillEnabled);
  static Insertable<GameSession> custom({
    Expression<String>? id,
    Expression<String>? playerId,
    Expression<int>? lastActiveAtMs,
    Expression<int>? lastSavedAtMs,
    Expression<int>? lastOfflineClaimAtMs,
    Expression<bool>? autoSkillEnabled,
    Expression<String>? sessionDataJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playerId != null) 'player_id': playerId,
      if (lastActiveAtMs != null) 'last_active_at_ms': lastActiveAtMs,
      if (lastSavedAtMs != null) 'last_saved_at_ms': lastSavedAtMs,
      if (lastOfflineClaimAtMs != null)
        'last_offline_claim_at_ms': lastOfflineClaimAtMs,
      if (autoSkillEnabled != null) 'auto_skill_enabled': autoSkillEnabled,
      if (sessionDataJson != null) 'session_data_json': sessionDataJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GameSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? playerId,
    Value<int>? lastActiveAtMs,
    Value<int>? lastSavedAtMs,
    Value<int>? lastOfflineClaimAtMs,
    Value<bool>? autoSkillEnabled,
    Value<String>? sessionDataJson,
    Value<int>? rowid,
  }) {
    return GameSessionsCompanion(
      id: id ?? this.id,
      playerId: playerId ?? this.playerId,
      lastActiveAtMs: lastActiveAtMs ?? this.lastActiveAtMs,
      lastSavedAtMs: lastSavedAtMs ?? this.lastSavedAtMs,
      lastOfflineClaimAtMs: lastOfflineClaimAtMs ?? this.lastOfflineClaimAtMs,
      autoSkillEnabled: autoSkillEnabled ?? this.autoSkillEnabled,
      sessionDataJson: sessionDataJson ?? this.sessionDataJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (playerId.present) {
      map['player_id'] = Variable<String>(playerId.value);
    }
    if (lastActiveAtMs.present) {
      map['last_active_at_ms'] = Variable<int>(lastActiveAtMs.value);
    }
    if (lastSavedAtMs.present) {
      map['last_saved_at_ms'] = Variable<int>(lastSavedAtMs.value);
    }
    if (lastOfflineClaimAtMs.present) {
      map['last_offline_claim_at_ms'] = Variable<int>(
        lastOfflineClaimAtMs.value,
      );
    }
    if (autoSkillEnabled.present) {
      map['auto_skill_enabled'] = Variable<bool>(autoSkillEnabled.value);
    }
    if (sessionDataJson.present) {
      map['session_data_json'] = Variable<String>(sessionDataJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GameSessionsCompanion(')
          ..write('id: $id, ')
          ..write('playerId: $playerId, ')
          ..write('lastActiveAtMs: $lastActiveAtMs, ')
          ..write('lastSavedAtMs: $lastSavedAtMs, ')
          ..write('lastOfflineClaimAtMs: $lastOfflineClaimAtMs, ')
          ..write('autoSkillEnabled: $autoSkillEnabled, ')
          ..write('sessionDataJson: $sessionDataJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClaimedRewardsTable extends ClaimedRewards
    with TableInfo<$ClaimedRewardsTable, ClaimedReward> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClaimedRewardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playerIdMeta = const VerificationMeta(
    'playerId',
  );
  @override
  late final GeneratedColumn<String> playerId = GeneratedColumn<String>(
    'player_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES players (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _claimedAtMsMeta = const VerificationMeta(
    'claimedAtMs',
  );
  @override
  late final GeneratedColumn<int> claimedAtMs = GeneratedColumn<int>(
    'claimed_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [playerId, eventId, claimedAtMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'claimed_rewards';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClaimedReward> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('player_id')) {
      context.handle(
        _playerIdMeta,
        playerId.isAcceptableOrUnknown(data['player_id']!, _playerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playerIdMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('claimed_at_ms')) {
      context.handle(
        _claimedAtMsMeta,
        claimedAtMs.isAcceptableOrUnknown(
          data['claimed_at_ms']!,
          _claimedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_claimedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playerId, eventId};
  @override
  ClaimedReward map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClaimedReward(
      playerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      claimedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}claimed_at_ms'],
      )!,
    );
  }

  @override
  $ClaimedRewardsTable createAlias(String alias) {
    return $ClaimedRewardsTable(attachedDatabase, alias);
  }
}

class ClaimedReward extends DataClass implements Insertable<ClaimedReward> {
  final String playerId;
  final String eventId;
  final int claimedAtMs;
  const ClaimedReward({
    required this.playerId,
    required this.eventId,
    required this.claimedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['player_id'] = Variable<String>(playerId);
    map['event_id'] = Variable<String>(eventId);
    map['claimed_at_ms'] = Variable<int>(claimedAtMs);
    return map;
  }

  ClaimedRewardsCompanion toCompanion(bool nullToAbsent) {
    return ClaimedRewardsCompanion(
      playerId: Value(playerId),
      eventId: Value(eventId),
      claimedAtMs: Value(claimedAtMs),
    );
  }

  factory ClaimedReward.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClaimedReward(
      playerId: serializer.fromJson<String>(json['playerId']),
      eventId: serializer.fromJson<String>(json['eventId']),
      claimedAtMs: serializer.fromJson<int>(json['claimedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playerId': serializer.toJson<String>(playerId),
      'eventId': serializer.toJson<String>(eventId),
      'claimedAtMs': serializer.toJson<int>(claimedAtMs),
    };
  }

  ClaimedReward copyWith({
    String? playerId,
    String? eventId,
    int? claimedAtMs,
  }) => ClaimedReward(
    playerId: playerId ?? this.playerId,
    eventId: eventId ?? this.eventId,
    claimedAtMs: claimedAtMs ?? this.claimedAtMs,
  );
  ClaimedReward copyWithCompanion(ClaimedRewardsCompanion data) {
    return ClaimedReward(
      playerId: data.playerId.present ? data.playerId.value : this.playerId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      claimedAtMs: data.claimedAtMs.present
          ? data.claimedAtMs.value
          : this.claimedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClaimedReward(')
          ..write('playerId: $playerId, ')
          ..write('eventId: $eventId, ')
          ..write('claimedAtMs: $claimedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playerId, eventId, claimedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClaimedReward &&
          other.playerId == this.playerId &&
          other.eventId == this.eventId &&
          other.claimedAtMs == this.claimedAtMs);
}

class ClaimedRewardsCompanion extends UpdateCompanion<ClaimedReward> {
  final Value<String> playerId;
  final Value<String> eventId;
  final Value<int> claimedAtMs;
  final Value<int> rowid;
  const ClaimedRewardsCompanion({
    this.playerId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.claimedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClaimedRewardsCompanion.insert({
    required String playerId,
    required String eventId,
    required int claimedAtMs,
    this.rowid = const Value.absent(),
  }) : playerId = Value(playerId),
       eventId = Value(eventId),
       claimedAtMs = Value(claimedAtMs);
  static Insertable<ClaimedReward> custom({
    Expression<String>? playerId,
    Expression<String>? eventId,
    Expression<int>? claimedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playerId != null) 'player_id': playerId,
      if (eventId != null) 'event_id': eventId,
      if (claimedAtMs != null) 'claimed_at_ms': claimedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClaimedRewardsCompanion copyWith({
    Value<String>? playerId,
    Value<String>? eventId,
    Value<int>? claimedAtMs,
    Value<int>? rowid,
  }) {
    return ClaimedRewardsCompanion(
      playerId: playerId ?? this.playerId,
      eventId: eventId ?? this.eventId,
      claimedAtMs: claimedAtMs ?? this.claimedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playerId.present) {
      map['player_id'] = Variable<String>(playerId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (claimedAtMs.present) {
      map['claimed_at_ms'] = Variable<int>(claimedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClaimedRewardsCompanion(')
          ..write('playerId: $playerId, ')
          ..write('eventId: $eventId, ')
          ..write('claimedAtMs: $claimedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShopPurchasesTable extends ShopPurchases
    with TableInfo<$ShopPurchasesTable, ShopPurchase> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShopPurchasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playerIdMeta = const VerificationMeta(
    'playerId',
  );
  @override
  late final GeneratedColumn<String> playerId = GeneratedColumn<String>(
    'player_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES players (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _purchasedCountMeta = const VerificationMeta(
    'purchasedCount',
  );
  @override
  late final GeneratedColumn<int> purchasedCount = GeneratedColumn<int>(
    'purchased_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [playerId, entryId, purchasedCount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shop_purchases';
  @override
  VerificationContext validateIntegrity(
    Insertable<ShopPurchase> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('player_id')) {
      context.handle(
        _playerIdMeta,
        playerId.isAcceptableOrUnknown(data['player_id']!, _playerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playerIdMeta);
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('purchased_count')) {
      context.handle(
        _purchasedCountMeta,
        purchasedCount.isAcceptableOrUnknown(
          data['purchased_count']!,
          _purchasedCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playerId, entryId};
  @override
  ShopPurchase map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShopPurchase(
      playerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_id'],
      )!,
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      purchasedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}purchased_count'],
      )!,
    );
  }

  @override
  $ShopPurchasesTable createAlias(String alias) {
    return $ShopPurchasesTable(attachedDatabase, alias);
  }
}

class ShopPurchase extends DataClass implements Insertable<ShopPurchase> {
  final String playerId;
  final String entryId;
  final int purchasedCount;
  const ShopPurchase({
    required this.playerId,
    required this.entryId,
    required this.purchasedCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['player_id'] = Variable<String>(playerId);
    map['entry_id'] = Variable<String>(entryId);
    map['purchased_count'] = Variable<int>(purchasedCount);
    return map;
  }

  ShopPurchasesCompanion toCompanion(bool nullToAbsent) {
    return ShopPurchasesCompanion(
      playerId: Value(playerId),
      entryId: Value(entryId),
      purchasedCount: Value(purchasedCount),
    );
  }

  factory ShopPurchase.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShopPurchase(
      playerId: serializer.fromJson<String>(json['playerId']),
      entryId: serializer.fromJson<String>(json['entryId']),
      purchasedCount: serializer.fromJson<int>(json['purchasedCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playerId': serializer.toJson<String>(playerId),
      'entryId': serializer.toJson<String>(entryId),
      'purchasedCount': serializer.toJson<int>(purchasedCount),
    };
  }

  ShopPurchase copyWith({
    String? playerId,
    String? entryId,
    int? purchasedCount,
  }) => ShopPurchase(
    playerId: playerId ?? this.playerId,
    entryId: entryId ?? this.entryId,
    purchasedCount: purchasedCount ?? this.purchasedCount,
  );
  ShopPurchase copyWithCompanion(ShopPurchasesCompanion data) {
    return ShopPurchase(
      playerId: data.playerId.present ? data.playerId.value : this.playerId,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      purchasedCount: data.purchasedCount.present
          ? data.purchasedCount.value
          : this.purchasedCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShopPurchase(')
          ..write('playerId: $playerId, ')
          ..write('entryId: $entryId, ')
          ..write('purchasedCount: $purchasedCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playerId, entryId, purchasedCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShopPurchase &&
          other.playerId == this.playerId &&
          other.entryId == this.entryId &&
          other.purchasedCount == this.purchasedCount);
}

class ShopPurchasesCompanion extends UpdateCompanion<ShopPurchase> {
  final Value<String> playerId;
  final Value<String> entryId;
  final Value<int> purchasedCount;
  final Value<int> rowid;
  const ShopPurchasesCompanion({
    this.playerId = const Value.absent(),
    this.entryId = const Value.absent(),
    this.purchasedCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShopPurchasesCompanion.insert({
    required String playerId,
    required String entryId,
    this.purchasedCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : playerId = Value(playerId),
       entryId = Value(entryId);
  static Insertable<ShopPurchase> custom({
    Expression<String>? playerId,
    Expression<String>? entryId,
    Expression<int>? purchasedCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playerId != null) 'player_id': playerId,
      if (entryId != null) 'entry_id': entryId,
      if (purchasedCount != null) 'purchased_count': purchasedCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShopPurchasesCompanion copyWith({
    Value<String>? playerId,
    Value<String>? entryId,
    Value<int>? purchasedCount,
    Value<int>? rowid,
  }) {
    return ShopPurchasesCompanion(
      playerId: playerId ?? this.playerId,
      entryId: entryId ?? this.entryId,
      purchasedCount: purchasedCount ?? this.purchasedCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playerId.present) {
      map['player_id'] = Variable<String>(playerId.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (purchasedCount.present) {
      map['purchased_count'] = Variable<int>(purchasedCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShopPurchasesCompanion(')
          ..write('playerId: $playerId, ')
          ..write('entryId: $entryId, ')
          ..write('purchasedCount: $purchasedCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClockStatesTable extends ClockStates
    with TableInfo<$ClockStatesTable, ClockState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClockStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playerIdMeta = const VerificationMeta(
    'playerId',
  );
  @override
  late final GeneratedColumn<String> playerId = GeneratedColumn<String>(
    'player_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES players (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _lastSeenAtMsMeta = const VerificationMeta(
    'lastSeenAtMs',
  );
  @override
  late final GeneratedColumn<int> lastSeenAtMs = GeneratedColumn<int>(
    'last_seen_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _forwardJumpCountMeta = const VerificationMeta(
    'forwardJumpCount',
  );
  @override
  late final GeneratedColumn<int> forwardJumpCount = GeneratedColumn<int>(
    'forward_jump_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _maxForwardJumpMsMeta = const VerificationMeta(
    'maxForwardJumpMs',
  );
  @override
  late final GeneratedColumn<int> maxForwardJumpMs = GeneratedColumn<int>(
    'max_forward_jump_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    playerId,
    lastSeenAtMs,
    forwardJumpCount,
    maxForwardJumpMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clock_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClockState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('player_id')) {
      context.handle(
        _playerIdMeta,
        playerId.isAcceptableOrUnknown(data['player_id']!, _playerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playerIdMeta);
    }
    if (data.containsKey('last_seen_at_ms')) {
      context.handle(
        _lastSeenAtMsMeta,
        lastSeenAtMs.isAcceptableOrUnknown(
          data['last_seen_at_ms']!,
          _lastSeenAtMsMeta,
        ),
      );
    }
    if (data.containsKey('forward_jump_count')) {
      context.handle(
        _forwardJumpCountMeta,
        forwardJumpCount.isAcceptableOrUnknown(
          data['forward_jump_count']!,
          _forwardJumpCountMeta,
        ),
      );
    }
    if (data.containsKey('max_forward_jump_ms')) {
      context.handle(
        _maxForwardJumpMsMeta,
        maxForwardJumpMs.isAcceptableOrUnknown(
          data['max_forward_jump_ms']!,
          _maxForwardJumpMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playerId};
  @override
  ClockState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClockState(
      playerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_id'],
      )!,
      lastSeenAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen_at_ms'],
      )!,
      forwardJumpCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}forward_jump_count'],
      )!,
      maxForwardJumpMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_forward_jump_ms'],
      )!,
    );
  }

  @override
  $ClockStatesTable createAlias(String alias) {
    return $ClockStatesTable(attachedDatabase, alias);
  }
}

class ClockState extends DataClass implements Insertable<ClockState> {
  final String playerId;
  final int lastSeenAtMs;
  final int forwardJumpCount;
  final int maxForwardJumpMs;
  const ClockState({
    required this.playerId,
    required this.lastSeenAtMs,
    required this.forwardJumpCount,
    required this.maxForwardJumpMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['player_id'] = Variable<String>(playerId);
    map['last_seen_at_ms'] = Variable<int>(lastSeenAtMs);
    map['forward_jump_count'] = Variable<int>(forwardJumpCount);
    map['max_forward_jump_ms'] = Variable<int>(maxForwardJumpMs);
    return map;
  }

  ClockStatesCompanion toCompanion(bool nullToAbsent) {
    return ClockStatesCompanion(
      playerId: Value(playerId),
      lastSeenAtMs: Value(lastSeenAtMs),
      forwardJumpCount: Value(forwardJumpCount),
      maxForwardJumpMs: Value(maxForwardJumpMs),
    );
  }

  factory ClockState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClockState(
      playerId: serializer.fromJson<String>(json['playerId']),
      lastSeenAtMs: serializer.fromJson<int>(json['lastSeenAtMs']),
      forwardJumpCount: serializer.fromJson<int>(json['forwardJumpCount']),
      maxForwardJumpMs: serializer.fromJson<int>(json['maxForwardJumpMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playerId': serializer.toJson<String>(playerId),
      'lastSeenAtMs': serializer.toJson<int>(lastSeenAtMs),
      'forwardJumpCount': serializer.toJson<int>(forwardJumpCount),
      'maxForwardJumpMs': serializer.toJson<int>(maxForwardJumpMs),
    };
  }

  ClockState copyWith({
    String? playerId,
    int? lastSeenAtMs,
    int? forwardJumpCount,
    int? maxForwardJumpMs,
  }) => ClockState(
    playerId: playerId ?? this.playerId,
    lastSeenAtMs: lastSeenAtMs ?? this.lastSeenAtMs,
    forwardJumpCount: forwardJumpCount ?? this.forwardJumpCount,
    maxForwardJumpMs: maxForwardJumpMs ?? this.maxForwardJumpMs,
  );
  ClockState copyWithCompanion(ClockStatesCompanion data) {
    return ClockState(
      playerId: data.playerId.present ? data.playerId.value : this.playerId,
      lastSeenAtMs: data.lastSeenAtMs.present
          ? data.lastSeenAtMs.value
          : this.lastSeenAtMs,
      forwardJumpCount: data.forwardJumpCount.present
          ? data.forwardJumpCount.value
          : this.forwardJumpCount,
      maxForwardJumpMs: data.maxForwardJumpMs.present
          ? data.maxForwardJumpMs.value
          : this.maxForwardJumpMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClockState(')
          ..write('playerId: $playerId, ')
          ..write('lastSeenAtMs: $lastSeenAtMs, ')
          ..write('forwardJumpCount: $forwardJumpCount, ')
          ..write('maxForwardJumpMs: $maxForwardJumpMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(playerId, lastSeenAtMs, forwardJumpCount, maxForwardJumpMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClockState &&
          other.playerId == this.playerId &&
          other.lastSeenAtMs == this.lastSeenAtMs &&
          other.forwardJumpCount == this.forwardJumpCount &&
          other.maxForwardJumpMs == this.maxForwardJumpMs);
}

class ClockStatesCompanion extends UpdateCompanion<ClockState> {
  final Value<String> playerId;
  final Value<int> lastSeenAtMs;
  final Value<int> forwardJumpCount;
  final Value<int> maxForwardJumpMs;
  final Value<int> rowid;
  const ClockStatesCompanion({
    this.playerId = const Value.absent(),
    this.lastSeenAtMs = const Value.absent(),
    this.forwardJumpCount = const Value.absent(),
    this.maxForwardJumpMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClockStatesCompanion.insert({
    required String playerId,
    this.lastSeenAtMs = const Value.absent(),
    this.forwardJumpCount = const Value.absent(),
    this.maxForwardJumpMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : playerId = Value(playerId);
  static Insertable<ClockState> custom({
    Expression<String>? playerId,
    Expression<int>? lastSeenAtMs,
    Expression<int>? forwardJumpCount,
    Expression<int>? maxForwardJumpMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playerId != null) 'player_id': playerId,
      if (lastSeenAtMs != null) 'last_seen_at_ms': lastSeenAtMs,
      if (forwardJumpCount != null) 'forward_jump_count': forwardJumpCount,
      if (maxForwardJumpMs != null) 'max_forward_jump_ms': maxForwardJumpMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClockStatesCompanion copyWith({
    Value<String>? playerId,
    Value<int>? lastSeenAtMs,
    Value<int>? forwardJumpCount,
    Value<int>? maxForwardJumpMs,
    Value<int>? rowid,
  }) {
    return ClockStatesCompanion(
      playerId: playerId ?? this.playerId,
      lastSeenAtMs: lastSeenAtMs ?? this.lastSeenAtMs,
      forwardJumpCount: forwardJumpCount ?? this.forwardJumpCount,
      maxForwardJumpMs: maxForwardJumpMs ?? this.maxForwardJumpMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playerId.present) {
      map['player_id'] = Variable<String>(playerId.value);
    }
    if (lastSeenAtMs.present) {
      map['last_seen_at_ms'] = Variable<int>(lastSeenAtMs.value);
    }
    if (forwardJumpCount.present) {
      map['forward_jump_count'] = Variable<int>(forwardJumpCount.value);
    }
    if (maxForwardJumpMs.present) {
      map['max_forward_jump_ms'] = Variable<int>(maxForwardJumpMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClockStatesCompanion(')
          ..write('playerId: $playerId, ')
          ..write('lastSeenAtMs: $lastSeenAtMs, ')
          ..write('forwardJumpCount: $forwardJumpCount, ')
          ..write('maxForwardJumpMs: $maxForwardJumpMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CurrenciesTable extends Currencies
    with TableInfo<$CurrenciesTable, Currency> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CurrenciesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playerIdMeta = const VerificationMeta(
    'playerId',
  );
  @override
  late final GeneratedColumn<String> playerId = GeneratedColumn<String>(
    'player_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES players (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _currencyIdMeta = const VerificationMeta(
    'currencyId',
  );
  @override
  late final GeneratedColumn<String> currencyId = GeneratedColumn<String>(
    'currency_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [playerId, currencyId, amount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'currencies';
  @override
  VerificationContext validateIntegrity(
    Insertable<Currency> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('player_id')) {
      context.handle(
        _playerIdMeta,
        playerId.isAcceptableOrUnknown(data['player_id']!, _playerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playerIdMeta);
    }
    if (data.containsKey('currency_id')) {
      context.handle(
        _currencyIdMeta,
        currencyId.isAcceptableOrUnknown(data['currency_id']!, _currencyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playerId, currencyId};
  @override
  Currency map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Currency(
      playerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_id'],
      )!,
      currencyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
    );
  }

  @override
  $CurrenciesTable createAlias(String alias) {
    return $CurrenciesTable(attachedDatabase, alias);
  }
}

class Currency extends DataClass implements Insertable<Currency> {
  final String playerId;
  final String currencyId;
  final int amount;
  const Currency({
    required this.playerId,
    required this.currencyId,
    required this.amount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['player_id'] = Variable<String>(playerId);
    map['currency_id'] = Variable<String>(currencyId);
    map['amount'] = Variable<int>(amount);
    return map;
  }

  CurrenciesCompanion toCompanion(bool nullToAbsent) {
    return CurrenciesCompanion(
      playerId: Value(playerId),
      currencyId: Value(currencyId),
      amount: Value(amount),
    );
  }

  factory Currency.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Currency(
      playerId: serializer.fromJson<String>(json['playerId']),
      currencyId: serializer.fromJson<String>(json['currencyId']),
      amount: serializer.fromJson<int>(json['amount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playerId': serializer.toJson<String>(playerId),
      'currencyId': serializer.toJson<String>(currencyId),
      'amount': serializer.toJson<int>(amount),
    };
  }

  Currency copyWith({String? playerId, String? currencyId, int? amount}) =>
      Currency(
        playerId: playerId ?? this.playerId,
        currencyId: currencyId ?? this.currencyId,
        amount: amount ?? this.amount,
      );
  Currency copyWithCompanion(CurrenciesCompanion data) {
    return Currency(
      playerId: data.playerId.present ? data.playerId.value : this.playerId,
      currencyId: data.currencyId.present
          ? data.currencyId.value
          : this.currencyId,
      amount: data.amount.present ? data.amount.value : this.amount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Currency(')
          ..write('playerId: $playerId, ')
          ..write('currencyId: $currencyId, ')
          ..write('amount: $amount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playerId, currencyId, amount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Currency &&
          other.playerId == this.playerId &&
          other.currencyId == this.currencyId &&
          other.amount == this.amount);
}

class CurrenciesCompanion extends UpdateCompanion<Currency> {
  final Value<String> playerId;
  final Value<String> currencyId;
  final Value<int> amount;
  final Value<int> rowid;
  const CurrenciesCompanion({
    this.playerId = const Value.absent(),
    this.currencyId = const Value.absent(),
    this.amount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CurrenciesCompanion.insert({
    required String playerId,
    required String currencyId,
    this.amount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : playerId = Value(playerId),
       currencyId = Value(currencyId);
  static Insertable<Currency> custom({
    Expression<String>? playerId,
    Expression<String>? currencyId,
    Expression<int>? amount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playerId != null) 'player_id': playerId,
      if (currencyId != null) 'currency_id': currencyId,
      if (amount != null) 'amount': amount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CurrenciesCompanion copyWith({
    Value<String>? playerId,
    Value<String>? currencyId,
    Value<int>? amount,
    Value<int>? rowid,
  }) {
    return CurrenciesCompanion(
      playerId: playerId ?? this.playerId,
      currencyId: currencyId ?? this.currencyId,
      amount: amount ?? this.amount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playerId.present) {
      map['player_id'] = Variable<String>(playerId.value);
    }
    if (currencyId.present) {
      map['currency_id'] = Variable<String>(currencyId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CurrenciesCompanion(')
          ..write('playerId: $playerId, ')
          ..write('currencyId: $currencyId, ')
          ..write('amount: $amount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PeriodicQuestStatesTable extends PeriodicQuestStates
    with TableInfo<$PeriodicQuestStatesTable, PeriodicQuestState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeriodicQuestStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playerIdMeta = const VerificationMeta(
    'playerId',
  );
  @override
  late final GeneratedColumn<String> playerId = GeneratedColumn<String>(
    'player_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES players (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _questIdMeta = const VerificationMeta(
    'questId',
  );
  @override
  late final GeneratedColumn<String> questId = GeneratedColumn<String>(
    'quest_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _periodKeyMeta = const VerificationMeta(
    'periodKey',
  );
  @override
  late final GeneratedColumn<String> periodKey = GeneratedColumn<String>(
    'period_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMsMeta = const VerificationMeta(
    'completedAtMs',
  );
  @override
  late final GeneratedColumn<int> completedAtMs = GeneratedColumn<int>(
    'completed_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    playerId,
    questId,
    periodKey,
    completedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'periodic_quest_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<PeriodicQuestState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('player_id')) {
      context.handle(
        _playerIdMeta,
        playerId.isAcceptableOrUnknown(data['player_id']!, _playerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playerIdMeta);
    }
    if (data.containsKey('quest_id')) {
      context.handle(
        _questIdMeta,
        questId.isAcceptableOrUnknown(data['quest_id']!, _questIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questIdMeta);
    }
    if (data.containsKey('period_key')) {
      context.handle(
        _periodKeyMeta,
        periodKey.isAcceptableOrUnknown(data['period_key']!, _periodKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_periodKeyMeta);
    }
    if (data.containsKey('completed_at_ms')) {
      context.handle(
        _completedAtMsMeta,
        completedAtMs.isAcceptableOrUnknown(
          data['completed_at_ms']!,
          _completedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playerId, questId, periodKey};
  @override
  PeriodicQuestState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PeriodicQuestState(
      playerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_id'],
      )!,
      questId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quest_id'],
      )!,
      periodKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period_key'],
      )!,
      completedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at_ms'],
      )!,
    );
  }

  @override
  $PeriodicQuestStatesTable createAlias(String alias) {
    return $PeriodicQuestStatesTable(attachedDatabase, alias);
  }
}

class PeriodicQuestState extends DataClass
    implements Insertable<PeriodicQuestState> {
  final String playerId;
  final String questId;
  final String periodKey;
  final int completedAtMs;
  const PeriodicQuestState({
    required this.playerId,
    required this.questId,
    required this.periodKey,
    required this.completedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['player_id'] = Variable<String>(playerId);
    map['quest_id'] = Variable<String>(questId);
    map['period_key'] = Variable<String>(periodKey);
    map['completed_at_ms'] = Variable<int>(completedAtMs);
    return map;
  }

  PeriodicQuestStatesCompanion toCompanion(bool nullToAbsent) {
    return PeriodicQuestStatesCompanion(
      playerId: Value(playerId),
      questId: Value(questId),
      periodKey: Value(periodKey),
      completedAtMs: Value(completedAtMs),
    );
  }

  factory PeriodicQuestState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PeriodicQuestState(
      playerId: serializer.fromJson<String>(json['playerId']),
      questId: serializer.fromJson<String>(json['questId']),
      periodKey: serializer.fromJson<String>(json['periodKey']),
      completedAtMs: serializer.fromJson<int>(json['completedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playerId': serializer.toJson<String>(playerId),
      'questId': serializer.toJson<String>(questId),
      'periodKey': serializer.toJson<String>(periodKey),
      'completedAtMs': serializer.toJson<int>(completedAtMs),
    };
  }

  PeriodicQuestState copyWith({
    String? playerId,
    String? questId,
    String? periodKey,
    int? completedAtMs,
  }) => PeriodicQuestState(
    playerId: playerId ?? this.playerId,
    questId: questId ?? this.questId,
    periodKey: periodKey ?? this.periodKey,
    completedAtMs: completedAtMs ?? this.completedAtMs,
  );
  PeriodicQuestState copyWithCompanion(PeriodicQuestStatesCompanion data) {
    return PeriodicQuestState(
      playerId: data.playerId.present ? data.playerId.value : this.playerId,
      questId: data.questId.present ? data.questId.value : this.questId,
      periodKey: data.periodKey.present ? data.periodKey.value : this.periodKey,
      completedAtMs: data.completedAtMs.present
          ? data.completedAtMs.value
          : this.completedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PeriodicQuestState(')
          ..write('playerId: $playerId, ')
          ..write('questId: $questId, ')
          ..write('periodKey: $periodKey, ')
          ..write('completedAtMs: $completedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playerId, questId, periodKey, completedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeriodicQuestState &&
          other.playerId == this.playerId &&
          other.questId == this.questId &&
          other.periodKey == this.periodKey &&
          other.completedAtMs == this.completedAtMs);
}

class PeriodicQuestStatesCompanion extends UpdateCompanion<PeriodicQuestState> {
  final Value<String> playerId;
  final Value<String> questId;
  final Value<String> periodKey;
  final Value<int> completedAtMs;
  final Value<int> rowid;
  const PeriodicQuestStatesCompanion({
    this.playerId = const Value.absent(),
    this.questId = const Value.absent(),
    this.periodKey = const Value.absent(),
    this.completedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PeriodicQuestStatesCompanion.insert({
    required String playerId,
    required String questId,
    required String periodKey,
    required int completedAtMs,
    this.rowid = const Value.absent(),
  }) : playerId = Value(playerId),
       questId = Value(questId),
       periodKey = Value(periodKey),
       completedAtMs = Value(completedAtMs);
  static Insertable<PeriodicQuestState> custom({
    Expression<String>? playerId,
    Expression<String>? questId,
    Expression<String>? periodKey,
    Expression<int>? completedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playerId != null) 'player_id': playerId,
      if (questId != null) 'quest_id': questId,
      if (periodKey != null) 'period_key': periodKey,
      if (completedAtMs != null) 'completed_at_ms': completedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PeriodicQuestStatesCompanion copyWith({
    Value<String>? playerId,
    Value<String>? questId,
    Value<String>? periodKey,
    Value<int>? completedAtMs,
    Value<int>? rowid,
  }) {
    return PeriodicQuestStatesCompanion(
      playerId: playerId ?? this.playerId,
      questId: questId ?? this.questId,
      periodKey: periodKey ?? this.periodKey,
      completedAtMs: completedAtMs ?? this.completedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playerId.present) {
      map['player_id'] = Variable<String>(playerId.value);
    }
    if (questId.present) {
      map['quest_id'] = Variable<String>(questId.value);
    }
    if (periodKey.present) {
      map['period_key'] = Variable<String>(periodKey.value);
    }
    if (completedAtMs.present) {
      map['completed_at_ms'] = Variable<int>(completedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeriodicQuestStatesCompanion(')
          ..write('playerId: $playerId, ')
          ..write('questId: $questId, ')
          ..write('periodKey: $periodKey, ')
          ..write('completedAtMs: $completedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EventShopPurchasesTable extends EventShopPurchases
    with TableInfo<$EventShopPurchasesTable, EventShopPurchase> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventShopPurchasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playerIdMeta = const VerificationMeta(
    'playerId',
  );
  @override
  late final GeneratedColumn<String> playerId = GeneratedColumn<String>(
    'player_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES players (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _periodKeyMeta = const VerificationMeta(
    'periodKey',
  );
  @override
  late final GeneratedColumn<String> periodKey = GeneratedColumn<String>(
    'period_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _purchasedCountMeta = const VerificationMeta(
    'purchasedCount',
  );
  @override
  late final GeneratedColumn<int> purchasedCount = GeneratedColumn<int>(
    'purchased_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    playerId,
    entryId,
    periodKey,
    purchasedCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'event_shop_purchases';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventShopPurchase> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('player_id')) {
      context.handle(
        _playerIdMeta,
        playerId.isAcceptableOrUnknown(data['player_id']!, _playerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playerIdMeta);
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('period_key')) {
      context.handle(
        _periodKeyMeta,
        periodKey.isAcceptableOrUnknown(data['period_key']!, _periodKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_periodKeyMeta);
    }
    if (data.containsKey('purchased_count')) {
      context.handle(
        _purchasedCountMeta,
        purchasedCount.isAcceptableOrUnknown(
          data['purchased_count']!,
          _purchasedCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playerId, entryId, periodKey};
  @override
  EventShopPurchase map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventShopPurchase(
      playerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_id'],
      )!,
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      periodKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}period_key'],
      )!,
      purchasedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}purchased_count'],
      )!,
    );
  }

  @override
  $EventShopPurchasesTable createAlias(String alias) {
    return $EventShopPurchasesTable(attachedDatabase, alias);
  }
}

class EventShopPurchase extends DataClass
    implements Insertable<EventShopPurchase> {
  final String playerId;
  final String entryId;
  final String periodKey;
  final int purchasedCount;
  const EventShopPurchase({
    required this.playerId,
    required this.entryId,
    required this.periodKey,
    required this.purchasedCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['player_id'] = Variable<String>(playerId);
    map['entry_id'] = Variable<String>(entryId);
    map['period_key'] = Variable<String>(periodKey);
    map['purchased_count'] = Variable<int>(purchasedCount);
    return map;
  }

  EventShopPurchasesCompanion toCompanion(bool nullToAbsent) {
    return EventShopPurchasesCompanion(
      playerId: Value(playerId),
      entryId: Value(entryId),
      periodKey: Value(periodKey),
      purchasedCount: Value(purchasedCount),
    );
  }

  factory EventShopPurchase.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventShopPurchase(
      playerId: serializer.fromJson<String>(json['playerId']),
      entryId: serializer.fromJson<String>(json['entryId']),
      periodKey: serializer.fromJson<String>(json['periodKey']),
      purchasedCount: serializer.fromJson<int>(json['purchasedCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playerId': serializer.toJson<String>(playerId),
      'entryId': serializer.toJson<String>(entryId),
      'periodKey': serializer.toJson<String>(periodKey),
      'purchasedCount': serializer.toJson<int>(purchasedCount),
    };
  }

  EventShopPurchase copyWith({
    String? playerId,
    String? entryId,
    String? periodKey,
    int? purchasedCount,
  }) => EventShopPurchase(
    playerId: playerId ?? this.playerId,
    entryId: entryId ?? this.entryId,
    periodKey: periodKey ?? this.periodKey,
    purchasedCount: purchasedCount ?? this.purchasedCount,
  );
  EventShopPurchase copyWithCompanion(EventShopPurchasesCompanion data) {
    return EventShopPurchase(
      playerId: data.playerId.present ? data.playerId.value : this.playerId,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      periodKey: data.periodKey.present ? data.periodKey.value : this.periodKey,
      purchasedCount: data.purchasedCount.present
          ? data.purchasedCount.value
          : this.purchasedCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventShopPurchase(')
          ..write('playerId: $playerId, ')
          ..write('entryId: $entryId, ')
          ..write('periodKey: $periodKey, ')
          ..write('purchasedCount: $purchasedCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playerId, entryId, periodKey, purchasedCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventShopPurchase &&
          other.playerId == this.playerId &&
          other.entryId == this.entryId &&
          other.periodKey == this.periodKey &&
          other.purchasedCount == this.purchasedCount);
}

class EventShopPurchasesCompanion extends UpdateCompanion<EventShopPurchase> {
  final Value<String> playerId;
  final Value<String> entryId;
  final Value<String> periodKey;
  final Value<int> purchasedCount;
  final Value<int> rowid;
  const EventShopPurchasesCompanion({
    this.playerId = const Value.absent(),
    this.entryId = const Value.absent(),
    this.periodKey = const Value.absent(),
    this.purchasedCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventShopPurchasesCompanion.insert({
    required String playerId,
    required String entryId,
    required String periodKey,
    this.purchasedCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : playerId = Value(playerId),
       entryId = Value(entryId),
       periodKey = Value(periodKey);
  static Insertable<EventShopPurchase> custom({
    Expression<String>? playerId,
    Expression<String>? entryId,
    Expression<String>? periodKey,
    Expression<int>? purchasedCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playerId != null) 'player_id': playerId,
      if (entryId != null) 'entry_id': entryId,
      if (periodKey != null) 'period_key': periodKey,
      if (purchasedCount != null) 'purchased_count': purchasedCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventShopPurchasesCompanion copyWith({
    Value<String>? playerId,
    Value<String>? entryId,
    Value<String>? periodKey,
    Value<int>? purchasedCount,
    Value<int>? rowid,
  }) {
    return EventShopPurchasesCompanion(
      playerId: playerId ?? this.playerId,
      entryId: entryId ?? this.entryId,
      periodKey: periodKey ?? this.periodKey,
      purchasedCount: purchasedCount ?? this.purchasedCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playerId.present) {
      map['player_id'] = Variable<String>(playerId.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (periodKey.present) {
      map['period_key'] = Variable<String>(periodKey.value);
    }
    if (purchasedCount.present) {
      map['purchased_count'] = Variable<int>(purchasedCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventShopPurchasesCompanion(')
          ..write('playerId: $playerId, ')
          ..write('entryId: $entryId, ')
          ..write('periodKey: $periodKey, ')
          ..write('purchasedCount: $purchasedCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CloudSyncStatesTable extends CloudSyncStates
    with TableInfo<$CloudSyncStatesTable, CloudSyncState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CloudSyncStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playerIdMeta = const VerificationMeta(
    'playerId',
  );
  @override
  late final GeneratedColumn<String> playerId = GeneratedColumn<String>(
    'player_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncedRevisionMeta =
      const VerificationMeta('lastSyncedRevision');
  @override
  late final GeneratedColumn<int> lastSyncedRevision = GeneratedColumn<int>(
    'last_synced_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSyncedBlobSha256Meta =
      const VerificationMeta('lastSyncedBlobSha256');
  @override
  late final GeneratedColumn<String> lastSyncedBlobSha256 =
      GeneratedColumn<String>(
        'last_synced_blob_sha256',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastSyncAtMsMeta = const VerificationMeta(
    'lastSyncAtMs',
  );
  @override
  late final GeneratedColumn<int> lastSyncAtMs = GeneratedColumn<int>(
    'last_sync_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastRejectCodeMeta = const VerificationMeta(
    'lastRejectCode',
  );
  @override
  late final GeneratedColumn<String> lastRejectCode = GeneratedColumn<String>(
    'last_reject_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastRejectAtMsMeta = const VerificationMeta(
    'lastRejectAtMs',
  );
  @override
  late final GeneratedColumn<int> lastRejectAtMs = GeneratedColumn<int>(
    'last_reject_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverOffsetMsMeta = const VerificationMeta(
    'serverOffsetMs',
  );
  @override
  late final GeneratedColumn<int> serverOffsetMs = GeneratedColumn<int>(
    'server_offset_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverOffsetAtMsMeta = const VerificationMeta(
    'serverOffsetAtMs',
  );
  @override
  late final GeneratedColumn<int> serverOffsetAtMs = GeneratedColumn<int>(
    'server_offset_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    playerId,
    deviceId,
    lastSyncedRevision,
    lastSyncedBlobSha256,
    lastSyncAtMs,
    lastRejectCode,
    lastRejectAtMs,
    serverOffsetMs,
    serverOffsetAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cloud_sync_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<CloudSyncState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('player_id')) {
      context.handle(
        _playerIdMeta,
        playerId.isAcceptableOrUnknown(data['player_id']!, _playerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playerIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('last_synced_revision')) {
      context.handle(
        _lastSyncedRevisionMeta,
        lastSyncedRevision.isAcceptableOrUnknown(
          data['last_synced_revision']!,
          _lastSyncedRevisionMeta,
        ),
      );
    }
    if (data.containsKey('last_synced_blob_sha256')) {
      context.handle(
        _lastSyncedBlobSha256Meta,
        lastSyncedBlobSha256.isAcceptableOrUnknown(
          data['last_synced_blob_sha256']!,
          _lastSyncedBlobSha256Meta,
        ),
      );
    }
    if (data.containsKey('last_sync_at_ms')) {
      context.handle(
        _lastSyncAtMsMeta,
        lastSyncAtMs.isAcceptableOrUnknown(
          data['last_sync_at_ms']!,
          _lastSyncAtMsMeta,
        ),
      );
    }
    if (data.containsKey('last_reject_code')) {
      context.handle(
        _lastRejectCodeMeta,
        lastRejectCode.isAcceptableOrUnknown(
          data['last_reject_code']!,
          _lastRejectCodeMeta,
        ),
      );
    }
    if (data.containsKey('last_reject_at_ms')) {
      context.handle(
        _lastRejectAtMsMeta,
        lastRejectAtMs.isAcceptableOrUnknown(
          data['last_reject_at_ms']!,
          _lastRejectAtMsMeta,
        ),
      );
    }
    if (data.containsKey('server_offset_ms')) {
      context.handle(
        _serverOffsetMsMeta,
        serverOffsetMs.isAcceptableOrUnknown(
          data['server_offset_ms']!,
          _serverOffsetMsMeta,
        ),
      );
    }
    if (data.containsKey('server_offset_at_ms')) {
      context.handle(
        _serverOffsetAtMsMeta,
        serverOffsetAtMs.isAcceptableOrUnknown(
          data['server_offset_at_ms']!,
          _serverOffsetAtMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playerId};
  @override
  CloudSyncState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CloudSyncState(
      playerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      lastSyncedRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_synced_revision'],
      )!,
      lastSyncedBlobSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_synced_blob_sha256'],
      ),
      lastSyncAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_sync_at_ms'],
      ),
      lastRejectCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_reject_code'],
      ),
      lastRejectAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_reject_at_ms'],
      ),
      serverOffsetMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_offset_ms'],
      ),
      serverOffsetAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_offset_at_ms'],
      ),
    );
  }

  @override
  $CloudSyncStatesTable createAlias(String alias) {
    return $CloudSyncStatesTable(attachedDatabase, alias);
  }
}

class CloudSyncState extends DataClass implements Insertable<CloudSyncState> {
  final String playerId;
  final String deviceId;
  final int lastSyncedRevision;
  final String? lastSyncedBlobSha256;
  final int? lastSyncAtMs;
  final String? lastRejectCode;
  final int? lastRejectAtMs;
  final int? serverOffsetMs;
  final int? serverOffsetAtMs;
  const CloudSyncState({
    required this.playerId,
    required this.deviceId,
    required this.lastSyncedRevision,
    this.lastSyncedBlobSha256,
    this.lastSyncAtMs,
    this.lastRejectCode,
    this.lastRejectAtMs,
    this.serverOffsetMs,
    this.serverOffsetAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['player_id'] = Variable<String>(playerId);
    map['device_id'] = Variable<String>(deviceId);
    map['last_synced_revision'] = Variable<int>(lastSyncedRevision);
    if (!nullToAbsent || lastSyncedBlobSha256 != null) {
      map['last_synced_blob_sha256'] = Variable<String>(lastSyncedBlobSha256);
    }
    if (!nullToAbsent || lastSyncAtMs != null) {
      map['last_sync_at_ms'] = Variable<int>(lastSyncAtMs);
    }
    if (!nullToAbsent || lastRejectCode != null) {
      map['last_reject_code'] = Variable<String>(lastRejectCode);
    }
    if (!nullToAbsent || lastRejectAtMs != null) {
      map['last_reject_at_ms'] = Variable<int>(lastRejectAtMs);
    }
    if (!nullToAbsent || serverOffsetMs != null) {
      map['server_offset_ms'] = Variable<int>(serverOffsetMs);
    }
    if (!nullToAbsent || serverOffsetAtMs != null) {
      map['server_offset_at_ms'] = Variable<int>(serverOffsetAtMs);
    }
    return map;
  }

  CloudSyncStatesCompanion toCompanion(bool nullToAbsent) {
    return CloudSyncStatesCompanion(
      playerId: Value(playerId),
      deviceId: Value(deviceId),
      lastSyncedRevision: Value(lastSyncedRevision),
      lastSyncedBlobSha256: lastSyncedBlobSha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedBlobSha256),
      lastSyncAtMs: lastSyncAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncAtMs),
      lastRejectCode: lastRejectCode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastRejectCode),
      lastRejectAtMs: lastRejectAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(lastRejectAtMs),
      serverOffsetMs: serverOffsetMs == null && nullToAbsent
          ? const Value.absent()
          : Value(serverOffsetMs),
      serverOffsetAtMs: serverOffsetAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(serverOffsetAtMs),
    );
  }

  factory CloudSyncState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CloudSyncState(
      playerId: serializer.fromJson<String>(json['playerId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      lastSyncedRevision: serializer.fromJson<int>(json['lastSyncedRevision']),
      lastSyncedBlobSha256: serializer.fromJson<String?>(
        json['lastSyncedBlobSha256'],
      ),
      lastSyncAtMs: serializer.fromJson<int?>(json['lastSyncAtMs']),
      lastRejectCode: serializer.fromJson<String?>(json['lastRejectCode']),
      lastRejectAtMs: serializer.fromJson<int?>(json['lastRejectAtMs']),
      serverOffsetMs: serializer.fromJson<int?>(json['serverOffsetMs']),
      serverOffsetAtMs: serializer.fromJson<int?>(json['serverOffsetAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playerId': serializer.toJson<String>(playerId),
      'deviceId': serializer.toJson<String>(deviceId),
      'lastSyncedRevision': serializer.toJson<int>(lastSyncedRevision),
      'lastSyncedBlobSha256': serializer.toJson<String?>(lastSyncedBlobSha256),
      'lastSyncAtMs': serializer.toJson<int?>(lastSyncAtMs),
      'lastRejectCode': serializer.toJson<String?>(lastRejectCode),
      'lastRejectAtMs': serializer.toJson<int?>(lastRejectAtMs),
      'serverOffsetMs': serializer.toJson<int?>(serverOffsetMs),
      'serverOffsetAtMs': serializer.toJson<int?>(serverOffsetAtMs),
    };
  }

  CloudSyncState copyWith({
    String? playerId,
    String? deviceId,
    int? lastSyncedRevision,
    Value<String?> lastSyncedBlobSha256 = const Value.absent(),
    Value<int?> lastSyncAtMs = const Value.absent(),
    Value<String?> lastRejectCode = const Value.absent(),
    Value<int?> lastRejectAtMs = const Value.absent(),
    Value<int?> serverOffsetMs = const Value.absent(),
    Value<int?> serverOffsetAtMs = const Value.absent(),
  }) => CloudSyncState(
    playerId: playerId ?? this.playerId,
    deviceId: deviceId ?? this.deviceId,
    lastSyncedRevision: lastSyncedRevision ?? this.lastSyncedRevision,
    lastSyncedBlobSha256: lastSyncedBlobSha256.present
        ? lastSyncedBlobSha256.value
        : this.lastSyncedBlobSha256,
    lastSyncAtMs: lastSyncAtMs.present ? lastSyncAtMs.value : this.lastSyncAtMs,
    lastRejectCode: lastRejectCode.present
        ? lastRejectCode.value
        : this.lastRejectCode,
    lastRejectAtMs: lastRejectAtMs.present
        ? lastRejectAtMs.value
        : this.lastRejectAtMs,
    serverOffsetMs: serverOffsetMs.present
        ? serverOffsetMs.value
        : this.serverOffsetMs,
    serverOffsetAtMs: serverOffsetAtMs.present
        ? serverOffsetAtMs.value
        : this.serverOffsetAtMs,
  );
  CloudSyncState copyWithCompanion(CloudSyncStatesCompanion data) {
    return CloudSyncState(
      playerId: data.playerId.present ? data.playerId.value : this.playerId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      lastSyncedRevision: data.lastSyncedRevision.present
          ? data.lastSyncedRevision.value
          : this.lastSyncedRevision,
      lastSyncedBlobSha256: data.lastSyncedBlobSha256.present
          ? data.lastSyncedBlobSha256.value
          : this.lastSyncedBlobSha256,
      lastSyncAtMs: data.lastSyncAtMs.present
          ? data.lastSyncAtMs.value
          : this.lastSyncAtMs,
      lastRejectCode: data.lastRejectCode.present
          ? data.lastRejectCode.value
          : this.lastRejectCode,
      lastRejectAtMs: data.lastRejectAtMs.present
          ? data.lastRejectAtMs.value
          : this.lastRejectAtMs,
      serverOffsetMs: data.serverOffsetMs.present
          ? data.serverOffsetMs.value
          : this.serverOffsetMs,
      serverOffsetAtMs: data.serverOffsetAtMs.present
          ? data.serverOffsetAtMs.value
          : this.serverOffsetAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CloudSyncState(')
          ..write('playerId: $playerId, ')
          ..write('deviceId: $deviceId, ')
          ..write('lastSyncedRevision: $lastSyncedRevision, ')
          ..write('lastSyncedBlobSha256: $lastSyncedBlobSha256, ')
          ..write('lastSyncAtMs: $lastSyncAtMs, ')
          ..write('lastRejectCode: $lastRejectCode, ')
          ..write('lastRejectAtMs: $lastRejectAtMs, ')
          ..write('serverOffsetMs: $serverOffsetMs, ')
          ..write('serverOffsetAtMs: $serverOffsetAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    playerId,
    deviceId,
    lastSyncedRevision,
    lastSyncedBlobSha256,
    lastSyncAtMs,
    lastRejectCode,
    lastRejectAtMs,
    serverOffsetMs,
    serverOffsetAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CloudSyncState &&
          other.playerId == this.playerId &&
          other.deviceId == this.deviceId &&
          other.lastSyncedRevision == this.lastSyncedRevision &&
          other.lastSyncedBlobSha256 == this.lastSyncedBlobSha256 &&
          other.lastSyncAtMs == this.lastSyncAtMs &&
          other.lastRejectCode == this.lastRejectCode &&
          other.lastRejectAtMs == this.lastRejectAtMs &&
          other.serverOffsetMs == this.serverOffsetMs &&
          other.serverOffsetAtMs == this.serverOffsetAtMs);
}

class CloudSyncStatesCompanion extends UpdateCompanion<CloudSyncState> {
  final Value<String> playerId;
  final Value<String> deviceId;
  final Value<int> lastSyncedRevision;
  final Value<String?> lastSyncedBlobSha256;
  final Value<int?> lastSyncAtMs;
  final Value<String?> lastRejectCode;
  final Value<int?> lastRejectAtMs;
  final Value<int?> serverOffsetMs;
  final Value<int?> serverOffsetAtMs;
  final Value<int> rowid;
  const CloudSyncStatesCompanion({
    this.playerId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.lastSyncedRevision = const Value.absent(),
    this.lastSyncedBlobSha256 = const Value.absent(),
    this.lastSyncAtMs = const Value.absent(),
    this.lastRejectCode = const Value.absent(),
    this.lastRejectAtMs = const Value.absent(),
    this.serverOffsetMs = const Value.absent(),
    this.serverOffsetAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CloudSyncStatesCompanion.insert({
    required String playerId,
    required String deviceId,
    this.lastSyncedRevision = const Value.absent(),
    this.lastSyncedBlobSha256 = const Value.absent(),
    this.lastSyncAtMs = const Value.absent(),
    this.lastRejectCode = const Value.absent(),
    this.lastRejectAtMs = const Value.absent(),
    this.serverOffsetMs = const Value.absent(),
    this.serverOffsetAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : playerId = Value(playerId),
       deviceId = Value(deviceId);
  static Insertable<CloudSyncState> custom({
    Expression<String>? playerId,
    Expression<String>? deviceId,
    Expression<int>? lastSyncedRevision,
    Expression<String>? lastSyncedBlobSha256,
    Expression<int>? lastSyncAtMs,
    Expression<String>? lastRejectCode,
    Expression<int>? lastRejectAtMs,
    Expression<int>? serverOffsetMs,
    Expression<int>? serverOffsetAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playerId != null) 'player_id': playerId,
      if (deviceId != null) 'device_id': deviceId,
      if (lastSyncedRevision != null)
        'last_synced_revision': lastSyncedRevision,
      if (lastSyncedBlobSha256 != null)
        'last_synced_blob_sha256': lastSyncedBlobSha256,
      if (lastSyncAtMs != null) 'last_sync_at_ms': lastSyncAtMs,
      if (lastRejectCode != null) 'last_reject_code': lastRejectCode,
      if (lastRejectAtMs != null) 'last_reject_at_ms': lastRejectAtMs,
      if (serverOffsetMs != null) 'server_offset_ms': serverOffsetMs,
      if (serverOffsetAtMs != null) 'server_offset_at_ms': serverOffsetAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CloudSyncStatesCompanion copyWith({
    Value<String>? playerId,
    Value<String>? deviceId,
    Value<int>? lastSyncedRevision,
    Value<String?>? lastSyncedBlobSha256,
    Value<int?>? lastSyncAtMs,
    Value<String?>? lastRejectCode,
    Value<int?>? lastRejectAtMs,
    Value<int?>? serverOffsetMs,
    Value<int?>? serverOffsetAtMs,
    Value<int>? rowid,
  }) {
    return CloudSyncStatesCompanion(
      playerId: playerId ?? this.playerId,
      deviceId: deviceId ?? this.deviceId,
      lastSyncedRevision: lastSyncedRevision ?? this.lastSyncedRevision,
      lastSyncedBlobSha256: lastSyncedBlobSha256 ?? this.lastSyncedBlobSha256,
      lastSyncAtMs: lastSyncAtMs ?? this.lastSyncAtMs,
      lastRejectCode: lastRejectCode ?? this.lastRejectCode,
      lastRejectAtMs: lastRejectAtMs ?? this.lastRejectAtMs,
      serverOffsetMs: serverOffsetMs ?? this.serverOffsetMs,
      serverOffsetAtMs: serverOffsetAtMs ?? this.serverOffsetAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playerId.present) {
      map['player_id'] = Variable<String>(playerId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (lastSyncedRevision.present) {
      map['last_synced_revision'] = Variable<int>(lastSyncedRevision.value);
    }
    if (lastSyncedBlobSha256.present) {
      map['last_synced_blob_sha256'] = Variable<String>(
        lastSyncedBlobSha256.value,
      );
    }
    if (lastSyncAtMs.present) {
      map['last_sync_at_ms'] = Variable<int>(lastSyncAtMs.value);
    }
    if (lastRejectCode.present) {
      map['last_reject_code'] = Variable<String>(lastRejectCode.value);
    }
    if (lastRejectAtMs.present) {
      map['last_reject_at_ms'] = Variable<int>(lastRejectAtMs.value);
    }
    if (serverOffsetMs.present) {
      map['server_offset_ms'] = Variable<int>(serverOffsetMs.value);
    }
    if (serverOffsetAtMs.present) {
      map['server_offset_at_ms'] = Variable<int>(serverOffsetAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CloudSyncStatesCompanion(')
          ..write('playerId: $playerId, ')
          ..write('deviceId: $deviceId, ')
          ..write('lastSyncedRevision: $lastSyncedRevision, ')
          ..write('lastSyncedBlobSha256: $lastSyncedBlobSha256, ')
          ..write('lastSyncAtMs: $lastSyncAtMs, ')
          ..write('lastRejectCode: $lastRejectCode, ')
          ..write('lastRejectAtMs: $lastRejectAtMs, ')
          ..write('serverOffsetMs: $serverOffsetMs, ')
          ..write('serverOffsetAtMs: $serverOffsetAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSaveBackupsTable extends LocalSaveBackups
    with TableInfo<$LocalSaveBackupsTable, LocalSaveBackup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSaveBackupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  @override
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
    'schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _blobSha256Meta = const VerificationMeta(
    'blobSha256',
  );
  @override
  late final GeneratedColumn<String> blobSha256 = GeneratedColumn<String>(
    'blob_sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<Uint8List> payload = GeneratedColumn<Uint8List>(
    'blob',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAtMs,
    reason,
    schemaVersion,
    blobSha256,
    payload,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_save_backups';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSaveBackup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schemaVersionMeta);
    }
    if (data.containsKey('blob_sha256')) {
      context.handle(
        _blobSha256Meta,
        blobSha256.isAcceptableOrUnknown(data['blob_sha256']!, _blobSha256Meta),
      );
    } else if (isInserting) {
      context.missing(_blobSha256Meta);
    }
    if (data.containsKey('blob')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['blob']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSaveBackup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSaveBackup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_version'],
      )!,
      blobSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blob_sha256'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}blob'],
      )!,
    );
  }

  @override
  $LocalSaveBackupsTable createAlias(String alias) {
    return $LocalSaveBackupsTable(attachedDatabase, alias);
  }
}

class LocalSaveBackup extends DataClass implements Insertable<LocalSaveBackup> {
  final int id;
  final int createdAtMs;
  final String reason;
  final int schemaVersion;
  final String blobSha256;
  final Uint8List payload;
  const LocalSaveBackup({
    required this.id,
    required this.createdAtMs,
    required this.reason,
    required this.schemaVersion,
    required this.blobSha256,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['reason'] = Variable<String>(reason);
    map['schema_version'] = Variable<int>(schemaVersion);
    map['blob_sha256'] = Variable<String>(blobSha256);
    map['blob'] = Variable<Uint8List>(payload);
    return map;
  }

  LocalSaveBackupsCompanion toCompanion(bool nullToAbsent) {
    return LocalSaveBackupsCompanion(
      id: Value(id),
      createdAtMs: Value(createdAtMs),
      reason: Value(reason),
      schemaVersion: Value(schemaVersion),
      blobSha256: Value(blobSha256),
      payload: Value(payload),
    );
  }

  factory LocalSaveBackup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSaveBackup(
      id: serializer.fromJson<int>(json['id']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      reason: serializer.fromJson<String>(json['reason']),
      schemaVersion: serializer.fromJson<int>(json['schemaVersion']),
      blobSha256: serializer.fromJson<String>(json['blobSha256']),
      payload: serializer.fromJson<Uint8List>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'reason': serializer.toJson<String>(reason),
      'schemaVersion': serializer.toJson<int>(schemaVersion),
      'blobSha256': serializer.toJson<String>(blobSha256),
      'payload': serializer.toJson<Uint8List>(payload),
    };
  }

  LocalSaveBackup copyWith({
    int? id,
    int? createdAtMs,
    String? reason,
    int? schemaVersion,
    String? blobSha256,
    Uint8List? payload,
  }) => LocalSaveBackup(
    id: id ?? this.id,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    reason: reason ?? this.reason,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    blobSha256: blobSha256 ?? this.blobSha256,
    payload: payload ?? this.payload,
  );
  LocalSaveBackup copyWithCompanion(LocalSaveBackupsCompanion data) {
    return LocalSaveBackup(
      id: data.id.present ? data.id.value : this.id,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      reason: data.reason.present ? data.reason.value : this.reason,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      blobSha256: data.blobSha256.present
          ? data.blobSha256.value
          : this.blobSha256,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSaveBackup(')
          ..write('id: $id, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('reason: $reason, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('blobSha256: $blobSha256, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAtMs,
    reason,
    schemaVersion,
    blobSha256,
    $driftBlobEquality.hash(payload),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSaveBackup &&
          other.id == this.id &&
          other.createdAtMs == this.createdAtMs &&
          other.reason == this.reason &&
          other.schemaVersion == this.schemaVersion &&
          other.blobSha256 == this.blobSha256 &&
          $driftBlobEquality.equals(other.payload, this.payload));
}

class LocalSaveBackupsCompanion extends UpdateCompanion<LocalSaveBackup> {
  final Value<int> id;
  final Value<int> createdAtMs;
  final Value<String> reason;
  final Value<int> schemaVersion;
  final Value<String> blobSha256;
  final Value<Uint8List> payload;
  const LocalSaveBackupsCompanion({
    this.id = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.reason = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.blobSha256 = const Value.absent(),
    this.payload = const Value.absent(),
  });
  LocalSaveBackupsCompanion.insert({
    this.id = const Value.absent(),
    required int createdAtMs,
    required String reason,
    required int schemaVersion,
    required String blobSha256,
    required Uint8List payload,
  }) : createdAtMs = Value(createdAtMs),
       reason = Value(reason),
       schemaVersion = Value(schemaVersion),
       blobSha256 = Value(blobSha256),
       payload = Value(payload);
  static Insertable<LocalSaveBackup> custom({
    Expression<int>? id,
    Expression<int>? createdAtMs,
    Expression<String>? reason,
    Expression<int>? schemaVersion,
    Expression<String>? blobSha256,
    Expression<Uint8List>? payload,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (reason != null) 'reason': reason,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (blobSha256 != null) 'blob_sha256': blobSha256,
      if (payload != null) 'blob': payload,
    });
  }

  LocalSaveBackupsCompanion copyWith({
    Value<int>? id,
    Value<int>? createdAtMs,
    Value<String>? reason,
    Value<int>? schemaVersion,
    Value<String>? blobSha256,
    Value<Uint8List>? payload,
  }) {
    return LocalSaveBackupsCompanion(
      id: id ?? this.id,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      reason: reason ?? this.reason,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      blobSha256: blobSha256 ?? this.blobSha256,
      payload: payload ?? this.payload,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (blobSha256.present) {
      map['blob_sha256'] = Variable<String>(blobSha256.value);
    }
    if (payload.present) {
      map['blob'] = Variable<Uint8List>(payload.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSaveBackupsCompanion(')
          ..write('id: $id, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('reason: $reason, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('blobSha256: $blobSha256, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $GameSettingsTable gameSettings = $GameSettingsTable(this);
  late final $PlayersTable players = $PlayersTable(this);
  late final $SkillProgressesTable skillProgresses = $SkillProgressesTable(
    this,
  );
  late final $InventoryEntriesTable inventoryEntries = $InventoryEntriesTable(
    this,
  );
  late final $EquipmentInstancesTable equipmentInstances =
      $EquipmentInstancesTable(this);
  late final $EquippedItemsTable equippedItems = $EquippedItemsTable(this);
  late final $DungeonProgressesTable dungeonProgresses =
      $DungeonProgressesTable(this);
  late final $CycleProgressesTable cycleProgresses = $CycleProgressesTable(
    this,
  );
  late final $GameSessionsTable gameSessions = $GameSessionsTable(this);
  late final $ClaimedRewardsTable claimedRewards = $ClaimedRewardsTable(this);
  late final $ShopPurchasesTable shopPurchases = $ShopPurchasesTable(this);
  late final $ClockStatesTable clockStates = $ClockStatesTable(this);
  late final $CurrenciesTable currencies = $CurrenciesTable(this);
  late final $PeriodicQuestStatesTable periodicQuestStates =
      $PeriodicQuestStatesTable(this);
  late final $EventShopPurchasesTable eventShopPurchases =
      $EventShopPurchasesTable(this);
  late final $CloudSyncStatesTable cloudSyncStates = $CloudSyncStatesTable(
    this,
  );
  late final $LocalSaveBackupsTable localSaveBackups = $LocalSaveBackupsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    gameSettings,
    players,
    skillProgresses,
    inventoryEntries,
    equipmentInstances,
    equippedItems,
    dungeonProgresses,
    cycleProgresses,
    gameSessions,
    claimedRewards,
    shopPurchases,
    clockStates,
    currencies,
    periodicQuestStates,
    eventShopPurchases,
    cloudSyncStates,
    localSaveBackups,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'players',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('skill_progresses', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'players',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('inventory_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'players',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('equipment_instances', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'players',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('equipped_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'players',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('dungeon_progresses', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'players',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('cycle_progresses', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'players',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('game_sessions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'players',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('claimed_rewards', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'players',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('shop_purchases', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'players',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('clock_states', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'players',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('currencies', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'players',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('periodic_quest_states', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'players',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('event_shop_purchases', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$GameSettingsTableCreateCompanionBuilder =
    GameSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$GameSettingsTableUpdateCompanionBuilder =
    GameSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$GameSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $GameSettingsTable> {
  $$GameSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GameSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $GameSettingsTable> {
  $$GameSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GameSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GameSettingsTable> {
  $$GameSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$GameSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GameSettingsTable,
          GameSetting,
          $$GameSettingsTableFilterComposer,
          $$GameSettingsTableOrderingComposer,
          $$GameSettingsTableAnnotationComposer,
          $$GameSettingsTableCreateCompanionBuilder,
          $$GameSettingsTableUpdateCompanionBuilder,
          (
            GameSetting,
            BaseReferences<_$AppDatabase, $GameSettingsTable, GameSetting>,
          ),
          GameSetting,
          PrefetchHooks Function()
        > {
  $$GameSettingsTableTableManager(_$AppDatabase db, $GameSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GameSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GameSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GameSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => GameSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => GameSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GameSettingsTable, GameSetting>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $GameSettingsTable,
                    GameSetting
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GameSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GameSettingsTable,
      GameSetting,
      $$GameSettingsTableFilterComposer,
      $$GameSettingsTableOrderingComposer,
      $$GameSettingsTableAnnotationComposer,
      $$GameSettingsTableCreateCompanionBuilder,
      $$GameSettingsTableUpdateCompanionBuilder,
      (
        GameSetting,
        BaseReferences<_$AppDatabase, $GameSettingsTable, GameSetting>,
      ),
      GameSetting,
      PrefetchHooks Function()
    >;
typedef $$PlayersTableCreateCompanionBuilder = PlayersCompanion Function({
  required String id,
  required int level,
  required int currentExp,
  required int gold,
  Value<int?> currentHp,
  Value<String?> activeSpecializationId,
  required String baseStatsJson,
  Value<int> equipmentCounter,
  required int lastSavedAtMs,
  Value<int> rowid,
});
typedef $$PlayersTableUpdateCompanionBuilder = PlayersCompanion Function({
  Value<String> id,
  Value<int> level,
  Value<int> currentExp,
  Value<int> gold,
  Value<int?> currentHp,
  Value<String?> activeSpecializationId,
  Value<String> baseStatsJson,
  Value<int> equipmentCounter,
  Value<int> lastSavedAtMs,
  Value<int> rowid,
});

final class $$PlayersTableReferences
    extends BaseReferences<_$AppDatabase, $PlayersTable, Player> {
  $$PlayersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SkillProgressesTable, List<SkillProgressesData>>
  _skillProgressesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.skillProgresses,
    aliasName: 'players__id__skill_progresses__player_id',
  );

  $$SkillProgressesTableProcessedTableManager get skillProgressesRefs {
    final manager = $$SkillProgressesTableTableManager(
      $_db,
      $_db.skillProgresses,
    ).filter((f) => f.playerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _skillProgressesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$InventoryEntriesTable, List<InventoryEntry>>
  _inventoryEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.inventoryEntries,
    aliasName: 'players__id__inventory_entries__player_id',
  );

  $$InventoryEntriesTableProcessedTableManager get inventoryEntriesRefs {
    final manager = $$InventoryEntriesTableTableManager(
      $_db,
      $_db.inventoryEntries,
    ).filter((f) => f.playerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _inventoryEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $EquipmentInstancesTable,
    List<EquipmentInstanceRow>
  >
  _equipmentInstancesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.equipmentInstances,
        aliasName: 'players__id__equipment_instances__player_id',
      );

  $$EquipmentInstancesTableProcessedTableManager get equipmentInstancesRefs {
    final manager = $$EquipmentInstancesTableTableManager(
      $_db,
      $_db.equipmentInstances,
    ).filter((f) => f.playerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _equipmentInstancesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EquippedItemsTable, List<EquippedItem>>
  _equippedItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.equippedItems,
    aliasName: 'players__id__equipped_items__player_id',
  );

  $$EquippedItemsTableProcessedTableManager get equippedItemsRefs {
    final manager = $$EquippedItemsTableTableManager(
      $_db,
      $_db.equippedItems,
    ).filter((f) => f.playerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_equippedItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $DungeonProgressesTable,
    List<DungeonProgressesData>
  >
  _dungeonProgressesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.dungeonProgresses,
        aliasName: 'players__id__dungeon_progresses__player_id',
      );

  $$DungeonProgressesTableProcessedTableManager get dungeonProgressesRefs {
    final manager = $$DungeonProgressesTableTableManager(
      $_db,
      $_db.dungeonProgresses,
    ).filter((f) => f.playerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _dungeonProgressesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CycleProgressesTable, List<CycleProgressesData>>
  _cycleProgressesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cycleProgresses,
    aliasName: 'players__id__cycle_progresses__player_id',
  );

  $$CycleProgressesTableProcessedTableManager get cycleProgressesRefs {
    final manager = $$CycleProgressesTableTableManager(
      $_db,
      $_db.cycleProgresses,
    ).filter((f) => f.playerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _cycleProgressesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$GameSessionsTable, List<GameSession>>
  _gameSessionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.gameSessions,
    aliasName: 'players__id__game_sessions__player_id',
  );

  $$GameSessionsTableProcessedTableManager get gameSessionsRefs {
    final manager = $$GameSessionsTableTableManager(
      $_db,
      $_db.gameSessions,
    ).filter((f) => f.playerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_gameSessionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ClaimedRewardsTable, List<ClaimedReward>>
  _claimedRewardsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.claimedRewards,
    aliasName: 'players__id__claimed_rewards__player_id',
  );

  $$ClaimedRewardsTableProcessedTableManager get claimedRewardsRefs {
    final manager = $$ClaimedRewardsTableTableManager(
      $_db,
      $_db.claimedRewards,
    ).filter((f) => f.playerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_claimedRewardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ShopPurchasesTable, List<ShopPurchase>>
  _shopPurchasesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.shopPurchases,
    aliasName: 'players__id__shop_purchases__player_id',
  );

  $$ShopPurchasesTableProcessedTableManager get shopPurchasesRefs {
    final manager = $$ShopPurchasesTableTableManager(
      $_db,
      $_db.shopPurchases,
    ).filter((f) => f.playerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_shopPurchasesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ClockStatesTable, List<ClockState>>
  _clockStatesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.clockStates,
    aliasName: 'players__id__clock_states__player_id',
  );

  $$ClockStatesTableProcessedTableManager get clockStatesRefs {
    final manager = $$ClockStatesTableTableManager(
      $_db,
      $_db.clockStates,
    ).filter((f) => f.playerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_clockStatesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CurrenciesTable, List<Currency>>
  _currenciesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.currencies,
    aliasName: 'players__id__currencies__player_id',
  );

  $$CurrenciesTableProcessedTableManager get currenciesRefs {
    final manager = $$CurrenciesTableTableManager(
      $_db,
      $_db.currencies,
    ).filter((f) => f.playerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_currenciesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $PeriodicQuestStatesTable,
    List<PeriodicQuestState>
  >
  _periodicQuestStatesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.periodicQuestStates,
        aliasName: 'players__id__periodic_quest_states__player_id',
      );

  $$PeriodicQuestStatesTableProcessedTableManager get periodicQuestStatesRefs {
    final manager = $$PeriodicQuestStatesTableTableManager(
      $_db,
      $_db.periodicQuestStates,
    ).filter((f) => f.playerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _periodicQuestStatesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EventShopPurchasesTable, List<EventShopPurchase>>
  _eventShopPurchasesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.eventShopPurchases,
        aliasName: 'players__id__event_shop_purchases__player_id',
      );

  $$EventShopPurchasesTableProcessedTableManager get eventShopPurchasesRefs {
    final manager = $$EventShopPurchasesTableTableManager(
      $_db,
      $_db.eventShopPurchases,
    ).filter((f) => f.playerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _eventShopPurchasesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlayersTableFilterComposer
    extends Composer<_$AppDatabase, $PlayersTable> {
  $$PlayersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentExp => $composableBuilder(
    column: $table.currentExp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gold => $composableBuilder(
    column: $table.gold,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentHp => $composableBuilder(
    column: $table.currentHp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activeSpecializationId => $composableBuilder(
    column: $table.activeSpecializationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseStatsJson => $composableBuilder(
    column: $table.baseStatsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get equipmentCounter => $composableBuilder(
    column: $table.equipmentCounter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSavedAtMs => $composableBuilder(
    column: $table.lastSavedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> skillProgressesRefs(
    Expression<bool> Function($$SkillProgressesTableFilterComposer f) f,
  ) {
    final $$SkillProgressesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.skillProgresses,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SkillProgressesTableFilterComposer(
            $db: $db,
            $table: $db.skillProgresses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> inventoryEntriesRefs(
    Expression<bool> Function($$InventoryEntriesTableFilterComposer f) f,
  ) {
    final $$InventoryEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.inventoryEntries,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InventoryEntriesTableFilterComposer(
            $db: $db,
            $table: $db.inventoryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> equipmentInstancesRefs(
    Expression<bool> Function($$EquipmentInstancesTableFilterComposer f) f,
  ) {
    final $$EquipmentInstancesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.equipmentInstances,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquipmentInstancesTableFilterComposer(
            $db: $db,
            $table: $db.equipmentInstances,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> equippedItemsRefs(
    Expression<bool> Function($$EquippedItemsTableFilterComposer f) f,
  ) {
    final $$EquippedItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.equippedItems,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquippedItemsTableFilterComposer(
            $db: $db,
            $table: $db.equippedItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> dungeonProgressesRefs(
    Expression<bool> Function($$DungeonProgressesTableFilterComposer f) f,
  ) {
    final $$DungeonProgressesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dungeonProgresses,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DungeonProgressesTableFilterComposer(
            $db: $db,
            $table: $db.dungeonProgresses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cycleProgressesRefs(
    Expression<bool> Function($$CycleProgressesTableFilterComposer f) f,
  ) {
    final $$CycleProgressesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cycleProgresses,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CycleProgressesTableFilterComposer(
            $db: $db,
            $table: $db.cycleProgresses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> gameSessionsRefs(
    Expression<bool> Function($$GameSessionsTableFilterComposer f) f,
  ) {
    final $$GameSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gameSessions,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GameSessionsTableFilterComposer(
            $db: $db,
            $table: $db.gameSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> claimedRewardsRefs(
    Expression<bool> Function($$ClaimedRewardsTableFilterComposer f) f,
  ) {
    final $$ClaimedRewardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.claimedRewards,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClaimedRewardsTableFilterComposer(
            $db: $db,
            $table: $db.claimedRewards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> shopPurchasesRefs(
    Expression<bool> Function($$ShopPurchasesTableFilterComposer f) f,
  ) {
    final $$ShopPurchasesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shopPurchases,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShopPurchasesTableFilterComposer(
            $db: $db,
            $table: $db.shopPurchases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> clockStatesRefs(
    Expression<bool> Function($$ClockStatesTableFilterComposer f) f,
  ) {
    final $$ClockStatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.clockStates,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClockStatesTableFilterComposer(
            $db: $db,
            $table: $db.clockStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> currenciesRefs(
    Expression<bool> Function($$CurrenciesTableFilterComposer f) f,
  ) {
    final $$CurrenciesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.currencies,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurrenciesTableFilterComposer(
            $db: $db,
            $table: $db.currencies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> periodicQuestStatesRefs(
    Expression<bool> Function($$PeriodicQuestStatesTableFilterComposer f) f,
  ) {
    final $$PeriodicQuestStatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.periodicQuestStates,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeriodicQuestStatesTableFilterComposer(
            $db: $db,
            $table: $db.periodicQuestStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> eventShopPurchasesRefs(
    Expression<bool> Function($$EventShopPurchasesTableFilterComposer f) f,
  ) {
    final $$EventShopPurchasesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.eventShopPurchases,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventShopPurchasesTableFilterComposer(
            $db: $db,
            $table: $db.eventShopPurchases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlayersTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayersTable> {
  $$PlayersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentExp => $composableBuilder(
    column: $table.currentExp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gold => $composableBuilder(
    column: $table.gold,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentHp => $composableBuilder(
    column: $table.currentHp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activeSpecializationId => $composableBuilder(
    column: $table.activeSpecializationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseStatsJson => $composableBuilder(
    column: $table.baseStatsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get equipmentCounter => $composableBuilder(
    column: $table.equipmentCounter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSavedAtMs => $composableBuilder(
    column: $table.lastSavedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlayersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayersTable> {
  $$PlayersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<int> get currentExp => $composableBuilder(
    column: $table.currentExp,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gold =>
      $composableBuilder(column: $table.gold, builder: (column) => column);

  GeneratedColumn<int> get currentHp =>
      $composableBuilder(column: $table.currentHp, builder: (column) => column);

  GeneratedColumn<String> get activeSpecializationId => $composableBuilder(
    column: $table.activeSpecializationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baseStatsJson => $composableBuilder(
    column: $table.baseStatsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get equipmentCounter => $composableBuilder(
    column: $table.equipmentCounter,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSavedAtMs => $composableBuilder(
    column: $table.lastSavedAtMs,
    builder: (column) => column,
  );

  Expression<T> skillProgressesRefs<T extends Object>(
    Expression<T> Function($$SkillProgressesTableAnnotationComposer a) f,
  ) {
    final $$SkillProgressesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.skillProgresses,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SkillProgressesTableAnnotationComposer(
            $db: $db,
            $table: $db.skillProgresses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> inventoryEntriesRefs<T extends Object>(
    Expression<T> Function($$InventoryEntriesTableAnnotationComposer a) f,
  ) {
    final $$InventoryEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.inventoryEntries,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InventoryEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.inventoryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> equipmentInstancesRefs<T extends Object>(
    Expression<T> Function($$EquipmentInstancesTableAnnotationComposer a) f,
  ) {
    final $$EquipmentInstancesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.equipmentInstances,
          getReferencedColumn: (t) => t.playerId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EquipmentInstancesTableAnnotationComposer(
                $db: $db,
                $table: $db.equipmentInstances,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> equippedItemsRefs<T extends Object>(
    Expression<T> Function($$EquippedItemsTableAnnotationComposer a) f,
  ) {
    final $$EquippedItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.equippedItems,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EquippedItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.equippedItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> dungeonProgressesRefs<T extends Object>(
    Expression<T> Function($$DungeonProgressesTableAnnotationComposer a) f,
  ) {
    final $$DungeonProgressesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.dungeonProgresses,
          getReferencedColumn: (t) => t.playerId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DungeonProgressesTableAnnotationComposer(
                $db: $db,
                $table: $db.dungeonProgresses,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> cycleProgressesRefs<T extends Object>(
    Expression<T> Function($$CycleProgressesTableAnnotationComposer a) f,
  ) {
    final $$CycleProgressesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cycleProgresses,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CycleProgressesTableAnnotationComposer(
            $db: $db,
            $table: $db.cycleProgresses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> gameSessionsRefs<T extends Object>(
    Expression<T> Function($$GameSessionsTableAnnotationComposer a) f,
  ) {
    final $$GameSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gameSessions,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GameSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.gameSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> claimedRewardsRefs<T extends Object>(
    Expression<T> Function($$ClaimedRewardsTableAnnotationComposer a) f,
  ) {
    final $$ClaimedRewardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.claimedRewards,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClaimedRewardsTableAnnotationComposer(
            $db: $db,
            $table: $db.claimedRewards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> shopPurchasesRefs<T extends Object>(
    Expression<T> Function($$ShopPurchasesTableAnnotationComposer a) f,
  ) {
    final $$ShopPurchasesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.shopPurchases,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ShopPurchasesTableAnnotationComposer(
            $db: $db,
            $table: $db.shopPurchases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> clockStatesRefs<T extends Object>(
    Expression<T> Function($$ClockStatesTableAnnotationComposer a) f,
  ) {
    final $$ClockStatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.clockStates,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ClockStatesTableAnnotationComposer(
            $db: $db,
            $table: $db.clockStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> currenciesRefs<T extends Object>(
    Expression<T> Function($$CurrenciesTableAnnotationComposer a) f,
  ) {
    final $$CurrenciesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.currencies,
      getReferencedColumn: (t) => t.playerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CurrenciesTableAnnotationComposer(
            $db: $db,
            $table: $db.currencies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> periodicQuestStatesRefs<T extends Object>(
    Expression<T> Function($$PeriodicQuestStatesTableAnnotationComposer a) f,
  ) {
    final $$PeriodicQuestStatesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.periodicQuestStates,
          getReferencedColumn: (t) => t.playerId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PeriodicQuestStatesTableAnnotationComposer(
                $db: $db,
                $table: $db.periodicQuestStates,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> eventShopPurchasesRefs<T extends Object>(
    Expression<T> Function($$EventShopPurchasesTableAnnotationComposer a) f,
  ) {
    final $$EventShopPurchasesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.eventShopPurchases,
          getReferencedColumn: (t) => t.playerId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EventShopPurchasesTableAnnotationComposer(
                $db: $db,
                $table: $db.eventShopPurchases,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PlayersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlayersTable,
          Player,
          $$PlayersTableFilterComposer,
          $$PlayersTableOrderingComposer,
          $$PlayersTableAnnotationComposer,
          $$PlayersTableCreateCompanionBuilder,
          $$PlayersTableUpdateCompanionBuilder,
          (Player, $$PlayersTableReferences),
          Player,
          PrefetchHooks Function({
            bool skillProgressesRefs,
            bool inventoryEntriesRefs,
            bool equipmentInstancesRefs,
            bool equippedItemsRefs,
            bool dungeonProgressesRefs,
            bool cycleProgressesRefs,
            bool gameSessionsRefs,
            bool claimedRewardsRefs,
            bool shopPurchasesRefs,
            bool clockStatesRefs,
            bool currenciesRefs,
            bool periodicQuestStatesRefs,
            bool eventShopPurchasesRefs,
          })
        > {
  $$PlayersTableTableManager(_$AppDatabase db, $PlayersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<int> currentExp = const Value.absent(),
                Value<int> gold = const Value.absent(),
                Value<int?> currentHp = const Value.absent(),
                Value<String?> activeSpecializationId = const Value.absent(),
                Value<String> baseStatsJson = const Value.absent(),
                Value<int> equipmentCounter = const Value.absent(),
                Value<int> lastSavedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayersCompanion(
                id: id,
                level: level,
                currentExp: currentExp,
                gold: gold,
                currentHp: currentHp,
                activeSpecializationId: activeSpecializationId,
                baseStatsJson: baseStatsJson,
                equipmentCounter: equipmentCounter,
                lastSavedAtMs: lastSavedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int level,
                required int currentExp,
                required int gold,
                Value<int?> currentHp = const Value.absent(),
                Value<String?> activeSpecializationId = const Value.absent(),
                required String baseStatsJson,
                Value<int> equipmentCounter = const Value.absent(),
                required int lastSavedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => PlayersCompanion.insert(
                id: id,
                level: level,
                currentExp: currentExp,
                gold: gold,
                currentHp: currentHp,
                activeSpecializationId: activeSpecializationId,
                baseStatsJson: baseStatsJson,
                equipmentCounter: equipmentCounter,
                lastSavedAtMs: lastSavedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlayersTable, Player>(table),
                  $$PlayersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                skillProgressesRefs = false,
                inventoryEntriesRefs = false,
                equipmentInstancesRefs = false,
                equippedItemsRefs = false,
                dungeonProgressesRefs = false,
                cycleProgressesRefs = false,
                gameSessionsRefs = false,
                claimedRewardsRefs = false,
                shopPurchasesRefs = false,
                clockStatesRefs = false,
                currenciesRefs = false,
                periodicQuestStatesRefs = false,
                eventShopPurchasesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (skillProgressesRefs) db.skillProgresses,
                    if (inventoryEntriesRefs) db.inventoryEntries,
                    if (equipmentInstancesRefs) db.equipmentInstances,
                    if (equippedItemsRefs) db.equippedItems,
                    if (dungeonProgressesRefs) db.dungeonProgresses,
                    if (cycleProgressesRefs) db.cycleProgresses,
                    if (gameSessionsRefs) db.gameSessions,
                    if (claimedRewardsRefs) db.claimedRewards,
                    if (shopPurchasesRefs) db.shopPurchases,
                    if (clockStatesRefs) db.clockStates,
                    if (currenciesRefs) db.currencies,
                    if (periodicQuestStatesRefs) db.periodicQuestStates,
                    if (eventShopPurchasesRefs) db.eventShopPurchases,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (skillProgressesRefs)
                        await $_getPrefetchedDataByColumns<
                          Player,
                          $PlayersTable,
                          SkillProgressesData,
                          $SkillProgressesTable
                        >(
                          currentTable: table,
                          referencedTable: $$PlayersTableReferences
                              ._skillProgressesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlayersTableReferences(
                                db,
                                table,
                                p0,
                              ).skillProgressesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'player_id',
                          typedResults: items,
                        ),
                      if (inventoryEntriesRefs)
                        await $_getPrefetchedDataByColumns<
                          Player,
                          $PlayersTable,
                          InventoryEntry,
                          $InventoryEntriesTable
                        >(
                          currentTable: table,
                          referencedTable: $$PlayersTableReferences
                              ._inventoryEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlayersTableReferences(
                                db,
                                table,
                                p0,
                              ).inventoryEntriesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'player_id',
                          typedResults: items,
                        ),
                      if (equipmentInstancesRefs)
                        await $_getPrefetchedDataByColumns<
                          Player,
                          $PlayersTable,
                          EquipmentInstanceRow,
                          $EquipmentInstancesTable
                        >(
                          currentTable: table,
                          referencedTable: $$PlayersTableReferences
                              ._equipmentInstancesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlayersTableReferences(
                                db,
                                table,
                                p0,
                              ).equipmentInstancesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'player_id',
                          typedResults: items,
                        ),
                      if (equippedItemsRefs)
                        await $_getPrefetchedDataByColumns<
                          Player,
                          $PlayersTable,
                          EquippedItem,
                          $EquippedItemsTable
                        >(
                          currentTable: table,
                          referencedTable: $$PlayersTableReferences
                              ._equippedItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlayersTableReferences(
                                db,
                                table,
                                p0,
                              ).equippedItemsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'player_id',
                          typedResults: items,
                        ),
                      if (dungeonProgressesRefs)
                        await $_getPrefetchedDataByColumns<
                          Player,
                          $PlayersTable,
                          DungeonProgressesData,
                          $DungeonProgressesTable
                        >(
                          currentTable: table,
                          referencedTable: $$PlayersTableReferences
                              ._dungeonProgressesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlayersTableReferences(
                                db,
                                table,
                                p0,
                              ).dungeonProgressesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'player_id',
                          typedResults: items,
                        ),
                      if (cycleProgressesRefs)
                        await $_getPrefetchedDataByColumns<
                          Player,
                          $PlayersTable,
                          CycleProgressesData,
                          $CycleProgressesTable
                        >(
                          currentTable: table,
                          referencedTable: $$PlayersTableReferences
                              ._cycleProgressesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlayersTableReferences(
                                db,
                                table,
                                p0,
                              ).cycleProgressesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'player_id',
                          typedResults: items,
                        ),
                      if (gameSessionsRefs)
                        await $_getPrefetchedDataByColumns<
                          Player,
                          $PlayersTable,
                          GameSession,
                          $GameSessionsTable
                        >(
                          currentTable: table,
                          referencedTable: $$PlayersTableReferences
                              ._gameSessionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlayersTableReferences(
                                db,
                                table,
                                p0,
                              ).gameSessionsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'player_id',
                          typedResults: items,
                        ),
                      if (claimedRewardsRefs)
                        await $_getPrefetchedDataByColumns<
                          Player,
                          $PlayersTable,
                          ClaimedReward,
                          $ClaimedRewardsTable
                        >(
                          currentTable: table,
                          referencedTable: $$PlayersTableReferences
                              ._claimedRewardsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlayersTableReferences(
                                db,
                                table,
                                p0,
                              ).claimedRewardsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'player_id',
                          typedResults: items,
                        ),
                      if (shopPurchasesRefs)
                        await $_getPrefetchedDataByColumns<
                          Player,
                          $PlayersTable,
                          ShopPurchase,
                          $ShopPurchasesTable
                        >(
                          currentTable: table,
                          referencedTable: $$PlayersTableReferences
                              ._shopPurchasesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlayersTableReferences(
                                db,
                                table,
                                p0,
                              ).shopPurchasesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'player_id',
                          typedResults: items,
                        ),
                      if (clockStatesRefs)
                        await $_getPrefetchedDataByColumns<
                          Player,
                          $PlayersTable,
                          ClockState,
                          $ClockStatesTable
                        >(
                          currentTable: table,
                          referencedTable: $$PlayersTableReferences
                              ._clockStatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlayersTableReferences(
                                db,
                                table,
                                p0,
                              ).clockStatesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'player_id',
                          typedResults: items,
                        ),
                      if (currenciesRefs)
                        await $_getPrefetchedDataByColumns<
                          Player,
                          $PlayersTable,
                          Currency,
                          $CurrenciesTable
                        >(
                          currentTable: table,
                          referencedTable: $$PlayersTableReferences
                              ._currenciesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlayersTableReferences(
                                db,
                                table,
                                p0,
                              ).currenciesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'player_id',
                          typedResults: items,
                        ),
                      if (periodicQuestStatesRefs)
                        await $_getPrefetchedDataByColumns<
                          Player,
                          $PlayersTable,
                          PeriodicQuestState,
                          $PeriodicQuestStatesTable
                        >(
                          currentTable: table,
                          referencedTable: $$PlayersTableReferences
                              ._periodicQuestStatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlayersTableReferences(
                                db,
                                table,
                                p0,
                              ).periodicQuestStatesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'player_id',
                          typedResults: items,
                        ),
                      if (eventShopPurchasesRefs)
                        await $_getPrefetchedDataByColumns<
                          Player,
                          $PlayersTable,
                          EventShopPurchase,
                          $EventShopPurchasesTable
                        >(
                          currentTable: table,
                          referencedTable: $$PlayersTableReferences
                              ._eventShopPurchasesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlayersTableReferences(
                                db,
                                table,
                                p0,
                              ).eventShopPurchasesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'player_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PlayersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlayersTable,
      Player,
      $$PlayersTableFilterComposer,
      $$PlayersTableOrderingComposer,
      $$PlayersTableAnnotationComposer,
      $$PlayersTableCreateCompanionBuilder,
      $$PlayersTableUpdateCompanionBuilder,
      (Player, $$PlayersTableReferences),
      Player,
      PrefetchHooks Function({
        bool skillProgressesRefs,
        bool inventoryEntriesRefs,
        bool equipmentInstancesRefs,
        bool equippedItemsRefs,
        bool dungeonProgressesRefs,
        bool cycleProgressesRefs,
        bool gameSessionsRefs,
        bool claimedRewardsRefs,
        bool shopPurchasesRefs,
        bool clockStatesRefs,
        bool currenciesRefs,
        bool periodicQuestStatesRefs,
        bool eventShopPurchasesRefs,
      })
    >;
typedef $$SkillProgressesTableCreateCompanionBuilder =
    SkillProgressesCompanion Function({
      required String playerId,
      required String skillId,
      required int skillLevel,
      required bool unlocked,
      Value<int> cooldownTicksRemaining,
      Value<int> rowid,
    });
typedef $$SkillProgressesTableUpdateCompanionBuilder =
    SkillProgressesCompanion Function({
      Value<String> playerId,
      Value<String> skillId,
      Value<int> skillLevel,
      Value<bool> unlocked,
      Value<int> cooldownTicksRemaining,
      Value<int> rowid,
    });

final class $$SkillProgressesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $SkillProgressesTable,
          SkillProgressesData
        > {
  $$SkillProgressesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlayersTable _playerIdTable(_$AppDatabase db) =>
      db.players.createAlias('skill_progresses__player_id__players__id');

  $$PlayersTableProcessedTableManager get playerId {
    final $_column = $_itemColumn<String>('player_id')!;

    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SkillProgressesTableFilterComposer
    extends Composer<_$AppDatabase, $SkillProgressesTable> {
  $$SkillProgressesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get skillId => $composableBuilder(
    column: $table.skillId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get skillLevel => $composableBuilder(
    column: $table.skillLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get unlocked => $composableBuilder(
    column: $table.unlocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cooldownTicksRemaining => $composableBuilder(
    column: $table.cooldownTicksRemaining,
    builder: (column) => ColumnFilters(column),
  );

  $$PlayersTableFilterComposer get playerId {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableFilterComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SkillProgressesTableOrderingComposer
    extends Composer<_$AppDatabase, $SkillProgressesTable> {
  $$SkillProgressesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get skillId => $composableBuilder(
    column: $table.skillId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get skillLevel => $composableBuilder(
    column: $table.skillLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get unlocked => $composableBuilder(
    column: $table.unlocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cooldownTicksRemaining => $composableBuilder(
    column: $table.cooldownTicksRemaining,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlayersTableOrderingComposer get playerId {
    final $$PlayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableOrderingComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SkillProgressesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SkillProgressesTable> {
  $$SkillProgressesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get skillId =>
      $composableBuilder(column: $table.skillId, builder: (column) => column);

  GeneratedColumn<int> get skillLevel => $composableBuilder(
    column: $table.skillLevel,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get unlocked =>
      $composableBuilder(column: $table.unlocked, builder: (column) => column);

  GeneratedColumn<int> get cooldownTicksRemaining => $composableBuilder(
    column: $table.cooldownTicksRemaining,
    builder: (column) => column,
  );

  $$PlayersTableAnnotationComposer get playerId {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SkillProgressesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SkillProgressesTable,
          SkillProgressesData,
          $$SkillProgressesTableFilterComposer,
          $$SkillProgressesTableOrderingComposer,
          $$SkillProgressesTableAnnotationComposer,
          $$SkillProgressesTableCreateCompanionBuilder,
          $$SkillProgressesTableUpdateCompanionBuilder,
          (SkillProgressesData, $$SkillProgressesTableReferences),
          SkillProgressesData,
          PrefetchHooks Function({bool playerId})
        > {
  $$SkillProgressesTableTableManager(
    _$AppDatabase db,
    $SkillProgressesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SkillProgressesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SkillProgressesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SkillProgressesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> playerId = const Value.absent(),
                Value<String> skillId = const Value.absent(),
                Value<int> skillLevel = const Value.absent(),
                Value<bool> unlocked = const Value.absent(),
                Value<int> cooldownTicksRemaining = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SkillProgressesCompanion(
                playerId: playerId,
                skillId: skillId,
                skillLevel: skillLevel,
                unlocked: unlocked,
                cooldownTicksRemaining: cooldownTicksRemaining,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String playerId,
                required String skillId,
                required int skillLevel,
                required bool unlocked,
                Value<int> cooldownTicksRemaining = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SkillProgressesCompanion.insert(
                playerId: playerId,
                skillId: skillId,
                skillLevel: skillLevel,
                unlocked: unlocked,
                cooldownTicksRemaining: cooldownTicksRemaining,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SkillProgressesTable, SkillProgressesData>(
                    table,
                  ),
                  $$SkillProgressesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playerId,
                        referencedTable: $$SkillProgressesTableReferences
                            ._playerIdTable(db),
                        referencedColumn: $$SkillProgressesTableReferences
                            ._playerIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SkillProgressesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SkillProgressesTable,
      SkillProgressesData,
      $$SkillProgressesTableFilterComposer,
      $$SkillProgressesTableOrderingComposer,
      $$SkillProgressesTableAnnotationComposer,
      $$SkillProgressesTableCreateCompanionBuilder,
      $$SkillProgressesTableUpdateCompanionBuilder,
      (SkillProgressesData, $$SkillProgressesTableReferences),
      SkillProgressesData,
      PrefetchHooks Function({bool playerId})
    >;
typedef $$InventoryEntriesTableCreateCompanionBuilder =
    InventoryEntriesCompanion Function({
      required String playerId,
      required String itemId,
      required int quantity,
      Value<int> rowid,
    });
typedef $$InventoryEntriesTableUpdateCompanionBuilder =
    InventoryEntriesCompanion Function({
      Value<String> playerId,
      Value<String> itemId,
      Value<int> quantity,
      Value<int> rowid,
    });

final class $$InventoryEntriesTableReferences
    extends
        BaseReferences<_$AppDatabase, $InventoryEntriesTable, InventoryEntry> {
  $$InventoryEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlayersTable _playerIdTable(_$AppDatabase db) =>
      db.players.createAlias('inventory_entries__player_id__players__id');

  $$PlayersTableProcessedTableManager get playerId {
    final $_column = $_itemColumn<String>('player_id')!;

    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$InventoryEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $InventoryEntriesTable> {
  $$InventoryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  $$PlayersTableFilterComposer get playerId {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableFilterComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InventoryEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $InventoryEntriesTable> {
  $$InventoryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlayersTableOrderingComposer get playerId {
    final $$PlayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableOrderingComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InventoryEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $InventoryEntriesTable> {
  $$InventoryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  $$PlayersTableAnnotationComposer get playerId {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InventoryEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InventoryEntriesTable,
          InventoryEntry,
          $$InventoryEntriesTableFilterComposer,
          $$InventoryEntriesTableOrderingComposer,
          $$InventoryEntriesTableAnnotationComposer,
          $$InventoryEntriesTableCreateCompanionBuilder,
          $$InventoryEntriesTableUpdateCompanionBuilder,
          (InventoryEntry, $$InventoryEntriesTableReferences),
          InventoryEntry,
          PrefetchHooks Function({bool playerId})
        > {
  $$InventoryEntriesTableTableManager(
    _$AppDatabase db,
    $InventoryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InventoryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InventoryEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InventoryEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> playerId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InventoryEntriesCompanion(
                playerId: playerId,
                itemId: itemId,
                quantity: quantity,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String playerId,
                required String itemId,
                required int quantity,
                Value<int> rowid = const Value.absent(),
              }) => InventoryEntriesCompanion.insert(
                playerId: playerId,
                itemId: itemId,
                quantity: quantity,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$InventoryEntriesTable, InventoryEntry>(table),
                  $$InventoryEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playerId,
                        referencedTable: $$InventoryEntriesTableReferences
                            ._playerIdTable(db),
                        referencedColumn: $$InventoryEntriesTableReferences
                            ._playerIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$InventoryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InventoryEntriesTable,
      InventoryEntry,
      $$InventoryEntriesTableFilterComposer,
      $$InventoryEntriesTableOrderingComposer,
      $$InventoryEntriesTableAnnotationComposer,
      $$InventoryEntriesTableCreateCompanionBuilder,
      $$InventoryEntriesTableUpdateCompanionBuilder,
      (InventoryEntry, $$InventoryEntriesTableReferences),
      InventoryEntry,
      PrefetchHooks Function({bool playerId})
    >;
typedef $$EquipmentInstancesTableCreateCompanionBuilder =
    EquipmentInstancesCompanion Function({
      required String playerId,
      required String instanceId,
      required String definitionId,
      required String slot,
      required String rarity,
      required String rolledStatsJson,
      Value<int> enhancementLevel,
      Value<int> rowid,
    });
typedef $$EquipmentInstancesTableUpdateCompanionBuilder =
    EquipmentInstancesCompanion Function({
      Value<String> playerId,
      Value<String> instanceId,
      Value<String> definitionId,
      Value<String> slot,
      Value<String> rarity,
      Value<String> rolledStatsJson,
      Value<int> enhancementLevel,
      Value<int> rowid,
    });

final class $$EquipmentInstancesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $EquipmentInstancesTable,
          EquipmentInstanceRow
        > {
  $$EquipmentInstancesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlayersTable _playerIdTable(_$AppDatabase db) =>
      db.players.createAlias('equipment_instances__player_id__players__id');

  $$PlayersTableProcessedTableManager get playerId {
    final $_column = $_itemColumn<String>('player_id')!;

    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EquipmentInstancesTableFilterComposer
    extends Composer<_$AppDatabase, $EquipmentInstancesTable> {
  $$EquipmentInstancesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get instanceId => $composableBuilder(
    column: $table.instanceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get definitionId => $composableBuilder(
    column: $table.definitionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rarity => $composableBuilder(
    column: $table.rarity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rolledStatsJson => $composableBuilder(
    column: $table.rolledStatsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get enhancementLevel => $composableBuilder(
    column: $table.enhancementLevel,
    builder: (column) => ColumnFilters(column),
  );

  $$PlayersTableFilterComposer get playerId {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableFilterComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EquipmentInstancesTableOrderingComposer
    extends Composer<_$AppDatabase, $EquipmentInstancesTable> {
  $$EquipmentInstancesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get instanceId => $composableBuilder(
    column: $table.instanceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get definitionId => $composableBuilder(
    column: $table.definitionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rarity => $composableBuilder(
    column: $table.rarity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rolledStatsJson => $composableBuilder(
    column: $table.rolledStatsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get enhancementLevel => $composableBuilder(
    column: $table.enhancementLevel,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlayersTableOrderingComposer get playerId {
    final $$PlayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableOrderingComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EquipmentInstancesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EquipmentInstancesTable> {
  $$EquipmentInstancesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get instanceId => $composableBuilder(
    column: $table.instanceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get definitionId => $composableBuilder(
    column: $table.definitionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<String> get rarity =>
      $composableBuilder(column: $table.rarity, builder: (column) => column);

  GeneratedColumn<String> get rolledStatsJson => $composableBuilder(
    column: $table.rolledStatsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get enhancementLevel => $composableBuilder(
    column: $table.enhancementLevel,
    builder: (column) => column,
  );

  $$PlayersTableAnnotationComposer get playerId {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EquipmentInstancesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EquipmentInstancesTable,
          EquipmentInstanceRow,
          $$EquipmentInstancesTableFilterComposer,
          $$EquipmentInstancesTableOrderingComposer,
          $$EquipmentInstancesTableAnnotationComposer,
          $$EquipmentInstancesTableCreateCompanionBuilder,
          $$EquipmentInstancesTableUpdateCompanionBuilder,
          (EquipmentInstanceRow, $$EquipmentInstancesTableReferences),
          EquipmentInstanceRow,
          PrefetchHooks Function({bool playerId})
        > {
  $$EquipmentInstancesTableTableManager(
    _$AppDatabase db,
    $EquipmentInstancesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EquipmentInstancesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EquipmentInstancesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EquipmentInstancesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> playerId = const Value.absent(),
                Value<String> instanceId = const Value.absent(),
                Value<String> definitionId = const Value.absent(),
                Value<String> slot = const Value.absent(),
                Value<String> rarity = const Value.absent(),
                Value<String> rolledStatsJson = const Value.absent(),
                Value<int> enhancementLevel = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EquipmentInstancesCompanion(
                playerId: playerId,
                instanceId: instanceId,
                definitionId: definitionId,
                slot: slot,
                rarity: rarity,
                rolledStatsJson: rolledStatsJson,
                enhancementLevel: enhancementLevel,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String playerId,
                required String instanceId,
                required String definitionId,
                required String slot,
                required String rarity,
                required String rolledStatsJson,
                Value<int> enhancementLevel = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EquipmentInstancesCompanion.insert(
                playerId: playerId,
                instanceId: instanceId,
                definitionId: definitionId,
                slot: slot,
                rarity: rarity,
                rolledStatsJson: rolledStatsJson,
                enhancementLevel: enhancementLevel,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EquipmentInstancesTable, EquipmentInstanceRow>(
                    table,
                  ),
                  $$EquipmentInstancesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playerId,
                        referencedTable: $$EquipmentInstancesTableReferences
                            ._playerIdTable(db),
                        referencedColumn: $$EquipmentInstancesTableReferences
                            ._playerIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EquipmentInstancesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EquipmentInstancesTable,
      EquipmentInstanceRow,
      $$EquipmentInstancesTableFilterComposer,
      $$EquipmentInstancesTableOrderingComposer,
      $$EquipmentInstancesTableAnnotationComposer,
      $$EquipmentInstancesTableCreateCompanionBuilder,
      $$EquipmentInstancesTableUpdateCompanionBuilder,
      (EquipmentInstanceRow, $$EquipmentInstancesTableReferences),
      EquipmentInstanceRow,
      PrefetchHooks Function({bool playerId})
    >;
typedef $$EquippedItemsTableCreateCompanionBuilder =
    EquippedItemsCompanion Function({
      required String playerId,
      required String slot,
      required String equipmentInstanceId,
      Value<int> rowid,
    });
typedef $$EquippedItemsTableUpdateCompanionBuilder =
    EquippedItemsCompanion Function({
      Value<String> playerId,
      Value<String> slot,
      Value<String> equipmentInstanceId,
      Value<int> rowid,
    });

final class $$EquippedItemsTableReferences
    extends BaseReferences<_$AppDatabase, $EquippedItemsTable, EquippedItem> {
  $$EquippedItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlayersTable _playerIdTable(_$AppDatabase db) =>
      db.players.createAlias('equipped_items__player_id__players__id');

  $$PlayersTableProcessedTableManager get playerId {
    final $_column = $_itemColumn<String>('player_id')!;

    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EquippedItemsTableFilterComposer
    extends Composer<_$AppDatabase, $EquippedItemsTable> {
  $$EquippedItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get equipmentInstanceId => $composableBuilder(
    column: $table.equipmentInstanceId,
    builder: (column) => ColumnFilters(column),
  );

  $$PlayersTableFilterComposer get playerId {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableFilterComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EquippedItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $EquippedItemsTable> {
  $$EquippedItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get equipmentInstanceId => $composableBuilder(
    column: $table.equipmentInstanceId,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlayersTableOrderingComposer get playerId {
    final $$PlayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableOrderingComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EquippedItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EquippedItemsTable> {
  $$EquippedItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<String> get equipmentInstanceId => $composableBuilder(
    column: $table.equipmentInstanceId,
    builder: (column) => column,
  );

  $$PlayersTableAnnotationComposer get playerId {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EquippedItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EquippedItemsTable,
          EquippedItem,
          $$EquippedItemsTableFilterComposer,
          $$EquippedItemsTableOrderingComposer,
          $$EquippedItemsTableAnnotationComposer,
          $$EquippedItemsTableCreateCompanionBuilder,
          $$EquippedItemsTableUpdateCompanionBuilder,
          (EquippedItem, $$EquippedItemsTableReferences),
          EquippedItem,
          PrefetchHooks Function({bool playerId})
        > {
  $$EquippedItemsTableTableManager(_$AppDatabase db, $EquippedItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EquippedItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EquippedItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EquippedItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> playerId = const Value.absent(),
                Value<String> slot = const Value.absent(),
                Value<String> equipmentInstanceId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EquippedItemsCompanion(
                playerId: playerId,
                slot: slot,
                equipmentInstanceId: equipmentInstanceId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String playerId,
                required String slot,
                required String equipmentInstanceId,
                Value<int> rowid = const Value.absent(),
              }) => EquippedItemsCompanion.insert(
                playerId: playerId,
                slot: slot,
                equipmentInstanceId: equipmentInstanceId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EquippedItemsTable, EquippedItem>(table),
                  $$EquippedItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playerId,
                        referencedTable: $$EquippedItemsTableReferences
                            ._playerIdTable(db),
                        referencedColumn: $$EquippedItemsTableReferences
                            ._playerIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EquippedItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EquippedItemsTable,
      EquippedItem,
      $$EquippedItemsTableFilterComposer,
      $$EquippedItemsTableOrderingComposer,
      $$EquippedItemsTableAnnotationComposer,
      $$EquippedItemsTableCreateCompanionBuilder,
      $$EquippedItemsTableUpdateCompanionBuilder,
      (EquippedItem, $$EquippedItemsTableReferences),
      EquippedItem,
      PrefetchHooks Function({bool playerId})
    >;
typedef $$DungeonProgressesTableCreateCompanionBuilder =
    DungeonProgressesCompanion Function({
      required String playerId,
      required String dungeonId,
      required String currentRoomId,
      required int currentRoomIndex,
      required int highestClearedRoomIndex,
      required int clearsCount,
      Value<int> clearedInCycleRank,
      Value<String> rewardStateJson,
      Value<int> rowid,
    });
typedef $$DungeonProgressesTableUpdateCompanionBuilder =
    DungeonProgressesCompanion Function({
      Value<String> playerId,
      Value<String> dungeonId,
      Value<String> currentRoomId,
      Value<int> currentRoomIndex,
      Value<int> highestClearedRoomIndex,
      Value<int> clearsCount,
      Value<int> clearedInCycleRank,
      Value<String> rewardStateJson,
      Value<int> rowid,
    });

final class $$DungeonProgressesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $DungeonProgressesTable,
          DungeonProgressesData
        > {
  $$DungeonProgressesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlayersTable _playerIdTable(_$AppDatabase db) =>
      db.players.createAlias('dungeon_progresses__player_id__players__id');

  $$PlayersTableProcessedTableManager get playerId {
    final $_column = $_itemColumn<String>('player_id')!;

    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DungeonProgressesTableFilterComposer
    extends Composer<_$AppDatabase, $DungeonProgressesTable> {
  $$DungeonProgressesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dungeonId => $composableBuilder(
    column: $table.dungeonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentRoomId => $composableBuilder(
    column: $table.currentRoomId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentRoomIndex => $composableBuilder(
    column: $table.currentRoomIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get highestClearedRoomIndex => $composableBuilder(
    column: $table.highestClearedRoomIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get clearsCount => $composableBuilder(
    column: $table.clearsCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get clearedInCycleRank => $composableBuilder(
    column: $table.clearedInCycleRank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rewardStateJson => $composableBuilder(
    column: $table.rewardStateJson,
    builder: (column) => ColumnFilters(column),
  );

  $$PlayersTableFilterComposer get playerId {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableFilterComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DungeonProgressesTableOrderingComposer
    extends Composer<_$AppDatabase, $DungeonProgressesTable> {
  $$DungeonProgressesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dungeonId => $composableBuilder(
    column: $table.dungeonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentRoomId => $composableBuilder(
    column: $table.currentRoomId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentRoomIndex => $composableBuilder(
    column: $table.currentRoomIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get highestClearedRoomIndex => $composableBuilder(
    column: $table.highestClearedRoomIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get clearsCount => $composableBuilder(
    column: $table.clearsCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get clearedInCycleRank => $composableBuilder(
    column: $table.clearedInCycleRank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rewardStateJson => $composableBuilder(
    column: $table.rewardStateJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlayersTableOrderingComposer get playerId {
    final $$PlayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableOrderingComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DungeonProgressesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DungeonProgressesTable> {
  $$DungeonProgressesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dungeonId =>
      $composableBuilder(column: $table.dungeonId, builder: (column) => column);

  GeneratedColumn<String> get currentRoomId => $composableBuilder(
    column: $table.currentRoomId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentRoomIndex => $composableBuilder(
    column: $table.currentRoomIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get highestClearedRoomIndex => $composableBuilder(
    column: $table.highestClearedRoomIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get clearsCount => $composableBuilder(
    column: $table.clearsCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get clearedInCycleRank => $composableBuilder(
    column: $table.clearedInCycleRank,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rewardStateJson => $composableBuilder(
    column: $table.rewardStateJson,
    builder: (column) => column,
  );

  $$PlayersTableAnnotationComposer get playerId {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DungeonProgressesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DungeonProgressesTable,
          DungeonProgressesData,
          $$DungeonProgressesTableFilterComposer,
          $$DungeonProgressesTableOrderingComposer,
          $$DungeonProgressesTableAnnotationComposer,
          $$DungeonProgressesTableCreateCompanionBuilder,
          $$DungeonProgressesTableUpdateCompanionBuilder,
          (DungeonProgressesData, $$DungeonProgressesTableReferences),
          DungeonProgressesData,
          PrefetchHooks Function({bool playerId})
        > {
  $$DungeonProgressesTableTableManager(
    _$AppDatabase db,
    $DungeonProgressesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DungeonProgressesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DungeonProgressesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DungeonProgressesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> playerId = const Value.absent(),
                Value<String> dungeonId = const Value.absent(),
                Value<String> currentRoomId = const Value.absent(),
                Value<int> currentRoomIndex = const Value.absent(),
                Value<int> highestClearedRoomIndex = const Value.absent(),
                Value<int> clearsCount = const Value.absent(),
                Value<int> clearedInCycleRank = const Value.absent(),
                Value<String> rewardStateJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DungeonProgressesCompanion(
                playerId: playerId,
                dungeonId: dungeonId,
                currentRoomId: currentRoomId,
                currentRoomIndex: currentRoomIndex,
                highestClearedRoomIndex: highestClearedRoomIndex,
                clearsCount: clearsCount,
                clearedInCycleRank: clearedInCycleRank,
                rewardStateJson: rewardStateJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String playerId,
                required String dungeonId,
                required String currentRoomId,
                required int currentRoomIndex,
                required int highestClearedRoomIndex,
                required int clearsCount,
                Value<int> clearedInCycleRank = const Value.absent(),
                Value<String> rewardStateJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DungeonProgressesCompanion.insert(
                playerId: playerId,
                dungeonId: dungeonId,
                currentRoomId: currentRoomId,
                currentRoomIndex: currentRoomIndex,
                highestClearedRoomIndex: highestClearedRoomIndex,
                clearsCount: clearsCount,
                clearedInCycleRank: clearedInCycleRank,
                rewardStateJson: rewardStateJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DungeonProgressesTable, DungeonProgressesData>(
                    table,
                  ),
                  $$DungeonProgressesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playerId,
                        referencedTable: $$DungeonProgressesTableReferences
                            ._playerIdTable(db),
                        referencedColumn: $$DungeonProgressesTableReferences
                            ._playerIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DungeonProgressesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DungeonProgressesTable,
      DungeonProgressesData,
      $$DungeonProgressesTableFilterComposer,
      $$DungeonProgressesTableOrderingComposer,
      $$DungeonProgressesTableAnnotationComposer,
      $$DungeonProgressesTableCreateCompanionBuilder,
      $$DungeonProgressesTableUpdateCompanionBuilder,
      (DungeonProgressesData, $$DungeonProgressesTableReferences),
      DungeonProgressesData,
      PrefetchHooks Function({bool playerId})
    >;
typedef $$CycleProgressesTableCreateCompanionBuilder =
    CycleProgressesCompanion Function({
      required String playerId,
      Value<int> ascensionRank,
      Value<int> highestAscensionRank,
      Value<String?> lastNormalDungeonId,
      required int updatedAtMs,
      Value<int> rowid,
    });
typedef $$CycleProgressesTableUpdateCompanionBuilder =
    CycleProgressesCompanion Function({
      Value<String> playerId,
      Value<int> ascensionRank,
      Value<int> highestAscensionRank,
      Value<String?> lastNormalDungeonId,
      Value<int> updatedAtMs,
      Value<int> rowid,
    });

final class $$CycleProgressesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CycleProgressesTable,
          CycleProgressesData
        > {
  $$CycleProgressesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlayersTable _playerIdTable(_$AppDatabase db) =>
      db.players.createAlias('cycle_progresses__player_id__players__id');

  $$PlayersTableProcessedTableManager get playerId {
    final $_column = $_itemColumn<String>('player_id')!;

    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CycleProgressesTableFilterComposer
    extends Composer<_$AppDatabase, $CycleProgressesTable> {
  $$CycleProgressesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get ascensionRank => $composableBuilder(
    column: $table.ascensionRank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get highestAscensionRank => $composableBuilder(
    column: $table.highestAscensionRank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastNormalDungeonId => $composableBuilder(
    column: $table.lastNormalDungeonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  $$PlayersTableFilterComposer get playerId {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableFilterComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CycleProgressesTableOrderingComposer
    extends Composer<_$AppDatabase, $CycleProgressesTable> {
  $$CycleProgressesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get ascensionRank => $composableBuilder(
    column: $table.ascensionRank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get highestAscensionRank => $composableBuilder(
    column: $table.highestAscensionRank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastNormalDungeonId => $composableBuilder(
    column: $table.lastNormalDungeonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlayersTableOrderingComposer get playerId {
    final $$PlayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableOrderingComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CycleProgressesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CycleProgressesTable> {
  $$CycleProgressesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get ascensionRank => $composableBuilder(
    column: $table.ascensionRank,
    builder: (column) => column,
  );

  GeneratedColumn<int> get highestAscensionRank => $composableBuilder(
    column: $table.highestAscensionRank,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastNormalDungeonId => $composableBuilder(
    column: $table.lastNormalDungeonId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );

  $$PlayersTableAnnotationComposer get playerId {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CycleProgressesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CycleProgressesTable,
          CycleProgressesData,
          $$CycleProgressesTableFilterComposer,
          $$CycleProgressesTableOrderingComposer,
          $$CycleProgressesTableAnnotationComposer,
          $$CycleProgressesTableCreateCompanionBuilder,
          $$CycleProgressesTableUpdateCompanionBuilder,
          (CycleProgressesData, $$CycleProgressesTableReferences),
          CycleProgressesData,
          PrefetchHooks Function({bool playerId})
        > {
  $$CycleProgressesTableTableManager(
    _$AppDatabase db,
    $CycleProgressesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CycleProgressesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CycleProgressesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CycleProgressesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> playerId = const Value.absent(),
                Value<int> ascensionRank = const Value.absent(),
                Value<int> highestAscensionRank = const Value.absent(),
                Value<String?> lastNormalDungeonId = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CycleProgressesCompanion(
                playerId: playerId,
                ascensionRank: ascensionRank,
                highestAscensionRank: highestAscensionRank,
                lastNormalDungeonId: lastNormalDungeonId,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String playerId,
                Value<int> ascensionRank = const Value.absent(),
                Value<int> highestAscensionRank = const Value.absent(),
                Value<String?> lastNormalDungeonId = const Value.absent(),
                required int updatedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => CycleProgressesCompanion.insert(
                playerId: playerId,
                ascensionRank: ascensionRank,
                highestAscensionRank: highestAscensionRank,
                lastNormalDungeonId: lastNormalDungeonId,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CycleProgressesTable, CycleProgressesData>(
                    table,
                  ),
                  $$CycleProgressesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playerId,
                        referencedTable: $$CycleProgressesTableReferences
                            ._playerIdTable(db),
                        referencedColumn: $$CycleProgressesTableReferences
                            ._playerIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CycleProgressesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CycleProgressesTable,
      CycleProgressesData,
      $$CycleProgressesTableFilterComposer,
      $$CycleProgressesTableOrderingComposer,
      $$CycleProgressesTableAnnotationComposer,
      $$CycleProgressesTableCreateCompanionBuilder,
      $$CycleProgressesTableUpdateCompanionBuilder,
      (CycleProgressesData, $$CycleProgressesTableReferences),
      CycleProgressesData,
      PrefetchHooks Function({bool playerId})
    >;
typedef $$GameSessionsTableCreateCompanionBuilder =
    GameSessionsCompanion Function({
      required String id,
      required String playerId,
      required int lastActiveAtMs,
      required int lastSavedAtMs,
      required int lastOfflineClaimAtMs,
      required bool autoSkillEnabled,
      Value<String> sessionDataJson,
      Value<int> rowid,
    });
typedef $$GameSessionsTableUpdateCompanionBuilder =
    GameSessionsCompanion Function({
      Value<String> id,
      Value<String> playerId,
      Value<int> lastActiveAtMs,
      Value<int> lastSavedAtMs,
      Value<int> lastOfflineClaimAtMs,
      Value<bool> autoSkillEnabled,
      Value<String> sessionDataJson,
      Value<int> rowid,
    });

final class $$GameSessionsTableReferences
    extends BaseReferences<_$AppDatabase, $GameSessionsTable, GameSession> {
  $$GameSessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlayersTable _playerIdTable(_$AppDatabase db) =>
      db.players.createAlias('game_sessions__player_id__players__id');

  $$PlayersTableProcessedTableManager get playerId {
    final $_column = $_itemColumn<String>('player_id')!;

    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GameSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $GameSessionsTable> {
  $$GameSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastActiveAtMs => $composableBuilder(
    column: $table.lastActiveAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSavedAtMs => $composableBuilder(
    column: $table.lastSavedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastOfflineClaimAtMs => $composableBuilder(
    column: $table.lastOfflineClaimAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoSkillEnabled => $composableBuilder(
    column: $table.autoSkillEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionDataJson => $composableBuilder(
    column: $table.sessionDataJson,
    builder: (column) => ColumnFilters(column),
  );

  $$PlayersTableFilterComposer get playerId {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableFilterComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GameSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $GameSessionsTable> {
  $$GameSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastActiveAtMs => $composableBuilder(
    column: $table.lastActiveAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSavedAtMs => $composableBuilder(
    column: $table.lastSavedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastOfflineClaimAtMs => $composableBuilder(
    column: $table.lastOfflineClaimAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoSkillEnabled => $composableBuilder(
    column: $table.autoSkillEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionDataJson => $composableBuilder(
    column: $table.sessionDataJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlayersTableOrderingComposer get playerId {
    final $$PlayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableOrderingComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GameSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GameSessionsTable> {
  $$GameSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get lastActiveAtMs => $composableBuilder(
    column: $table.lastActiveAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSavedAtMs => $composableBuilder(
    column: $table.lastSavedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastOfflineClaimAtMs => $composableBuilder(
    column: $table.lastOfflineClaimAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoSkillEnabled => $composableBuilder(
    column: $table.autoSkillEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sessionDataJson => $composableBuilder(
    column: $table.sessionDataJson,
    builder: (column) => column,
  );

  $$PlayersTableAnnotationComposer get playerId {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GameSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GameSessionsTable,
          GameSession,
          $$GameSessionsTableFilterComposer,
          $$GameSessionsTableOrderingComposer,
          $$GameSessionsTableAnnotationComposer,
          $$GameSessionsTableCreateCompanionBuilder,
          $$GameSessionsTableUpdateCompanionBuilder,
          (GameSession, $$GameSessionsTableReferences),
          GameSession,
          PrefetchHooks Function({bool playerId})
        > {
  $$GameSessionsTableTableManager(_$AppDatabase db, $GameSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GameSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GameSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GameSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> playerId = const Value.absent(),
                Value<int> lastActiveAtMs = const Value.absent(),
                Value<int> lastSavedAtMs = const Value.absent(),
                Value<int> lastOfflineClaimAtMs = const Value.absent(),
                Value<bool> autoSkillEnabled = const Value.absent(),
                Value<String> sessionDataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GameSessionsCompanion(
                id: id,
                playerId: playerId,
                lastActiveAtMs: lastActiveAtMs,
                lastSavedAtMs: lastSavedAtMs,
                lastOfflineClaimAtMs: lastOfflineClaimAtMs,
                autoSkillEnabled: autoSkillEnabled,
                sessionDataJson: sessionDataJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String playerId,
                required int lastActiveAtMs,
                required int lastSavedAtMs,
                required int lastOfflineClaimAtMs,
                required bool autoSkillEnabled,
                Value<String> sessionDataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GameSessionsCompanion.insert(
                id: id,
                playerId: playerId,
                lastActiveAtMs: lastActiveAtMs,
                lastSavedAtMs: lastSavedAtMs,
                lastOfflineClaimAtMs: lastOfflineClaimAtMs,
                autoSkillEnabled: autoSkillEnabled,
                sessionDataJson: sessionDataJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GameSessionsTable, GameSession>(table),
                  $$GameSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playerId,
                        referencedTable: $$GameSessionsTableReferences
                            ._playerIdTable(db),
                        referencedColumn: $$GameSessionsTableReferences
                            ._playerIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GameSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GameSessionsTable,
      GameSession,
      $$GameSessionsTableFilterComposer,
      $$GameSessionsTableOrderingComposer,
      $$GameSessionsTableAnnotationComposer,
      $$GameSessionsTableCreateCompanionBuilder,
      $$GameSessionsTableUpdateCompanionBuilder,
      (GameSession, $$GameSessionsTableReferences),
      GameSession,
      PrefetchHooks Function({bool playerId})
    >;
typedef $$ClaimedRewardsTableCreateCompanionBuilder =
    ClaimedRewardsCompanion Function({
      required String playerId,
      required String eventId,
      required int claimedAtMs,
      Value<int> rowid,
    });
typedef $$ClaimedRewardsTableUpdateCompanionBuilder =
    ClaimedRewardsCompanion Function({
      Value<String> playerId,
      Value<String> eventId,
      Value<int> claimedAtMs,
      Value<int> rowid,
    });

final class $$ClaimedRewardsTableReferences
    extends BaseReferences<_$AppDatabase, $ClaimedRewardsTable, ClaimedReward> {
  $$ClaimedRewardsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlayersTable _playerIdTable(_$AppDatabase db) =>
      db.players.createAlias('claimed_rewards__player_id__players__id');

  $$PlayersTableProcessedTableManager get playerId {
    final $_column = $_itemColumn<String>('player_id')!;

    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ClaimedRewardsTableFilterComposer
    extends Composer<_$AppDatabase, $ClaimedRewardsTable> {
  $$ClaimedRewardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get claimedAtMs => $composableBuilder(
    column: $table.claimedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  $$PlayersTableFilterComposer get playerId {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableFilterComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClaimedRewardsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClaimedRewardsTable> {
  $$ClaimedRewardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get claimedAtMs => $composableBuilder(
    column: $table.claimedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlayersTableOrderingComposer get playerId {
    final $$PlayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableOrderingComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClaimedRewardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClaimedRewardsTable> {
  $$ClaimedRewardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<int> get claimedAtMs => $composableBuilder(
    column: $table.claimedAtMs,
    builder: (column) => column,
  );

  $$PlayersTableAnnotationComposer get playerId {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClaimedRewardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClaimedRewardsTable,
          ClaimedReward,
          $$ClaimedRewardsTableFilterComposer,
          $$ClaimedRewardsTableOrderingComposer,
          $$ClaimedRewardsTableAnnotationComposer,
          $$ClaimedRewardsTableCreateCompanionBuilder,
          $$ClaimedRewardsTableUpdateCompanionBuilder,
          (ClaimedReward, $$ClaimedRewardsTableReferences),
          ClaimedReward,
          PrefetchHooks Function({bool playerId})
        > {
  $$ClaimedRewardsTableTableManager(
    _$AppDatabase db,
    $ClaimedRewardsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClaimedRewardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClaimedRewardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClaimedRewardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> playerId = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<int> claimedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClaimedRewardsCompanion(
                playerId: playerId,
                eventId: eventId,
                claimedAtMs: claimedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String playerId,
                required String eventId,
                required int claimedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => ClaimedRewardsCompanion.insert(
                playerId: playerId,
                eventId: eventId,
                claimedAtMs: claimedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ClaimedRewardsTable, ClaimedReward>(table),
                  $$ClaimedRewardsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playerId,
                        referencedTable: $$ClaimedRewardsTableReferences
                            ._playerIdTable(db),
                        referencedColumn: $$ClaimedRewardsTableReferences
                            ._playerIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ClaimedRewardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClaimedRewardsTable,
      ClaimedReward,
      $$ClaimedRewardsTableFilterComposer,
      $$ClaimedRewardsTableOrderingComposer,
      $$ClaimedRewardsTableAnnotationComposer,
      $$ClaimedRewardsTableCreateCompanionBuilder,
      $$ClaimedRewardsTableUpdateCompanionBuilder,
      (ClaimedReward, $$ClaimedRewardsTableReferences),
      ClaimedReward,
      PrefetchHooks Function({bool playerId})
    >;
typedef $$ShopPurchasesTableCreateCompanionBuilder =
    ShopPurchasesCompanion Function({
      required String playerId,
      required String entryId,
      Value<int> purchasedCount,
      Value<int> rowid,
    });
typedef $$ShopPurchasesTableUpdateCompanionBuilder =
    ShopPurchasesCompanion Function({
      Value<String> playerId,
      Value<String> entryId,
      Value<int> purchasedCount,
      Value<int> rowid,
    });

final class $$ShopPurchasesTableReferences
    extends BaseReferences<_$AppDatabase, $ShopPurchasesTable, ShopPurchase> {
  $$ShopPurchasesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlayersTable _playerIdTable(_$AppDatabase db) =>
      db.players.createAlias('shop_purchases__player_id__players__id');

  $$PlayersTableProcessedTableManager get playerId {
    final $_column = $_itemColumn<String>('player_id')!;

    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ShopPurchasesTableFilterComposer
    extends Composer<_$AppDatabase, $ShopPurchasesTable> {
  $$ShopPurchasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get purchasedCount => $composableBuilder(
    column: $table.purchasedCount,
    builder: (column) => ColumnFilters(column),
  );

  $$PlayersTableFilterComposer get playerId {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableFilterComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShopPurchasesTableOrderingComposer
    extends Composer<_$AppDatabase, $ShopPurchasesTable> {
  $$ShopPurchasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get purchasedCount => $composableBuilder(
    column: $table.purchasedCount,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlayersTableOrderingComposer get playerId {
    final $$PlayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableOrderingComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShopPurchasesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShopPurchasesTable> {
  $$ShopPurchasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<int> get purchasedCount => $composableBuilder(
    column: $table.purchasedCount,
    builder: (column) => column,
  );

  $$PlayersTableAnnotationComposer get playerId {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ShopPurchasesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ShopPurchasesTable,
          ShopPurchase,
          $$ShopPurchasesTableFilterComposer,
          $$ShopPurchasesTableOrderingComposer,
          $$ShopPurchasesTableAnnotationComposer,
          $$ShopPurchasesTableCreateCompanionBuilder,
          $$ShopPurchasesTableUpdateCompanionBuilder,
          (ShopPurchase, $$ShopPurchasesTableReferences),
          ShopPurchase,
          PrefetchHooks Function({bool playerId})
        > {
  $$ShopPurchasesTableTableManager(_$AppDatabase db, $ShopPurchasesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShopPurchasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShopPurchasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShopPurchasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> playerId = const Value.absent(),
                Value<String> entryId = const Value.absent(),
                Value<int> purchasedCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShopPurchasesCompanion(
                playerId: playerId,
                entryId: entryId,
                purchasedCount: purchasedCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String playerId,
                required String entryId,
                Value<int> purchasedCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ShopPurchasesCompanion.insert(
                playerId: playerId,
                entryId: entryId,
                purchasedCount: purchasedCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ShopPurchasesTable, ShopPurchase>(table),
                  $$ShopPurchasesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playerId,
                        referencedTable: $$ShopPurchasesTableReferences
                            ._playerIdTable(db),
                        referencedColumn: $$ShopPurchasesTableReferences
                            ._playerIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ShopPurchasesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ShopPurchasesTable,
      ShopPurchase,
      $$ShopPurchasesTableFilterComposer,
      $$ShopPurchasesTableOrderingComposer,
      $$ShopPurchasesTableAnnotationComposer,
      $$ShopPurchasesTableCreateCompanionBuilder,
      $$ShopPurchasesTableUpdateCompanionBuilder,
      (ShopPurchase, $$ShopPurchasesTableReferences),
      ShopPurchase,
      PrefetchHooks Function({bool playerId})
    >;
typedef $$ClockStatesTableCreateCompanionBuilder =
    ClockStatesCompanion Function({
      required String playerId,
      Value<int> lastSeenAtMs,
      Value<int> forwardJumpCount,
      Value<int> maxForwardJumpMs,
      Value<int> rowid,
    });
typedef $$ClockStatesTableUpdateCompanionBuilder =
    ClockStatesCompanion Function({
      Value<String> playerId,
      Value<int> lastSeenAtMs,
      Value<int> forwardJumpCount,
      Value<int> maxForwardJumpMs,
      Value<int> rowid,
    });

final class $$ClockStatesTableReferences
    extends BaseReferences<_$AppDatabase, $ClockStatesTable, ClockState> {
  $$ClockStatesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlayersTable _playerIdTable(_$AppDatabase db) =>
      db.players.createAlias('clock_states__player_id__players__id');

  $$PlayersTableProcessedTableManager get playerId {
    final $_column = $_itemColumn<String>('player_id')!;

    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ClockStatesTableFilterComposer
    extends Composer<_$AppDatabase, $ClockStatesTable> {
  $$ClockStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get lastSeenAtMs => $composableBuilder(
    column: $table.lastSeenAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get forwardJumpCount => $composableBuilder(
    column: $table.forwardJumpCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxForwardJumpMs => $composableBuilder(
    column: $table.maxForwardJumpMs,
    builder: (column) => ColumnFilters(column),
  );

  $$PlayersTableFilterComposer get playerId {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableFilterComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClockStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $ClockStatesTable> {
  $$ClockStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get lastSeenAtMs => $composableBuilder(
    column: $table.lastSeenAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get forwardJumpCount => $composableBuilder(
    column: $table.forwardJumpCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxForwardJumpMs => $composableBuilder(
    column: $table.maxForwardJumpMs,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlayersTableOrderingComposer get playerId {
    final $$PlayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableOrderingComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClockStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClockStatesTable> {
  $$ClockStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get lastSeenAtMs => $composableBuilder(
    column: $table.lastSeenAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get forwardJumpCount => $composableBuilder(
    column: $table.forwardJumpCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxForwardJumpMs => $composableBuilder(
    column: $table.maxForwardJumpMs,
    builder: (column) => column,
  );

  $$PlayersTableAnnotationComposer get playerId {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ClockStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClockStatesTable,
          ClockState,
          $$ClockStatesTableFilterComposer,
          $$ClockStatesTableOrderingComposer,
          $$ClockStatesTableAnnotationComposer,
          $$ClockStatesTableCreateCompanionBuilder,
          $$ClockStatesTableUpdateCompanionBuilder,
          (ClockState, $$ClockStatesTableReferences),
          ClockState,
          PrefetchHooks Function({bool playerId})
        > {
  $$ClockStatesTableTableManager(_$AppDatabase db, $ClockStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClockStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClockStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClockStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> playerId = const Value.absent(),
                Value<int> lastSeenAtMs = const Value.absent(),
                Value<int> forwardJumpCount = const Value.absent(),
                Value<int> maxForwardJumpMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClockStatesCompanion(
                playerId: playerId,
                lastSeenAtMs: lastSeenAtMs,
                forwardJumpCount: forwardJumpCount,
                maxForwardJumpMs: maxForwardJumpMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String playerId,
                Value<int> lastSeenAtMs = const Value.absent(),
                Value<int> forwardJumpCount = const Value.absent(),
                Value<int> maxForwardJumpMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClockStatesCompanion.insert(
                playerId: playerId,
                lastSeenAtMs: lastSeenAtMs,
                forwardJumpCount: forwardJumpCount,
                maxForwardJumpMs: maxForwardJumpMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ClockStatesTable, ClockState>(table),
                  $$ClockStatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playerId,
                        referencedTable: $$ClockStatesTableReferences
                            ._playerIdTable(db),
                        referencedColumn: $$ClockStatesTableReferences
                            ._playerIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ClockStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClockStatesTable,
      ClockState,
      $$ClockStatesTableFilterComposer,
      $$ClockStatesTableOrderingComposer,
      $$ClockStatesTableAnnotationComposer,
      $$ClockStatesTableCreateCompanionBuilder,
      $$ClockStatesTableUpdateCompanionBuilder,
      (ClockState, $$ClockStatesTableReferences),
      ClockState,
      PrefetchHooks Function({bool playerId})
    >;
typedef $$CurrenciesTableCreateCompanionBuilder = CurrenciesCompanion Function({
  required String playerId,
  required String currencyId,
  Value<int> amount,
  Value<int> rowid,
});
typedef $$CurrenciesTableUpdateCompanionBuilder = CurrenciesCompanion Function({
  Value<String> playerId,
  Value<String> currencyId,
  Value<int> amount,
  Value<int> rowid,
});

final class $$CurrenciesTableReferences
    extends BaseReferences<_$AppDatabase, $CurrenciesTable, Currency> {
  $$CurrenciesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlayersTable _playerIdTable(_$AppDatabase db) =>
      db.players.createAlias('currencies__player_id__players__id');

  $$PlayersTableProcessedTableManager get playerId {
    final $_column = $_itemColumn<String>('player_id')!;

    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CurrenciesTableFilterComposer
    extends Composer<_$AppDatabase, $CurrenciesTable> {
  $$CurrenciesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get currencyId => $composableBuilder(
    column: $table.currencyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  $$PlayersTableFilterComposer get playerId {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableFilterComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CurrenciesTableOrderingComposer
    extends Composer<_$AppDatabase, $CurrenciesTable> {
  $$CurrenciesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get currencyId => $composableBuilder(
    column: $table.currencyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlayersTableOrderingComposer get playerId {
    final $$PlayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableOrderingComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CurrenciesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CurrenciesTable> {
  $$CurrenciesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get currencyId => $composableBuilder(
    column: $table.currencyId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  $$PlayersTableAnnotationComposer get playerId {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CurrenciesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CurrenciesTable,
          Currency,
          $$CurrenciesTableFilterComposer,
          $$CurrenciesTableOrderingComposer,
          $$CurrenciesTableAnnotationComposer,
          $$CurrenciesTableCreateCompanionBuilder,
          $$CurrenciesTableUpdateCompanionBuilder,
          (Currency, $$CurrenciesTableReferences),
          Currency,
          PrefetchHooks Function({bool playerId})
        > {
  $$CurrenciesTableTableManager(_$AppDatabase db, $CurrenciesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CurrenciesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CurrenciesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CurrenciesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> playerId = const Value.absent(),
                Value<String> currencyId = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CurrenciesCompanion(
                playerId: playerId,
                currencyId: currencyId,
                amount: amount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String playerId,
                required String currencyId,
                Value<int> amount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CurrenciesCompanion.insert(
                playerId: playerId,
                currencyId: currencyId,
                amount: amount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CurrenciesTable, Currency>(table),
                  $$CurrenciesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playerId,
                        referencedTable: $$CurrenciesTableReferences
                            ._playerIdTable(db),
                        referencedColumn: $$CurrenciesTableReferences
                            ._playerIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CurrenciesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CurrenciesTable,
      Currency,
      $$CurrenciesTableFilterComposer,
      $$CurrenciesTableOrderingComposer,
      $$CurrenciesTableAnnotationComposer,
      $$CurrenciesTableCreateCompanionBuilder,
      $$CurrenciesTableUpdateCompanionBuilder,
      (Currency, $$CurrenciesTableReferences),
      Currency,
      PrefetchHooks Function({bool playerId})
    >;
typedef $$PeriodicQuestStatesTableCreateCompanionBuilder =
    PeriodicQuestStatesCompanion Function({
      required String playerId,
      required String questId,
      required String periodKey,
      required int completedAtMs,
      Value<int> rowid,
    });
typedef $$PeriodicQuestStatesTableUpdateCompanionBuilder =
    PeriodicQuestStatesCompanion Function({
      Value<String> playerId,
      Value<String> questId,
      Value<String> periodKey,
      Value<int> completedAtMs,
      Value<int> rowid,
    });

final class $$PeriodicQuestStatesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PeriodicQuestStatesTable,
          PeriodicQuestState
        > {
  $$PeriodicQuestStatesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlayersTable _playerIdTable(_$AppDatabase db) =>
      db.players.createAlias('periodic_quest_states__player_id__players__id');

  $$PlayersTableProcessedTableManager get playerId {
    final $_column = $_itemColumn<String>('player_id')!;

    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PeriodicQuestStatesTableFilterComposer
    extends Composer<_$AppDatabase, $PeriodicQuestStatesTable> {
  $$PeriodicQuestStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get questId => $composableBuilder(
    column: $table.questId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get periodKey => $composableBuilder(
    column: $table.periodKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAtMs => $composableBuilder(
    column: $table.completedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  $$PlayersTableFilterComposer get playerId {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableFilterComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PeriodicQuestStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $PeriodicQuestStatesTable> {
  $$PeriodicQuestStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get questId => $composableBuilder(
    column: $table.questId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get periodKey => $composableBuilder(
    column: $table.periodKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAtMs => $composableBuilder(
    column: $table.completedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlayersTableOrderingComposer get playerId {
    final $$PlayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableOrderingComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PeriodicQuestStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PeriodicQuestStatesTable> {
  $$PeriodicQuestStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get questId =>
      $composableBuilder(column: $table.questId, builder: (column) => column);

  GeneratedColumn<String> get periodKey =>
      $composableBuilder(column: $table.periodKey, builder: (column) => column);

  GeneratedColumn<int> get completedAtMs => $composableBuilder(
    column: $table.completedAtMs,
    builder: (column) => column,
  );

  $$PlayersTableAnnotationComposer get playerId {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PeriodicQuestStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PeriodicQuestStatesTable,
          PeriodicQuestState,
          $$PeriodicQuestStatesTableFilterComposer,
          $$PeriodicQuestStatesTableOrderingComposer,
          $$PeriodicQuestStatesTableAnnotationComposer,
          $$PeriodicQuestStatesTableCreateCompanionBuilder,
          $$PeriodicQuestStatesTableUpdateCompanionBuilder,
          (PeriodicQuestState, $$PeriodicQuestStatesTableReferences),
          PeriodicQuestState,
          PrefetchHooks Function({bool playerId})
        > {
  $$PeriodicQuestStatesTableTableManager(
    _$AppDatabase db,
    $PeriodicQuestStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeriodicQuestStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeriodicQuestStatesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PeriodicQuestStatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> playerId = const Value.absent(),
                Value<String> questId = const Value.absent(),
                Value<String> periodKey = const Value.absent(),
                Value<int> completedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeriodicQuestStatesCompanion(
                playerId: playerId,
                questId: questId,
                periodKey: periodKey,
                completedAtMs: completedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String playerId,
                required String questId,
                required String periodKey,
                required int completedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => PeriodicQuestStatesCompanion.insert(
                playerId: playerId,
                questId: questId,
                periodKey: periodKey,
                completedAtMs: completedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PeriodicQuestStatesTable, PeriodicQuestState>(
                    table,
                  ),
                  $$PeriodicQuestStatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playerId,
                        referencedTable: $$PeriodicQuestStatesTableReferences
                            ._playerIdTable(db),
                        referencedColumn: $$PeriodicQuestStatesTableReferences
                            ._playerIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PeriodicQuestStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PeriodicQuestStatesTable,
      PeriodicQuestState,
      $$PeriodicQuestStatesTableFilterComposer,
      $$PeriodicQuestStatesTableOrderingComposer,
      $$PeriodicQuestStatesTableAnnotationComposer,
      $$PeriodicQuestStatesTableCreateCompanionBuilder,
      $$PeriodicQuestStatesTableUpdateCompanionBuilder,
      (PeriodicQuestState, $$PeriodicQuestStatesTableReferences),
      PeriodicQuestState,
      PrefetchHooks Function({bool playerId})
    >;
typedef $$EventShopPurchasesTableCreateCompanionBuilder =
    EventShopPurchasesCompanion Function({
      required String playerId,
      required String entryId,
      required String periodKey,
      Value<int> purchasedCount,
      Value<int> rowid,
    });
typedef $$EventShopPurchasesTableUpdateCompanionBuilder =
    EventShopPurchasesCompanion Function({
      Value<String> playerId,
      Value<String> entryId,
      Value<String> periodKey,
      Value<int> purchasedCount,
      Value<int> rowid,
    });

final class $$EventShopPurchasesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $EventShopPurchasesTable,
          EventShopPurchase
        > {
  $$EventShopPurchasesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlayersTable _playerIdTable(_$AppDatabase db) =>
      db.players.createAlias('event_shop_purchases__player_id__players__id');

  $$PlayersTableProcessedTableManager get playerId {
    final $_column = $_itemColumn<String>('player_id')!;

    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EventShopPurchasesTableFilterComposer
    extends Composer<_$AppDatabase, $EventShopPurchasesTable> {
  $$EventShopPurchasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get periodKey => $composableBuilder(
    column: $table.periodKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get purchasedCount => $composableBuilder(
    column: $table.purchasedCount,
    builder: (column) => ColumnFilters(column),
  );

  $$PlayersTableFilterComposer get playerId {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableFilterComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EventShopPurchasesTableOrderingComposer
    extends Composer<_$AppDatabase, $EventShopPurchasesTable> {
  $$EventShopPurchasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get periodKey => $composableBuilder(
    column: $table.periodKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get purchasedCount => $composableBuilder(
    column: $table.purchasedCount,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlayersTableOrderingComposer get playerId {
    final $$PlayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableOrderingComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EventShopPurchasesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventShopPurchasesTable> {
  $$EventShopPurchasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<String> get periodKey =>
      $composableBuilder(column: $table.periodKey, builder: (column) => column);

  GeneratedColumn<int> get purchasedCount => $composableBuilder(
    column: $table.purchasedCount,
    builder: (column) => column,
  );

  $$PlayersTableAnnotationComposer get playerId {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EventShopPurchasesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventShopPurchasesTable,
          EventShopPurchase,
          $$EventShopPurchasesTableFilterComposer,
          $$EventShopPurchasesTableOrderingComposer,
          $$EventShopPurchasesTableAnnotationComposer,
          $$EventShopPurchasesTableCreateCompanionBuilder,
          $$EventShopPurchasesTableUpdateCompanionBuilder,
          (EventShopPurchase, $$EventShopPurchasesTableReferences),
          EventShopPurchase,
          PrefetchHooks Function({bool playerId})
        > {
  $$EventShopPurchasesTableTableManager(
    _$AppDatabase db,
    $EventShopPurchasesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventShopPurchasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventShopPurchasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventShopPurchasesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> playerId = const Value.absent(),
                Value<String> entryId = const Value.absent(),
                Value<String> periodKey = const Value.absent(),
                Value<int> purchasedCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventShopPurchasesCompanion(
                playerId: playerId,
                entryId: entryId,
                periodKey: periodKey,
                purchasedCount: purchasedCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String playerId,
                required String entryId,
                required String periodKey,
                Value<int> purchasedCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventShopPurchasesCompanion.insert(
                playerId: playerId,
                entryId: entryId,
                periodKey: periodKey,
                purchasedCount: purchasedCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EventShopPurchasesTable, EventShopPurchase>(
                    table,
                  ),
                  $$EventShopPurchasesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playerId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playerId,
                        referencedTable: $$EventShopPurchasesTableReferences
                            ._playerIdTable(db),
                        referencedColumn: $$EventShopPurchasesTableReferences
                            ._playerIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EventShopPurchasesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventShopPurchasesTable,
      EventShopPurchase,
      $$EventShopPurchasesTableFilterComposer,
      $$EventShopPurchasesTableOrderingComposer,
      $$EventShopPurchasesTableAnnotationComposer,
      $$EventShopPurchasesTableCreateCompanionBuilder,
      $$EventShopPurchasesTableUpdateCompanionBuilder,
      (EventShopPurchase, $$EventShopPurchasesTableReferences),
      EventShopPurchase,
      PrefetchHooks Function({bool playerId})
    >;
typedef $$CloudSyncStatesTableCreateCompanionBuilder =
    CloudSyncStatesCompanion Function({
      required String playerId,
      required String deviceId,
      Value<int> lastSyncedRevision,
      Value<String?> lastSyncedBlobSha256,
      Value<int?> lastSyncAtMs,
      Value<String?> lastRejectCode,
      Value<int?> lastRejectAtMs,
      Value<int?> serverOffsetMs,
      Value<int?> serverOffsetAtMs,
      Value<int> rowid,
    });
typedef $$CloudSyncStatesTableUpdateCompanionBuilder =
    CloudSyncStatesCompanion Function({
      Value<String> playerId,
      Value<String> deviceId,
      Value<int> lastSyncedRevision,
      Value<String?> lastSyncedBlobSha256,
      Value<int?> lastSyncAtMs,
      Value<String?> lastRejectCode,
      Value<int?> lastRejectAtMs,
      Value<int?> serverOffsetMs,
      Value<int?> serverOffsetAtMs,
      Value<int> rowid,
    });

class $$CloudSyncStatesTableFilterComposer
    extends Composer<_$AppDatabase, $CloudSyncStatesTable> {
  $$CloudSyncStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get playerId => $composableBuilder(
    column: $table.playerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncedRevision => $composableBuilder(
    column: $table.lastSyncedRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastSyncedBlobSha256 => $composableBuilder(
    column: $table.lastSyncedBlobSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncAtMs => $composableBuilder(
    column: $table.lastSyncAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastRejectCode => $composableBuilder(
    column: $table.lastRejectCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastRejectAtMs => $composableBuilder(
    column: $table.lastRejectAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverOffsetMs => $composableBuilder(
    column: $table.serverOffsetMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverOffsetAtMs => $composableBuilder(
    column: $table.serverOffsetAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CloudSyncStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $CloudSyncStatesTable> {
  $$CloudSyncStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get playerId => $composableBuilder(
    column: $table.playerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncedRevision => $composableBuilder(
    column: $table.lastSyncedRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastSyncedBlobSha256 => $composableBuilder(
    column: $table.lastSyncedBlobSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncAtMs => $composableBuilder(
    column: $table.lastSyncAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastRejectCode => $composableBuilder(
    column: $table.lastRejectCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastRejectAtMs => $composableBuilder(
    column: $table.lastRejectAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverOffsetMs => $composableBuilder(
    column: $table.serverOffsetMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverOffsetAtMs => $composableBuilder(
    column: $table.serverOffsetAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CloudSyncStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CloudSyncStatesTable> {
  $$CloudSyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get playerId =>
      $composableBuilder(column: $table.playerId, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get lastSyncedRevision => $composableBuilder(
    column: $table.lastSyncedRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastSyncedBlobSha256 => $composableBuilder(
    column: $table.lastSyncedBlobSha256,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSyncAtMs => $composableBuilder(
    column: $table.lastSyncAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastRejectCode => $composableBuilder(
    column: $table.lastRejectCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastRejectAtMs => $composableBuilder(
    column: $table.lastRejectAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverOffsetMs => $composableBuilder(
    column: $table.serverOffsetMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverOffsetAtMs => $composableBuilder(
    column: $table.serverOffsetAtMs,
    builder: (column) => column,
  );
}

class $$CloudSyncStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CloudSyncStatesTable,
          CloudSyncState,
          $$CloudSyncStatesTableFilterComposer,
          $$CloudSyncStatesTableOrderingComposer,
          $$CloudSyncStatesTableAnnotationComposer,
          $$CloudSyncStatesTableCreateCompanionBuilder,
          $$CloudSyncStatesTableUpdateCompanionBuilder,
          (
            CloudSyncState,
            BaseReferences<
              _$AppDatabase,
              $CloudSyncStatesTable,
              CloudSyncState
            >,
          ),
          CloudSyncState,
          PrefetchHooks Function()
        > {
  $$CloudSyncStatesTableTableManager(
    _$AppDatabase db,
    $CloudSyncStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CloudSyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CloudSyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CloudSyncStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> playerId = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> lastSyncedRevision = const Value.absent(),
                Value<String?> lastSyncedBlobSha256 = const Value.absent(),
                Value<int?> lastSyncAtMs = const Value.absent(),
                Value<String?> lastRejectCode = const Value.absent(),
                Value<int?> lastRejectAtMs = const Value.absent(),
                Value<int?> serverOffsetMs = const Value.absent(),
                Value<int?> serverOffsetAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CloudSyncStatesCompanion(
                playerId: playerId,
                deviceId: deviceId,
                lastSyncedRevision: lastSyncedRevision,
                lastSyncedBlobSha256: lastSyncedBlobSha256,
                lastSyncAtMs: lastSyncAtMs,
                lastRejectCode: lastRejectCode,
                lastRejectAtMs: lastRejectAtMs,
                serverOffsetMs: serverOffsetMs,
                serverOffsetAtMs: serverOffsetAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String playerId,
                required String deviceId,
                Value<int> lastSyncedRevision = const Value.absent(),
                Value<String?> lastSyncedBlobSha256 = const Value.absent(),
                Value<int?> lastSyncAtMs = const Value.absent(),
                Value<String?> lastRejectCode = const Value.absent(),
                Value<int?> lastRejectAtMs = const Value.absent(),
                Value<int?> serverOffsetMs = const Value.absent(),
                Value<int?> serverOffsetAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CloudSyncStatesCompanion.insert(
                playerId: playerId,
                deviceId: deviceId,
                lastSyncedRevision: lastSyncedRevision,
                lastSyncedBlobSha256: lastSyncedBlobSha256,
                lastSyncAtMs: lastSyncAtMs,
                lastRejectCode: lastRejectCode,
                lastRejectAtMs: lastRejectAtMs,
                serverOffsetMs: serverOffsetMs,
                serverOffsetAtMs: serverOffsetAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CloudSyncStatesTable, CloudSyncState>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CloudSyncStatesTable,
                    CloudSyncState
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CloudSyncStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CloudSyncStatesTable,
      CloudSyncState,
      $$CloudSyncStatesTableFilterComposer,
      $$CloudSyncStatesTableOrderingComposer,
      $$CloudSyncStatesTableAnnotationComposer,
      $$CloudSyncStatesTableCreateCompanionBuilder,
      $$CloudSyncStatesTableUpdateCompanionBuilder,
      (
        CloudSyncState,
        BaseReferences<_$AppDatabase, $CloudSyncStatesTable, CloudSyncState>,
      ),
      CloudSyncState,
      PrefetchHooks Function()
    >;
typedef $$LocalSaveBackupsTableCreateCompanionBuilder =
    LocalSaveBackupsCompanion Function({
      Value<int> id,
      required int createdAtMs,
      required String reason,
      required int schemaVersion,
      required String blobSha256,
      required Uint8List payload,
    });
typedef $$LocalSaveBackupsTableUpdateCompanionBuilder =
    LocalSaveBackupsCompanion Function({
      Value<int> id,
      Value<int> createdAtMs,
      Value<String> reason,
      Value<int> schemaVersion,
      Value<String> blobSha256,
      Value<Uint8List> payload,
    });

class $$LocalSaveBackupsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSaveBackupsTable> {
  $$LocalSaveBackupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blobSha256 => $composableBuilder(
    column: $table.blobSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalSaveBackupsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSaveBackupsTable> {
  $$LocalSaveBackupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blobSha256 => $composableBuilder(
    column: $table.blobSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSaveBackupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSaveBackupsTable> {
  $$LocalSaveBackupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get blobSha256 => $composableBuilder(
    column: $table.blobSha256,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$LocalSaveBackupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSaveBackupsTable,
          LocalSaveBackup,
          $$LocalSaveBackupsTableFilterComposer,
          $$LocalSaveBackupsTableOrderingComposer,
          $$LocalSaveBackupsTableAnnotationComposer,
          $$LocalSaveBackupsTableCreateCompanionBuilder,
          $$LocalSaveBackupsTableUpdateCompanionBuilder,
          (
            LocalSaveBackup,
            BaseReferences<
              _$AppDatabase,
              $LocalSaveBackupsTable,
              LocalSaveBackup
            >,
          ),
          LocalSaveBackup,
          PrefetchHooks Function()
        > {
  $$LocalSaveBackupsTableTableManager(
    _$AppDatabase db,
    $LocalSaveBackupsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSaveBackupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSaveBackupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSaveBackupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<String> blobSha256 = const Value.absent(),
                Value<Uint8List> payload = const Value.absent(),
              }) => LocalSaveBackupsCompanion(
                id: id,
                createdAtMs: createdAtMs,
                reason: reason,
                schemaVersion: schemaVersion,
                blobSha256: blobSha256,
                payload: payload,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int createdAtMs,
                required String reason,
                required int schemaVersion,
                required String blobSha256,
                required Uint8List payload,
              }) => LocalSaveBackupsCompanion.insert(
                id: id,
                createdAtMs: createdAtMs,
                reason: reason,
                schemaVersion: schemaVersion,
                blobSha256: blobSha256,
                payload: payload,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalSaveBackupsTable, LocalSaveBackup>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalSaveBackupsTable,
                    LocalSaveBackup
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSaveBackupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSaveBackupsTable,
      LocalSaveBackup,
      $$LocalSaveBackupsTableFilterComposer,
      $$LocalSaveBackupsTableOrderingComposer,
      $$LocalSaveBackupsTableAnnotationComposer,
      $$LocalSaveBackupsTableCreateCompanionBuilder,
      $$LocalSaveBackupsTableUpdateCompanionBuilder,
      (
        LocalSaveBackup,
        BaseReferences<_$AppDatabase, $LocalSaveBackupsTable, LocalSaveBackup>,
      ),
      LocalSaveBackup,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$GameSettingsTableTableManager get gameSettings =>
      $$GameSettingsTableTableManager(_db, _db.gameSettings);
  $$PlayersTableTableManager get players =>
      $$PlayersTableTableManager(_db, _db.players);
  $$SkillProgressesTableTableManager get skillProgresses =>
      $$SkillProgressesTableTableManager(_db, _db.skillProgresses);
  $$InventoryEntriesTableTableManager get inventoryEntries =>
      $$InventoryEntriesTableTableManager(_db, _db.inventoryEntries);
  $$EquipmentInstancesTableTableManager get equipmentInstances =>
      $$EquipmentInstancesTableTableManager(_db, _db.equipmentInstances);
  $$EquippedItemsTableTableManager get equippedItems =>
      $$EquippedItemsTableTableManager(_db, _db.equippedItems);
  $$DungeonProgressesTableTableManager get dungeonProgresses =>
      $$DungeonProgressesTableTableManager(_db, _db.dungeonProgresses);
  $$CycleProgressesTableTableManager get cycleProgresses =>
      $$CycleProgressesTableTableManager(_db, _db.cycleProgresses);
  $$GameSessionsTableTableManager get gameSessions =>
      $$GameSessionsTableTableManager(_db, _db.gameSessions);
  $$ClaimedRewardsTableTableManager get claimedRewards =>
      $$ClaimedRewardsTableTableManager(_db, _db.claimedRewards);
  $$ShopPurchasesTableTableManager get shopPurchases =>
      $$ShopPurchasesTableTableManager(_db, _db.shopPurchases);
  $$ClockStatesTableTableManager get clockStates =>
      $$ClockStatesTableTableManager(_db, _db.clockStates);
  $$CurrenciesTableTableManager get currencies =>
      $$CurrenciesTableTableManager(_db, _db.currencies);
  $$PeriodicQuestStatesTableTableManager get periodicQuestStates =>
      $$PeriodicQuestStatesTableTableManager(_db, _db.periodicQuestStates);
  $$EventShopPurchasesTableTableManager get eventShopPurchases =>
      $$EventShopPurchasesTableTableManager(_db, _db.eventShopPurchases);
  $$CloudSyncStatesTableTableManager get cloudSyncStates =>
      $$CloudSyncStatesTableTableManager(_db, _db.cloudSyncStates);
  $$LocalSaveBackupsTableTableManager get localSaveBackups =>
      $$LocalSaveBackupsTableTableManager(_db, _db.localSaveBackups);
}
