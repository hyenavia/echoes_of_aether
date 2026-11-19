import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import 'aether_symbol_mark.dart';

/// Indikator pemuatan bertema Aether crystal dengan pulsasi cahaya lembut.
class AetherLoadingIndicator extends StatefulWidget {
  const AetherLoadingIndicator({super.key, this.size = 40.0, this.message});

  final double size;
  final String? message;

  @override
  State<AetherLoadingIndicator> createState() => _AetherLoadingIndicatorState();
}

class _AetherLoadingIndicatorState extends State<AetherLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final pulse =
                (math.sin(_controller.value * 2 * math.pi) + 1.0) / 2.0;
            final glowOpacity = 0.2 + (pulse * 0.45);
            return Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.aetherBlue.withValues(alpha: glowOpacity),
                    blurRadius: widget.size * 0.4,
                    spreadRadius: widget.size * 0.1,
                  ),
                ],
              ),
              child: AetherSymbolMark(
                size: widget.size,
                variant: AetherSymbolVariant.mark,
              ),
            );
          },
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.message!,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}
