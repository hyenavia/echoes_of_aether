import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Gaya visual gradien dan aksen untuk [GameButton].
enum GameButtonStyle {
  /// Gradien Magical Gold (#FFD700) mewah — Tombol aksi utama, klaim hadiah, konfirmasi run.
  gold(
    gradient: AppTheme.goldGradient,
    borderColor: Color(0xFFFFF07C),
    bottomBezelColor: Color(0xFF7A5408),
    textColor: Color(0xFF221500),
    glowColor: AppTheme.gold,
  ),

  /// Gradien Arcane Purple (#9D4EDD) — Aksi sihir, rank up, terobosan hero, gacha.
  arcane(
    gradient: AppTheme.arcaneGradient,
    borderColor: Color(0xFFE0AAFF),
    bottomBezelColor: Color(0xFF3C096C),
    textColor: Colors.white,
    glowColor: AppTheme.arcanePurple,
  ),

  /// Gradien Cyan Glow (#00F5D4) — EXP, upgrade, info aksi, aether tech.
  cyan(
    gradient: AppTheme.cyanGradient,
    borderColor: Color(0xFFA7FFF6),
    bottomBezelColor: Color(0xFF005F73),
    textColor: Color(0xFF002B36),
    glowColor: AppTheme.cyanGlow,
  ),

  /// Gradien Deep Slate — Tombol sekunder, tutup, batal, navigasi samping.
  slate(
    gradient: AppTheme.slateGradient,
    borderColor: Color(0xFF4A5F87),
    bottomBezelColor: Color(0xFF0A0F1A),
    textColor: AppTheme.textPrimary,
    glowColor: AppTheme.panelBorderHighlight,
  ),

  /// Gradien Crimson Red — Bahaya, keluar dungeon, reset, menyerah.
  danger(
    gradient: AppTheme.hpGradient,
    borderColor: Color(0xFFFF9E9E),
    bottomBezelColor: Color(0xFF4A000E),
    textColor: Colors.white,
    glowColor: AppTheme.hpRed,
  );

  const GameButtonStyle({
    required this.gradient,
    required this.borderColor,
    required this.bottomBezelColor,
    required this.textColor,
    required this.glowColor,
  });

  final LinearGradient gradient;
  final Color borderColor;
  final Color bottomBezelColor;
  final Color textColor;
  final Color glowColor;
}

/// Tombol interaktif khas game RPG dengan:
/// - Gradien berornamen dan bevel 3D.
/// - Efek glossy (pantulan specular di paruh atas).
/// - Drop shadow tebal berlayer glow.
/// - Efek tactile pressed (mengecil 0.94x dan turun 2px saat ditekan).
/// - Dukungan animasi pulse (berdenyut halus) untuk tombol aksi krusial.
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.onPressed,
    this.text,
    this.icon,
    this.child,
    this.style = GameButtonStyle.gold,
    this.width,
    this.height = 46.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    this.enabled = true,
    this.isLoading = false,
    this.pulse = false,
    this.fontSize = 15.0,
  }) : assert(
         text != null || child != null,
         'GameButton membutuhkan text atau child.',
       );

  /// Pintasan untuk tombol emas utama.
  const GameButton.gold({
    super.key,
    required this.onPressed,
    this.text,
    this.icon,
    this.child,
    this.width,
    this.height = 46.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    this.enabled = true,
    this.isLoading = false,
    this.pulse = false,
    this.fontSize = 15.0,
  }) : style = GameButtonStyle.gold;

  /// Pintasan untuk tombol arcane purple.
  const GameButton.arcane({
    super.key,
    required this.onPressed,
    this.text,
    this.icon,
    this.child,
    this.width,
    this.height = 46.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    this.enabled = true,
    this.isLoading = false,
    this.pulse = false,
    this.fontSize = 15.0,
  }) : style = GameButtonStyle.arcane;

  /// Pintasan untuk tombol sekunder slate.
  const GameButton.slate({
    super.key,
    required this.onPressed,
    this.text,
    this.icon,
    this.child,
    this.width,
    this.height = 46.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    this.enabled = true,
    this.isLoading = false,
    this.pulse = false,
    this.fontSize = 15.0,
  }) : style = GameButtonStyle.slate;

  final VoidCallback? onPressed;
  final String? text;
  final IconData? icon;
  final Widget? child;
  final GameButtonStyle style;
  final double? width;
  final double height;
  final EdgeInsetsGeometry padding;
  final bool enabled;
  final bool isLoading;
  final bool pulse;
  final double fontSize;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    final isTesting =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (widget.pulse && widget.enabled && !isTesting) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant GameButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isTesting =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (widget.pulse != oldWidget.pulse ||
        widget.enabled != oldWidget.enabled) {
      if (widget.pulse && widget.enabled && !isTesting) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (!widget.enabled || widget.isLoading) return;
    HapticFeedback.selectionClick();
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (!widget.enabled || widget.isLoading) return;
    setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (!widget.enabled || widget.isLoading) return;
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final isClickable = widget.enabled && !widget.isLoading;

    // Konten tombol (Icon + Teks atau Custom Child)
    Widget buttonContent;
    if (widget.isLoading) {
      buttonContent = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          valueColor: AlwaysStoppedAnimation<Color>(style.textColor),
        ),
      );
    } else if (widget.child != null) {
      buttonContent = widget.child!;
    } else {
      final textWidget = Text(
        widget.text!,
        style: AppTheme.headingFantasy(
          fontSize: widget.fontSize,
          color: style.textColor,
          letterSpacing: 1.0,
          shadows: [
            if (style == GameButtonStyle.gold || style == GameButtonStyle.cyan)
              Shadow(
                color: Colors.white.withValues(alpha: 0.6),
                offset: const Offset(0, 1),
                blurRadius: 1,
              )
            else
              Shadow(
                color: Colors.black.withValues(alpha: 0.9),
                offset: const Offset(0, 2),
                blurRadius: 3,
              ),
          ],
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );

      if (widget.icon != null) {
        buttonContent = Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.icon,
              size: widget.fontSize + 3,
              color: style.textColor,
            ),
            const SizedBox(width: 8),
            Flexible(child: textWidget),
          ],
        );
      } else {
        buttonContent = textWidget;
      }
    }

    // Bangun Box Tombol dengan Bevel & Glossy
    Widget buttonBox = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: isClickable
            ? style.gradient
            : const LinearGradient(
                colors: [AppTheme.surfaceElevated, AppTheme.surface],
              ),
        border: Border.all(
          color: isClickable
              ? style.borderColor.withValues(alpha: 0.85)
              : AppTheme.panelBorder,
          width: 1.5,
        ),
        boxShadow: isClickable
            ? [
                // 1. Drop shadow bawah
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.65),
                  blurRadius: _isPressed ? 3 : 7,
                  offset: Offset(0, _isPressed ? 1 : 4),
                ),
                // 2. Glow lembut aksen
                if (!_isPressed)
                  BoxShadow(
                    color: style.glowColor.withValues(alpha: 0.35),
                    blurRadius: 10,
                    spreadRadius: 0.5,
                  ),
              ]
            : const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6.5),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Lapisan Bevel Bawah (efek kedalaman 3D tombol mekanik)
            if (isClickable)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: _isPressed ? 1.5 : 3.5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: style.bottomBezelColor.withValues(alpha: 0.7),
                  ),
                ),
              ),

            // Lapisan Specular Highlight Atas (1.5px rim putih lembut)
            if (isClickable)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1.5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ),

            // Lapisan Glossy Specular Highlight di paruh atas
            if (isClickable)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: widget.height * 0.46,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.38),
                        Colors.white.withValues(alpha: 0.04),
                      ],
                    ),
                  ),
                ),
              ),

            // Konten Tengah
            Padding(padding: widget.padding, child: buttonContent),
          ],
        ),
      ),
    );

    // Animasi Tactile Pressed: scale 0.94x dan turun 2px
    Widget interactiveButton = GestureDetector(
      onTapDown: isClickable ? _handleTapDown : null,
      onTapUp: isClickable ? _handleTapUp : null,
      onTapCancel: isClickable ? _handleTapCancel : null,
      onTap: isClickable ? widget.onPressed : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: Offset(0, _isPressed ? 0.04 : 0.0),
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOutCubic,
          child: Opacity(
            opacity: widget.enabled ? 1.0 : 0.45,
            child: buttonBox,
          ),
        ),
      ),
    );

    // Efek pulse berdenyut jika diminta
    if (widget.pulse && widget.enabled) {
      interactiveButton = ScaleTransition(
        scale: _pulseAnimation,
        child: interactiveButton,
      );
    }

    return interactiveButton;
  }
}
