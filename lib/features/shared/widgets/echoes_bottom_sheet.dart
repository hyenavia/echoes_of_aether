import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import 'app_icon_button.dart';

/// Kontainer bottom sheet bergaya Living Aether Camp dengan handle, header
/// serif, dan SafeArea.
class EchoesBottomSheet extends StatelessWidget {
  const EchoesBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.onClose,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
          border: Border(
            top: BorderSide(color: AppColors.panelBorder, width: 1.5),
            left: BorderSide(color: AppColors.panelBorder, width: 1.5),
            right: BorderSide(color: AppColors.panelBorder, width: 1.5),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.panelBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headingSerif(
                          theme.textTheme.titleLarge,
                          color: AppColors.antiqueGold,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppIconButton(
                  icon: Icons.close,
                  semanticLabel: 'Tutup',
                  onPressed: onClose ?? () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(child: SingleChildScrollView(child: child)),
          ],
        ),
      ),
    );
  }
}

/// Helper terpusat untuk menampilkan [EchoesBottomSheet].
Future<T?> showEchoesBottomSheet<T>({
  required BuildContext context,
  required String title,
  required Widget child,
  String? subtitle,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => EchoesBottomSheet(
      title: title,
      subtitle: subtitle,
      onClose: () => Navigator.of(sheetContext).pop(),
      child: child,
    ),
  );
}
