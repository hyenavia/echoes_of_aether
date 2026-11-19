import 'dart:collection';
import 'dart:convert';

import '../entities/clock_state.dart';
import '../entities/cycle_progress.dart';
import '../entities/equipment.dart';
import '../entities/event_shop_purchase.dart';
import '../entities/gacha_config.dart';
import '../entities/game_config.dart';
import '../entities/item_definition.dart';
import '../entities/offline_activity.dart';
import '../entities/periodic_quest_state.dart';
import '../entities/player_progress.dart';
import '../entities/player_save_snapshot.dart';
import 'claimed_rewards_pruner.dart';
import 'period_service.dart';

/// Jenis kegagalan kodek save cloud yang menyebabkan seluruh blob ditolak.
enum SaveCodecErrorCode {
  malformedJson,
  invalidStructure,
  unsupportedCodecVersion,
  invalidFieldType,
  invalidValueRange,
  unknownReferenceId,
  duplicateEquipmentId,
  slotMismatch,
}

/// Exception bertipe untuk kegagalan encode/decode/validasi snapshot cloud.
class SaveCodecException implements Exception {
  const SaveCodecException(this.code, this.message, {this.path});

  final SaveCodecErrorCode code;
  final String message;
  final String? path;

  @override
  String toString() =>
      'SaveCodecException($code${path == null ? '' : ' @ $path'}: $message)';
}

/// Kodek deterministik domain murni untuk mengubah [PlayerSaveSnapshot] menjadi
/// JSON kanonis versi 1 dan mendekodekannya secara ketat terhadap [GameConfig].
///
/// ### Daftar Final Field Disertakan vs Dikecualikan (`DESIGN_ADDENDUM_v1.3 §1.2`)
///
/// **Disertakan (canonical sorted JSON):**
/// - `codecVersion`, `playerId`
/// - `character`: `progress` (`level`, `currentExp`, `gold`), `specializationId`,
///   `skillLevels`, `skillCooldownTicks`, `equipped` (slot -> [EquipmentInstance]),
///   `currentHp`
/// - `inventory`: `stacks`, `equipment` (seluruh [EquipmentInstance] termasuk
///   `rolledStats` stat flat + stat persen `hpPct`/`atkPct`/`defPct` M13),
///   `equipmentCounter`
/// - `dungeon`, `dungeonProgresses` (termasuk `rewardState`)
/// - `cycleProgress` (`ascensionRank`, `highestAscensionRank`, `lastNormalDungeonId`)
/// - `session`: `autoSkillEnabled`, `consecutiveDefeats`, `lastFailedDungeonId`
/// - `claimedEventIds`: HANYA ID klaim permanen berawalan `ascension:`,
///   `shop:`, `bossquest:`, `eventshop:`
/// - `shopPurchases`, `eventShopPurchases`, `currencies`, `periodicQuestStates`
/// - `clockState` (`lastSeenAtMs`, `forwardJumpCount`, `maxForwardJumpMs`)
///
/// **Dikecualikan:**
/// - `activeDungeonSession` (sesi run dungeon aktif bersifat sementara per perangkat)
/// - `offlineActivity` (checkpoint & status pemrosesan offline sementara)
/// - Jangkar waktu offline sesi: `session.lastActiveAtMs`, `session.lastSavedAtMs`,
///   `session.lastOfflineClaimAtMs` (pada pemulihan disetel ke `restoredAtMs`)
/// - ID klaim sementara: `offline_kill:*`, `room_clear:*`, `dungeon_clear:*`,
///   `offline:*`, `enemy:*`
/// - `GameSettings` (pengaturan audio/bahasa/notifikasi lokal)
/// - `CloudSyncStates` dan `LocalSaveBackups` (metadata sinkronisasi & cadangan lokal)
class SaveSnapshotCodec {
  const SaveSnapshotCodec();

  static const int supportedCodecVersion = 1;

  static const List<String> permanentClaimPrefixes = [
    ...ClaimedRewardsPruner.neverPrunePrefixes,
    ...ClaimedRewardsPruner.periodScopedPrefixes,
  ];

  static bool isPermanentClaimId(String id) {
    for (final prefix in permanentClaimPrefixes) {
      if (id.startsWith(prefix)) return true;
    }
    return false;
  }

  /// Memeriksa apakah [dungeonId] valid, baik sebagai dungeon statis di
  /// [GameConfig.dungeons], Boss Event dinamis di [GameConfig.bossEvents]
  /// (`boss_daily:<id>` atau `boss_weekly:<id>`), maupun Menara Bos di
  /// [GameConfig.bossSpire] (`boss_spire:floor_<x>`).
  static bool isValidDungeonId(String dungeonId, GameConfig config) {
    if (config.dungeons.containsKey(dungeonId)) return true;
    final bossEvents = config.bossEvents;
    if (bossEvents != null) {
      if (dungeonId.startsWith('boss_daily:')) {
        final bossId = dungeonId.substring('boss_daily:'.length);
        return bossEvents.periodForBossId(bossId) == Period.daily;
      }
      if (dungeonId.startsWith('boss_weekly:')) {
        final bossId = dungeonId.substring('boss_weekly:'.length);
        return bossEvents.periodForBossId(bossId) == Period.weekly;
      }
    }
    final bossSpire = config.bossSpire;
    if (bossSpire != null) {
      if (dungeonId == bossSpire.spireId) return true;
      if (dungeonId.startsWith('boss_spire:floor_')) {
        final floorStr = dungeonId.substring('boss_spire:floor_'.length);
        final floor = int.tryParse(floorStr);
        return floor != null && bossSpire.hasFloor(floor);
      }
    }
    return false;
  }

  /// Mengubah [snapshot] menjadi JSON kanonis deterministik (kunci terurut,
  /// tanpa whitespace tambahan, koleksi terurut stabil).
  String encodeToCanonicalJson(PlayerSaveSnapshot snapshot) =>
      jsonEncode(encodeToMap(snapshot));

  /// Mengubah [snapshot] menjadi struktur [Map] kanonis deterministik.
  Map<String, dynamic> encodeToMap(PlayerSaveSnapshot snapshot) {
    final sortedSkillLevels = _sortedIntMap(snapshot.character.skillLevels);
    final sortedSkillCooldowns = _sortedIntMap(
      snapshot.character.skillCooldownTicks,
    );

    final equippedMap = SplayTreeMap<String, dynamic>();
    final equippedEntries = snapshot.character.equipped.entries.toList()
      ..sort((a, b) => a.key.name.compareTo(b.key.name));
    for (final entry in equippedEntries) {
      equippedMap[entry.key.name] = _encodeEquipment(entry.value);
    }

    final sortedEquipmentBag = [...snapshot.inventory.equipment]
      ..sort((a, b) => a.id.compareTo(b.id));

    final sortedDungeonProgresses = SplayTreeMap<String, dynamic>();
    final dpEntries = snapshot.dungeonProgresses.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final entry in dpEntries) {
      sortedDungeonProgresses[entry.key] = _encodeDungeonProgress(entry.value);
    }

    final sortedPermanentClaims =
        snapshot.claimedEventIds.where(isPermanentClaimId).toList()..sort();

    final sortedEventShop = [...snapshot.eventShopPurchases]
      ..sort((a, b) {
        final byEntry = a.entryId.compareTo(b.entryId);
        return byEntry != 0 ? byEntry : a.periodKey.compareTo(b.periodKey);
      });

    final sortedQuests = [...snapshot.periodicQuestStates]
      ..sort((a, b) {
        final byQuest = a.questId.compareTo(b.questId);
        return byQuest != 0 ? byQuest : a.periodKey.compareTo(b.periodKey);
      });

    return _sortedMap({
      'character': _sortedMap({
        'currentHp': snapshot.character.currentHp,
        'equipped': equippedMap,
        'progress': _sortedMap({
          'currentExp': snapshot.character.progress.currentExp,
          'gold': snapshot.character.progress.gold,
          'level': snapshot.character.progress.level,
        }),
        'skillCooldownTicks': sortedSkillCooldowns,
        'skillLevels': sortedSkillLevels,
        'specializationId': snapshot.character.specializationId,
      }),
      'claimedEventIds': sortedPermanentClaims,
      'clockState': _sortedMap({
        'forwardJumpCount': snapshot.clockState.forwardJumpCount,
        'lastSeenAtMs': snapshot.clockState.lastSeenAtMs,
        'maxForwardJumpMs': snapshot.clockState.maxForwardJumpMs,
      }),
      'codecVersion': supportedCodecVersion,
      'currencies': _sortedIntMap(snapshot.currencies),
      'cycleProgress': _sortedMap({
        'ascensionRank': snapshot.cycleProgress.ascensionRank,
        'highestAscensionRank': snapshot.cycleProgress.highestAscensionRank,
        'lastNormalDungeonId': snapshot.cycleProgress.lastNormalDungeonId,
      }),
      'dungeon': _encodeDungeonProgress(snapshot.dungeon),
      'dungeonProgresses': sortedDungeonProgresses,
      'eventShopPurchases': [
        for (final record in sortedEventShop)
          _sortedMap({
            'entryId': record.entryId,
            'periodKey': record.periodKey,
            'purchasedCount': record.purchasedCount,
          }),
      ],
      'inventory': _sortedMap({
        'equipment': [
          for (final item in sortedEquipmentBag) _encodeEquipment(item),
        ],
        'equipmentCounter': snapshot.inventory.equipmentCounter,
        'stacks': _sortedIntMap(snapshot.inventory.stacks),
      }),
      'periodicQuestStates': [
        for (final quest in sortedQuests)
          _sortedMap({
            'completedAtMs': quest.completedAtMs,
            'periodKey': quest.periodKey,
            'questId': quest.questId,
          }),
      ],
      'playerId': snapshot.playerId,
      'gachaPityStates': _sortedMap({
        for (final p in snapshot.gachaPityStates.entries)
          p.key: _sortedMap({
            'bannerType': p.value.bannerType,
            'isGuaranteed': p.value.isGuaranteed,
            'pullCount': p.value.pullCount,
          }),
      }),
      'unlockedSpecializations': snapshot.unlockedSpecializations.toList()
        ..sort(),
      'session': _sortedMap({
        'autoSkillEnabled': snapshot.session.autoSkillEnabled,
        'consecutiveDefeats': _sortedIntMap(
          snapshot.session.consecutiveDefeats,
        ),
        'lastFailedDungeonId': snapshot.session.lastFailedDungeonId,
      }),
      'shopPurchases': _sortedIntMap(snapshot.shopPurchases),
    });
  }

  /// Mendekode JSON kanonis menjadi [PlayerSaveSnapshot] secara ketat terhadap
  /// [config]. Setiap ketidakcocokan versi, struktur, rentang nilai, atau ID
  /// referensi melempar [SaveCodecException] tanpa perbaikan sebagian.
  PlayerSaveSnapshot decodeFromCanonicalJson(
    String source, {
    required GameConfig config,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (e) {
      throw SaveCodecException(
        SaveCodecErrorCode.malformedJson,
        'JSON save rusak: ${e.message}',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const SaveCodecException(
        SaveCodecErrorCode.invalidStructure,
        'Root JSON save harus berupa object.',
      );
    }
    return decodeFromMap(decoded, config: config);
  }

  /// Mendekode [Map] terstruktur menjadi [PlayerSaveSnapshot] secara ketat
  /// terhadap [config].
  PlayerSaveSnapshot decodeFromMap(
    Map<String, dynamic> root, {
    required GameConfig config,
  }) {
    const allowedRootKeys = {
      'character',
      'claimedEventIds',
      'clockState',
      'codecVersion',
      'currencies',
      'cycleProgress',
      'dungeon',
      'dungeonProgresses',
      'eventShopPurchases',
      'gachaPityStates',
      'inventory',
      'periodicQuestStates',
      'playerId',
      'session',
      'shopPurchases',
      'unlockedSpecializations',
    };
    _rejectUnknownKeys(root, allowedRootKeys, 'root');

    final codecVersion = _requireInt(
      root,
      'codecVersion',
      path: 'codecVersion',
    );
    if (codecVersion < 1) {
      throw SaveCodecException(
        SaveCodecErrorCode.invalidValueRange,
        'codecVersion harus >= 1 (nilai: $codecVersion).',
        path: 'codecVersion',
      );
    }
    if (codecVersion > supportedCodecVersion) {
      throw SaveCodecException(
        SaveCodecErrorCode.unsupportedCodecVersion,
        'codecVersion $codecVersion lebih baru daripada versi didukung ($supportedCodecVersion).',
        path: 'codecVersion',
      );
    }

    final playerId = _requireNonEmptyString(root, 'playerId', path: 'playerId');

    final seenEquipmentIds = <String>{};
    final character = _decodeCharacter(
      _requireMap(root, 'character', path: 'character'),
      config: config,
      seenEquipmentIds: seenEquipmentIds,
    );
    final inventory = _decodeInventory(
      _requireMap(root, 'inventory', path: 'inventory'),
      config: config,
      seenEquipmentIds: seenEquipmentIds,
    );
    final dungeon = _decodeDungeonProgress(
      _requireMap(root, 'dungeon', path: 'dungeon'),
      config: config,
      path: 'dungeon',
    );
    final dungeonProgresses = _decodeDungeonProgresses(
      _requireMap(root, 'dungeonProgresses', path: 'dungeonProgresses'),
      config: config,
    );
    final cycleProgress = _decodeCycleProgress(
      _requireMap(root, 'cycleProgress', path: 'cycleProgress'),
      config: config,
    );
    final session = _decodeSession(
      _requireMap(root, 'session', path: 'session'),
      playerId: playerId,
      config: config,
    );
    final claimedEventIds = _decodeClaimedEventIds(
      _requireList(root, 'claimedEventIds', path: 'claimedEventIds'),
    );
    final shopPurchases = _decodeShopPurchases(
      _requireMap(root, 'shopPurchases', path: 'shopPurchases'),
      config: config,
    );
    final eventShopPurchases = _decodeEventShopPurchases(
      _requireList(root, 'eventShopPurchases', path: 'eventShopPurchases'),
      config: config,
    );
    final currencies = _decodeCurrencies(
      _requireMap(root, 'currencies', path: 'currencies'),
      config: config,
    );
    final clockState = _decodeClockState(
      _requireMap(root, 'clockState', path: 'clockState'),
    );
    final periodicQuestStates = _decodePeriodicQuestStates(
      _requireList(root, 'periodicQuestStates', path: 'periodicQuestStates'),
      config: config,
    );
    final gachaPityStates = _decodeGachaPityStates(
      root['gachaPityStates'] == null
          ? const {}
          : _requireMap(root, 'gachaPityStates', path: 'gachaPityStates'),
    );
    final unlockedSpecializations = _decodeUnlockedSpecializations(
      root['unlockedSpecializations'] == null
          ? const ['vanguard', 'arcanist', 'ranger']
          : _requireList(
              root,
              'unlockedSpecializations',
              path: 'unlockedSpecializations',
            ),
      config: config,
    );

    return PlayerSaveSnapshot(
      playerId: playerId,
      character: character,
      inventory: inventory,
      dungeon: dungeon,
      dungeonProgresses: dungeonProgresses,
      cycleProgress: cycleProgress,
      session: session,
      claimedEventIds: claimedEventIds,
      activeDungeonSession: null,
      offlineActivity: const OfflineActivitySnapshot.paused(),
      shopPurchases: shopPurchases,
      eventShopPurchases: eventShopPurchases,
      currencies: currencies,
      clockState: clockState,
      periodicQuestStates: periodicQuestStates,
      gachaPityStates: gachaPityStates,
      unlockedSpecializations: unlockedSpecializations,
    );
  }

  Map<String, dynamic> _encodeEquipment(EquipmentInstance item) => _sortedMap({
    'definitionId': item.definitionId,
    'enhancementLevel': item.enhancementLevel,
    'id': item.id,
    'isFavorite': item.isFavorite,
    'rarity': item.rarity.name,
    'rolledStats': _sortedMap({
      'atk': _normDouble(item.rolledStats.atk),
      'atkPct': _normDouble(item.rolledStats.atkPct),
      'attackRange': _normDouble(item.rolledStats.attackRange),
      'attackSpeed': _normDouble(item.rolledStats.attackSpeed),
      'critDamage': _normDouble(item.rolledStats.critDamage),
      'critRate': _normDouble(item.rolledStats.critRate),
      'def': _normDouble(item.rolledStats.def),
      'defPct': _normDouble(item.rolledStats.defPct),
      'hp': _normDouble(item.rolledStats.hp),
      'hpPct': _normDouble(item.rolledStats.hpPct),
      'lifesteal': _normDouble(item.rolledStats.lifesteal),
      'moveSpeed': _normDouble(item.rolledStats.moveSpeed),
      'skillHaste': _normDouble(item.rolledStats.skillHaste),
      'spellVamp': _normDouble(item.rolledStats.spellVamp),
    }),
    'slot': item.slot.name,
  });

  Map<String, dynamic> _encodeDungeonProgress(DungeonProgressSnapshot p) {
    final sortedRoomIds = p.rewardState.claimedRoomRewardIds.toList()..sort();
    return _sortedMap({
      'clearedInCycleRank': p.clearedInCycleRank,
      'clearsCount': p.clearsCount,
      'currentDungeonId': p.currentDungeonId,
      'currentRoomId': p.currentRoomId,
      'currentRoomIndex': p.currentRoomIndex,
      'highestClearedRoomIndex': p.highestClearedRoomIndex,
      'rewardState': _sortedMap({
        'claimedRoomRewardIds': sortedRoomIds,
        'completionRewardClaimed': p.rewardState.completionRewardClaimed,
        'lastRunId': p.rewardState.lastRunId,
      }),
    });
  }

  PlayerCharacterSnapshot _decodeCharacter(
    Map<String, dynamic> map, {
    required GameConfig config,
    required Set<String> seenEquipmentIds,
  }) {
    _rejectUnknownKeys(map, const {
      'currentHp',
      'equipped',
      'progress',
      'skillCooldownTicks',
      'skillLevels',
      'specializationId',
    }, 'character');

    final progressMap = _requireMap(
      map,
      'progress',
      path: 'character.progress',
    );
    _rejectUnknownKeys(progressMap, const {
      'currentExp',
      'gold',
      'level',
    }, 'character.progress');

    final level = _requireInt(
      progressMap,
      'level',
      path: 'character.progress.level',
      min: 1,
    );
    final currentExp = _requireInt(
      progressMap,
      'currentExp',
      path: 'character.progress.currentExp',
      min: 0,
    );
    final gold = _requireInt(
      progressMap,
      'gold',
      path: 'character.progress.gold',
      min: 0,
    );

    final specializationId = _optionalNonEmptyString(
      map,
      'specializationId',
      path: 'character.specializationId',
    );
    if (specializationId != null &&
        !config.specializations.definitions.containsKey(specializationId)) {
      throw SaveCodecException(
        SaveCodecErrorCode.unknownReferenceId,
        'Specialization "$specializationId" tidak ada dalam konfigurasi.',
        path: 'character.specializationId',
      );
    }

    final currentHp = _optionalInt(
      map,
      'currentHp',
      path: 'character.currentHp',
      min: 0,
    );

    final skillLevels = _decodeSkillIntMap(
      _requireMap(map, 'skillLevels', path: 'character.skillLevels'),
      config: config,
      path: 'character.skillLevels',
      min: 0,
    );
    final skillCooldownTicks = _decodeSkillIntMap(
      _requireMap(
        map,
        'skillCooldownTicks',
        path: 'character.skillCooldownTicks',
      ),
      config: config,
      path: 'character.skillCooldownTicks',
      min: 0,
    );

    final equippedRaw = _requireMap(
      map,
      'equipped',
      path: 'character.equipped',
    );
    final equipped = <EquipmentSlot, EquipmentInstance>{};
    for (final entry in equippedRaw.entries) {
      final slot = _parseEquipmentSlot(
        entry.key,
        path: 'character.equipped.${entry.key}',
      );
      final rawInstance = entry.value;
      if (rawInstance is! Map<String, dynamic>) {
        throw SaveCodecException(
          SaveCodecErrorCode.invalidFieldType,
          'Entri equipped harus berupa object.',
          path: 'character.equipped.${entry.key}',
        );
      }
      final instance = _decodeEquipment(
        rawInstance,
        config: config,
        seenEquipmentIds: seenEquipmentIds,
        path: 'character.equipped.${entry.key}',
      );
      if (instance.slot != slot) {
        throw SaveCodecException(
          SaveCodecErrorCode.slotMismatch,
          'Slot instance (${instance.slot.name}) tidak cocok dengan slot map (${slot.name}).',
          path: 'character.equipped.${entry.key}',
        );
      }
      equipped[slot] = instance;
    }

    return PlayerCharacterSnapshot(
      progress: PlayerProgress(
        level: level,
        currentExp: currentExp,
        gold: gold,
      ),
      specializationId: specializationId,
      skillLevels: Map.unmodifiable(skillLevels),
      skillCooldownTicks: Map.unmodifiable(skillCooldownTicks),
      equipped: Map.unmodifiable(equipped),
      currentHp: currentHp,
    );
  }

  InventorySnapshot _decodeInventory(
    Map<String, dynamic> map, {
    required GameConfig config,
    required Set<String> seenEquipmentIds,
  }) {
    _rejectUnknownKeys(map, const {
      'equipment',
      'equipmentCounter',
      'stacks',
    }, 'inventory');

    final equipmentCounter = _requireInt(
      map,
      'equipmentCounter',
      path: 'inventory.equipmentCounter',
      min: 0,
    );

    final rawStacks = _requireMap(map, 'stacks', path: 'inventory.stacks');
    final stacks = <String, int>{};
    for (final entry in rawStacks.entries) {
      final itemId = entry.key;
      if (!config.items.containsKey(itemId)) {
        throw SaveCodecException(
          SaveCodecErrorCode.unknownReferenceId,
          'Item stack "$itemId" tidak dikenal di items.json.',
          path: 'inventory.stacks.$itemId',
        );
      }
      final count = _asInt(
        entry.value,
        path: 'inventory.stacks.$itemId',
        min: 0,
      );
      stacks[itemId] = count;
    }

    final rawEquipment = _requireList(
      map,
      'equipment',
      path: 'inventory.equipment',
    );
    final equipment = <EquipmentInstance>[];
    for (var i = 0; i < rawEquipment.length; i++) {
      final rawItem = rawEquipment[i];
      if (rawItem is! Map<String, dynamic>) {
        throw SaveCodecException(
          SaveCodecErrorCode.invalidFieldType,
          'Entri equipment[$i] harus berupa object.',
          path: 'inventory.equipment[$i]',
        );
      }
      equipment.add(
        _decodeEquipment(
          rawItem,
          config: config,
          seenEquipmentIds: seenEquipmentIds,
          path: 'inventory.equipment[$i]',
        ),
      );
    }

    return InventorySnapshot(
      stacks: Map.unmodifiable(stacks),
      equipment: List.unmodifiable(equipment),
      equipmentCounter: equipmentCounter,
    );
  }

  EquipmentInstance _decodeEquipment(
    Map<String, dynamic> map, {
    required GameConfig config,
    required Set<String> seenEquipmentIds,
    required String path,
  }) {
    _rejectUnknownKeys(map, const {
      'definitionId',
      'enhancementLevel',
      'id',
      'isFavorite',
      'rarity',
      'rolledStats',
      'slot',
    }, path);

    final id = _requireNonEmptyString(map, 'id', path: '$path.id');
    if (!seenEquipmentIds.add(id)) {
      throw SaveCodecException(
        SaveCodecErrorCode.duplicateEquipmentId,
        'Duplikat id equipment "$id".',
        path: '$path.id',
      );
    }

    final definitionId = _requireNonEmptyString(
      map,
      'definitionId',
      path: '$path.definitionId',
    );
    final def = config.items[definitionId];
    if (def == null) {
      throw SaveCodecException(
        SaveCodecErrorCode.unknownReferenceId,
        'definitionId "$definitionId" tidak ada di items.json.',
        path: '$path.definitionId',
      );
    }
    if (!def.isEquipment) {
      throw SaveCodecException(
        SaveCodecErrorCode.invalidStructure,
        'Item "$definitionId" bukan kategori equipment.',
        path: '$path.definitionId',
      );
    }

    final slot = _parseEquipmentSlot(
      _requireNonEmptyString(map, 'slot', path: '$path.slot'),
      path: '$path.slot',
    );
    if (def.equipment != null && def.equipment!.slot != slot) {
      throw SaveCodecException(
        SaveCodecErrorCode.slotMismatch,
        'Slot "${slot.name}" tidak cocok dengan definisi "${def.equipment!.slot.name}".',
        path: '$path.slot',
      );
    }

    final rarity = _parseRarity(
      _requireNonEmptyString(map, 'rarity', path: '$path.rarity'),
      path: '$path.rarity',
    );
    final enhancementLevel = _requireInt(
      map,
      'enhancementLevel',
      path: '$path.enhancementLevel',
      min: 0,
    );
    final statsMap = _requireMap(map, 'rolledStats', path: '$path.rolledStats');
    _rejectUnknownKeys(statsMap, const {
      'atk',
      'atkPct',
      'attackRange',
      'attackSpeed',
      'critDamage',
      'critRate',
      'def',
      'defPct',
      'hp',
      'hpPct',
      'lifesteal',
      'moveSpeed',
      'skillHaste',
      'spellVamp',
    }, '$path.rolledStats');

    double stat(String key) => _requireNonNegativeFiniteDouble(
      statsMap,
      key,
      path: '$path.rolledStats',
    );
    double optionalStat(String key) => statsMap.containsKey(key)
        ? _requireNonNegativeFiniteDouble(
            statsMap,
            key,
            path: '$path.rolledStats',
          )
        : 0.0;

    final isFavorite = map.containsKey('isFavorite')
        ? (map['isFavorite'] is bool
              ? map['isFavorite'] as bool
              : throw SaveCodecException(
                  SaveCodecErrorCode.invalidFieldType,
                  'Field "isFavorite" harus boolean.',
                  path: '$path.isFavorite',
                ))
        : false;

    return EquipmentInstance(
      id: id,
      definitionId: definitionId,
      slot: slot,
      rarity: rarity,
      enhancementLevel: enhancementLevel,
      isFavorite: isFavorite,
      rolledStats: EquipmentStats(
        hp: stat('hp'),
        atk: stat('atk'),
        def: stat('def'),
        hpPct: stat('hpPct'),
        atkPct: stat('atkPct'),
        defPct: stat('defPct'),
        critRate: stat('critRate'),
        critDamage: stat('critDamage'),
        attackSpeed: stat('attackSpeed'),
        moveSpeed: stat('moveSpeed'),
        attackRange: stat('attackRange'),
        skillHaste: stat('skillHaste'),
        lifesteal: optionalStat('lifesteal'),
        spellVamp: optionalStat('spellVamp'),
      ),
    );
  }

  DungeonProgressSnapshot _decodeDungeonProgress(
    Map<String, dynamic> map, {
    required GameConfig config,
    required String path,
  }) {
    _rejectUnknownKeys(map, const {
      'clearedInCycleRank',
      'clearsCount',
      'currentDungeonId',
      'currentRoomId',
      'currentRoomIndex',
      'highestClearedRoomIndex',
      'rewardState',
    }, path);

    final currentDungeonId = _requireNonEmptyString(
      map,
      'currentDungeonId',
      path: '$path.currentDungeonId',
    );
    if (!isValidDungeonId(currentDungeonId, config)) {
      throw SaveCodecException(
        SaveCodecErrorCode.unknownReferenceId,
        'Dungeon "$currentDungeonId" tidak ada dalam konfigurasi.',
        path: '$path.currentDungeonId',
      );
    }

    final currentRoomId = _requireNonEmptyString(
      map,
      'currentRoomId',
      path: '$path.currentRoomId',
    );
    final currentRoomIndex = _requireInt(
      map,
      'currentRoomIndex',
      path: '$path.currentRoomIndex',
      min: 0,
    );
    final highestClearedRoomIndex = _requireInt(
      map,
      'highestClearedRoomIndex',
      path: '$path.highestClearedRoomIndex',
      min: -1,
    );
    final clearsCount = _requireInt(
      map,
      'clearsCount',
      path: '$path.clearsCount',
      min: 0,
    );
    final clearedInCycleRank = _requireInt(
      map,
      'clearedInCycleRank',
      path: '$path.clearedInCycleRank',
      min: -1,
    );

    final rewardMap = _requireMap(
      map,
      'rewardState',
      path: '$path.rewardState',
    );
    _rejectUnknownKeys(rewardMap, const {
      'claimedRoomRewardIds',
      'completionRewardClaimed',
      'lastRunId',
    }, '$path.rewardState');

    final lastRunId = _optionalNonEmptyString(
      rewardMap,
      'lastRunId',
      path: '$path.rewardState.lastRunId',
    );
    final completionRewardClaimed = _requireBool(
      rewardMap,
      'completionRewardClaimed',
      path: '$path.rewardState.completionRewardClaimed',
    );
    final rawRoomIds = _requireList(
      rewardMap,
      'claimedRoomRewardIds',
      path: '$path.rewardState.claimedRoomRewardIds',
    );
    final claimedRoomRewardIds = <String>{};
    for (var i = 0; i < rawRoomIds.length; i++) {
      final raw = rawRoomIds[i];
      if (raw is! String || raw.trim().isEmpty) {
        throw SaveCodecException(
          SaveCodecErrorCode.invalidFieldType,
          'claimedRoomRewardIds[$i] harus berupa teks non-kosong.',
          path: '$path.rewardState.claimedRoomRewardIds[$i]',
        );
      }
      claimedRoomRewardIds.add(raw);
    }

    return DungeonProgressSnapshot(
      currentDungeonId: currentDungeonId,
      currentRoomId: currentRoomId,
      currentRoomIndex: currentRoomIndex,
      highestClearedRoomIndex: highestClearedRoomIndex,
      clearsCount: clearsCount,
      clearedInCycleRank: clearedInCycleRank,
      rewardState: DungeonRewardStateSnapshot(
        lastRunId: lastRunId,
        completionRewardClaimed: completionRewardClaimed,
        claimedRoomRewardIds: Set.unmodifiable(claimedRoomRewardIds),
      ),
    );
  }

  Map<String, DungeonProgressSnapshot> _decodeDungeonProgresses(
    Map<String, dynamic> map, {
    required GameConfig config,
  }) {
    final result = <String, DungeonProgressSnapshot>{};
    for (final entry in map.entries) {
      final dungeonId = entry.key;
      if (!isValidDungeonId(dungeonId, config)) {
        throw SaveCodecException(
          SaveCodecErrorCode.unknownReferenceId,
          'Dungeon "$dungeonId" di dungeonProgresses tidak ada dalam konfigurasi.',
          path: 'dungeonProgresses.$dungeonId',
        );
      }
      final raw = entry.value;
      if (raw is! Map<String, dynamic>) {
        throw SaveCodecException(
          SaveCodecErrorCode.invalidFieldType,
          'Entri dungeonProgresses.$dungeonId harus berupa object.',
          path: 'dungeonProgresses.$dungeonId',
        );
      }
      result[dungeonId] = _decodeDungeonProgress(
        raw,
        config: config,
        path: 'dungeonProgresses.$dungeonId',
      );
    }
    return Map.unmodifiable(result);
  }

  CycleProgress _decodeCycleProgress(
    Map<String, dynamic> map, {
    required GameConfig config,
  }) {
    _rejectUnknownKeys(map, const {
      'ascensionRank',
      'highestAscensionRank',
      'lastNormalDungeonId',
    }, 'cycleProgress');

    final ascensionRank = _requireInt(
      map,
      'ascensionRank',
      path: 'cycleProgress.ascensionRank',
      min: 0,
    );
    final highestAscensionRank = _requireInt(
      map,
      'highestAscensionRank',
      path: 'cycleProgress.highestAscensionRank',
      min: ascensionRank,
    );
    final lastNormalDungeonId = _optionalNonEmptyString(
      map,
      'lastNormalDungeonId',
      path: 'cycleProgress.lastNormalDungeonId',
    );
    if (lastNormalDungeonId != null &&
        !config.dungeons.containsKey(lastNormalDungeonId)) {
      throw SaveCodecException(
        SaveCodecErrorCode.unknownReferenceId,
        'lastNormalDungeonId "$lastNormalDungeonId" tidak ada dalam konfigurasi.',
        path: 'cycleProgress.lastNormalDungeonId',
      );
    }
    return CycleProgress(
      ascensionRank: ascensionRank,
      highestAscensionRank: highestAscensionRank,
      lastNormalDungeonId: lastNormalDungeonId,
    );
  }

  GameSessionSnapshot _decodeSession(
    Map<String, dynamic> map, {
    required String playerId,
    required GameConfig config,
  }) {
    _rejectUnknownKeys(map, const {
      'autoSkillEnabled',
      'consecutiveDefeats',
      'lastFailedDungeonId',
    }, 'session');

    final autoSkillEnabled = _requireBool(
      map,
      'autoSkillEnabled',
      path: 'session.autoSkillEnabled',
    );
    final rawDefeats = _requireMap(
      map,
      'consecutiveDefeats',
      path: 'session.consecutiveDefeats',
    );
    final consecutiveDefeats = <String, int>{};
    for (final entry in rawDefeats.entries) {
      if (!isValidDungeonId(entry.key, config)) {
        throw SaveCodecException(
          SaveCodecErrorCode.unknownReferenceId,
          'Dungeon "${entry.key}" pada consecutiveDefeats tidak ada dalam konfigurasi.',
          path: 'session.consecutiveDefeats.${entry.key}',
        );
      }
      consecutiveDefeats[entry.key] = _asInt(
        entry.value,
        path: 'session.consecutiveDefeats.${entry.key}',
        min: 0,
      );
    }

    final lastFailedDungeonId = _optionalNonEmptyString(
      map,
      'lastFailedDungeonId',
      path: 'session.lastFailedDungeonId',
    );
    if (lastFailedDungeonId != null &&
        !isValidDungeonId(lastFailedDungeonId, config)) {
      throw SaveCodecException(
        SaveCodecErrorCode.unknownReferenceId,
        'lastFailedDungeonId "$lastFailedDungeonId" tidak ada dalam konfigurasi.',
        path: 'session.lastFailedDungeonId',
      );
    }

    return GameSessionSnapshot(
      playerId: playerId,
      lastActiveAtMs: 0,
      lastSavedAtMs: 0,
      lastOfflineClaimAtMs: 0,
      autoSkillEnabled: autoSkillEnabled,
      consecutiveDefeats: Map.unmodifiable(consecutiveDefeats),
      lastFailedDungeonId: lastFailedDungeonId,
    );
  }

  Set<String> _decodeClaimedEventIds(List<dynamic> list) {
    final result = <String>{};
    for (var i = 0; i < list.length; i++) {
      final raw = list[i];
      if (raw is! String || raw.trim().isEmpty) {
        throw SaveCodecException(
          SaveCodecErrorCode.invalidFieldType,
          'claimedEventIds[$i] harus berupa teks non-kosong.',
          path: 'claimedEventIds[$i]',
        );
      }
      result.add(raw);
    }
    return Set.unmodifiable(result);
  }

  Map<String, int> _decodeShopPurchases(
    Map<String, dynamic> map, {
    required GameConfig config,
  }) {
    final result = <String, int>{};
    for (final entry in map.entries) {
      if (config.shop.byId(entry.key) == null) {
        throw SaveCodecException(
          SaveCodecErrorCode.unknownReferenceId,
          'Entri shop "${entry.key}" tidak ada di shop.json.',
          path: 'shopPurchases.${entry.key}',
        );
      }
      result[entry.key] = _asInt(
        entry.value,
        path: 'shopPurchases.${entry.key}',
        min: 0,
      );
    }
    return Map.unmodifiable(result);
  }

  List<EventShopPurchaseRecord> _decodeEventShopPurchases(
    List<dynamic> list, {
    required GameConfig config,
  }) {
    final result = <EventShopPurchaseRecord>[];
    for (var i = 0; i < list.length; i++) {
      final raw = list[i];
      if (raw is! Map<String, dynamic>) {
        throw SaveCodecException(
          SaveCodecErrorCode.invalidFieldType,
          'eventShopPurchases[$i] harus berupa object.',
          path: 'eventShopPurchases[$i]',
        );
      }
      _rejectUnknownKeys(raw, const {
        'entryId',
        'periodKey',
        'purchasedCount',
      }, 'eventShopPurchases[$i]');

      final entryId = _requireNonEmptyString(
        raw,
        'entryId',
        path: 'eventShopPurchases[$i].entryId',
      );
      if (config.eventShop != null && config.eventShop!.byId(entryId) == null) {
        throw SaveCodecException(
          SaveCodecErrorCode.unknownReferenceId,
          'Entri event shop "$entryId" tidak ada di event_shop.json.',
          path: 'eventShopPurchases[$i].entryId',
        );
      }
      final periodKey = _requireNonEmptyString(
        raw,
        'periodKey',
        path: 'eventShopPurchases[$i].periodKey',
      );
      final purchasedCount = _requireInt(
        raw,
        'purchasedCount',
        path: 'eventShopPurchases[$i].purchasedCount',
        min: 0,
      );
      result.add(
        EventShopPurchaseRecord(
          entryId: entryId,
          periodKey: periodKey,
          purchasedCount: purchasedCount,
        ),
      );
    }
    return List.unmodifiable(result);
  }

  Map<String, int> _decodeCurrencies(
    Map<String, dynamic> map, {
    required GameConfig config,
  }) {
    final result = <String, int>{};
    for (final entry in map.entries) {
      if (!config.currencies.containsKey(entry.key)) {
        throw SaveCodecException(
          SaveCodecErrorCode.unknownReferenceId,
          'Mata uang "${entry.key}" tidak ada dalam konfigurasi.',
          path: 'currencies.${entry.key}',
        );
      }
      result[entry.key] = _asInt(
        entry.value,
        path: 'currencies.${entry.key}',
        min: 0,
      );
    }
    return Map.unmodifiable(result);
  }

  ClockState _decodeClockState(Map<String, dynamic> map) {
    _rejectUnknownKeys(map, const {
      'forwardJumpCount',
      'lastSeenAtMs',
      'maxForwardJumpMs',
    }, 'clockState');

    return ClockState(
      lastSeenAtMs: _requireInt(
        map,
        'lastSeenAtMs',
        path: 'clockState.lastSeenAtMs',
        min: 0,
      ),
      forwardJumpCount: _requireInt(
        map,
        'forwardJumpCount',
        path: 'clockState.forwardJumpCount',
        min: 0,
      ),
      maxForwardJumpMs: _requireInt(
        map,
        'maxForwardJumpMs',
        path: 'clockState.maxForwardJumpMs',
        min: 0,
      ),
    );
  }

  List<PeriodicQuestState> _decodePeriodicQuestStates(
    List<dynamic> list, {
    required GameConfig config,
  }) {
    final result = <PeriodicQuestState>[];
    for (var i = 0; i < list.length; i++) {
      final raw = list[i];
      if (raw is! Map<String, dynamic>) {
        throw SaveCodecException(
          SaveCodecErrorCode.invalidFieldType,
          'periodicQuestStates[$i] harus berupa object.',
          path: 'periodicQuestStates[$i]',
        );
      }
      _rejectUnknownKeys(raw, const {
        'completedAtMs',
        'periodKey',
        'questId',
      }, 'periodicQuestStates[$i]');

      final questId = _requireNonEmptyString(
        raw,
        'questId',
        path: 'periodicQuestStates[$i].questId',
      );
      if (config.bossEvents != null &&
          config.bossEvents!.periodForQuestId(questId) == null) {
        throw SaveCodecException(
          SaveCodecErrorCode.unknownReferenceId,
          'questId "$questId" tidak ada di boss_events.json.',
          path: 'periodicQuestStates[$i].questId',
        );
      }
      final periodKey = _requireNonEmptyString(
        raw,
        'periodKey',
        path: 'periodicQuestStates[$i].periodKey',
      );
      final completedAtMs = _requireInt(
        raw,
        'completedAtMs',
        path: 'periodicQuestStates[$i].completedAtMs',
        min: 0,
      );
      result.add(
        PeriodicQuestState(
          questId: questId,
          periodKey: periodKey,
          completedAtMs: completedAtMs,
        ),
      );
    }
    return List.unmodifiable(result);
  }

  Map<String, int> _decodeSkillIntMap(
    Map<String, dynamic> map, {
    required GameConfig config,
    required String path,
    required int min,
  }) {
    final result = <String, int>{};
    for (final entry in map.entries) {
      if (!config.skills.containsKey(entry.key)) {
        throw SaveCodecException(
          SaveCodecErrorCode.unknownReferenceId,
          'Skill "${entry.key}" tidak ada di skills.json.',
          path: '$path.${entry.key}',
        );
      }
      result[entry.key] = _asInt(
        entry.value,
        path: '$path.${entry.key}',
        min: min,
      );
    }
    return Map.unmodifiable(result);
  }

  EquipmentSlot _parseEquipmentSlot(String raw, {required String path}) {
    for (final slot in EquipmentSlot.values) {
      if (slot.name == raw) return slot;
    }
    throw SaveCodecException(
      SaveCodecErrorCode.invalidFieldType,
      'EquipmentSlot tidak dikenal "$raw".',
      path: path,
    );
  }

  ItemRarity _parseRarity(String raw, {required String path}) {
    for (final rarity in ItemRarity.values) {
      if (rarity.name == raw) return rarity;
    }
    throw SaveCodecException(
      SaveCodecErrorCode.invalidFieldType,
      'ItemRarity tidak dikenal "$raw".',
      path: path,
    );
  }

  void _rejectUnknownKeys(
    Map<String, dynamic> map,
    Set<String> allowed,
    String path,
  ) {
    for (final key in map.keys) {
      if (!allowed.contains(key)) {
        throw SaveCodecException(
          SaveCodecErrorCode.invalidStructure,
          'Kunci tidak dikenal "$key".',
          path: '$path.$key',
        );
      }
    }
  }

  Map<String, dynamic> _requireMap(
    Map<String, dynamic> map,
    String key, {
    required String path,
  }) {
    if (!map.containsKey(key)) {
      throw SaveCodecException(
        SaveCodecErrorCode.invalidStructure,
        'Field wajib "$key" tidak ada.',
        path: path,
      );
    }
    final value = map[key];
    if (value is! Map<String, dynamic>) {
      throw SaveCodecException(
        SaveCodecErrorCode.invalidFieldType,
        'Field "$key" harus berupa object.',
        path: path,
      );
    }
    return value;
  }

  List<dynamic> _requireList(
    Map<String, dynamic> map,
    String key, {
    required String path,
  }) {
    if (!map.containsKey(key)) {
      throw SaveCodecException(
        SaveCodecErrorCode.invalidStructure,
        'Field wajib "$key" tidak ada.',
        path: path,
      );
    }
    final value = map[key];
    if (value is! List<dynamic>) {
      throw SaveCodecException(
        SaveCodecErrorCode.invalidFieldType,
        'Field "$key" harus berupa array.',
        path: path,
      );
    }
    return value;
  }

  String _requireNonEmptyString(
    Map<String, dynamic> map,
    String key, {
    required String path,
  }) {
    if (!map.containsKey(key)) {
      throw SaveCodecException(
        SaveCodecErrorCode.invalidStructure,
        'Field wajib "$key" tidak ada.',
        path: path,
      );
    }
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw SaveCodecException(
        SaveCodecErrorCode.invalidFieldType,
        'Field "$key" harus berupa teks non-kosong.',
        path: path,
      );
    }
    return value;
  }

  String? _optionalNonEmptyString(
    Map<String, dynamic> map,
    String key, {
    required String path,
  }) {
    if (!map.containsKey(key) || map[key] == null) {
      return null;
    }
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw SaveCodecException(
        SaveCodecErrorCode.invalidFieldType,
        'Field "$key" harus null atau teks non-kosong.',
        path: path,
      );
    }
    return value;
  }

  bool _requireBool(
    Map<String, dynamic> map,
    String key, {
    required String path,
  }) {
    if (!map.containsKey(key)) {
      throw SaveCodecException(
        SaveCodecErrorCode.invalidStructure,
        'Field wajib "$key" tidak ada.',
        path: path,
      );
    }
    final value = map[key];
    if (value is! bool) {
      throw SaveCodecException(
        SaveCodecErrorCode.invalidFieldType,
        'Field "$key" harus boolean.',
        path: path,
      );
    }
    return value;
  }

  int _requireInt(
    Map<String, dynamic> map,
    String key, {
    required String path,
    int? min,
  }) {
    if (!map.containsKey(key)) {
      throw SaveCodecException(
        SaveCodecErrorCode.invalidStructure,
        'Field wajib "$key" tidak ada.',
        path: path,
      );
    }
    return _asInt(map[key], path: path, min: min);
  }

  int? _optionalInt(
    Map<String, dynamic> map,
    String key, {
    required String path,
    int? min,
  }) {
    if (!map.containsKey(key) || map[key] == null) {
      return null;
    }
    return _asInt(map[key], path: path, min: min);
  }

  int _asInt(Object? value, {required String path, int? min}) {
    if (value is! int) {
      throw SaveCodecException(
        SaveCodecErrorCode.invalidFieldType,
        'Nilai harus bilangan bulat.',
        path: path,
      );
    }
    if (min != null && value < min) {
      throw SaveCodecException(
        SaveCodecErrorCode.invalidValueRange,
        'Nilai harus >= $min (nilai: $value).',
        path: path,
      );
    }
    return value;
  }

  double _requireNonNegativeFiniteDouble(
    Map<String, dynamic> map,
    String key, {
    required String path,
  }) {
    final fullPath = '$path.$key';
    if (!map.containsKey(key)) {
      throw SaveCodecException(
        SaveCodecErrorCode.invalidStructure,
        'Field wajib "$key" tidak ada.',
        path: fullPath,
      );
    }
    final value = map[key];
    if (value is! num) {
      throw SaveCodecException(
        SaveCodecErrorCode.invalidFieldType,
        'Field "$key" harus berupa angka.',
        path: fullPath,
      );
    }
    final d = value.toDouble();
    if (!d.isFinite || d < 0) {
      throw SaveCodecException(
        SaveCodecErrorCode.invalidValueRange,
        'Field "$key" harus finite dan >= 0 (nilai: $d).',
        path: fullPath,
      );
    }
    return d;
  }

  Map<String, GachaPityState> _decodeGachaPityStates(Map<String, dynamic> raw) {
    final result = <String, GachaPityState>{};
    for (final entry in raw.entries) {
      final pMap = _requireMap(
        raw,
        entry.key,
        path: 'gachaPityStates.${entry.key}',
      );
      result[entry.key] = GachaPityState(
        bannerType: _requireNonEmptyString(
          pMap,
          'bannerType',
          path: 'gachaPityStates.${entry.key}.bannerType',
        ),
        pullCount: _requireInt(
          pMap,
          'pullCount',
          path: 'gachaPityStates.${entry.key}.pullCount',
        ),
        isGuaranteed: _requireBool(
          pMap,
          'isGuaranteed',
          path: 'gachaPityStates.${entry.key}.isGuaranteed',
        ),
      );
    }
    return result;
  }

  Set<String> _decodeUnlockedSpecializations(
    List<dynamic> list, {
    required GameConfig config,
  }) {
    final result = <String>{};
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is! String || item.trim().isEmpty) {
        throw SaveCodecException(
          SaveCodecErrorCode.invalidStructure,
          'unlockedSpecializations[$i] harus berupa string tidak kosong.',
        );
      }
      final clean = item.trim();
      if (!config.specializations.definitions.containsKey(clean)) {
        throw SaveCodecException(
          SaveCodecErrorCode.unknownReferenceId,
          'unlockedSpecializations[$i] merujuk specialization tidak dikenal "$clean".',
        );
      }
      result.add(clean);
    }
    if (result.isEmpty) {
      result.addAll(['vanguard', 'arcanist', 'ranger']);
    }
    return result;
  }

  static double _normDouble(double v) => v == 0 ? 0.0 : v;

  static SplayTreeMap<String, int> _sortedIntMap(Map<String, int> source) {
    final result = SplayTreeMap<String, int>();
    result.addAll(source);
    return result;
  }

  static SplayTreeMap<String, dynamic> _sortedMap(Map<String, dynamic> source) {
    final result = SplayTreeMap<String, dynamic>();
    result.addAll(source);
    return result;
  }
}
