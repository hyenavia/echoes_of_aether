import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:echoes_of_aether/core/errors/config_exception.dart';
import 'package:echoes_of_aether/data/models/boss_events_config_parser.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/event_shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/data/repositories/save_blob_packer.dart';
import 'package:echoes_of_aether/domain/entities/clock_state.dart';
import 'package:echoes_of_aether/domain/entities/cloud_config.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/dungeon_session.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/event_shop_purchase.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/periodic_quest_state.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/player_status.dart';
import 'package:echoes_of_aether/domain/entities/save_metrics.dart';
import 'package:echoes_of_aether/domain/repositories/cloud_save_repository.dart';
import 'package:echoes_of_aether/domain/services/save_metrics_calculator.dart';
import 'package:echoes_of_aether/domain/services/save_snapshot_codec.dart';
import 'package:echoes_of_aether/domain/services/sync_planner.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealConfig() {
  const parser = GameConfigParser();
  const dungeonParser = DungeonConfigParser();
  final settings = _readAsset('game_config.json');
  final difficulty = parser.parseDifficulty(settings);
  final dungeonsJson = _readAsset('dungeons.json');
  final config = GameConfig(
    monsters: const MonsterConfigParser().parse(_readAsset('monsters.json')),
    damage: parser.parseDamage(settings),
    difficulty: difficulty,
    farming: parser.parseFarming(settings),
    revive: parser.parseRevive(settings),
    progression: parser.parseProgression(settings),
    equipment: parser.parseEquipment(settings),
    time: parser.parseTime(settings),
    claimedRewards: parser.parseClaimedRewards(settings),
    currencies: parser.parseCurrencies(settings),
    notifications: parser.parseNotifications(settings),
    dungeonCompletion: parser.parseDungeonCompletion(settings),
    cloud: parser.parseCloud(settings),
    items: const ItemConfigParser().parse(_readAsset('items.json')),
    lootTables: const LootConfigParser().parse(_readAsset('loot_tables.json')),
    skills: const SkillConfigParser().parse(_readAsset('skills.json')),
    specializations: const SpecializationConfigParser().parse(
      _readAsset('specializations.json'),
    ),
    dungeons: dungeonParser.parse(
      dungeonsJson,
      ascensionMultiplier: difficulty.ascensionMultiplier,
    ),
    mapLayouts: dungeonParser.parseMaps(dungeonsJson),
    bossEvents: const BossEventsConfigParser().parse(
      _readAsset('boss_events.json'),
    ),
    shop: const ShopConfigParser().parse(_readAsset('shop.json')),
    eventShop: const EventShopConfigParser().parse(
      _readAsset('event_shop.json'),
    ),
  );
  const GameConfigValidator().validate(config);
  return config;
}

EquipmentInstance _findEquipmentItem(
  GameConfig config,
  EquipmentSlot slot,
  String instanceId, {
  ItemRarity? rarity,
  bool preferEventItem = false,
}) {
  final matches =
      config.items.values
          .where((item) => item.isEquipment && item.equipment!.slot == slot)
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
  final chosen = preferEventItem
      ? matches.firstWhere((i) => !i.sellable, orElse: () => matches.first)
      : matches.first;
  final base = chosen.equipment!.baseStats;
  return EquipmentInstance(
    id: instanceId,
    definitionId: chosen.id,
    slot: slot,
    rarity: rarity ?? chosen.rarity,
    enhancementLevel: 3,
    rolledStats: EquipmentStats(
      hp: base.hp + 15,
      atk: base.atk + 8,
      def: base.def + 4,
      hpPct: base.hpPct > 0 ? base.hpPct : 0.08,
      atkPct: base.atkPct > 0 ? base.atkPct : 0.11,
      defPct: base.defPct > 0 ? base.defPct : 0.06,
      critRate: base.critRate + 0.02,
      critDamage: base.critDamage + 0.15,
      attackSpeed: base.attackSpeed + 0.1,
      moveSpeed: base.moveSpeed + 0.2,
      attackRange: base.attackRange,
      skillHaste: base.skillHaste + 0.05,
    ),
  );
}

PlayerSaveSnapshot _buildRichSnapshot(GameConfig config) {
  final dungeonIds = config.dungeons.keys.toList()..sort();
  final stackIds = config.items.values
      .where((i) => !i.isEquipment)
      .map((i) => i.id)
      .toList();
  final eventEntries = config.eventShop?.pool ?? const [];
  final shopEntries = config.shop.entries;

  final equipped = <EquipmentSlot, EquipmentInstance>{
    for (final slot in EquipmentSlot.values)
      slot: _findEquipmentItem(
        config,
        slot,
        'eq_equipped_${slot.name}',
        rarity: ItemRarity.epic,
        preferEventItem: true,
      ),
  };

  final bag = <EquipmentInstance>[
    for (var i = 0; i < 12; i++)
      _findEquipmentItem(
        config,
        EquipmentSlot.values[i % EquipmentSlot.values.length],
        'eq_bag_${i.toString().padLeft(3, '0')}',
      ),
  ];

  final dungeonProgresses = <String, DungeonProgressSnapshot>{
    for (var i = 0; i < dungeonIds.length; i++)
      dungeonIds[i]: DungeonProgressSnapshot(
        currentDungeonId: dungeonIds[i],
        currentRoomId: config.dungeons[dungeonIds[i]]!.rooms.values.first.id,
        currentRoomIndex: 0,
        highestClearedRoomIndex:
            config.dungeons[dungeonIds[i]]!.rooms.length - 1,
        clearsCount: (i + 1) * 3,
        clearedInCycleRank: 4,
        rewardState: DungeonRewardStateSnapshot(
          lastRunId: 'run_${dungeonIds[i]}',
          completionRewardClaimed: true,
          claimedRoomRewardIds: {
            config.dungeons[dungeonIds[i]]!.rooms.values.first.id,
            config.dungeons[dungeonIds[i]]!.rooms.values.last.id,
          },
        ),
      ),
  };

  return PlayerSaveSnapshot(
    playerId: 'default_player',
    character: PlayerCharacterSnapshot(
      progress: const PlayerProgress(level: 42, currentExp: 1950, gold: 88250),
      specializationId: config.specializations.definitions.keys.first,
      skillLevels: {for (final s in config.skills.keys.take(4)) s: 3},
      skillCooldownTicks: {for (final s in config.skills.keys.take(2)) s: 12},
      equipped: equipped,
      currentHp: 640,
    ),
    inventory: InventorySnapshot(
      stacks: {
        for (var i = 0; i < stackIds.length; i++) stackIds[i]: (i + 1) * 15,
      },
      equipment: bag,
      equipmentCounter: 240,
    ),
    dungeon: dungeonProgresses[dungeonIds.last]!,
    dungeonProgresses: dungeonProgresses,
    cycleProgress: CycleProgress(
      ascensionRank: 3,
      highestAscensionRank: 5,
      lastNormalDungeonId: dungeonIds.last,
    ),
    session: GameSessionSnapshot(
      playerId: 'default_player',
      lastActiveAtMs: 1700000100000,
      lastSavedAtMs: 1700000123000,
      lastOfflineClaimAtMs: 1700000090000,
      autoSkillEnabled: false,
      consecutiveDefeats: {dungeonIds.first: 2, dungeonIds.last: 1},
      lastFailedDungeonId: dungeonIds.first,
    ),
    claimedEventIds: {
      // Permanen (wajib bertahan saat round-trip)
      'ascension:run_1',
      'shop:${shopEntries.first.id}',
      'bossquest:daily_boss:2026-10-01',
      'eventshop:${eventEntries.first.id}:2026-W40',
      // Sementara (wajib dikecualikan oleh kodek)
      'offline_kill:run_99:slime_1',
      'room_clear:run_99:forest_entrance',
      'dungeon_clear:run_99',
      'offline:1700000000000:1700000050000',
      'enemy:42:m1',
    },
    activeDungeonSession: ActiveDungeonSessionSnapshot(
      runId: 'active_run_should_be_excluded',
      dungeonId: dungeonIds.first,
      currentRoomId: config.dungeons[dungeonIds.first]!.rooms.values.first.id,
      currentRoomIndex: 1,
      status: DungeonSessionStatus.inProgress,
      clearedRoomIds: {config.dungeons[dungeonIds.first]!.rooms.values.first.id},
      reviveCooldownTicks: 120,
      playerStatus: PlayerStatus.downed,
      cycleRank: 3,
    ),
    offlineActivity: OfflineActivitySnapshot(
      mode: OfflineActivityMode.autoFarming,
      state: OfflineActivityState.interrupted,
      selectedDungeonId: dungeonIds.first,
      activeRunId: 'offline_run_excluded',
      lastCheckpointAtMs: 1700000110000,
      processedOfflineDurationMs: 600000,
    ),
    shopPurchases: {
      for (var i = 0; i < 3 && i < shopEntries.length; i++)
        shopEntries[i].id: i + 1,
    },
    eventShopPurchases: [
      EventShopPurchaseRecord(
        entryId: eventEntries[0].id,
        periodKey: '2026-W40',
        purchasedCount: 1,
      ),
      EventShopPurchaseRecord(
        entryId: eventEntries[1].id,
        periodKey: '2026-W41',
        purchasedCount: 2,
      ),
    ],
    currencies: const {'aether_shard': 480},
    clockState: const ClockState(
      lastSeenAtMs: 1700000200000,
      forwardJumpCount: 1,
      maxForwardJumpMs: 420000,
    ),
    periodicQuestStates: const [
      PeriodicQuestState(
        questId: 'daily_boss',
        periodKey: '2026-10-01',
        completedAtMs: 1700000010000,
      ),
      PeriodicQuestState(
        questId: 'daily_boss',
        periodKey: '2026-10-02',
        completedAtMs: 1700000090000,
      ),
      PeriodicQuestState(
        questId: 'weekly_boss',
        periodKey: '2026-W40',
        completedAtMs: 1700000080000,
      ),
    ],
  );
}

CloudSaveMeta _meta({required int revision, int savedAtMs = 1000000}) =>
    CloudSaveMeta(
      revision: revision,
      slot: revision % 2,
      savedAtServerMs: savedAtMs,
      deviceId: 'device_a',
      appVersion: '1.0.0+1',
      metrics: const SaveMetrics(
        level: 10,
        gold: 500,
        shards: 50,
        highestAscensionRank: 1,
        lifetimeClears: 5,
        dailyQuestDone: 1,
        weeklyQuestDone: 0,
        eventPurchasesLifetime: 0,
        equipmentCount: 4,
        blobBytes: 1200,
        blobSha256:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        schemaVersion: 8,
        codecVersion: 1,
      ),
    );

void main() {
  late GameConfig config;

  setUpAll(() {
    config = _loadRealConfig();
  });

  group('CloudConfig parser & validator', () {
    test('assets/data/game_config.json memuat blok cloud default 5/60/5', () {
      expect(config.cloud.autoSyncMinIntervalMinutes, 5);
      expect(config.cloud.rejectBackoffMinutes, 60);
      expect(config.cloud.serverTimeToleranceMinutes, 5);
      expect(config.cloud.autoSyncMinIntervalMs, 5 * 60 * 1000);
      expect(config.cloud.rejectBackoffMs, 60 * 60 * 1000);
      expect(config.cloud.serverTimeToleranceMs, 5 * 60 * 1000);
    });

    test(
      'GameConfigParser & GameConfigValidator menolak nilai cloud tidak valid',
      () {
        const parser = GameConfigParser();
        expect(
          () => parser.parseCloud('{"cloud":{"unknown_key":1}}'),
          throwsA(isA<ConfigException>()),
        );
        expect(
          () => parser.parseCloud('{"cloud":{"reject_backoff_minutes":0}}'),
          throwsA(isA<ConfigException>()),
        );
        expect(
          () => const GameConfigValidator().validate(
            GameConfig(
              monsters: config.monsters,
              revive: config.revive,
              progression: config.progression,
              items: config.items,
              lootTables: config.lootTables,
              cloud: const CloudConfig(autoSyncMinIntervalMinutes: -1),
            ),
          ),
          throwsA(isA<ConfigException>()),
        );
      },
    );
  });

  group('SaveSnapshotCodec & SaveBlobPacker', () {
    const codec = SaveSnapshotCodec();
    const packer = SaveBlobPacker();

    test('round-trip menghasilkan JSON kanonis identik serta membuktikan pengecualian field sementara', () {
      final rich = _buildRichSnapshot(config);
      final json1 = codec.encodeToCanonicalJson(rich);
      final decoded = codec.decodeFromCanonicalJson(json1, config: config);
      final json2 = codec.encodeToCanonicalJson(decoded);

      expect(json2, equals(json1));

      // Field permanen bertahan utuh.
      expect(decoded.character.progress.level, 42);
      expect(decoded.character.progress.gold, 88250);
      expect(decoded.character.specializationId, isNotNull);
      expect(
        decoded.character.equipped[EquipmentSlot.weapon]!.rolledStats.hpPct,
        greaterThan(0),
      );
      expect(
        decoded.character.equipped[EquipmentSlot.weapon]!.rolledStats.atkPct,
        greaterThan(0),
      );
      expect(
        decoded.character.equipped[EquipmentSlot.weapon]!.rolledStats.defPct,
        greaterThan(0),
      );
      expect(decoded.currencies['aether_shard'], 480);
      expect(decoded.clockState, rich.clockState);
      expect(decoded.eventShopPurchases, rich.eventShopPurchases);
      expect(decoded.periodicQuestStates, rich.periodicQuestStates);
      expect(decoded.session.autoSkillEnabled, false);
      expect(
        decoded.session.consecutiveDefeats,
        rich.session.consecutiveDefeats,
      );
      expect(
        decoded.session.lastFailedDungeonId,
        rich.session.lastFailedDungeonId,
      );

      // Hanya ID klaim permanen yang ikut; ID sementara dikecualikan.
      expect(
        decoded.claimedEventIds,
        containsAll([
          'ascension:run_1',
          'shop:${config.shop.entries.first.id}',
          'bossquest:daily_boss:2026-10-01',
          'eventshop:${config.eventShop!.pool.first.id}:2026-W40',
        ]),
      );
      expect(
        decoded.claimedEventIds.any((e) => e.startsWith('offline_kill:')),
        false,
      );
      expect(
        decoded.claimedEventIds.any((e) => e.startsWith('room_clear:')),
        false,
      );
      expect(
        decoded.claimedEventIds.any((e) => e.startsWith('dungeon_clear:')),
        false,
      );
      expect(
        decoded.claimedEventIds.any((e) => e.startsWith('offline:')),
        false,
      );
      expect(decoded.claimedEventIds.any((e) => e.startsWith('enemy:')), false);

      // Active dungeon session, offline activity, dan jangkar offline dikecualikan/direset.
      expect(decoded.activeDungeonSession, isNull);
      expect(
        decoded.offlineActivity.mode,
        OfflineActivityMode.pauseProgression,
      );
      expect(decoded.offlineActivity.state, OfflineActivityState.inactive);
      expect(decoded.session.lastOfflineClaimAtMs, 0);
      expect(decoded.session.lastSavedAtMs, 0);
      expect(decoded.session.lastActiveAtMs, 0);
    });

    test('determinisme: urutan Map/Set/List berbeda menghasilkan byte gzip dan SHA-256 identik', () {
      final base = _buildRichSnapshot(config);
      final reversedCurrencies = {
        'aether_shard': base.currencies['aether_shard']!,
      };
      final reversedStacks = Map<String, int>.fromEntries(
        base.inventory.stacks.entries.toList().reversed,
      );
      final reversedBag = base.inventory.equipment.reversed.toList();
      final reversedClaims = base.claimedEventIds.toList().reversed.toSet();
      final reversedEquipped =
          Map<EquipmentSlot, EquipmentInstance>.fromEntries(
            base.character.equipped.entries.toList().reversed,
          );
      final reversedDungeonProgress =
          Map<String, DungeonProgressSnapshot>.fromEntries(
            base.dungeonProgresses.entries.toList().reversed,
          );
      final reversedQuests = base.periodicQuestStates.reversed.toList();
      final reversedEventShop = base.eventShopPurchases.reversed.toList();

      final reordered = PlayerSaveSnapshot(
        playerId: base.playerId,
        character: PlayerCharacterSnapshot(
          progress: base.character.progress,
          specializationId: base.character.specializationId,
          skillLevels: Map.fromEntries(
            base.character.skillLevels.entries.toList().reversed,
          ),
          skillCooldownTicks: Map.fromEntries(
            base.character.skillCooldownTicks.entries.toList().reversed,
          ),
          equipped: reversedEquipped,
          currentHp: base.character.currentHp,
        ),
        inventory: InventorySnapshot(
          stacks: reversedStacks,
          equipment: reversedBag,
          equipmentCounter: base.inventory.equipmentCounter,
        ),
        dungeon: base.dungeon,
        dungeonProgresses: reversedDungeonProgress,
        cycleProgress: base.cycleProgress,
        session: base.session,
        claimedEventIds: reversedClaims,
        activeDungeonSession: base.activeDungeonSession,
        offlineActivity: base.offlineActivity,
        shopPurchases: Map.fromEntries(
          base.shopPurchases.entries.toList().reversed,
        ),
        eventShopPurchases: reversedEventShop,
        currencies: reversedCurrencies,
        clockState: base.clockState,
        periodicQuestStates: reversedQuests,
      );

      final packedA = packer.pack(base);
      final packedB = packer.pack(reordered);

      expect(packedA.canonicalJson, equals(packedB.canonicalJson));
      expect(packedA.compressedBytes, equals(packedB.compressedBytes));
      expect(packedA.sha256Hex, equals(packedB.sha256Hex));
      expect(packedA.sha256Hex.length, 64);

      final unpacked = packer.unpack(
        packedA.compressedBytes,
        expectedSha256: packedA.sha256Hex,
        config: config,
      );
      expect(
        codec.encodeToCanonicalJson(unpacked),
        equals(packedA.canonicalJson),
      );
    });

    test('decode ketat menolak versi baru, JSON rusak, referensi tak dikenal, nilai negatif, duplikat, dan hash salah', () {
      final baseMap = codec.encodeToMap(_buildRichSnapshot(config));

      // codecVersion terlalu baru
      final newerVersion = Map<String, dynamic>.from(baseMap)
        ..['codecVersion'] = SaveSnapshotCodec.supportedCodecVersion + 1;
      expect(
        () => codec.decodeFromMap(newerVersion, config: config),
        throwsA(
          isA<SaveCodecException>().having(
            (e) => e.code,
            'code',
            SaveCodecErrorCode.unsupportedCodecVersion,
          ),
        ),
      );

      // JSON rusak
      expect(
        () => codec.decodeFromCanonicalJson('{not-json', config: config),
        throwsA(
          isA<SaveCodecException>().having(
            (e) => e.code,
            'code',
            SaveCodecErrorCode.malformedJson,
          ),
        ),
      );

      // Struktur salah (kunci tidak dikenal)
      final extraKey = Map<String, dynamic>.from(baseMap)..['rogue'] = 1;
      expect(
        () => codec.decodeFromMap(extraKey, config: config),
        throwsA(
          isA<SaveCodecException>().having(
            (e) => e.code,
            'code',
            SaveCodecErrorCode.invalidStructure,
          ),
        ),
      );

      // ID item tidak dikenal
      final badItemMap = jsonDecode(
        codec.encodeToCanonicalJson(_buildRichSnapshot(config)),
      ) as Map<String, dynamic>;
      (badItemMap['inventory'] as Map<String, dynamic>)['stacks'] = {
        'non_existent_item': 5,
      };
      expect(
        () => codec.decodeFromMap(badItemMap, config: config),
        throwsA(
          isA<SaveCodecException>().having(
            (e) => e.code,
            'code',
            SaveCodecErrorCode.unknownReferenceId,
          ),
        ),
      );

      // ID skill tidak dikenal
      final badSkillMap = jsonDecode(
        codec.encodeToCanonicalJson(_buildRichSnapshot(config)),
      ) as Map<String, dynamic>;
      (badSkillMap['character'] as Map<String, dynamic>)['skillLevels'] = {
        'unknown_skill': 2,
      };
      expect(
        () => codec.decodeFromMap(badSkillMap, config: config),
        throwsA(
          isA<SaveCodecException>().having(
            (e) => e.code,
            'code',
            SaveCodecErrorCode.unknownReferenceId,
          ),
        ),
      );

      // ID dungeon tidak dikenal
      final badDungeonMap = jsonDecode(
        codec.encodeToCanonicalJson(_buildRichSnapshot(config)),
      ) as Map<String, dynamic>;
      (badDungeonMap['dungeon'] as Map<String, dynamic>)['currentDungeonId'] =
          'unknown_dungeon';
      expect(
        () => codec.decodeFromMap(badDungeonMap, config: config),
        throwsA(
          isA<SaveCodecException>().having(
            (e) => e.code,
            'code',
            SaveCodecErrorCode.unknownReferenceId,
          ),
        ),
      );

      // level < 1 dan nilai negatif
      final badLevelMap = jsonDecode(
        codec.encodeToCanonicalJson(_buildRichSnapshot(config)),
      ) as Map<String, dynamic>;
      ((badLevelMap['character'] as Map<String, dynamic>)['progress']
              as Map<String, dynamic>)['level'] =
          0;
      expect(
        () => codec.decodeFromMap(badLevelMap, config: config),
        throwsA(
          isA<SaveCodecException>().having(
            (e) => e.code,
            'code',
            SaveCodecErrorCode.invalidValueRange,
          ),
        ),
      );

      final negativeGoldMap = jsonDecode(
        codec.encodeToCanonicalJson(_buildRichSnapshot(config)),
      ) as Map<String, dynamic>;
      ((negativeGoldMap['character'] as Map<String, dynamic>)['progress']
              as Map<String, dynamic>)['gold'] =
          -5;
      expect(
        () => codec.decodeFromMap(negativeGoldMap, config: config),
        throwsA(
          isA<SaveCodecException>().having(
            (e) => e.code,
            'code',
            SaveCodecErrorCode.invalidValueRange,
          ),
        ),
      );

      // Duplikat equipment ID
      final dupEqMap = jsonDecode(
        codec.encodeToCanonicalJson(_buildRichSnapshot(config)),
      ) as Map<String, dynamic>;
      final bagList =
          (dupEqMap['inventory'] as Map<String, dynamic>)['equipment']
              as List<dynamic>;
      (bagList.first as Map<String, dynamic>)['id'] = 'eq_equipped_weapon';
      expect(
        () => codec.decodeFromMap(dupEqMap, config: config),
        throwsA(
          isA<SaveCodecException>().having(
            (e) => e.code,
            'code',
            SaveCodecErrorCode.duplicateEquipmentId,
          ),
        ),
      );

      // Hash SHA-256 tidak cocok & stream gzip rusak
      final packed = packer.pack(_buildRichSnapshot(config));
      expect(
        () => packer.unpack(
          packed.compressedBytes,
          expectedSha256: '0' * 64,
          config: config,
        ),
        throwsA(
          isA<SaveBlobPackException>().having(
            (e) => e.code,
            'code',
            SaveBlobUnpackErrorCode.hashMismatch,
          ),
        ),
      );

      expect(
        () =>
            packer.unpack(Uint8List.fromList([1, 2, 3, 4, 5]), config: config),
        throwsA(
          isA<SaveBlobPackException>().having(
            (e) => e.code,
            'code',
            SaveBlobUnpackErrorCode.corruptedGzip,
          ),
        ),
      );
    });

    test('ukuran snapshot berat jauh di bawah batas 900.000 byte setelah gzip', () {
      final dungeonIds = config.dungeons.keys.toList()..sort();
      final stackItems = config.items.values
          .where((i) => !i.isEquipment)
          .map((i) => i.id)
          .toList();
      final eventEntries = config.eventShop!.pool;
      final shopEntries = config.shop.entries;

      final heavyBag = <EquipmentInstance>[
        for (var i = 0; i < 200; i++)
          _findEquipmentItem(
            config,
            EquipmentSlot.values[i % EquipmentSlot.values.length],
            'eq_heavy_${i.toString().padLeft(4, '0')}',
            rarity: ItemRarity.legendary,
            preferEventItem: i.isEven,
          ),
      ];
      final heavyClaims = <String>{
        for (var i = 0; i < 100; i++) 'ascension:run_$i',
        for (final entry in shopEntries) 'shop:${entry.id}',
        for (var i = 0; i < 120; i++) 'bossquest:daily_boss:2026-01-${i + 1}',
        for (var i = 0; i < 50; i++)
          'eventshop:${eventEntries[i % eventEntries.length].id}:2026-W${(i % 52) + 1}',
      };
      final heavyQuests = <PeriodicQuestState>[
        for (var i = 0; i < 120; i++)
          PeriodicQuestState(
            questId: i % 7 == 0 ? 'weekly_boss' : 'daily_boss',
            periodKey: '2026-${(i + 1).toString().padLeft(3, '0')}',
            completedAtMs: 1700000000000 + i * 86400000,
          ),
      ];
      final heavyEventPurchases = <EventShopPurchaseRecord>[
        for (var i = 0; i < 40; i++)
          EventShopPurchaseRecord(
            entryId: eventEntries[i % eventEntries.length].id,
            periodKey: '2026-W${(i + 1).toString().padLeft(2, '0')}',
            purchasedCount: 1,
          ),
      ];

      final heavySnapshot = PlayerSaveSnapshot(
        playerId: 'default_player',
        character: PlayerCharacterSnapshot(
          progress: const PlayerProgress(
            level: 250,
            currentExp: 999999,
            gold: 99999999,
          ),
          specializationId: config.specializations.definitions.keys.first,
          skillLevels: {for (final id in config.skills.keys) id: 5},
          skillCooldownTicks: {for (final id in config.skills.keys) id: 30},
          equipped: {
            for (final slot in EquipmentSlot.values)
              slot: _findEquipmentItem(
                config,
                slot,
                'eq_heavy_eq_${slot.name}',
                rarity: ItemRarity.legendary,
                preferEventItem: true,
              ),
          },
          currentHp: 50000,
        ),
        inventory: InventorySnapshot(
          stacks: {for (final id in stackItems) id: 999},
          equipment: heavyBag,
          equipmentCounter: 5000,
        ),
        dungeon: DungeonProgressSnapshot(
          currentDungeonId: dungeonIds.last,
          currentRoomId: config.dungeons[dungeonIds.last]!.rooms.values.last.id,
          currentRoomIndex: config.dungeons[dungeonIds.last]!.rooms.length - 1,
          highestClearedRoomIndex:
              config.dungeons[dungeonIds.last]!.rooms.length - 1,
          clearsCount: 1500,
          clearedInCycleRank: 25,
          rewardState: DungeonRewardStateSnapshot(
            lastRunId: 'run_heavy',
            completionRewardClaimed: true,
            claimedRoomRewardIds: {
              for (final r in config.dungeons[dungeonIds.last]!.rooms.values)
                r.id,
            },
          ),
        ),
        dungeonProgresses: {
          for (final id in dungeonIds)
            id: DungeonProgressSnapshot(
              currentDungeonId: id,
              currentRoomId: config.dungeons[id]!.rooms.values.last.id,
              currentRoomIndex: config.dungeons[id]!.rooms.length - 1,
              highestClearedRoomIndex: config.dungeons[id]!.rooms.length - 1,
              clearsCount: 1500,
              clearedInCycleRank: 25,
              rewardState: DungeonRewardStateSnapshot(
                lastRunId: 'run_$id',
                completionRewardClaimed: true,
                claimedRoomRewardIds: {
                  for (final r in config.dungeons[id]!.rooms.values) r.id,
                },
              ),
            ),
        },
        cycleProgress: CycleProgress(
          ascensionRank: 20,
          highestAscensionRank: 25,
          lastNormalDungeonId: dungeonIds.last,
        ),
        session: GameSessionSnapshot(
          autoSkillEnabled: true,
          consecutiveDefeats: {for (final id in dungeonIds) id: 1},
          lastFailedDungeonId: dungeonIds.first,
        ),
        claimedEventIds: heavyClaims,
        shopPurchases: {for (final entry in shopEntries) entry.id: 1},
        eventShopPurchases: heavyEventPurchases,
        currencies: const {'aether_shard': 15000},
        clockState: const ClockState(
          lastSeenAtMs: 1700050000000,
          forwardJumpCount: 0,
          maxForwardJumpMs: 0,
        ),
        periodicQuestStates: heavyQuests,
      );

      final packed = packer.pack(heavySnapshot);
      // ignore: avoid_print
      print(
        '[M14-Stage1 Heavy Blob] equipment=${heavyBag.length + 4}, '
        'claims=${heavyClaims.length}, quests=${heavyQuests.length}, '
        'rawJsonBytes=${packed.rawJsonBytes}, gzipBytes=${packed.blobBytes}',
      );
      expect(packed.rawJsonBytes, greaterThan(10000));
      expect(packed.blobBytes, lessThan(900000));
      expect(packed.blobBytes, lessThan(packed.rawJsonBytes));
    });
  });

  group('SaveMetricsCalculator', () {
    test('menghitung seluruh metrik lintas dungeon, quest harian/mingguan, shard, event shop, dan equipment', () {
      const calculator = SaveMetricsCalculator();
      const packer = SaveBlobPacker();
      final rich = _buildRichSnapshot(config);
      final packed = packer.pack(rich);

      final metrics = calculator.compute(
        snapshot: rich,
        config: config,
        blobBytes: packed.blobBytes,
        blobSha256: packed.sha256Hex,
        schemaVersion: 8,
      );

      final expectedClears = rich.dungeonProgresses.values.fold<int>(
        0,
        (sum, dp) => sum + dp.clearsCount,
      );

      expect(metrics.level, 42);
      expect(metrics.gold, 88250);
      expect(metrics.shards, 480);
      expect(metrics.highestAscensionRank, 5);
      expect(metrics.lifetimeClears, expectedClears);
      expect(metrics.dailyQuestDone, 2);
      expect(metrics.weeklyQuestDone, 1);
      expect(metrics.eventPurchasesLifetime, 3);
      expect(metrics.equipmentCount, 12 + 4);
      expect(metrics.blobBytes, packed.blobBytes);
      expect(metrics.blobSha256, packed.sha256Hex);
      expect(metrics.schemaVersion, 8);
      expect(metrics.codecVersion, SaveSnapshotCodec.supportedCodecVersion);
    });
  });

  group('SyncPlanner', () {
    const planner = SyncPlanner();
    const cloudConfig = CloudConfig(
      autoSyncMinIntervalMinutes: 5,
      rejectBackoffMinutes: 60,
      serverTimeToleranceMinutes: 5,
    );
    const hashA = 'hash_a';
    const hashB = 'hash_b';

    test('belum login menghasilkan SyncRequireSignIn untuk pemicu otomatis & manual', () {
      for (final trigger in SyncTrigger.values) {
        final plan = planner.plan(
          isSignedIn: false,
          trigger: trigger,
          local: const LocalSyncStateSnapshot(
            lastSyncedRevision: 0,
            lastSyncedBlobSha256: null,
            currentBlobSha256: hashA,
          ),
          cloudMeta: null,
          nowMs: 1000000,
          config: cloudConfig,
        );
        expect(plan, isA<SyncRequireSignIn>());
      }
    });

    test(
      'tidak ada perubahan lokal dilewati termasuk pada manual & ascension',
      () {
        for (final trigger in SyncTrigger.values) {
          final plan = planner.plan(
            isSignedIn: true,
            trigger: trigger,
            local: const LocalSyncStateSnapshot(
              lastSyncedRevision: 3,
              lastSyncedBlobSha256: hashA,
              currentBlobSha256: hashA,
              lastSyncAtMs: 0,
            ),
            cloudMeta: _meta(revision: 3),
            nowMs: 1000000,
            config: cloudConfig,
          );
          expect(
            plan,
            isA<SyncSkip>().having(
              (s) => s.reason,
              'reason',
              SyncSkipReason.noLocalChanges,
            ),
          );
        }
      },
    );

    test('throttle 5 menit menahan appOpen & background, namun diabaikan ascension & manual', () {
      const twoMinutesMs = 2 * 60 * 1000;
      const fiveMinutesMs = 5 * 60 * 1000;
      const localChanged = LocalSyncStateSnapshot(
        lastSyncedRevision: 2,
        lastSyncedBlobSha256: hashA,
        currentBlobSha256: hashB,
        lastSyncAtMs: 1000000,
      );

      for (final autoTrigger in [SyncTrigger.appOpen, SyncTrigger.background]) {
        final blocked = planner.plan(
          isSignedIn: true,
          trigger: autoTrigger,
          local: localChanged,
          cloudMeta: _meta(revision: 2),
          nowMs: 1000000 + twoMinutesMs,
          config: cloudConfig,
        );
        expect(
          blocked,
          isA<SyncSkip>().having(
            (s) => s.reason,
            'reason',
            SyncSkipReason.throttled,
          ),
        );

        final allowedAfterWindow = planner.plan(
          isSignedIn: true,
          trigger: autoTrigger,
          local: localChanged,
          cloudMeta: _meta(revision: 2),
          nowMs: 1000000 + fiveMinutesMs,
          config: cloudConfig,
        );
        expect(
          allowedAfterWindow,
          isA<SyncUpload>()
              .having((u) => u.expectedBaseRevision, 'expectedBase', 2)
              .having((u) => u.newRevision, 'newRevision', 3),
        );
      }

      for (final priorityTrigger in [
        SyncTrigger.ascension,
        SyncTrigger.manual,
      ]) {
        final plan = planner.plan(
          isSignedIn: true,
          trigger: priorityTrigger,
          local: localChanged,
          cloudMeta: _meta(revision: 2),
          nowMs: 1000000 + twoMinutesMs,
          config: cloudConfig,
        );
        expect(plan, isA<SyncUpload>());
      }
    });

    test('jeda penolakan 1 jam menahan pemicu otomatis & ascension, namun manual mengabaikan batas', () {
      const thirtyMinutesMs = 30 * 60 * 1000;
      const sixtyMinutesMs = 60 * 60 * 1000;
      const localRejected = LocalSyncStateSnapshot(
        lastSyncedRevision: 2,
        lastSyncedBlobSha256: hashA,
        currentBlobSha256: hashB,
        lastSyncAtMs: 0,
        lastRejectAtMs: 5000000,
      );

      for (final blockedTrigger in [
        SyncTrigger.appOpen,
        SyncTrigger.background,
        SyncTrigger.ascension,
      ]) {
        final duringBackoff = planner.plan(
          isSignedIn: true,
          trigger: blockedTrigger,
          local: localRejected,
          cloudMeta: _meta(revision: 2),
          nowMs: 5000000 + thirtyMinutesMs,
          config: cloudConfig,
        );
        expect(
          duringBackoff,
          isA<SyncSkip>().having(
            (s) => s.reason,
            'reason',
            SyncSkipReason.rejectBackoff,
          ),
        );

        final afterBackoff = planner.plan(
          isSignedIn: true,
          trigger: blockedTrigger,
          local: localRejected,
          cloudMeta: _meta(revision: 2),
          nowMs: 5000000 + sixtyMinutesMs,
          config: cloudConfig,
        );
        expect(afterBackoff, isA<SyncUpload>());
      }

      final manualOverride = planner.plan(
        isSignedIn: true,
        trigger: SyncTrigger.manual,
        local: localRejected,
        cloudMeta: _meta(revision: 2),
        nowMs: 5000000 + thirtyMinutesMs,
        config: cloudConfig,
      );
      expect(
        manualOverride,
        isA<SyncUpload>()
            .having((u) => u.expectedBaseRevision, 'expectedBase', 2)
            .having((u) => u.newRevision, 'newRevision', 3),
      );
    });

    test('cloud lebih baru menawarkan pemulihan jika lokal bersih atau perangkat baru, dan konflik jika lokal berubah', () {
      final cloudNewer = _meta(revision: 4);

      final offerRestoreSyncedClean = planner.plan(
        isSignedIn: true,
        trigger: SyncTrigger.appOpen,
        local: const LocalSyncStateSnapshot(
          lastSyncedRevision: 2,
          lastSyncedBlobSha256: hashA,
          currentBlobSha256: hashA,
        ),
        cloudMeta: cloudNewer,
        nowMs: 9000000,
        config: cloudConfig,
      );
      expect(
        offerRestoreSyncedClean,
        isA<SyncOfferRestore>().having((o) => o.cloudMeta.revision, 'rev', 4),
      );

      final offerRestoreNewDevice = planner.plan(
        isSignedIn: true,
        trigger: SyncTrigger.appOpen,
        local: const LocalSyncStateSnapshot(
          lastSyncedRevision: 0,
          lastSyncedBlobSha256: null,
          currentBlobSha256: hashA,
          hasMeaningfulLocalSave: false,
        ),
        cloudMeta: cloudNewer,
        nowMs: 9000000,
        config: cloudConfig,
      );
      expect(offerRestoreNewDevice, isA<SyncOfferRestore>());

      final conflictChanged = planner.plan(
        isSignedIn: true,
        trigger: SyncTrigger.appOpen,
        local: const LocalSyncStateSnapshot(
          lastSyncedRevision: 2,
          lastSyncedBlobSha256: hashA,
          currentBlobSha256: hashB,
        ),
        cloudMeta: cloudNewer,
        nowMs: 9000000,
        config: cloudConfig,
      );
      expect(
        conflictChanged,
        isA<SyncConflict>().having((c) => c.cloudMeta.revision, 'rev', 4),
      );

      final conflictUnlinkedWithLocalSave = planner.plan(
        isSignedIn: true,
        trigger: SyncTrigger.manual,
        local: const LocalSyncStateSnapshot(
          lastSyncedRevision: 0,
          lastSyncedBlobSha256: null,
          currentBlobSha256: hashB,
          hasMeaningfulLocalSave: true,
        ),
        cloudMeta: cloudNewer,
        nowMs: 9000000,
        config: cloudConfig,
      );
      expect(conflictUnlinkedWithLocalSave, isA<SyncConflict>());
    });

    test('unggah pertama dari perangkat dengan save lokal menghasilkan SyncUpload(0 -> 1)', () {
      final firstUpload = planner.plan(
        isSignedIn: true,
        trigger: SyncTrigger.appOpen,
        local: const LocalSyncStateSnapshot(
          lastSyncedRevision: 0,
          lastSyncedBlobSha256: null,
          currentBlobSha256: hashA,
        ),
        cloudMeta: null,
        nowMs: 1000000,
        config: cloudConfig,
      );
      expect(
        firstUpload,
        isA<SyncUpload>()
            .having((u) => u.expectedBaseRevision, 'expectedBase', 0)
            .having((u) => u.newRevision, 'newRevision', 1),
      );
    });
  });
}
