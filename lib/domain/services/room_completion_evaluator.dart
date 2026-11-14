import '../entities/dungeon_definition.dart';
import '../entities/dungeon_session.dart';
import '../entities/grid_point.dart';
import '../entities/room_encounter.dart';

/// Hasil evaluasi penyelesaian ruangan berdasarkan state domain.
class RoomCompletionEvaluation {
  const RoomCompletionEvaluation({
    required this.roomId,
    required this.isCompleted,
    required this.encountersSatisfied,
    required this.exitRequired,
    required this.exitUnlocked,
    required this.exitReached,
    this.unmetReasons = const [],
  });

  final String roomId;
  final bool isCompleted;
  final bool encountersSatisfied;
  final bool exitRequired;
  final bool exitUnlocked;
  final bool exitReached;
  final List<String> unmetReasons;
}

/// Evaluator domain murni (tanpa dependensi Flame/Flutter) yang menentukan
/// apakah sebuah room telah memenuhi seluruh [RoomCompletionCondition].
class RoomCompletionEvaluator {
  const RoomCompletionEvaluator();

  RoomCompletionEvaluation evaluate({
    required RoomDefinition room,
    required RoomLifecycleState roomLifecycle,
    required List<RoomEncounterState> encounters,
    GridPoint? playerCell,
  }) {
    final condition = room.completionCondition;
    final exitRequired = condition.requiresExit;

    if (roomLifecycle != RoomLifecycleState.active) {
      return RoomCompletionEvaluation(
        roomId: room.id,
        isCompleted: false,
        encountersSatisfied: false,
        exitRequired: exitRequired,
        exitUnlocked: false,
        exitReached: false,
        unmetReasons: ['room_not_active:${roomLifecycle.name}'],
      );
    }

    final combatClauses = <RoomCompletionCondition>[
      if (condition.type != RoomCompletionConditionType.reachExit) condition,
      for (final extra in condition.additionalConditions)
        if (extra.type != RoomCompletionConditionType.reachExit) extra,
    ];

    final unmetReasons = <String>[];
    for (final clause in combatClauses) {
      if (!_isCombatClauseSatisfied(clause, encounters)) {
        unmetReasons.add('combat:${clause.type.name}');
      }
    }

    final encountersSatisfied = unmetReasons.isEmpty;
    final exitUnlocked = encountersSatisfied;
    final exitReached = playerCell != null && playerCell == room.exitPosition;

    if (exitRequired && !exitReached) {
      unmetReasons.add('exit_not_reached');
    }

    final isCompleted = encountersSatisfied && (!exitRequired || exitReached);

    return RoomCompletionEvaluation(
      roomId: room.id,
      isCompleted: isCompleted,
      encountersSatisfied: encountersSatisfied,
      exitRequired: exitRequired,
      exitUnlocked: exitUnlocked,
      exitReached: exitReached,
      unmetReasons: List.unmodifiable(unmetReasons),
    );
  }

  /// Memeriksa apakah hanya syarat encounter/combat sebuah room terpenuhi.
  bool areCombatRequirementsSatisfied(
    RoomDefinition room,
    List<RoomEncounterState> encounters,
  ) {
    final condition = room.completionCondition;
    final combatClauses = <RoomCompletionCondition>[
      if (condition.type != RoomCompletionConditionType.reachExit) condition,
      for (final extra in condition.additionalConditions)
        if (extra.type != RoomCompletionConditionType.reachExit) extra,
    ];
    for (final clause in combatClauses) {
      if (!_isCombatClauseSatisfied(clause, encounters)) {
        return false;
      }
    }
    return true;
  }

  bool _isCombatClauseSatisfied(
    RoomCompletionCondition clause,
    List<RoomEncounterState> encounters,
  ) {
    if (clause.type == RoomCompletionConditionType.reachExit) {
      return true;
    }

    bool matchesGroup(RoomEncounterState e) =>
        clause.requiredSpawnGroup == null ||
        e.spawnGroup == clause.requiredSpawnGroup;

    final List<RoomEncounterState> targets;
    switch (clause.type) {
      case RoomCompletionConditionType.defeatRequiredEnemies:
        targets = encounters
            .where((e) => e.requiredForCompletion && matchesGroup(e))
            .toList(growable: false);
      case RoomCompletionConditionType.defeatElite:
        targets = encounters
            .where(
              (e) => e.requiredForCompletion && matchesGroup(e) && e.isElite,
            )
            .toList(growable: false);
      case RoomCompletionConditionType.defeatBoss:
        targets = encounters
            .where(
              (e) => e.requiredForCompletion && matchesGroup(e) && e.isBoss,
            )
            .toList(growable: false);
      case RoomCompletionConditionType.reachExit:
        return true;
    }

    if (targets.isEmpty) return false;
    if (targets.any((e) => e.isFailed)) return false;

    final targetCount = clause.targetCount;
    if (targetCount != null) {
      final defeated = targets.fold<int>(0, (sum, e) => sum + e.defeatedCount);
      return defeated >= targetCount;
    }
    return targets.every((e) => e.isCompleted);
  }
}
