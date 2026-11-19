import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../core/utils/number_formatter.dart';
import '../../domain/entities/altar_blessing.dart';
import '../../domain/services/altar_service.dart';
import '../../game/hud/inventory_views.dart';
import '../shared/widgets/shared_widgets.dart';

/// Overlay Camp Altar di Town Hub.
/// Memungkinkan pemain mengorbankan Gold untuk memperoleh berkah stat permanen
/// (Might, Vitality, Aegis) dan bonus multiplier perolehan Gold (Fortune).
class AltarOverlay extends StatefulWidget {
  const AltarOverlay({
    super.key,
    required this.characterSnapshot,
    required this.getBalances,
    required this.onUpgradeBlessing,
    required this.onClose,
    this.embedded = false,
  });

  final ValueListenable<CharacterSnapshot> characterSnapshot;
  final Map<String, int> Function() getBalances;
  final AltarUpgradeResult Function(AltarBlessingType type) onUpgradeBlessing;
  final VoidCallback onClose;
  final bool embedded;

  @override
  State<AltarOverlay> createState() => _AltarOverlayState();
}

class _AltarOverlayState extends State<AltarOverlay> {
  static const _service = AltarService();

  String? _feedbackMessage;
  bool _feedbackIsError = false;
  bool _busy = false;

  void _handleUpgrade(AltarBlessingType type) {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final res = widget.onUpgradeBlessing(type);
      final def = _service.definitions[type];
      final blessingName = def?.name ?? 'Berkah';

      setState(() {
        if (res.isSuccess) {
          _feedbackIsError = false;
          _feedbackMessage =
              'Sukses! $blessingName berhasil ditingkatkan ke Lv. ${res.newLevel}.';
        } else {
          _feedbackIsError = true;
          switch (res.status) {
            case AltarUpgradeStatus.maxLevelReached:
              _feedbackMessage =
                  '$blessingName sudah mencapai level maksimum (20).';
            case AltarUpgradeStatus.insufficientGold:
              _feedbackMessage =
                  'Gold tidak mencukupi untuk mempersembahkan berkah.';
            case AltarUpgradeStatus.unknownBlessing:
            default:
              _feedbackMessage = 'Gagal meningkatkan berkah altar.';
          }
        }
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final panel = PanelFrame(
      showCornerOrnaments: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm + 2,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: ValueListenableBuilder<CharacterSnapshot>(
        valueListenable: widget.characterSnapshot,
        builder: (context, char, _) {
          final balances = widget.getBalances();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(char.gold),
              if (_feedbackMessage != null) ...[
                const SizedBox(height: AppSpacing.xs),
                _buildFeedbackBanner(),
              ],
              const SizedBox(height: AppSpacing.xs),
              _buildSummaryBanner(balances),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ListView(
                  children: [
                    for (final type in AltarBlessingType.values)
                      _buildBlessingCard(
                        type: type,
                        balances: balances,
                        playerGold: char.gold,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
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
            constraints: const BoxConstraints(maxWidth: 540),
            child: panel,
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
          child: panel,
        ),
      ),
    );
  }

  Widget _buildHeader(int playerGold) {
    return Row(
      children: [
        const Icon(Icons.auto_awesome, color: AppColors.antiqueGold, size: 20),
        const SizedBox(width: AppSpacing.sm),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Camp Altar',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Persembahkan Gold untuk berkah permanen',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
              ),
            ],
          ),
        ),
        ResourceChip.gold(playerGold),
        if (!widget.embedded) ...[
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            key: const Key('altar_close_button'),
            icon: const Icon(Icons.close, color: AppColors.textSecondary),
            splashRadius: 18,
            onPressed: widget.onClose,
            tooltip: 'Tutup Altar',
          ),
        ],
      ],
    );
  }

  Widget _buildFeedbackBanner() {
    final color = _feedbackIsError ? AppColors.danger : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            _feedbackIsError ? Icons.error_outline : Icons.check_circle_outline,
            color: color,
            size: 14,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              _feedbackMessage!,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _feedbackMessage = null),
            child: Icon(Icons.close, color: color, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBanner(Map<String, int> balances) {
    final statBonus = _service.getAltarStatBonus(balances);
    final goldBonus = _service.getGoldBonusPercent(balances);

    final hpText = statBonus.hp > 0 ? '+${statBonus.hp.round()} HP' : '0 HP';
    final atkText = statBonus.atk > 0
        ? '+${statBonus.atk.round()} ATK'
        : '0 ATK';
    final defText = statBonus.def > 0
        ? '+${statBonus.def.round()} DEF'
        : '0 DEF';
    final goldText = goldBonus > 0
        ? '+${(goldBonus * 100).round()}% Gold'
        : '0% Gold';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.panelDark.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryChip(Icons.favorite, const Color(0xFF66BB6A), hpText),
          _buildSummaryChip(
            Icons.local_fire_department,
            const Color(0xFFEF5350),
            atkText,
          ),
          _buildSummaryChip(Icons.shield, const Color(0xFF42A5F5), defText),
          _buildSummaryChip(Icons.stars, AppColors.antiqueGold, goldText),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(IconData icon, Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBlessingCard({
    required AltarBlessingType type,
    required Map<String, int> balances,
    required int playerGold,
  }) {
    final def = _service.definitions[type]!;
    final level = _service.getBlessingLevel(type, balances);
    final isMax = level >= def.maxLevel;
    final cost = _service.getUpgradeCost(type, level);
    final canAfford = cost != null && playerGold >= cost;

    final IconData icon;
    final Color accentColor;
    switch (type) {
      case AltarBlessingType.might:
        icon = Icons.local_fire_department;
        accentColor = const Color(0xFFEF5350);
      case AltarBlessingType.vitality:
        icon = Icons.favorite;
        accentColor = const Color(0xFF66BB6A);
      case AltarBlessingType.aegis:
        icon = Icons.shield;
        accentColor = const Color(0xFF42A5F5);
      case AltarBlessingType.fortune:
        icon = Icons.stars;
        accentColor = AppColors.antiqueGold;
    }

    final currentEffect = level > 0
        ? def.describeEffectAt(level)
        : 'Belum aktif';
    final nextEffect = !isMax ? def.describeEffectAt(level + 1) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.panelElevated.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isMax
              ? AppColors.antiqueGold.withValues(alpha: 0.8)
              : accentColor.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs + 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      def.name,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      def.description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: isMax
                      ? AppColors.antiqueGold.withValues(alpha: 0.2)
                      : AppColors.panelDark,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: isMax
                        ? AppColors.antiqueGold
                        : AppColors.panelBorder,
                  ),
                ),
                child: Text(
                  'Lv. $level/${def.maxLevel}',
                  style: TextStyle(
                    color: isMax
                        ? AppColors.antiqueGold
                        : AppColors.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: level / def.maxLevel,
              backgroundColor: AppColors.panelDark,
              valueColor: AlwaysStoppedAnimation<Color>(
                isMax ? AppColors.antiqueGold : accentColor,
              ),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Efek: $currentEffect',
                      style: TextStyle(
                        color: level > 0
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (nextEffect != null)
                      Text(
                        'Lv. ${level + 1} ➔ $nextEffect',
                        style: TextStyle(
                          color: accentColor.withValues(alpha: 0.9),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _buildUpgradeButton(
                type: type,
                isMax: isMax,
                cost: cost,
                canAfford: canAfford,
                accentColor: accentColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeButton({
    required AltarBlessingType type,
    required bool isMax,
    required int? cost,
    required bool canAfford,
    required Color accentColor,
  }) {
    if (isMax) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.antiqueGold.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: AppColors.antiqueGold.withValues(alpha: 0.5),
          ),
        ),
        child: const Text(
          'MAKSIMUM',
          style: TextStyle(
            color: AppColors.antiqueGold,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    final enabled = canAfford && !_busy;
    return ElevatedButton(
      key: Key('altar_upgrade_${type.name}'),
      onPressed: enabled ? () => _handleUpgrade(type) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled ? accentColor : AppColors.panelDark,
        foregroundColor: enabled ? Colors.black : AppColors.textMuted,
        disabledBackgroundColor: AppColors.panelDark,
        disabledForegroundColor: AppColors.textMuted,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: AppSpacing.xs + 2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          side: BorderSide(
            color: enabled
                ? accentColor
                : (cost != null && !canAfford
                      ? AppColors.danger.withValues(alpha: 0.5)
                      : AppColors.panelBorder),
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.upgrade, size: 14),
          const SizedBox(width: 3),
          const Icon(
            Icons.monetization_on,
            size: 13,
            color: AppColors.antiqueGold,
          ),
          const SizedBox(width: 2),
          Text(
            NumberFormatter.format(cost ?? 0),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: enabled
                  ? Colors.black
                  : (!canAfford ? AppColors.danger : AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
