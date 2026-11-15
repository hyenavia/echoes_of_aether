import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../domain/entities/game_settings.dart';
import '../shared/widgets/shared_widgets.dart';

/// Overlay pengaturan audio (BGM & SFX) dan notifikasi lokal yang dipersistensikan ke `GameSettings`.
class SettingsOverlay extends StatefulWidget {
  const SettingsOverlay({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onClose,
    this.onTestSfx,
    this.onRequestNotificationPermission,
  });

  final ValueListenable<GameSettingsData> settings;
  final void Function(GameSettingsData next) onChanged;
  final VoidCallback onClose;
  final VoidCallback? onTestSfx;
  final Future<bool> Function()? onRequestNotificationPermission;

  @override
  State<SettingsOverlay> createState() => _SettingsOverlayState();
}

class _SettingsOverlayState extends State<SettingsOverlay> {
  String? _permissionMessage;

  Future<void> _toggleNotificationCategory(
    GameSettingsData current,
    bool nextValue,
    GameSettingsData Function(bool enabled) apply,
  ) async {
    if (nextValue && !current.anyNotificationCategoryEnabled) {
      final requester = widget.onRequestNotificationPermission;
      if (requester != null) {
        final granted = await requester();
        if (!mounted) return;
        if (!granted) {
          setState(() {
            _permissionMessage = 'Izin notifikasi ditolak. Aktifkan izin notifikasi di pengaturan perangkat.';
          });
          widget.onChanged(apply(false));
          return;
        }
      }
    }
    if (mounted && _permissionMessage != null) {
      setState(() {
        _permissionMessage = null;
      });
    }
    widget.onChanged(apply(nextValue));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 560),
          child: PanelFrame(
            showCornerOrnaments: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: ValueListenableBuilder<GameSettingsData>(
              valueListenable: widget.settings,
              builder: (context, s, _) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.settings_outlined,
                        size: 20,
                        color: AppColors.antiqueGold,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Pengaturan',
                          style: AppTypography.headingSerif(
                            theme.textTheme.titleLarge,
                            color: AppColors.antiqueGold,
                          ),
                        ),
                      ),
                      AppIconButton(
                        icon: Icons.close,
                        semanticLabel: 'Tutup Pengaturan',
                        tooltip: 'Tutup',
                        size: 36,
                        iconSize: 18,
                        onPressed: widget.onClose,
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
                          const SectionHeader(title: 'Audio', useSerif: true),
                          const SizedBox(height: AppSpacing.xs),
                          PanelFrame(
                            backgroundColor: AppColors.surfaceDark,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SwitchListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Musik Latar (BGM)'),
                                  value: s.bgmEnabled,
                                  onChanged: (v) => widget.onChanged(
                                    s.copyWith(bgmEnabled: v),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Volume BGM: ${(s.bgmVolume * 100).round()}%',
                                      style: AppTypography.numeric(
                                        theme.textTheme.bodySmall,
                                      ),
                                    ),
                                    Slider(
                                      value: s.bgmVolume,
                                      min: 0,
                                      max: 1,
                                      divisions: 10,
                                      onChanged: s.bgmEnabled
                                          ? (v) => widget.onChanged(
                                              s.copyWith(bgmVolume: v),
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                                const Divider(height: AppSpacing.sm),
                                SwitchListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Efek Suara (SFX)'),
                                  value: s.sfxEnabled,
                                  onChanged: (v) => widget.onChanged(
                                    s.copyWith(sfxEnabled: v),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Volume SFX: ${(s.sfxVolume * 100).round()}%',
                                      style: AppTypography.numeric(
                                        theme.textTheme.bodySmall,
                                      ),
                                    ),
                                    Slider(
                                      value: s.sfxVolume,
                                      min: 0,
                                      max: 1,
                                      divisions: 10,
                                      onChanged: s.sfxEnabled
                                          ? (v) => widget.onChanged(
                                              s.copyWith(sfxVolume: v),
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (widget.onTestSfx != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            Align(
                              alignment: Alignment.centerRight,
                              child: SecondaryButton(
                                label: 'Tes Suara',
                                icon: Icons.volume_up_outlined,
                                onPressed: s.sfxEnabled
                                    ? widget.onTestSfx
                                    : null,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          const SectionHeader(
                            title: 'Notifikasi',
                            useSerif: true,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          PanelFrame(
                            backgroundColor: AppColors.surfaceDark,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SwitchListTile(
                                  key: const Key('settings_notify_autofarm'),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'Auto Farming penuh (8 jam)',
                                  ),
                                  value: s.notifyAutoFarmingFull,
                                  onChanged: (v) => _toggleNotificationCategory(
                                    s,
                                    v,
                                    (e) => s.copyWith(notifyAutoFarmingFull: e),
                                  ),
                                ),
                                SwitchListTile(
                                  key: const Key('settings_notify_daily_boss'),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Pengingat Daily Boss'),
                                  value: s.notifyDailyBossReminder,
                                  onChanged: (v) => _toggleNotificationCategory(
                                    s,
                                    v,
                                    (e) =>
                                        s.copyWith(notifyDailyBossReminder: e),
                                  ),
                                ),
                                SwitchListTile(
                                  key: const Key('settings_notify_weekly_boss'),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Pengingat Weekly Boss'),
                                  value: s.notifyWeeklyBossReminder,
                                  onChanged: (v) => _toggleNotificationCategory(
                                    s,
                                    v,
                                    (e) =>
                                        s.copyWith(notifyWeeklyBossReminder: e),
                                  ),
                                ),
                                SwitchListTile(
                                  key: const Key('settings_notify_event_shop'),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'Pengingat Event Shop berganti',
                                  ),
                                  value: s.notifyEventShopEnding,
                                  onChanged: (v) => _toggleNotificationCategory(
                                    s,
                                    v,
                                    (e) => s.copyWith(notifyEventShopEnding: e),
                                  ),
                                ),
                                const Divider(height: AppSpacing.sm),
                                SwitchListTile(
                                  key: const Key('settings_notify_quiet_hours'),
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Jam Tenang (Quiet Hours)'),
                                  value: s.notifyQuietHoursEnabled,
                                  onChanged: (v) => widget.onChanged(
                                    s.copyWith(notifyQuietHoursEnabled: v),
                                  ),
                                ),
                                if (_permissionMessage != null) ...[
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    _permissionMessage!,
                                    key: const Key(
                                      'settings_notify_permission_error',
                                    ),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
