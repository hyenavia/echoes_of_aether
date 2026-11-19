import 'dart:io';

import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/data/models/boss_spire_config_parser.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/services/boss_spire_service.dart';
import 'package:echoes_of_aether/domain/services/currency_service.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/game_clock.dart';
import 'package:echoes_of_aether/domain/services/period_service.dart';
import 'package:echoes_of_aether/domain/services/reward_processor.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadConfig() {
  const parser = GameConfigParser();
  const dungeonParser = DungeonConfigParser();
  final settings = _readAsset('game_config.json');
  final dungeonsJson = _readAsset('dungeons.json');
  return GameConfig(
    monsters: const MonsterConfigParser().parse(_readAsset('monsters.json')),
    damage: parser.parseDamage(settings),
    difficulty: parser.parseDifficulty(settings),
    farming: parser.parseFarming(settings),
    revive: parser.parseRevive(settings),
    progression: parser.parseProgression(settings),
    equipment: parser.parseEquipment(settings),
    time: parser.parseTime(settings),
    claimedRewards: parser.parseClaimedRewards(settings),
    currencies: parser.parseCurrencies(settings),
    items: const ItemConfigParser().parse(_readAsset('items.json')),
    lootTables: const LootConfigParser().parse(_readAsset('loot_tables.json')),
    specializations: const SpecializationConfigParser().parse(
      _readAsset('specializations.json'),
    ),
    dungeons: dungeonParser.parse(
      dungeonsJson,
      ascensionMultiplier: parser.parseDifficulty(settings).ascensionMultiplier,
    ),
    mapLayouts: dungeonParser.parseMaps(dungeonsJson),
    bossSpire: const BossSpireConfigParser().parse(
      _readAsset('boss_spire.json'),
    ),
  );
}

class _FixedClock implements GameClock {
  const _FixedClock(this.nowMs);
  @override
  final int nowMs;
}

void main() {
  test('settleBossSpireVictory membuka lantai berikutnya dan bertahan setelah save ulang & reload', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final config = _loadConfig();
    final repo = DriftPlayerSaveRepository(db: db, config: config);
    const clock = _FixedClock(1700000000000);
    final coordinator = GameSessionCoordinator(
      repository: repo,
      config: config,
      clock: clock,
    );

    final character = PlayerCharacter(
      config: config.progression,
      specializationConfig: config.specializations,
    );
    final inventory = Inventory(definitions: config.items);
    final rewardProcessor = RewardProcessor(
      character: character,
      inventory: inventory,
      items: config.items,
      lootTables: config.lootTables,
      equipmentFactory: EquipmentFactory(config.equipment),
    );
    final currencyService = CurrencyService(definitions: config.currencies);
    const dungeon = DungeonProgressSnapshot();

    // 1. Selesaikan lantai 1 lewat coordinator
    final result = await coordinator.settleBossSpireVictory(
      floorNumber: 1,
      character: character,
      inventory: inventory,
      dungeon: dungeon,
      dungeonProgresses: const {},
      cycleProgress: const CycleProgress(),
      rewardProcessor: rewardProcessor,
      currencyService: currencyService,
      autoSkillEnabled: true,
      lastOfflineClaimAtMs: 0,
    );

    expect(result.isFirstClear, isTrue);
    expect(result.claimId, isNotNull);
    expect(rewardProcessor.claimedEventIds, contains(result.claimId));

    final spireService = BossSpireService(config.bossSpire!);
    final periodService = PeriodService(config: config.time);
    final cycleKey = periodService.biweeklyKey(clock.nowMs);
    final progressInMemory = spireService.getProgress(
      rewardProcessor.claimedEventIds,
      cycleKey: cycleKey,
    );
    expect(progressInMemory.isFloorCleared(1), isTrue);
    expect(progressInMemory.isFloorUnlocked(2), isTrue);

    // 2. Simulasikan saveFromRuntime berikutnya (misal saat kembali ke Town)
    await coordinator.saveFromRuntime(
      character: character,
      inventory: inventory,
      dungeon: dungeon,
      dungeonProgresses: const {},
      cycleProgress: const CycleProgress(),
      rewardProcessor: rewardProcessor,
      autoSkillEnabled: true,
      lastOfflineClaimAtMs: 0,
      currencyService: currencyService,
    );

    // 3. Reload dari DB dan pastikan claimId tetap tersimpan
    final reloaded = await repo.loadSnapshot();
    expect(reloaded, isNotNull);
    expect(reloaded!.claimedEventIds, contains(result.claimId));

    final progressAfterReload = spireService.getProgress(
      reloaded.claimedEventIds,
      cycleKey: cycleKey,
    );
    expect(progressAfterReload.isFloorCleared(1), isTrue);
    expect(progressAfterReload.isFloorUnlocked(2), isTrue);
    expect(progressAfterReload.isFloorUnlocked(3), isFalse);
  });
}
