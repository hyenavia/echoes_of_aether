import 'boss_event.dart';
import 'boss_spire.dart';
import 'cloud_config.dart';
import 'currency_config.dart';
import 'damage_config.dart';
import 'difficulty_config.dart';
import 'dungeon_definition.dart';
import 'dungeon_reward.dart';
import 'enemy_definition.dart';
import 'equipment_config.dart';
import 'event_shop_config.dart';
import 'farming_config.dart';
import 'gacha_config.dart';
import 'hero_ascension.dart';
import 'infinite_spire.dart';
import 'item_definition.dart';
import 'loot_table.dart';
import 'notification_config.dart';
import 'progression_config.dart';
import 'revive_config.dart';
import 'shop_config.dart';
import 'skill_definition.dart';
import 'specialization.dart';
import 'time_config.dart';

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
    this.time = const TimeConfig(),
    this.claimedRewards = const ClaimedRewardsConfig(),
    this.currencies = CurrencyDefinition.defaults,
    this.notifications = const NotificationConfig(),
    this.dungeonCompletion = const DungeonCompletionReward(),
    this.skills = const {},
    this.specializations = const SpecializationConfig(),
    this.dungeons = const {},
    this.mapLayouts = const {},
    this.bossEvents,
    this.bossSpire,
    this.shop = const ShopCatalog.empty(),
    this.eventShop,
    this.cloud = const CloudConfig(),
    this.gacha,
    this.heroAscension = const HeroAscensionConfig(),
    this.infiniteSpire,
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
  final TimeConfig time;
  final ClaimedRewardsConfig claimedRewards;
  final Map<String, CurrencyDefinition> currencies;
  final NotificationConfig notifications;
  final DungeonCompletionReward dungeonCompletion;
  final Map<String, SkillDefinition> skills;
  final SpecializationConfig specializations;
  final Map<String, DungeonDefinition> dungeons;
  final Map<String, List<String>> mapLayouts;
  final BossEventsConfig? bossEvents;
  final BossSpireConfig? bossSpire;
  final ShopCatalog shop;
  final EventShopCatalog? eventShop;
  final CloudConfig cloud;
  final GachaConfig? gacha;
  final HeroAscensionConfig heroAscension;
  final InfiniteSpireConfig? infiniteSpire;
}
