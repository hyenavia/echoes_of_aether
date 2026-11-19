import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../domain/entities/gacha_config.dart';
import '../../domain/entities/item_definition.dart';
import '../../domain/entities/specialization.dart';
import '../../domain/services/gacha_service.dart';
import '../shared/widgets/shared_widgets.dart';
import 'boss_events_overlay.dart';

enum _GachaTab { classBanner, weaponBanner, sanctuary }

/// Overlay fungsional untuk sistem Gacha (Class Awakening, Mythical Armory,
/// dan Toko Penukaran Sanctuary) pada M15 Stage 5.
class GachaOverlay extends StatefulWidget {
  const GachaOverlay({
    super.key,
    required this.gachaService,
    required this.aetherShards,
    required this.soulPrisms,
    required this.pityStates,
    required this.unlockedSpecializations,
    required this.nowMs,
    required this.onPull,
    required this.onExchangeWeapon,
    required this.onExchangeClass,
    required this.onClose,
  });

  final GachaService gachaService;
  final int aetherShards;
  final int soulPrisms;
  final Map<String, GachaPityState> pityStates;
  final Set<String> unlockedSpecializations;
  final int nowMs;
  final Future<GachaPullSessionResult> Function(
    GachaBannerType bannerType,
    int count,
  )
  onPull;
  final Future<SanctuaryExchangeResult> Function(String weaponId)
  onExchangeWeapon;
  final Future<SanctuaryExchangeResult> Function(String classId)
  onExchangeClass;
  final VoidCallback onClose;

  @override
  State<GachaOverlay> createState() => _GachaOverlayState();
}

class _GachaOverlayState extends State<GachaOverlay> {
  _GachaTab _currentTab = _GachaTab.classBanner;
  bool _busy = false;
  String? _feedbackMessage;
  bool _feedbackIsError = false;

  GachaPityState _pityFor(GachaBannerType type) {
    return widget.pityStates[type.idString] ??
        GachaPityState(bannerType: type.idString);
  }

  Future<void> _handlePull(GachaBannerType bannerType, int count) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _feedbackMessage = null;
    });
    try {
      final result = await widget.onPull(bannerType, count);
      if (!mounted) return;
      if (result.isSuccess) {
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => _GachaResultDialog(
            result: result,
            items: widget.gachaService.items,
            specializations: widget.gachaService.specializations,
          ),
        );
      } else {
        setState(() {
          _feedbackIsError = true;
          _feedbackMessage = switch (result.status) {
            GachaPullStatus.insufficientAetherShards =>
              'Aether Shard tidak mencukupi untuk menarik ${count}x.',
            GachaPullStatus.inventoryFull => 'Kapasitas tas perlengkapan penuh! Kosongkan tas terlebih dahulu.',
            GachaPullStatus.bannerNotFound => 'Banner tidak ditemukan.',
            GachaPullStatus.invalidCount => 'Jumlah pull tidak valid.',
            GachaPullStatus.success => null,
          };
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleExchangeWeapon(String weaponId) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _feedbackMessage = null;
    });
    try {
      final result = await widget.onExchangeWeapon(weaponId);
      if (!mounted) return;
      final weaponName = widget.gachaService.items[weaponId]?.name ?? weaponId;
      setState(() {
        if (result.isSuccess) {
          _feedbackIsError = false;
          _feedbackMessage =
              'Berhasil menukar ${result.soulPrismSpent} Soul Prism dengan $weaponName!';
        } else {
          _feedbackIsError = true;
          _feedbackMessage = switch (result.status) {
            SanctuaryExchangeStatus.insufficientSoulPrisms =>
              'Soul Prism tidak mencukupi.',
            SanctuaryExchangeStatus.inventoryFull =>
              'Tas perlengkapan penuh! Kosongkan slot terlebih dahulu.',
            SanctuaryExchangeStatus.alreadyOwned => 'Item sudah dimiliki.',
            SanctuaryExchangeStatus.invalidTarget =>
              'Target penukaran tidak valid.',
            SanctuaryExchangeStatus.success => null,
          };
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleExchangeClass(String classId) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _feedbackMessage = null;
    });
    try {
      final result = await widget.onExchangeClass(classId);
      if (!mounted) return;
      final className =
          widget.gachaService.specializations[classId]?.name ?? classId;
      setState(() {
        if (result.isSuccess) {
          _feedbackIsError = false;
          _feedbackMessage =
              'Berhasil membuka Class $className dengan ${result.soulPrismSpent} Soul Prism!';
        } else {
          _feedbackIsError = true;
          _feedbackMessage = switch (result.status) {
            SanctuaryExchangeStatus.insufficientSoulPrisms =>
              'Soul Prism tidak mencukupi.',
            SanctuaryExchangeStatus.alreadyOwned =>
              'Class $className sudah Anda miliki.',
            SanctuaryExchangeStatus.inventoryFull => 'Tas penuh.',
            SanctuaryExchangeStatus.invalidTarget =>
              'Target penukaran tidak valid.',
            SanctuaryExchangeStatus.success => null,
          };
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);

    return Material(
      color: Colors.black54,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
              child: PanelFrame(
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
                    _buildHeader(theme, ext),
                    const SizedBox(height: AppSpacing.xs),
                    _buildTabSelector(),
                    if (_feedbackMessage != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      _buildFeedbackBanner(theme, ext),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: switch (_currentTab) {
                        _GachaTab.classBanner => _buildBannerView(
                          theme,
                          ext,
                          GachaBannerType.classBanner,
                        ),
                        _GachaTab.weaponBanner => _buildBannerView(
                          theme,
                          ext,
                          GachaBannerType.weaponBanner,
                        ),
                        _GachaTab.sanctuary => _buildSanctuaryView(theme, ext),
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, EchoesThemeExtension ext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_motion, color: ext.gold, size: 22),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Altar Pemanggilan',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ext.gold,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: widget.onClose,
              visualDensity: VisualDensity.compact,
              tooltip: 'Tutup',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ResourceChip.aetherShard(
              widget.aetherShards,
              key: const Key('gacha_shard_balance'),
            ),
            Container(
              key: const Key('gacha_prism_balance'),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs + 2,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: ext.colorForRarity(ItemRarity.mythical),
                ),
              ),
              child: Text(
                'Prism: ${NumberFormatter.format(widget.soulPrisms)}',
                style: AppTypography.numeric(
                  theme.textTheme.labelSmall?.copyWith(
                    color: ext.colorForRarity(ItemRarity.mythical),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabSelector() {
    return SegmentedButton<_GachaTab>(
      segments: const [
        ButtonSegment<_GachaTab>(
          value: _GachaTab.classBanner,
          label: Text('Class', overflow: TextOverflow.ellipsis),
        ),
        ButtonSegment<_GachaTab>(
          value: _GachaTab.weaponBanner,
          label: Text('Senjata', overflow: TextOverflow.ellipsis),
        ),
        ButtonSegment<_GachaTab>(
          value: _GachaTab.sanctuary,
          label: Text('Sanctuary', overflow: TextOverflow.ellipsis),
        ),
      ],
      selected: {_currentTab},
      onSelectionChanged: (next) {
        setState(() {
          _currentTab = next.first;
          _feedbackMessage = null;
        });
      },
    );
  }

  Widget _buildFeedbackBanner(ThemeData theme, EchoesThemeExtension ext) {
    final color = _feedbackIsError ? theme.colorScheme.error : ext.success;
    return Container(
      key: const Key('gacha_feedback'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        _feedbackMessage!,
        style: theme.textTheme.bodySmall?.copyWith(color: color),
      ),
    );
  }

  Widget _buildBannerView(
    ThemeData theme,
    EchoesThemeExtension ext,
    GachaBannerType bannerType,
  ) {
    final pity = _pityFor(bannerType);
    final info = widget.gachaService.getActiveBannerInfo(
      bannerType: bannerType,
      nowMs: widget.nowMs,
      pityStates: widget.pityStates,
    );

    final isClassBanner = bannerType == GachaBannerType.classBanner;
    final featuredSpec = isClassBanner
        ? widget.gachaService.specializations[info.featuredId]
        : null;
    final featuredItem = !isClassBanner
        ? widget.gachaService.items[info.featuredId]
        : null;
    final featuredName =
        featuredSpec?.name ?? featuredItem?.name ?? info.featuredId;
    final featuredDesc = isClassBanner
        ? (featuredSpec?.description ?? '')
        : (featuredItem?.equipment?.resonanceDescription ?? '');
    final spritePath = !isClassBanner
        ? ItemSpriteRegistry.spriteForItem(info.featuredId)
        : null;

    final gachaCfg = widget.gachaService.gachaConfig;
    final singleCost = gachaCfg.costPerPull;
    final tenCost = gachaCfg.costPerTenPull;
    final canPull1 = !_busy && widget.aetherShards >= singleCost;
    final canPull10 = !_busy && widget.aetherShards >= tenCost;
    final remaining = Duration(seconds: info.remainingSeconds(widget.nowMs));
    final countdown = BossEventsOverlay.formatCountdown(remaining);
    final mythicalColor = ext.colorForRarity(ItemRarity.mythical);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PanelFrame(
            padding: const EdgeInsets.all(AppSpacing.md),
            backgroundColor: AppColors.surfaceDark,
            borderColor: mythicalColor.withValues(alpha: 0.75),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      info.banner.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: mythicalColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const RarityLabel(
                      rarity: ItemRarity.mythical,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Pergantian banner: $countdown',
                  key: const Key('gacha_banner_countdown'),
                  style: AppTypography.numeric(
                    theme.textTheme.labelSmall,
                    color: AppColors.textSecondary,
                  ),
                ),
                const Divider(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.panelDark,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: mythicalColor),
                      ),
                      child: spritePath != null
                          ? Padding(
                              padding: const EdgeInsets.all(6),
                              child: Image.asset(
                                spritePath,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.none,
                                errorBuilder: (_, _, _) => Icon(
                                  Icons.auto_awesome,
                                  color: mythicalColor,
                                ),
                              ),
                            )
                          : Icon(
                              isClassBanner ? Icons.person_pin : Icons.hardware,
                              color: mythicalColor,
                              size: 26,
                            ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rate-Up: $featuredName',
                            key: const Key('gacha_featured_name'),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (featuredDesc.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              featuredDesc,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          if (isClassBanner &&
                              widget.unlockedSpecializations.contains(
                                info.featuredId,
                              )) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Sudah dimiliki (Duplikat -> +1 Soul Prism)',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: ext.gold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Pity: ${pity.pullCount}/${info.banner.hardPity}',
                      key: const Key('gacha_pity_counter'),
                      style: AppTypography.numeric(
                        theme.textTheme.labelMedium?.copyWith(
                          color: ext.gold,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      'Base Rate: ${(info.banner.baseRate * 100).toStringAsFixed(1)}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (pity.isGuaranteed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: ext.success.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          border: Border.all(color: ext.success),
                        ),
                        child: Text(
                          '50/50 Guaranteed!',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: ext.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  key: const Key('gacha_pull_1x'),
                  label: 'Tarik 1x ($singleCost)',
                  icon: Icons.star_outline,
                  expand: true,
                  onPressed: canPull1 ? () => _handlePull(bannerType, 1) : null,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: PrimaryButton(
                  key: const Key('gacha_pull_10x'),
                  label: 'Tarik 10x ($tenCost)',
                  icon: Icons.auto_awesome,
                  expand: true,
                  onPressed: canPull10
                      ? () => _handlePull(bannerType, 10)
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSanctuaryView(ThemeData theme, EchoesThemeExtension ext) {
    final exchange = widget.gachaService.gachaConfig.sanctuaryExchange;
    final mythicalColor = ext.colorForRarity(ItemRarity.mythical);
    final mythicalWeapons =
        widget.gachaService.items.values
            .where((i) => i.isEquipment && i.rarity == ItemRarity.mythical)
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    final mythicalClasses =
        widget.gachaService.specializations.values
            .where((s) => s.rarity == ItemRarity.mythical)
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));

    return ListView(
      children: [
        SectionHeader(
          title: 'Senjata Signature (${exchange.weaponCost} Soul Prism)',
          useSerif: true,
        ),
        for (final w in mythicalWeapons)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: PanelFrame(
              padding: const EdgeInsets.all(AppSpacing.sm),
              backgroundColor: AppColors.surfaceDark,
              borderColor: mythicalColor.withValues(alpha: 0.45),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          w.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: mythicalColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (w.equipment?.resonanceDescription != null)
                          Text(
                            w.equipment!.resonanceDescription!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  FilledButton(
                    key: Key('sanctuary_weapon_${w.id}'),
                    onPressed:
                        !_busy && widget.soulPrisms >= exchange.weaponCost
                        ? () => _handleExchangeWeapon(w.id)
                        : null,
                    child: Text('Tukar (${exchange.weaponCost})'),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        SectionHeader(
          title: 'Class Mythical (${exchange.classCost} Soul Prism)',
          useSerif: true,
        ),
        for (final c in mythicalClasses)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: PanelFrame(
              padding: const EdgeInsets.all(AppSpacing.sm),
              backgroundColor: AppColors.surfaceDark,
              borderColor: mythicalColor.withValues(alpha: 0.45),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: mythicalColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          c.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  if (widget.unlockedSpecializations.contains(c.id))
                    const LockedBadge(label: 'Sudah Dimiliki')
                  else
                    FilledButton(
                      key: Key('sanctuary_class_${c.id}'),
                      onPressed:
                          !_busy && widget.soulPrisms >= exchange.classCost
                          ? () => _handleExchangeClass(c.id)
                          : null,
                      child: Text('Tukar (${exchange.classCost})'),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _GachaResultDialog extends StatelessWidget {
  const _GachaResultDialog({
    required this.result,
    required this.items,
    required this.specializations,
  });

  final GachaPullSessionResult result;
  final Map<String, ItemDefinition> items;
  final Map<String, SpecializationDefinition> specializations;

  String _nameFor(GachaPullResult pull) {
    if (pull.isSpecialization) {
      return specializations[pull.itemId]?.name ?? pull.itemId;
    }
    return items[pull.itemId]?.name ?? pull.itemId;
  }

  ItemRarity _rarityFor(GachaPullResult pull) {
    if (pull.isMythical) return ItemRarity.mythical;
    if (pull.isSpecialization) {
      return specializations[pull.itemId]?.rarity ?? ItemRarity.legendary;
    }
    return items[pull.itemId]?.rarity ?? ItemRarity.rare;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = EchoesTheme.of(context);

    return AlertDialog(
      title: Text(
        'Hasil Pemanggilan (${result.pulls.length}x)',
        style: theme.textTheme.titleMedium?.copyWith(
          color: ext.gold,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: 420,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: 1.0),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(scale: scale, child: child);
          },
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (result.soulPrismGranted > 0) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: ext.gold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: ext.gold),
                    ),
                    child: Text(
                      'Duplikat Class dikonversi menjadi +${result.soulPrismGranted} Soul Prism!',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: ext.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                for (final pull in result.pulls)
                  Builder(
                    builder: (context) {
                      final rarity = _rarityFor(pull);
                      final color = ext.colorForRarity(rarity);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: PanelFrame(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          backgroundColor: AppColors.surfaceDark,
                          borderColor: color,
                          child: Row(
                            children: [
                              RarityLabel(rarity: rarity, compact: true),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  _nameFor(pull),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (pull.isDuplicate)
                                Text(
                                  '+1 Prism',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: ext.gold,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              else if (pull.isFeatured)
                                Text(
                                  'Featured',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: ext.success,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        FilledButton(
          key: const Key('gacha_result_close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}
