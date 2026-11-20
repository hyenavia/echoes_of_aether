import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../domain/entities/enemy_definition.dart';
import '../../domain/entities/game_config.dart';
import '../../domain/repositories/game_config_repository.dart';
import '../models/boss_events_config_parser.dart';
import '../models/boss_spire_config_parser.dart';
import '../models/dungeon_config_parser.dart';
import '../models/event_shop_config_parser.dart';
import '../models/gacha_config_parser.dart';
import '../models/game_config_parser.dart';
import '../models/game_config_validator.dart';
import '../models/infinite_spire_config_parser.dart';
import '../models/item_config_parser.dart';
import '../models/loot_config_parser.dart';
import '../models/monster_config_parser.dart';
import '../models/shop_config_parser.dart';
import '../models/skill_config_parser.dart';
import '../models/specialization_config_parser.dart';

/// Memuat konfigurasi statis game dari assets/data/.
class AssetGameConfigRepository implements GameConfigRepository {
  AssetGameConfigRepository({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  Future<String> _read(String name) => _bundle.loadString('assets/data/$name');

  @override
  Future<Map<String, EnemyDefinition>> loadMonsters() async =>
      const MonsterConfigParser().parse(await _read('monsters.json'));

  @override
  Future<GameConfig> loadGameConfig() async {
    final settings = await _read('game_config.json');
    final dungeonsJson = await _read('dungeons.json');
    const parser = GameConfigParser();
    const dungeonParser = DungeonConfigParser();

    final config = GameConfig(
      monsters: await loadMonsters(),
      damage: parser.parseDamage(settings),
      difficulty: parser.parseDifficulty(settings),
      farming: parser.parseFarming(settings),
      revive: parser.parseRevive(settings),
      progression: parser.parseProgression(settings),
      equipment: parser.parseEquipment(settings),
      time: parser.parseTime(settings),
      claimedRewards: parser.parseClaimedRewards(settings),
      currencies: parser.parseCurrencies(settings),
      notifications: parser.parseNotifications(settings),
      dungeonCompletion: parser.parseDungeonCompletion(settings),
      cloud: parser.parseCloud(settings),
      items: const ItemConfigParser().parse(await _read('items.json')),
      lootTables: const LootConfigParser().parse(
        await _read('loot_tables.json'),
      ),
      skills: const SkillConfigParser().parse(await _read('skills.json')),
      specializations: const SpecializationConfigParser().parse(
        await _read('specializations.json'),
      ),
      dungeons: dungeonParser.parse(
        dungeonsJson,
        ascensionMultiplier: parser
            .parseDifficulty(settings)
            .ascensionMultiplier,
      ),
      mapLayouts: dungeonParser.parseMaps(dungeonsJson),
      bossEvents: const BossEventsConfigParser().parse(
        await _read('boss_events.json'),
      ),
      bossSpire: const BossSpireConfigParser().parse(
        await _read('boss_spire.json'),
      ),
      shop: const ShopConfigParser().parse(await _read('shop.json')),
      eventShop: const EventShopConfigParser().parse(
        await _read('event_shop.json'),
      ),
      gacha: const GachaConfigParser().parse(await _read('gacha_banners.json')),
      heroAscension: parser.parseHeroAscension(settings),
      infiniteSpire: const InfiniteSpireConfigParser().parse(
        await _read('infinite_spire.json'),
      ),
    );
    const GameConfigValidator().validate(config);
    return config;
  }
}
