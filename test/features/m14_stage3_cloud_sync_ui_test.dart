import 'dart:io';

import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/providers/cloud_sync_provider.dart';
import 'package:echoes_of_aether/application/providers/database_provider.dart';
import 'package:echoes_of_aether/application/providers/game_config_provider.dart';
import 'package:echoes_of_aether/application/services/account_service.dart';
import 'package:echoes_of_aether/application/services/app_update_service.dart';
import 'package:echoes_of_aether/application/services/cloud_sync_service.dart';
import 'package:echoes_of_aether/data/cloud/firebase_bootstrap.dart';
import 'package:echoes_of_aether/data/cloud/github_release_checker.dart';
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
import 'package:echoes_of_aether/data/repositories/drift_player_save_repository.dart';
import 'package:echoes_of_aether/domain/entities/game_config.dart';
import 'package:echoes_of_aether/domain/entities/offline_activity.dart';
import 'package:echoes_of_aether/domain/entities/player_progress.dart';
import 'package:echoes_of_aether/domain/entities/player_save_snapshot.dart';
import 'package:echoes_of_aether/domain/entities/save_metrics.dart';
import 'package:echoes_of_aether/domain/repositories/cloud_save_repository.dart';
import 'package:echoes_of_aether/features/dungeon/cloud_sync_section.dart';
import 'package:echoes_of_aether/features/dungeon/dungeon_screen.dart';
import 'package:echoes_of_aether/features/dungeon/settings_overlay.dart';
import 'package:echoes_of_aether/features/dungeon/town_hub_view.dart';
import 'package:echoes_of_aether/features/dungeon/update_reminder_dialog.dart';
import 'package:echoes_of_aether/domain/entities/game_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

Future<void> _flushDb() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

void main() {
  late GameConfig config;

  setUpAll(() {
    config = _loadRealConfig();
  });

  group('CloudSyncSection UI & Dialogs', () {
    testWidgets(
      'menampilkan semua status akun/sinkronisasi, memicu callback, dan membuka section',
      (tester) async {
        var openedCalls = 0;
        var linkCalls = 0;
        var signInCalls = 0;
        var resetCalls = 0;
        var signOutCalls = 0;
        var syncNowCalls = 0;
        var returnFailFirst = true;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CloudSyncSection(
                  status: const CloudSyncStatusSnapshot(
                    phase: CloudSyncPhase.pendingChanges,
                    account: CloudAccountSnapshot(
                      kind: CloudAccountKind.anonymous,
                      uid: 'anon-1234567890',
                    ),
                    lastSyncedRevision: 2,
                    lastSyncAtMs: 1700000000000,
                  ),
                  isDungeonRunActive: false,
                  onSectionOpened: () => openedCalls++,
                  onLinkEmail: ({required email, required password}) async {
                    linkCalls++;
                    if (returnFailFirst) {
                      returnFailFirst = false;
                      return const EmailAuthFailed(
                        'Kata sandi minimal 6 karakter.',
                      );
                    }
                    return const EmailAuthSuccess(
                      CloudAccountSnapshot(
                        kind: CloudAccountKind.emailLinked,
                        uid: 'anon-1234567890',
                        email: 'hero@example.com',
                      ),
                    );
                  },
                  onSignInEmail: ({required email, required password}) async {
                    signInCalls++;
                    return const EmailAuthSwitchedAccountConflict(
                      CloudAccountSnapshot(
                        kind: CloudAccountKind.emailLinked,
                        uid: 'existing-1',
                        email: 'hero@example.com',
                      ),
                    );
                  },
                  onResetPassword: ({required email}) async {
                    resetCalls++;
                    return PasswordResetSent(email);
                  },
                  onSignOut: () async => signOutCalls++,
                  onSyncNow: () async => syncNowCalls++,
                  onConfirmRestore: () async {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(openedCalls, 1);
        expect(find.byKey(const Key('cloud_account_label')), findsOneWidget);
        expect(find.textContaining('Akun Anonim'), findsOneWidget);
        expect(find.text('Ada perubahan belum tersinkron'), findsOneWidget);

        await tester.ensureVisible(
          find.byKey(const Key('cloud_link_email_btn')),
        );
        await tester.tap(find.byKey(const Key('cloud_link_email_btn')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('cloud_email_auth_dialog')),
          findsOneWidget,
        );
        await tester.enterText(
          find.byKey(const Key('cloud_email_field')),
          'hero@example.com',
        );
        await tester.enterText(
          find.byKey(const Key('cloud_password_field')),
          '123',
        );
        await tester.tap(find.text('Tautkan Akun'));
        await tester.pumpAndSettle();

        // Gagal validasi menampilkan pesan error inline tanpa menutup dialog
        expect(linkCalls, 1);
        expect(find.byKey(const Key('cloud_email_auth_error')), findsOneWidget);

        // Uji mode Masuk Akun Lama & lupa password lalu submit
        await tester.tap(find.byKey(const Key('cloud_mode_signin_chip')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('cloud_reset_password_btn')));
        await tester.pumpAndSettle();
        expect(resetCalls, 1);
        expect(find.byKey(const Key('cloud_email_auth_info')), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('cloud_password_field')),
          'secret123',
        );
        await tester.tap(find.text('Masuk'));
        await tester.pumpAndSettle();
        expect(signInCalls, 1);
        expect(find.byKey(const Key('cloud_conflict_dialog')), findsOneWidget);
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(const Key('cloud_sync_now_btn')));
        await tester.tap(find.byKey(const Key('cloud_sync_now_btn')));
        await tester.pump();
        expect(syncNowCalls, 1);

        await tester.ensureVisible(find.byKey(const Key('cloud_sign_out_btn')));
        await tester.tap(find.byKey(const Key('cloud_sign_out_btn')));
        await tester.pump();
        expect(signOutCalls, 1);

        // Periksa status Email terhubung + ditolak + pesan penolakan
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CloudSyncSection(
                status: const CloudSyncStatusSnapshot(
                  phase: CloudSyncPhase.rejected,
                  account: CloudAccountSnapshot(
                    kind: CloudAccountKind.emailLinked,
                    uid: 'e-1',
                    email: 'player@example.com',
                  ),
                  lastRejectCode: 'permission-denied',
                  lastRejectMessage: 'Kenaikan gold melebihi batas.',
                ),
                isDungeonRunActive: false,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.text('Email terhubung (player@example.com)'),
          findsOneWidget,
        );
        expect(
          find.text('Ditolak: Kenaikan gold melebihi batas.'),
          findsOneWidget,
        );
        expect(
          find.text('Penolakan terakhir: Kenaikan gold melebihi batas.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('cloud_link_email_btn')), findsNothing);
      },
    );

    testWidgets(
      'pemulihan dari cloud mewajibkan dialog konfirmasi dan diblokir saat dungeon run aktif',
      (tester) async {
        var restoreCalls = 0;

        // 1. Saat run aktif -> tampilkan pesan blokir, tidak buka dialog maupun callback
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CloudSyncSection(
                status: const CloudSyncStatusSnapshot(
                  phase: CloudSyncPhase.synced,
                  account: CloudAccountSnapshot(
                    kind: CloudAccountKind.emailLinked,
                    uid: 'e-1',
                    email: 'hero@example.com',
                  ),
                ),
                isDungeonRunActive: true,
                onConfirmRestore: () async => restoreCalls++,
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('cloud_restore_btn')));
        await tester.pump();
        expect(
          find.byKey(const Key('cloud_restore_blocked_label')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('cloud_restore_confirm_dialog')),
          findsNothing,
        );
        expect(restoreCalls, 0);

        // 2. Saat tidak ada run aktif -> buka dialog konfirmasi terlebih dahulu
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CloudSyncSection(
                status: const CloudSyncStatusSnapshot(
                  phase: CloudSyncPhase.synced,
                  account: CloudAccountSnapshot(
                    kind: CloudAccountKind.emailLinked,
                    uid: 'e-1',
                    email: 'hero@example.com',
                  ),
                ),
                isDungeonRunActive: false,
                onConfirmRestore: () async => restoreCalls++,
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byKey(const Key('cloud_restore_btn')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('cloud_restore_confirm_dialog')),
          findsOneWidget,
        );

        // Batal -> tidak memanggil restore
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();
        expect(restoreCalls, 0);

        // Konfirmasi -> memanggil restore
        await tester.tap(find.byKey(const Key('cloud_restore_btn')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Pulihkan dari cloud').last);
        await tester.pumpAndSettle();
        expect(restoreCalls, 1);
      },
    );

    testWidgets(
      'showCloudConflictDialog menangani konflik dan menonaktifkan pemulihan saat run aktif',
      (tester) async {
        const meta = CloudSaveMeta(
          revision: 7,
          slot: 1,
          savedAtServerMs: 1700000000000,
          deviceId: 'dev-other',
          appVersion: '1.0.0',
          metrics: SaveMetrics(
            level: 22,
            gold: 8800,
            shards: 15,
            highestAscensionRank: 1,
            lifetimeClears: 4,
            dailyQuestDone: 2,
            weeklyQuestDone: 1,
            eventPurchasesLifetime: 0,
            equipmentCount: 6,
            blobBytes: 1200,
            blobSha256: 'abc',
            schemaVersion: 8,
            codecVersion: 1,
          ),
        );

        bool? dialogResult;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    dialogResult = await showCloudConflictDialog(
                      context,
                      kind: CloudConflictKind.divergedSave,
                      cloudMeta: meta,
                      isDungeonRunActive: false,
                    );
                  },
                  child: const Text('Open Conflict'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Conflict'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('cloud_conflict_dialog')), findsOneWidget);
        expect(find.text('Save Cloud (Revisi 7)'), findsOneWidget);
        expect(
          find.text('Lv 22 • Rank Ascension 1 • Gold 8800'),
          findsOneWidget,
        );

        await tester.tap(find.text('Pulihkan dari cloud'));
        await tester.pumpAndSettle();
        expect(dialogResult, isTrue);

        // Saat run aktif tombol primary disembunyikan & pesan blokir muncul
        bool? activeResult;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    activeResult = await showCloudConflictDialog(
                      context,
                      kind: CloudConflictKind.accountSwitch,
                      cloudMeta: meta,
                      isDungeonRunActive: true,
                    );
                  },
                  child: const Text('Open Blocked'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Blocked'));
        await tester.pumpAndSettle();
        expect(find.text('Pulihkan dari cloud'), findsNothing);
        expect(
          find.text('Pemulihan diblokir selama dungeon run aktif.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();
        expect(activeResult, isFalse);
      },
    );

    testWidgets(
      'DungeonScreen berjalan penuh saat Firebase CloudUnavailable dan menampilkan status di Pengaturan',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = AppDatabase(NativeDatabase.memory());
        await tester.runAsync(() async {
          await db.initialize();
          final repo = DriftPlayerSaveRepository(db: db, config: config);
          await repo.saveSnapshot(
            const PlayerSaveSnapshot(
              character: PlayerCharacterSnapshot(
                progress: PlayerProgress(level: 5, gold: 250),
              ),
              inventory: InventorySnapshot(),
              offlineActivity: OfflineActivitySnapshot.paused(),
            ),
          );
        });
        addTearDown(() => tester.runAsync(db.close));

        final failedBootstrap = FirebaseBootstrap(
          initializeFirebase: () async =>
              throw StateError('No Play Services on test device'),
        );
        await failedBootstrap.initialize();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              gameConfigProvider.overrideWith((ref) async => config),
              playerSaveRepositoryProvider.overrideWith(
                (ref) async =>
                    DriftPlayerSaveRepository(db: db, config: config),
              ),
              firebaseBootstrapProvider.overrideWithValue(failedBootstrap),
            ],
            child: const MaterialApp(
              home: DungeonScreen(roomTransitionDelaySeconds: 0.05),
            ),
          ),
        );

        for (var i = 0; i < 20; i++) {
          await tester.pump();
          await tester.runAsync(_flushDb);
          await tester.pump();
          if (find.byType(TownHubView).evaluate().isNotEmpty) break;
        }
        expect(find.byType(TownHubView), findsOneWidget);

        await tester.tap(find.text('Settings'));
        await tester.pump();
        await tester.runAsync(_flushDb);
        await tester.pump();

        expect(find.text('Cloud Save & Akun'), findsOneWidget);
        expect(
          find.byKey(const Key('cloud_sync_status_label')),
          findsOneWidget,
        );
        expect(find.text('Layanan cloud tidak tersedia'), findsOneWidget);
        expect(find.byKey(const Key('cloud_sync_now_btn')), findsNothing);
        await tester.runAsync(_flushDb);
      },
    );

    testWidgets(
      'UpdateReminderBanner, showSystemUpdateNoticeDialog, dan tombol Catatan Update di Settings bekerja',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CloudSyncSection(
                  status: const CloudSyncStatusSnapshot(
                    phase: CloudSyncPhase.rejected,
                    account: CloudAccountSnapshot(
                      kind: CloudAccountKind.emailLinked,
                      uid: 'e-1',
                      email: 'hero@example.com',
                    ),
                    updateAvailableVersion: '1.2.0+5',
                    updateAvailableSchemaVersion: 12,
                    updateReminderMessage:
                        'Save cloud berasal dari versi aplikasi lebih baru.',
                    isUpdateRequiredForSync: true,
                  ),
                  isDungeonRunActive: false,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('cloud_update_reminder_banner')),
          findsOneWidget,
        );
        expect(find.text('v1.2.0+5'), findsOneWidget);
        expect(
          find.text('Save cloud berasal dari versi aplikasi lebih baru.'),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('cloud_update_reminder_detail_btn')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('app_update_available_dialog')),
          findsOneWidget,
        );
        await tester.tap(find.text('Tutup'));
        await tester.pumpAndSettle();

        // Uji showSystemUpdateNoticeDialog & tombol di SettingsOverlay
        final settingsNotifier = ValueNotifier(const GameSettingsData());
        addTearDown(settingsNotifier.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: SettingsOverlay(
                  settings: settingsNotifier,
                  onChanged: (_) {},
                  onClose: () {},
                  onOpenUpdateNotice: () => showSystemUpdateNoticeDialog(
                    context,
                    appVersion: '1.0.0+1',
                    playerLevel: 90,
                    ascensionPhase: 6,
                    highestAscensionRank: 5,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.ensureVisible(
          find.byKey(const Key('settings_update_notice_btn')),
        );
        await tester.tap(find.byKey(const Key('settings_update_notice_btn')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('system_update_notice_dialog')),
          findsOneWidget,
        );
        expect(
          find.text('v1.0.0+1 • Lv 90 • Fase A6 • Rank 5'),
          findsOneWidget,
        );
        await tester.tap(find.text('Mengerti'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('system_update_notice_dialog')),
          findsNothing,
        );
      },
    );

    test(
      'lastSeenUpdateNoticeVersion dipersistensikan di GameSettings Drift',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await db.initialize();
        final repo = DriftPlayerSaveRepository(db: db, config: config);

        final initial = await repo.loadSettings();
        expect(initial.lastSeenUpdateNoticeVersion, 0);

        await repo.saveSettings(
          initial.copyWith(
            lastSeenUpdateNoticeVersion: kLatestSystemUpdateNoticeVersion,
          ),
        );
        final reloaded = await repo.loadSettings();
        expect(
          reloaded.lastSeenUpdateNoticeVersion,
          kLatestSystemUpdateNoticeVersion,
        );
      },
    );

    test('GithubReleaseChecker.parseReleaseJson & AppUpdateService mendeteksi rilis APK lebih baru', () async {
      const sampleJson = '''
      {
        "tag_name": "v1.2.0+3",
        "name": "Echoes of Aether v1.2.0",
        "html_url": "https://github.com/hyenavia/echoes_of_aether/releases/tag/v1.2.0+3",
        "body": "Perbaikan Cloud Sync & rebalancing.",
        "draft": false,
        "assets": [
          {
            "name": "app-release.apk",
            "browser_download_url": "https://github.com/hyenavia/echoes_of_aether/releases/download/v1.2.0+3/app-release.apk"
          }
        ]
      }
      ''';
      final parsed = GithubReleaseChecker.parseReleaseJson(sampleJson);
      expect(parsed, isNotNull);
      expect(parsed!.latestVersion, '1.2.0+3');
      expect(parsed.hasDirectApk, isTrue);
      expect(parsed.preferredActionUrl, endsWith('/app-release.apk'));

      final service = AppUpdateService(
        source: _FakeReleaseSource(parsed),
        currentVersion: '1.0.0+1',
      );
      final check = await service.checkForUpdate();
      expect(check.hasUpdate, isTrue);
      expect(check.releaseInfo?.latestVersion, '1.2.0+3');

      final upToDate = await const AppUpdateService(
        source: _FakeReleaseSource(
          AppReleaseUpdateInfo(
            latestVersion: '1.0.0+1',
            releaseUrl: 'https://github.com/hyenavia/echoes_of_aether/releases',
          ),
        ),
        currentVersion: '1.0.0+1',
      ).checkForUpdate();
      expect(upToDate.hasUpdate, isFalse);
    });

    testWidgets(
      'DungeonScreen memunculkan popup update di beranda Town saat GitHub Releases punya versi lebih baru',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = AppDatabase(NativeDatabase.memory());
        await tester.runAsync(() async {
          await db.initialize();
          final repo = DriftPlayerSaveRepository(db: db, config: config);
          await repo.saveSnapshot(
            const PlayerSaveSnapshot(
              character: PlayerCharacterSnapshot(
                progress: PlayerProgress(level: 5, gold: 250),
              ),
              inventory: InventorySnapshot(),
              offlineActivity: OfflineActivitySnapshot.paused(),
            ),
          );
        });
        addTearDown(() => tester.runAsync(db.close));

        final failedBootstrap = FirebaseBootstrap(
          initializeFirebase: () async =>
              throw StateError('No Play Services on test device'),
        );
        await failedBootstrap.initialize();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              gameConfigProvider.overrideWith((ref) async => config),
              playerSaveRepositoryProvider.overrideWith(
                (ref) async =>
                    DriftPlayerSaveRepository(db: db, config: config),
              ),
              firebaseBootstrapProvider.overrideWithValue(failedBootstrap),
              appReleaseSourceProvider.overrideWithValue(
                const _FakeReleaseSource(
                  AppReleaseUpdateInfo(
                    latestVersion: '1.2.0+3',
                    releaseUrl: 'https://github.com/hyenavia/echoes_of_aether/releases/tag/v1.2.0+3',
                    apkDownloadUrl: 'https://github.com/hyenavia/echoes_of_aether/releases/download/v1.2.0+3/app-release.apk',
                    releaseNotes: 'Rilis baru tersedia dengan APK langsung.',
                  ),
                ),
              ),
            ],
            child: const MaterialApp(
              home: DungeonScreen(roomTransitionDelaySeconds: 0.05),
            ),
          ),
        );

        for (var i = 0; i < 20; i++) {
          await tester.pump();
          await tester.runAsync(_flushDb);
          await tester.pump();
          if (find
              .byKey(const Key('app_update_available_dialog'))
              .evaluate()
              .isNotEmpty) {
            break;
          }
        }

        expect(
          find.byKey(const Key('app_update_available_dialog')),
          findsOneWidget,
        );
        expect(find.text('Versi Terbaru: v1.2.0+3'), findsOneWidget);
        expect(find.text('Unduh APK'), findsOneWidget);
        expect(find.text('Nanti'), findsOneWidget);

        await tester.tap(find.text('Nanti'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('app_update_available_dialog')),
          findsNothing,
        );
        await tester.runAsync(_flushDb);
      },
    );
  });
}

class _FakeReleaseSource implements AppReleaseSource {
  const _FakeReleaseSource(this.info);

  final AppReleaseUpdateInfo? info;

  @override
  Future<AppReleaseUpdateInfo?> fetchLatestRelease() async => info;
}
