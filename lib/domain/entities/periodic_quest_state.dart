/// Catatan penyelesaian quest periodik (mis. Daily/Weekly Boss Quest).
class PeriodicQuestState {
  const PeriodicQuestState({
    required this.questId,
    required this.periodKey,
    required this.completedAtMs,
  });

  final String questId;
  final String periodKey;
  final int completedAtMs;

  String get compositeKey => '$questId:$periodKey';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeriodicQuestState &&
          questId == other.questId &&
          periodKey == other.periodKey &&
          completedAtMs == other.completedAtMs;

  @override
  int get hashCode => Object.hash(questId, periodKey, completedAtMs);
}
