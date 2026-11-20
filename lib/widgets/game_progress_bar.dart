import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Gaya visual dan skema warna untuk [GameProgressBar].
enum GameProgressBarStyle {
  /// Health Point (HP) — Gradien merah darah menyala dengan ujung putih/merah membara.
  hp(
    gradient: AppTheme.hpGradient,
    glowColor: AppTheme.hpRedLight,
    borderColor: Color(0xFFFF9E9E),
    trackColor: Color(0xFF14080B),
  ),

  /// Experience (EXP) — Gradien Cyan Aether bercahaya terang.
  exp(
    gradient: AppTheme.cyanGradient,
    glowColor: AppTheme.cyanGlow,
    borderColor: Color(0xFFA7FFF6),
    trackColor: Color(0xFF07141B),
  ),

  /// Mana / Energy — Gradien biru sihir dengan ujung bercahaya.
  mana(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF60A5FA), Color(0xFF3B82F6), Color(0xFF1D4ED8)],
    ),
    glowColor: Color(0xFF93C5FD),
    borderColor: Color(0xFF93C5FD),
    trackColor: Color(0xFF091124),
  ),

  /// Arcane / Shield — Gradien Arcane Purple mistis.
  arcane(
    gradient: AppTheme.arcaneGradient,
    glowColor: AppTheme.arcaneLight,
    borderColor: Color(0xFFE0AAFF),
    trackColor: Color(0xFF160924),
  ),

  /// Gold / Boss Enrage — Gradien Emas menyala.
  gold(
    gradient: AppTheme.goldGradient,
    glowColor: AppTheme.goldLight,
    borderColor: Color(0xFFFFF07C),
    trackColor: Color(0xFF1A1405),
  );

  const GameProgressBarStyle({
    required this.gradient,
    required this.glowColor,
    required this.borderColor,
    required this.trackColor,
  });

  final LinearGradient gradient;
  final Color glowColor;
  final Color borderColor;
  final Color trackColor;
}

/// Progress bar kustom bergaya game RPG dengan:
/// - Bentuk agak miring (parallelogram / slanted bar).
/// - Gradien warna mewah (HP merah, EXP cyan, Mana biru, Gold emas).
/// - Ujung menyala (glow spark flare) di pucuk progress pengisian.
/// - Animasi transisi nilai otomatis (interpolasi halus saat HP berkurang/tambah).
/// - Label angka statistik tabular yang tetap tegak lurus dan tajam (text shadow).
class GameProgressBar extends StatelessWidget {
  const GameProgressBar({
    super.key,
    required this.value,
    this.style = GameProgressBarStyle.hp,
    this.height = 20.0,
    this.width,
    this.skewOffset = 8.0,
    this.label,
    this.leadingIcon,
    this.animate = true,
    this.animationDuration = const Duration(milliseconds: 350),
    this.customGradient,
    this.customGlowColor,
  });

  /// Pintasan untuk Health Point (HP) Bar.
  const GameProgressBar.hp({
    super.key,
    required this.value,
    this.height = 20.0,
    this.width,
    this.skewOffset = 8.0,
    this.label,
    this.leadingIcon,
    this.animate = true,
    this.animationDuration = const Duration(milliseconds: 350),
  }) : style = GameProgressBarStyle.hp,
       customGradient = null,
       customGlowColor = null;

  /// Pintasan untuk Experience (EXP) Bar.
  const GameProgressBar.exp({
    super.key,
    required this.value,
    this.height = 18.0,
    this.width,
    this.skewOffset = 8.0,
    this.label,
    this.leadingIcon,
    this.animate = true,
    this.animationDuration = const Duration(milliseconds: 350),
  }) : style = GameProgressBarStyle.exp,
       customGradient = null,
       customGlowColor = null;

  /// Pintasan untuk Mana Bar.
  const GameProgressBar.mana({
    super.key,
    required this.value,
    this.height = 18.0,
    this.width,
    this.skewOffset = 8.0,
    this.label,
    this.leadingIcon,
    this.animate = true,
    this.animationDuration = const Duration(milliseconds: 350),
  }) : style = GameProgressBarStyle.mana,
       customGradient = null,
       customGlowColor = null;

  /// Nilai progres dalam rentang 0.0 sampai 1.0.
  final double value;

  /// Gaya skema warna default.
  final GameProgressBarStyle style;

  /// Tinggi bar dalam piksel (default 20.0).
  final double height;

  /// Lebar opsional (bila null, menyesuaikan parent container).
  final double? width;

  /// Tingkat kemiringan sisi parallelogram dalam piksel (default 8.0).
  final double skewOffset;

  /// Teks angka/status (misal: "1,250 / 2,000 HP" atau "EXP 75%").
  final String? label;

  /// Ikon kecil di depan progress bar (misal: hati, petir, bintang).
  final Widget? leadingIcon;

  /// Mengaktifkan animasi interpolasi halus saat nilai berubah.
  final bool animate;

  /// Durasi animasi interpolasi nilai.
  final Duration animationDuration;

  /// Gradien kustom opsional.
  final LinearGradient? customGradient;

  /// Warna glow ujung kustom opsional.
  final Color? customGlowColor;

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(0.0, 1.0);
    final effectiveGradient = customGradient ?? style.gradient;
    final effectiveGlowColor = customGlowColor ?? style.glowColor;

    Widget barContent(double animatedValue) {
      return SizedBox(
        width: width,
        height: height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Gambar latar bar miring & fill & glow tip
            CustomPaint(
              size: Size(width ?? double.infinity, height),
              painter: _ParallelogramBarPainter(
                progress: animatedValue,
                skewOffset: skewOffset,
                gradient: effectiveGradient,
                glowColor: effectiveGlowColor,
                borderColor: style.borderColor,
                trackColor: style.trackColor,
              ),
            ),

            // 2. Teks label tengah (tetap tegak lurus, tidak terdistorsi skew)
            if (label != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: skewOffset + 4),
                child: Text(
                  label!,
                  style: AppTheme.statNumber(
                    fontSize: (height * 0.58).clamp(10.0, 14.0),
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.95),
                        offset: const Offset(0, 1),
                        blurRadius: 3,
                      ),
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.9),
                        offset: const Offset(0, -1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      );
    }

    Widget barWidget = animate
        ? TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: clampedValue, end: clampedValue),
            duration: animationDuration,
            curve: Curves.easeOutCubic,
            builder: (context, val, child) => barContent(val),
          )
        : barContent(clampedValue);

    if (leadingIcon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          leadingIcon!,
          const SizedBox(width: 8),
          Expanded(child: barWidget),
        ],
      );
    }

    return barWidget;
  }
}

/// Painter kustom untuk menggambar parallelogram miring, alur pengisian gradien,
/// bevel 3D, dan ujung menyala (glowing spark cap).
class _ParallelogramBarPainter extends CustomPainter {
  _ParallelogramBarPainter({
    required this.progress,
    required this.skewOffset,
    required this.gradient,
    required this.glowColor,
    required this.borderColor,
    required this.trackColor,
  });

  final double progress;
  final double skewOffset;
  final LinearGradient gradient;
  final Color glowColor;
  final Color borderColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    // Batasi kemiringan agar tidak melebihi separuh lebar bar
    final skew = skewOffset.clamp(0.0, w * 0.35);

    // =========================================================================
    // 1. TRACK CHANNEL (Latar Belakang Parallelogram Miring)
    // =========================================================================
    final trackPath = Path()
      ..moveTo(skew, 0)
      ..lineTo(w, 0)
      ..lineTo(w - skew, h)
      ..lineTo(0, h)
      ..close();

    // Gambar dasar track (deep slate)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(trackPath, trackPaint);

    // Inner shadow track channel (kedalaman 3D)
    final innerShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(trackPath, innerShadowPaint);

    // =========================================================================
    // 2. PROGRESS FILL (Gradien Mengisi sesuai Persentase)
    // =========================================================================
    if (progress > 0.001) {
      final fillProgress = progress.clamp(0.0, 1.0);
      final fillWidth = (w - skew) * fillProgress;

      final fillPath = Path()
        ..moveTo(skew, 0)
        ..lineTo(skew + fillWidth, 0)
        ..lineTo(fillWidth, h)
        ..lineTo(0, h)
        ..close();

      final fillPaint = Paint()
        ..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h))
        ..style = PaintingStyle.fill;

      canvas.save();
      // Clip ke track agar aman dari overflow
      canvas.clipPath(trackPath);
      canvas.drawPath(fillPath, fillPaint);

      // Glossy highlight di paruh atas fill
      final fillGlossPath = Path()
        ..moveTo(skew, 0)
        ..lineTo(skew + fillWidth, 0)
        ..lineTo(skew * 0.5 + fillWidth * 0.98, h * 0.45)
        ..lineTo(skew * 0.5, h * 0.45)
        ..close();

      final fillGlossPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.38),
            Colors.white.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h * 0.45))
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillGlossPath, fillGlossPaint);

      // =======================================================================
      // 3. UJUNG MENYALA (Glow Spark Cap Flare)
      // =======================================================================
      // Garis ujung menyala terletak di batas kanan progress:
      // Dari (skew + fillWidth, 0) ke (fillWidth, h)
      final tipTopX = skew + fillWidth;
      final tipBottomX = fillWidth;

      // a. Glow flare kabur (bloom lebar)
      final glowPaint = Paint()
        ..color = glowColor.withValues(alpha: 0.75)
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawLine(Offset(tipTopX, 1), Offset(tipBottomX, h - 1), glowPaint);

      // b. Garis specular putih tajam di tengah flare
      final coreFlarePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(tipTopX, 2),
        Offset(tipBottomX, h - 2),
        coreFlarePaint,
      );

      // c. Titik intisari bercahaya (spark diamond/circle) di titik tengah cap
      final midTipX = (tipTopX + tipBottomX) / 2;
      final sparkPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(midTipX, h / 2), 2.5, sparkPaint);

      canvas.restore();
    }

    // =========================================================================
    // 4. BORDER LUAR ORNAMEN & BEVEL EMAS/LOGAM
    // =========================================================================
    final borderPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawPath(trackPath, borderPaint);

    // Bevel atas yang lebih terang (pantulan cahaya dari atas)
    final topBezelPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(skew, 0), Offset(w, 0), topBezelPaint);

    // Bevel bawah yang lebih gelap (bayangan bawah)
    final bottomBezelPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, h), Offset(w - skew, h), bottomBezelPaint);
  }

  @override
  bool shouldRepaint(covariant _ParallelogramBarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.skewOffset != skewOffset ||
        oldDelegate.gradient != gradient ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.trackColor != trackColor;
  }
}
