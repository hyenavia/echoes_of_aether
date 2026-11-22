import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../domain/entities/game_config.dart';
import '../../domain/services/codex_service.dart';
import '../shared/widgets/shared_widgets.dart';

/// Overlay Codex / Galeri Panduan untuk melihat daftar efek
/// Signature Weapon Resonance dan sumber drop material Ascension dari konfigurasi JSON.
class CodexOverlay extends StatefulWidget {
  const CodexOverlay({
    super.key,
    required this.config,
    this.unlockedSpecializations = const {},
    this.inventoryQuantitiesProvider,
    this.embedded = false,
    required this.onClose,
  });

  final GameConfig config;
  final Set<String> unlockedSpecializations;
  final Map<String, int> Function()? inventoryQuantitiesProvider;
  final bool embedded;
  final VoidCallback onClose;

  @override
  State<CodexOverlay> createState() => _CodexOverlayState();
}

class _CodexOverlayState extends State<CodexOverlay> {
  static const _service = CodexService();
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    final resonances = _service.buildResonanceEntries(
      config: widget.config,
      unlockedSpecializations: widget.unlockedSpecializations,
    );
    final owned = widget.inventoryQuantitiesProvider?.call() ?? const {};
    final materials = _service.buildMaterialEntries(
      config: widget.config,
      ownedQuantities: owned,
    );

    final panel = PanelFrame(
      showCornerOrnaments: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm + 2,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_outlined, size: 20, color: ext.gold),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Codex & Panduan',
                  style: AppTypography.headingSerif(
                    theme.textTheme.titleMedium,
                    color: ext.gold,
                  ),
                ),
              ),
              if (!widget.embedded)
                AppIconButton(
                  icon: Icons.close,
                  semanticLabel: 'Tutup',
                  tooltip: 'Tutup',
                  onPressed: widget.onClose,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: SegmentedButton<int>(
              key: const Key('codex_tabs'),
              segments: const [
                ButtonSegment<int>(
                  value: 0,
                  icon: Icon(Icons.auto_awesome),
                  label: Text('Resonansi'),
                ),
                ButtonSegment<int>(
                  value: 1,
                  icon: Icon(Icons.diamond_outlined),
                  label: Text('Material & Drop'),
                ),
              ],
              selected: {_selectedTab},
              onSelectionChanged: (next) =>
                  setState(() => _selectedTab = next.first),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: _selectedTab == 0
                ? _buildResonanceList(theme, ext, resonances)
                : _buildMaterialList(theme, ext, materials),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: panel,
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 660),
          child: panel,
        ),
      ),
    );
  }

  Widget _buildResonanceList(
    ThemeData theme,
    EchoesThemeExtension ext,
    List<CodexResonanceEntry> entries,
  ) {
    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada data Signature Weapon Resonance.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs + 2),
      itemBuilder: (context, index) {
        final item = entries[index];
        final rarityColor = ext.colorForRarity(item.specializationRarity);
        return PanelFrame(
          key: Key('codex_resonance_${item.specializationId}'),
          padding: const EdgeInsets.all(AppSpacing.sm),
          backgroundColor: AppColors.surfaceDark,
          borderColor: rarityColor.withValues(alpha: 0.45),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  RarityLabel(rarity: item.specializationRarity, compact: true),
                  const SizedBox(width: AppSpacing.xs),
                  ClassEmblemIcon(
                    specializationId: item.specializationId,
                    size: 22,
                    fallbackColor: rarityColor,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      item.specializationName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: rarityColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs + 2,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (item.isUnlocked ? ext.success : AppColors.textMuted)
                              .withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color:
                            (item.isUnlocked
                                    ? ext.success
                                    : AppColors.textMuted)
                                .withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      item.isUnlocked ? 'Terbuka' : 'Terkunci',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: item.isUnlocked
                            ? ext.success
                            : AppColors.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(Icons.hardware_outlined, size: 14, color: ext.gold),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Senjata Signature: ${item.signatureWeaponName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ext.gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.resonanceDescription.isNotEmpty
                    ? item.resonanceDescription
                    : 'Aktif saat memakai senjata signature yang sesuai.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMaterialList(
    ThemeData theme,
    EchoesThemeExtension ext,
    List<CodexMaterialEntry> entries,
  ) {
    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada data material.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs + 2),
      itemBuilder: (context, index) {
        final item = entries[index];
        final rarityColor = ext.colorForRarity(item.rarity);
        final phaseLabel = item.usedInAscensionPhases
            .map((p) => 'A$p')
            .join(', ');

        return PanelFrame(
          key: Key('codex_material_${item.itemId}'),
          padding: const EdgeInsets.all(AppSpacing.sm),
          backgroundColor: AppColors.surfaceDark,
          borderColor: rarityColor.withValues(alpha: 0.45),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  RarityLabel(rarity: item.rarity, compact: true),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      item.itemName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: rarityColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    'Dimiliki: ${NumberFormatter.format(item.ownedQuantity)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (item.isAscensionMaterial) ...[
                const SizedBox(height: 4),
                Text(
                  'Dipakai untuk Terobosan: $phaseLabel',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: ext.gold,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              if (item.dropSources.isEmpty)
                const Text(
                  'Sumber drop belum terdaftar.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                )
              else
                for (final src in item.dropSources)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Icon(
                          src.isBossOrClear
                              ? Icons.stars_outlined
                              : Icons.place_outlined,
                          size: 13,
                          color: src.isBossOrClear
                              ? ext.gold
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            src.sourceLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${(src.chance * 100).round()}%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: src.chance >= 0.99
                                ? ext.success
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}
