import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../application/services/account_service.dart';
import 'firebase_bootstrap.dart';

/// Implementasi [AuthGateway] berbasis FirebaseAuth (Anonim + Email/Password).
///
/// Selalu memeriksa [FirebaseBootstrap.initialize] terlebih dahulu dan tidak
/// pernah mengakses [FirebaseAuth.instance] saat cloud berada pada status
/// [CloudUnavailable].
class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway({
    FirebaseBootstrap? bootstrap,
    FirebaseAuth? auth,
    this.requestTimeout = const Duration(seconds: 8),
  }) : _bootstrap = bootstrap ?? FirebaseBootstrap.instance,
       _authOverride = auth;

  final FirebaseBootstrap _bootstrap;
  final FirebaseAuth? _authOverride;
  final Duration requestTimeout;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  @override
  Future<CloudAccountSnapshot> currentAccount() async {
    final availability = await _bootstrap.initialize();
    if (availability is CloudUnavailable) {
      return CloudAccountSnapshot.unavailable(availability.reason);
    }
    try {
      return _mapUser(_auth.currentUser);
    } catch (e) {
      return CloudAccountSnapshot.unavailable('Auth tidak tersedia: $e');
    }
  }

  @override
  Future<AuthSignInResult> signInAnonymously() async {
    final availability = await _bootstrap.initialize();
    if (availability is CloudUnavailable) {
      return AuthSignInUnavailable(availability.reason);
    }
    try {
      final existing = _auth.currentUser;
      if (existing != null) {
        return AuthSignInSuccess(_mapUser(existing));
      }
      final credential = await _auth.signInAnonymously().timeout(
        requestTimeout,
      );
      return AuthSignInSuccess(_mapUser(credential.user));
    } on TimeoutException {
      return const AuthSignInNetworkError(
        'Masuk anonim melebihi batas waktu koneksi.',
      );
    } on FirebaseAuthException catch (e) {
      if (_isNetworkErrorCode(e.code)) {
        return AuthSignInNetworkError(
          e.message ?? 'Koneksi jaringan bermasalah saat masuk akun.',
        );
      }
      return AuthSignInFailure(
        e.message ?? 'Gagal masuk anonim (${e.code}).',
        code: e.code,
      );
    } catch (e) {
      return AuthSignInFailure('Gagal masuk anonim: $e');
    }
  }

  @override
  Future<AuthLinkResult> linkWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final availability = await _bootstrap.initialize();
    if (availability is CloudUnavailable) {
      return AuthLinkError(availability.reason);
    }

    try {
      var user = _auth.currentUser;
      if (user == null) {
        final anonCred = await _auth.signInAnonymously().timeout(
          requestTimeout,
        );
        user = anonCred.user;
      }
      if (user == null) {
        return const AuthLinkError('Pengguna aktif tidak tersedia.');
      }

      final cred = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      try {
        final linked = await user
            .linkWithCredential(cred)
            .timeout(requestTimeout);
        return AuthLinkLinked(_mapUser(linked.user ?? _auth.currentUser));
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use' ||
            e.code == 'credential-already-in-use' ||
            e.code == 'account-exists-with-different-credential') {
          try {
            final switched = await _auth
                .signInWithEmailAndPassword(email: email, password: password)
                .timeout(requestTimeout);
            return AuthLinkCredentialInUseSwitched(
              _mapUser(switched.user ?? _auth.currentUser),
            );
          } on FirebaseAuthException catch (signInErr) {
            if (_isNetworkErrorCode(signInErr.code)) {
              return AuthLinkNetworkError(
                signInErr.message ?? 'Koneksi bermasalah saat masuk akun.',
              );
            }
            if (signInErr.code == 'wrong-password' ||
                signInErr.code == 'invalid-credential') {
              return AuthLinkError(
                'Email sudah terdaftar dengan kata sandi berbeda.',
                code: signInErr.code,
              );
            }
            return AuthLinkError(
              _mapAuthErrorMessage(signInErr, 'Masuk akun email'),
              code: signInErr.code,
            );
          }
        }
        if (_isNetworkErrorCode(e.code)) {
          return AuthLinkNetworkError(
            e.message ?? 'Koneksi bermasalah saat menautkan email.',
          );
        }
        return AuthLinkError(
          _mapAuthErrorMessage(e, 'Menautkan email'),
          code: e.code,
        );
      }
    } on TimeoutException {
      return const AuthLinkNetworkError(
        'Permintaan tautan email melebihi batas waktu.',
      );
    } on FirebaseAuthException catch (e) {
      if (_isNetworkErrorCode(e.code)) {
        return AuthLinkNetworkError(
          e.message ?? 'Koneksi bermasalah saat autentikasi email.',
        );
      }
      return AuthLinkError(
        _mapAuthErrorMessage(e, 'Menautkan email'),
        code: e.code,
      );
    } catch (e) {
      return AuthLinkError('Gagal menautkan email: $e');
    }
  }

  @override
  Future<AuthLinkResult> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final availability = await _bootstrap.initialize();
    if (availability is CloudUnavailable) {
      return AuthLinkError(availability.reason);
    }

    try {
      final prevUid = _auth.currentUser?.uid;
      final signed = await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(requestTimeout);
      final mapped = _mapUser(signed.user ?? _auth.currentUser);
      if (prevUid != null && prevUid == mapped.uid) {
        return AuthLinkLinked(mapped);
      }
      return AuthLinkCredentialInUseSwitched(mapped);
    } on TimeoutException {
      return const AuthLinkNetworkError(
        'Permintaan masuk email melebihi batas waktu.',
      );
    } on FirebaseAuthException catch (e) {
      if (_isNetworkErrorCode(e.code)) {
        return AuthLinkNetworkError(
          e.message ?? 'Koneksi bermasalah saat masuk akun email.',
        );
      }
      return AuthLinkError(
        _mapAuthErrorMessage(e, 'Masuk akun email'),
        code: e.code,
      );
    } catch (e) {
      return AuthLinkError('Gagal masuk akun email: $e');
    }
  }

  @override
  Future<PasswordResetOutcome> sendPasswordResetEmail({
    required String email,
  }) async {
    final availability = await _bootstrap.initialize();
    if (availability is CloudUnavailable) {
      return PasswordResetFailed(availability.reason);
    }

    try {
      await _auth.sendPasswordResetEmail(email: email).timeout(requestTimeout);
      return PasswordResetSent(email);
    } on TimeoutException {
      return const PasswordResetFailed(
        'Permintaan reset kata sandi melebihi batas waktu.',
        isNetworkError: true,
      );
    } on FirebaseAuthException catch (e) {
      if (_isNetworkErrorCode(e.code)) {
        return PasswordResetFailed(
          e.message ?? 'Koneksi bermasalah saat mengirim email reset.',
          isNetworkError: true,
        );
      }
      return PasswordResetFailed(_mapAuthErrorMessage(e, 'Reset kata sandi'));
    } catch (e) {
      return PasswordResetFailed('Gagal mengirim email reset: $e');
    }
  }

  @override
  Future<void> signOut() async {
    if (_bootstrap.state is! CloudAvailable) {
      return;
    }
    try {
      await _auth.signOut().timeout(requestTimeout);
    } catch (_) {
      // Abaikan kegagalan sign-out jaringan agar lokal tetap bersih.
    }
  }

  static CloudAccountSnapshot _mapUser(User? user) {
    if (user == null) {
      return const CloudAccountSnapshot.unauthenticated();
    }
    final hasEmail = user.providerData.any(
      (p) => p.providerId == EmailAuthProvider.PROVIDER_ID,
    );
    final isEmailLinked = hasEmail || !user.isAnonymous;
    String? email = user.email;
    String? displayName = user.displayName;
    for (final info in user.providerData) {
      email ??= info.email;
      displayName ??= info.displayName;
    }
    return CloudAccountSnapshot(
      kind: isEmailLinked
          ? CloudAccountKind.emailLinked
          : CloudAccountKind.anonymous,
      uid: user.uid,
      email: email,
      displayName: displayName,
    );
  }

  static String _mapAuthErrorMessage(FirebaseAuthException e, String action) {
    return switch (e.code) {
      'invalid-email' => 'Format alamat email tidak valid.',
      'weak-password' => 'Kata sandi terlalu lemah (minimal 6 karakter).',
      'user-not-found' => 'Akun dengan email tersebut tidak ditemukan.',
      'wrong-password' => 'Kata sandi salah.',
      'invalid-credential' => 'Email atau kata sandi tidak sesuai.',
      'user-disabled' => 'Akun ini dinonaktifkan.',
      'too-many-requests' => 'Terlalu banyak percobaan. Coba lagi nanti.',
      'operation-not-allowed' =>
        'Autentikasi Email/Password belum diaktifkan di Firebase Console.',
      'requires-recent-login' => 'Silakan masuk ulang terlebih dahulu.',
      'provider-already-linked' => 'Akun ini sudah terhubung dengan email.',
      _ => e.message ?? '$action gagal (${e.code}).',
    };
  }

  static bool _isNetworkErrorCode(String code) =>
      code == 'network-request-failed' ||
      code == 'unavailable' ||
      code == 'timeout';
}
