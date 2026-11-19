import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import 'aether_logo.dart';
import 'aether_symbol_mark.dart';

/// Splash Screen resmi Echoes of Aether.
/// Menggunakan Primary Horizontal Logo, latar belakang dark fantasy (Midnight Forest),
/// subtle aether glow, dan komposisi bersih terpusat.
class AetherSplashScreen extends StatefulWidget {
  const AetherSplashScreen({
    super.key,
    required this.onComplete,
    this.minDuration = const Duration(milliseconds: 1400),
  });

  final VoidCallback onComplete;
  final Duration minDuration;

  @override
  State<AetherSplashScreen> createState() => _AetherSplashScreenState();
}

class _AetherSplashScreenState extends State<AetherSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  Timer? _timer;
  var _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.94,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    // Auto advance after minDuration
    _timer = Timer(widget.minDuration, () {
      if (mounted && !_completed) {
        _handleComplete();
      }
    });
  }

  void _handleComplete() {
    if (_completed) return;
    _completed = true;
    _timer?.cancel();
    widget.onComplete();
  }

  @override
  void dispose() {
    _completed = true;
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleComplete,
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: AppColors.midnightForest,
        body: Stack(
          children: [
            // Subtle ambient aether glow in the center
            Center(
              child: Container(
                width: 320,
                height: 320,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x2269BFE5),
                      Color(0x0A203B30),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Centered Branding Content
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AetherLogo(
                          variant: AetherLogoVariant.primary,
                          width: 300,
                        ),
                        SizedBox(height: 20),
                        AetherSymbolMark(
                          variant: AetherSymbolVariant.mark,
                          size: 32,
                          glow: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Subtle copyright / version text at bottom
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Echoes of Aether • Idle Dungeon RPG',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.1,
                    color: AppColors.textMuted.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
