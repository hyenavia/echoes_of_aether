/// Konfigurasi reward penyelesaian satu dungeon run (M4 Phase E).
class DungeonCompletionReward {
  const DungeonCompletionReward({
    this.expReward = 0,
    this.goldReward = 0,
    this.lootTableId,
  });

  final int expReward;
  final int goldReward;

  /// Id loot table opsional di `loot_tables.json` sebagai hadiah clear dungeon.
  final String? lootTableId;
}
