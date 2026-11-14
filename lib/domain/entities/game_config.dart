import 'damage_config.dart';
import 'difficulty_config.dart';
import 'dungeon_definition.dart';
import 'dungeon_reward.dart';
import 'enemy_definition.dart';
import 'equipment_config.dart';
import 'farming_config.dart';
import 'item_definition.dart';
import 'loot_table.dart';
import 'progression_config.dart';
import 'revive_config.dart';
import 'shop_config.dart';
import 'skill_definition.dart';
import 'specialization.dart';

/// Seluruh konfigurasi statis yang sudah divalidasi. Dibuat sekali saat
/// aplikasi memuat data, lalu dibagikan ke game.
class GameConfig {
  const GameConfig({
    required this.monsters,
    required this.revive,
    required this.progression,
    required this.items,
    required this.lootTables,
    this.damage = const DamageConfig(),
    this.difficulty = const DifficultyConfig(),
    this.farming = const FarmingConfig(),
    this.equipment = const EquipmentConfig(),
    this.dungeonCompletion = const DungeonCompletionReward(),
    this.skills = const {},
    this.specializations = const SpecializationConfig(),
    this.dungeons = const {},
    this.shop = const ShopCatalog.empty(),
  });

  final Map<String, EnemyDefinition> monsters;
  final ReviveConfig revive;
  final ProgressionConfig progression;
  final Map<String, ItemDefinition> items;
  final Map<String, LootTable> lootTables;
  final DamageConfig damage;
  final DifficultyConfig difficulty;
  final FarmingConfig farming;
  final EquipmentConfig equipment;
  final DungeonCompletionReward dungeonCompletion;
  final Map<String, SkillDefinition> skills;
  final SpecializationConfig specializations;
  final Map<String, DungeonDefinition> dungeons;
  final ShopCatalog shop;
}
