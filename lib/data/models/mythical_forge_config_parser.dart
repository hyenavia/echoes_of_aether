import '../../core/errors/config_exception.dart';
import '../../domain/entities/item_definition.dart';
import '../../domain/entities/mythical_forge_config.dart';
import 'json_reader.dart';
import 'stat_bonus_parser.dart';

/// Membaca dan memvalidasi mythical_forge.json.
class MythicalForgeConfigParser {
  const MythicalForgeConfigParser();

  static const JsonReader _r = JsonReader('mythical_forge.json');

  MythicalForgeConfig parse(String source) {
    final root = _r.decodeRoot(source);
    _r.ensureKnownKeys(root, 'root', {'sets', 'recipes'});

    final setsRaw = _r.list(root, 'root', 'sets');
    final sets = <String, MythicalSetDefinition>{};
    for (var i = 0; i < setsRaw.length; i++) {
      final where = 'sets[$i]';
      final map = _r.asMap(setsRaw[i], where);
      _r.ensureKnownKeys(map, where, {
        'id',
        'name',
        'signature_class_id',
        'two_piece_bonus',
        'two_piece_description',
        'four_piece_description',
      });
      final id = _r.string(map, where, 'id');
      if (sets.containsKey(id)) {
        throw ConfigException('mythical_forge.json: id set ganda "$id".');
      }
      final bonusWhere = '$where.two_piece_bonus';
      final bonus = StatBonusParser.parse(
        _r,
        _r.asMap(map['two_piece_bonus'], bonusWhere),
        bonusWhere,
      );
      sets[id] = MythicalSetDefinition(
        id: id,
        name: _r.string(map, where, 'name'),
        signatureClassId: _r.string(map, where, 'signature_class_id'),
        twoPieceBonus: bonus,
        twoPieceDescription: _r.string(map, where, 'two_piece_description'),
        fourPieceDescription: _r.string(map, where, 'four_piece_description'),
      );
    }

    final recipesRaw = _r.list(root, 'root', 'recipes');
    final recipes = <String, MythicalForgeRecipe>{};
    final seenTargets = <String>{};
    for (var i = 0; i < recipesRaw.length; i++) {
      final where = 'recipes[$i]';
      final map = _r.asMap(recipesRaw[i], where);
      _r.ensureKnownKeys(map, where, {
        'id',
        'target_item_id',
        'set_id',
        'required_catalyst_weapon_id',
        'sacrifice_min_rarity',
        'gold_cost',
        'materials',
      });
      final id = _r.string(map, where, 'id');
      if (recipes.containsKey(id)) {
        throw ConfigException('mythical_forge.json: id resep ganda "$id".');
      }
      final targetItemId = _r.string(map, where, 'target_item_id');
      if (!seenTargets.add(targetItemId)) {
        throw ConfigException(
          'mythical_forge.json: target_item_id ganda "$targetItemId".',
        );
      }
      final sacrificeMinRarity = map['sacrifice_min_rarity'] == null
          ? ItemRarity.legendary
          : _rarity(_r.string(map, where, 'sacrifice_min_rarity'), where);
      final goldCost = _r.integer(map, where, 'gold_cost', min: 0);

      final materialsWhere = '$where.materials';
      final materialsRaw = _r.asMap(map['materials'], materialsWhere);
      if (materialsRaw.isEmpty) {
        throw ConfigException(
          'mythical_forge.json: $materialsWhere tidak boleh kosong.',
        );
      }
      final materials = <String, int>{};
      for (final matId in materialsRaw.keys) {
        materials[matId] = _r.integer(
          materialsRaw,
          materialsWhere,
          matId,
          min: 1,
        );
      }

      recipes[id] = MythicalForgeRecipe(
        id: id,
        targetItemId: targetItemId,
        setId: _r.string(map, where, 'set_id'),
        requiredCatalystWeaponId: _r.string(
          map,
          where,
          'required_catalyst_weapon_id',
        ),
        sacrificeMinRarity: sacrificeMinRarity,
        goldCost: goldCost,
        materials: Map<String, int>.unmodifiable(materials),
      );
    }

    return MythicalForgeConfig(
      sets: Map<String, MythicalSetDefinition>.unmodifiable(sets),
      recipes: Map<String, MythicalForgeRecipe>.unmodifiable(recipes),
    );
  }

  ItemRarity _rarity(String raw, String where) => switch (raw) {
    'common' => ItemRarity.common,
    'uncommon' => ItemRarity.uncommon,
    'rare' => ItemRarity.rare,
    'epic' => ItemRarity.epic,
    'legendary' => ItemRarity.legendary,
    'mythical' => ItemRarity.mythical,
    _ => throw ConfigException(
      'mythical_forge.json: $where."sacrifice_min_rarity" tidak dikenal: "$raw" '
      '(pilihan: common, uncommon, rare, epic, legendary, mythical).',
    ),
  };
}
