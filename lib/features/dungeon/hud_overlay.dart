import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../game/hud/hud_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/game_panel.dart';
import '../../widgets/game_progress_bar.dart';

/// HUD Dungeon bertema Dark Fantasy RPG:
/// - Pojok kiri atas: Floating overlay status Hero & Room (GamePanel semi-transparan opacity 0.85).
/// - Pojok kanan atas: Boss Encounter Plate saat bertarung melawan Boss.
/// - Tengah bawah: Action Bar skill melayang dengan slot kotak berborder tebal & cooldown overlay putaran gelap.
/// - Kiri bawah: Combat Log semi-transparan yang memudar otomatis (auto-fade).
class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key, required this.state, this.onSkillTap});

  final ValueListenable<HudState> state;
  final void Function(String skillId)? onSkillTap;

  static const TextStyle _baseText = TextStyle(
    fontSize: 11,
    color: AppColors.textPrimary,
  );

  @override
  Widget build(BuildContext context) {
    final ext = EchoesTheme.of(context);
    final theme = Theme.of(context);
    return LayoutBuilder(
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

            final heroPanel = _buildHeroPanel(theme, ext, s, hasBoss: hasBoss);
            final bossPanel = hasBoss ? _buildBossPanel(theme, ext, s) : null;

            return Stack(
              children: [
                // 1. Top HUD (Hero & Boss Panels)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
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
                ),

                // 2. Bottom Center: Action Bar melayang
                if (s.skills.isNotEmpty)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: AppSpacing.sm,
                        right: maxWidth < 380 ? 44.0 : 0.0,
                      ),
                      child: _buildSkillBar(theme, ext, s.skills),
                    ),
                  ),

                // 3. Bottom Left: Combat Log semi-transparan dengan auto-fade
                if (hasFeed)
                  Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: AppSpacing.sm,
                        bottom: s.skills.isNotEmpty ? 76.0 : AppSpacing.sm,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: feedMaxWidth),
                        child: IgnorePointer(
                          child: _CombatFeed(
                            key: const ValueKey<String>('hud_combat_feed'),
                            hudState: s,
                            ext: ext,
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
    );
  }

  Widget _buildSkillBar(
    ThemeData theme,
    EchoesThemeExtension ext,
    List<HudSkillInfo> skills,
  ) {
    if (skills.isEmpty) return const SizedBox.shrink();

    return Container(
      key: const ValueKey<String>('hud_skill_bar'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xE00B0E17), // 88% dark navy
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.65),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.arcanePurple.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.70),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < skills.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs + 3),
            _SkillSlot(skill: skills[i], onSkillTap: onSkillTap),
          ],
        ],
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

    final hpRatio = s.maxHp > 0 ? (s.hp / s.maxHp).clamp(0.0, 1.0) : 0.0;
    final expRatio = s.isMaxLevel
        ? 1.0
        : (s.expToNext > 0
              ? (s.currentExp / s.expToNext).clamp(0.0, 1.0)
              : 0.0);
    final expPct = s.isMaxLevel ? 100 : (expRatio * 100).toInt();

    return GamePanel.hudOverlay(
      key: const ValueKey<String>('hud_hero_panel'),
      opacity: 0.85,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 2,
      ),
      showGlow: s.isElite || hasBoss,
      glowColor: borderColor,
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
              style: AppTheme.headingFantasy(
                fontSize: 10.5,
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
                  style: AppTheme.statNumber(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.monetization_on_outlined, size: 11, color: ext.gold),
              const SizedBox(width: 2),
              Text(
                'Gold ${NumberFormatter.format(s.gold)}',
                style: AppTheme.statNumber(
                  fontSize: 10,
                  color: ext.gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          GameProgressBar.hp(
            value: hpRatio,
            height: 13,
            skewOffset: 4,
            label:
                '${NumberFormatter.format(s.hp)}/${NumberFormatter.format(s.maxHp)} HP',
          ),
          const SizedBox(height: 3),
          GameProgressBar.exp(
            value: expRatio,
            height: 10,
            skewOffset: 3.5,
            label: s.isMaxLevel ? 'EXP MAX' : 'EXP $expPct%',
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
                    style: AppTheme.statNumber(
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
    return GamePanel(
      key: const ValueKey<String>('hud_boss_panel'),
      style: GamePanelStyle.darkStone,
      opacity: 0.90,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 2,
      ),
      showGlow: true,
      glowColor: bossAccent,
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
                  style: AppTheme.headingFantasy(
                    fontSize: 10.5,
                    color: bossAccent,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          GameProgressBar(
            value: s.bossMaxHp > 0
                ? (s.bossHp / s.bossMaxHp).clamp(0.0, 1.0)
                : 0.0,
            style: s.isFinalBoss
                ? GameProgressBarStyle.gold
                : GameProgressBarStyle.hp,
            height: 10.0,
            skewOffset: 4.0,
            label: s.isFinalBoss ? 'FINAL BOSS HP' : 'BOSS HP',
          ),
        ],
      ),
    );
  }
}

class _CombatFeed extends StatefulWidget {
  const _CombatFeed({super.key, required this.hudState, required this.ext});

  final HudState hudState;
  final EchoesThemeExtension ext;

  @override
  State<_CombatFeed> createState() => _CombatFeedState();
}

class _CombatFeedState extends State<_CombatFeed>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  Timer? _fadeTimer;
  String _lastContentKey = '';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
      value: 1.0,
    );
    _lastContentKey = _generateContentKey(widget.hudState);
    _scheduleFade();
  }

  String _generateContentKey(HudState s) {
    return '${s.transitionMessage}|${s.lastSkill}|${s.skillCooldownText}|${s.lastLoot}';
  }

  void _scheduleFade() {
    _fadeTimer?.cancel();
    _fadeController.value = 1.0;
    // Tampil terang selama 3.2 detik, lalu memudar perlahan ke 0.20 opacity
    _fadeTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) {
        _fadeController.animateTo(0.20, curve: Curves.easeOut);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _CombatFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newKey = _generateContentKey(widget.hudState);
    if (newKey != _lastContentKey) {
      _lastContentKey = newKey;
      _scheduleFade();
    }
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.hudState;
    final ext = widget.ext;

    return AnimatedBuilder(
      animation: _fadeController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeController.value.clamp(0.0, 1.0),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: const Color(0xDD0B0E17), // 87% dark navy
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: ext.panelBorder.withValues(alpha: 0.70),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
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
                      style: TextStyle(
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
                  Icon(
                    Icons.auto_fix_high_outlined,
                    size: 11,
                    color: ext.expBar,
                  ),
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
                        const TextStyle(
                          fontSize: 10,
                          color: AppColors.textPrimary,
                        ),
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
                      style: TextStyle(
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

class _SkillSlot extends StatefulWidget {
  const _SkillSlot({required this.skill, this.onSkillTap});

  final HudSkillInfo skill;
  final void Function(String skillId)? onSkillTap;

  @override
  State<_SkillSlot> createState() => _SkillSlotState();
}

class _SkillSlotState extends State<_SkillSlot> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final skill = widget.skill;
    final theme = Theme.of(context);
    final isReady = skill.isReady;

    return Semantics(
      label:
          '${skill.name} ${isReady ? 'Siap' : 'Cooldown ${skill.remainingSeconds.toStringAsFixed(1)}s'}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onSkillTap?.call(skill.id);
            },
            child: AnimatedScale(
              scale: _isPressed ? 0.90 : 1.0,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOutQuad,
              child: Container(
                key: ValueKey<String>('hud_skill_${skill.id}'),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1523),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: isReady ? AppTheme.gold : const Color(0xFF334155),
                    width: isReady ? 2.0 : 1.5,
                  ),
                  boxShadow: isReady
                      ? [
                          BoxShadow(
                            color: AppTheme.gold.withValues(alpha: 0.55),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm - 1),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: skill.spritePath != null
                            ? Image.asset(
                                skill.spritePath!,
                                width: 28,
                                height: 28,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.none,
                                errorBuilder: (_, _, _) => Icon(
                                  Icons.bolt_outlined,
                                  size: 20,
                                  color: isReady
                                      ? AppTheme.gold
                                      : AppColors.textMuted,
                                ),
                              )
                            : Icon(
                                Icons.bolt_outlined,
                                size: 20,
                                color: isReady
                                    ? AppTheme.gold
                                    : AppColors.textMuted,
                              ),
                      ),
                      if (!isReady && skill.progress > 0) ...[
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _CooldownSweepPainter(
                              progress: skill.progress,
                            ),
                          ),
                        ),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              skill.remainingSeconds >= 10
                                  ? '${skill.remainingSeconds.ceil()}s'
                                  : '${skill.remainingSeconds.toStringAsFixed(1)}s',
                              style: AppTypography.numeric(
                                theme.textTheme.labelSmall,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (isReady)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppTheme.cyanGlow,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.cyanGlow,
                                  blurRadius: 4,
                                  spreadRadius: 1,
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
          const SizedBox(height: 2),
          SizedBox(
            width: 44,
            child: Text(
              skill.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 8.5,
                color: isReady ? AppTheme.gold : AppColors.textMuted,
                fontWeight: isReady ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CooldownSweepPainter extends CustomPainter {
  const _CooldownSweepPainter({required this.progress});

  /// 0.0 (ready) -> 1.0 (just cast, full cooldown remaining)
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color =
          const Color(0xCC090D16) // 80% dark navy-black
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.max(size.width, size.height);
    final sweepAngle = 2 * math.pi * progress;

    final path = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
      )
      ..close();

    canvas.drawPath(path, paint);

    // Cyan glowing leading edge line
    final linePaint = Paint()
      ..color = AppTheme.cyanGlow.withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final endAngle = -math.pi / 2 + sweepAngle;
    final edgeX = center.dx + radius * math.cos(endAngle);
    final edgeY = center.dy + radius * math.sin(endAngle);
    canvas.drawLine(center, Offset(edgeX, edgeY), linePaint);
  }

  @override
  bool shouldRepaint(covariant _CooldownSweepPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
