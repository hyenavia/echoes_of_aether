import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../game/hud/hud_state.dart';
import '../shared/widgets/shared_widgets.dart';

/// HUD ringkas di pojok kiri atas agar area combat tengah tetap lega:
/// menampilkan dungeon/room, level, gold, bar HP/EXP, skill cooldown,
/// indikator elite/boss/Final Boss, status exit, dan drop terakhir.
class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key, required this.state});

  final ValueListenable<HudState> state;

  static const TextStyle _text = TextStyle(fontSize: 11, color: Colors.white);

  @override
  Widget build(BuildContext context) {
    final ext = EchoesTheme.of(context);
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: ValueListenableBuilder<HudState>(
            valueListenable: state,
            builder: (context, s, _) {
              final hasBoss = s.bossName.isNotEmpty && s.bossMaxHp > 0;
              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 196),
                child: PanelFrame(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  backgroundColor: AppColors.panelDark.withValues(alpha: 0.88),
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
                              _EncounterBadge(
                                label: 'ELITE',
                                color: ext.warning,
                              ),
                            if (s.isFinalBoss)
                              _EncounterBadge(
                                label: 'FINAL BOSS',
                                color: ext.rank,
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        'Lv ${NumberFormatter.format(s.level)}    '
                        'Gold ${NumberFormatter.format(s.gold)}',
                        style: _text.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      StatBar.hp(current: s.hp, max: s.maxHp),
                      const SizedBox(height: 4),
                      StatBar.exp(
                        label: s.isMaxLevel ? 'EXP MAX' : 'EXP',
                        current: s.isMaxLevel ? 1 : s.currentExp,
                        max: s.isMaxLevel ? 1 : s.expToNext,
                      ),
                      if (s.totalEnemies > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Musuh: ${s.activeEnemies}/${s.totalEnemies}',
                          style: _text,
                        ),
                      ],
                      if (s.roomStatus.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Status: ${s.roomStatus}',
                          style: _text.copyWith(
                            fontSize: 10,
                            color: s.exitUnlocked
                                ? ext.success
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (s.exitRequired || s.exitUnlocked) ...[
                        const SizedBox(height: 2),
                        Text(
                          s.exitUnlocked ? 'Exit: Terbuka' : 'Exit: Terkunci',
                          style: _text.copyWith(
                            fontSize: 10,
                            color: s.exitUnlocked ? ext.expBar : ext.warning,
                          ),
                        ),
                      ],
                      if (hasBoss) ...[
                        const SizedBox(height: 4),
                        Text(
                          s.isFinalBoss
                              ? 'FINAL BOSS: ${s.bossName}'
                              : 'BOSS: ${s.bossName}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _text.copyWith(
                            fontSize: 10,
                            color: s.isFinalBoss ? ext.rank : ext.hpBar,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        StatBar(
                          label: s.isFinalBoss ? 'FINAL' : 'BOSS',
                          current: s.bossHp,
                          max: s.bossMaxHp,
                          barColor: s.isFinalBoss ? ext.rank : ext.hpBar,
                          height: 6,
                        ),
                      ],
                      if (s.transitionMessage.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          s.transitionMessage,
                          style: _text.copyWith(
                            fontSize: 10,
                            color: ext.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (s.lastSkill.isNotEmpty ||
                          s.skillCooldownText.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (s.lastSkill.isNotEmpty) 'Skill: ${s.lastSkill}',
                            if (s.skillCooldownText.isNotEmpty)
                              s.skillCooldownText,
                          ].join(' • '),
                          style: _text.copyWith(color: ext.expBar),
                        ),
                      ],
                      if (s.lastLoot.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '+ ${s.lastLoot}',
                          style: _text.copyWith(color: ext.gold),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
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
