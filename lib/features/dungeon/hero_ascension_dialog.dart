import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../domain/entities/hero_ascension.dart';
import '../../domain/entities/item_definition.dart';
import '../../domain/entities/player_progress.dart';
import '../../domain/services/hero_ascension_service.dart';
import '../../game/hud/inventory_views.dart';
import '../shared/widgets/shared_widgets.dart';

/// Dialog konfirmasi terobosan Hero Ascension (Level Cap & Breakthrough)
/// sesuai GDD Addendum v1.5.
class HeroAscensionDialog extends StatefulWidget {
  const HeroAscensionDialog({
    super.key,
    required this.characterSnapshot,
    this.items = const {},
    this.inventoryQuantities = const {},
    this.currencies = const {},
    required this.onConfirmAscend,
    this.onClose,
  });

  final CharacterSnapshot characterSnapshot;
  final Map<String, ItemDefinition> items;
  final Map<String, int> inventoryQuantities;
  final Map<String, int> currencies;
  final Future<HeroAscensionResult> Function() onConfirmAscend;
  final VoidCallback? onClose;

  @override
  State<HeroAscensionDialog> createState() => _HeroAscensionDialogState();
}

class _HeroAscensionDialogState extends State<HeroAscensionDialog> {
  bool _isAscending = false;
  HeroAscensionResult? _ascendedResult;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    final s = widget.characterSnapshot;
    final cfg = s.heroAscensionConfig;
    final currentPhase = s.ascensionPhase;
    final isMaxPhase = currentPhase >= cfg.maxPhase;

    final nextPhaseDef = !isMaxPhase ? cfg.phase(currentPhase + 1) : null;
    final service = HeroAscensionService(cfg);
    final evalResult = !isMaxPhase
        ? service.canAscend(
            progress: s.toPlayerProgress(),
            inventoryStacks: widget.inventoryQuantities,
            currencies: widget.currencies,
          )
        : null;

    Widget body;
    if (_ascendedResult != null && _ascendedResult!.succeeded) {
      body = _buildCelebrationView(context, ext, theme, _ascendedResult!);
    } else if (isMaxPhase) {
      body = _buildMaxPhaseView(context, ext, theme, cfg);
    } else if (nextPhaseDef != null && evalResult != null) {
      body = _buildBreakthroughForm(
        context,
        ext,
        theme,
        nextPhaseDef,
        evalResult,
      );
    } else {
      body = const Center(child: Text('Data fase tidak tersedia.'));
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: PanelFrame(
          showCornerOrnaments: true,
          borderColor: isMaxPhase || (_ascendedResult?.hasGoldenAura ?? false)
              ? ext.gold
              : ext.panelBorder,
          boxShadow: isMaxPhase || (_ascendedResult?.hasGoldenAura ?? false)
              ? AppShadows.glow(ext.gold, alpha: 0.3)
              : AppShadows.panel,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: body,
        ),
      ),
    );
  }

  Widget _buildCelebrationView(
    BuildContext context,
    EchoesThemeExtension ext,
    ThemeData theme,
    HeroAscensionResult result,
  ) {
    final nextPhaseDef = result.phaseDefinition;
    final newCap = nextPhaseDef?.levelCap ?? 90;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AppIconButton(
              icon: Icons.close,
              semanticLabel: 'Tutup',
              onPressed: () {
                widget.onClose?.call();
                Navigator.of(context).maybePop();
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ext.gold.withValues(alpha: 0.16),
              border: Border.all(color: ext.gold, width: 2),
              boxShadow: AppShadows.glow(ext.gold, alpha: 0.4),
            ),
            child: Icon(Icons.auto_awesome, color: ext.gold, size: 48),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'ASCENDED!',
          key: const Key('ascended_celebration_title'),
          textAlign: TextAlign.center,
          style: AppTypography.headingSerif(
            theme.textTheme.headlineSmall,
            color: ext.gold,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Karakter berhasil menembus ke Fase A${result.newPhase}!',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Batas level karakter meningkat hingga Level $newCap.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        if (result.hasGoldenAura) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: ext.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: ext.gold.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.stars, color: ext.gold, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Aura Emas Puncak Telah Aktif!',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: ext.gold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        ElevatedButton(
          key: const Key('ascended_dialog_close_button'),
          style: ElevatedButton.styleFrom(
            backgroundColor: ext.gold,
            foregroundColor: AppColors.surfaceDark,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
          ),
          onPressed: () {
            widget.onClose?.call();
            Navigator.of(context).maybePop();
          },
          child: const Text(
            'Lanjutkan Petualangan',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildMaxPhaseView(
    BuildContext context,
    EchoesThemeExtension ext,
    ThemeData theme,
    HeroAscensionConfig cfg,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, color: ext.gold, size: 20),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Hero Ascension',
                style: AppTypography.headingSerif(
                  theme.textTheme.titleMedium,
                  color: ext.gold,
                ),
              ),
            ),
            AppIconButton(
              icon: Icons.close,
              semanticLabel: 'Tutup',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        const Divider(color: AppColors.panelBorder),
        const SizedBox(height: AppSpacing.md),
        Center(child: Icon(Icons.workspace_premium, color: ext.gold, size: 48)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'MAX POTENTIAL REACHED',
          textAlign: TextAlign.center,
          style: AppTypography.headingSerif(
            theme.textTheme.titleMedium,
            color: ext.gold,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Karakter telah mencapai Fase A6 (Level Cap 90) dengan Aura Emas Puncak aktif. Kekuatan terobosan hero telah sempurna.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Tutup'),
        ),
      ],
    );
  }

  Widget _buildBreakthroughForm(
    BuildContext context,
    EchoesThemeExtension ext,
    ThemeData theme,
    HeroAscensionPhaseDefinition nextPhaseDef,
    HeroAscensionCanAscendResult evalResult,
  ) {
    final s = widget.characterSnapshot;
    final currentPhase = s.ascensionPhase;
    final nextPhase = nextPhaseDef.phase;
    final nextCap = nextPhaseDef.levelCap;
    final boost = nextPhaseDef.statBoost;
    final cost = nextPhaseDef.cost;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.auto_awesome, color: ext.gold, size: 20),
              const SizedBox(width: AppSpacing.xs + 2),
              Expanded(
                child: Text(
                  'Terobosan Hero Ascension',
                  style: AppTypography.headingSerif(
                    theme.textTheme.titleMedium,
                    color: ext.gold,
                  ),
                ),
              ),
              AppIconButton(
                icon: Icons.close,
                semanticLabel: 'Tutup',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Buka batas level karakter dan peroleh bonus atribut terobosan permanen.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, color: AppColors.panelBorder),
          const SizedBox(height: AppSpacing.sm),

          // Phase comparison banner
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: ext.panelInnerBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'Fase A$currentPhase',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cap Lv ${s.effectiveLevelCap}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.arrow_forward, color: ext.gold, size: 20),
                Column(
                  children: [
                    Text(
                      'Fase A$nextPhase${nextPhase == 6 ? ' (MAX)' : ''}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: ext.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cap Lv $nextCap',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: ext.gold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Breakthrough Stat Boost Preview
          const SectionHeader(title: 'Bonus Terobosan', useSerif: true),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: ext.panelInnerBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xs,
                  children: [
                    if (boost.hp > 0) _statChip(ext, '+${boost.hp} Max HP'),
                    if (boost.atk > 0) _statChip(ext, '+${boost.atk} ATK'),
                    if (boost.def > 0) _statChip(ext, '+${boost.def} DEF'),
                    if (boost.critRate > 0)
                      _statChip(
                        ext,
                        '+${(boost.critRate * 100).toStringAsFixed(1)}% Crit Rate',
                      ),
                    if (boost.attackSpeed > 0)
                      _statChip(
                        ext,
                        '+${(boost.attackSpeed * 100).toStringAsFixed(1)}% Atk Speed',
                      ),
                    if (boost.critDamage > 0)
                      _statChip(
                        ext,
                        '+${(boost.critDamage * 100).toStringAsFixed(1)}% Crit DMG',
                      ),
                    if (boost.skillHaste > 0)
                      _statChip(
                        ext,
                        '+${(boost.skillHaste * 100).toStringAsFixed(1)}% Skill Haste',
                      ),
                  ],
                ),
                if (nextPhase == 6) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(Icons.stars, color: ext.gold, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Aura Emas Puncak (Golden Aura Status)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ext.gold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Requirement & Cost Checklist
          const SectionHeader(title: 'Syarat & Biaya', useSerif: true),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: ext.panelInnerBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Level requirement
                _requirementRow(
                  theme: theme,
                  ext: ext,
                  label: 'Level Karakter',
                  requiredStr: 'Lv ${nextPhaseDef.requiredPlayerLevel}',
                  currentStr: 'Lv ${s.level}',
                  isMet: s.level >= nextPhaseDef.requiredPlayerLevel,
                ),
                const Divider(height: 8, color: AppColors.panelBorder),
                // Gold requirement
                if (cost.gold > 0) ...[
                  _requirementRow(
                    theme: theme,
                    ext: ext,
                    label: 'Gold',
                    requiredStr: '${NumberFormatter.format(cost.gold)} G',
                    currentStr: '${NumberFormatter.format(s.gold)} G',
                    isMet: s.gold >= cost.gold,
                  ),
                  const Divider(height: 8, color: AppColors.panelBorder),
                ],
                // Items requirement
                for (final itemEntry in cost.items.entries) ...[
                  () {
                    final itemId = itemEntry.key;
                    final reqQty = itemEntry.value;
                    final ownedQty = widget.inventoryQuantities[itemId] ?? 0;
                    final itemName = widget.items[itemId]?.name ?? itemId;
                    return _requirementRow(
                      theme: theme,
                      ext: ext,
                      label: itemName,
                      requiredStr: '$reqQty unit',
                      currentStr: '$ownedQty unit',
                      isMet: ownedQty >= reqQty,
                    );
                  }(),
                  const Divider(height: 8, color: AppColors.panelBorder),
                ],
                // Currencies requirement
                for (final currEntry in cost.currencies.entries) ...[
                  () {
                    final currId = currEntry.key;
                    final reqQty = currEntry.value;
                    final ownedQty = widget.currencies[currId] ?? 0;
                    final currName = currId == 'aether_shard'
                        ? 'Aether Shard'
                        : currId;
                    return _requirementRow(
                      theme: theme,
                      ext: ext,
                      label: currName,
                      requiredStr: '$reqQty',
                      currentStr: '$ownedQty',
                      isMet: ownedQty >= reqQty,
                    );
                  }(),
                  const Divider(height: 8, color: AppColors.panelBorder),
                ],
              ],
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _errorMessage!,
              style: TextStyle(color: AppColors.emberRed, fontSize: 11),
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  key: const Key('confirm_ascend_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: evalResult.canAscend
                        ? ext.gold
                        : AppColors.panelBorder,
                    foregroundColor: evalResult.canAscend
                        ? AppColors.surfaceDark
                        : AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  onPressed: evalResult.canAscend && !_isAscending
                      ? _handleConfirmAscend
                      : null,
                  child: _isAscending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Terobosan Sekarang',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(EchoesThemeExtension ext, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: ext.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: ext.gold.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: ext.gold,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _requirementRow({
    required ThemeData theme,
    required EchoesThemeExtension ext,
    required String label,
    required String requiredStr,
    required String currentStr,
    required bool isMet,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  isMet ? Icons.check_circle : Icons.cancel,
                  size: 14,
                  color: isMet ? ext.success : AppColors.emberRed,
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$currentStr / $requiredStr',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isMet ? ext.success : AppColors.emberRed,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConfirmAscend() async {
    setState(() {
      _isAscending = true;
      _errorMessage = null;
    });
    try {
      final res = await widget.onConfirmAscend();
      if (!mounted) return;
      if (res.succeeded) {
        setState(() {
          _isAscending = false;
          _ascendedResult = res;
        });
      } else {
        setState(() {
          _isAscending = false;
          _errorMessage = _describeFailure(res.failureReason);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAscending = false;
        _errorMessage = 'Gagal melakukan terobosan: $e';
      });
    }
  }

  String _describeFailure(HeroAscensionFailureReason reason) {
    return switch (reason) {
      HeroAscensionFailureReason.none => '',
      HeroAscensionFailureReason.maxPhaseReached =>
        'Fase puncak A6 sudah tercapai.',
      HeroAscensionFailureReason.levelTooLow =>
        'Level karakter belum memenuhi syarat.',
      HeroAscensionFailureReason.insufficientGold => 'Saldo Gold tidak cukup.',
      HeroAscensionFailureReason.insufficientMaterials =>
        'Material boss remnant atau scrap tidak cukup.',
      HeroAscensionFailureReason.insufficientCurrencies =>
        'Aether Shard tidak cukup.',
    };
  }
}

extension _CharacterSnapshotHelper on CharacterSnapshot {
  PlayerProgress toPlayerProgress() {
    return PlayerProgress(
      level: level,
      gold: gold,
      ascensionPhase: ascensionPhase,
    );
  }
}
