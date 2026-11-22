import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:echoes_of_aether/application/providers/database_provider.dart';
import 'package:echoes_of_aether/application/providers/game_config_provider.dart';
import 'package:echoes_of_aether/data/database/app_database.dart';
import 'package:echoes_of_aether/domain/repositories/game_config_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDatabase initialization & schema v3', () {
    test('membuka koneksi in-memory, memverifikasi schemaVersion 9, dan baca-tulis dasar', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      expect(db.schemaVersion, 12);
      await db.initialize();

      await db
          .into(db.gameSettings)
          .insert(
            GameSettingsCompanion.insert(key: 'auto_skill', value: 'true'),
          );

      final rows = await db.select(db.gameSettings).get();
      expect(rows, hasLength(1));
      expect(rows.single.key, 'auto_skill');
      expect(rows.single.value, 'true');
    });

    test(
      'provider database & config repository terhubung ke interface domain',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWith((ref) {
              ref.onDispose(db.close);
              return db;
            }),
          ],
        );

        final resolvedDb = container.read(appDatabaseProvider);
        await resolvedDb.initialize();

        final configRepo = container.read(gameConfigRepositoryProvider);
        expect(configRepo, isA<GameConfigRepository>());

        container.dispose();
      },
    );

    test(
      'menegakkan foreign keys, CHECK constraints, dan rollback transaksi',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await db.initialize();

        // Foreign key menolak child tanpa parent player.
        await expectLater(
          () => db
              .into(db.inventoryEntries)
              .insert(
                InventoryEntriesCompanion.insert(
                  playerId: 'missing_player',
                  itemId: 'slime_gel',
                  quantity: 1,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );

        // Foreign key komposit menolak equipped_items yang merujuk equipment tidak ada.
        await db
            .into(db.players)
            .insert(
              PlayersCompanion.insert(
                id: 'p1',
                level: 1,
                currentExp: 0,
                gold: 100,
                baseStatsJson: '{}',
                lastSavedAtMs: 1000,
              ),
            );
        await expectLater(
          () => db
              .into(db.equippedItems)
              .insert(
                EquippedItemsCompanion.insert(
                  playerId: 'p1',
                  slot: 'weapon',
                  equipmentInstanceId: 'ghost_eq',
                ),
              ),
          throwsA(isA<SqliteException>()),
        );

        // CHECK constraint menolak gold negatif dan quantity <= 0.
        await expectLater(
          () => db
              .into(db.players)
              .insert(
                PlayersCompanion.insert(
                  id: 'p_bad',
                  level: 1,
                  currentExp: 0,
                  gold: -5,
                  baseStatsJson: '{}',
                  lastSavedAtMs: 1000,
                ),
              ),
          throwsA(isA<SqliteException>()),
        );

        // Rollback transaksi membatalkan insert sebelumnya saat terjadi error.
        await expectLater(
          () => db.transaction(() async {
            await db
                .into(db.inventoryEntries)
                .insert(
                  InventoryEntriesCompanion.insert(
                    playerId: 'p1',
                    itemId: 'slime_gel',
                    quantity: 5,
                  ),
                );
            throw StateError('simulasi gagal di tengah transaksi');
          }),
          throwsStateError,
        );
        final entries = await db.select(db.inventoryEntries).get();
        expect(entries, isEmpty);

        // Delete cascade membersihkan child rows.
        await db
            .into(db.inventoryEntries)
            .insert(
              InventoryEntriesCompanion.insert(
                playerId: 'p1',
                itemId: 'slime_gel',
                quantity: 3,
              ),
            );
        await (db.delete(db.players)..where((t) => t.id.equals('p1'))).go();
        expect(await db.select(db.inventoryEntries).get(), isEmpty);
      },
    );

    test(
      'migrasi v1 ke v2 mempertahankan game_settings lama tanpa reset data',
      () async {
        final tempDir = Directory.systemTemp.createTempSync('echoes_db_mig_');
        addTearDown(() => tempDir.deleteSync(recursive: true));
        final dbFile = File('${tempDir.path}/legacy_v1.sqlite');

        // Buat database v1 sebelum AppDatabase v2 membukanya.
        final seedDb = NativeDatabase(
          dbFile,
          setup: (raw) {
            raw.execute(
              'CREATE TABLE IF NOT EXISTS game_settings '
              '(key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL);',
            );
            raw.execute(
              "INSERT OR REPLACE INTO game_settings (key, value) VALUES ('auto_skill', 'false');",
            );
            raw.execute('PRAGMA user_version = 1;');
          },
        );
        final v1Conn = DatabaseConnection(seedDb);
        await v1Conn.ensureOpen(_DummyVersionUser());
        await v1Conn.close();

        // Buka dengan AppDatabase v2: onUpgrade harus berjalan ke schema v2.
        final upgraded = AppDatabase(NativeDatabase(dbFile));
        addTearDown(upgraded.close);
        await upgraded.initialize();

        final settings = await upgraded.select(upgraded.gameSettings).get();
        expect(settings, hasLength(1));
        expect(settings.single.key, 'auto_skill');
        expect(settings.single.value, 'false');

        // Tabel baru v2 siap dipakai setelah migrasi.
        await upgraded
            .into(upgraded.players)
            .insert(
              PlayersCompanion.insert(
                id: 'migrated_player',
                level: 3,
                currentExp: 10,
                gold: 25,
                baseStatsJson: '{}',
                lastSavedAtMs: 5000,
              ),
            );
        expect(await upgraded.select(upgraded.players).get(), hasLength(1));
      },
    );
  });
}

class _DummyVersionUser extends QueryExecutorUser {
  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
