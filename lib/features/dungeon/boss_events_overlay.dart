import 'package:flutter/material.dart';

import '../../core/utils/number_formatter.dart';

/// Data tampilan read-only untuk satu kartu Boss Event (Daily atau Weekly).
class BossEventCardData {
  const BossEventCardData({
    required this.periodKeyId,
    required this.periodLabel,
    required this.bossName,
    required this.referenceDungeonName,
    required this.recommendedLevel,
    required this.isCompleted,
    required this.remainingToReset,
    required this.rewardSummary,
    required this.onFight,
  });

  final String periodKeyId;
  final String periodLabel;
  final String bossName;
  final String referenceDungeonName;
  final int recommendedLevel;
  final bool isCompleted;
  final Duration remainingToReset;
  final String rewardSummary;
  final VoidCallback onFight;
}

/// Layar/overlay fungsional minimal untuk daftar Boss Event (Daily & Weekly).
/// Tidak menyimpan state gameplay maupun logika aturan game.
class BossEventsOverlay extends StatelessWidget {
  const BossEventsOverlay({
    super.key,
    required this.daily,
    required this.weekly,
    required this.onClose,
    this.embedded = false,
  });

  final BossEventCardData daily;
  final BossEventCardData weekly;
  final VoidCallback onClose;
  final bool embedded;

  static String formatCountdown(Duration duration) {
    final safeSeconds = duration.isNegative ? 0 : duration.inSeconds;
    final days = safeSeconds ~/ 86400;
    final hours = (safeSeconds % 86400) ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    final seconds = safeSeconds % 60;
    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (days > 0) {
      return '${days}h $hh:$mm:$ss';
    }
    return '$hh:$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (embedded) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BossCard(data: daily),
            const SizedBox(height: 12),
            _BossCard(data: weekly),
          ],
        ),
      );
    }
    return Material(
      color: Colors.black54,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Boss Events',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        key: const Key('boss_events_close'),
                        onPressed: onClose,
                        icon: const Icon(Icons.close),
                        tooltip: 'Tutup',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _BossCard(data: daily),
                  const SizedBox(height: 12),
                  _BossCard(data: weekly),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BossCard extends StatelessWidget {
  const _BossCard({required this.data});

  final BossEventCardData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusLabel = data.isCompleted ? 'Selesai' : 'Belum';
    final countdown = BossEventsOverlay.formatCountdown(data.remainingToReset);

    return Card(
      key: Key('boss_card_${data.periodKeyId}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data.periodLabel,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                Text(
                  statusLabel,
                  key: Key('boss_status_${data.periodKeyId}'),
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(data.bossName, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Peringatan: Rekomendasi Lv ${NumberFormatter.format(data.recommendedLevel)} (${data.referenceDungeonName})',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Hadiah Quest: ${data.rewardSummary}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Reset dalam: $countdown',
              key: Key('boss_countdown_${data.periodKeyId}'),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                key: Key('boss_fight_${data.periodKeyId}'),
                onPressed: data.onFight,
                child: const Text('Lawan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
