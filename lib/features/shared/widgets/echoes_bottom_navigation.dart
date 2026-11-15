import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/echoes_theme.dart';

/// Definisi tab navigasi utama Living Aether Camp.
@immutable
class EchoesNavItem {
  const EchoesNavItem({
    required this.label,
    required this.icon,
    this.activeIcon,
    this.key,
  });

  final String label;
  final IconData icon;
  final IconData? activeIcon;
  final Key? key;
}

/// Navigasi bawah terpadu berdesain RPG dengan aksen Antique Gold dan proteksi
/// target sentuh minimal 44dp serta teks bebas overflow.
class EchoesBottomNavigation extends StatelessWidget {
  const EchoesBottomNavigation({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<EchoesNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final ext = EchoesTheme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(
          top: BorderSide(
            color: ext.gold.withValues(alpha: 0.35),
            width: AppBorders.thin,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavTabButton(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTabButton extends StatelessWidget {
  const _NavTabButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final EchoesNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = EchoesTheme.of(context);
    final color = selected ? ext.gold : AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        key: item.key,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.xs + 2,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: AppDurations.fast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm + 2,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? ext.gold.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: selected
                        ? Border.all(
                            color: ext.gold.withValues(alpha: 0.45),
                            width: AppBorders.thin,
                          )
                        : null,
                  ),
                  child: Icon(
                    selected ? (item.activeIcon ?? item.icon) : item.icon,
                    size: 20,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Flexible(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0.15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
