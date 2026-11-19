import '../../core/errors/config_exception.dart';
import '../../domain/entities/item_definition.dart';
import '../../domain/entities/specialization.dart';
import 'json_reader.dart';
import 'stat_bonus_parser.dart';

/// Membaca dan memvalidasi specializations.json.
class SpecializationConfigParser {
  const SpecializationConfigParser();

  static const JsonReader _r = JsonReader('specializations.json');

  SpecializationConfig parse(String source) {
    final root = _r.decodeRoot(source);
    final unlockLevel = _r.integer(
      root,
      'root',
      'unlock_level',
      min: 1,
      fallback: 5,
    );
    final list = _r.list(root, 'root', 'specializations');

    final result = <String, SpecializationDefinition>{};
    for (var i = 0; i < list.length; i++) {
      final where = 'specializations[$i]';
      final map = _r.asMap(list[i], where);
      _r.ensureKnownKeys(map, where, {
        'id',
        'name',
        'description',
        'bonus',
        'attack_range',
        'unlock_level',
        'skill_affinities',
        'rarity',
        'signature_weapon_id',
      });

      final id = _r.string(map, where, 'id');
      if (result.containsKey(id)) {
        throw ConfigException('specializations.json: id ganda "$id".');
      }
      final bw = '$where.bonus';
      final specUnlockLevel = map['unlock_level'] == null
          ? null
          : _r.integer(map, where, 'unlock_level', min: 1);
      final affinities = _parseAffinities(map, where);
      final rarity = map['rarity'] == null
          ? ItemRarity.legendary
          : _parseRarity(_r.string(map, where, 'rarity'), where);
      final signatureWeaponId = map['signature_weapon_id'] == null
          ? null
          : _r.string(map, where, 'signature_weapon_id');
      result[id] = SpecializationDefinition(
        id: id,
        name: _r.string(map, where, 'name'),
        description: map['description'] == null
            ? ''
            : _r.string(map, where, 'description'),
        bonus: StatBonusParser.parse(_r, _r.asMap(map['bonus'], bw), bw),
        attackRange: map['attack_range'] == null
            ? null
            : _r.number(map, where, 'attack_range', min: 0, minExclusive: true),
        unlockLevel: specUnlockLevel,
        skillAffinities: affinities,
        rarity: rarity,
        signatureWeaponId: signatureWeaponId,
      );
    }
    return SpecializationConfig(unlockLevel: unlockLevel, definitions: result);
  }

  ItemRarity _parseRarity(String raw, String where) => switch (raw) {
    'legendary' => ItemRarity.legendary,
    'mythical' => ItemRarity.mythical,
    _ => throw ConfigException(
      'specializations.json: $where."rarity" tidak dikenal: "$raw" '
      '(pilihan: legendary, mythical).',
    ),
  };

  Map<String, double> _parseAffinities(Map<String, dynamic> map, String where) {
    final raw = map['skill_affinities'];
    if (raw == null) return const {};
    final affWhere = '$where.skill_affinities';
    final affMap = _r.asMap(raw, affWhere);
    final result = <String, double>{};
    for (final skillId in affMap.keys) {
      if (skillId.trim().isEmpty) {
        throw ConfigException(
          'specializations.json: $affWhere memiliki skill id kosong.',
        );
      }
      result[skillId] = _r.number(affMap, affWhere, skillId, min: 0, max: 2.0);
    }
    return Map.unmodifiable(result);
  }
}
