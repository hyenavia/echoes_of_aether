/// Definisi reward first-clear dari satu lantai The Infinite Spire.
class InfiniteSpireReward {
  const InfiniteSpireReward({
    this.exp = 0,
    this.gold = 0,
    this.items = const {},
    this.currencies = const {},
  });

  final int exp;
  final int gold;
  final Map<String, int> items;
  final Map<String, int> currencies;
}

/// Definisi satu lantai di The Infinite Spire.
class InfiniteSpireFloorDefinition {
  const InfiniteSpireFloorDefinition({
    required this.floor,
    required this.name,
    required this.recommendedLevel,
    this.isBossFloor = false,
    this.enemyIds = const [],
    this.bossId,
    this.bossName,
    this.affixDescription,
    this.reward = const InfiniteSpireReward(),
  });

  final int floor;
  final String name;
  final int recommendedLevel;
  final bool isBossFloor;
  final List<String> enemyIds;
  final String? bossId;
  final String? bossName;
  final String? affixDescription;
  final InfiniteSpireReward reward;
}

/// Konfigurasi The Infinite Spire yang dimuat dari infinite_spire.json.
class InfiniteSpireConfig {
  const InfiniteSpireConfig({
    this.spireId = 'infinite_spire',
    this.name = 'The Infinite Spire',
    this.totalFloors = 100,
    this.floors = const [],
  });

  final String spireId;
  final String name;
  final int totalFloors;
  final List<InfiniteSpireFloorDefinition> floors;

  InfiniteSpireFloorDefinition? floor(int floorNumber) {
    if (floorNumber < 1 || floorNumber > floors.length) return null;
    return floors[floorNumber - 1];
  }
}

/// Snapshot progres The Infinite Spire pemain.
class InfiniteSpireProgressSnapshot {
  const InfiniteSpireProgressSnapshot({
    this.highestFloorCleared = 0,
    this.claimedFloorRewards = const {},
  });

  final int highestFloorCleared;
  final Set<int> claimedFloorRewards;

  bool isFloorCleared(int floor) => floor <= highestFloorCleared;
  bool isRewardClaimed(int floor) => claimedFloorRewards.contains(floor);

  InfiniteSpireProgressSnapshot copyWith({
    int? highestFloorCleared,
    Set<int>? claimedFloorRewards,
  }) {
    return InfiniteSpireProgressSnapshot(
      highestFloorCleared: highestFloorCleared ?? this.highestFloorCleared,
      claimedFloorRewards: claimedFloorRewards ?? this.claimedFloorRewards,
    );
  }
}
