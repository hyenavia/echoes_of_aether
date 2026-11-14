import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/echoes_theme.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../domain/entities/combat_stats.dart';
import '../../../game/visuals/pixel_sprite_atlas.dart';
import 'panel_frame.dart';

/// Hero Showcase pada beranda Town/Camp: menampilkan sprite pixel-art
/// karakter utama dalam pose idle di atas pedestal Aether beserta info ringkas.
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
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
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

  Color _classAccent(EchoesThemeExtension ext) {
    switch (widget.specializationId) {
      case 'vanguard':
        return ext.gold;
      case 'arcanist':
        return ext.rank;
      case 'ranger':
        return AppColors.mossGreen;
      default:
        return ext.expBar;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    final accent = _classAccent(ext);
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
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: PanelFrame(
          showCornerOrnaments: true,
          borderColor: accent.withValues(alpha: 0.78),
          padding: EdgeInsets.zero,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.backgroundDark,
              AppColors.surfaceDark,
              accent.withValues(alpha: 0.14),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 310;
              final stageSize = compact ? 76.0 : 112.0;
              return Padding(
                padding: EdgeInsets.all(
                  compact ? AppSpacing.sm : AppSpacing.md,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildStage(accent, stageSize),
                    SizedBox(width: compact ? AppSpacing.sm : AppSpacing.md),
                    Expanded(
                      child: _buildInfo(
                        theme,
                        ext,
                        accent,
                        className,
                        combatPower,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStage(Color accent, double stageSize) {
    return SizedBox(
      width: stageSize,
      height: stageSize,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final pose = _anim.value < 0.5 ? 'idle0' : 'idle1';
          final sprite = PixelSpriteAtlas.instance.combatantSprite(
            isPlayer: true,
            specializationId: widget.specializationId,
            pose: pose,
          );
          return CustomPaint(
            painter: _HeroStagePainter(
              sprite: sprite,
              accent: accent,
              phase: _anim.value,
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfo(
    ThemeData theme,
    EchoesThemeExtension ext,
    Color accent,
    String className,
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
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: accent.withValues(alpha: 0.5)),
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
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          className,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
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
          Row(
            children: [
              Icon(Icons.bolt, size: 15, color: ext.gold),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  'Combat Power ${NumberFormatter.format(combatPower)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: ext.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (widget.onTap != null) ...[
          const SizedBox(height: 2),
          Text(
            'Ketuk karakter untuk kelola build & skill',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textMuted,
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
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _HeroStagePainter extends CustomPainter {
  const _HeroStagePainter({
    required this.sprite,
    required this.accent,
    required this.phase,
  });

  final ui.Image sprite;
  final Color accent;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final pulse = 0.5 + 0.5 * math.sin(phase * math.pi * 2);

    // Background sanctuary vignette
    final bgRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(AppRadius.md),
    );
    final bgPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(center.dx, center.dy - size.height * 0.08),
        size.width * 0.65,
        [
          accent.withValues(alpha: 0.22 + 0.08 * pulse),
          AppColors.deepForest.withValues(alpha: 0.9),
          AppColors.backgroundDark,
        ],
        const [0.0, 0.58, 1.0],
      );
    canvas.drawRRect(bgRect, bgPaint);

    // Subtle border
    final borderPaint = Paint()
      ..color = accent.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(bgRect, borderPaint);

    // Pedestal rune ellipse
    final pedestalRect = Rect.fromCenter(
      center: Offset(center.dx, size.height * 0.80),
      width: size.width * 0.68,
      height: size.height * 0.16,
    );
    canvas.drawOval(
      pedestalRect,
      Paint()..color = AppColors.ancientStone.withValues(alpha: 0.28),
    );
    canvas.drawOval(
      pedestalRect,
      Paint()
        ..color = accent.withValues(alpha: 0.48 + 0.22 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );

    // Floating Aether motes
    final motePaint = Paint()
      ..color = AppColors.aetherBlue.withValues(alpha: 0.45 + 0.35 * pulse);
    for (var i = 0; i < 4; i++) {
      final angle = (phase * math.pi * 2) + (i * math.pi / 2);
      final mx = center.dx + math.cos(angle) * (size.width * 0.30);
      final my =
          size.height * 0.48 +
          math.sin(angle * 1.3) * (size.height * 0.14) -
          (pulse * 3);
      canvas.drawCircle(Offset(mx, my), i.isEven ? 1.8 : 1.3, motePaint);
    }

    // Nearest-neighbor pixel-art hero sprite
    final spriteSize = (size.width * 0.58).floorToDouble();
    final dst = Rect.fromCenter(
      center: Offset(center.dx, size.height * 0.52),
      width: spriteSize,
      height: spriteSize,
    );
    final src = Rect.fromLTWH(
      0,
      0,
      sprite.width.toDouble(),
      sprite.height.toDouble(),
    );
    canvas.drawImageRect(sprite, src, dst, PixelSpriteAtlas.pixelPaint);
  }

  @override
  bool shouldRepaint(covariant _HeroStagePainter oldDelegate) =>
      oldDelegate.sprite != sprite ||
      oldDelegate.accent != accent ||
      oldDelegate.phase != phase;
}
