import 'dart:convert';
import 'dart:io';

import 'package:echoes_of_aether/core/errors/config_exception.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_validator.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/currency_config.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:echoes_of_aether/domain/services/currency_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurrencyService', () {
    test('grant dua kali dengan claimId sama hanya menaikkan saldo sekali', () {
      final service = CurrencyService(definitions: CurrencyDefinition.defaults);
      expect(service.balance(kAetherShardCurrencyId), 0);

      final first = service.grant(
        kAetherShardCurrencyId,
        50,
        claimId: 'bossquest:daily_boss:2026-11-16',
      );
      expect(first.isSuccess, isTrue);
      expect(first.alreadyClaimed, isFalse);
      expect(first.delta, 50);
      expect(first.balanceAfter, 50);
      expect(service.balance(kAetherShardCurrencyId), 50);

      final second = service.grant(
        kAetherShardCurrencyId,
        50,
        claimId: 'bossquest:daily_boss:2026-11-16',
      );
      expect(second.isSuccess, isTrue);
      expect(second.alreadyClaimed, isTrue);
      expect(second.delta, 0);
      expect(second.balanceAfter, 50);
      expect(service.balance(kAetherShardCurrencyId), 50);
    });

    test(
      'spend gagal (saldo kurang, amount <= 0, unknown) tanpa efek samping',
      () {
        final service = CurrencyService(
          definitions: CurrencyDefinition.defaults,
          initialBalances: const {kAetherShardCurrencyId: 40},
        );

        final insufficient = service.spend(kAetherShardCurrencyId, 41);
        expect(insufficient.isSuccess, isFalse);
        expect(
          insufficient.failureReason,
          CurrencyFailureReason.insufficientBalance,
        );
        expect(service.balance(kAetherShardCurrencyId), 40);

        final zero = service.spend(kAetherShardCurrencyId, 0);
        expect(zero.isSuccess, isFalse);
        expect(zero.failureReason, CurrencyFailureReason.invalidAmount);
        expect(service.balance(kAetherShardCurrencyId), 40);

        final negative = service.spend(kAetherShardCurrencyId, -10);
        expect(negative.isSuccess, isFalse);
        expect(negative.failureReason, CurrencyFailureReason.invalidAmount);
        expect(service.balance(kAetherShardCurrencyId), 40);

        final unknown = service.spend('gold', 10);
        expect(unknown.isSuccess, isFalse);
        expect(unknown.failureReason, CurrencyFailureReason.unknownCurrency);
        expect(service.balance(kAetherShardCurrencyId), 40);

        final valid = service.spend(kAetherShardCurrencyId, 15);
        expect(valid.isSuccess, isTrue);
        expect(valid.delta, -15);
        expect(valid.balanceAfter, 25);
        expect(service.balance(kAetherShardCurrencyId), 25);
      },
    );

    test('grant menolak amount <= 0, claimId kosong, dan unknown currency', () {
      final service = CurrencyService(definitions: CurrencyDefinition.defaults);

      final zero = service.grant(
        kAetherShardCurrencyId,
        0,
        claimId: 'claim_zero',
      );
      expect(zero.isSuccess, isFalse);
      expect(zero.failureReason, CurrencyFailureReason.invalidAmount);
      expect(service.claimedIds, isEmpty);

      final neg = service.grant(
        kAetherShardCurrencyId,
        -5,
        claimId: 'claim_neg',
      );
      expect(neg.isSuccess, isFalse);
      expect(neg.failureReason, CurrencyFailureReason.invalidAmount);
      expect(service.claimedIds, isEmpty);

      final emptyClaim = service.grant(
        kAetherShardCurrencyId,
        10,
        claimId: '   ',
      );
      expect(emptyClaim.isSuccess, isFalse);
      expect(emptyClaim.failureReason, CurrencyFailureReason.invalidClaimId);

      final unknown = service.grant('gold', 10, claimId: 'claim_gold');
      expect(unknown.isSuccess, isFalse);
      expect(unknown.failureReason, CurrencyFailureReason.unknownCurrency);
      expect(service.balance(kAetherShardCurrencyId), 0);
    });

    test('grant di-clamp ke max_amount tanpa integer overflow', () {
      final service = CurrencyService(
        definitions: const {
          kAetherShardCurrencyId: CurrencyDefinition(
            id: kAetherShardCurrencyId,
            name: 'Aether Shard',
            maxAmount: 1000000,
          ),
        },
        initialBalances: const {kAetherShardCurrencyId: 999950},
      );

      final clamped = service.grant(
        kAetherShardCurrencyId,
        200,
        claimId: 'claim_near_cap',
      );
      expect(clamped.isSuccess, isTrue);
      expect(clamped.clamped, isTrue);
      expect(clamped.delta, 50);
      expect(clamped.balanceAfter, 1000000);

      // Uji angka sangat besar mendekati batas 64-bit tanpa overflow.
      final huge = service.grant(
        kAetherShardCurrencyId,
        1 << 60,
        claimId: 'claim_huge',
      );
      expect(huge.isSuccess, isTrue);
      expect(huge.clamped, isTrue);
      expect(huge.delta, 0);
      expect(huge.balanceAfter, 1000000);
      expect(service.balance(kAetherShardCurrencyId), 1000000);
    });
  });

  group('currencies config parser & validator', () {
    test('parseCurrencies memuat blok currencies dari game_config.json', () {
      final jsonStr = File('assets/data/game_config.json').readAsStringSync();
      final parsed = const GameConfigParser().parseCurrencies(jsonStr);
      expect(parsed.containsKey(kAetherShardCurrencyId), isTrue);
      expect(parsed[kAetherShardCurrencyId]!.name, 'Aether Shard');
      expect(parsed[kAetherShardCurrencyId]!.maxAmount, 1000000);
    });

    test(
      'parseCurrencies menolak unknown key, max_amount <= 0, dan nama kosong',
      () {
        const parser = GameConfigParser();
        expect(
          () => parser.parseCurrencies(
            jsonEncode({
              'currencies': {
                'aether_shard': {
                  'name': 'Aether Shard',
                  'max_amount': 1000,
                  'extra': true,
                },
              },
            }),
          ),
          throwsA(isA<ConfigException>()),
        );
        expect(
          () => parser.parseCurrencies(
            jsonEncode({
              'currencies': {
                'aether_shard': {'name': 'Aether Shard', 'max_amount': 0},
              },
            }),
          ),
          throwsA(isA<ConfigException>()),
        );
        expect(
          () => parser.parseCurrencies(
            jsonEncode({
              'currencies': {
                'aether_shard': {'name': '   ', 'max_amount': 100},
              },
            }),
          ),
          throwsA(isA<ConfigException>()),
        );
      },
    );

    test('GameConfigValidator menolak maxAmount <= 0 pada currencies', () {
      final invalidConfig = GameConfig(
        monsters: const {},
        revive: const ReviveConfig(),
        progression: const ProgressionConfig(
          baseStats: CombatStats(maxHp: 100, atk: 12, def: 2),
          perLevel: LevelGrowth(hp: 15, atk: 2, def: 0.5),
        ),
        items: const {},
        lootTables: const {},
        currencies: const {
          kAetherShardCurrencyId: CurrencyDefinition(
            id: kAetherShardCurrencyId,
            name: 'Aether Shard',
            maxAmount: 0,
          ),
        },
      );
      expect(
        () => const GameConfigValidator().validate(invalidConfig),
        throwsA(isA<ConfigException>()),
      );
    });
  });
}
