import '../../core/errors/config_exception.dart';
import '../../domain/entities/difficulty_config.dart';
import '../../domain/entities/dungeon_definition.dart';
import '../../domain/entities/farming_config.dart';
import '../../domain/entities/game_config.dart';
import '../../domain/entities/item_definition.dart';
import '../../domain/entities/progression_config.dart';
import '../../domain/entities/shop_config.dart';
import '../../domain/entities/skill_definition.dart';
import '../../domain/services/damage_calculator.dart';
import '../../domain/services/navigation_grid.dart';
import 'monster_config_parser.dart';

/// Memeriksa referensi antar file konfigurasi, misalnya monster yang merujuk
/// loot table yang tidak ada. Dijalankan sekali saat memuat data, sehingga
/// kesalahan muncul sebagai pesan jelas, bukan crash di tengah permainan.
class GameConfigValidator {
  const GameConfigValidator();

  void validate(GameConfig config) {
    switch (config.damage.formula) {
      case DamageFormula.ratio:
      case DamageFormula.subtractive:
        break;
    }
    _validateProgression(config.progression);
    _validateDifficulty(config.difficulty);
    _validateFarming(config.farming);
    _validateShop(config);
    for (final table in config.lootTables.values) {
      for (final entry in table.entries) {
        if (!config.items.containsKey(entry.itemId)) {
          throw ConfigException(
            'loot_tables.json: tabel "${table.id}" merujuk item '
            '"${entry.itemId}" yang tidak ada di items.json.',
          );
        }
      }
    }
    for (final monster in config.monsters.values) {
      if (monster.isElite && monster.isBoss) {
        throw ConfigException(
          'monsters.json: monster "${monster.id}" tidak boleh sekaligus '
          'menjadi elite dan boss.',
        );
      }
      final tableId = monster.lootTableId;
      if (tableId != null && !config.lootTables.containsKey(tableId)) {
        throw ConfigException(
          'monsters.json: monster "${monster.id}" merujuk loot_table_id '
          '"$tableId" yang tidak ada di loot_tables.json.',
        );
      }
      final tint = monster.spriteTint;
      if (tint != null && !MonsterConfigParser.isValidHexTint(tint)) {
        throw ConfigException(
          'monsters.json: monster "${monster.id}" memiliki sprite_tint '
          'tidak valid "$tint".',
        );
      }
    }
    final dungeonCompletion = config.dungeonCompletion;
    if (dungeonCompletion.expReward < 0 || dungeonCompletion.goldReward < 0) {
      throw const ConfigException(
        'game_config.json: reward dungeon_completion tidak boleh negatif.',
      );
    }
    final clearTableId = dungeonCompletion.lootTableId;
    if (clearTableId != null && !config.lootTables.containsKey(clearTableId)) {
      throw ConfigException(
        'game_config.json: dungeon_completion.loot_table_id '
        '"$clearTableId" tidak ada di loot_tables.json.',
      );
    }
    for (final skill in config.skills.values) {
      final specId = skill.specializationId;
      if (specId != null &&
          !config.specializations.definitions.containsKey(specId)) {
        throw ConfigException(
          'skills.json: skill "${skill.id}" merujuk specialization_id '
          '"$specId" yang tidak ada di specializations.json.',
        );
      }
      if (skill.cooldownSeconds < 0) {
        throw ConfigException(
          'skills.json: skill "${skill.id}" memiliki cooldown negatif.',
        );
      }
      if (skill.maxLevel < 1) {
        throw ConfigException(
          'skills.json: skill "${skill.id}" memiliki max_level < 1.',
        );
      }
      if (skill.upgradeCost < 0) {
        throw ConfigException(
          'skills.json: skill "${skill.id}" memiliki upgrade_cost negatif.',
        );
      }
      if (skill.baseValue <= 0 || skill.valuePerLevel < 0) {
        throw ConfigException(
          'skills.json: skill "${skill.id}" memiliki konfigurasi scaling tidak valid.',
        );
      }
      if (skill.effect == SkillEffectType.damage && skill.damageType == null) {
        throw ConfigException(
          'skills.json: skill damage "${skill.id}" wajib memiliki damage_type.',
        );
      }
      if (skill.effect != SkillEffectType.damage && skill.damageType != null) {
        throw ConfigException(
          'skills.json: skill non-damage "${skill.id}" tidak boleh memiliki damage_type.',
        );
      }
    }
    for (final spec in config.specializations.definitions.values) {
      if (spec.unlockLevel != null && spec.unlockLevel! < 1) {
        throw ConfigException(
          'specializations.json: specialization "${spec.id}" memiliki unlock_level < 1.',
        );
      }
      for (final entry in spec.skillAffinities.entries) {
        if (!config.skills.containsKey(entry.key)) {
          throw ConfigException(
            'specializations.json: specialization "${spec.id}" merujuk skill '
            '"${entry.key}" yang tidak ada di skills.json.',
          );
        }
        if (entry.value < 0) {
          throw ConfigException(
            'specializations.json: specialization "${spec.id}" memiliki affinity '
            'negatif untuk "${entry.key}".',
          );
        }
      }
    }
    _validateDungeonCatalog(config);
    for (final dungeon in config.dungeons.values) {
      _validateDungeon(dungeon, config);
    }
  }

  void _validateDungeon(DungeonDefinition dungeon, GameConfig config) {
    if (dungeon.rooms.isEmpty) {
      throw ConfigException(
        'dungeons.json: dungeon "${dungeon.id}" tidak memiliki room.',
      );
    }
    if (!dungeon.rooms.containsKey(dungeon.startRoomId)) {
      throw ConfigException(
        'dungeons.json: dungeon "${dungeon.id}" memiliki start_room_id '
        '"${dungeon.startRoomId}" yang tidak ada.',
      );
    }
    final completionLoot = dungeon.completionReward?.lootTableId;
    if (completionLoot != null &&
        !config.lootTables.containsKey(completionLoot)) {
      throw ConfigException(
        'dungeons.json: dungeon "${dungeon.id}" merujuk completion_reward.loot_table_id '
        '"$completionLoot" yang tidak ada di loot_tables.json.',
      );
    }

    for (final room in dungeon.rooms.values) {
      if (room.dungeonId != dungeon.id) {
        throw ConfigException(
          'dungeons.json: room "${room.id}" memiliki dungeonId "${room.dungeonId}" '
          'yang tidak cocok dengan "${dungeon.id}".',
        );
      }

      final NavigationGrid grid;
      try {
        grid = room.createNavigationGrid();
      } on ArgumentError catch (e) {
        throw ConfigException(
          'dungeons.json: room "${room.id}" memiliki layout tidak valid: ${e.message}',
        );
      }

      if (!grid.isWalkable(room.entryPosition.x, room.entryPosition.y)) {
        throw ConfigException(
          'dungeons.json: room "${room.id}" memiliki entry_position tidak walkable.',
        );
      }
      if (!grid.isWalkable(room.exitPosition.x, room.exitPosition.y)) {
        throw ConfigException(
          'dungeons.json: room "${room.id}" memiliki exit_position tidak walkable.',
        );
      }

      for (final nextId in room.nextRoomIds) {
        if (nextId == room.id) {
          throw ConfigException(
            'dungeons.json: room "${room.id}" tidak boleh merujuk dirinya sendiri pada next_room_ids.',
          );
        }
        if (!dungeon.rooms.containsKey(nextId)) {
          throw ConfigException(
            'dungeons.json: room "${room.id}" merujuk next_room_ids '
            '"$nextId" yang tidak ada di dungeon "${dungeon.id}".',
          );
        }
      }

      final roomLoot = room.reward?.lootTableId;
      if (roomLoot != null && !config.lootTables.containsKey(roomLoot)) {
        throw ConfigException(
          'dungeons.json: room "${room.id}" merujuk reward.loot_table_id '
          '"$roomLoot" yang tidak ada di loot_tables.json.',
        );
      }

      final groupsInRoom = {for (final s in room.spawns) s.spawnGroup};
      for (final spawn in room.spawns) {
        if (!config.monsters.containsKey(spawn.monsterId)) {
          throw ConfigException(
            'dungeons.json: room "${room.id}" spawn "${spawn.id}" merujuk '
            'monster_id "${spawn.monsterId}" yang tidak ada di monsters.json.',
          );
        }
        if (!grid.isWalkable(spawn.position.x, spawn.position.y)) {
          throw ConfigException(
            'dungeons.json: room "${room.id}" spawn "${spawn.id}" berada di posisi '
            'tidak walkable (${spawn.position.x}, ${spawn.position.y}).',
          );
        }
        if (spawn.isElite && spawn.isBoss) {
          throw ConfigException(
            'dungeons.json: room "${room.id}" spawn "${spawn.id}" tidak boleh '
            'sekaligus elite dan boss.',
          );
        }
        if (spawn.activationState == SpawnActivationState.onGroupCleared) {
          final trigger = spawn.activationTriggerGroup;
          if (trigger == null || !groupsInRoom.contains(trigger)) {
            throw ConfigException(
              'dungeons.json: room "${room.id}" spawn "${spawn.id}" merujuk '
              'activation_trigger_group "$trigger" yang tidak ada di room.',
            );
          }
        }
      }

      _validateRoomCompletion(room, config, groupsInRoom);
    }

    _validateDungeonGraph(dungeon);
  }

  void _validateRoomCompletion(
    RoomDefinition room,
    GameConfig config,
    Set<String> groupsInRoom,
  ) {
    bool isEliteSpawn(RoomSpawnConfig s) =>
        s.isElite || (config.monsters[s.monsterId]?.isElite ?? false);

    bool isBossSpawn(RoomSpawnConfig s) =>
        s.isBoss || (config.monsters[s.monsterId]?.isBoss ?? false);

    if (room.type == RoomType.elite && !room.spawns.any(isEliteSpawn)) {
      throw ConfigException(
        'dungeons.json: room elite "${room.id}" wajib memiliki minimal satu spawn elite.',
      );
    }
    if (room.type == RoomType.boss && !room.spawns.any(isBossSpawn)) {
      throw ConfigException(
        'dungeons.json: room boss "${room.id}" wajib memiliki minimal satu spawn boss.',
      );
    }

    final rootCondition = room.completionCondition;
    final allClauses = <RoomCompletionCondition>[
      rootCondition,
      ...rootCondition.additionalConditions,
    ];

    for (final condition in allClauses) {
      if (condition.requiredSpawnGroup != null &&
          !groupsInRoom.contains(condition.requiredSpawnGroup)) {
        throw ConfigException(
          'dungeons.json: room "${room.id}" completion_condition merujuk '
          'required_spawn_group "${condition.requiredSpawnGroup}" yang tidak ada.',
        );
      }

      if (condition.type == RoomCompletionConditionType.reachExit) {
        continue;
      }

      bool matchesGroup(RoomSpawnConfig s) =>
          condition.requiredSpawnGroup == null ||
          s.spawnGroup == condition.requiredSpawnGroup;

      final Iterable<RoomSpawnConfig> eligible;
      switch (condition.type) {
        case RoomCompletionConditionType.defeatRequiredEnemies:
          eligible = room.spawns.where((s) => s.required && matchesGroup(s));
        case RoomCompletionConditionType.defeatElite:
          eligible = room.spawns.where(
            (s) => s.required && matchesGroup(s) && isEliteSpawn(s),
          );
        case RoomCompletionConditionType.defeatBoss:
          eligible = room.spawns.where(
            (s) => s.required && matchesGroup(s) && isBossSpawn(s),
          );
        case RoomCompletionConditionType.reachExit:
          eligible = const [];
      }

      final totalTargetQty = eligible.fold<int>(
        0,
        (sum, s) => sum + s.quantity,
      );
      if (totalTargetQty <= 0) {
        throw ConfigException(
          'dungeons.json: room "${room.id}" memiliki completion_condition '
          '${condition.type.name} tanpa target spawn wajib yang memenuhi syarat.',
        );
      }
      if (condition.targetCount != null &&
          condition.targetCount! > totalTargetQty) {
        throw ConfigException(
          'dungeons.json: room "${room.id}" target_count (${condition.targetCount}) '
          'melebihi jumlah spawn target ($totalTargetQty).',
        );
      }
    }
  }

  void _validateDungeonGraph(DungeonDefinition dungeon) {
    final visiting = <String>{};
    final visited = <String>{};
    var hasReachableExit = false;

    void dfs(String roomId) {
      if (visited.contains(roomId)) return;
      if (!visiting.add(roomId)) {
        throw ConfigException(
          'dungeons.json: terdeteksi siklus graph room pada dungeon "${dungeon.id}" '
          'melibatkan "$roomId".',
        );
      }
      final room = dungeon.rooms[roomId]!;
      if (room.nextRoomIds.isEmpty) {
        hasReachableExit = true;
      } else {
        for (final nextId in room.nextRoomIds) {
          dfs(nextId);
        }
      }
      visiting.remove(roomId);
      visited.add(roomId);
    }

    dfs(dungeon.startRoomId);
    if (!hasReachableExit) {
      throw ConfigException(
        'dungeons.json: dungeon "${dungeon.id}" tidak memiliki jalur menuju room akhir.',
      );
    }
  }

  void _validateProgression(ProgressionConfig progression) {
    if (progression.maxLevel != null && progression.maxLevel! < 1) {
      throw const ConfigException(
        'game_config.json: progression.max_level harus >= 1 atau null.',
      );
    }
    if (progression.expCurve.base <= 0) {
      throw const ConfigException(
        'game_config.json: progression.exp.base harus > 0.',
      );
    }
    switch (progression.expCurve.type) {
      case ExpCurveType.polynomial:
        final exp = progression.expCurve.exponent;
        if (exp == null || exp <= 0) {
          throw const ConfigException(
            'game_config.json: progression.exp.exponent harus > 0.',
          );
        }
      case ExpCurveType.exponential:
        final growth = progression.expCurve.growth;
        if (growth == null || growth < 1.0) {
          throw const ConfigException(
            'game_config.json: progression.exp.growth harus >= 1.0.',
          );
        }
    }
  }

  void _validateDifficulty(DifficultyConfig difficulty) {
    void requireFiniteRange(
      String field,
      double value, {
      required double min,
      required double max,
    }) {
      if (!value.isFinite || value < min || value > max) {
        throw ConfigException(
          'game_config.json: difficulty.$field tidak valid '
          '(nilai: $value, rentang: $min..$max).',
        );
      }
    }

    requireFiniteRange(
      'cycle_per_rank',
      difficulty.cyclePerRank,
      min: 0.0,
      max: 10.0,
    );
    requireFiniteRange(
      'ascension_multiplier',
      difficulty.ascensionMultiplier,
      min: 1.0,
      max: 100.0,
    );
    void validateExponents(String prefix, StatExponentsConfig exp) {
      requireFiniteRange('$prefix.hp', exp.hp, min: 0.0, max: 5.0);
      requireFiniteRange('$prefix.atk', exp.atk, min: 0.0, max: 5.0);
      requireFiniteRange('$prefix.def', exp.def, min: 0.0, max: 5.0);
    }

    validateExponents('stat_exponents', difficulty.statExponents);
    if (difficulty.cycleStatExponents != null) {
      validateExponents('cycle_stat_exponents', difficulty.cycleStatExponents!);
    }
    if (difficulty.cycleLevelStep != null &&
        (difficulty.cycleLevelStep! < 0 ||
            difficulty.cycleLevelStep! > 10000)) {
      throw ConfigException(
        'game_config.json: difficulty.cycle_level_step harus berada di rentang '
        '0..10000 (nilai: ${difficulty.cycleLevelStep}).',
      );
    }
    requireFiniteRange(
      'reward_exponent',
      difficulty.rewardExponent,
      min: 0.0,
      max: 5.0,
    );
    requireFiniteRange(
      'drop.rare_chance_per_rank',
      difficulty.drop.rareChancePerRank,
      min: 0.0,
      max: 5.0,
    );
    requireFiniteRange(
      'drop.max_chance_multiplier',
      difficulty.drop.maxChanceMultiplier,
      min: 1.0,
      max: 20.0,
    );
    requireFiniteRange(
      'drop.roll_bonus_per_rank',
      difficulty.drop.rollBonusPerRank,
      min: 0.0,
      max: 1.0,
    );
    requireFiniteRange(
      'drop.max_roll_bonus',
      difficulty.drop.maxRollBonus,
      min: 0.0,
      max: 2.0,
    );
    requireFiniteRange(
      'max_multiplier',
      difficulty.maxMultiplier,
      min: 1.0,
      max: DifficultyConfig.technicalMaxMultiplierLimit,
    );
  }

  void _validateFarming(FarmingConfig farming) {
    if (farming.deathLoopSuggestAfter < 1) {
      throw ConfigException(
        'game_config.json: farming.death_loop_suggest_after harus >= 1 '
        '(nilai: ${farming.deathLoopSuggestAfter}).',
      );
    }
  }

  void _validateDungeonCatalog(GameConfig config) {
    final dungeons = config.dungeons;
    if (dungeons.isEmpty) return;

    final seenOrders = <int>{};
    var ascensionCount = 0;

    for (final dungeon in dungeons.values) {
      if (!dungeon.difficultyScale.isFinite || dungeon.difficultyScale < 0.1) {
        throw ConfigException(
          'dungeons.json: dungeon "${dungeon.id}" memiliki difficulty_scale '
          'tidak valid (${dungeon.difficultyScale}).',
        );
      }
      if (dungeon.order < 1) {
        throw ConfigException(
          'dungeons.json: dungeon "${dungeon.id}" harus memiliki order >= 1 '
          '(nilai: ${dungeon.order}).',
        );
      }
      if (!seenOrders.add(dungeon.order)) {
        throw ConfigException(
          'dungeons.json: order dungeon ganda (${dungeon.order}) pada '
          '"${dungeon.id}".',
        );
      }
      if (dungeon.recommendedLevel < 1) {
        throw ConfigException(
          'dungeons.json: dungeon "${dungeon.id}" harus memiliki '
          'recommended_level >= 1 (nilai: ${dungeon.recommendedLevel}).',
        );
      }

      if (dungeon.isAscension) {
        ascensionCount++;
        if (ascensionCount > 1) {
          throw const ConfigException(
            'dungeons.json: maksimal hanya boleh ada satu dungeon ascension.',
          );
        }
        final baseId = dungeon.baseDungeonId;
        if (baseId == null || baseId.isEmpty) {
          throw ConfigException(
            'dungeons.json: dungeon ascension "${dungeon.id}" wajib '
            'memiliki base_dungeon_id.',
          );
        }
        if (baseId == dungeon.id) {
          throw ConfigException(
            'dungeons.json: dungeon ascension "${dungeon.id}" tidak boleh '
            'merujuk dirinya sendiri sebagai base_dungeon_id.',
          );
        }
        final base = dungeons[baseId];
        if (base == null || !base.isNormal) {
          throw ConfigException(
            'dungeons.json: dungeon ascension "${dungeon.id}" merujuk '
            'base_dungeon_id "$baseId" yang tidak ada atau bukan bertipe normal.',
          );
        }
      } else if (dungeon.baseDungeonId != null) {
        throw ConfigException(
          'dungeons.json: dungeon normal "${dungeon.id}" tidak boleh '
          'memiliki base_dungeon_id.',
        );
      }
    }

    for (var expected = 1; expected <= dungeons.length; expected++) {
      if (!seenOrders.contains(expected)) {
        throw ConfigException(
          'dungeons.json: order dungeon harus berurutan 1..${dungeons.length} '
          '(order $expected hilang).',
        );
      }
    }

    // Periksa referensi & siklus unlock sebelum syarat urutan.
    final visited = <String>{};
    final visiting = <String>{};
    for (final dungeon in dungeons.values) {
      final reqId = dungeon.unlockRequiresDungeonId;
      if (reqId != null && !dungeons.containsKey(reqId)) {
        throw ConfigException(
          'dungeons.json: dungeon "${dungeon.id}" merujuk '
          'unlock_requires_dungeon_id "$reqId" yang tidak ada.',
        );
      }
    }
    for (final dungeon in dungeons.values) {
      var cursor = dungeon.id;
      visiting.clear();
      while (true) {
        if (visited.contains(cursor)) break;
        if (!visiting.add(cursor)) {
          throw ConfigException(
            'dungeons.json: terdeteksi siklus unlock_requires_dungeon_id '
            'melibatkan "$cursor".',
          );
        }
        final next = dungeons[cursor]?.unlockRequiresDungeonId;
        if (next == null) break;
        cursor = next;
      }
      visited.addAll(visiting);

      final reqId = dungeon.unlockRequiresDungeonId;
      if (reqId != null) {
        final req = dungeons[reqId]!;
        if (req.order >= dungeon.order) {
          throw ConfigException(
            'dungeons.json: dungeon "${dungeon.id}" (order ${dungeon.order}) '
            'membutuhkan "$reqId" (order ${req.order}) yang order-nya tidak '
            'lebih kecil.',
          );
        }
      }
    }
  }

  void _validateShop(GameConfig config) {
    final shop = config.shop;
    final maxSellRatio = shop.sell.maxSellRatio;
    if (!maxSellRatio.isFinite || maxSellRatio <= 0 || maxSellRatio > 1.0) {
      throw ConfigException(
        'shop.json: sell.max_sell_ratio harus berada di (0, 1] '
        '(nilai: $maxSellRatio).',
      );
    }
    if (shop.entries.isEmpty) return;

    final seenIds = <String>{};
    final minPriceByRarity = <ItemRarity, int>{};
    final maxPriceByRarity = <ItemRarity, int>{};

    for (final entry in shop.entries) {
      if (entry.id.trim().isEmpty) {
        throw const ConfigException('shop.json: id entri tidak boleh kosong.');
      }
      if (!seenIds.add(entry.id)) {
        throw ConfigException('shop.json: id entri duplikat "${entry.id}".');
      }
      if (entry.price <= 0) {
        throw ConfigException(
          'shop.json: entri "${entry.id}" memiliki price <= 0 (${entry.price}).',
        );
      }
      if (entry.purchaseLimit != null && entry.purchaseLimit! <= 0) {
        throw ConfigException(
          'shop.json: entri "${entry.id}" memiliki purchase_limit <= 0 '
          '(${entry.purchaseLimit}).',
        );
      }

      final item = config.items[entry.itemId];
      if (item == null) {
        throw ConfigException(
          'shop.json: entri "${entry.id}" merujuk item "${entry.itemId}" '
          'yang tidak ada di items.json.',
        );
      }
      // Consumable (mis. small_potion) belum memiliki fungsi di gameplay,
      // sehingga tidak boleh dijual di shop sampai sistem consumable tersedia.
      if (item.category == ItemCategory.consumable) {
        throw ConfigException(
          'shop.json: entri "${entry.id}" merujuk consumable "${item.id}" '
          'yang belum memiliki fungsi di game.',
        );
      }
      if (item.category == ItemCategory.equipment && item.equipment == null) {
        throw ConfigException(
          'shop.json: entri "${entry.id}" merujuk equipment "${item.id}" '
          'yang tidak memiliki data equipment.',
        );
      }
      if (item.sellValue > entry.price * maxSellRatio + 1e-9) {
        throw ConfigException(
          'shop.json: entri "${entry.id}" memiliki sell_value (${item.sellValue}) '
          'melebihi max_sell_ratio ($maxSellRatio) x price (${entry.price}).',
        );
      }

      for (final req in entry.requirements) {
        switch (req) {
          case MinLevelRequirement(:final minLevel):
            if (minLevel < 1) {
              throw ConfigException(
                'shop.json: entri "${entry.id}" memiliki min_level < 1 ($minLevel).',
              );
            }
          case DungeonClearedRequirement(:final dungeonId):
            if (config.dungeons.isNotEmpty &&
                !config.dungeons.containsKey(dungeonId)) {
              throw ConfigException(
                'shop.json: entri "${entry.id}" merujuk dungeon_cleared '
                '"$dungeonId" yang tidak ada di dungeons.json.',
              );
            }
          case MinAscensionRankRequirement(:final minRank):
            if (minRank < 0) {
              throw ConfigException(
                'shop.json: entri "${entry.id}" memiliki min_ascension_rank < 0 '
                '($minRank).',
              );
            }
        }
      }

      final prevMin = minPriceByRarity[item.rarity];
      final prevMax = maxPriceByRarity[item.rarity];
      if (prevMin == null || entry.price < prevMin) {
        minPriceByRarity[item.rarity] = entry.price;
      }
      if (prevMax == null || entry.price > prevMax) {
        maxPriceByRarity[item.rarity] = entry.price;
      }
    }

    // Pita harga harus monoton: harga minimum rarity lebih tinggi > harga
    // maksimum rarity di bawahnya.
    const rarityOrder = [
      ItemRarity.common,
      ItemRarity.uncommon,
      ItemRarity.rare,
      ItemRarity.epic,
      ItemRarity.legendary,
    ];
    ItemRarity? lowerRarity;
    int? lowerMaxPrice;
    for (final rarity in rarityOrder) {
      final minPrice = minPriceByRarity[rarity];
      final maxPrice = maxPriceByRarity[rarity];
      if (minPrice == null || maxPrice == null) continue;
      if (lowerMaxPrice != null && minPrice <= lowerMaxPrice) {
        throw ConfigException(
          'shop.json: pita harga tidak monoton — harga minimum ${rarity.name} '
          '($minPrice) harus > harga maksimum ${lowerRarity!.name} ($lowerMaxPrice).',
        );
      }
      lowerRarity = rarity;
      lowerMaxPrice = maxPrice;
    }
  }
}
