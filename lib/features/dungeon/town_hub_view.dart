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
import '../../domain/services/shop_service.dart';
import '../../game/hud/inventory_views.dart';
import '../../game/overlays.dart';
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

  @override
  State<TownHubView> createState() => _TownHubViewState();
}

class _TownHubViewState extends State<TownHubView> {
  String? _openPanel;
  TownTab _selectedTab = TownTab.adventure;
  int _bagSubTab = 0;

  void _togglePanel(String panel) {
    setState(() {
      _openPanel = _openPanel == panel ? null : panel;
    });
  }

  void _closePanel() {
    if (_openPanel != null) {
      setState(() => _openPanel = null);
    }
  }

  void _selectTab(TownTab tab) {
    setState(() {
      _openPanel = null;
      _selectedTab = tab;
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

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: ValueListenableBuilder<CharacterSnapshot>(
                  valueListenable: widget.views.characterView,
                  builder: (context, charSnap, _) => TownTopBar(
                    level: charSnap.level,
                    currentExp: widget.character.currentExp,
                    expToNext: widget.character.expToNext,
                    gold: widget.character.gold,
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
                          onClose: () => _selectTab(TownTab.adventure),
                        )
                      : const Center(
                          child: PanelFrame(
                            child: Text('Toko belum tersedia.'),
                          ),
                        ),
                TownTab.settings =>
                  (widget.settings != null && widget.onSettingsChanged != null)
                      ? SettingsOverlay(
                          settings: widget.settings!,
                          onChanged: widget.onSettingsChanged!,
                          onTestSfx: widget.onTestSfx,
                          onClose: () => _selectTab(TownTab.adventure),
                        )
                      : const Center(
                          child: PanelFrame(
                            child: Text('Pengaturan belum tersedia.'),
                          ),
                        ),
              },
            ),
            NavigationBar(
              key: const Key('town_bottom_nav'),
              height: 64,
              selectedIndex: _selectedTab.index,
              onDestinationSelected: (index) =>
                  _selectTab(TownTab.values[index]),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore),
                  label: 'Adventure',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Hero',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: 'Bag',
                ),
                NavigationDestination(
                  icon: Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront),
                  label: 'Shop',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ],
        ),
        if (_openPanel != null) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: _closePanel,
              child: const ColoredBox(color: Color(0x88000000)),
            ),
          ),
          if (_openPanel == GameOverlays.inventory)
            InventoryOverlay(
              entries: widget.views.stacks,
              onClose: _closePanel,
            ),
          if (_openPanel == GameOverlays.equipment)
            EquipmentOverlay(
              snapshot: widget.views.equipment,
              items: widget.items,
              onEquip: widget.onEquip,
              onUnequip: widget.onUnequip,
              onClose: _closePanel,
            ),
          if (_openPanel == GameOverlays.character)
            CharacterOverlay(
              snapshot: widget.views.characterView,
              onChooseSpecialization: widget.onChooseSpecialization,
              onUpgradeSkill: widget.onUpgradeSkill,
              onClose: _closePanel,
            ),
          if (_openPanel == GameOverlays.settings &&
              widget.settings != null &&
              widget.onSettingsChanged != null)
            SettingsOverlay(
              settings: widget.settings!,
              onChanged: widget.onSettingsChanged!,
              onTestSfx: widget.onTestSfx,
              onClose: _closePanel,
            ),
          if (_openPanel == GameOverlays.shop &&
              widget.shopCatalog != null &&
              widget.shopService != null &&
              widget.shopContext != null &&
              widget.onShopBuy != null &&
              widget.onShopSellEquipment != null &&
              widget.onShopSellMaterialBulk != null)
            ShopOverlay(
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
              onClose: _closePanel,
            ),
        ],
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Town / Camp',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              if (widget.cycleProgress.highestAscensionRank >= 1) ...[
                _buildCycleRankSwitcherCard(theme),
                const SizedBox(height: 12),
              ],
              if (deathLoopSuggestion != null) ...[
                _buildDeathLoopSuggestionCard(
                  context,
                  theme,
                  deathLoopSuggestion,
                ),
                const SizedBox(height: 12),
              ],
              ValueListenableBuilder<CharacterSnapshot>(
                valueListenable: widget.views.characterView,
                builder: (context, charSnap, _) {
                  final selectedMeetsLevel =
                      dungeon != null && charSnap.level >= selectedReqLevel;
                  final selectedUnlocked =
                      selectedUnlockedNoLevel && selectedMeetsLevel;
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
                  return PanelFrame(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    borderColor: (dungeon?.isAscension ?? false)
                        ? ext.rank
                        : ext.gold,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                dungeon?.name ?? 'Pilih Dungeon',
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            if (dungeon?.isAscension ?? false)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: ext.rank.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                  border: Border.all(
                                    color: ext.rank.withValues(alpha: 0.55),
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
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dungeon == null
                              ? 'Konfigurasi dungeon belum tersedia.'
                              : 'Biome: ${dungeon.biome} • $totalRooms Room',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (dungeon != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Rekomendasi Lv ${NumberFormatter.format(selectedRecLevel)} • Siklus Rank ${widget.cycleProgress.ascensionRank}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          totalRooms > 0
                              ? 'Progres room tertinggi: $clearedCount / $totalRooms'
                              : 'Progres room tertinggi: $clearedCount',
                        ),
                        Text(
                          'Total dungeon selesai: ${widget.dungeonProgress.clearsCount}',
                        ),
                        if (selectedLockReason != null) ...[
                          const SizedBox(height: 6),
                          LockedBadge(label: selectedLockReason),
                        ],
                        if (isUnderLeveled) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Peringatan: Level karakter (${NumberFormatter.format(charSnap.level)}) jauh di bawah rekomendasi Lv ${NumberFormatter.format(selectedRecLevel)}.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: ext.warning,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: (dungeon == null || !selectedUnlocked)
                                ? null
                                : widget.onEnterDungeon,
                            icon: Icon(
                              selectedUnlocked
                                  ? Icons.play_arrow
                                  : Icons.lock_outline,
                            ),
                            label: Text('Masuk ${dungeon?.name ?? 'Dungeon'}'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _togglePanel(GameOverlays.inventory),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Tas'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _togglePanel(GameOverlays.equipment),
                    icon: const Icon(Icons.shield_outlined),
                    label: const Text('Perlengkapan'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _togglePanel(GameOverlays.character),
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: const Text('Karakter'),
                  ),
                  if (widget.shopCatalog != null &&
                      widget.shopService != null &&
                      widget.shopContext != null &&
                      widget.onShopBuy != null &&
                      widget.onShopSellEquipment != null &&
                      widget.onShopSellMaterialBulk != null)
                    FilledButton.tonalIcon(
                      onPressed: () => _togglePanel(GameOverlays.shop),
                      icon: const Icon(Icons.storefront_outlined),
                      label: const Text('Toko'),
                    ),
                  if (widget.settings != null &&
                      widget.onSettingsChanged != null)
                    FilledButton.tonalIcon(
                      onPressed: () => _togglePanel(GameOverlays.settings),
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Pengaturan'),
                    ),
                ],
              ),
              if (catalog.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildDungeonListCard(
                  context,
                  theme,
                  catalog: catalog,
                  progressMap: progressMap,
                  progression: progression,
                ),
              ],
              const SizedBox(height: 12),
              _buildOfflineActivityCard(
                context,
                theme,
                catalog: catalog,
                progressMap: progressMap,
                progression: progression,
              ),
            ],
          ),
        ),
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
              const SectionHeader(title: 'Daftar Dungeon'),
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

                    return PanelFrame(
                      key: Key('dungeon_row_${d.id}'),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      backgroundColor: AppColors.surfaceDark,
                      borderColor: d.isAscension
                          ? ext.rank
                          : (isSelected ? ext.gold : ext.panelInnerBorder),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${d.order}. ${d.name}',
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                              if (!unlocked)
                                const LockedBadge(label: 'Terkunci')
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.sm,
                                    ),
                                    border: Border.all(
                                      color: statusColor.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: statusColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rekomendasi Lv ${NumberFormatter.format(recLevel)} • Kesulitan ${diffMultiplier.toStringAsFixed(2)}x • ${d.roomOrder.length} Room',
                            style: theme.textTheme.bodySmall,
                          ),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
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
                                const SizedBox(width: 8),
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
    final ascensionCatalog = catalog.where((d) => !d.isNormal).toList();
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Aktivitas Offline', style: theme.textTheme.titleMedium),
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
      ),
    );
  }
}
