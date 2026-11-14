import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../game/hud/hud_state.dart';
import '../shared/widgets/shared_widgets.dart';

/// HUD Dungeon ringkas dan anti-tumpang-tindih:
/// - Atas: Status Hero & Room di kiri, Boss HP Bar di kanan (atau tersusun
///   vertikal otomatis pada layar sangat sempit < 340dp).
/// - Kiri bawah: Feed ringkas skill, transisi room, dan loot drop.
class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key, required this.state});

  final ValueListenable<HudState> state;

  static const TextStyle _text = TextStyle(fontSize: 11, color: Colors.white);

  @override
  Widget build(BuildContext context) {
    final ext = EchoesTheme.of(context);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final stackTopVertically = maxWidth < 340;
          final feedMaxWidth = (maxWidth * 0.48).clamp(130.0, 240.0);

          return ValueListenableBuilder<HudState>(
            valueListenable: state,
            builder: (context, s, _) {
              final hasBoss = s.bossName.isNotEmpty && s.bossMaxHp > 0;
              final hasFeed =
                  s.transitionMessage.isNotEmpty ||
                  s.lastSkill.isNotEmpty ||
                  s.skillCooldownText.isNotEmpty ||
                  s.lastLoot.isNotEmpty;

              final heroPanel = _buildHeroPanel(ext, s, hasBoss: hasBoss);
              final bossPanel = hasBoss ? _buildBossPanel(ext, s) : null;

              return Stack(
                children: [
                  // Top area: Hero status + Boss HP bar arranged without overlap
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: stackTopVertically
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 220,
                                  ),
                                  child: heroPanel,
                                ),
                                if (bossPanel != null) ...[
                                  const SizedBox(height: AppSpacing.xs + 2),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 220,
                                    ),
                                    child: bossPanel,
                                  ),
                                ],
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(
                                  flex: 5,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 192,
                                    ),
                                    child: heroPanel,
                                  ),
                                ),
                                if (bossPanel != null) ...[
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    flex: 5,
                                    child: Align(
                                      alignment: Alignment.topRight,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 210,
                                        ),
                                        child: bossPanel,
                                      ),
                                    ),
                                  ),
                                ] else
                                  const Spacer(),
                              ],
                            ),
                    ),
                  ),

                  // Bottom-left: Compact Combat & Loot Feed
                  if (hasFeed)
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: feedMaxWidth),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs + 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundDark.withValues(
                                alpha: 0.80,
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                color: AppColors.panelBorder.withValues(
                                  alpha: 0.65,
                                ),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (s.transitionMessage.isNotEmpty)
                                  Text(
                                    s.transitionMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _text.copyWith(
                                      fontSize: 10,
                                      color: ext.success,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                if (s.lastSkill.isNotEmpty ||
                                    s.skillCooldownText.isNotEmpty)
                                  Text(
                                    [
                                      if (s.lastSkill.isNotEmpty)
                                        'Skill: ${s.lastSkill}',
                                      if (s.skillCooldownText.isNotEmpty)
                                        s.skillCooldownText,
                                    ].join(' • '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _text.copyWith(
                                      fontSize: 10,
                                      color: ext.expBar,
                                    ),
                                  ),
                                if (s.lastLoot.isNotEmpty)
                                  Text(
                                    '+ ${s.lastLoot}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _text.copyWith(
                                      fontSize: 10,
                                      color: ext.gold,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeroPanel(
    EchoesThemeExtension ext,
    HudState s, {
    required bool hasBoss,
  }) {
    return PanelFrame(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 2,
      ),
      backgroundColor: AppColors.backgroundDark.withValues(alpha: 0.82),
      borderColor: s.isFinalBoss
          ? ext.rank
          : (hasBoss ? ext.hpBar : ext.panelBorder),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s.roomName.isNotEmpty) ...[
            Text(
              s.dungeonName.isNotEmpty
                  ? '${s.dungeonName} • ${s.roomName}'
                  : s.roomName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _text.copyWith(
                fontSize: 10,
                color: ext.gold,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
          ],
          if (s.isElite || s.isFinalBoss) ...[
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: 2,
              children: [
                if (s.isElite)
                  _EncounterBadge(label: 'ELITE', color: ext.warning),
                if (s.isFinalBoss)
                  _EncounterBadge(label: 'FINAL BOSS', color: ext.rank),
              ],
            ),
            const SizedBox(height: 3),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  'Lv ${NumberFormatter.format(s.level)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _text.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                'Gold ${NumberFormatter.format(s.gold)}',
                style: _text.copyWith(
                  color: ext.gold,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          StatBar.hp(current: s.hp, max: s.maxHp),
          const SizedBox(height: 3),
          StatBar.exp(
            label: s.isMaxLevel ? 'EXP MAX' : 'EXP',
            current: s.isMaxLevel ? 1 : s.currentExp,
            max: s.isMaxLevel ? 1 : s.expToNext,
          ),
          if (s.totalEnemies > 0 || s.exitRequired || s.exitUnlocked) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: AppSpacing.xs + 2,
              runSpacing: 2,
              children: [
                if (s.totalEnemies > 0)
                  Text(
                    'Musuh: ${s.activeEnemies}/${s.totalEnemies}',
                    style: _text.copyWith(fontSize: 10),
                  ),
                if (s.exitRequired || s.exitUnlocked)
                  Text(
                    s.exitUnlocked ? 'Exit: Terbuka' : 'Exit: Terkunci',
                    style: _text.copyWith(
                      fontSize: 10,
                      color: s.exitUnlocked ? ext.expBar : ext.warning,
                    ),
                  ),
              ],
            ),
          ],
          if (s.roomStatus.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Status: ${s.roomStatus}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _text.copyWith(
                fontSize: 10,
                color: s.exitUnlocked ? ext.success : AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBossPanel(EchoesThemeExtension ext, HudState s) {
    return PanelFrame(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 1,
      ),
      backgroundColor: AppColors.backgroundDark.withValues(alpha: 0.86),
      borderColor: s.isFinalBoss ? ext.rank : ext.hpBar,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.isFinalBoss ? 'FINAL BOSS: ${s.bossName}' : 'BOSS: ${s.bossName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: _text.copyWith(
              fontSize: 10,
              color: s.isFinalBoss ? ext.rank : ext.hpBar,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          StatBar(
            label: s.isFinalBoss ? 'FINAL' : 'BOSS',
            current: s.bossHp,
            max: s.bossMaxHp,
            barColor: s.isFinalBoss ? ext.rank : ext.hpBar,
            height: 6,
          ),
        ],
      ),
    );
  }
}

class _EncounterBadge extends StatelessWidget {
  const _EncounterBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
