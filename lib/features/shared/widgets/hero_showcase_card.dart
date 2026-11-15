import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/echoes_theme.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../domain/entities/combat_stats.dart';
import '../assets/game_assets.dart';
import 'artwork/biome_artwork.dart';
import 'artwork/character_illustration.dart';
import 'panel_frame.dart';

/// Hero Showcase pada beranda Town/Camp (**Living Aether Camp**).
///
/// Menampilkan ilustrasi karakter fantasy ber-layer ([CharacterIllustration])
/// sesuai class/specialization aktif di atas latar perkemahan ([CampBackdrop])
/// dengan pencahayaan ambien dan partikel Aether halus.
/// Tap pada showcase membuka halaman Hero tanpa mengganggu lifecycle Flame.
class HeroShowcaseCard extends StatefulWidget {
  const HeroShowcaseCard({
    super.key,
    required this.level,
    required this.ascensionRank,
    this.specializationId,
    this.specializationName,
    this.stats,
    this.onTap,
  });

  final int level;
  final int ascensionRank;
  final String? specializationId;
  final String? specializationName;
  final CombatStats? stats;
  final VoidCallback? onTap;

  /// Estimasi Combat Power deterministik dari [CombatStats] karakter.
  static int computeCombatPower(CombatStats stats) {
    final power =
        (stats.maxHp * 0.25) +
        (stats.atk * 4.5) +
        (stats.def * 3.0) +
        (stats.critRate * 200) +
        (stats.attackSpeed * 20);
    return math.max(1, power.round());
  }

  @override
  State<HeroShowcaseCard> createState() => _HeroShowcaseCardState();
}

class _HeroShowcaseCardState extends State<HeroShowcaseCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: AppDurations.ambient);
    final isWidgetTest = WidgetsBinding.instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
    if (isWidgetTest) {
      _anim.value = 0.25;
    } else {
      _anim.repeat();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    final specId = widget.specializationId ?? 'base';
    final visualSpec = CharacterVisualSpec.resolve(specId);
    final accent = switch (specId) {
      'vanguard' => ext.gold,
      'arcanist' => ext.expBar,
      'ranger' => AppColors.mossGreen,
      _ => AppColors.aetherBlue,
    };
    final className = widget.specializationName ?? 'Petualang';
    final combatPower = widget.stats != null
        ? HeroShowcaseCard.computeCombatPower(widget.stats!)
        : null;

    return Semantics(
      button: widget.onTap != null,
      label: 'Hero Showcase $className Level ${widget.level}',
      child: InkWell(
        key: const Key('hero_showcase_card'),
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: PanelFrame(
          showCornerOrnaments: true,
          borderRadius: AppRadius.lg,
          borderColor: accent.withValues(alpha: 0.75),
          boxShadow: AppShadows.panel,
          padding: EdgeInsets.zero,
          child: CampBackdrop(
            borderRadius: AppRadius.md,
            child: Stack(
              children: [
                // Pencahayaan ambien terkonsentrasi di karakter + scrim keterbacaan
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          AppColors.midnightForest.withValues(alpha: 0.12),
                          AppColors.midnightForest.withValues(alpha: 0.56),
                          AppColors.midnightForest.withValues(alpha: 0.86),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _anim,
                      builder: (context, _) => CustomPaint(
                        painter: _CampAmbientPainter(
                          accent: accent,
                          phase: _anim.value,
                        ),
                      ),
                    ),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 310;
                    final heroW = compact ? 88.0 : 114.0;
                    final heroH = compact ? 108.0 : 138.0;

                    return Padding(
                      padding: EdgeInsets.all(
                        compact ? AppSpacing.sm : AppSpacing.sm + 2,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _anim,
                            builder: (context, child) {
                              final bob =
                                  math.sin(_anim.value * math.pi * 2) * 2.2;
                              return Transform.translate(
                                offset: Offset(0, bob),
                                child: child,
                              );
                            },
                            child: CharacterIllustration(
                              specializationId: specId,
                              width: heroW,
                              height: heroH,
                              showPedestal: true,
                              showAura: true,
                            ),
                          ),
                          SizedBox(
                            width: compact ? AppSpacing.sm : AppSpacing.md,
                          ),
                          Expanded(
                            child: _buildInfo(
                              theme,
                              ext,
                              accent,
                              className,
                              visualSpec,
                              combatPower,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfo(
    ThemeData theme,
    EchoesThemeExtension ext,
    Color accent,
    String className,
    CharacterVisualSpec visualSpec,
    int? combatPower,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs + 2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.midnightForest.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: accent.withValues(alpha: 0.55)),
                ),
                child: Text(
                  widget.specializationId == null
                      ? 'KELAS DASAR'
                      : 'SPECIALIZATION',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    color: accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            if (widget.onTap != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.antiqueGold.withValues(alpha: 0.9),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          className,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.headingSerif(
            theme.textTheme.titleLarge,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          visualSpec.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs + 2,
          runSpacing: AppSpacing.xs,
          children: [
            _StatBadge(
              label: 'Lv ${NumberFormatter.format(widget.level)}',
              color: ext.expBar,
            ),
            _StatBadge(
              label: 'Rank ${NumberFormatter.format(widget.ascensionRank)}',
              color: ext.rank,
            ),
          ],
        ),
        if (combatPower != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.midnightForest.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: ext.gold.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt, size: 15, color: ext.gold),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    'Combat Power ${NumberFormatter.format(combatPower)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.numeric(
                      theme.textTheme.labelMedium,
                      color: ext.gold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (widget.onTap != null) ...[
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            'Ketuk karakter untuk kelola build & skill',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.midnightForest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: AppTypography.numeric(
          Theme.of(context).textTheme.labelSmall,
          fontSize: 11,
          color: color,
        ),
      ),
    );
  }
}

class _CampAmbientPainter extends CustomPainter {
  const _CampAmbientPainter({required this.accent, required this.phase});

  final Color accent;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final pulse = 0.5 + 0.5 * math.sin(phase * math.pi * 2);

    // Subtle radial spotlight focused behind the hero on the left side
    final heroCenter = Offset(size.width * 0.22, size.height * 0.48);
    canvas.drawCircle(
      heroCenter,
      size.height * 0.62,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                accent.withValues(alpha: 0.16 + 0.06 * pulse),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(center: heroCenter, radius: size.height * 0.62),
            ),
    );

    // Gentle rising Aether & campfire particles (kept subtle)
    final aetherPaint = Paint()
      ..color = AppColors.aetherBlue.withValues(alpha: 0.40 + 0.30 * pulse);
    final emberPaint = Paint()
      ..color = AppColors.campAmber.withValues(alpha: 0.36 + 0.24 * pulse);

    for (var i = 0; i < 4; i++) {
      final t = (phase + i * 0.25) % 1.0;
      final px = size.width * (0.10 + i * 0.09);
      final py = size.height * (0.82 - t * 0.62);
      canvas.drawCircle(
        Offset(px, py),
        i.isEven ? 1.8 : 1.3,
        i.isEven ? aetherPaint : emberPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CampAmbientPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.phase != phase;
}
