import 'dart:math' as math;

import '../entities/dungeon_reward.dart';
import '../entities/dungeon_session.dart';
import '../entities/game_config.dart';
import '../entities/dungeon_definition.dart';
import 'difficulty_service.dart';
import 'dungeon_manager.dart';
import 'reward_processor.dart';

/// Hasil settlement completion reward dungeon yang aman dari klaim ganda.
class DungeonSettlementResult {
  const DungeonSettlementResult({
    required this.eventId,
    required this.granted,
    required this.validCompletion,
  });

  final String eventId;
  final GrantedReward? granted;
  final bool validCompletion;
}

/// Koordinator domain untuk menyelesaikan reward penyelesaian room maupun
/// penyelesaian dungeon satu kali per `runId` melalui [RewardProcessor].
class DungeonRewardSettlementService {
  const DungeonRewardSettlementService();

  static String roomEventId(String runId, String roomId) =>
      'room_clear:$runId:$roomId';

  static String dungeonEventId(String runId) => 'dungeon_clear:$runId';

  /// Memproses reward opsional pada room yang baru selesai secara idempotent.
  GrantedReward? settleRoomCompleted({
    required DungeonSession session,
    required RoomDefinition room,
    required RewardProcessor rewardProcessor,
    required math.Random random,
    DifficultyProfile difficultyProfile = DifficultyProfile.identity,
    DifficultyService difficultyService = const DifficultyService(),
  }) {
    final roomReward = room.reward;
    if (roomReward == null || roomReward.isEmpty) return null;
    if (!session.isRoomCleared(room.id)) return null;

    final eventId = roomEventId(session.runId, room.id);
    return rewardProcessor.processDungeonCompletion(
      eventId: eventId,
      reward: DungeonCompletionReward(
        expReward: roomReward.expReward,
        goldReward: roomReward.goldReward,
        lootTableId: roomReward.lootTableId,
      ),
      random: random,
      difficultyProfile: difficultyProfile,
      difficultyService: difficultyService,
    );
  }

  /// Memvalidasi penyelesaian dungeon dan memproses [DungeonCompletionReward]
  /// paling banyak satu kali untuk `session.runId`.
  DungeonSettlementResult settleDungeonCompleted({
    required DungeonEndedEvent event,
    required GameConfig config,
    required RewardProcessor rewardProcessor,
    required math.Random random,
    DungeonManager? dungeonManager,
    DifficultyProfile difficultyProfile = DifficultyProfile.identity,
    DifficultyService difficultyService = const DifficultyService(),
  }) {
    final session = event.session;
    final eventId = dungeonEventId(session.runId);
    if (event.finalStatus != DungeonSessionStatus.completed ||
        event.effectiveReason != DungeonEndReason.completed) {
      return DungeonSettlementResult(
        eventId: eventId,
        granted: null,
        validCompletion: false,
      );
    }

    final dungeon = event.dungeon ?? config.dungeons[session.dungeonId];
    final currentRoom = dungeon?.roomById(session.currentRoomId);
    final isCompleteValid =
        dungeon != null &&
        currentRoom != null &&
        currentRoom.isFinalRoom &&
        session.isRoomCleared(currentRoom.id);
    if (!isCompleteValid) {
      return DungeonSettlementResult(
        eventId: eventId,
        granted: null,
        validCompletion: false,
      );
    }

    if (session.completionRewardClaimed || rewardProcessor.isClaimed(eventId)) {
      if (dungeonManager != null) {
        dungeonManager.markCompletionRewardClaimed();
      } else {
        rewardProcessor.markClaimed(eventId);
      }
      return DungeonSettlementResult(
        eventId: eventId,
        granted: GrantedReward(eventId: eventId, alreadyClaimed: true),
        validCompletion: true,
      );
    }

    final reward = dungeon.completionReward ?? config.dungeonCompletion;
    final granted = rewardProcessor.processDungeonCompletion(
      eventId: eventId,
      reward: reward,
      random: random,
      difficultyProfile: difficultyProfile,
      difficultyService: difficultyService,
    );
    dungeonManager?.markCompletionRewardClaimed();
    return DungeonSettlementResult(
      eventId: eventId,
      granted: granted,
      validCompletion: true,
    );
  }
}
