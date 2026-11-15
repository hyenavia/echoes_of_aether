import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';

/// Tombol aksi utama dengan target sentuh minimal 44dp dan proteksi overflow.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: AppSpacing.xs + 2),
        ],
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: SizedBox(
          width: expand ? double.infinity : null,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.antiqueGold,
              foregroundColor: AppColors.midnightForest,
              disabledBackgroundColor: AppColors.panelInnerBorder,
              disabledForegroundColor: AppColors.textMuted,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
