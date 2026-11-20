import 'dart:io';
import 'dart:math' as math;

import 'package:echoes_of_aether/data/models/gacha_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/domain/entities/equipment.dart';
import 'package:echoes_of_aether/domain/entities/equipment_config.dart';
import 'package:echoes_of_aether/domain/entities/gacha_config.dart';
import 'package:echoes_of_aether/domain/entities/item_definition.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/specialization.dart';
import 'package:echoes_of_aether/domain/entities/time_config.dart';
import 'package:echoes_of_aether/domain/services/equipment_factory.dart';
import 'package:echoes_of_aether/domain/services/gacha_service.dart';
import 'package:echoes_of_aether/domain/services/period_service.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String filename) =>
    File('assets/data/$filename').readAsStringSync();

void main() {
  late GachaConfig gachaConfig;
  late Map<String, ItemDefinition> items;
  late Map<String, SpecializationDefinition> specializations;
  late EquipmentFactory equipmentFactory;
  late PeriodService periodService;
  late GachaService gachaService;

  setUpAll(() {
    gachaConfig = const GachaConfigParser().parse(
      _readAsset('gacha_banners.json'),
    );
    items = const ItemConfigParser().parse(_readAsset('items.json'));
    specializations = const SpecializationConfigParser()
        .parse(_readAsset('specializations.json'))
        .definitions;
    equipmentFactory = const EquipmentFactory(EquipmentConfig());
    periodService = const PeriodService(config: TimeConfig());
    gachaService = GachaService(
      gachaConfig: gachaConfig,
      items: items,
      specializations: specializations,
      equipmentFactory: equipmentFactory,
      periodService: periodService,
    );
  });

  PlayerSaveSnapshot makeTestSnapshot({
    int aetherShards = 1000,
    int soulPrisms = 0,
    Set<String> unlocked = const {'vanguard', 'arcanist', 'ranger'},
    Map<String, GachaPityState> pity = const {},
    List<EquipmentInstance> equipment = const [],
  }) {
    return PlayerSaveSnapshot(
      character: const PlayerCharacterSnapshot(
        progress: PlayerProgress(level: 10, currentExp: 0, gold: 5000),
      ),
      inventory: InventorySnapshot(
        stacks: const {},
        equipment: equipment,
        equipmentCounter: equipment.length,
      ),
      currencies: {'aether_shard': aetherShards, 'soul_prism': soulPrisms},
      unlockedSpecializations: unlocked,
      gachaPityStates: pity,
    );
  }

  group('M15 Stage 2 — Banner Rotation & Active Banner Calculation', () {
    test(
      'Rotasi siklus 21 hari berputar teratur di antara 6 class dan 6 senjata',
      () {
        final epochMondayUtc = DateTime.utc(2026, 11, 16);
        final baseMs = epochMondayUtc.millisecondsSinceEpoch;

        // Siklus 0 (Hari 0 s.d. 20) -> Paladin & Dawn's Aegis Blade
        final cycle0 = gachaService.getActiveBannerInfo(
          bannerType: GachaBannerType.classBanner,
          nowMs: baseMs,
        );
        expect(cycle0.cycleIndex, 0);
        expect(cycle0.featuredId, 'paladin');
        expect(cycle0.standardPool, isNot(contains('paladin')));
        expect(cycle0.standardPool.length, 5);

        final cycle0W = gachaService.getActiveBannerInfo(
          bannerType: GachaBannerType.weaponBanner,
          nowMs: baseMs,
        );
        expect(cycle0W.featuredId, 'dawns_aegis_blade');

        // Siklus 1 (Hari 21) -> Voidblade & Shadowfang Twinblade
        final cycle1Ms = baseMs + const Duration(days: 21).inMilliseconds;
        final cycle1 = gachaService.getActiveBannerInfo(
          bannerType: GachaBannerType.classBanner,
          nowMs: cycle1Ms,
        );
        expect(cycle1.cycleIndex, 1);
        expect(cycle1.featuredId, 'voidblade');

        final cycle1W = gachaService.getActiveBannerInfo(
          bannerType: GachaBannerType.weaponBanner,
          nowMs: cycle1Ms,
        );
        expect(cycle1W.featuredId, 'shadowfang_twinblade');

        // Siklus 2 (Hari 42) -> Chronomancer & Hourglass of Eternity
        final cycle2Ms = baseMs + const Duration(days: 42).inMilliseconds;
        final cycle2 = gachaService.getActiveBannerInfo(
          bannerType: GachaBannerType.classBanner,
          nowMs: cycle2Ms,
        );
        expect(cycle2.cycleIndex, 2);
        expect(cycle2.featuredId, 'chronomancer');

        // Siklus 5 (Hari 105) -> Stormcaller & Thunderlord's Scepter
        final cycle5Ms = baseMs + const Duration(days: 105).inMilliseconds;
        final cycle5 = gachaService.getActiveBannerInfo(
          bannerType: GachaBannerType.classBanner,
          nowMs: cycle5Ms,
        );
        expect(cycle5.cycleIndex, 5);
        expect(cycle5.featuredId, 'stormcaller');

        // Siklus 6 (Hari 126) -> Wrap-around kembali ke Paladin
        final cycle6Ms = baseMs + const Duration(days: 126).inMilliseconds;
        final cycle6 = gachaService.getActiveBannerInfo(
          bannerType: GachaBannerType.classBanner,
          nowMs: cycle6Ms,
        );
        expect(cycle6.cycleIndex, 6);
        expect(cycle6.featuredId, 'paladin');
      },
    );

    test('Waktu reset siklus berikutnya konsisten dengan batas 21 hari', () {
      final baseMs = DateTime.utc(2026, 11, 16, 4).millisecondsSinceEpoch;
      final nextReset = gachaService.getNextResetMs(baseMs);
      expect(nextReset, greaterThan(baseMs));

      final diffDays = (nextReset - baseMs) / (1000 * 60 * 60 * 24);
      expect(diffDays, closeTo(21.0, 1.0));
    });
  });

  group('M15 Stage 2 — Pull Currency & Validation', () {
    test('1x pull mengurangi 30 Shard, 10x pull mengurangi 300 Shard', () {
      final rng = math.Random(42);
      final snap = makeTestSnapshot(aetherShards: 350);
      final nowMs = DateTime.utc(2026, 11, 16).millisecondsSinceEpoch;

      final res1 = gachaService.pullOnce(
        snapshot: snap,
        bannerType: GachaBannerType.classBanner,
        nowMs: nowMs,
        random: rng,
      );
      expect(res1.isSuccess, isTrue);
      expect(res1.shardsSpent, 30);
      expect(res1.remainingShards, 320);
      expect(res1.updatedSnapshot!.currencies['aether_shard'], 320);

      final res10 = gachaService.pullTen(
        snapshot: res1.updatedSnapshot!,
        bannerType: GachaBannerType.classBanner,
        nowMs: nowMs,
        random: rng,
      );
      expect(res10.isSuccess, isTrue);
      expect(res10.shardsSpent, 300);
      expect(res10.remainingShards, 20);
      expect(res10.updatedSnapshot!.currencies['aether_shard'], 20);
    });

    test('Pull gagal jika Aether Shard tidak mencukupi', () {
      final rng = math.Random(42);
      final snap = makeTestSnapshot(aetherShards: 25);
      final nowMs = DateTime.utc(2026, 11, 16).millisecondsSinceEpoch;

      final res = gachaService.pullOnce(
        snapshot: snap,
        bannerType: GachaBannerType.classBanner,
        nowMs: nowMs,
        random: rng,
      );
      expect(res.isSuccess, isFalse);
      expect(res.status, GachaPullStatus.insufficientAetherShards);
      expect(res.updatedSnapshot, isNull);
    });

    test('Pull gagal jika tas perlengkapan penuh', () {
      final rng = math.Random(42);
      // Buat tas penuh dengan 100 equipment dummy
      final fullEquipment = List.generate(
        100,
        (i) => EquipmentInstance(
          id: 'eq_$i',
          definitionId: 'rusty_sword',
          slot: EquipmentSlot.weapon,
          rarity: ItemRarity.common,
          rolledStats: EquipmentStats.zero,
        ),
      );
      final snap = makeTestSnapshot(
        aetherShards: 500,
        equipment: fullEquipment,
      );
      final nowMs = DateTime.utc(2026, 11, 16).millisecondsSinceEpoch;

      final res = gachaService.pullOnce(
        snapshot: snap,
        bannerType: GachaBannerType.weaponBanner,
        nowMs: nowMs,
        random: rng,
      );
      expect(res.isSuccess, isFalse);
      expect(res.status, GachaPullStatus.inventoryFull);
    });
  });

  group('M15 Stage 2 — Pity System & Rate-Up 50/50', () {
    test('Class Banner mencapai Hard Pity tepat di pull ke-40 jika belum dapat 5★', () {
      // RNG seed yang selalu me-roll nilai tinggi (tidak memicu base rate 1.5%)
      // dan 50/50 memenangkan featured class
      final nowMs = DateTime.utc(2026, 11, 16).millisecondsSinceEpoch;
      var snap = makeTestSnapshot(
        aetherShards: 3000,
        pity: {
          'class': const GachaPityState(bannerType: 'class', pullCount: 39),
        },
      );

      final rng = math.Random(12345);
      final res = gachaService.pullOnce(
        snapshot: snap,
        bannerType: GachaBannerType.classBanner,
        nowMs: nowMs,
        random: rng,
      );

      expect(res.isSuccess, isTrue);
      expect(res.pulls.length, 1);
      final pull = res.pulls.first;
      expect(pull.isMythical, isTrue);
      expect(pull.isSpecialization, isTrue);
      // Pity counter harus ter-reset kembali ke 0
      expect(res.updatedPityState!.pullCount, 0);
      expect(res.updatedSnapshot!.gachaPityStates['class']!.pullCount, 0);
    });

    test('Weapon Banner mencapai Hard Pity tepat di pull ke-30 jika belum dapat 5★', () {
      final nowMs = DateTime.utc(2026, 11, 16).millisecondsSinceEpoch;
      var snap = makeTestSnapshot(
        aetherShards: 3000,
        pity: {
          'weapon': const GachaPityState(bannerType: 'weapon', pullCount: 29),
        },
      );

      final rng = math.Random(12345);
      final res = gachaService.pullOnce(
        snapshot: snap,
        bannerType: GachaBannerType.weaponBanner,
        nowMs: nowMs,
        random: rng,
      );

      expect(res.isSuccess, isTrue);
      final pull = res.pulls.first;
      expect(pull.isMythical, isTrue);
      expect(pull.isSpecialization, isFalse);
      expect(res.updatedPityState!.pullCount, 0);
    });

    test('Kalah 50/50 mengaktifkan status guarantee untuk 5★ berikutnya', () {
      final nowMs = DateTime.utc(2026, 11, 16).millisecondsSinceEpoch;
      // Pity 39 (akan memicu pity di pull 40) dengan isGuaranteed = false
      var snap = makeTestSnapshot(
        aetherShards: 5000,
        pity: {
          'class': const GachaPityState(
            bannerType: 'class',
            pullCount: 39,
            isGuaranteed: false,
          ),
        },
      );

      // Cari seed yang kalah 50/50 (random.nextDouble() >= 0.5)
      math.Random? loseRng;
      for (var seed = 0; seed < 1000; seed++) {
        final r = math.Random(seed);
        // Tarikan pertama (50/50 check)
        final won5050 = r.nextDouble() < 0.5;
        if (!won5050) {
          loseRng = math.Random(seed);
          break;
        }
      }
      expect(loseRng, isNotNull);

      final res1 = gachaService.pullOnce(
        snapshot: snap,
        bannerType: GachaBannerType.classBanner,
        nowMs: nowMs,
        random: loseRng!,
      );
      expect(res1.isSuccess, isTrue);
      final pull1 = res1.pulls.first;
      expect(pull1.isMythical, isTrue);
      expect(pull1.isFeatured, isFalse); // Kalah 50/50
      expect(
        res1.updatedPityState!.isGuaranteed,
        isTrue,
      ); // Terjamin di 5★ selanjutnya!

      // Pull berikutnya dengan guarantee aktif harus 100% Featured!
      var snapGuaranteed = res1.updatedSnapshot!.copyWith(
        gachaPityStates: {
          'class': const GachaPityState(
            bannerType: 'class',
            pullCount: 39,
            isGuaranteed: true,
          ),
        },
      );
      final res2 = gachaService.pullOnce(
        snapshot: snapGuaranteed,
        bannerType: GachaBannerType.classBanner,
        nowMs: nowMs,
        random: math.Random(999),
      );
      expect(res2.isSuccess, isTrue);
      final pull2 = res2.pulls.first;
      expect(pull2.isMythical, isTrue);
      expect(pull2.isFeatured, isTrue); // Wajib featured karena guarantee!
      expect(pull2.itemId, 'paladin');
      expect(
        res2.updatedPityState!.isGuaranteed,
        isFalse,
      ); // Reset setelah dapat featured
    });
  });

  group('M15 Stage 2 — Class Duplicate Conversion to Soul Prism', () {
    test('Class pertama kali ditarik masuk unlockedSpecializations tanpa Soul Prism', () {
      final nowMs = DateTime.utc(2026, 11, 16).millisecondsSinceEpoch;
      // Menjamin featured Paladin di pull ke-40
      final snap = makeTestSnapshot(
        aetherShards: 500,
        unlocked: {'vanguard', 'arcanist', 'ranger'},
        pity: {
          'class': const GachaPityState(
            bannerType: 'class',
            pullCount: 39,
            isGuaranteed: true,
          ),
        },
      );

      final res = gachaService.pullOnce(
        snapshot: snap,
        bannerType: GachaBannerType.classBanner,
        nowMs: nowMs,
        random: math.Random(1),
      );

      expect(res.isSuccess, isTrue);
      final pull = res.pulls.first;
      expect(pull.itemId, 'paladin');
      expect(pull.isDuplicate, isFalse);
      expect(pull.soulPrismGranted, 0);
      expect(res.soulPrismGranted, 0);
      expect(res.newClassesUnlocked, contains('paladin'));
      expect(res.updatedSnapshot!.unlockedSpecializations, contains('paladin'));
    });

    test('Class duplikat otomatis terkonversi menjadi 1x Soul Prism', () {
      final nowMs = DateTime.utc(2026, 11, 16).millisecondsSinceEpoch;
      // Pemain sudah memiliki 'paladin'
      final snap = makeTestSnapshot(
        aetherShards: 500,
        soulPrisms: 0,
        unlocked: {'vanguard', 'arcanist', 'ranger', 'paladin'},
        pity: {
          'class': const GachaPityState(
            bannerType: 'class',
            pullCount: 39,
            isGuaranteed: true,
          ),
        },
      );

      final res = gachaService.pullOnce(
        snapshot: snap,
        bannerType: GachaBannerType.classBanner,
        nowMs: nowMs,
        random: math.Random(1),
      );

      expect(res.isSuccess, isTrue);
      final pull = res.pulls.first;
      expect(pull.itemId, 'paladin');
      expect(pull.isDuplicate, isTrue);
      expect(pull.soulPrismGranted, 1);
      expect(res.soulPrismGranted, 1);
      expect(res.remainingSoulPrism, 1);
      expect(res.updatedSnapshot!.currencies['soul_prism'], 1);
    });
  });

  group('M15 Stage 2 — Sanctuary Exchange Shop', () {
    test(
      'Tukar 2 Soul Prism untuk Senjata Mythical berhasil dan mengurangi saldo',
      () {
        final snap = makeTestSnapshot(soulPrisms: 5);
        final rng = math.Random(1);

        final res = gachaService.exchangeSanctuaryWeapon(
          snapshot: snap,
          weaponId: 'shadowfang_twinblade',
          random: rng,
        );

        expect(res.isSuccess, isTrue);
        expect(res.soulPrismSpent, 2);
        expect(res.remainingSoulPrism, 3);
        expect(res.grantedEquipment, isNotNull);
        expect(res.grantedEquipment!.definitionId, 'shadowfang_twinblade');
        expect(res.grantedEquipment!.rarity, ItemRarity.mythical);
        expect(res.updatedSnapshot!.currencies['soul_prism'], 3);
        expect(res.updatedSnapshot!.inventory.equipment.length, 1);
      },
    );

    test('Tukar Senjata Mythical gagal jika Soul Prism kurang dari 2', () {
      final snap = makeTestSnapshot(soulPrisms: 1);
      final res = gachaService.exchangeSanctuaryWeapon(
        snapshot: snap,
        weaponId: 'dawns_aegis_blade',
        random: math.Random(1),
      );
      expect(res.isSuccess, isFalse);
      expect(res.status, SanctuaryExchangeStatus.insufficientSoulPrisms);
    });

    test(
      'Tukar 3 Soul Prism untuk Class Mythical berhasil dan membuka class',
      () {
        final snap = makeTestSnapshot(
          soulPrisms: 4,
          unlocked: {'vanguard', 'arcanist', 'ranger'},
        );

        final res = gachaService.exchangeSanctuaryClass(
          snapshot: snap,
          classId: 'voidblade',
        );

        expect(res.isSuccess, isTrue);
        expect(res.soulPrismSpent, 3);
        expect(res.remainingSoulPrism, 1);
        expect(res.unlockedClassId, 'voidblade');
        expect(res.updatedSnapshot!.currencies['soul_prism'], 1);
        expect(
          res.updatedSnapshot!.unlockedSpecializations,
          contains('voidblade'),
        );
      },
    );

    test('Tukar Class Mythical gagal jika class sudah dimiliki', () {
      final snap = makeTestSnapshot(
        soulPrisms: 10,
        unlocked: {'vanguard', 'arcanist', 'ranger', 'paladin'},
      );

      final res = gachaService.exchangeSanctuaryClass(
        snapshot: snap,
        classId: 'paladin',
      );

      expect(res.isSuccess, isFalse);
      expect(res.status, SanctuaryExchangeStatus.alreadyOwned);
      expect(res.updatedSnapshot, isNull);
    });
  });

  group('M15 Stage 2 — 1000-Pull Monte Carlo Verification', () {
    test('Simulasi 1000 pull Class Banner menjaga batasan hard pity dan integritas data', () {
      final nowMs = DateTime.utc(2026, 11, 16).millisecondsSinceEpoch;
      var snap = makeTestSnapshot(aetherShards: 50000);
      final rng = math.Random(2026);

      var mythicalCount = 0;
      var duplicateCount = 0;
      var maxObservedPity = 0;

      for (var i = 0; i < 100; i++) {
        // 100 x 10 pulls = 1000 pulls
        final res = gachaService.pullTen(
          snapshot: snap,
          bannerType: GachaBannerType.classBanner,
          nowMs: nowMs,
          random: rng,
        );

        expect(
          res.isSuccess,
          isTrue,
          reason:
              'Failed at iteration $i with status: ${res.status} (${res.errorMessage})',
        );
        // Kosongkan equipment tas di setiap tarikan 10x agar tas tidak penuh selama simulasi 1000 pull
        snap = res.updatedSnapshot!.copyWith(
          inventory: InventorySnapshot(
            stacks: res.updatedSnapshot!.inventory.stacks,
            equipment: const [],
            equipmentCounter: res.updatedSnapshot!.inventory.equipmentCounter,
          ),
        );

        for (final pull in res.pulls) {
          if (pull.isMythical) {
            mythicalCount++;
            if (pull.isDuplicate) duplicateCount++;
          }
        }
        if (res.updatedPityState!.pullCount > maxObservedPity) {
          maxObservedPity = res.updatedPityState!.pullCount;
        }
      }

      // Hard pity tidak boleh pernah melebihi 40
      expect(maxObservedPity, lessThanOrEqualTo(40));
      // Dari 1000 pull dengan hard pity 40, minimal dapat 1000 / 40 = 25 5★ (rata-rata 30-40)
      expect(mythicalCount, greaterThanOrEqualTo(25));
      expect(
        mythicalCount,
        lessThan(100),
      ); // Tidak terjadi overflow atau rate 100%
      // Duplikasi terjadi karena total hanya ada 6 class mythical
      expect(duplicateCount, greaterThan(0));
      // Saldo Soul Prism konsisten dengan jumlah duplikat
      expect(snap.currencies['soul_prism'], equals(duplicateCount));
      // Saldo Aether Shard tersisa sesuai perhitungan: 50.000 - (100 * 300) = 20.000
      expect(snap.currencies['aether_shard'], equals(20000));
    });
  });
}
