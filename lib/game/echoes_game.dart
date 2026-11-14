import 'dart:ui' show Color;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart' show ValueNotifier, VoidCallback;

import '../core/constants/game_constants.dart';
import '../domain/entities/equipment.dart';
import '../domain/entities/game_config.dart';
import '../domain/entities/inventory.dart';
import '../domain/entities/player_character.dart';
import '../domain/services/difficulty_service.dart';
import '../domain/services/dungeon_manager.dart';
import '../domain/services/equipment_service.dart';
import '../domain/services/reward_processor.dart';
import 'audio/audio_service.dart';
import 'hud/hud_state.dart';
import 'hud/inventory_views.dart';
import 'world/dungeon_world.dart';

/// Root game (GDD 12.1).
class EchoesGame extends FlameGame<DungeonWorld> {
  factory EchoesGame({
    required GameConfig config,
    required PlayerCharacter character,
    required Inventory inventory,
    required ValueNotifier<bool> autoSkill,
    DungeonManager? dungeonManager,
    double roomTransitionDelaySeconds = 1.0,
    InventoryViews? views,
    EquipmentService? equipmentService,
    RewardProcessor? rewardProcessor,
    VoidCallback? onProgressionChanged,
    VoidCallback? onBuildChanged,
    VoidCallback? onCriticalSaveRequired,
    void Function(GrantedReward reward)? onDungeonRewardSettled,
    int? initialPlayerHp,
    int initialReviveCooldownTicks = 0,
    Map<String, int> initialSkillCooldownTicks = const {},
    int? simulationSeed,
    AudioService? audioService,
    DifficultyProfile? difficultyProfile,
  }) {
    final maxHp = character.stats.maxHp;
    final resolvedHp = initialPlayerHp != null
        ? initialPlayerHp.clamp(1, maxHp)
        : maxHp;
    final resolvedViews =
        views ?? InventoryViews(inventory: inventory, character: character);
    final resolvedEquipmentService =
        equipmentService ??
        EquipmentService(inventory: inventory, loadout: character.loadout);
    return EchoesGame._(
      config: config,
      character: character,
      autoSkill: autoSkill,
      dungeonManager: dungeonManager,
      roomTransitionDelaySeconds: roomTransitionDelaySeconds,
      rewardProcessor: rewardProcessor,
      onProgressionChanged: onProgressionChanged,
      onBuildChanged: onBuildChanged,
      onCriticalSaveRequired: onCriticalSaveRequired,
      onDungeonRewardSettled: onDungeonRewardSettled,
      initialPlayerHp: initialPlayerHp,
      initialReviveCooldownTicks: initialReviveCooldownTicks,
      initialSkillCooldownTicks: initialSkillCooldownTicks,
      simulationSeed: simulationSeed,
      audioService: audioService,
      difficultyProfile: difficultyProfile,
      views: resolvedViews,
      equipmentService: resolvedEquipmentService,
      hud: ValueNotifier<HudState>(
        HudState.fromCharacter(
          character,
          hp: resolvedHp,
          maxHp: maxHp,
          dungeonName: dungeonManager?.activeDungeon?.name ?? '',
          roomName: dungeonManager?.activeRoom?.name ?? '',
        ),
      ),
    );
  }

  EchoesGame._({
    required GameConfig config,
    required this.character,
    required this.autoSkill,
    DungeonManager? dungeonManager,
    double roomTransitionDelaySeconds = 1.0,
    RewardProcessor? rewardProcessor,
    VoidCallback? onProgressionChanged,
    this.onBuildChanged,
    VoidCallback? onCriticalSaveRequired,
    void Function(GrantedReward reward)? onDungeonRewardSettled,
    int? initialPlayerHp,
    int initialReviveCooldownTicks = 0,
    Map<String, int> initialSkillCooldownTicks = const {},
    int? simulationSeed,
    AudioService? audioService,
    DifficultyProfile? difficultyProfile,
    required this.views,
    required this.equipmentService,
    required this.hud,
  }) : super(
         world: DungeonWorld(
           config: config,
           character: character,
           views: views,
           hud: hud,
           autoSkill: autoSkill,
           dungeonManager: dungeonManager,
           roomTransitionDelaySeconds: roomTransitionDelaySeconds,
           rewardProcessor: rewardProcessor,
           onProgressionChanged: onProgressionChanged,
           onCriticalSaveRequired: onCriticalSaveRequired,
           onDungeonRewardSettled: onDungeonRewardSettled,
           initialPlayerHp: initialPlayerHp,
           initialReviveCooldownTicks: initialReviveCooldownTicks,
           initialSkillCooldownTicks: initialSkillCooldownTicks,
           simulationSeed: simulationSeed,
           audioService: audioService,
           difficultyProfile: difficultyProfile,
         ),
         camera: CameraComponent.withFixedResolution(
           width: GameConstants.viewWidth,
           height: GameConstants.viewHeight,
         ),
       );

  final PlayerCharacter character;

  /// Pengaturan auto skill (GDD 2.4), diubah dari UI.
  final ValueNotifier<bool> autoSkill;
  final VoidCallback? onBuildChanged;

  /// Data yang dibaca overlay Flutter.
  final ValueNotifier<HudState> hud;
  final InventoryViews views;
  final EquipmentService equipmentService;

  /// Dipanggil dari UI. Stat dan skill combatant diperbarui otomatis oleh
  /// CombatSystem pada frame berikutnya (mendeteksi perubahan build).
  void equip(String instanceId) {
    if (equipmentService.equip(instanceId)) {
      views.refresh();
      onBuildChanged?.call();
    }
  }

  void unequip(EquipmentSlot slot) {
    if (equipmentService.unequip(slot)) {
      views.refresh();
      onBuildChanged?.call();
    }
  }

  void chooseSpecialization(String id) {
    if (character.chooseSpecialization(id)) {
      views.refresh();
      onBuildChanged?.call();
    }
  }

  void upgradeSkill(String skillId) {
    final result = character.upgradeSkill(skillId);
    if (result.status == SkillUpgradeStatus.upgraded) {
      views.refresh();
      onBuildChanged?.call();
    }
  }

  /// Melepas listener sesi dari `DungeonManager` agar instance game lama
  /// tidak bereaksi terhadap transisi run berikutnya.
  void detachSessionListeners() {
    world.detachSessionListeners();
  }

  @override
  void onDispose() {
    detachSessionListeners();
    hud.dispose();
    super.onDispose();
  }

  @override
  Future<void> onLoad() async {
    camera.viewfinder.position = Vector2(
      GameConstants.viewWidth / 2,
      GameConstants.viewHeight / 2,
    );
  }

  @override
  Color backgroundColor() => const Color(0xFF0B0B12);
}
