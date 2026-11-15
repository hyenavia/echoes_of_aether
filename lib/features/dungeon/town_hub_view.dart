import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/theme/echoes_theme.dart';
import '../../core/utils/number_formatter.dart';
import '../../domain/entities/cycle_progress.dart';
import '../../domain/entities/difficulty_config.dart';
import '../../domain/entities/dungeon_definition.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/entities/farming_config.dart';
import '../../domain/entities/game_settings.dart';
import '../../domain/entities/item_definition.dart';
import '../../domain/entities/offline_activity.dart';
import '../../domain/entities/player_character.dart';
import '../../domain/entities/player_save_snapshot.dart';
import '../../domain/entities/shop_config.dart';
import '../../domain/services/difficulty_service.dart';
import '../../domain/services/dungeon_progression_service.dart';
import '../../domain/services/event_shop_service.dart';
import '../../domain/services/shop_service.dart';
import '../../game/hud/inventory_views.dart';
import '../shared/widgets/shared_widgets.dart';
import 'character_overlay.dart';
import 'equipment_overlay.dart';
import 'inventory_overlay.dart';
import 'settings_overlay.dart';
import 'shop_overlay.dart';
import 'town_top_bar.dart';

/// Tab navigasi bawah pada Town Hub (M11 Stage 2).
enum TownTab { adventure, hero, bag, shop, settings }

/// Hub Town/Camp sederhana (MVP M5) sebagai titik masuk/keluar dungeon serta
/// akses Tas, Perlengkapan, dan Karakter sebelum memulai ekspedisi.
class TownHubView extends StatefulWidget {
  const TownHubView({
    super.key,
    required this.character,
    required this.views,
    required this.items,
    required this.dungeonProgress,
    required this.dungeonDefinition,
    required this.onEnterDungeon,
    required this.onEquip,
    required this.onUnequip,
    required this.onChooseSpecialization,
    this.onUpgradeSkill,
    this.settings,
    this.onSettingsChanged,
    this.onTestSfx,
    this.offlineActivity = const OfflineActivitySnapshot.paused(),
    this.availableDungeons = const {},
    this.dungeonProgresses = const {},
    this.cycleProgress = const CycleProgress(),
    this.difficultyConfig = const DifficultyConfig(),
    this.farmingConfig = const FarmingConfig(),
    this.consecutiveDefeats = const {},
    this.lastFailedDungeonId,
    this.selectedDungeonId,
    this.onSelectDungeon,
    this.onEnterDungeonById,
    this.onSwitchCycleRank,
    this.onSelectPauseOffline,
    this.onSelectAutoFarming,
    this.shopCatalog,
    this.shopService,
    this.shopContext,
    this.onShopBuy,
    this.onShopSellEquipment,
    this.onShopSellMaterialBulk,
    this.onShopSellBatch,
    this.eventShopData,
    this.onEventShopBuy,
    this.aetherShard = 0,
    this.onOpenBossEvents,
    this.onRequestNotificationPermission,
  });

  static const int underLevelWarningDelta = 5;

  final PlayerCharacter character;
  final InventoryViews views;
  final Map<String, ItemDefinition> items;
  final DungeonProgressSnapshot dungeonProgress;
  final DungeonDefinition? dungeonDefinition;
  final VoidCallback onEnterDungeon;
  final void Function(String instanceId) onEquip;
  final void Function(EquipmentSlot slot) onUnequip;
  final void Function(String specializationId) onChooseSpecialization;
  final void Function(String skillId)? onUpgradeSkill;
  final ValueListenable<GameSettingsData>? settings;
  final void Function(GameSettingsData next)? onSettingsChanged;
  final VoidCallback? onTestSfx;
  final OfflineActivitySnapshot offlineActivity;
  final Map<String, DungeonDefinition> availableDungeons;
  final Map<String, DungeonProgressSnapshot> dungeonProgresses;
  final CycleProgress cycleProgress;
  final DifficultyConfig difficultyConfig;
  final FarmingConfig farmingConfig;
  final Map<String, int> consecutiveDefeats;
  final String? lastFailedDungeonId;
  final String? selectedDungeonId;
  final void Function(String dungeonId)? onSelectDungeon;
  final void Function(String dungeonId)? onEnterDungeonById;
  final void Function(int targetRank)? onSwitchCycleRank;
  final VoidCallback? onSelectPauseOffline;
  final void Function(String dungeonId)? onSelectAutoFarming;
  final ShopCatalog? shopCatalog;
  final ShopService? shopService;
  final ShopPlayerContext? shopContext;
  final Future<ShopBuyResult> Function(String entryId)? onShopBuy;
  final Future<ShopSellResult> Function(String instanceId)? onShopSellEquipment;
  final Future<ShopSellResult> Function(String itemId, int quantity)?
  onShopSellMaterialBulk;
  final Future<ShopSellResult> Function(
    List<String> equipmentInstanceIds,
    Map<String, int> materialQuantities,
  )?
  onShopSellBatch;
  final EventShopViewData? eventShopData;
  final Future<EventShopBuyResult> Function(String entryId)? onEventShopBuy;
  final int aetherShard;
  final VoidCallback? onOpenBossEvents;
  final Future<bool> Function()? onRequestNotificationPermission;

  @override
  State<TownHubView> createState() => _TownHubViewState();
}

class _TownHubViewState extends State<TownHubView> {
  TownTab _selectedTab = TownTab.adventure;
  int _bagSubTab = 0;

  void _selectTab(TownTab tab) {
    setState(() {
      _selectedTab = tab;
    });
  }

  void _openBagSubTab(int subTab) {
    setState(() {
      _bagSubTab = subTab;
      _selectedTab = TownTab.bag;
    });
  }

  List<DungeonDefinition> _resolvedCatalog() {
    final list = widget.availableDungeons.isNotEmpty
        ? widget.availableDungeons.values.toList()
        : <DungeonDefinition>[
            if (widget.dungeonDefinition != null) widget.dungeonDefinition!,
          ];
    list.sort((a, b) {
      final orderCmp = a.order.compareTo(b.order);
      return orderCmp != 0 ? orderCmp : a.id.compareTo(b.id);
    });
    return list;
  }

  Map<String, DungeonProgressSnapshot> _buildProgressMap() {
    final map = <String, DungeonProgressSnapshot>{...widget.dungeonProgresses};
    if (widget.dungeonProgress.currentDungeonId.isNotEmpty) {
      map[widget.dungeonProgress.currentDungeonId] = widget.dungeonProgress;
    } else if (widget.dungeonDefinition != null) {
      map.putIfAbsent(
        widget.dungeonDefinition!.id,
        () => widget.dungeonProgress,
      );
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dungeon = widget.dungeonDefinition;
    final catalog = _resolvedCatalog();
    final progressMap = _buildProgressMap();
    final progression = DungeonProgressionService(widget.difficultyConfig);
    final totalRooms = dungeon?.roomOrder.length ?? 0;
    final clearedCount = widget.dungeonProgress.highestClearedRoomIndex >= 0
        ? (widget.dungeonProgress.highestClearedRoomIndex + 1).clamp(
            0,
            totalRooms > 0 ? totalRooms : 999,
          )
        : 0;
    final selectedRecLevel = dungeon != null
        ? progression.recommendedLevel(
            dungeon,
            widget.cycleProgress.ascensionRank,
          )
        : 1;
    final selectedReqLevel = dungeon != null
        ? progression.requiredLevel(dungeon, widget.cycleProgress.ascensionRank)
        : 1;
    final selectedUnlockedNoLevel =
        dungeon != null &&
        progression.isUnlocked(
          dungeon,
          widget.cycleProgress,
          progressMap,
          allDungeons: catalog,
        );
    final deathLoopSuggestion = progression.evaluateDeathLoop(
      dungeons: catalog,
      cycle: widget.cycleProgress,
      progresses: progressMap,
      consecutiveDefeats: widget.consecutiveDefeats,
      suggestAfter: widget.farmingConfig.deathLoopSuggestAfter,
      selectedDungeonId: widget.selectedDungeonId ?? dungeon?.id,
      lastFailedDungeonId: widget.lastFailedDungeonId,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: ValueListenableBuilder<CharacterSnapshot>(
              valueListenable: widget.views.characterView,
              builder: (context, charSnap, _) => TownTopBar(
                level: charSnap.level,
                currentExp: widget.character.currentExp,
                expToNext: widget.character.expToNext,
                gold: widget.character.gold,
                aetherShard: widget.aetherShard,
                ascensionRank: widget.cycleProgress.ascensionRank,
                specializationName: widget.character.specialization?.name,
                maxHp: widget.character.stats.maxHp,
              ),
            ),
          ),
        ),
        Expanded(
          child: switch (_selectedTab) {
            TownTab.adventure => _buildAdventureBody(
              context,
              theme,
              dungeon: dungeon,
              catalog: catalog,
              progressMap: progressMap,
              progression: progression,
              totalRooms: totalRooms,
              clearedCount: clearedCount,
              selectedRecLevel: selectedRecLevel,
              selectedReqLevel: selectedReqLevel,
              selectedUnlockedNoLevel: selectedUnlockedNoLevel,
              deathLoopSuggestion: deathLoopSuggestion,
            ),
            TownTab.hero => CharacterOverlay(
              snapshot: widget.views.characterView,
              onChooseSpecialization: widget.onChooseSpecialization,
              onUpgradeSkill: widget.onUpgradeSkill,
              onClose: () => _selectTab(TownTab.adventure),
            ),
            TownTab.bag => _buildBagTabBody(context),
            TownTab.shop =>
              (widget.shopCatalog != null &&
                      widget.shopService != null &&
                      widget.shopContext != null &&
                      widget.onShopBuy != null &&
                      widget.onShopSellEquipment != null &&
                      widget.onShopSellMaterialBulk != null)
                  ? ShopOverlay(
                      catalog: widget.shopCatalog!,
                      items: widget.items,
                      dungeons: widget.availableDungeons,
                      shopService: widget.shopService!,
                      playerContext: widget.shopContext!,
                      playerGold: widget.character.gold,
                      views: widget.views,
                      onBuy: widget.onShopBuy!,
                      onSellEquipment: widget.onShopSellEquipment!,
                      onSellMaterialBulk: widget.onShopSellMaterialBulk!,
                      onSellBatch: widget.onShopSellBatch,
                      eventShopData: widget.eventShopData,
                      onBuyEventItem: widget.onEventShopBuy,
                      onClose: () => _selectTab(TownTab.adventure),
                    )
                  : const Center(
                      child: PanelFrame(child: Text('Toko belum tersedia.')),
                    ),
            TownTab.settings =>
              (widget.settings != null && widget.onSettingsChanged != null)
                  ? SettingsOverlay(
                      settings: widget.settings!,
                      onChanged: widget.onSettingsChanged!,
                      onTestSfx: widget.onTestSfx,
                      onRequestNotificationPermission:
                          widget.onRequestNotificationPermission,
                      onClose: () => _selectTab(TownTab.adventure),
                    )
                  : const Center(
                      child: PanelFrame(
                        child: Text('Pengaturan belum tersedia.'),
                      ),
                    ),
          },
        ),
        EchoesBottomNavigation(
          key: const Key('town_bottom_nav'),
          currentIndex: _selectedTab.index,
          onSelected: (index) => _selectTab(TownTab.values[index]),
          items: const [
            EchoesNavItem(
              label: 'Adventure',
              icon: Icons.explore_outlined,
              activeIcon: Icons.explore,
            ),
            EchoesNavItem(
              label: 'Hero',
              icon: Icons.person_outline,
              activeIcon: Icons.person,
            ),
            EchoesNavItem(
              label: 'Bag',
              icon: Icons.inventory_2_outlined,
              activeIcon: Icons.inventory_2,
            ),
            EchoesNavItem(
              label: 'Shop',
              icon: Icons.storefront_outlined,
              activeIcon: Icons.storefront,
            ),
            EchoesNavItem(
              label: 'Settings',
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBagTabBody(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment<int>(
                  value: 0,
                  icon: Icon(Icons.shield_outlined),
                  label: Text('Perlengkapan'),
                ),
                ButtonSegment<int>(
                  value: 1,
                  icon: Icon(Icons.inventory_2_outlined),
                  label: Text('Tas'),
                ),
              ],
              selected: {_bagSubTab},
              onSelectionChanged: (next) =>
                  setState(() => _bagSubTab = next.first),
            ),
          ),
        ),
        Expanded(
          child: _bagSubTab == 0
              ? EquipmentOverlay(
                  snapshot: widget.views.equipment,
                  items: widget.items,
                  onEquip: widget.onEquip,
                  onUnequip: widget.onUnequip,
                  onClose: () => _selectTab(TownTab.adventure),
                )
              : InventoryOverlay(
                  entries: widget.views.stacks,
                  onClose: () => _selectTab(TownTab.adventure),
                ),
        ),
      ],
    );
  }

  Widget _buildAdventureBody(
    BuildContext context,
    ThemeData theme, {
    required DungeonDefinition? dungeon,
    required List<DungeonDefinition> catalog,
    required Map<String, DungeonProgressSnapshot> progressMap,
    required DungeonProgressionService progression,
    required int totalRooms,
    required int clearedCount,
    required int selectedRecLevel,
    required int selectedReqLevel,
    required bool selectedUnlockedNoLevel,
    required DeathLoopSuggestion? deathLoopSuggestion,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        final campHeader = _buildCampHeader(context, theme);

        final heroShowcase = ValueListenableBuilder<CharacterSnapshot>(
          valueListenable: widget.views.characterView,
          builder: (context, charSnap, _) {
            final specId = charSnap.specializationId;
            String? specName;
            if (specId != null) {
              for (final sp in charSnap.specializations) {
                if (sp.id == specId) {
                  specName = sp.name;
                  break;
                }
              }
            }
            return HeroShowcaseCard(
              level: charSnap.level,
              ascensionRank: widget.cycleProgress.ascensionRank,
              specializationId: specId,
              specializationName: specName,
              stats: charSnap.stats,
              onTap: () => _selectTab(TownTab.hero),
            );
          },
        );

        final quickAccess = _buildQuickAccessStrip(context, theme);

        final activeAdventure = ValueListenableBuilder<CharacterSnapshot>(
          valueListenable: widget.views.characterView,
          builder: (context, charSnap, _) => _buildActiveAdventureCard(
            context,
            theme,
            charSnap: charSnap,
            dungeon: dungeon,
            totalRooms: totalRooms,
            clearedCount: clearedCount,
            selectedRecLevel: selectedRecLevel,
            selectedReqLevel: selectedReqLevel,
            selectedUnlockedNoLevel: selectedUnlockedNoLevel,
          ),
        );

        final dungeonCatalogCard = catalog.isNotEmpty
            ? _buildDungeonListCard(
                context,
                theme,
                catalog: catalog,
                progressMap: progressMap,
                progression: progression,
              )
            : null;

        final offlineCard = _buildOfflineActivityCard(
          context,
          theme,
          catalog: catalog,
          progressMap: progressMap,
          progression: progression,
        );

        if (isWide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          campHeader,
                          const SizedBox(height: AppSpacing.xs + 2),
                          heroShowcase,
                          const SizedBox(height: AppSpacing.xs + 2),
                          quickAccess,
                          if (widget.cycleProgress.highestAscensionRank >=
                              1) ...[
                            const SizedBox(height: AppSpacing.sm + 2),
                            _buildCycleRankSwitcherCard(theme),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (deathLoopSuggestion != null) ...[
                            _buildDeathLoopSuggestionCard(
                              context,
                              theme,
                              deathLoopSuggestion,
                            ),
                            const SizedBox(height: AppSpacing.sm + 2),
                          ],
                          activeAdventure,
                          if (dungeonCatalogCard != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            dungeonCatalogCard,
                          ],
                          const SizedBox(height: AppSpacing.md),
                          offlineCard,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  campHeader,
                  const SizedBox(height: AppSpacing.sm),
                  heroShowcase,
                  const SizedBox(height: AppSpacing.sm),
                  quickAccess,
                  const SizedBox(height: AppSpacing.md),
                  if (widget.cycleProgress.highestAscensionRank >= 1) ...[
                    _buildCycleRankSwitcherCard(theme),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (deathLoopSuggestion != null) ...[
                    _buildDeathLoopSuggestionCard(
                      context,
                      theme,
                      deathLoopSuggestion,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  activeAdventure,
                  if (dungeonCatalogCard != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    dungeonCatalogCard,
                  ],
                  const SizedBox(height: AppSpacing.md),
                  offlineCard,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCampHeader(BuildContext context, ThemeData theme) {
    final ext = EchoesTheme.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs + 2,
      runSpacing: AppSpacing.xs,
      children: [
        Icon(Icons.local_fire_department_outlined, size: 16, color: ext.gold),
        Text(
          'Town / Camp',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.headingSerif(
            theme.textTheme.titleMedium,
            color: ext.gold,
            letterSpacing: 0.8,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.aetherBlue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: AppColors.aetherBlue.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            'Living Aether Camp',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.aetherBlue,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccessStrip(BuildContext context, ThemeData theme) {
    final actions =
        <({Key key, String label, IconData icon, VoidCallback onTap})>[
          (
            key: const Key('quick_access_hero'),
            label: 'Karakter',
            icon: Icons.person_outline,
            onTap: () => _selectTab(TownTab.hero),
          ),
          (
            key: const Key('quick_access_equipment'),
            label: 'Equip',
            icon: Icons.shield_outlined,
            onTap: () => _openBagSubTab(0),
          ),
          (
            key: const Key('quick_access_bag'),
            label: 'Inventori',
            icon: Icons.inventory_2_outlined,
            onTap: () => _openBagSubTab(1),
          ),
          (
            key: const Key('quick_access_skills'),
            label: 'Skill',
            icon: Icons.auto_fix_high_outlined,
            onTap: () => _selectTab(TownTab.hero),
          ),
          (
            key: const Key('quick_access_shop'),
            label: 'Toko',
            icon: Icons.storefront_outlined,
            onTap: () => _selectTab(TownTab.shop),
          ),
          if (widget.onOpenBossEvents != null)
            (
              key: const Key('quick_access_boss'),
              label: 'Boss',
              icon: Icons.whatshot_outlined,
              onTap: widget.onOpenBossEvents!,
            ),
        ];

    return PanelFrame(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 2,
        vertical: AppSpacing.xs,
      ),
      backgroundColor: AppColors.surfaceDark,
      borderColor: AppColors.panelBorder,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final veryNarrow = constraints.maxWidth < 240;
          if (veryNarrow) {
            return Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final a in actions)
                  _QuickAccessButton(
                    key: a.key,
                    label: a.label,
                    icon: a.icon,
                    onTap: a.onTap,
                    compact: true,
                  ),
              ],
            );
          }
          return Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                Expanded(
                  child: _QuickAccessButton(
                    key: actions[i].key,
                    label: actions[i].label,
                    icon: actions[i].icon,
                    onTap: actions[i].onTap,
                  ),
                ),
                if (i < actions.length - 1)
                  const SizedBox(width: AppSpacing.xs),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildActiveAdventureCard(
    BuildContext context,
    ThemeData theme, {
    required CharacterSnapshot charSnap,
    required DungeonDefinition? dungeon,
    required int totalRooms,
    required int clearedCount,
    required int selectedRecLevel,
    required int selectedReqLevel,
    required bool selectedUnlockedNoLevel,
  }) {
    final selectedMeetsLevel =
        dungeon != null && charSnap.level >= selectedReqLevel;
    final selectedUnlocked = selectedUnlockedNoLevel && selectedMeetsLevel;
    final isUnderLeveled =
        dungeon != null &&
        selectedUnlocked &&
        (selectedRecLevel - charSnap.level) >=
            TownHubView.underLevelWarningDelta;
    final selectedLockReason = !selectedUnlockedNoLevel
        ? 'Terkunci — selesaikan dungeon sebelumnya pada siklus ini.'
        : (!selectedMeetsLevel
              ? 'Terkunci — butuh minimal Lv ${NumberFormatter.format(selectedReqLevel)} (saat ini Lv ${NumberFormatter.format(charSnap.level)}).'
              : null);
    final ext = EchoesTheme.of(context);
    final biomeStyle = dungeon != null
        ? BiomeStyle.resolve(dungeon.biome, isAscension: dungeon.isAscension)
        : BiomeStyle.resolve('default');
    final roomRatio = totalRooms > 0
        ? (clearedCount / totalRooms).clamp(0.0, 1.0)
        : 0.0;

    final bannerHeight = math.max(
      70.0,
      MediaQuery.textScalerOf(context).scale(64),
    );

    return PanelFrame(
      showCornerOrnaments: true,
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      borderColor: (dungeon?.isAscension ?? false) ? ext.rank : ext.gold,
      boxShadow: AppShadows.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BiomeArtwork(
            biomeId: dungeon?.biome ?? 'forgotten_forest',
            isAscension: dungeon?.isAscension ?? false,
            height: bannerHeight,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.midnightForest.withValues(
                              alpha: 0.85,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: biomeStyle.accentColor.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                biomeStyle.icon,
                                size: 13,
                                color: biomeStyle.accentColor,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Flexible(
                                child: Text(
                                  biomeStyle.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: biomeStyle.accentColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (dungeon?.isAscension ?? false) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.midnightForest.withValues(
                              alpha: 0.85,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: ext.rank.withValues(alpha: 0.65),
                            ),
                          ),
                          child: Text(
                            'Ascension',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: ext.rank,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    dungeon?.name ?? 'Pilih Dungeon',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.headingSerif(
                      theme.textTheme.titleLarge,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            dungeon == null
                ? 'Konfigurasi dungeon belum tersedia.'
                : 'Biome: ${dungeon.biome} • $totalRooms Room',
            style: theme.textTheme.bodySmall,
          ),
          if (dungeon != null) ...[
            const SizedBox(height: 2),
            Text(
              'Rekomendasi Lv ${NumberFormatter.format(selectedRecLevel)} • Siklus Rank ${widget.cycleProgress.ascensionRank}',
              style: AppTypography.numeric(
                theme.textTheme.bodySmall,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            totalRooms > 0
                ? 'Progres room tertinggi: $clearedCount / $totalRooms'
                : 'Progres room tertinggi: $clearedCount',
            style: theme.textTheme.bodyMedium,
          ),
          if (totalRooms > 0) ...[
            const SizedBox(height: 4),
            ProgressBar(
              value: roomRatio,
              color: biomeStyle.accentColor,
              height: 6,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Total dungeon selesai: ${widget.dungeonProgress.clearsCount}',
            style: theme.textTheme.bodySmall,
          ),
          if (selectedLockReason != null) ...[
            const SizedBox(height: 6),
            LockedBadge(label: selectedLockReason),
          ],
          if (isUnderLeveled) ...[
            const SizedBox(height: 6),
            Text(
              'Peringatan: Level karakter (${NumberFormatter.format(charSnap.level)}) jauh di bawah rekomendasi Lv ${NumberFormatter.format(selectedRecLevel)}.',
              style: theme.textTheme.bodySmall?.copyWith(color: ext.warning),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            expand: true,
            onPressed: (dungeon == null || !selectedUnlocked)
                ? null
                : widget.onEnterDungeon,
            icon: selectedUnlocked ? Icons.play_arrow : Icons.lock_outline,
            label: 'Masuk ${dungeon?.name ?? 'Dungeon'}',
          ),
        ],
      ),
    );
  }

  Widget _buildDeathLoopSuggestionCard(
    BuildContext context,
    ThemeData theme,
    DeathLoopSuggestion suggestion,
  ) {
    final lower = suggestion.suggestedDungeon;
    final message = lower != null
        ? 'Kamu kalah ${suggestion.consecutiveDefeats} kali beruntun di ${suggestion.failedDungeon.name}. '
              'Sebaiknya pilih dungeon yang lebih rendah (${lower.name}) untuk memperkuat karakter.'
        : 'Kamu kalah ${suggestion.consecutiveDefeats} kali beruntun di ${suggestion.failedDungeon.name}. '
              'Tingkatkan level atau perlengkapan di Town terlebih dahulu.';
    final ext = EchoesTheme.of(context);
    return PanelFrame(
      key: const Key('death_loop_suggestion'),
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: ext.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_outlined, size: 18, color: ext.warning),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Saran: Pilih Dungeon Lebih Rendah',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: ext.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(message, style: theme.textTheme.bodySmall),
          if (lower != null && widget.onSelectDungeon != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                key: const Key('death_loop_select_lower'),
                onPressed: () => widget.onSelectDungeon!(lower.id),
                child: Text('Pilih ${lower.name}'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCycleRankSwitcherCard(ThemeData theme) {
    final current = widget.cycleProgress.ascensionRank;
    final highest = widget.cycleProgress.highestAscensionRank;
    final canDecrease = current > 0 && widget.onSwitchCycleRank != null;
    final canIncrease = current < highest && widget.onSwitchCycleRank != null;
    final ext = EchoesTheme.of(context);
    return PanelFrame(
      key: const Key('cycle_rank_switcher'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      borderColor: ext.rank,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Siklus Rank $current / $highest',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              IconButton(
                key: const Key('cycle_rank_decrease_button'),
                tooltip: 'Turun ke Rank ${current - 1}',
                onPressed: canDecrease
                    ? () => widget.onSwitchCycleRank!(current - 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                key: const Key('cycle_rank_increase_button'),
                tooltip: 'Naik ke Rank ${current + 1}',
                onPressed: canIncrease
                    ? () => widget.onSwitchCycleRank!(current + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          if (current < highest)
            Text(
              'Mode farming rank bawah — rank tertinggi ($highest) tetap tersimpan.',
              style: theme.textTheme.bodySmall?.copyWith(color: ext.rank),
            ),
        ],
      ),
    );
  }

  Widget _buildDungeonListCard(
    BuildContext context,
    ThemeData theme, {
    required List<DungeonDefinition> catalog,
    required Map<String, DungeonProgressSnapshot> progressMap,
    required DungeonProgressionService progression,
  }) {
    final activeId = widget.selectedDungeonId ?? widget.dungeonDefinition?.id;
    final difficultyService = DifficultyService(progression.difficultyConfig);
    final ext = EchoesTheme.of(context);
    return ValueListenableBuilder<CharacterSnapshot>(
      valueListenable: widget.views.characterView,
      builder: (context, charSnap, _) {
        return PanelFrame(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(title: 'Daftar Dungeon', useSerif: true),
              const SizedBox(height: 2),
              Text(
                'Siklus Rank ${widget.cycleProgress.ascensionRank} • Selesaikan berurutan untuk membuka dungeon berikutnya.',
                style: theme.textTheme.bodySmall,
              ),
              for (final d in catalog) ...[
                const SizedBox(height: AppSpacing.sm),
                Builder(
                  builder: (context) {
                    final unlockedByProgress = progression.isUnlocked(
                      d,
                      widget.cycleProgress,
                      progressMap,
                      allDungeons: catalog,
                    );
                    final clearedInCycle = progression.isClearedInCurrentCycle(
                      d.id,
                      widget.cycleProgress,
                      progressMap,
                    );
                    final recLevel = progression.recommendedLevel(
                      d,
                      widget.cycleProgress.ascensionRank,
                    );
                    final reqLevel = progression.requiredLevel(
                      d,
                      widget.cycleProgress.ascensionRank,
                    );
                    final diffMultiplier = difficultyService
                        .profileFor(d, widget.cycleProgress.ascensionRank)
                        .multiplier;
                    final meetsLevel = charSnap.level >= reqLevel;
                    final unlocked = unlockedByProgress && meetsLevel;
                    final isSelected = d.id == activeId;
                    final underLeveled =
                        unlocked &&
                        (recLevel - charSnap.level) >=
                            TownHubView.underLevelWarningDelta;
                    final statusLabel = !unlocked
                        ? 'Terkunci'
                        : (clearedInCycle ? 'Selesai' : 'Terbuka');
                    final statusColor = !unlocked
                        ? ext.locked
                        : (clearedInCycle ? ext.success : ext.expBar);
                    final enterCallback = !unlocked
                        ? null
                        : (widget.onEnterDungeonById != null
                              ? () => widget.onEnterDungeonById!(d.id)
                              : (isSelected ? widget.onEnterDungeon : null));

                    final biomeStyle = BiomeStyle.resolve(
                      d.biome,
                      isAscension: d.isAscension,
                    );
                    final totalRoomsInDungeon = d.roomOrder.length;
                    final snapshot = progressMap[d.id];
                    final clearedRoomsInDungeon = clearedInCycle
                        ? totalRoomsInDungeon
                        : (snapshot != null &&
                                  snapshot.highestClearedRoomIndex >= 0
                              ? (snapshot.highestClearedRoomIndex + 1).clamp(
                                  0,
                                  totalRoomsInDungeon > 0
                                      ? totalRoomsInDungeon
                                      : 999,
                                )
                              : 0);
                    final roomProgress = totalRoomsInDungeon > 0
                        ? (clearedRoomsInDungeon / totalRoomsInDungeon).clamp(
                            0.0,
                            1.0,
                          )
                        : 0.0;

                    return PanelFrame(
                      key: Key('dungeon_row_${d.id}'),
                      padding: const EdgeInsets.all(AppSpacing.sm + 2),
                      backgroundColor: AppColors.surfaceDark,
                      borderColor: d.isAscension
                          ? ext.rank
                          : (isSelected ? ext.gold : ext.panelInnerBorder),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          BiomeArtwork(
                            biomeId: d.biome,
                            isAscension: d.isAscension,
                            height: math.max(
                              78.0,
                              MediaQuery.textScalerOf(context).scale(64),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.xs + 2,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.midnightForest
                                                .withValues(alpha: 0.84),
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.sm,
                                            ),
                                            border: Border.all(
                                              color: biomeStyle.accentColor
                                                  .withValues(alpha: 0.5),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                biomeStyle.icon,
                                                size: 13,
                                                color: unlocked
                                                    ? biomeStyle.accentColor
                                                    : ext.locked,
                                              ),
                                              const SizedBox(
                                                width: AppSpacing.xs,
                                              ),
                                              Flexible(
                                                child: Text(
                                                  biomeStyle.label,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: theme
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: unlocked
                                                            ? biomeStyle
                                                                  .accentColor
                                                            : ext.locked,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      if (!unlocked)
                                        const LockedBadge(label: 'Terkunci')
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.sm,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.midnightForest
                                                .withValues(alpha: 0.86),
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.sm,
                                            ),
                                            border: Border.all(
                                              color: statusColor.withValues(
                                                alpha: 0.65,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            statusLabel,
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: statusColor,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    '${d.order}. ${d.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.headingSerif(
                                      theme.textTheme.titleMedium,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs + 2),
                          Text(
                            'Rekomendasi Lv ${NumberFormatter.format(recLevel)} • Kesulitan ${diffMultiplier.toStringAsFixed(2)}x • ${d.roomOrder.length} Room',
                            style: AppTypography.numeric(
                              theme.textTheme.bodySmall,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (totalRoomsInDungeon > 0) ...[
                            const SizedBox(height: 5),
                            ProgressBar(
                              value: roomProgress,
                              label: 'Progres Room',
                              trailingText:
                                  '$clearedRoomsInDungeon / $totalRoomsInDungeon',
                              color: clearedInCycle
                                  ? ext.success
                                  : biomeStyle.accentColor,
                              height: 5,
                            ),
                          ],
                          if (d.isAscension) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Ascension (Manual-only — tidak tersedia untuk Auto Farming).',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: ext.rank,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (!unlocked) ...[
                            const SizedBox(height: 4),
                            Text(
                              !unlockedByProgress
                                  ? 'Terkunci — selesaikan dungeon sebelumnya pada siklus ini.'
                                  : 'Terkunci — butuh minimal Lv ${NumberFormatter.format(reqLevel)}.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: !unlockedByProgress
                                    ? ext.locked
                                    : theme.colorScheme.error,
                              ),
                            ),
                          ],
                          if (underLeveled) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Peringatan: Level karakter jauh di bawah rekomendasi (Lv ${NumberFormatter.format(recLevel)}).',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: ext.warning,
                              ),
                            ),
                          ],
                          if (unlocked) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.end,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.xs,
                              children: [
                                if (widget.onSelectDungeon != null)
                                  TextButton(
                                    key: Key('dungeon_select_${d.id}'),
                                    onPressed: isSelected
                                        ? null
                                        : () => widget.onSelectDungeon!(d.id),
                                    child: Text(
                                      isSelected
                                          ? 'Target Aktif'
                                          : 'Pilih Target',
                                    ),
                                  ),
                                FilledButton.tonal(
                                  key: Key('dungeon_enter_${d.id}'),
                                  onPressed: enterCallback,
                                  child: const Text('Masuk'),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildOfflineActivityCard(
    BuildContext context,
    ThemeData theme, {
    required List<DungeonDefinition> catalog,
    required Map<String, DungeonProgressSnapshot> progressMap,
    required DungeonProgressionService progression,
  }) {
    final normalCatalog = catalog.where((d) => d.isNormal).toList();
    final ascensionCatalog = catalog.where((d) => d.isAscension).toList();
    final activity = widget.offlineActivity;
    final isPausedSelected =
        activity.isPaused || activity.state == OfflineActivityState.inactive;
    final selectedDungeonName = activity.selectedDungeonId != null
        ? (widget.availableDungeons[activity.selectedDungeonId]?.name ??
              (widget.dungeonDefinition?.id == activity.selectedDungeonId
                  ? widget.dungeonDefinition!.name
                  : activity.selectedDungeonId))
        : null;
    final defaultFarmId = progression.resolveFarmDungeonId(
      dungeons: normalCatalog,
      cycle: widget.cycleProgress,
      progresses: progressMap,
    );
    final defaultFarmName = defaultFarmId != null
        ? (widget.availableDungeons[defaultFarmId]?.name ?? defaultFarmId)
        : null;

    final String activeStatusText;
    if (isPausedSelected) {
      activeStatusText = 'Mode aktif: Pause Progression (Default)';
    } else if (activity.mode == OfflineActivityMode.autoFarming) {
      activeStatusText =
          'Mode aktif: Auto Farming — ${selectedDungeonName ?? 'Dungeon'}';
    } else {
      activeStatusText =
          'Mode aktif: Continue Dungeon${selectedDungeonName != null ? ' — $selectedDungeonName' : ''}';
    }

    return PanelFrame(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Aktivitas Offline',
            trailing: Icon(
              isPausedSelected ? Icons.pause_circle_outline : Icons.autorenew,
              size: 16,
              color: isPausedSelected
                  ? AppColors.textSecondary
                  : EchoesTheme.of(context).expBar,
            ),
          ),
          const SizedBox(height: 4),
          Text(activeStatusText, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            'Maks 8 jam offline • Auto Farming berhenti otomatis jika kalah (stopOnDefeat).',
            style: theme.textTheme.bodySmall,
          ),
          if (defaultFarmName != null) ...[
            const SizedBox(height: 4),
            Text(
              'Target default Auto Farming: $defaultFarmName',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 10),
          isPausedSelected
              ? FilledButton.tonalIcon(
                  onPressed: widget.onSelectPauseOffline,
                  icon: const Icon(Icons.pause_circle_outline),
                  label: const Text('Pause Progression (Default)'),
                )
              : OutlinedButton.icon(
                  onPressed: widget.onSelectPauseOffline,
                  icon: const Icon(Icons.pause_circle_outline),
                  label: const Text('Pause Progression (Default)'),
                ),
          for (final d in normalCatalog) ...[
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final unlocked = progression.isClearedInCurrentCycle(
                  d.id,
                  widget.cycleProgress,
                  progressMap,
                );
                final selected =
                    !isPausedSelected &&
                    activity.mode == OfflineActivityMode.autoFarming &&
                    activity.selectedDungeonId == d.id;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    selected
                        ? FilledButton.icon(
                            onPressed: unlocked
                                ? () => widget.onSelectAutoFarming?.call(d.id)
                                : null,
                            icon: const Icon(Icons.autorenew),
                            label: Text('Auto Farming: ${d.name}'),
                          )
                        : OutlinedButton.icon(
                            onPressed: unlocked
                                ? () => widget.onSelectAutoFarming?.call(d.id)
                                : null,
                            icon: Icon(
                              unlocked ? Icons.autorenew : Icons.lock_outline,
                            ),
                            label: Text('Auto Farming: ${d.name}'),
                          ),
                    if (!unlocked) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Terkunci — selesaikan ${d.name} pada siklus ini untuk membuka Auto Farming.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
          for (final d in ascensionCatalog) ...[
            const SizedBox(height: 6),
            Text(
              '${d.name}: Hanya manual (Ascension Dungeon tidak berjalan offline).',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickAccessButton extends StatelessWidget {
  const _QuickAccessButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 44, minWidth: compact ? 64 : 0),
        child: Material(
          color: AppColors.deepTeal.withValues(alpha: 0.72),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            side: BorderSide(
              color: AppColors.panelBorder.withValues(alpha: 0.8),
              width: AppBorders.thin,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs + 2,
                vertical: AppSpacing.xs + 2,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: AppColors.antiqueGold),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
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
}
