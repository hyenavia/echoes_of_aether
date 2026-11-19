import 'dart:async';

/// Status akun cloud pemain (`DESIGN_ADDENDUM_v1.3 §1.1`).
enum CloudAccountKind { unauthenticated, anonymous, emailLinked, unavailable }

/// Snapshot ringkas status akun cloud yang aman ditampilkan UI.
class CloudAccountSnapshot {
  const CloudAccountSnapshot({
    required this.kind,
    this.uid,
    this.email,
    this.displayName,
    this.unavailableReason,
  });

  const CloudAccountSnapshot.unauthenticated()
    : kind = CloudAccountKind.unauthenticated,
      uid = null,
      email = null,
      displayName = null,
      unavailableReason = null;

  const CloudAccountSnapshot.unavailable(String reason)
    : kind = CloudAccountKind.unavailable,
      uid = null,
      email = null,
      displayName = null,
      unavailableReason = reason;

  final CloudAccountKind kind;
  final String? uid;
  final String? email;
  final String? displayName;
  final String? unavailableReason;

  bool get isSignedIn =>
      (kind == CloudAccountKind.anonymous ||
          kind == CloudAccountKind.emailLinked) &&
      uid != null &&
      uid!.isNotEmpty;

  bool get isEmailLinked => kind == CloudAccountKind.emailLinked;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CloudAccountSnapshot &&
          kind == other.kind &&
          uid == other.uid &&
          email == other.email &&
          displayName == other.displayName &&
          unavailableReason == other.unavailableReason;

  @override
  int get hashCode =>
      Object.hash(kind, uid, email, displayName, unavailableReason);
}

sealed class AuthSignInResult {
  const AuthSignInResult();
}

final class AuthSignInSuccess extends AuthSignInResult {
  const AuthSignInSuccess(this.account);

  final CloudAccountSnapshot account;
}

final class AuthSignInUnavailable extends AuthSignInResult {
  const AuthSignInUnavailable(this.reason);

  final String reason;
}

final class AuthSignInNetworkError extends AuthSignInResult {
  const AuthSignInNetworkError(this.message);

  final String message;
}

final class AuthSignInFailure extends AuthSignInResult {
  const AuthSignInFailure(this.message, {this.code});

  final String message;
  final String? code;
}

sealed class AuthLinkResult {
  const AuthLinkResult();
}

final class AuthLinkLinked extends AuthLinkResult {
  const AuthLinkLinked(this.account);

  final CloudAccountSnapshot account;
}

final class AuthLinkCredentialInUseSwitched extends AuthLinkResult {
  const AuthLinkCredentialInUseSwitched(this.account);

  final CloudAccountSnapshot account;
}

final class AuthLinkCancelled extends AuthLinkResult {
  const AuthLinkCancelled();
}

final class AuthLinkNetworkError extends AuthLinkResult {
  const AuthLinkNetworkError(this.message);

  final String message;
}

final class AuthLinkError extends AuthLinkResult {
  const AuthLinkError(this.message, {this.code});

  final String message;
  final String? code;
}

/// Kontrak lapisan data untuk autentikasi Firebase (anonim + Email/Password).
abstract interface class AuthGateway {
  Future<CloudAccountSnapshot> currentAccount();

  Future<AuthSignInResult> signInAnonymously();

  Future<AuthLinkResult> linkWithEmailPassword({
    required String email,
    required String password,
  });

  Future<AuthLinkResult> signInWithEmailPassword({
    required String email,
    required String password,
  });

  Future<PasswordResetOutcome> sendPasswordResetEmail({required String email});

  Future<void> signOut();
}

sealed class EnsureSignInOutcome {
  const EnsureSignInOutcome();
}

final class EnsureSignInReady extends EnsureSignInOutcome {
  const EnsureSignInReady(this.account);

  final CloudAccountSnapshot account;
}

final class EnsureSignInUnavailable extends EnsureSignInOutcome {
  const EnsureSignInUnavailable(this.reason);

  final String reason;
}

final class EnsureSignInOffline extends EnsureSignInOutcome {
  const EnsureSignInOffline(this.message);

  final String message;
}

final class EnsureSignInFailed extends EnsureSignInOutcome {
  const EnsureSignInFailed(this.message);

  final String message;
}

sealed class EmailAuthOutcome {
  const EmailAuthOutcome();
}

final class EmailAuthSuccess extends EmailAuthOutcome {
  const EmailAuthSuccess(this.account);

  final CloudAccountSnapshot account;
}

final class EmailAuthSwitchedAccountConflict extends EmailAuthOutcome {
  const EmailAuthSwitchedAccountConflict(this.account);

  final CloudAccountSnapshot account;
}

final class EmailAuthFailed extends EmailAuthOutcome {
  const EmailAuthFailed(this.message, {this.code, this.isNetworkError = false});

  final String message;
  final String? code;
  final bool isNetworkError;
}

sealed class PasswordResetOutcome {
  const PasswordResetOutcome();
}

final class PasswordResetSent extends PasswordResetOutcome {
  const PasswordResetSent(this.email);

  final String email;
}

final class PasswordResetFailed extends PasswordResetOutcome {
  const PasswordResetFailed(this.message, {this.isNetworkError = false});

  final String message;
  final bool isNetworkError;
}

/// Mengelola siklus akun cloud pemain (anonim lazy, tautan Email/Password, keluar)
/// tanpa menyentuh save lokal Drift.
class AccountService {
  AccountService({required this.gateway});

  final AuthGateway gateway;

  final StreamController<CloudAccountSnapshot> _controller =
      StreamController<CloudAccountSnapshot>.broadcast();

  CloudAccountSnapshot _current = const CloudAccountSnapshot.unauthenticated();
  bool _hasPendingAccountSwitchConflict = false;
  Future<EnsureSignInOutcome>? _inFlightAnonymous;

  CloudAccountSnapshot get current => _current;

  Stream<CloudAccountSnapshot> get stream => _controller.stream;

  bool get hasPendingAccountSwitchConflict => _hasPendingAccountSwitchConflict;

  Future<CloudAccountSnapshot> refreshState() async {
    final next = await gateway.currentAccount();
    _emit(next);
    return next;
  }

  /// Masuk anonim secara lazy saat pemicu sinkronisasi pertama atau pemain
  /// membuka bagian akun di Pengaturan.
  Future<EnsureSignInOutcome> ensureSignedInForSync() {
    if (_inFlightAnonymous != null) return _inFlightAnonymous!;
    final future = _runEnsureSignedInForSync();
    _inFlightAnonymous = future;
    return future;
  }

  Future<EnsureSignInOutcome> _runEnsureSignedInForSync() async {
    try {
      final existing = await gateway.currentAccount();
      _emit(existing);

      if (existing.kind == CloudAccountKind.unavailable) {
        return EnsureSignInUnavailable(
          existing.unavailableReason ?? 'Layanan cloud tidak tersedia.',
        );
      }
      if (existing.isSignedIn) {
        return EnsureSignInReady(existing);
      }

      final signedIn = await gateway.signInAnonymously();
      switch (signedIn) {
        case AuthSignInSuccess(:final account):
          _emit(account);
          return EnsureSignInReady(account);
        case AuthSignInUnavailable(:final reason):
          _emit(CloudAccountSnapshot.unavailable(reason));
          return EnsureSignInUnavailable(reason);
        case AuthSignInNetworkError(:final message):
          return EnsureSignInOffline(message);
        case AuthSignInFailure(:final message):
          return EnsureSignInFailed(message);
      }
    } finally {
      _inFlightAnonymous = null;
    }
  }

  /// Menautkan Email & Password ke akun aktif (atau masuk ke akun yang sudah
  /// ada bila `email-already-in-use`, sambil menandai konflik agar save lokal
  /// tidak pernah otomatis ditimpakan ke akun tersebut).
  Future<EmailAuthOutcome> linkEmailAccount({
    required String email,
    required String password,
  }) => _authenticateEmail(
    email: email,
    password: password,
    gatewayCall: gateway.linkWithEmailPassword,
  );

  /// Masuk langsung ke akun Email & Password yang sudah terdaftar (mis. di
  /// perangkat baru) tanpa otomatis menimpa save cloud maupun lokal.
  Future<EmailAuthOutcome> signInWithEmailAccount({
    required String email,
    required String password,
  }) => _authenticateEmail(
    email: email,
    password: password,
    gatewayCall: gateway.signInWithEmailPassword,
  );

  Future<EmailAuthOutcome> _authenticateEmail({
    required String email,
    required String password,
    required Future<AuthLinkResult> Function({
      required String email,
      required String password,
    })
    gatewayCall,
  }) async {
    final trimmedEmail = email.trim();
    if (!_looksLikeEmail(trimmedEmail)) {
      return const EmailAuthFailed('Format alamat email tidak valid.');
    }
    if (password.length < 6) {
      return const EmailAuthFailed('Kata sandi minimal 6 karakter.');
    }

    final currentAcc = await gateway.currentAccount();
    _emit(currentAcc);
    if (currentAcc.kind == CloudAccountKind.unavailable) {
      return EmailAuthFailed(
        currentAcc.unavailableReason ?? 'Layanan cloud tidak tersedia.',
      );
    }

    final result = await gatewayCall(email: trimmedEmail, password: password);
    switch (result) {
      case AuthLinkLinked(:final account):
        _hasPendingAccountSwitchConflict = false;
        _emit(account);
        return EmailAuthSuccess(account);
      case AuthLinkCredentialInUseSwitched(:final account):
        _hasPendingAccountSwitchConflict = true;
        _emit(account);
        return EmailAuthSwitchedAccountConflict(account);
      case AuthLinkCancelled():
        return const EmailAuthFailed('Autentikasi email dibatalkan.');
      case AuthLinkNetworkError(:final message):
        return EmailAuthFailed(message, isNetworkError: true);
      case AuthLinkError(:final message, :final code):
        return EmailAuthFailed(message, code: code);
    }
  }

  /// Mengirim email reset kata sandi untuk akun email terdaftar.
  Future<PasswordResetOutcome> sendPasswordReset({
    required String email,
  }) async {
    final trimmedEmail = email.trim();
    if (!_looksLikeEmail(trimmedEmail)) {
      return const PasswordResetFailed('Format alamat email tidak valid.');
    }
    final currentAcc = await gateway.currentAccount();
    _emit(currentAcc);
    if (currentAcc.kind == CloudAccountKind.unavailable) {
      return PasswordResetFailed(
        currentAcc.unavailableReason ?? 'Layanan cloud tidak tersedia.',
      );
    }
    return gateway.sendPasswordResetEmail(email: trimmedEmail);
  }

  static bool _looksLikeEmail(String email) {
    if (email.isEmpty || email.contains(RegExp(r'\s'))) {
      return false;
    }
    final atIndex = email.indexOf('@');
    if (atIndex <= 0 || atIndex != email.lastIndexOf('@')) {
      return false;
    }
    final domain = email.substring(atIndex + 1);
    final dotIndex = domain.indexOf('.');
    return dotIndex > 0 && dotIndex < domain.length - 1;
  }

  void clearAccountSwitchConflict() {
    _hasPendingAccountSwitchConflict = false;
  }

  /// Keluar dari akun cloud tanpa menghapus save lokal di Drift.
  Future<void> signOut() async {
    await gateway.signOut();
    _hasPendingAccountSwitchConflict = false;
    final next = await gateway.currentAccount();
    _emit(
      next.kind == CloudAccountKind.unavailable
          ? next
          : const CloudAccountSnapshot.unauthenticated(),
    );
  }

  void _emit(CloudAccountSnapshot snapshot) {
    _current = snapshot;
    if (!_controller.isClosed) {
      _controller.add(snapshot);
    }
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
