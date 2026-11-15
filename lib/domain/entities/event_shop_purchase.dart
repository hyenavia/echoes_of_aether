/// Satu catatan jumlah pembelian entri Event Shop pada suatu periode mingguan
/// (`EventShopPurchases`, schema Drift v7).
class EventShopPurchaseRecord {
  const EventShopPurchaseRecord({
    required this.entryId,
    required this.periodKey,
    this.purchasedCount = 1,
  });

  final String entryId;
  final String periodKey;
  final int purchasedCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventShopPurchaseRecord &&
          entryId == other.entryId &&
          periodKey == other.periodKey &&
          purchasedCount == other.purchasedCount;

  @override
  int get hashCode => Object.hash(entryId, periodKey, purchasedCount);
}
