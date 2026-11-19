import 'dart:math' as math;

import '../entities/currency_config.dart';

/// Alasan kegagalan operasi mata uang non-gold.
enum CurrencyFailureReason {
  unknownCurrency,
  invalidAmount,
  invalidClaimId,
  insufficientBalance,
}

/// Hasil operasi `grant` atau `spend` pada [CurrencyService].
class CurrencyResult {
  const CurrencyResult._({
    required this.isSuccess,
    required this.currencyId,
    required this.balanceAfter,
    this.delta = 0,
    this.alreadyClaimed = false,
    this.clamped = false,
    this.failureReason,
  });

  const CurrencyResult.granted({
    required String currencyId,
    required int balanceAfter,
    required int delta,
    bool alreadyClaimed = false,
    bool clamped = false,
  }) : this._(
         isSuccess: true,
         currencyId: currencyId,
         balanceAfter: balanceAfter,
         delta: delta,
         alreadyClaimed: alreadyClaimed,
         clamped: clamped,
       );

  const CurrencyResult.spent({
    required String currencyId,
    required int balanceAfter,
    required int delta,
  }) : this._(
         isSuccess: true,
         currencyId: currencyId,
         balanceAfter: balanceAfter,
         delta: delta,
       );

  const CurrencyResult.failure({
    required String currencyId,
    required int balanceAfter,
    required CurrencyFailureReason reason,
  }) : this._(
         isSuccess: false,
         currencyId: currencyId,
         balanceAfter: balanceAfter,
         failureReason: reason,
       );

  final bool isSuccess;
  final String currencyId;
  final int balanceAfter;
  final int delta;
  final bool alreadyClaimed;
  final bool clamped;
  final CurrencyFailureReason? failureReason;
}

/// Service domain murni untuk mengelola saldo mata uang non-gold (mis.
/// `aether_shard`) secara deterministik, idempoten (`claimId`), dan aman
/// terhadap overflow maupun kegagalan parsial. Gold tetap dikelola di
/// `PlayerProgress` / `PlayerCharacter`.
class CurrencyService {
  CurrencyService({
    required Map<String, CurrencyDefinition> definitions,
    Map<String, int>? initialBalances,
    Set<String>? claimedIds,
  }) : _definitions = Map<String, CurrencyDefinition>.unmodifiable(definitions),
       _balances = <String, int>{},
       _claimedIds = claimedIds != null ? {...claimedIds} : <String>{} {
    if (initialBalances != null) {
      for (final entry in initialBalances.entries) {
        final def = _definitions[entry.key];
        if (def == null) continue;
        final safe = entry.value < 0 ? 0 : math.min(entry.value, def.maxAmount);
        if (safe > 0) {
          _balances[entry.key] = safe;
        }
      }
    }
  }

  final Map<String, CurrencyDefinition> _definitions;
  final Map<String, int> _balances;
  final Set<String> _claimedIds;

  /// Mengembalikan saldo saat ini untuk [currencyId] (default `0`).
  int balance(String currencyId) => _balances[currencyId] ?? 0;

  /// Salinan read-only seluruh saldo mata uang untuk snapshot/persistensi.
  Map<String, int> toSnapshot() => Map<String, int>.unmodifiable(_balances);

  /// Salinan read-only saldo mata uang saat ini.
  Map<String, int> get balances => toSnapshot();

  /// Salinan read-only seluruh ID klaim yang telah diproses.
  Set<String> get claimedIds => Set<String>.unmodifiable(_claimedIds);

  /// Memulihkan state saldo dan ID klaim (mis. rollback transaksi gagal).
  void restoreState({
    required Map<String, int> balances,
    required Set<String> claimedIds,
  }) {
    _balances
      ..clear()
      ..addAll(balances);
    _claimedIds
      ..clear()
      ..addAll(claimedIds);
  }

  /// Menambahkan [amount] ke [currencyId] secara idempoten menggunakan
  /// [claimId] dan membatasi saldo ke `max_amount`.
  CurrencyResult grant(
    String currencyId,
    int amount, {
    required String claimId,
  }) {
    final def = _definitions[currencyId];
    if (def == null) {
      return CurrencyResult.failure(
        currencyId: currencyId,
        balanceAfter: 0,
        reason: CurrencyFailureReason.unknownCurrency,
      );
    }
    final normalizedClaimId = claimId.trim();
    if (normalizedClaimId.isEmpty) {
      return CurrencyResult.failure(
        currencyId: currencyId,
        balanceAfter: balance(currencyId),
        reason: CurrencyFailureReason.invalidClaimId,
      );
    }
    if (amount <= 0) {
      return CurrencyResult.failure(
        currencyId: currencyId,
        balanceAfter: balance(currencyId),
        reason: CurrencyFailureReason.invalidAmount,
      );
    }
    final current = balance(currencyId);
    if (_claimedIds.contains(normalizedClaimId)) {
      return CurrencyResult.granted(
        currencyId: currencyId,
        balanceAfter: current,
        delta: 0,
        alreadyClaimed: true,
      );
    }

    final remaining = math.max(0, def.maxAmount - current);
    final added = math.min(amount, remaining);
    final next = current + added;
    _claimedIds.add(normalizedClaimId);
    if (next > 0) {
      _balances[currencyId] = next;
    }

    return CurrencyResult.granted(
      currencyId: currencyId,
      balanceAfter: next,
      delta: added,
      clamped: added < amount,
    );
  }

  /// Mengurangi [amount] dari [currencyId] setelah memvalidasi seluruh syarat.
  /// Tidak memiliki efek samping bila gagal.
  CurrencyResult spend(String currencyId, int amount) {
    final def = _definitions[currencyId];
    if (def == null) {
      return CurrencyResult.failure(
        currencyId: currencyId,
        balanceAfter: 0,
        reason: CurrencyFailureReason.unknownCurrency,
      );
    }
    final current = balance(currencyId);
    if (amount <= 0) {
      return CurrencyResult.failure(
        currencyId: currencyId,
        balanceAfter: current,
        reason: CurrencyFailureReason.invalidAmount,
      );
    }
    if (current < amount) {
      return CurrencyResult.failure(
        currencyId: currencyId,
        balanceAfter: current,
        reason: CurrencyFailureReason.insufficientBalance,
      );
    }
    final next = current - amount;
    if (next == 0) {
      _balances.remove(currencyId);
    } else {
      _balances[currencyId] = next;
    }
    return CurrencyResult.spent(
      currencyId: currencyId,
      balanceAfter: next,
      delta: -amount,
    );
  }
}
