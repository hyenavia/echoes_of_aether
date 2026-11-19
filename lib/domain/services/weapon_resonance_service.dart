import '../entities/equipment.dart';
import '../entities/item_definition.dart';

/// Service untuk mendeteksi dan mengelola Signature Weapon Resonance (GDD Addendum v1.4).
///
/// Resonansi aktif jika karakter memiliki specialization dan menggunakan
/// senjata Mythical yang memiliki `signatureClassId` selaras dengan specialization tersebut.
class WeaponResonanceService {
  const WeaponResonanceService();

  static const String paladin = 'paladin';
  static const String voidblade = 'voidblade';
  static const String chronomancer = 'chronomancer';
  static const String gunslinger = 'gunslinger';
  static const String necromancer = 'necromancer';
  static const String stormcaller = 'stormcaller';

  static const Set<String> allMythicalClasses = {
    paladin,
    voidblade,
    chronomancer,
    gunslinger,
    necromancer,
    stormcaller,
  };

  /// Memeriksa apakah resonansi senjata aktif untuk karakter dengan [specializationId]
  /// dan instance [equippedWeapon] berdasarkan [itemCatalog].
  bool isResonanceActive({
    required String? specializationId,
    required EquipmentInstance? equippedWeapon,
    required Map<String, ItemDefinition> itemCatalog,
  }) {
    if (specializationId == null || equippedWeapon == null) return false;
    final itemDef = itemCatalog[equippedWeapon.definitionId];
    return itemDef?.equipment?.signatureClassId == specializationId;
  }

  /// Mengembalikan id class yang resonansinya aktif, atau null jika tidak aktif.
  String? resolveActiveResonanceClassId({
    required String? specializationId,
    required EquipmentInstance? equippedWeapon,
    required Map<String, ItemDefinition> itemCatalog,
  }) {
    if (specializationId == null || equippedWeapon == null) return null;
    final itemDef = itemCatalog[equippedWeapon.definitionId];
    if (itemDef?.equipment?.signatureClassId == specializationId) {
      return specializationId;
    }
    return null;
  }

  /// Mendapatkan deskripsi efek resonansi untuk [classId].
  String? getResonanceDescription(String classId) => switch (classId) {
    paladin => 'Saat memblokir/terkena serangan, memicu holy nova yang memulihkan 5% Max HP dan memberikan damage area sebesar 35% DEF (cooldown 3 detik).',
    voidblade => 'Serangan kritikal memberi tanda Shadow Mark. Menyerang target bertanda menghasilkan True Damage (mengabaikan 100% Armor).',
    chronomancer => 'Setiap 4x penggunaan skill, membekukan (Freeze) seluruh monster biasa di ruangan selama 2 detik.',
    gunslinger => 'Jangkauan serang +2 petak. Peluru menembus seluruh monster dalam satu garis lurus tanpa pengurangan damage.',
    necromancer => 'Serangan menghasilkan +8% Lifesteal pasif. Mengalahkan musuh memanggil Minion Bayangan yang mewarisi 50% HP dan ATK hero selama 6 detik.',
    stormcaller => 'Serangan petir menyambar ke +2 musuh tambahan dan menyebabkan efek Shock (+15% damage diterima selama 4 detik).',
    _ => null,
  };
}
