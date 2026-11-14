import 'dart:io';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/services/game_session_coordinator.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/inventory.dart';
import 'package:echoes_of_aether/domain/entities/player_character.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/shop_config.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/shop_service.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealConfig({ShopCatalog? shopOverride}) {
  const parser = GameConfigParser();
  final settings = _readAsset('game_config.json');
  final difficulty = parser.parseDifficulty(settings);
  return GameConfig(
    monsters: const MonsterConfigParser().parse(_readAsset('monsters.json')),
    damage: parser.parseDamage(settings),
    difficulty: difficulty,
    farming: parser.parseFarming(settings),
    revive: parser.parseRevive(settings),
    progression: parser.parseProgression(settings),
    equipment: parser.parseEquipment(settings),
    dungeonCompletion: parser.parseDungeonCompletion(settings),
    items: const ItemConfigParser().parse(_readAsset('items.json')),
    lootTables: const LootConfigParser().parse(_readAsset('loot_tables.json')),
    skills: const SkillConfigParser().parse(_readAsset('skills.json')),
    specializations: const SpecializationConfigParser().parse(
      _readAsset('specializations.json'),
    ),
    dungeons: const DungeonConfigParser().parse(
      _readAsset('dungeons.json'),
      ascensionMultiplier: difficulty.ascensionMultiplier,
    ),
    shop:
        shopOverride ?? const ShopConfigParser().parse(_readAsset('shop.json')),
  );
}

void main() {
  late AppDatabase db;
  late GameConfig config;
  late DriftPlayerSaveRepository repo;
  late GameSessionCoordinator coordinator;

  setUp(() {
    final realConfig = _loadRealConfig();
    final limitedCatalog = ShopCatalog(
      entries: [
        const ShopEntry(
          id: 'shop_rusty_sword',
          itemId: 'rusty_sword',
          price: 12,
          purchaseLimit: 1,
        ),
        ...realConfig.shop.entries.where((e) => e.id != 'shop_rusty_sword'),
      ],
      sell: realConfig.shop.sell,
    );
    config = _loadRealConfig(shopOverride: limitedCatalog);
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftPlayerSaveRepository(db: db, config: config);
    coordinator = GameSessionCoordinator(
      config: config,
      repository: repo,
      nowMs: () => 1_700_000_000_000,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('transaksi beli/jual dipersistenkan atomik, purchase_limit bertahan lintas restart, dan actionId idempoten di DB', () async {
    final character = PlayerCharacter(
      config: config.progression,
      specializationConfig: config.specializations,
      skillCatalog: config.skills,
      progress: const PlayerProgress(level: 10, currentExp: 0, gold: 100),
      initialSpecializationId: 'vanguard',
    );
    final inventory = Inventory(definitions: config.items);
    final shop = ShopService(
      catalog: config.shop,
      items: config.items,
      equipmentFactory: EquipmentFactory(config.equipment),
    );
    final purchases = <String, int>{};

    // Simpan baseline terlebih dahulu
    await coordinator.saveShopTransaction(
      character: character,
      inventory: inventory,
      shopPurchases: purchases,
    );

    // Beli rusty_sword (limit 1, harga 12)
    final buyRes = shop.buy(
      entryId: 'shop_rusty_sword',
      character: character,
      inventory: inventory,
      context: ShopPlayerContext(playerLevel: 10, shopPurchases: purchases),
      random: math.Random(99),
      purchaseCounts: purchases,
      actionId: 'tx-buy-1',
    );
    expect(buyRes, isA<ShopBuySuccess>());
    final boughtId = (buyRes as ShopBuySuccess).purchasedEquipment!.id;

    await coordinator.saveShopTransaction(
      character: character,
      inventory: inventory,
      shopPurchases: purchases,
      actionId: 'tx-buy-1',
    );

    // Simulasi duplikasi DB write dengan actionId sama tidak menimpa/menggandakan
    await repo.saveShopTransaction(
      progress: const PlayerProgress(level: 10, currentExp: 0, gold: 9999),
      inventory: inventory.toSnapshot(),
      equipped: character.loadout.equipped,
      shopPurchases: const {'shop_rusty_sword': 99},
      actionId: 'tx-buy-1',
    );

    // Restart sesi: loadSnapshot & loadAndProcessOffline
    final loaded = await coordinator.loadAndProcessOffline();
    expect(loaded.character.gold, 88);
    expect(loaded.inventory.equipmentById(boughtId), isNotNull);
    expect(loaded.shopPurchases['shop_rusty_sword'], 1);

    // Setelah restart, purchase_limit tetap menegakkan batas (1)
    final blockedAfterRestart = shop.buy(
      entryId: 'shop_rusty_sword',
      character: loaded.character,
      inventory: loaded.inventory,
      context: ShopPlayerContext(
        playerLevel: loaded.character.level,
        shopPurchases: loaded.shopPurchases,
      ),
      random: math.Random(100),
    );
    expect(blockedAfterRestart, isA<ShopBuyLimitReached>());

    // Jual item yang sama setelah restart dan persist
    final sellRes = shop.sellEquipment(
      instanceId: boughtId,
      character: loaded.character,
      inventory: loaded.inventory,
      actionId: 'tx-sell-1',
    );
    expect(sellRes, isA<ShopSellSuccess>());
    await coordinator.saveShopTransaction(
      character: loaded.character,
      inventory: loaded.inventory,
      shopPurchases: loaded.shopPurchases,
      actionId: 'tx-sell-1',
    );

    final afterSell = await repo.loadSnapshot();
    expect(afterSell, isNotNull);
    expect(
      afterSell!.character.progress.gold,
      88 + (sellRes as ShopSellSuccess).goldEarned,
    );
    expect(afterSell.inventory.equipment, isEmpty);
    expect(afterSell.shopPurchases['shop_rusty_sword'], 1);
  });
}
