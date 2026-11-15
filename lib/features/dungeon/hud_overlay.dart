import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../game/hud/hud_state.dart';
import '../shared/widgets/shared_widgets.dart';

/// HUD Dungeon bertema Living Aether Camp:
/// - Atas: Status Hero & Room di kiri, Boss Encounter Plate di kanan (atau
///   tersusun vertikal otomatis pada layar sangat sempit < 340dp).
/// - Kiri bawah: Feed ringkas transisi room, skill aktif/cooldown, dan loot.
class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key, required this.state});

  final ValueListenable<HudState> state;

  static const TextStyle _baseText = TextStyle(
    fontSize: 11,
    color: AppColors.textPrimary,
  );

  @override
  Widget build(BuildContext context) {
    final ext = EchoesTheme.of(context);
    final theme = Theme.of(context);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final stackTopVertically = maxWidth < 340;
          final feedMaxWidth = (maxWidth * 0.48).clamp(136.0, 248.0);

          return ValueListenableBuilder<HudState>(
            valueListenable: state,
            builder: (context, s, _) {
              final hasBoss = s.bossName.isNotEmpty && s.bossMaxHp > 0;
              final hasFeed =
                  s.transitionMessage.isNotEmpty ||
                  s.lastSkill.isNotEmpty ||
                  s.skillCooldownText.isNotEmpty ||
                  s.lastLoot.isNotEmpty;

              final heroPanel = _buildHeroPanel(
                theme,
                ext,
                s,
                hasBoss: hasBoss,
              );
              final bossPanel = hasBoss ? _buildBossPanel(theme, ext, s) : null;

              return Stack(
                children: [
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
                                    maxWidth: 228,
                                  ),
                                  child: heroPanel,
                                ),
                                if (bossPanel != null) ...[
                                  const SizedBox(height: AppSpacing.xs + 2),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 228,
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
                                      maxWidth: 204,
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
                                          maxWidth: 220,
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
                  if (hasFeed)
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: feedMaxWidth),
                          child: _buildCombatFeed(ext, s),
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
    ThemeData theme,
    EchoesThemeExtension ext,
    HudState s, {
    required bool hasBoss,
  }) {
    final borderColor = s.isFinalBoss
        ? ext.rank
        : (hasBoss ? ext.hpBar : ext.panelBorder);
    return PanelFrame(
      key: const ValueKey<String>('hud_hero_panel'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 2,
      ),
      backgroundColor: AppColors.midnightForest.withValues(alpha: 0.86),
      borderColor: borderColor,
      showCornerOrnaments: s.isElite || hasBoss,
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
              style: AppTypography.headingSerif(
                (theme.textTheme.labelSmall ?? _baseText).copyWith(
                  fontSize: 10.5,
                ),
                color: ext.gold,
                letterSpacing: 0.25,
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
                  style: AppTypography.numeric(
                    _baseText,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.monetization_on_outlined, size: 11, color: ext.gold),
              const SizedBox(width: 2),
              Text(
                'Gold ${NumberFormatter.format(s.gold)}',
                style: AppTypography.numeric(
                  _baseText,
                  fontSize: 10,
                  color: ext.gold,
                  fontWeight: FontWeight.w600,
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
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (s.totalEnemies > 0)
                  Text(
                    'Musuh: ${s.activeEnemies}/${s.totalEnemies}',
                    style: AppTypography.numeric(
                      _baseText,
                      fontSize: 10,
                      color: AppColors.textPrimary,
                    ),
                  ),
                if (s.exitRequired || s.exitUnlocked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: (s.exitUnlocked ? ext.expBar : ext.warning)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: (s.exitUnlocked ? ext.expBar : ext.warning)
                            .withValues(alpha: 0.55),
                      ),
                    ),
                    child: Text(
                      s.exitUnlocked ? 'Exit: Terbuka' : 'Exit: Terkunci',
                      style: _baseText.copyWith(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: s.exitUnlocked ? ext.expBar : ext.warning,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (s.roomStatus.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              'Status: ${s.roomStatus}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _baseText.copyWith(
                fontSize: 10,
                color: s.exitUnlocked ? ext.success : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBossPanel(
    ThemeData theme,
    EchoesThemeExtension ext,
    HudState s,
  ) {
    final bossAccent = s.isFinalBoss ? ext.rank : ext.hpBar;
    return PanelFrame(
      key: const ValueKey<String>('hud_boss_panel'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 2,
      ),
      backgroundColor: AppColors.midnightForest.withValues(alpha: 0.90),
      borderColor: bossAccent,
      showCornerOrnaments: true,
      boxShadow: AppShadows.glow(bossAccent, alpha: 0.22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                s.isFinalBoss
                    ? Icons.auto_awesome
                    : Icons.local_fire_department_outlined,
                size: 12,
                color: bossAccent,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  s.isFinalBoss
                      ? 'FINAL BOSS: ${s.bossName}'
                      : 'BOSS: ${s.bossName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.headingSerif(
                    (theme.textTheme.labelSmall ?? _baseText).copyWith(
                      fontSize: 10.5,
                    ),
                    color: bossAccent,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          StatBar(
            label: s.isFinalBoss ? 'FINAL' : 'BOSS',
            current: s.bossHp,
            max: s.bossMaxHp,
            barColor: bossAccent,
            height: 7,
          ),
        ],
      ),
    );
  }

  Widget _buildCombatFeed(EchoesThemeExtension ext, HudState s) {
    return Container(
      key: const ValueKey<String>('hud_combat_feed'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.midnightForest.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: ext.panelBorder.withValues(alpha: 0.68)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s.transitionMessage.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.route_outlined, size: 11, color: ext.success),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    s.transitionMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _baseText.copyWith(
                      fontSize: 10,
                      color: ext.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          if (s.lastSkill.isNotEmpty || s.skillCooldownText.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_fix_high_outlined, size: 11, color: ext.expBar),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    [
                      if (s.lastSkill.isNotEmpty) 'Skill: ${s.lastSkill}',
                      if (s.skillCooldownText.isNotEmpty) s.skillCooldownText,
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.numeric(
                      _baseText,
                      fontSize: 10,
                      color: ext.expBar,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          if (s.lastLoot.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_outlined, size: 11, color: ext.gold),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '+ ${s.lastLoot}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _baseText.copyWith(
                      fontSize: 10,
                      color: ext.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
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
        border: Border.all(color: color.withValues(alpha: 0.72)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
