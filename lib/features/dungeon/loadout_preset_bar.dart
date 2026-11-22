import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../../domain/entities/loadout_preset.dart';
import '../shared/widgets/shared_widgets.dart';

/// Bar ringkas untuk memilih, menyimpan, dan menerapkan maksimal 3 preset
/// kombinasi specialization + perlengkapan di EquipmentOverlay.
class LoadoutPresetBar extends StatefulWidget {
  const LoadoutPresetBar({
    super.key,
    required this.presets,
    this.specializationNames = const {},
    this.onSavePreset,
    this.onApplyPreset,
  });

  final List<LoadoutPreset> presets;
  final Map<String, String> specializationNames;
  final void Function(int slotIndex)? onSavePreset;
  final void Function(int slotIndex)? onApplyPreset;

  @override
  State<LoadoutPresetBar> createState() => _LoadoutPresetBarState();
}

class _LoadoutPresetBarState extends State<LoadoutPresetBar> {
  int _selectedSlot = 0;

  LoadoutPreset? _presetFor(int slotIndex) {
    for (final preset in widget.presets) {
      if (preset.slotIndex == slotIndex) return preset;
    }
    return null;
  }

  String _describePreset(LoadoutPreset? preset) {
    if (preset == null || preset.isEmpty) {
      return 'Slot kosong — tekan Simpan untuk menyimpan build saat ini.';
    }
    final specId = preset.specializationId;
    final specLabel = (specId == null || specId.trim().isEmpty)
        ? 'Tanpa Class'
        : (widget.specializationNames[specId] ?? specId);
    final gearCount = preset.equipmentInstanceIds.length;
    return '$specLabel • $gearCount Gear tersimpan';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);
    final selectedPreset = _presetFor(_selectedSlot);
    final hasSavedData = selectedPreset != null && !selectedPreset.isEmpty;

    return PanelFrame(
      key: const Key('loadout_preset_bar'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      backgroundColor: AppColors.surfaceDark,
      borderColor: ext.panelInnerBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.bookmarks_outlined, size: 16, color: ext.gold),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Preset Build',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: ext.gold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              for (var i = 0; i < LoadoutPreset.maxSlots; i++) ...[
                Expanded(
                  child: _SlotChip(
                    key: Key('loadout_preset_slot_$i'),
                    label: 'Preset ${i + 1}',
                    isSelected: _selectedSlot == i,
                    isFilled: !(_presetFor(i)?.isEmpty ?? true),
                    accentColor: ext.gold,
                    onTap: () => setState(() => _selectedSlot = i),
                  ),
                ),
                if (i < LoadoutPreset.maxSlots - 1)
                  const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _describePreset(selectedPreset),
            key: const Key('loadout_preset_summary'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: hasSavedData ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  key: const Key('loadout_preset_save_button'),
                  label: 'Simpan',
                  icon: Icons.save_outlined,
                  expand: true,
                  onPressed: widget.onSavePreset != null
                      ? () => widget.onSavePreset!(_selectedSlot)
                      : null,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: PrimaryButton(
                  key: const Key('loadout_preset_apply_button'),
                  label: 'Pakai',
                  icon: Icons.flash_on_outlined,
                  expand: true,
                  onPressed: hasSavedData && widget.onApplyPreset != null
                      ? () => widget.onApplyPreset!(_selectedSlot)
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.isFilled,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isFilled;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.16)
              : AppColors.midnightForest,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isSelected ? accentColor : AppColors.panelInnerBorder,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isFilled ? Icons.bookmark : Icons.bookmark_border,
              size: 13,
              color: isFilled
                  ? accentColor
                  : (isSelected ? AppColors.textPrimary : AppColors.textMuted),
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected
                      ? accentColor
                      : (isFilled
                            ? AppColors.textPrimary
                            : AppColors.textMuted),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
