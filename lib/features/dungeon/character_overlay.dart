import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../domain/entities/combat_stats.dart';
import '../../domain/entities/specialization.dart';
import '../../game/hud/inventory_views.dart';
import '../shared/widgets/shared_widgets.dart';
import 'equipment_text.dart';
import 'skill_text.dart';

/// Layar karakter: profil hero berilustrasi, stat tempur, pilihan
/// specialization, dan daftar/upgrade skill.
class CharacterOverlay extends StatelessWidget {
  const CharacterOverlay({
    super.key,
    required this.snapshot,
    required this.onChooseSpecialization,
    this.onUpgradeSkill,
    required this.onClose,
  });

  final ValueListenable<CharacterSnapshot> snapshot;
  final void Function(String specializationId) onChooseSpecialization;
  final void Function(String skillId)? onUpgradeSkill;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 640),
          child: PanelFrame(
            showCornerOrnaments: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xs + 2,
              AppSpacing.md,
              AppSpacing.xs + 2,
            ),
            child: ValueListenableBuilder<CharacterSnapshot>(
              valueListenable: snapshot,
              builder: (context, s, _) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Karakter - Lv ${NumberFormatter.format(s.level)}',
                              style: AppTypography.headingSerif(
                                theme.textTheme.titleMedium,
                                color: ext.gold,
                              ),
                            ),
                            ResourceChip.gold(s.gold),
                          ],
                        ),
                      ),
                      AppIconButton(
                        icon: Icons.close,
                        semanticLabel: 'Tutup',
                        tooltip: 'Tutup',
                        onPressed: onClose,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _HeroProfileBanner(snapshot: s),
                          if (s.stats != null) ...[
                            const SectionHeader(
                              title: 'Stat Tempur',
                              useSerif: true,
                            ),
                            _CombatStatGrid(stats: s.stats!),
                          ],
                          const SectionHeader(
                            title: 'Spesialisasi',
                            useSerif: true,
                          ),
                          if (!s.canChooseSpecialization)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: LockedBadge(
                                label:
                                    'Terbuka di level ${s.specializationUnlockLevel}.',
                              ),
                            ),
                          for (final spec in s.specializations)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.xs,
                              ),
                              child: _specTile(context, s, spec),
                            ),
                          const SectionHeader(title: 'Skill', useSerif: true),
                          for (final e in s.skills)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.xs,
                              ),
                              child: _skillTile(context, e),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _skillTile(BuildContext context, SkillEntry e) {
    final ext = EchoesTheme.of(context);
    final theme = Theme.of(context);
    final isMax = e.level >= e.definition.maxLevel;
    final Widget trailing;
    if (!e.unlocked) {
      trailing = const LockedBadge(label: 'Terkunci');
    } else if (isMax) {
      trailing = Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: ext.gold.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: ext.gold.withValues(alpha: 0.5)),
        ),
        child: Text(
          'MAX',
          style: theme.textTheme.labelSmall?.copyWith(
            color: ext.gold,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    } else if (onUpgradeSkill != null) {
      trailing = FilledButton.tonal(
        onPressed: e.canUpgrade ? () => onUpgradeSkill!(e.definition.id) : null,
        child: Text('Upgrade (${NumberFormatter.format(e.nextUpgradeCost)}G)'),
      );
    } else {
      trailing = Text(
        'Lv ${e.level}/${e.definition.maxLevel}',
        style: AppTypography.numeric(theme.textTheme.labelMedium),
      );
    }

    return PanelFrame(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs + 2,
      ),
      backgroundColor: AppColors.surfaceDark,
      borderColor: e.unlocked
          ? ext.panelBorder.withValues(alpha: 0.72)
          : ext.panelInnerBorder,
      child: _AdaptiveOverlayTile(
        title: Text(
          e.unlocked
              ? '${e.definition.name} • Lv ${e.level}/${e.definition.maxLevel}'
              : '${e.definition.name} (Lv ${e.definition.unlockLevel})',
          style: theme.textTheme.titleSmall?.copyWith(
            color: e.unlocked ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
        subtitle: Text(
          describeSkill(e.definition, level: e.level),
          style: theme.textTheme.bodySmall?.copyWith(
            color: e.unlocked ? AppColors.textSecondary : AppColors.textMuted,
          ),
        ),
        trailing: trailing,
      ),
    );
  }

  Widget _specTile(
    BuildContext context,
    CharacterSnapshot s,
    SpecializationDefinition spec,
  ) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    final selected = s.specializationId == spec.id;
    final requiredLevel = spec.unlockLevel ?? s.specializationUnlockLevel;
    final unlocked = s.level >= requiredLevel;
    final range = spec.attackRange == null
        ? ''
        : ' | Jangkauan ${spec.attackRange!.toStringAsFixed(1)}';
    final affinities = spec.skillAffinities.entries
        .map(
          (e) => '${s.skillNames[e.key] ?? e.key} +${(e.value * 100).round()}%',
        )
        .join(', ');
    final affinityLine = affinities.isEmpty ? '' : '\nAfinitas: $affinities';

    return PanelFrame(
      showCornerOrnaments: selected,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      backgroundColor: AppColors.surfaceDark,
      borderColor: selected ? ext.gold : null,
      child: _AdaptiveOverlayTile(
        title: Text(
          selected ? '${spec.name} (dipilih)' : spec.name,
          style: theme.textTheme.titleSmall?.copyWith(
            color: selected ? ext.gold : AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '${spec.description}\n'
          '${describeEquipmentStats(spec.bonus)}$range$affinityLine',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        trailing: selected
            ? Icon(Icons.check_circle, color: ext.gold)
            : FilledButton.tonal(
                onPressed: unlocked
                    ? () => onChooseSpecialization(spec.id)
                    : null,
                child: const Text('Pilih'),
              ),
      ),
    );
  }
}

class _AdaptiveOverlayTile extends StatelessWidget {
  const _AdaptiveOverlayTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final Widget title;
  final Widget subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactWidth = constraints.maxWidth < 260 * textScale;
        if (compactWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              title,
              const SizedBox(height: 2),
              subtitle,
              const SizedBox(height: AppSpacing.xs),
              Align(alignment: Alignment.centerRight, child: trailing),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [title, const SizedBox(height: 2), subtitle],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            trailing,
          ],
        );
      },
    );
  }
}

class _HeroProfileBanner extends StatelessWidget {
  const _HeroProfileBanner({required this.snapshot});

  final CharacterSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    final specId = snapshot.specializationId ?? 'base';
    final specVisual = CharacterVisualSpec.resolve(specId);
    final specDef = snapshot.specializations
        .where((sp) => sp.id == snapshot.specializationId)
        .firstOrNull;
    final classTitle = specDef?.name ?? specVisual.title;
    final cp = snapshot.stats != null
        ? HeroShowcaseCard.computeCombatPower(snapshot.stats!)
        : null;

    return Container(
      key: const Key('character_profile_banner'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: specVisual.auraColor.withValues(alpha: 0.55),
          width: 1.25,
        ),
      ),
      child: CampBackdrop(
        borderRadius: AppRadius.md,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.midnightForest.withValues(alpha: 0.45),
                AppColors.midnightForest.withValues(alpha: 0.88),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 4,
            ),
            child: Row(
              children: [
                CharacterIllustration(
                  specializationId: specId,
                  width: 36,
                  height: 40,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: AppSpacing.xs + 2,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            classTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.headingSerif(
                              theme.textTheme.titleSmall,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (cp != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs + 2,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: ext.gold.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                                border: Border.all(
                                  color: ext.gold.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Text(
                                'Combat Power: ${NumberFormatter.format(cp)}',
                                style: AppTypography.numeric(
                                  theme.textTheme.labelSmall,
                                  color: ext.gold,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        specVisual.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: specVisual.auraColor,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
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

class _CombatStatGrid extends StatelessWidget {
  const _CombatStatGrid({required this.stats});

  final CombatStats stats;

  @override
  Widget build(BuildContext context) {
    final ext = EchoesTheme.of(context);
    final primary = <({String label, String value, Color color})>[
      (
        label: 'HP',
        value: NumberFormatter.format(stats.maxHp),
        color: ext.hpBar,
      ),
      (label: 'ATK', value: NumberFormatter.format(stats.atk), color: ext.gold),
      (
        label: 'DEF',
        value: NumberFormatter.format(stats.def),
        color: ext.expBar,
      ),
      (
        label: 'CRIT',
        value: '${(stats.critRate * 100).round()}%',
        color: ext.warning,
      ),
    ];

    return PanelFrame(
      showCornerOrnaments: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      backgroundColor: AppColors.surfaceDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: AppSpacing.xs + 2,
            runSpacing: 2,
            children: [
              for (final e in primary)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs + 2,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: e.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: e.color.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${e.label} ',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: e.color,
                        ),
                      ),
                      Text(
                        e.value,
                        style: AppTypography.numeric(
                          const TextStyle(fontSize: 10),
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            describeCombatStats(stats),
            style: AppTypography.numeric(
              Theme.of(context).textTheme.bodySmall,
              color: AppColors.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
