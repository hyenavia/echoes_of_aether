import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../../domain/entities/boss_spire.dart';
import '../shared/widgets/shared_widgets.dart';
import 'boss_events_overlay.dart';
import 'boss_spire_overlay.dart';

/// Hub gabungan untuk seluruh tantangan Boss: Event (Daily & Weekly) dan
/// Menara Bos (Boss Spire).
class BossHubOverlay extends StatefulWidget {
  const BossHubOverlay({
    super.key,
    this.daily,
    this.weekly,
    this.spireConfig,
    this.spireProgress,
    this.playerLevel = 1,
    this.spireRemainingToReset,
    this.onFightSpireFloor,
    this.initialTab = 0,
    required this.onClose,
  });

  final BossEventCardData? daily;
  final BossEventCardData? weekly;
  final BossSpireConfig? spireConfig;
  final BossSpireProgress? spireProgress;
  final int playerLevel;
  final Duration? spireRemainingToReset;
  final void Function(int floor)? onFightSpireFloor;
  final int initialTab;
  final VoidCallback onClose;

  @override
  State<BossHubOverlay> createState() => _BossHubOverlayState();
}

class _BossHubOverlayState extends State<BossHubOverlay> {
  late int _selectedTab;

  bool get _hasEvents => widget.daily != null && widget.weekly != null;
  bool get _hasSpire =>
      widget.spireConfig != null &&
      widget.spireProgress != null &&
      widget.onFightSpireFloor != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialTab == 1 && _hasSpire) {
      _selectedTab = 1;
    } else if (_hasEvents) {
      _selectedTab = 0;
    } else if (_hasSpire) {
      _selectedTab = 1;
    } else {
      _selectedTab = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);

    return Material(
      color: AppColors.midnightForest.withValues(alpha: 0.82),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: PanelFrame(
              padding: const EdgeInsets.all(AppSpacing.md),
              borderColor: _selectedTab == 1 ? ext.rank : ext.gold,
              showCornerOrnaments: true,
              boxShadow: AppShadows.glow(
                _selectedTab == 1 ? ext.rank : ext.gold,
                alpha: 0.22,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        _selectedTab == 1
                            ? Icons.castle_outlined
                            : Icons.whatshot_outlined,
                        color: _selectedTab == 1 ? ext.rank : ext.gold,
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Tantangan Boss',
                          style: AppTypography.headingSerif(
                            theme.textTheme.titleMedium,
                            color: _selectedTab == 1 ? ext.rank : ext.gold,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('boss_hub_close'),
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close),
                        tooltip: 'Tutup',
                      ),
                    ],
                  ),
                  if (_hasEvents && _hasSpire) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SegmentedButton<int>(
                          key: const Key('boss_hub_tabs'),
                          segments: const [
                            ButtonSegment<int>(
                              value: 0,
                              icon: Icon(Icons.whatshot_outlined),
                              label: Text('Daily & Weekly'),
                            ),
                            ButtonSegment<int>(
                              value: 1,
                              icon: Icon(Icons.castle_outlined),
                              label: Text('Menara'),
                            ),
                          ],
                          selected: {_selectedTab},
                          onSelectionChanged: (next) =>
                              setState(() => _selectedTab = next.first),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  const Divider(height: 1, color: AppColors.panelBorder),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: _selectedTab == 1 && _hasSpire
                        ? BossSpireOverlay(
                            config: widget.spireConfig!,
                            progress: widget.spireProgress!,
                            playerLevel: widget.playerLevel,
                            remainingToReset: widget.spireRemainingToReset,
                            onFightFloor: widget.onFightSpireFloor!,
                            onClose: widget.onClose,
                            embedded: true,
                          )
                        : _hasEvents
                        ? BossEventsOverlay(
                            daily: widget.daily!,
                            weekly: widget.weekly!,
                            onClose: widget.onClose,
                            embedded: true,
                          )
                        : const Center(
                            child: Text('Tantangan Boss belum tersedia.'),
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
