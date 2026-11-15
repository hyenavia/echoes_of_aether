import 'dart:io';

import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
import 'package:echoes_of_aether/data/database/app_database.dart'
    hide ClockState, PeriodicQuestState;
import 'package:echoes_of_aether/data/models/boss_events_config_parser.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/boss_event.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/time_config.dart';
import 'package:echoes_of_aether/domain/services/boss_quest_service.dart';
import 'package:echoes_of_aether/domain/services/currency_service.dart';
import 'package:echoes_of_aether/domain/services/difficulty_service.dart';
import 'package:echoes_of_aether/domain/services/period_service.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadTestConfig() {
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
    dungeonCompletion: parser.parseDungeonCompletion(settings),
    items: const ItemConfigParser().parse(_readAsset('items.json')),
    lootTables: const LootConfigParser().parse(_readAsset('loot_tables.json')),
    skills: const SkillConfigParser().parse(_readAsset('skills.json')),
    specializations: const SpecializationConfigParser().parse(
      _readAsset('specializations.json'),
    ),
    dungeons: dungeonParser.parse(
      dungeonsJson,
      ascensionMultiplier: parser.parseDifficulty(settings).ascensionMultiplier,
    ),
    mapLayouts: dungeonParser.parseMaps(dungeonsJson),
    bossEvents: const BossEventsConfigParser().parse(
      _readAsset('boss_events.json'),
    ),
    shop: const ShopConfigParser().parse(_readAsset('shop.json')),
  );
}

class _FailingSaveRepository extends DriftPlayerSaveRepository {
  _FailingSaveRepository({required super.db, required super.config});

  bool shouldFailSave = false;

  @override
  Future<void> saveSnapshot(PlayerSaveSnapshot snapshot) async {
    if (shouldFailSave) {
      throw StateError('Simulated DB write failure');
    }
    await super.saveSnapshot(snapshot);
  }
}

void main() {
  group('BossQuestService & Stage 4 Persistence', () {
    late GameConfig config;

    setUpAll(() {
      config = _loadTestConfig();
    });

    test('kemenangan pertama memberi shard+gold+EXP sekali, kemenangan kedua tidak memberi apa pun', () {
      final character = PlayerCharacter(config: config.progression);
      final currencies = CurrencyService(definitions: config.currencies);
      final questService = BossQuestService();
      final claimed = <String>{};
      const profile = DifficultyProfile(
        hpMultiplier: 1.0,
        atkMultiplier: 1.0,
        defMultiplier: 1.0,
        rewardMultiplier: 1.5,
      );
      const reward = BossQuestReward(
        currency: {'aether_shard': 40},
        gold: 100,
        exp: 150,
      );

      final first = questService.onBossDefeated(
        questId: 'daily_boss_quest',
        periodKeyAtStart: '2026-11-16',
        currentPeriodKey: '2026-11-16',
        reward: reward,
        difficultyProfile: profile,
        completedAtMs: 1000,
        character: character,
        currencyService: currencies,
        claimedEventIds: claimed,
      );

      expect(first.rewardGranted, isTrue);
      expect(first.claimId, 'bossquest:daily_boss_quest:2026-11-16');
      expect(first.aetherShardGranted, 40);
      expect(first.goldGranted, 150);
      expect(first.expGranted, 225);
      expect(currencies.balance('aether_shard'), 40);
      expect(character.gold, 150);
      expect(
        questService.isCompleted('daily_boss_quest', '2026-11-16'),
        isTrue,
      );

      final shardBefore = currencies.balance('aether_shard');
      final goldBefore = character.gold;
      final levelBefore = character.level;
      final expBefore = character.currentExp;

      final second = questService.onBossDefeated(
        questId: 'daily_boss_quest',
        periodKeyAtStart: '2026-11-16',
        currentPeriodKey: '2026-11-16',
        reward: reward,
        difficultyProfile: profile,
        completedAtMs: 2000,
        character: character,
        currencyService: currencies,
        claimedEventIds: claimed,
      );

      expect(second.rewardGranted, isFalse);
      expect(second.noRewardReason, BossQuestNoRewardReason.alreadyCompleted);
      expect(currencies.balance('aether_shard'), shardBefore);
      expect(character.gold, goldBefore);
      expect(character.level, levelBefore);
      expect(character.currentExp, expBefore);
    });

    test('batas reset harian/mingguan dan run melewati reset ditangani dengan benar', () {
      final periodService = PeriodService(
        config: const TimeConfig(resetHour: 0, epochMonday: '2026-11-16'),
        timeZoneOffset: () => Duration.zero,
      );
      final day1Key = periodService.keyFor(
        Period.daily,
        DateTime.utc(2026, 11, 16, 23, 55).millisecondsSinceEpoch,
      );
      final day2Key = periodService.keyFor(
        Period.daily,
        DateTime.utc(2026, 11, 17, 0, 5).millisecondsSinceEpoch,
      );
      final week1Key = periodService.keyFor(
        Period.weekly,
        DateTime.utc(2026, 11, 22, 23, 55).millisecondsSinceEpoch,
      );
      final week2Key = periodService.keyFor(
        Period.weekly,
        DateTime.utc(2026, 11, 23, 0, 5).millisecondsSinceEpoch,
      );

      expect(day1Key, '2026-11-16');
      expect(day2Key, '2026-11-17');
      expect(week1Key, '2026-11-16');
      expect(week2Key, '2026-11-23');

      final character = PlayerCharacter(config: config.progression);
      final currencies = CurrencyService(definitions: config.currencies);
      final questService = BossQuestService();
      final claimed = <String>{};
      const reward = BossQuestReward(
        currency: {'aether_shard': 25},
        gold: 50,
        exp: 80,
      );

      // Run dimulai pada day1Key dan selesai pada day2Key -> melewati reset, tanpa hadiah.
      final crossed = questService.onBossDefeated(
        questId: 'daily_boss_quest',
        periodKeyAtStart: day1Key,
        currentPeriodKey: day2Key,
        reward: reward,
        difficultyProfile: DifficultyProfile.identity,
        completedAtMs: 5000,
        character: character,
        currencyService: currencies,
        claimedEventIds: claimed,
      );
      expect(crossed.rewardGranted, isFalse);
      expect(crossed.noRewardReason, BossQuestNoRewardReason.crossedReset);
      expect(questService.isCompleted('daily_boss_quest', day2Key), isFalse);
      expect(currencies.balance('aether_shard'), 0);

      // Run baru dimulai dan selesai pada day2Key -> dapat hadiah.
      final day2Win = questService.onBossDefeated(
        questId: 'daily_boss_quest',
        periodKeyAtStart: day2Key,
        currentPeriodKey: day2Key,
        reward: reward,
        difficultyProfile: DifficultyProfile.identity,
        completedAtMs: 6000,
        character: character,
        currencyService: currencies,
        claimedEventIds: claimed,
      );
      expect(day2Win.rewardGranted, isTrue);
      expect(currencies.balance('aether_shard'), 25);

      // Weekly: menang di week1, lalu menang lagi di week2 -> masing-masing dapat sekali.
      final w1 = questService.onBossDefeated(
        questId: 'weekly_boss_quest',
        periodKeyAtStart: week1Key,
        currentPeriodKey: week1Key,
        reward: reward,
        difficultyProfile: DifficultyProfile.identity,
        completedAtMs: 7000,
        character: character,
        currencyService: currencies,
        claimedEventIds: claimed,
      );
      final w2 = questService.onBossDefeated(
        questId: 'weekly_boss_quest',
        periodKeyAtStart: week2Key,
        currentPeriodKey: week2Key,
        reward: reward,
        difficultyProfile: DifficultyProfile.identity,
        completedAtMs: 8000,
        character: character,
        currencyService: currencies,
        claimedEventIds: claimed,
      );
      expect(w1.rewardGranted, isTrue);
      expect(w2.rewardGranted, isTrue);
      expect(currencies.balance('aether_shard'), 75);
    });

    test('level-up akibat EXP quest dan clamp Aether Shard ke max_amount', () {
      final character = PlayerCharacter(config: config.progression);
      final maxAmount = config.currencies['aether_shard']!.maxAmount;
      final currencies = CurrencyService(
        definitions: config.currencies,
        initialBalances: {'aether_shard': maxAmount - 10},
      );
      final questService = BossQuestService();
      final claimed = <String>{};

      final res = questService.onBossDefeated(
        questId: 'weekly_boss_quest',
        periodKeyAtStart: '2026-11-16',
        currentPeriodKey: '2026-11-16',
        reward: const BossQuestReward(
          currency: {'aether_shard': 100},
          gold: 1,
          exp: 5000,
        ),
        difficultyProfile: const DifficultyProfile(
          hpMultiplier: 1.0,
          atkMultiplier: 1.0,
          defMultiplier: 1.0,
          rewardMultiplier: 0.1,
        ),
        completedAtMs: 1000,
        character: character,
        currencyService: currencies,
        claimedEventIds: claimed,
      );

      expect(res.rewardGranted, isTrue);
      expect(res.aetherShardClamped, isTrue);
      expect(res.aetherShardGranted, 10);
      expect(currencies.balance('aether_shard'), maxAmount);
      expect(res.goldGranted, 1); // minimal 1 bila dasarnya > 0
      expect(res.levelsGained, greaterThan(0));
      expect(character.level, greaterThan(1));
    });

    test('jam mundur, atomisitas kegagalan persistensi, dan recovery lintas restart tanpa hadiah ganda', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = _FailingSaveRepository(db: db, config: config);

      var currentNow = DateTime(2026, 11, 17, 12, 0).millisecondsSinceEpoch;
      final coordinator1 = GameSessionCoordinator(
        repository: repo,
        config: config,
        nowMs: () => currentNow,
      );
      final boot1 = await coordinator1.loadAndProcessOffline();
      final currencies = CurrencyService(
        definitions: config.currencies,
        initialBalances: boot1.currencies,
        claimedIds: boot1.rewardProcessor.claimedEventIds,
      );
      final questService = BossQuestService(
        initialStates: boot1.periodicQuestStates,
      );
      final periodKey = PeriodService(config: config.time)
          .keyFor(Period.daily, currentNow);

      // 1. Simulasi kegagalan persistensi di tengah -> seluruh state di-rollback.
      repo.shouldFailSave = true;
      await expectLater(
        () => coordinator1.settleBossQuestVictory(
          period: Period.daily,
          periodKeyAtStart: periodKey,
          difficultyProfile: DifficultyProfile.identity,
          character: boot1.character,
          inventory: boot1.inventory,
          dungeon: boot1.dungeon,
          dungeonProgresses: boot1.dungeonProgresses,
          cycleProgress: boot1.cycleProgress,
          rewardProcessor: boot1.rewardProcessor,
          currencyService: currencies,
          bossQuestService: questService,
          autoSkillEnabled: boot1.session.autoSkillEnabled,
          lastOfflineClaimAtMs: boot1.session.lastOfflineClaimAtMs,
        ),
        throwsStateError,
      );
      expect(currencies.balance('aether_shard'), 0);
      expect(boot1.character.gold, 0);
      expect(
        questService.isCompleted(config.bossEvents!.daily.questId, periodKey),
        isFalse,
      );
      expect(
        boot1.rewardProcessor.isClaimed(
          BossQuestService.claimId(config.bossEvents!.daily.questId, periodKey),
        ),
        isFalse,
      );

      // 2. Persistensi normal -> berhasil sekali.
      repo.shouldFailSave = false;
      final settled = await coordinator1.settleBossQuestVictory(
        period: Period.daily,
        periodKeyAtStart: periodKey,
        difficultyProfile: DifficultyProfile.identity,
        character: boot1.character,
        inventory: boot1.inventory,
        dungeon: boot1.dungeon,
        dungeonProgresses: boot1.dungeonProgresses,
        cycleProgress: boot1.cycleProgress,
        rewardProcessor: boot1.rewardProcessor,
        currencyService: currencies,
        bossQuestService: questService,
        autoSkillEnabled: boot1.session.autoSkillEnabled,
        lastOfflineClaimAtMs: boot1.session.lastOfflineClaimAtMs,
      );
      expect(settled.rewardGranted, isTrue);
      final shardAfterWin = currencies.balance('aether_shard');
      final goldAfterWin = boot1.character.gold;
      expect(shardAfterWin, greaterThan(0));

      // 3. Jam dimundurkan 2 hari -> ClockGuard menahan periode, tidak membuka quest lagi.
      currentNow = DateTime(2026, 11, 15, 12, 0).millisecondsSinceEpoch;
      final clockBackAttempt = await coordinator1.settleBossQuestVictory(
        period: Period.daily,
        periodKeyAtStart: periodKey,
        difficultyProfile: DifficultyProfile.identity,
        character: boot1.character,
        inventory: boot1.inventory,
        dungeon: boot1.dungeon,
        dungeonProgresses: boot1.dungeonProgresses,
        cycleProgress: boot1.cycleProgress,
        rewardProcessor: boot1.rewardProcessor,
        currencyService: currencies,
        bossQuestService: questService,
        autoSkillEnabled: boot1.session.autoSkillEnabled,
        lastOfflineClaimAtMs: boot1.session.lastOfflineClaimAtMs,
      );
      expect(clockBackAttempt.rewardGranted, isFalse);
      expect(currencies.balance('aether_shard'), shardAfterWin);
      expect(boot1.character.gold, goldAfterWin);

      // 4. Restart aplikasi -> PeriodicQuestStates & ClaimedRewards dipulihkan.
      currentNow = DateTime(2026, 11, 17, 13, 0).millisecondsSinceEpoch;
      final coordinator2 = GameSessionCoordinator(
        repository: repo,
        config: config,
        nowMs: () => currentNow,
      );
      final boot2 = await coordinator2.loadAndProcessOffline();
      final currencies2 = CurrencyService(
        definitions: config.currencies,
        initialBalances: boot2.currencies,
        claimedIds: boot2.rewardProcessor.claimedEventIds,
      );
      final questService2 = BossQuestService(
        initialStates: boot2.periodicQuestStates,
      );
      expect(currencies2.balance('aether_shard'), shardAfterWin);
      expect(
        questService2.isCompleted(config.bossEvents!.daily.questId, periodKey),
        isTrue,
      );
      final afterRestartAttempt = await coordinator2.settleBossQuestVictory(
        period: Period.daily,
        periodKeyAtStart: periodKey,
        difficultyProfile: DifficultyProfile.identity,
        character: boot2.character,
        inventory: boot2.inventory,
        dungeon: boot2.dungeon,
        dungeonProgresses: boot2.dungeonProgresses,
        cycleProgress: boot2.cycleProgress,
        rewardProcessor: boot2.rewardProcessor,
        currencyService: currencies2,
        bossQuestService: questService2,
        autoSkillEnabled: boot2.session.autoSkillEnabled,
        lastOfflineClaimAtMs: boot2.session.lastOfflineClaimAtMs,
      );
      expect(afterRestartAttempt.rewardGranted, isFalse);
      expect(currencies2.balance('aether_shard'), shardAfterWin);
    });
  });
}
