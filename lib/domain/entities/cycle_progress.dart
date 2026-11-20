import 'dart:math' as math;

/// State siklus ascension pemain saat ini.
class CycleProgress {
  const CycleProgress({
    this.ascensionRank = 0,
    int? highestAscensionRank,
    this.lastNormalDungeonId,
  }) : assert(ascensionRank >= 0, 'ascensionRank must be >= 0'),
       highestAscensionRank = highestAscensionRank ?? ascensionRank,
       assert(
         (highestAscensionRank ?? ascensionRank) >= ascensionRank,
         'highestAscensionRank must be >= ascensionRank',
       );

  /// Membuat [CycleProgress] dengan sanitasi defensif untuk nilai tidak valid.
  factory CycleProgress.sanitized({
    int ascensionRank = 0,
    int? highestAscensionRank,
    String? lastNormalDungeonId,
  }) {
    final normalizedRank = ascensionRank < 0 ? 0 : ascensionRank;
    final rawHighest = highestAscensionRank ?? normalizedRank;
    final normalizedHighest = math.max(
      normalizedRank,
      rawHighest < 0 ? 0 : rawHighest,
    );
    final normalizedDungeonId = lastNormalDungeonId?.trim();
    return CycleProgress(
      ascensionRank: normalizedRank,
      highestAscensionRank: normalizedHighest,
      lastNormalDungeonId:
          normalizedDungeonId == null || normalizedDungeonId.isEmpty
          ? null
          : normalizedDungeonId,
    );
  }

  /// Batas tingkat dunia puncak (Peak World Tier).
  static const int kPeakWorldRank = 5;

  /// Rank siklus aktif saat ini (`>= 0`). Rank 0 berarti belum pernah ascension.
  final int ascensionRank;

  /// Rank siklus tertinggi yang pernah dicapai (`>= ascensionRank`).
  /// Memungkinkan pemain turun ke rank `0 .. highestAscensionRank` untuk farming.
  final int highestAscensionRank;

  /// Apakah pemain sudah berada di tingkat dunia puncak (*Peak World Tier*).
  bool get isPeakWorldTier => highestAscensionRank >= kPeakWorldRank;

  /// ID dungeon normal terakhir yang dipilih/diselesaikan pemain.
  final String? lastNormalDungeonId;

  /// Apakah pemain sudah memiliki ID dungeon normal terakhir yang valid.
  bool get hasLastNormalDungeon =>
      lastNormalDungeonId != null && lastNormalDungeonId!.isNotEmpty;

  CycleProgress copyWith({
    int? ascensionRank,
    int? highestAscensionRank,
    String? lastNormalDungeonId,
    bool clearLastNormalDungeonId = false,
  }) {
    final rawRank = ascensionRank ?? this.ascensionRank;
    final nextRank = rawRank < 0 ? 0 : rawRank;
    final rawHighest = highestAscensionRank ?? this.highestAscensionRank;
    final nextHighest = math.max(nextRank, rawHighest < 0 ? 0 : rawHighest);
    return CycleProgress(
      ascensionRank: nextRank,
      highestAscensionRank: nextHighest,
      lastNormalDungeonId: clearLastNormalDungeonId
          ? null
          : (lastNormalDungeonId ?? this.lastNormalDungeonId),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CycleProgress &&
            other.ascensionRank == ascensionRank &&
            other.highestAscensionRank == highestAscensionRank &&
            other.lastNormalDungeonId == lastNormalDungeonId;
  }

  @override
  int get hashCode =>
      Object.hash(ascensionRank, highestAscensionRank, lastNormalDungeonId);

  @override
  String toString() =>
      'CycleProgress(ascensionRank: $ascensionRank, '
      'highestAscensionRank: $highestAscensionRank, '
      'lastNormalDungeonId: $lastNormalDungeonId)';
}
