import 'dart:math' as math;

import '../entities/boss_event.dart';
import '../entities/periodic_quest_state.dart';
import '../entities/player_character.dart';
import 'currency_service.dart';
import 'difficulty_service.dart';

/// Alasan mengapa penyelesaian Boss Event tidak memberikan hadiah quest.
enum BossQuestNoRewardReason {
  invalidInput,
  crossedReset,
  alreadyCompleted,
  alreadyClaimed,
}

/// Hasil evaluasi `BossQuestService.onBossDefeated`.
class BossQuestSettlementResult {
  const BossQuestSettlementResult({
    required this.claimId,
    required this.rewardGranted,
    this.noRewardReason,
    this.aetherShardGranted = 0,
    this.aetherShardClamped = false,
    this.goldGranted = 0,
    this.expGranted = 0,
    this.levelsGained = 0,
    this.completedState,
  });

  final String claimId;
  final bool rewardGranted;
  final BossQuestNoRewardReason? noRewardReason;
  final int aetherShardGranted;
  final bool aetherShardClamped;
  final int goldGranted;
  final int expGranted;
  final int levelsGained;
  final PeriodicQuestState? completedState;

  String get userMessage {
    if (rewardGranted) {
      final parts = <String>[];
      if (aetherShardGranted > 0) {
        parts.add('+$aetherShardGranted Aether Shard');
      }
      if (goldGranted > 0) parts.add('+$goldGranted Gold');
      if (expGranted > 0) parts.add('+$expGranted EXP');
      if (levelsGained > 0) parts.add('Naik $levelsGained Level!');
      return parts.isEmpty ? 'Quest selesai!' : parts.join(' • ');
    }
    return switch (noRewardReason) {
      BossQuestNoRewardReason.crossedReset =>
        'Tidak ada hadiah (run melewati batas reset periode).',
      BossQuestNoRewardReason.alreadyCompleted ||
      BossQuestNoRewardReason.alreadyClaimed =>
        'Tidak ada hadiah (sudah selesai periode ini).',
      BossQuestNoRewardReason.invalidInput || null => 'Tidak ada hadiah.',
    };
  }
}

/// Service domain murni untuk mengelola status dan hadiah Boss Quest periodik
/// (`bossquest:{questId}:{periodKey}`).
class BossQuestService {
  BossQuestService({Iterable<PeriodicQuestState> initialStates = const []}) {
    for (final state in initialStates) {
      final qid = state.questId.trim();
      final pkey = state.periodKey.trim();
      if (qid.isEmpty || pkey.isEmpty) continue;
      _states[_key(qid, pkey)] = PeriodicQuestState(
        questId: qid,
        periodKey: pkey,
        completedAtMs: math.max(0, state.completedAtMs),
      );
    }
  }

  static const String aetherShardCurrencyId = 'aether_shard';

  final Map<String, PeriodicQuestState> _states = {};

  static String claimId(String questId, String periodKey) =>
      'bossquest:${questId.trim()}:${periodKey.trim()}';

  static String _key(String questId, String periodKey) =>
      '${questId.trim()}:${periodKey.trim()}';

  /// Mengembalikan state penyelesaian quest pada [periodKey], atau `null` bila
  /// belum selesai.
  PeriodicQuestState? stateOf(String questId, String periodKey) {
    final qid = questId.trim();
    final pkey = periodKey.trim();
    if (qid.isEmpty || pkey.isEmpty) return null;
    return _states[_key(qid, pkey)];
  }

  bool isCompleted(String questId, String periodKey) =>
      stateOf(questId, periodKey) != null;

  List<PeriodicQuestState> toSnapshot() =>
      List<PeriodicQuestState>.unmodifiable(_states.values);

  void replaceStates(Iterable<PeriodicQuestState> states) {
    _states.clear();
    for (final state in states) {
      final qid = state.questId.trim();
      final pkey = state.periodKey.trim();
      if (qid.isEmpty || pkey.isEmpty) continue;
      _states[_key(qid, pkey)] = PeriodicQuestState(
        questId: qid,
        periodKey: pkey,
        completedAtMs: math.max(0, state.completedAtMs),
      );
    }
  }

  /// Menghitung hadiah gold & EXP boss quest setelah dikalikan
  /// `rewardMultiplier` profil acuan (dibulatkan, minimal 1 bila dasarnya > 0).
  static ({int aetherShard, int gold, int exp}) computeScaledReward({
    required BossQuestReward reward,
    required DifficultyProfile difficultyProfile,
  }) {
    final mult = difficultyProfile.rewardMultiplier;
    final scaledGold = reward.gold > 0
        ? math.max(1, (reward.gold * mult).round())
        : 0;
    final scaledExp = reward.exp > 0
        ? math.max(1, (reward.exp * mult).round())
        : 0;
    return (
      aetherShard: math.max(0, reward.currency[aetherShardCurrencyId] ?? 0),
      gold: scaledGold,
      exp: scaledExp,
    );
  }

  /// Memproses kemenangan boss event pada akhir run.
  ///
  /// Hadiah diberikan HANYA bila:
  /// - `periodKeyAtStart == currentPeriodKey`
  /// - quest pada `currentPeriodKey` belum selesai
  /// - `claimId` belum pernah diklaim di [claimedEventIds]
  BossQuestSettlementResult onBossDefeated({
    required String questId,
    required String periodKeyAtStart,
    required String currentPeriodKey,
    required BossQuestReward reward,
    required DifficultyProfile difficultyProfile,
    required int completedAtMs,
    required PlayerCharacter character,
    required CurrencyService currencyService,
    required Set<String> claimedEventIds,
  }) {
    final qid = questId.trim();
    final startKey = periodKeyAtStart.trim();
    final curKey = currentPeriodKey.trim();
    final cid = claimId(qid, curKey);

    if (qid.isEmpty || startKey.isEmpty || curKey.isEmpty) {
      return BossQuestSettlementResult(
        claimId: cid,
        rewardGranted: false,
        noRewardReason: BossQuestNoRewardReason.invalidInput,
      );
    }

    if (startKey != curKey) {
      return BossQuestSettlementResult(
        claimId: cid,
        rewardGranted: false,
        noRewardReason: BossQuestNoRewardReason.crossedReset,
      );
    }

    if (isCompleted(qid, curKey)) {
      return BossQuestSettlementResult(
        claimId: cid,
        rewardGranted: false,
        noRewardReason: BossQuestNoRewardReason.alreadyCompleted,
      );
    }

    if (claimedEventIds.contains(cid)) {
      return BossQuestSettlementResult(
        claimId: cid,
        rewardGranted: false,
        noRewardReason: BossQuestNoRewardReason.alreadyClaimed,
      );
    }

    final scaled = computeScaledReward(
      reward: reward,
      difficultyProfile: difficultyProfile,
    );

    var shardGranted = 0;
    var shardClamped = false;
    if (scaled.aetherShard > 0) {
      final grantRes = currencyService.grant(
        aetherShardCurrencyId,
        scaled.aetherShard,
        claimId: cid,
      );
      if (!grantRes.isSuccess) {
        return BossQuestSettlementResult(
          claimId: cid,
          rewardGranted: false,
          noRewardReason: BossQuestNoRewardReason.invalidInput,
        );
      }
      shardGranted = grantRes.delta;
      shardClamped = grantRes.clamped;
    }

    final levelsGained = character.receiveReward(
      exp: scaled.exp,
      gold: scaled.gold,
    );
    claimedEventIds.add(cid);
    final completedState = PeriodicQuestState(
      questId: qid,
      periodKey: curKey,
      completedAtMs: math.max(0, completedAtMs),
    );
    _states[_key(qid, curKey)] = completedState;

    return BossQuestSettlementResult(
      claimId: cid,
      rewardGranted: true,
      aetherShardGranted: shardGranted,
      aetherShardClamped: shardClamped,
      goldGranted: scaled.gold,
      expGranted: scaled.exp,
      levelsGained: levelsGained,
      completedState: completedState,
    );
  }
}
