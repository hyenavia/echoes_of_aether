import 'package:flutter/foundation.dart';

import '../../../domain/entities/equipment.dart';
import '../../../domain/entities/item_definition.dart';

/// Registry pemetaan sprite pixel art untuk item, perlengkapan, dan resource.
/// Berisi referensi ke file PNG 32x32 (64x64) di `assets/sprite/`.
@immutable
abstract final class ItemSpriteRegistry {
  /// Pemetaan itemId -> asset path di assets/sprite/
  static const Map<String, String> itemSprites = {
    // Materials & Consumables
    'slime_gel': 'assets/sprite/fc167.png',
    'goblin_ear': 'assets/sprite/fc237.png',
    'forest_herb': 'assets/sprite/fc245.png',
    'wolf_fang': 'assets/sprite/fc233.png',
    'corrupted_bark': 'assets/sprite/fc252.png',
    'small_potion': 'assets/sprite/fc265.png',
    'ancient_fragment': 'assets/sprite/fc254.png',
    'aether_scrap': 'assets/sprite/fc255.png',
    'boss_remnant': 'assets/sprite/fc194.png',
    'abyssal_remnant': 'assets/sprite/fc194.png',
    'void_essence': 'assets/sprite/fc254.png',
    'aether_sigil': 'assets/sprite/fc600.png',

    // Weapons
    'rusty_sword': 'assets/sprite/fc1447.png',
    'hunters_bow': 'assets/sprite/fc1100.png',
    'composite_warbow': 'assets/sprite/fc1099.png',
    'windforce_bow': 'assets/sprite/fc1100.png',
    'celestial_recurve': 'assets/sprite/fc1100.png',
    'apprentice_staff': 'assets/sprite/fc295.png',
    'sage_scepter': 'assets/sprite/fc295.png',
    'archmage_staff': 'assets/sprite/fc295.png',
    'cosmic_staff': 'assets/sprite/fc295.png',
    'ranger_blade': 'assets/sprite/fc1452.png',
    'aether_blade': 'assets/sprite/fc2147.png',
    'celestial_blade': 'assets/sprite/fc1528.png',
    'event_dawn_blade': 'assets/sprite/fc1527.png',
    'event_eclipse_blade': 'assets/sprite/fc1456.png',
    'abyssal_blade': 'assets/sprite/fc1456.png',
    'abyssal_bow': 'assets/sprite/fc1100.png',
    'abyssal_staff': 'assets/sprite/fc295.png',
    'void_cleaver': 'assets/sprite/fc1528.png',

    // Mythical Signature Weapons
    'dawns_aegis_blade': 'assets/sprite/fc1529.png',
    'shadowfang_twinblade': 'assets/sprite/fc1455.png',
    'hourglass_of_eternity': 'assets/sprite/fc296.png',
    'aether_railgun': 'assets/sprite/fc1101.png',
    'scythe_of_the_harvester': 'assets/sprite/fc1450.png',
    'thunderlords_scepter': 'assets/sprite/fc294.png',

    // Helms
    'leather_cap': 'assets/sprite/fc2003.png',
    'iron_helm': 'assets/sprite/fc2052.png',
    'knight_helm': 'assets/sprite/fc2053.png',
    'aether_helm': 'assets/sprite/fc2158.png',
    'celestial_crown': 'assets/sprite/fc2171.png',
    'event_warden_helm': 'assets/sprite/fc2054.png',
    'event_crown_of_dusk': 'assets/sprite/fc2169.png',
    'abyssal_cowl': 'assets/sprite/fc2054.png',
    'void_crown': 'assets/sprite/fc2169.png',

    // Body Armor
    'padded_vest': 'assets/sprite/fc2019.png',
    'forest_mail': 'assets/sprite/fc2020.png',
    'knight_armor': 'assets/sprite/fc2051.png',
    'aether_armor': 'assets/sprite/fc2165.png',
    'celestial_plate': 'assets/sprite/fc2164.png',
    'event_aegis_mail': 'assets/sprite/fc2050.png',
    'event_bulwark_plate': 'assets/sprite/fc2174.png',
    'void_carapace': 'assets/sprite/fc2164.png',

    // Accessories
    'copper_ring': 'assets/sprite/fc117.png',
    'mossy_charm': 'assets/sprite/fc2062.png',
    'guardian_amulet': 'assets/sprite/fc2065.png',
    'swift_charm': 'assets/sprite/fc293.png',
    'heart_of_aether': 'assets/sprite/fc165.png',
    'aether_ring': 'assets/sprite/fc2185.png',
    'event_ember_ring': 'assets/sprite/fc2186.png',
    'event_aether_pendant': 'assets/sprite/fc2177.png',
    'abyssal_eye': 'assets/sprite/fc2185.png',
  };

  /// Pemetaan hub icon & resource -> asset path
  static const Map<String, String> hubSprites = {
    'gold': 'assets/sprite/fc131.png',
    'aether_shards': 'assets/sprite/fc255.png',
    'ancient_embers': 'assets/sprite/fc194.png',
    'mystery_box': 'assets/sprite/fc6.png',
    'altar_blessing': 'assets/sprite/fc37.png',
    'blacksmith': 'assets/sprite/fc39.png',
    'bag_expansion': 'assets/sprite/fc21.png',
    'dungeon_portal': 'assets/sprite/fc36.png',
    'settings': 'assets/sprite/fc2.png',
  };

  /// Pemetaan skill id -> asset path di assets/sprite/
  static const Map<String, String> skillSprites = {
    // Active Skills
    'power_strike': 'assets/sprite/fc1452.png',
    'healing_pulse': 'assets/sprite/fc364.png',
    'crushing_blow': 'assets/sprite/fc1413.png',
    'aether_burst': 'assets/sprite/fc604.png',
    'meteor_fall': 'assets/sprite/fc345.png',
    'quick_shot': 'assets/sprite/fc1100.png',
    'volley': 'assets/sprite/fc1099.png',
    'radiant_smite': 'assets/sprite/fc1529.png',
    'divine_judgment': 'assets/sprite/fc345.png',
    'phantom_slash': 'assets/sprite/fc1455.png',
    'void_execution': 'assets/sprite/fc1456.png',
    'time_bolt': 'assets/sprite/fc296.png',
    'chrono_collapse': 'assets/sprite/fc604.png',
    'rapid_fire': 'assets/sprite/fc1101.png',
    'aether_barrage': 'assets/sprite/fc1099.png',
    'death_bolt': 'assets/sprite/fc1450.png',
    'soul_eruption': 'assets/sprite/fc345.png',
    'lightning_arc': 'assets/sprite/fc294.png',
    'thunderstorm': 'assets/sprite/fc604.png',

    // Passive Skills
    'vitality': 'assets/sprite/fc260.png',
    'focus': 'assets/sprite/fc381.png',
    'iron_resolve': 'assets/sprite/fc2014.png',
    'mana_attunement': 'assets/sprite/fc292.png',
    'hawk_eye': 'assets/sprite/fc382.png',
    'sacred_bulwark': 'assets/sprite/fc2014.png',
    'shadow_mastery': 'assets/sprite/fc381.png',
    'temporal_flow': 'assets/sprite/fc292.png',
    'eagle_caliber': 'assets/sprite/fc382.png',
    'soul_harvest': 'assets/sprite/fc260.png',
    'tempest_aura': 'assets/sprite/fc292.png',
  };

  /// Pemetaan slot equipment placeholder -> asset path
  static const Map<String, String> slotSprites = {
    'weapon': 'assets/sprite/fc1447.png',
    'head': 'assets/sprite/fc2003.png',
    'body': 'assets/sprite/fc2019.png',
    'accessory': 'assets/sprite/fc117.png',
  };

  /// Pemetaan combat stat -> asset path
  static const Map<String, String> statSprites = {
    'hp': 'assets/sprite/fc260.png',
    'atk': 'assets/sprite/fc1447.png',
    'def': 'assets/sprite/fc2014.png',
    'crit': 'assets/sprite/fc382.png',
    'crit_rate': 'assets/sprite/fc382.png',
    'speed': 'assets/sprite/fc2028.png',
    'haste': 'assets/sprite/fc293.png',
  };

  /// Mengembalikan asset path untuk [itemId], atau `null` bila tidak terdaftar.
  static String? spriteForItem(String? itemId) {
    if (itemId == null || itemId.isEmpty) return null;
    return itemSprites[itemId.trim()];
  }

  /// Mengembalikan asset path untuk skill [skillId].
  static String? spriteForSkill(String? skillId) {
    if (skillId == null || skillId.isEmpty) return null;
    return skillSprites[skillId.trim()];
  }

  /// Mengembalikan asset path placeholder untuk [slot].
  static String? spriteForSlot(EquipmentSlot? slot) {
    if (slot == null) return null;
    return slotSprites[slot.name];
  }

  /// Mengembalikan asset path placeholder berdasarkan nama slot.
  static String? spriteForSlotName(String? slotName) {
    if (slotName == null || slotName.isEmpty) return null;
    return slotSprites[slotName.trim().toLowerCase()];
  }

  /// Mengembalikan asset path untuk stat tempur.
  static String? spriteForStat(String? statKey) {
    if (statKey == null || statKey.isEmpty) return null;
    return statSprites[statKey.trim().toLowerCase()];
  }

  /// Mengembalikan asset path fallback untuk kategori item.
  static String? spriteForCategory(ItemCategory? category) {
    if (category == null) return null;
    return switch (category) {
      ItemCategory.material => 'assets/sprite/fc254.png',
      ItemCategory.consumable => 'assets/sprite/fc265.png',
      ItemCategory.questItem => 'assets/sprite/fc600.png',
      _ => null,
    };
  }

  /// Mengembalikan asset path untuk resource / hub feature.
  static String? spriteForHub(String? key) {
    if (key == null || key.isEmpty) return null;
    return hubSprites[key.trim()];
  }
}
