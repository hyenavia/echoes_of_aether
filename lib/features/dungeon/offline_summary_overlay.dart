import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../domain/entities/dungeon_definition.dart';
import '../../domain/entities/item_definition.dart';
import '../../domain/entities/offline_activity.dart';
import '../shared/widgets/shared_widgets.dart';

/// Modal ringkasan hasil **Hybrid Offline Progression** (M6 Stage 3).
/// Ditampilkan ketika terdapat [OfflineSummarySnapshot] yang belum diakui dan
/// tetap muncul lintas restart hingga pemain menutupnya ([onAcknowledge]).
class OfflineSummaryOverlay extends StatelessWidget {
  const OfflineSummaryOverlay({
    super.key,
    required this.summary,
    required this.items,
    this.dungeons = const {},
    this.selectedDungeonId,
    required this.onAcknowledge,
  });

  final OfflineSummarySnapshot summary;
  final Map<String, ItemDefinition> items;
  final Map<String, DungeonDefinition> dungeons;
  final String? selectedDungeonId;
  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    final dungeonName = selectedDungeonId != null
        ? dungeons[selectedDungeonId]?.name
        : null;
    final stackEntries = summary.addedStacks.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final overflowEntries = summary.overflowStacks.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final hasOverflow =
        overflowEntries.isNotEmpty || summary.droppedEquipmentCount > 0;

    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.midnightForest.withValues(alpha: 0.78),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
              child: PanelFrame(
                showCornerOrnaments: true,
                padding: const EdgeInsets.all(AppSpacing.lg),
                borderColor: ext.gold,
                boxShadow: AppShadows.glow(ext.gold, alpha: 0.24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.deepForest,
                            border: Border.all(
                              color: ext.gold.withValues(alpha: 0.6),
                            ),
                            boxShadow: AppShadows.glow(ext.gold, alpha: 0.18),
                          ),
                          child: Icon(
                            Icons.nights_stay_outlined,
                            size: 18,
                            color: ext.gold,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            'Ringkasan Offline',
                            style: AppTypography.headingSerif(
                              theme.textTheme.titleLarge,
                              color: ext.gold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${_modeLabel(summary.mode)}'
                              '${dungeonName != null ? ' • $dungeonName' : ''}',
                              style: theme.textTheme.titleSmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_stateLabel(summary.finalState)} • '
                              'Durasi: ${_formatDurationMs(summary.effectiveElapsedMs)}'
                              '${summary.cappedAtMaxDuration ? ' (maks 8 jam)' : ''}',
                              style: AppTypography.numeric(
                                theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (summary.failureReason != null &&
                                summary.failureReason!.trim().isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                  border: Border.all(
                                    color: theme.colorScheme.error.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  summary.failureReason!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.sm),
                            if (summary.runsAttempted > 0 ||
                                summary.roomsCleared > 0 ||
                                summary.encountersCleared > 0) ...[
                              const SectionHeader(
                                title: 'Aktivitas',
                                useSerif: true,
                              ),
                              PanelFrame(
                                backgroundColor: AppColors.surfaceDark,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.xs + 2,
                                ),
                                child: Column(
                                  children: [
                                    _MetricRow(
                                      label: 'Run',
                                      value:
                                          '${summary.runsCompleted}/${summary.runsAttempted} selesai'
                                          '${summary.runsFailed > 0 ? ' (${summary.runsFailed} gagal)' : ''}',
                                    ),
                                    _MetricRow(
                                      label: 'Progres',
                                      value:
                                          '${summary.roomsCleared} room • '
                                          '${summary.encountersCleared} encounter',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (summary.expGained > 0 ||
                                summary.goldGained > 0 ||
                                summary.levelsGained > 0) ...[
                              const SizedBox(height: AppSpacing.xs),
                              const SectionHeader(
                                title: 'Hadiah',
                                useSerif: true,
                              ),
                              PanelFrame(
                                backgroundColor: AppColors.surfaceDark,
                                borderColor: ext.gold.withValues(alpha: 0.4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.xs + 2,
                                ),
                                child: _MetricRow(
                                  label: 'Hadiah Utama',
                                  value:
                                      '+${NumberFormatter.format(summary.expGained)} EXP • '
                                      '+${NumberFormatter.format(summary.goldGained)} Gold'
                                      '${summary.levelsGained > 0 ? ' (+${NumberFormatter.format(summary.levelsGained)} Lv)' : ''}',
                                ),
                              ),
                            ],
                            if (stackEntries.isNotEmpty ||
                                summary.addedEquipmentCount > 0 ||
                                summary.autoSoldEquipmentCount > 0) ...[
                              const SizedBox(height: AppSpacing.xs),
                              PanelFrame(
                                backgroundColor: AppColors.surfaceDark,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.xs + 2,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (stackEntries.isNotEmpty) ...[
                                      Text(
                                        'Item Diperoleh:',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(color: ext.gold),
                                      ),
                                      const SizedBox(height: 2),
                                      for (final entry in stackEntries)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 2,
                                          ),
                                          child: Text(
                                            '• ${items[entry.key]?.name ?? entry.key} x${entry.value}',
                                            style: AppTypography.numeric(
                                              theme.textTheme.bodySmall,
                                            ),
                                          ),
                                        ),
                                    ],
                                    if (summary.addedEquipmentCount > 0) ...[
                                      if (stackEntries.isNotEmpty)
                                        const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        'Equipment masuk tas: +${summary.addedEquipmentCount}',
                                        style: AppTypography.numeric(
                                          theme.textTheme.bodySmall?.copyWith(
                                            color: AppColors.aetherBlue,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (summary.autoSoldEquipmentCount > 0) ...[
                                      if (stackEntries.isNotEmpty ||
                                          summary.addedEquipmentCount > 0)
                                        const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        'Gear sampah terjual otomatis: +${summary.autoSoldEquipmentCount} item (+${NumberFormatter.format(summary.autoSoldEquipmentGold)} Gold)',
                                        style: AppTypography.numeric(
                                          theme.textTheme.bodySmall?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if (summary.autoSalvagedEquipmentCount >
                                        0) ...[
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        'Gear AFK dibongkar otomatis: +${summary.autoSalvagedEquipmentCount} item (+${NumberFormatter.format(summary.autoSalvagedScrapCount)} Aether Scrap)',
                                        style: AppTypography.numeric(
                                          theme.textTheme.bodySmall?.copyWith(
                                            color: AppColors.aetherBlue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                            if (!summary.hasRewards) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Tidak ada hadiah baru yang diperoleh.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            if (hasOverflow) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Catatan: sebagian drop tidak masuk karena batas tas'
                                '${summary.droppedEquipmentCount > 0 ? ' (${summary.droppedEquipmentCount} equipment terlewat)' : ''}.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PrimaryButton(
                      label: 'Tutup & Simpan',
                      onPressed: onAcknowledge,
                      expand: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _modeLabel(OfflineActivityMode mode) {
    switch (mode) {
      case OfflineActivityMode.pauseProgression:
        return 'Pause Progression';
      case OfflineActivityMode.continueDungeon:
        return 'Continue Dungeon';
      case OfflineActivityMode.autoFarming:
        return 'Auto Farming';
    }
  }

  static String _stateLabel(OfflineActivityState state) {
    switch (state) {
      case OfflineActivityState.completed:
        return 'Selesai';
      case OfflineActivityState.failed:
        return 'Terhenti';
      case OfflineActivityState.interrupted:
        return 'Tertunda';
      case OfflineActivityState.inactive:
      case OfflineActivityState.configured:
      case OfflineActivityState.pending:
      case OfflineActivityState.processing:
        return state.name;
    }
  }

  static String _formatDurationMs(int ms) {
    if (ms <= 0) return '0 detik';
    final totalSeconds = ms ~/ 1000;
    if (totalSeconds <= 0) return '< 1 detik';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final parts = <String>[
      if (hours > 0) '$hours jam',
      if (minutes > 0) '$minutes menit',
      if (seconds > 0 && hours == 0) '$seconds detik',
    ];
    return parts.join(' ');
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.numeric(theme.textTheme.bodySmall),
            ),
          ),
        ],
      ),
    );
  }
}
