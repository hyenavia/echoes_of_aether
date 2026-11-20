import 'package:flutter/material.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../theme/app_theme.dart';

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

/// Navigasi bawah bergaya Wood & Dark Metal RPG dengan aksen emas berornamen
/// dan efek ikon menyala (glow) saat dipilih.
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
    return Container(
      decoration: BoxDecoration(
        // Gradien kayu/metal gelap fantasi
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF261D17), // Rich dark bronze-wood
            Color(0xFF18120E), // Dark iron wood
            Color(0xFF0F0B09), // Deep shadow base
          ],
        ),
        border: const Border(
          top: BorderSide(
            color: Color(0xFFD4AF37), // Golden metallic trim
            width: 2.0,
          ),
        ),
        boxShadow: [
          // Shadow ke atas layar
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            offset: const Offset(0, -3),
            blurRadius: 10,
          ),
          // Glow emas halus dari trim atas
          BoxShadow(
            color: AppTheme.gold.withValues(alpha: 0.15),
            offset: const Offset(0, -1),
            blurRadius: 4,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
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
    final activeColor = AppTheme.gold;
    final inactiveColor = AppTheme.textMuted;
    final color = selected ? activeColor : inactiveColor;

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
              vertical: 4,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Indikator permata emas di atas tab aktif
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: selected ? 16 : 0,
                  height: 2,
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.goldLight : Colors.transparent,
                    borderRadius: BorderRadius.circular(1),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppTheme.gold.withValues(alpha: 0.8),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(height: 3),

                // Icon dengan glow saat aktif
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.gold.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: selected
                        ? Border.all(
                            color: AppTheme.gold.withValues(alpha: 0.6),
                            width: 1.2,
                          )
                        : null,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppTheme.gold.withValues(alpha: 0.35),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    selected ? (item.activeIcon ?? item.icon) : item.icon,
                    size: 20,
                    color: color,
                    shadows: selected
                        ? [
                            Shadow(
                              color: AppTheme.gold.withValues(alpha: 0.8),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(height: 2),

                // Label Tab
                Flexible(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: selected
                          ? AppTheme.fantasyFontFamily
                          : AppTheme.statsFontFamily,
                      fontFamilyFallback: selected
                          ? AppTheme.fantasyFontFallback
                          : AppTheme.statsFontFallback,
                      fontSize: 10.5,
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: selected ? 0.4 : 0.1,
                      shadows: selected
                          ? [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.9),
                                offset: const Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ]
                          : null,
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
