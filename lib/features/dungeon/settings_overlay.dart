import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../domain/entities/game_settings.dart';
import '../shared/widgets/shared_widgets.dart';

/// Overlay pengaturan audio (BGM & SFX) yang dipersistensikan ke `GameSettings`.
class SettingsOverlay extends StatelessWidget {
  const SettingsOverlay({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.onClose,
    this.onTestSfx,
  });

  final ValueListenable<GameSettingsData> settings;
  final void Function(GameSettingsData next) onChanged;
  final VoidCallback onClose;
  final VoidCallback? onTestSfx;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: PanelFrame(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm + 2,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: ValueListenableBuilder<GameSettingsData>(
              valueListenable: settings,
              builder: (context, s, _) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.settings_outlined),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Pengaturan',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(Icons.close),
                        tooltip: 'Tutup',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  const SectionHeader(title: 'Audio'),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Musik Latar (BGM)'),
                    value: s.bgmEnabled,
                    onChanged: (v) => onChanged(s.copyWith(bgmEnabled: v)),
                  ),
                  Row(
                    children: [
                      const SizedBox(width: AppSpacing.xs),
                      Text('Volume BGM: ${(s.bgmVolume * 100).round()}%'),
                      Expanded(
                        child: Slider(
                          value: s.bgmVolume,
                          min: 0,
                          max: 1,
                          divisions: 10,
                          onChanged: s.bgmEnabled
                              ? (v) => onChanged(s.copyWith(bgmVolume: v))
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Efek Suara (SFX)'),
                    value: s.sfxEnabled,
                    onChanged: (v) => onChanged(s.copyWith(sfxEnabled: v)),
                  ),
                  Row(
                    children: [
                      const SizedBox(width: AppSpacing.xs),
                      Text('Volume SFX: ${(s.sfxVolume * 100).round()}%'),
                      Expanded(
                        child: Slider(
                          value: s.sfxVolume,
                          min: 0,
                          max: 1,
                          divisions: 10,
                          onChanged: s.sfxEnabled
                              ? (v) => onChanged(s.copyWith(sfxVolume: v))
                              : null,
                        ),
                      ),
                    ],
                  ),
                  if (onTestSfx != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: SecondaryButton(
                        label: 'Tes Suara',
                        icon: Icons.volume_up_outlined,
                        onPressed: s.sfxEnabled ? onTestSfx : null,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
