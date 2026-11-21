import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../shared/widgets/shared_widgets.dart';

/// Versi notice pembaruan sistem terbaru (selaras dengan Drift `schemaVersion = 11` / M16).
const int kLatestSystemUpdateNoticeVersion = 11;

/// Banner pengingat update aplikasi untuk ditampilkan di dalam `CloudSyncSection`.
class UpdateReminderBanner extends StatelessWidget {
  const UpdateReminderBanner({
    super.key,
    required this.message,
    this.latestVersion,
    this.isRequired = false,
    this.onTapDetails,
  });

  final String message;
  final String? latestVersion;
  final bool isRequired;
  final VoidCallback? onTapDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = isRequired ? AppColors.campAmber : AppColors.aetherBlue;
    final title = isRequired
        ? 'Perbarui Aplikasi Diperlukan'
        : 'Update Aplikasi Tersedia';

    return PanelFrame(
      key: const Key('cloud_update_reminder_banner'),
      backgroundColor: AppColors.deepTeal.withValues(alpha: 0.72),
      borderColor: accent.withValues(alpha: 0.7),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isRequired ? Icons.system_update_alt : Icons.new_releases_outlined,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (latestVersion != null &&
                        latestVersion!.trim().isNotEmpty)
                      Text(
                        'v$latestVersion',
                        style: AppTypography.numeric(
                          theme.textTheme.labelSmall,
                          color: accent,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  key: const Key('cloud_update_reminder_message'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (onTapDetails != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SecondaryButton(
                      key: const Key('cloud_update_reminder_detail_btn'),
                      label: 'Detail',
                      icon: Icons.info_outline,
                      onPressed: onTapDetails,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog "What's New & Aether Legacy Gift" yang muncul sekali setelah migrasi
/// sistem M16 (Lv 90 Max, Rank 5, Hero Ascension, The Infinite Spire) dan dapat
/// dibuka kembali dari Pengaturan.
Future<void> showSystemUpdateNoticeDialog(
  BuildContext context, {
  required String appVersion,
  required int playerLevel,
  required int ascensionPhase,
  required int highestAscensionRank,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => EchoesDialog(
      key: const Key('system_update_notice_dialog'),
      title: 'Pembaruan Sistem M16',
      icon: Icons.auto_awesome,
      accentColor: AppColors.antiqueGold,
      primaryLabel: 'Mengerti',
      onPrimary: () => Navigator.of(dialogContext).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelFrame(
            backgroundColor: AppColors.surfaceDark,
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 18,
                  color: AppColors.antiqueGold,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'v$appVersion • Lv $playerLevel • Fase A$ascensionPhase • Rank $highestAscensionRank',
                    style: AppTypography.numeric(
                      Theme.of(dialogContext).textTheme.labelMedium,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _NoticeItem(
            title: 'Batas Sistem Baru & Hero Ascension',
            description: 'Level maksimal kini Lv 90 (Fase A0–A6) dan World Tier puncak dikunci pada Rank 5 (Peak World Tier).',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _NoticeItem(
            title: 'Konversi Progres Lama & Aether Legacy Gift',
            description: 'Save lama di atas Lv 90 otomatis dipetakan ke Fase A6 dan menerima kompensasi Gold, Aether Shard, serta Soul Prism. Sinkronisasi Cloud Save kini mendukung transisi save lama ke sistem baru.',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _NoticeItem(
            title: 'Konten End-Game Baru',
            description: 'Jelajahi Dungeon 6 (The Abyssal Rift) untuk gear Tier 6 serta taklukkan 100 lantai The Infinite Spire.',
          ),
        ],
      ),
    ),
  );
}

/// Dialog pengingat ketika versi aplikasi / skema save yang lebih baru
/// terdeteksi dari Cloud Save atau metadata versi remote.
Future<void> showAppUpdateAvailableDialog(
  BuildContext context, {
  required String message,
  String? latestVersion,
  bool isRequired = false,
  String? actionLabel,
  VoidCallback? onActionPressed,
}) {
  final accent = isRequired ? AppColors.campAmber : AppColors.aetherBlue;
  final hasAction = onActionPressed != null;
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => EchoesDialog(
      key: const Key('app_update_available_dialog'),
      title: isRequired
          ? 'Pembaruan Aplikasi Diperlukan'
          : 'Pembaruan Aplikasi Tersedia',
      icon: isRequired ? Icons.system_update_alt : Icons.new_releases_outlined,
      accentColor: accent,
      secondaryLabel: hasAction ? 'Nanti' : null,
      onSecondary: hasAction ? () => Navigator.of(dialogContext).pop() : null,
      primaryLabel: hasAction ? (actionLabel ?? 'Unduh APK') : 'Tutup',
      onPrimary: () {
        Navigator.of(dialogContext).pop();
        onActionPressed?.call();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (latestVersion != null && latestVersion.trim().isNotEmpty) ...[
            Text(
              'Versi Terbaru: v$latestVersion',
              style: AppTypography.numeric(
                Theme.of(dialogContext).textTheme.labelLarge,
                color: accent,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            message,
            style: Theme.of(dialogContext).textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}

class _NoticeItem extends StatelessWidget {
  const _NoticeItem({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: AppColors.antiqueGold,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
