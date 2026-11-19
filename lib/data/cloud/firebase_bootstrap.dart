import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Status ketersediaan layanan Firebase/Cloud pada sesi aplikasi ini.
sealed class CloudAvailabilityState {
  const CloudAvailabilityState();
}

final class CloudAvailable extends CloudAvailabilityState {
  const CloudAvailable({this.usingEmulator = false});

  final bool usingEmulator;
}

final class CloudUnavailable extends CloudAvailabilityState {
  const CloudUnavailable(this.reason);

  final String reason;
}

typedef FirebaseAppInitializer = Future<void> Function();
typedef FirebaseEmulatorConfigurator = Future<void> Function(String host);

/// Pengelola inisialisasi Firebase yang toleran terhadap kegagalan & batas waktu.
///
/// Jika inisialisasi gagal (misalnya Play Services tidak tersedia atau timeout),
/// aplikasi tetap berjalan penuh secara lokal dengan status [CloudUnavailable].
class FirebaseBootstrap {
  FirebaseBootstrap({
    this.timeout = defaultTimeout,
    this.initializeFirebase,
    this.configureEmulators,
    bool? isDebugBuild,
    bool? useEmulatorOverride,
    String? emulatorHostOverride,
  }) : _isDebugBuild = isDebugBuild ?? kDebugMode,
       _useEmulator = useEmulatorOverride ?? useEmulatorFlag,
       _emulatorHostOverride = emulatorHostOverride ?? emulatorHostDefine;

  static final FirebaseBootstrap instance = FirebaseBootstrap();

  static const Duration defaultTimeout = Duration(seconds: 5);
  static const int authEmulatorPort = 9099;
  static const int firestoreEmulatorPort = 8080;

  /// Aktifkan emulator Firebase hanya di build debug lewat:
  /// `--dart-define=FIREBASE_EMULATOR=true`
  static const bool useEmulatorFlag = bool.fromEnvironment(
    'FIREBASE_EMULATOR',
    defaultValue: false,
  );

  /// Opsional override host emulator (`--dart-define=FIREBASE_EMULATOR_HOST=...`).
  static const String emulatorHostDefine = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '',
  );

  final Duration timeout;
  final FirebaseAppInitializer? initializeFirebase;
  final FirebaseEmulatorConfigurator? configureEmulators;
  final bool _isDebugBuild;
  final bool _useEmulator;
  final String _emulatorHostOverride;

  CloudAvailabilityState _state = const CloudUnavailable(
    'Layanan cloud belum diinisialisasi.',
  );
  Completer<CloudAvailabilityState>? _pendingCompleter;
  Timer? _timeoutTimer;
  Zone? _initZone;
  bool _emulatorConfigured = false;

  CloudAvailabilityState get state => _state;

  bool get isAvailable => _state is CloudAvailable;

  String resolveEmulatorHost() {
    if (_emulatorHostOverride.trim().isNotEmpty) {
      return _emulatorHostOverride.trim();
    }
    return defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : '127.0.0.1';
  }

  /// Membatalkan timer inisialisasi yang masih menunggu (aman dipanggil saat
  /// container/scope dibersihkan). Tidak mengubah state bila sudah tersedia.
  void cancelPendingInit() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    final pending = _pendingCompleter;
    if (pending != null && !pending.isCompleted) {
      const cancelled = CloudUnavailable('Layanan cloud belum tersedia.');
      if (_state is! CloudAvailable) {
        _state = cancelled;
      }
      pending.complete(_state);
    }
    _pendingCompleter = null;
    _initZone = null;
  }

  /// Menginisialisasi Firebase satu kali dengan `try/catch` dan timeout.
  /// Tidak pernah melempar exception uncaught ke caller.
  Future<CloudAvailabilityState> initialize() {
    if (_state is CloudAvailable) {
      return Future<CloudAvailabilityState>.value(_state);
    }
    final pending = _pendingCompleter;
    if (pending != null && !pending.isCompleted) {
      if (_initZone == Zone.current) {
        return pending.future;
      }
      cancelPendingInit();
    }
    return _startInitialize();
  }

  Future<CloudAvailabilityState> _startInitialize() {
    final completer = Completer<CloudAvailabilityState>();
    _pendingCompleter = completer;
    _initZone = Zone.current;
    var finished = false;

    _timeoutTimer?.cancel();
    // Pakai Zone.root agar timer batas waktu host SDK tidak membocorkan
    // FakeTimer antar zona widget test ketika inisialisasi masih berlangsung.
    _timeoutTimer = Zone.root.createTimer(timeout, () {
      if (finished || completer.isCompleted) return;
      finished = true;
      _timeoutTimer = null;
      _state = const CloudUnavailable(
        'Inisialisasi layanan cloud melebihi batas waktu.',
      );
      completer.complete(_state);
      if (identical(_pendingCompleter, completer)) {
        _pendingCompleter = null;
        _initZone = null;
      }
    });

    unawaited(() async {
      try {
        final initFn = initializeFirebase ?? _defaultInitializeFirebase;
        await initFn();
        if (finished || completer.isCompleted) return;

        var usingEmulator = false;
        if (_isDebugBuild && _useEmulator) {
          final host = resolveEmulatorHost();
          if (!_emulatorConfigured) {
            final emulatorFn = configureEmulators ?? _defaultConfigureEmulators;
            await emulatorFn(host);
            if (finished || completer.isCompleted) return;
            _emulatorConfigured = true;
          }
          usingEmulator = true;
        }

        _state = CloudAvailable(usingEmulator: usingEmulator);
      } catch (e) {
        if (!finished && !completer.isCompleted) {
          _state = CloudUnavailable('Layanan cloud tidak tersedia: $e');
        }
      } finally {
        _timeoutTimer?.cancel();
        _timeoutTimer = null;
        finished = true;
        if (!completer.isCompleted) {
          completer.complete(_state);
        }
        if (identical(_pendingCompleter, completer)) {
          _pendingCompleter = null;
          _initZone = null;
        }
      }
    }());

    return completer.future;
  }

  static Future<void> _defaultInitializeFirebase() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  }

  static Future<void> _defaultConfigureEmulators(String host) async {
    await FirebaseAuth.instance.useAuthEmulator(
      host,
      authEmulatorPort,
      automaticHostMapping: false,
    );
    FirebaseFirestore.instance.useFirestoreEmulator(
      host,
      firestoreEmulatorPort,
      automaticHostMapping: false,
    );
  }
}
