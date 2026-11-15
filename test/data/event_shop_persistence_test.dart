import 'dart:io';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
import 'package:echoes_of_aether/data/database/app_database.dart'
    hide ClockState;
import 'package:echoes_of_aether/data/models/boss_events_config_parser.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/event_shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/clock_state.dart';
import 'package:echoes_of_aether/domain/entities/currency_config.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/event_shop_config.dart';
import 'package:echoes_of_aether/domain/entities/event_shop_purchase.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/game_settings.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/services/claimed_rewards_pruner.dart';
import 'package:echoes_of_aether/domain/services/currency_service.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/event_shop_service.dart';
import 'package:echoes_of_aether/domain/services/shop_service.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealConfig() {
  const parser = GameConfigParser();
  final settings = _readAsset('game_config.json');
  final difficulty = parser.parseDifficulty(settings);
  final dungeonsJson = _readAsset('dungeons.json');
  return GameConfig(
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
    items: const ItemConfigParser().parse(_readAsset('items.json')),
    lootTables: const LootConfigParser().parse(_readAsset('loot_tables.json')),
    skills: const SkillConfigParser().parse(_readAsset('skills.json')),
    specializations: const SpecializationConfigParser().parse(
      _readAsset('specializations.json'),
    ),
    dungeons: const DungeonConfigParser().parse(
      dungeonsJson,
      ascensionMultiplier: difficulty.ascensionMultiplier,
    ),
    mapLayouts: const DungeonConfigParser().parseMaps(dungeonsJson),
    bossEvents: const BossEventsConfigParser().parse(
      _readAsset('boss_events.json'),
    ),
    shop: const ShopConfigParser().parse(_readAsset('shop.json')),
    eventShop: const EventShopConfigParser().parse(
      _readAsset('event_shop.json'),
    ),
  );
}

void main() {
  late AppDatabase db;
  late GameConfig config;
  late DriftPlayerSaveRepository repo;
  late int mockNowMs;
  late GameSessionCoordinator coordinator;

  final week1MondayMs = DateTime.utc(
    2026,
    11,
    16,
    10,
    0,
  ).millisecondsSinceEpoch;

  setUp(() {
    config = _loadRealConfig();
    mockNowMs = week1MondayMs;
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftPlayerSaveRepository(db: db, config: config);
    coordinator = GameSessionCoordinator(
      config: config,
      repository: repo,
      nowMs: () => mockNowMs,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('transaksi event shop dipersistenkan atomik (shard, equipment % stats, EventShopPurchases, ClaimedRewards) dan bertahan lintas restart', () async {
    final character = PlayerCharacter(
      config: config.progression,
      specializationConfig: config.specializations,
      skillCatalog: config.skills,
      progress: const PlayerProgress(level: 30, gold: 1000),
      initialSpecializationId: 'vanguard',
    );
    final inventory = Inventory(definitions: config.items);
    final currencyService = CurrencyService(
      definitions: config.currencies,
      initialBalances: {kAetherShardCurrencyId: 300},
    );
    await repo.saveSnapshot(
      PlayerSaveSnapshot(
        character: character.toSnapshot(),
        inventory: inventory.toSnapshot(),
        dungeonProgresses: const {
          'ancient_crypt': DungeonProgressSnapshot(
            currentDungeonId: 'ancient_crypt',
            clearsCount: 1,
          ),
        },
        cycleProgress: const CycleProgress(
          ascensionRank: 1,
          highestAscensionRank: 1,
        ),
        session: GameSessionSnapshot(
          lastActiveAtMs: week1MondayMs,
          lastSavedAtMs: week1MondayMs,
          lastOfflineClaimAtMs: week1MondayMs,
        ),
        currencies: currencyService.toSnapshot(),
        clockState: ClockState(lastSeenAtMs: week1MondayMs),
      ),
    );

    final eventService = EventShopService(
      catalog: config.eventShop!,
      items: config.items,
      equipmentFactory: EquipmentFactory(config.equipment),
    );
    final active = eventService.activeEntriesAt(
      week1MondayMs,
      offset: Duration.zero,
    );
    final legEntry = active.firstWhere(
      (e) => e.tier == EventItemTier.legendary,
    );
    final ctx = ShopPlayerContext(
      playerLevel: 30,
      cycleProgress: const CycleProgress(
        ascensionRank: 1,
        highestAscensionRank: 1,
      ),
      dungeonProgresses: const {
        'ancient_crypt': DungeonProgressSnapshot(
          currentDungeonId: 'ancient_crypt',
          clearsCount: 1,
        ),
      },
    );
    final counts = <(String, String), int>{};
    final buyResult = eventService.buy(
      entryId: legEntry.id,
      effectiveNowMs: week1MondayMs,
      inventory: inventory,
      currencyService: currencyService,
      context: ctx,
      random: math.Random(7),
      purchaseCounts: counts,
      timeZoneOffset: Duration.zero,
      actionId: 'event_buy_1',
    ) as EventShopBuySuccess;

    final purchaseRecord = EventShopPurchaseRecord(
      entryId: legEntry.id,
      periodKey: buyResult.periodKey,
      purchasedCount: buyResult.newPurchaseCount,
    );
    await coordinator.saveEventShopTransaction(
      character: character,
      inventory: inventory,
      currencyService: currencyService,
      purchase: purchaseRecord,
      actionId: 'event_buy_1',
    );

    // Panggil ulang dengan actionId sama -> idempoten di DB.
    await coordinator.saveEventShopTransaction(
      character: character,
      inventory: inventory,
      currencyService: currencyService,
      purchase: purchaseRecord,
      actionId: 'event_buy_1',
    );

    final reloaded = await GameSessionCoordinator(
      config: config,
      repository: repo,
      nowMs: () => week1MondayMs,
    ).loadAndProcessOffline();

    expect(reloaded.currencies[kAetherShardCurrencyId], 300 - legEntry.price);
    expect(reloaded.eventShopPurchases, [purchaseRecord]);
    expect(reloaded.inventory.equipmentCount, 1);
    final eq = reloaded.inventory.equipmentById(
      buyResult.purchasedEquipment!.id,
    )!;
    final expectedStats = config.items[legEntry.itemId]!.equipment!.baseStats;
    expect(eq.definitionId, legEntry.itemId);
    expect(eq.rolledStats.hp, expectedStats.hp);
    expect(eq.rolledStats.atk, expectedStats.atk);
    expect(eq.rolledStats.def, expectedStats.def);
    expect(eq.rolledStats.hpPct, expectedStats.hpPct);
    expect(eq.rolledStats.atkPct, expectedStats.atkPct);
    expect(eq.rolledStats.defPct, expectedStats.defPct);

    // Klaim eventshop tercatat di ClaimedRewards.
    final claimedRows = await db.select(db.claimedRewards).get();
    expect(
      claimedRows.any(
        (r) => r.eventId == 'eventshop:event_buy_1:${buyResult.periodKey}',
      ),
      isTrue,
    );

    // Pembelian ulang di minggu yang sama setelah restart ditolak domain.
    final restoredCounts = <(String, String), int>{
      for (final p in reloaded.eventShopPurchases)
        (p.entryId, p.periodKey): p.purchasedCount,
    };
    final blocked = eventService.buy(
      entryId: legEntry.id,
      effectiveNowMs: week1MondayMs + 3600000,
      inventory: reloaded.inventory,
      currencyService: CurrencyService(
        definitions: config.currencies,
        initialBalances: reloaded.currencies,
      ),
      context: ShopPlayerContext(
        playerLevel: 30,
        cycleProgress: const CycleProgress(
          ascensionRank: 1,
          highestAscensionRank: 1,
        ),
        dungeonProgresses: const {
          'ancient_crypt': DungeonProgressSnapshot(
            currentDungeonId: 'ancient_crypt',
            clearsCount: 1,
          ),
        },
        eventShopPurchases: restoredCounts,
      ),
      timeZoneOffset: Duration.zero,
    );
    expect(blocked, isA<EventShopBuyLimitReached>());
  });

  test('validasi invalid di saveEventShopTransaction melakukan rollback transaksi secara penuh', () async {
    final character = PlayerCharacter(
      config: config.progression,
      specializationConfig: config.specializations,
      skillCatalog: config.skills,
      progress: const PlayerProgress(level: 10),
      initialSpecializationId: 'vanguard',
    );
    final inventory = Inventory(definitions: config.items);
    final currencyService = CurrencyService(
      definitions: config.currencies,
      initialBalances: {kAetherShardCurrencyId: 120},
    );
    await repo.saveSnapshot(
      PlayerSaveSnapshot(
        character: character.toSnapshot(),
        inventory: inventory.toSnapshot(),
        session: GameSessionSnapshot(
          lastActiveAtMs: week1MondayMs,
          lastSavedAtMs: week1MondayMs,
          lastOfflineClaimAtMs: week1MondayMs,
        ),
        currencies: currencyService.toSnapshot(),
        clockState: ClockState(lastSeenAtMs: week1MondayMs),
      ),
    );

    // Paksa transaksi gagal saat validasi purchase count negatif.
    currencyService.spend(kAetherShardCurrencyId, 100);
    await expectLater(
      () => repo.saveEventShopTransaction(
        progress: character.toSnapshot().progress,
        inventory: inventory.toSnapshot(),
        equipped: character.toSnapshot().equipped,
        currencies: currencyService.toSnapshot(),
        purchase: const EventShopPurchaseRecord(
          entryId: 'event_dawn_blade_entry',
          periodKey: '2026-W47',
          purchasedCount: -1,
        ),
        actionId: 'bad_tx',
        updatedAtMs: week1MondayMs,
      ),
      throwsStateError,
    );

    final afterFail = await repo.loadSnapshot();
    expect(afterFail!.currencies[kAetherShardCurrencyId], 120);
    expect(afterFail.eventShopPurchases, isEmpty);
  });

  test('persistensi settings notifyEventShopEnding & pruning ClaimedRewards menjaga periode aktif dan memangkas periode lewat', () async {
    await repo.saveSettings(
      const GameSettingsData(notifyEventShopEnding: true),
    );
    final loadedSettings = await repo.loadSettings();
    expect(loadedSettings.notifyEventShopEnding, isTrue);

    const pruner = ClaimedRewardsPruner();
    const retentionCutoffMs = 1_000_000_000;
    const oldClaimedMs = 1_000_000;

    // Kunci minggu aktif tidak dihapus meski claimedAtMs < cutoff.
    expect(
      pruner.shouldPrune(
        eventId: 'eventshop:buy_curr:2026-W47',
        claimedAtMs: oldClaimedMs,
        cutoffMs: retentionCutoffMs,
        activePeriodKeys: const {'2026-W47', '2026-11-16'},
      ),
      isFalse,
    );

    // Kunci minggu lama di luar activePeriodKeys dipangkas.
    expect(
      pruner.shouldPrune(
        eventId: 'eventshop:buy_old:2026-W45',
        claimedAtMs: oldClaimedMs,
        cutoffMs: retentionCutoffMs,
        activePeriodKeys: const {'2026-W47', '2026-11-16'},
      ),
      isTrue,
    );
  });
}
