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

/// Layar karakter: ringkasan stat tempur, pilihan specialization, dan daftar/upgrade skill.
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 580),
          child: PanelFrame(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.md,
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
                              style: theme.textTheme.titleMedium,
                            ),
                            ResourceChip.gold(s.gold),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: onClose,
                        icon: const Icon(Icons.close),
                        tooltip: 'Tutup',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (s.stats != null) ...[
                            const SectionHeader(title: 'Stat Tempur'),
                            _CombatStatGrid(stats: s.stats!),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          const SectionHeader(title: 'Spesialisasi'),
                          if (!s.canChooseSpecialization)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.xs,
                              ),
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
                          const SizedBox(height: AppSpacing.sm),
                          const SectionHeader(title: 'Skill'),
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
      trailing = Text('Lv ${e.level}/${e.definition.maxLevel}');
    }

    return PanelFrame(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      backgroundColor: AppColors.surfaceDark,
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        enabled: e.unlocked,
        title: Text(
          e.unlocked
              ? '${e.definition.name} • Lv ${e.level}/${e.definition.maxLevel}'
              : '${e.definition.name} (Lv ${e.definition.unlockLevel})',
        ),
        subtitle: Text(describeSkill(e.definition, level: e.level)),
        trailing: trailing,
      ),
    );
  }

  Widget _specTile(
    BuildContext context,
    CharacterSnapshot s,
    SpecializationDefinition spec,
  ) {
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
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      backgroundColor: AppColors.surfaceDark,
      borderColor: selected ? ext.gold : null,
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        selected: selected,
        title: Text(selected ? '${spec.name} (dipilih)' : spec.name),
        subtitle: Text(
          '${spec.description}\n'
          '${describeEquipmentStats(spec.bonus)}$range$affinityLine',
        ),
        isThreeLine: true,
        trailing: selected
            ? Icon(Icons.check, color: ext.gold)
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

class _CombatStatGrid extends StatelessWidget {
  const _CombatStatGrid({required this.stats});

  final CombatStats stats;

  @override
  Widget build(BuildContext context) {
    final ext = EchoesTheme.of(context);
    final entries = <({String label, String value, Color color})>[
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
        label: 'ASPD',
        value: '${stats.attackSpeed.toStringAsFixed(2)}/s',
        color: AppColors.textPrimary,
      ),
      (
        label: 'CRIT',
        value: '${(stats.critRate * 100).round()}%',
        color: ext.warning,
      ),
      (
        label: 'CRIT DMG',
        value: '${(stats.critDamage * 100).round()}%',
        color: ext.warning,
      ),
      (
        label: 'HASTE',
        value: '${(stats.skillHaste * 100).round()}%',
        color: ext.rank,
      ),
      (
        label: 'RNG',
        value: stats.attackRange.toStringAsFixed(1),
        color: AppColors.textSecondary,
      ),
    ];

    return PanelFrame(
      showCornerOrnaments: true,
      padding: const EdgeInsets.all(AppSpacing.sm),
      backgroundColor: AppColors.surfaceDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth >= 320 ? 4 : 2;
              const spacing = AppSpacing.xs + 2;
              final cellWidth =
                  (constraints.maxWidth - spacing * (cols - 1)) / cols;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final e in entries)
                    SizedBox(
                      width: cellWidth,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs + 2,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundDark.withValues(
                            alpha: 0.7,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: AppColors.panelInnerBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              e.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              e.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: e.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            describeCombatStats(stats),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
