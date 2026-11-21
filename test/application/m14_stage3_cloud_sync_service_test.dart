import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/services/account_service.dart';
import 'package:echoes_of_aether/application/services/cloud_sync_service.dart';
import 'package:echoes_of_aether/data/cloud/drift_cloud_sync_adapters.dart';
import 'package:echoes_of_aether/data/database/app_database.dart'
    hide ClockState, CloudSyncState, GameSettings, PeriodicQuestState;
import 'package:echoes_of_aether/data/models/boss_events_config_parser.dart';
import 'package:echoes_of_aether/data/models/dungeon_config_parser.dart';
import 'package:echoes_of_aether/data/models/event_shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/game_config_parser.dart';
import 'package:echoes_of_aether/data/models/item_config_parser.dart';
import 'package:echoes_of_aether/data/models/loot_config_parser.dart';
import 'package:echoes_of_aether/data/models/monster_config_parser.dart';
import 'package:echoes_of_aether/data/models/shop_config_parser.dart';
import 'package:echoes_of_aether/data/models/skill_config_parser.dart';
import 'package:echoes_of_aether/data/models/specialization_config_parser.dart';
import 'package:echoes_of_aether/data/repositories/drift_cloud_sync_state_repository.dart';
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/data/repositories/in_memory_cloud_save_repository.dart';
import 'package:echoes_of_aether/data/repositories/local_backup_service.dart';
import 'package:echoes_of_aether/data/repositories/save_blob_packer.dart';
import 'package:echoes_of_aether/domain/entities/cycle_progress.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/repositories/cloud_save_repository.dart';
import 'package:echoes_of_aether/domain/services/app_version_comparator.dart';
import 'package:echoes_of_aether/domain/services/cloud_limits.dart';
import 'package:echoes_of_aether/domain/services/game_clock.dart';
import 'package:echoes_of_aether/domain/services/legacy_save_converter.dart';
import 'package:echoes_of_aether/domain/services/save_metrics_calculator.dart';
import 'package:echoes_of_aether/domain/services/sync_planner.dart';
import 'package:flutter_test/flutter_test.dart';

String _readAsset(String name) => File('assets/data/$name').readAsStringSync();

GameConfig _loadRealConfig() {
  const parser = GameConfigParser();
  const dungeonParser = DungeonConfigParser();
  final settings = _readAsset('game_config.json');
  final difficulty = parser.parseDifficulty(settings);
  final dungeonsJson = _readAsset('dungeons.json');
  return GameConfig(
    monsters: const MonsterConfigParser().parse(_readAsset('monsters.json')),
    damage: parser.parseDamage(settings),
    difficulty: difficulty,
    farming: parser.parseFarming(settings),
    revive: parser.parseRevive(settings),
    progression: parser.parseProgression(settings),
    equipment: parser.parseEquipment(settings),
    time: parser.parseTime(settings),
    claimedRewards: parser.parseClaimedRewards(settings),
    currencies: parser.parseCurrencies(settings),
    notifications: parser.parseNotifications(settings),
    dungeonCompletion: parser.parseDungeonCompletion(settings),
    cloud: parser.parseCloud(settings),
    items: const ItemConfigParser().parse(_readAsset('items.json')),
    lootTables: const LootConfigParser().parse(_readAsset('loot_tables.json')),
    skills: const SkillConfigParser().parse(_readAsset('skills.json')),
    specializations: const SpecializationConfigParser().parse(
      _readAsset('specializations.json'),
    ),
    dungeons: dungeonParser.parse(
      dungeonsJson,
      ascensionMultiplier: difficulty.ascensionMultiplier,
    ),
    mapLayouts: dungeonParser.parseMaps(dungeonsJson),
    bossEvents: const BossEventsConfigParser().parse(
      _readAsset('boss_events.json'),
    ),
    shop: const ShopConfigParser().parse(_readAsset('shop.json')),
    eventShop: const EventShopConfigParser().parse(
      _readAsset('event_shop.json'),
    ),
  );
}

PlayerSaveSnapshot _makeSnapshot({
  int level = 1,
  int gold = 0,
  int ascensionPhase = 0,
  CycleProgress cycleProgress = const CycleProgress(),
  Map<String, int> currencies = const {},
  String currentDungeonId = 'forgotten_forest',
}) => PlayerSaveSnapshot(
  character: PlayerCharacterSnapshot(
    progress: PlayerProgress(
      level: level,
      gold: gold,
      ascensionPhase: ascensionPhase,
    ),
  ),
  inventory: const InventorySnapshot(),
  dungeon: DungeonProgressSnapshot(currentDungeonId: currentDungeonId),
  cycleProgress: cycleProgress,
  currencies: currencies,
  offlineActivity: const OfflineActivitySnapshot.paused(),
);

class _MutableClock implements GameClock {
  _MutableClock(this._nowMs);
  int _nowMs;
  @override
  int get nowMs => _nowMs;
  set nowMs(int value) => _nowMs = value;
}

class _ConfigurableAuthGateway implements AuthGateway {
  CloudAccountSnapshot account = const CloudAccountSnapshot.unauthenticated();
  AuthSignInResult? anonymousOverride;
  AuthLinkResult nextLinkResult = const AuthLinkCancelled();

  @override
  Future<CloudAccountSnapshot> currentAccount() async => account;

  @override
  Future<AuthSignInResult> signInAnonymously() async {
    if (anonymousOverride != null) return anonymousOverride!;
    account = const CloudAccountSnapshot(
      kind: CloudAccountKind.anonymous,
      uid: 'anon-uid-1',
    );
    return AuthSignInSuccess(account);
  }

  @override
  Future<AuthLinkResult> linkWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final res = nextLinkResult;
    if (res is AuthLinkLinked) {
      account = res.account;
    } else if (res is AuthLinkCredentialInUseSwitched) {
      account = res.account;
    }
    return res;
  }

  @override
  Future<AuthLinkResult> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final res = nextLinkResult;
    if (res is AuthLinkLinked) {
      account = res.account;
    } else if (res is AuthLinkCredentialInUseSwitched) {
      account = res.account;
    }
    return res;
  }

  @override
  Future<PasswordResetOutcome> sendPasswordResetEmail({
    required String email,
  }) async => PasswordResetSent(email);

  @override
  Future<void> signOut() async {
    account = const CloudAccountSnapshot.unauthenticated();
  }
}

class _CountingCloudSaveRepository extends InMemoryCloudSaveRepository {
  _CountingCloudSaveRepository({required int Function() serverNowMs})
    : super(serverNowMs: serverNowMs);

  int latestMetaCalls = 0;
  int uploadCalls = 0;
  int downloadCalls = 0;

  @override
  Future<CloudResult<CloudSaveMeta?>> latestMeta() async {
    latestMetaCalls++;
    return super.latestMeta();
  }

  @override
  Future<CloudResult<CloudSaveMeta>> upload(
    CloudSaveUploadRequest request,
  ) async {
    uploadCalls++;
    return super.upload(request);
  }

  @override
  Future<CloudResult<CloudSaveDownload?>> download() async {
    downloadCalls++;
    return super.download();
  }
}

class _CorruptingCloudSaveRepository extends _CountingCloudSaveRepository {
  _CorruptingCloudSaveRepository({required super.serverNowMs});

  CloudSaveDownload? customDownload;

  @override
  Future<CloudResult<CloudSaveMeta?>> latestMeta() async {
    if (customDownload != null) {
      return CloudSuccess(customDownload!.meta);
    }
    return super.latestMeta();
  }

  @override
  Future<CloudResult<CloudSaveDownload?>> download() async {
    downloadCalls++;
    if (customDownload != null) {
      return CloudSuccess(customDownload);
    }
    return super.download();
  }
}

void main() {
  late GameConfig config;

  setUpAll(() {
    config = _loadRealConfig();
  });

  CloudSyncService createService({
    required AppDatabase db,
    required _MutableClock clock,
    required _ConfigurableAuthGateway authGateway,
    required InMemoryCloudSaveRepository cloudRepo,
    DriftPlayerSaveRepository? saveRepoOverride,
    int schemaVersion = 8,
    String appVersion = '1.0.0',
  }) {
    final saveRepo =
        saveRepoOverride ??
        DriftPlayerSaveRepository(db: db, config: config, clock: clock);
    return CloudSyncService(
      accountService: AccountService(gateway: authGateway),
      cloudSaveRepository: cloudRepo,
      syncStateRepository: DriftCloudSyncStateRepository(db: db),
      saveRepository: saveRepo,
      replaceRepository: saveRepo,
      blobPort: const SaveBlobPackerAdapter(),
      backupPort: LocalBackupServiceAdapter(
        LocalBackupService(db: db, clock: clock),
      ),
      config: config,
      appVersion: appVersion,
      schemaVersion: schemaVersion,
      clock: clock,
    );
  }

  group('CloudSyncService', () {
    test('sinkronisasi pertama mengunggah revisi 1 dan background tanpa perubahan di-skip lokal', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.initialize();
      addTearDown(db.close);
      final clock = _MutableClock(1700000000000);
      final auth = _ConfigurableAuthGateway();
      final cloudRepo = _CountingCloudSaveRepository(
        serverNowMs: () => clock.nowMs,
      );
      final saveRepo = DriftPlayerSaveRepository(
        db: db,
        config: config,
        clock: clock,
      );
      await saveRepo.saveSnapshot(_makeSnapshot(level: 3, gold: 250));

      final service = createService(
        db: db,
        clock: clock,
        authGateway: auth,
        cloudRepo: cloudRepo,
        saveRepoOverride: saveRepo,
      );

      final first = await service.sync(SyncTrigger.appOpen);
      expect(first.kind, SyncOutcomeKind.uploaded);
      expect(first.cloudMeta?.revision, 1);
      expect(first.status.phase, CloudSyncPhase.synced);
      expect(first.status.lastSyncedRevision, 1);
      expect(cloudRepo.uploadCalls, 1);

      // Background dengan hash sama tidak boleh memanggil Firestore sama sekali
      final metaCallsBeforeBg = cloudRepo.latestMetaCalls;
      final bg = await service.sync(SyncTrigger.background);
      expect(bg.kind, SyncOutcomeKind.skippedNoChanges);
      expect(cloudRepo.latestMetaCalls, metaCallsBeforeBg);
      expect(cloudRepo.uploadCalls, 1);
    });

    test('throttle 5 menit menahan auto-sync, tetapi ascension dan manual melewatinya', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.initialize();
      addTearDown(db.close);
      final clock = _MutableClock(1700000000000);
      final auth = _ConfigurableAuthGateway();
      final cloudRepo = _CountingCloudSaveRepository(
        serverNowMs: () => clock.nowMs,
      );
      final saveRepo = DriftPlayerSaveRepository(
        db: db,
        config: config,
        clock: clock,
      );
      await saveRepo.saveSnapshot(_makeSnapshot(level: 4, gold: 400));

      final service = createService(
        db: db,
        clock: clock,
        authGateway: auth,
        cloudRepo: cloudRepo,
        saveRepoOverride: saveRepo,
      );

      final rev1 = await service.sync(SyncTrigger.appOpen);
      expect(rev1.kind, SyncOutcomeKind.uploaded);

      // Ubah progres 1 menit kemudian -> appOpen di-throttle
      clock.nowMs += 60 * 1000;
      await saveRepo.saveSnapshot(_makeSnapshot(level: 4, gold: 500));
      final throttled = await service.sync(SyncTrigger.appOpen);
      expect(throttled.kind, SyncOutcomeKind.skippedThrottled);

      // Ascension melewati throttle dan menulis revisi 2
      final asc = await service.sync(SyncTrigger.ascension);
      expect(asc.kind, SyncOutcomeKind.uploaded);
      expect(asc.cloudMeta?.revision, 2);

      // Manual 30 detik kemudian juga melewati throttle -> revisi 3
      clock.nowMs += 30 * 1000;
      await saveRepo.saveSnapshot(_makeSnapshot(level: 5, gold: 700));
      final manual = await service.sync(SyncTrigger.manual);
      expect(manual.kind, SyncOutcomeKind.uploaded);
      expect(manual.cloudMeta?.revision, 3);
    });

    test('perangkat baru dengan cloud lebih baru menawarkan pemulihan (offerRestore) tanpa menimpa lokal otomatis', () async {
      final clock = _MutableClock(1700000000000);
      // Buat blob valid dari perangkat lain dengan level 12 & gold 9999
      final remoteDb = AppDatabase(NativeDatabase.memory());
      await remoteDb.initialize();
      final remoteSaveRepo = DriftPlayerSaveRepository(
        db: remoteDb,
        config: config,
        clock: clock,
      );
      await remoteSaveRepo.saveSnapshot(_makeSnapshot(level: 12, gold: 9999));
      final remoteSnap = (await remoteSaveRepo.loadSnapshot())!;
      await remoteDb.close();
      const packer = SaveBlobPackerAdapter();
      final packed = packer.pack(remoteSnap);
      final metrics = const SaveMetricsCalculator().compute(
        snapshot: remoteSnap,
        config: config,
        blobBytes: packed.blobBytes,
        blobSha256: packed.sha256Hex,
        schemaVersion: 8,
        codecVersion: packed.codecVersion,
      );

      final cloudRepo = _CountingCloudSaveRepository(
        serverNowMs: () => clock.nowMs,
      );
      cloudRepo.seedSlot(
        CloudSaveDownload(
          meta: CloudSaveMeta(
            revision: 4,
            slot: 0,
            savedAtServerMs: clock.nowMs - 10000,
            deviceId: 'other-device',
            appVersion: '1.0.0',
            metrics: metrics,
          ),
          blob: packed.compressedBytes,
        ),
      );

      // Perangkat baru (save kosong default)
      final localDb = AppDatabase(NativeDatabase.memory());
      await localDb.initialize();
      addTearDown(localDb.close);
      final localSaveRepo = DriftPlayerSaveRepository(
        db: localDb,
        config: config,
        clock: clock,
      );
      await localSaveRepo.saveSnapshot(_makeSnapshot(level: 1, gold: 0));
      final auth = _ConfigurableAuthGateway();
      final service = createService(
        db: localDb,
        clock: clock,
        authGateway: auth,
        cloudRepo: cloudRepo,
        saveRepoOverride: localSaveRepo,
      );

      final outcome = await service.sync(SyncTrigger.appOpen);
      expect(outcome.kind, SyncOutcomeKind.offerRestore);
      expect(outcome.status.phase, CloudSyncPhase.conflict);
      expect(
        outcome.status.conflictKind,
        CloudConflictKind.cloudAheadUnchanged,
      );
      expect(outcome.cloudMeta?.revision, 4);

      // Pastikan save lokal BELUM tertimpa secara diam-diam!
      final stillLocal = (await localSaveRepo.loadSnapshot())!;
      expect(stillLocal.character.progress.level, 1);
      expect(stillLocal.character.progress.gold, 0);

      // Diblokir saat dungeon run aktif
      final blocked = await service.restoreFromCloud(isDungeonRunActive: true);
      expect(blocked, isA<CloudRestoreBlockedActiveRun>());

      // Konfirmasi pemulihan membuat cadangan lokal & memulihkan snapshot secara atomik
      final restored = await service.restoreFromCloud(
        isDungeonRunActive: false,
      );
      expect(restored, isA<CloudRestoreSuccess>());
      final afterRestore = (await localSaveRepo.loadSnapshot())!;
      expect(afterRestore.character.progress.level, 12);
      expect(afterRestore.character.progress.gold, 9999);
      expect(afterRestore.activeDungeonSession, isNull);
      expect(
        afterRestore.offlineActivity.mode,
        OfflineActivityMode.pauseProgression,
      );

      final backups = await LocalBackupService(db: localDb).listBackups();
      expect(backups.length, 1);
      final unpackedBackup = const SaveBlobPacker().unpack(
        backups.first.blob,
        expectedSha256: backups.first.blobSha256,
        config: config,
      );
      expect(unpackedBackup.character.progress.level, 1);

      final syncState = await DriftCloudSyncStateRepository(db: localDb)
          .getOrCreateState();
      expect(syncState.lastSyncedRevision, 4);
    });

    test('save bercabang (lokal & cloud sama-sama berubah) masuk ke conflict, tidak menimpa cloud', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.initialize();
      addTearDown(db.close);
      final clock = _MutableClock(1700000000000);
      final auth = _ConfigurableAuthGateway();
      final cloudRepo = _CountingCloudSaveRepository(
        serverNowMs: () => clock.nowMs,
      );
      final saveRepo = DriftPlayerSaveRepository(
        db: db,
        config: config,
        clock: clock,
      );
      await saveRepo.saveSnapshot(_makeSnapshot(level: 3, gold: 300));

      final service = createService(
        db: db,
        clock: clock,
        authGateway: auth,
        cloudRepo: cloudRepo,
        saveRepoOverride: saveRepo,
      );

      await service.sync(SyncTrigger.appOpen); // rev 1

      // Simulasikan perangkat lain mengunggah rev 2
      final remote2 = (await saveRepo.loadSnapshot())!;
      final packed2 = const SaveBlobPackerAdapter().pack(remote2);
      final metrics2 = const SaveMetricsCalculator().compute(
        snapshot: remote2,
        config: config,
        blobBytes: packed2.blobBytes,
        blobSha256: packed2.sha256Hex,
        schemaVersion: 8,
        codecVersion: packed2.codecVersion,
      );
      cloudRepo.seedSlot(
        CloudSaveDownload(
          meta: CloudSaveMeta(
            revision: 2,
            slot: 0,
            savedAtServerMs: clock.nowMs + 1000,
            deviceId: 'second-device',
            appVersion: '1.0.0',
            metrics: metrics2,
          ),
          blob: packed2.compressedBytes,
        ),
      );

      // Lokal juga berubah
      clock.nowMs += 10 * 60 * 1000;
      await saveRepo.saveSnapshot(_makeSnapshot(level: 6, gold: 1200));

      final uploadsBefore = cloudRepo.uploadCalls;
      final conflictOutcome = await service.sync(SyncTrigger.appOpen);
      expect(conflictOutcome.kind, SyncOutcomeKind.conflict);
      expect(
        conflictOutcome.status.conflictKind,
        CloudConflictKind.divergedSave,
      );
      expect(cloudRepo.uploadCalls, uploadsBefore);
    });

    test('credential-already-in-use account switch memblokir unggahan otomatis hingga pemain memilih', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.initialize();
      addTearDown(db.close);
      final clock = _MutableClock(1700000000000);
      final auth = _ConfigurableAuthGateway()
        ..account = const CloudAccountSnapshot(
          kind: CloudAccountKind.anonymous,
          uid: 'anon-1',
        )
        ..nextLinkResult = const AuthLinkCredentialInUseSwitched(
          CloudAccountSnapshot(
            kind: CloudAccountKind.emailLinked,
            uid: 'email-existing-uid',
            email: 'hero@example.com',
          ),
        );
      final cloudRepo = _CountingCloudSaveRepository(
        serverNowMs: () => clock.nowMs,
      );
      final saveRepo = DriftPlayerSaveRepository(
        db: db,
        config: config,
        clock: clock,
      );
      await saveRepo.saveSnapshot(_makeSnapshot(level: 8, gold: 5000));

      final service = createService(
        db: db,
        clock: clock,
        authGateway: auth,
        cloudRepo: cloudRepo,
        saveRepoOverride: saveRepo,
      );

      final linkOutcome = await service.linkEmailAccount(
        email: 'hero@example.com',
        password: 'password123',
      );
      expect(linkOutcome, isA<EmailAuthSwitchedAccountConflict>());
      expect(service.status.phase, CloudSyncPhase.conflict);
      expect(service.status.conflictKind, CloudConflictKind.accountSwitch);

      // Sync otomatis tidak boleh langsung menimpa akun baru
      final syncOutcome = await service.sync(SyncTrigger.manual);
      expect(syncOutcome.kind, SyncOutcomeKind.conflict);
      expect(cloudRepo.uploadCalls, 0);

      // Reset password memperbarui infoMessage tanpa mengubah konflik/save
      final resetOutcome = await service.sendPasswordReset(
        email: 'hero@example.com',
      );
      expect(resetOutcome, isA<PasswordResetSent>());
      expect(service.status.infoMessage, contains('hero@example.com'));
    });

    test('penolakan rules memicu diagnosis CloudLimits, simpan lastRejectCode, backoff 60m, dan bypass manual', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.initialize();
      addTearDown(db.close);
      final clock = _MutableClock(1700000000000);
      final auth = _ConfigurableAuthGateway();
      final cloudRepo = _CountingCloudSaveRepository(
        serverNowMs: () => clock.nowMs,
      );
      final saveRepo = DriftPlayerSaveRepository(
        db: db,
        config: config,
        clock: clock,
      );
      await saveRepo.saveSnapshot(_makeSnapshot(level: 3, gold: 300));

      final service = createService(
        db: db,
        clock: clock,
        authGateway: auth,
        cloudRepo: cloudRepo,
        saveRepoOverride: saveRepo,
      );

      // Revisi 1 sukses
      await service.sync(SyncTrigger.appOpen);

      // Lonjakan gold tidak wajar lalu server menolak unggahan
      clock.nowMs += 10 * 60 * 1000;
      await saveRepo.saveSnapshot(_makeSnapshot(level: 3, gold: 999999999));
      cloudRepo.uploadValidatorHook = (req, prev) {
        if (req.metrics.gold > 100000) {
          return const CloudRejected<CloudSaveMeta>(
            code: 'permission-denied',
            message: 'Kenaikan gold melebihi batas.',
          );
        }
        return null;
      };

      final rejected = await service.sync(SyncTrigger.appOpen);
      expect(rejected.kind, SyncOutcomeKind.rejected);
      expect(rejected.status.phase, CloudSyncPhase.rejected);
      expect(rejected.status.lastRejectMessage, isNotEmpty);

      // 10 menit kemudian auto-sync tertahan reject backoff 60 menit
      clock.nowMs += 10 * 60 * 1000;
      final skipped = await service.sync(SyncTrigger.appOpen);
      expect(skipped.kind, SyncOutcomeKind.skippedRejectBackoff);

      // Manual tetap bisa mencoba (misal setelah data valid & fault clear)
      await saveRepo.saveSnapshot(_makeSnapshot(level: 3, gold: 450));
      final manual = await service.sync(SyncTrigger.manual);
      expect(manual.kind, SyncOutcomeKind.uploaded);
      expect(manual.status.lastRejectCode, isNull);
    });

    test('backoff jaringan eksponensial (1, 5, 30 menit), reset saat pulih, blob korup gagal aman, dan antrean tunggal', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.initialize();
      addTearDown(db.close);
      final clock = _MutableClock(1700000000000);
      final auth = _ConfigurableAuthGateway();
      final cloudRepo = _CountingCloudSaveRepository(
        serverNowMs: () => clock.nowMs,
      );
      final saveRepo = DriftPlayerSaveRepository(
        db: db,
        config: config,
        clock: clock,
      );
      await saveRepo.saveSnapshot(_makeSnapshot(level: 2, gold: 100));

      final service = createService(
        db: db,
        clock: clock,
        authGateway: auth,
        cloudRepo: cloudRepo,
        saveRepoOverride: saveRepo,
      );

      cloudRepo.nextFault = CloudFaultMode.networkError;
      final f1 = await service.sync(SyncTrigger.appOpen);
      expect(f1.kind, SyncOutcomeKind.offline);
      expect(f1.status.consecutiveNetworkFailures, 1);

      // 30 detik kemudian masih dalam backoff 1 menit
      clock.nowMs += 30 * 1000;
      final b1 = await service.sync(SyncTrigger.appOpen);
      expect(b1.kind, SyncOutcomeKind.skippedOfflineBackoff);

      // +31 detik -> gagal ke-2 (backoff 5 menit)
      clock.nowMs += 31 * 1000;
      final f2 = await service.sync(SyncTrigger.appOpen);
      expect(f2.kind, SyncOutcomeKind.offline);
      expect(f2.status.consecutiveNetworkFailures, 2);

      // Pulih via manual
      cloudRepo.nextFault = CloudFaultMode.none;
      final recovered = await service.sync(SyncTrigger.manual);
      expect(recovered.kind, SyncOutcomeKind.uploaded);
      expect(recovered.status.consecutiveNetworkFailures, 0);

      // Antrean tunggal: 2 panggilan manual paralel tidak boleh saling tabrak revisi
      clock.nowMs += 1000;
      await saveRepo.saveSnapshot(_makeSnapshot(level: 2, gold: 222));
      final parallel = await Future.wait([
        service.sync(SyncTrigger.manual),
        service.sync(SyncTrigger.manual),
      ]);
      expect(parallel[0].kind, SyncOutcomeKind.uploaded);
      expect(parallel[1].kind, SyncOutcomeKind.skippedNoChanges);

      // Uji pemulihan gagal karena hash korup tanpa merusak save lokal
      final corruptRepo = _CorruptingCloudSaveRepository(
        serverNowMs: () => clock.nowMs,
      );
      final cur = (await saveRepo.loadSnapshot())!;
      final goodPack = const SaveBlobPackerAdapter().pack(cur);
      final goodMetrics = const SaveMetricsCalculator().compute(
        snapshot: cur,
        config: config,
        blobBytes: goodPack.blobBytes,
        blobSha256: goodPack.sha256Hex,
        schemaVersion: 8,
        codecVersion: goodPack.codecVersion,
      );
      final corruptBytes = Uint8List.fromList(goodPack.compressedBytes);
      corruptBytes[0] = corruptBytes[0] ^ 0xFF;
      corruptRepo.customDownload = CloudSaveDownload(
        meta: CloudSaveMeta(
          revision: 9,
          slot: 1,
          savedAtServerMs: clock.nowMs,
          deviceId: 'other',
          appVersion: '1.0.0',
          metrics: goodMetrics,
        ),
        blob: corruptBytes,
      );

      final corruptService = createService(
        db: db,
        clock: clock,
        authGateway: auth,
        cloudRepo: corruptRepo,
        saveRepoOverride: saveRepo,
      );
      final corruptRestore = await corruptService.restoreFromCloud(
        isDungeonRunActive: false,
      );
      expect(corruptRestore, isA<CloudRestoreFailed>());
    });

    test('migrasi save cloud v10 (Lv 604, Rank 13) -> v11 (Lv 90, Rank 5) diterima saat unggah & dikonversi saat pulihkan', () async {
      final clock = _MutableClock(1700000000000);
      final legacySnap = _makeSnapshot(
        level: 604,
        gold: 100000,
        cycleProgress: const CycleProgress(
          ascensionRank: 13,
          highestAscensionRank: 13,
        ),
        currencies: const {'aether_shard': 100},
      );
      const packer = SaveBlobPackerAdapter();
      final legacyPacked = packer.pack(legacySnap);
      final legacyMetrics = const SaveMetricsCalculator().compute(
        snapshot: legacySnap,
        config: config,
        blobBytes: legacyPacked.blobBytes,
        blobSha256: legacyPacked.sha256Hex,
        schemaVersion: 10,
        codecVersion: legacyPacked.codecVersion,
      );

      final cloudRepo = _CountingCloudSaveRepository(
        serverNowMs: () => clock.nowMs,
      );
      cloudRepo.uploadValidatorHook = (req, prev) {
        final prevCandidate = prev == null
            ? null
            : CloudSaveCandidate.fromMeta(prev);
        final nextCandidate = CloudSaveCandidate.fromMetrics(
          req.metrics,
          revision: req.newRevision,
          deviceId: req.deviceId,
          appVersion: req.appVersion,
          actualBlobLength: req.blob.length,
        );
        final dt = prev == null
            ? 0.0
            : (clock.nowMs - prev.savedAtServerMs) / 1000.0;
        final violations = const CloudLimits().explainViolation(
          prevCandidate,
          nextCandidate,
          dt,
        );
        if (violations.isNotEmpty) {
          return CloudRejected<CloudSaveMeta>(
            code: 'permission-denied',
            message: violations.map((v) => v.message).join(' '),
          );
        }
        return null;
      };

      cloudRepo.seedSlot(
        CloudSaveDownload(
          meta: CloudSaveMeta(
            revision: 68,
            slot: 0,
            savedAtServerMs: clock.nowMs - 60000,
            deviceId: 'dev-1',
            appVersion: '1.0.0+1',
            metrics: legacyMetrics,
          ),
          blob: legacyPacked.compressedBytes,
        ),
      );

      // Skenario 1: Perangkat sudah terkonversi lokal (Lv 90, Fase A6, Rank 5, Legacy Gift)
      // dengan lastSyncedRevision == 68 berhasil mengunggah Rev 69 ke cloud.
      final db1 = AppDatabase(NativeDatabase.memory());
      await db1.initialize();
      addTearDown(db1.close);
      final saveRepo1 = DriftPlayerSaveRepository(
        db: db1,
        config: config,
        clock: clock,
      );
      final convertedSnap = LegacySaveConverter.convertToV11IfNeeded(
        legacySnap,
        fromSchemaVersion: 10,
      );
      expect(convertedSnap.character.progress.level, 90);
      expect(convertedSnap.character.progress.ascensionPhase, 6);
      expect(convertedSnap.character.progress.gold, 100000 + (604 - 90) * 5000);
      expect(convertedSnap.currencies['aether_shard'], 100 + (604 - 90) * 20);
      expect(convertedSnap.currencies['soul_prism'], (604 - 90) ~/ 10);
      expect(convertedSnap.cycleProgress.ascensionRank, 5);
      expect(convertedSnap.cycleProgress.highestAscensionRank, 5);

      await saveRepo1.saveSnapshot(convertedSnap);
      await DriftCloudSyncStateRepository(db: db1).markSynced(
        revision: 68,
        blobSha256: legacyPacked.sha256Hex,
        syncedAtMs: clock.nowMs - 60000,
      );

      final service1 = createService(
        db: db1,
        clock: clock,
        authGateway: _ConfigurableAuthGateway(),
        cloudRepo: cloudRepo,
        saveRepoOverride: saveRepo1,
        schemaVersion: 11,
        appVersion: '1.0.0+1',
      );
      final uploadOutcome = await service1.sync(SyncTrigger.manual);
      expect(uploadOutcome.kind, SyncOutcomeKind.uploaded);
      expect(uploadOutcome.cloudMeta?.revision, 69);
      expect(uploadOutcome.cloudMeta?.metrics.level, 90);
      expect(uploadOutcome.cloudMeta?.metrics.highestAscensionRank, 5);
      expect(uploadOutcome.cloudMeta?.metrics.schemaVersion, 11);

      // Skenario 2: Restore dari cloud save v10 otomatis mengonversi ke M16 v11 & siap diunggah ulang.
      final cloudRepo2 = _CountingCloudSaveRepository(
        serverNowMs: () => clock.nowMs,
      );
      cloudRepo2.uploadValidatorHook = cloudRepo.uploadValidatorHook;
      cloudRepo2.seedSlot(
        CloudSaveDownload(
          meta: CloudSaveMeta(
            revision: 68,
            slot: 0,
            savedAtServerMs: clock.nowMs - 60000,
            deviceId: 'dev-old',
            appVersion: '1.0.0+1',
            metrics: legacyMetrics,
          ),
          blob: legacyPacked.compressedBytes,
        ),
      );
      final db2 = AppDatabase(NativeDatabase.memory());
      await db2.initialize();
      addTearDown(db2.close);
      final saveRepo2 = DriftPlayerSaveRepository(
        db: db2,
        config: config,
        clock: clock,
      );
      final service2 = createService(
        db: db2,
        clock: clock,
        authGateway: _ConfigurableAuthGateway(),
        cloudRepo: cloudRepo2,
        saveRepoOverride: saveRepo2,
        schemaVersion: 11,
        appVersion: '1.0.0+1',
      );

      final restored = await service2.restoreFromCloud(
        isDungeonRunActive: false,
      );
      expect(restored, isA<CloudRestoreSuccess>());
      final success = restored as CloudRestoreSuccess;
      expect(success.restoredSnapshot.character.progress.level, 90);
      expect(success.restoredSnapshot.character.progress.ascensionPhase, 6);
      expect(success.restoredSnapshot.cycleProgress.highestAscensionRank, 5);
      expect(success.status.phase, CloudSyncPhase.pendingChanges);

      clock.nowMs += 1000;
      final reSync = await service2.sync(SyncTrigger.manual);
      expect(reSync.kind, SyncOutcomeKind.uploaded);
      expect(reSync.cloudMeta?.revision, 69);
      expect(reSync.cloudMeta?.metrics.schemaVersion, 11);
    });

    test('pengingat update aplikasi terdeteksi dari cloud schema lebih baru, appVersion lebih baru, dan versionInfo remote', () async {
      expect(AppVersionComparator.compare('1.0.0+1', '1.0.0+2'), lessThan(0));
      expect(AppVersionComparator.compare('1.1.0', '1.0.9+99'), greaterThan(0));

      final clock = _MutableClock(1700000000000);
      final db = AppDatabase(NativeDatabase.memory());
      await db.initialize();
      addTearDown(db.close);
      final saveRepo = DriftPlayerSaveRepository(
        db: db,
        config: config,
        clock: clock,
      );
      await saveRepo.saveSnapshot(_makeSnapshot(level: 10, gold: 500));

      final remoteSnap = (await saveRepo.loadSnapshot())!;
      const packer = SaveBlobPackerAdapter();
      final remotePacked = packer.pack(remoteSnap);

      // 1. Cloud memakai schemaVersion lebih baru (v12 > lokal v11) -> blokir sync & minta update.
      final cloudRepo = _CountingCloudSaveRepository(
        serverNowMs: () => clock.nowMs,
      );
      cloudRepo.seedSlot(
        CloudSaveDownload(
          meta: CloudSaveMeta(
            revision: 3,
            slot: 1,
            savedAtServerMs: clock.nowMs - 5000,
            deviceId: 'other-dev',
            appVersion: '1.2.0+5',
            metrics: const SaveMetricsCalculator().compute(
              snapshot: remoteSnap,
              config: config,
              blobBytes: remotePacked.blobBytes,
              blobSha256: remotePacked.sha256Hex,
              schemaVersion: 12,
              codecVersion: remotePacked.codecVersion,
            ),
          ),
          blob: remotePacked.compressedBytes,
        ),
      );

      final service = createService(
        db: db,
        clock: clock,
        authGateway: _ConfigurableAuthGateway(),
        cloudRepo: cloudRepo,
        saveRepoOverride: saveRepo,
        schemaVersion: 11,
        appVersion: '1.0.0+1',
      );

      final blocked = await service.sync(SyncTrigger.appOpen);
      expect(blocked.kind, SyncOutcomeKind.rejected);
      expect(blocked.status.isUpdateRequiredForSync, isTrue);
      expect(blocked.status.updateAvailableVersion, '1.2.0+5');
      expect(blocked.status.updateAvailableSchemaVersion, 12);
      expect(
        blocked.status.updateReminderMessage,
        contains('Perbarui aplikasi'),
      );

      // 2. Schema kompatibel, tetapi fetchVersionInfo melaporkan versi baru tersedia.
      final cloudRepo2 =
          _CountingCloudSaveRepository(serverNowMs: () => clock.nowMs)
            ..versionInfo = const RemoteAppVersionInfo(
              latestAppVersion: '1.3.0+10',
              latestSchemaVersion: 11,
              releaseNotes: 'Perbaikan Cloud Sync & keseimbangan Spire',
            );
      final service2 = createService(
        db: db,
        clock: clock,
        authGateway: _ConfigurableAuthGateway(),
        cloudRepo: cloudRepo2,
        saveRepoOverride: saveRepo,
        schemaVersion: 11,
        appVersion: '1.0.0+1',
      );

      final ok = await service2.sync(SyncTrigger.appOpen);
      expect(ok.kind, SyncOutcomeKind.uploaded);
      expect(ok.status.isUpdateRequiredForSync, isFalse);
      expect(ok.status.updateAvailableVersion, '1.3.0+10');
      expect(
        ok.status.updateReminderMessage,
        contains('Perbaikan Cloud Sync & keseimbangan Spire'),
      );
    });
  });
}
