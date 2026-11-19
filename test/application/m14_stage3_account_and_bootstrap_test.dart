import 'dart:async';

import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/services/account_service.dart';
import 'package:echoes_of_aether/data/cloud/firebase_bootstrap.dart';
import 'package:echoes_of_aether/data/database/app_database.dart'
    hide ClockState, CloudSyncState, GameSettings, PeriodicQuestState;
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/combat_stats.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/progression_config.dart';
import 'package:echoes_of_aether/domain/entities/revive_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthGateway implements AuthGateway {
  CloudAccountSnapshot account = const CloudAccountSnapshot.unauthenticated();
  int anonymousSignInCalls = 0;
  int linkEmailCalls = 0;
  int signInEmailCalls = 0;
  int resetPasswordCalls = 0;
  int signOutCalls = 0;
  String? lastEmail;
  String? lastPassword;

  AuthSignInResult nextAnonymousResult = const AuthSignInSuccess(
    CloudAccountSnapshot(kind: CloudAccountKind.anonymous, uid: 'anon-1'),
  );
  AuthLinkResult nextLinkResult = const AuthLinkLinked(
    CloudAccountSnapshot(
      kind: CloudAccountKind.emailLinked,
      uid: 'anon-1',
      email: 'hero@example.com',
    ),
  );
  AuthLinkResult nextSignInResult = const AuthLinkCredentialInUseSwitched(
    CloudAccountSnapshot(
      kind: CloudAccountKind.emailLinked,
      uid: 'existing-email-uid',
      email: 'hero@example.com',
    ),
  );
  PasswordResetOutcome? nextResetResult;

  @override
  Future<CloudAccountSnapshot> currentAccount() async => account;

  @override
  Future<AuthSignInResult> signInAnonymously() async {
    anonymousSignInCalls++;
    final res = nextAnonymousResult;
    if (res is AuthSignInSuccess) {
      account = res.account;
    }
    return res;
  }

  @override
  Future<AuthLinkResult> linkWithEmailPassword({
    required String email,
    required String password,
  }) async {
    linkEmailCalls++;
    lastEmail = email;
    lastPassword = password;
    final res = nextLinkResult;
    switch (res) {
      case AuthLinkLinked(:final account):
        this.account = account;
      case AuthLinkCredentialInUseSwitched(:final account):
        this.account = account;
      case AuthLinkCancelled():
      case AuthLinkNetworkError():
      case AuthLinkError():
        break;
    }
    return res;
  }

  @override
  Future<AuthLinkResult> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    signInEmailCalls++;
    lastEmail = email;
    lastPassword = password;
    final res = nextSignInResult;
    switch (res) {
      case AuthLinkLinked(:final account):
        this.account = account;
      case AuthLinkCredentialInUseSwitched(:final account):
        this.account = account;
      case AuthLinkCancelled():
      case AuthLinkNetworkError():
      case AuthLinkError():
        break;
    }
    return res;
  }

  @override
  Future<PasswordResetOutcome> sendPasswordResetEmail({
    required String email,
  }) async {
    resetPasswordCalls++;
    lastEmail = email;
    return nextResetResult ?? PasswordResetSent(email);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    account = const CloudAccountSnapshot.unauthenticated();
  }
}

void main() {
  group('FirebaseBootstrap', () {
    test(
      'gagal inisialisasi menghasilkan CloudUnavailable tanpa melempar',
      () async {
        final bootstrap = FirebaseBootstrap(
          initializeFirebase: () async {
            throw StateError('Play Services missing');
          },
        );

        final state = await bootstrap.initialize();
        expect(state, isA<CloudUnavailable>());
        expect(bootstrap.isAvailable, isFalse);
        expect(
          (state as CloudUnavailable).reason,
          contains('Play Services missing'),
        );
      },
    );

    test('melewati batas waktu menghasilkan CloudUnavailable', () async {
      final neverCompletes = Completer<void>();
      final bootstrap = FirebaseBootstrap(
        timeout: const Duration(milliseconds: 20),
        initializeFirebase: () => neverCompletes.future,
      );

      final state = await bootstrap.initialize();
      expect(state, isA<CloudUnavailable>());
      expect(bootstrap.isAvailable, isFalse);
    });

    test('hook FIREBASE_EMULATOR hanya berjalan di debug build dan memakai host platform', () async {
      String? configuredHostDebug;
      final debugBootstrap = FirebaseBootstrap(
        isDebugBuild: true,
        useEmulatorOverride: true,
        initializeFirebase: () async {},
        configureEmulators: (host) async {
          configuredHostDebug = host;
        },
      );

      final debugState = await debugBootstrap.initialize();
      expect(debugState, isA<CloudAvailable>());
      expect((debugState as CloudAvailable).usingEmulator, isTrue);
      final expectedDefaultHost =
          defaultTargetPlatform == TargetPlatform.android
          ? '10.0.2.2'
          : '127.0.0.1';
      expect(configuredHostDebug, expectedDefaultHost);

      String? configuredHostRelease;
      final releaseBootstrap = FirebaseBootstrap(
        isDebugBuild: false,
        useEmulatorOverride: true,
        initializeFirebase: () async {},
        configureEmulators: (host) async {
          configuredHostRelease = host;
        },
      );
      final releaseState = await releaseBootstrap.initialize();
      expect(releaseState, isA<CloudAvailable>());
      expect((releaseState as CloudAvailable).usingEmulator, isFalse);
      expect(configuredHostRelease, isNull);
    });

    test('resolveEmulatorHost menghormati FIREBASE_EMULATOR_HOST override', () {
      final bootstrap = FirebaseBootstrap(
        emulatorHostOverride: ' 192.168.1.44 ',
      );
      expect(bootstrap.resolveEmulatorHost(), '192.168.1.44');
    });
  });

  group('AccountService', () {
    test(
      'masuk anonim secara lazy dan menggabungkan panggilan konkuren',
      () async {
        final gateway = _FakeAuthGateway();
        final service = AccountService(gateway: gateway);

        final results = await Future.wait([
          service.ensureSignedInForSync(),
          service.ensureSignedInForSync(),
        ]);

        expect(gateway.anonymousSignInCalls, 1);
        expect(results[0], isA<EnsureSignInReady>());
        expect(results[1], isA<EnsureSignInReady>());
        expect(service.current.kind, CloudAccountKind.anonymous);
        expect(service.current.uid, 'anon-1');
      },
    );

    test('status unavailable & network error dipetakan tanpa crash', () async {
      final gateway = _FakeAuthGateway()
        ..account = const CloudAccountSnapshot.unavailable('Firebase offline');
      final service = AccountService(gateway: gateway);

      final unavail = await service.ensureSignedInForSync();
      expect(unavail, isA<EnsureSignInUnavailable>());

      gateway
        ..account = const CloudAccountSnapshot.unauthenticated()
        ..nextAnonymousResult = const AuthSignInNetworkError('No internet');
      final offline = await service.ensureSignedInForSync();
      expect(offline, isA<EnsureSignInOffline>());
    });

    test('tautkan email menolak input email/kata sandi tidak valid sebelum ke gateway', () async {
      final gateway = _FakeAuthGateway();
      final service = AccountService(gateway: gateway);

      final badEmail = await service.linkEmailAccount(
        email: 'bukan-email',
        password: 'password123',
      );
      expect(badEmail, isA<EmailAuthFailed>());
      expect(gateway.linkEmailCalls, 0);

      final shortPass = await service.linkEmailAccount(
        email: 'hero@example.com',
        password: '12345',
      );
      expect(shortPass, isA<EmailAuthFailed>());
      expect(gateway.linkEmailCalls, 0);
    });

    test('tautkan email sukses mempertahankan uid, merapikan spasi email, dan menghapus status konflik', () async {
      final gateway = _FakeAuthGateway()
        ..account = const CloudAccountSnapshot(
          kind: CloudAccountKind.anonymous,
          uid: 'anon-1',
        );
      final service = AccountService(gateway: gateway);

      final outcome = await service.linkEmailAccount(
        email: '  hero@example.com  ',
        password: 'password123',
      );
      expect(outcome, isA<EmailAuthSuccess>());
      expect(gateway.linkEmailCalls, 1);
      expect(gateway.lastEmail, 'hero@example.com');
      expect(service.current.kind, CloudAccountKind.emailLinked);
      expect(service.current.uid, 'anon-1');
      expect(service.hasPendingAccountSwitchConflict, isFalse);
    });

    test(
      'email-already-in-use atau sign-in akun lain menandai konflik',
      () async {
        final gateway = _FakeAuthGateway()
          ..account = const CloudAccountSnapshot(
            kind: CloudAccountKind.anonymous,
            uid: 'anon-local',
          )
          ..nextLinkResult = const AuthLinkCredentialInUseSwitched(
            CloudAccountSnapshot(
              kind: CloudAccountKind.emailLinked,
              uid: 'existing-email-uid',
              email: 'player@example.com',
            ),
          );
        final service = AccountService(gateway: gateway);

        final outcome = await service.linkEmailAccount(
          email: 'player@example.com',
          password: 'password123',
        );
        expect(outcome, isA<EmailAuthSwitchedAccountConflict>());
        expect(service.current.uid, 'existing-email-uid');
        expect(service.hasPendingAccountSwitchConflict, isTrue);

        service.clearAccountSwitchConflict();
        expect(service.hasPendingAccountSwitchConflict, isFalse);

        final signInOutcome = await service.signInWithEmailAccount(
          email: 'player@example.com',
          password: 'password123',
        );
        expect(signInOutcome, isA<EmailAuthSwitchedAccountConflict>());
        expect(gateway.signInEmailCalls, 1);
        expect(service.hasPendingAccountSwitchConflict, isTrue);
      },
    );

    test(
      'sendPasswordReset memvalidasi email dan meneruskan ke gateway',
      () async {
        final gateway = _FakeAuthGateway();
        final service = AccountService(gateway: gateway);

        final invalid = await service.sendPasswordReset(email: 'invalid');
        expect(invalid, isA<PasswordResetFailed>());
        expect(gateway.resetPasswordCalls, 0);

        final ok = await service.sendPasswordReset(email: ' hero@example.com ');
        expect(ok, isA<PasswordResetSent>());
        expect(gateway.resetPasswordCalls, 1);
        expect(gateway.lastEmail, 'hero@example.com');
      },
    );

    test('keluar akun tidak menghapus save lokal Drift', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.initialize();
      addTearDown(db.close);
      const minimalConfig = GameConfig(
        monsters: {},
        revive: ReviveConfig(),
        progression: ProgressionConfig(
          baseStats: CombatStats(maxHp: 100, atk: 12, def: 2),
          perLevel: LevelGrowth(hp: 15, atk: 2, def: 0.5),
        ),
        items: {},
        lootTables: {},
      );
      final saveRepo = DriftPlayerSaveRepository(db: db, config: minimalConfig);
      await saveRepo.saveSnapshot(
        const PlayerSaveSnapshot(
          character: PlayerCharacterSnapshot(
            progress: PlayerProgress(level: 9, gold: 4321),
          ),
          inventory: InventorySnapshot(),
        ),
      );

      final gateway = _FakeAuthGateway()
        ..account = const CloudAccountSnapshot(
          kind: CloudAccountKind.emailLinked,
          uid: 'uid-99',
          email: 'hero@example.com',
        );
      final service = AccountService(gateway: gateway);
      await service.refreshState();

      await service.signOut();
      expect(gateway.signOutCalls, 1);
      expect(service.current.kind, CloudAccountKind.unauthenticated);
      expect(service.hasPendingAccountSwitchConflict, isFalse);

      final localAfterSignOut = await saveRepo.loadSnapshot();
      expect(localAfterSignOut, isNotNull);
      expect(localAfterSignOut!.character.progress.level, 9);
      expect(localAfterSignOut.character.progress.gold, 4321);
    });
  });
}
