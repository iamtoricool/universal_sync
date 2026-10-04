import 'dart:math';

import 'package:drift/drift.dart';

import 'sync_tables.dart';

/// Version of the package-owned schema. Bumped with forward-only migrations.
const int kSyncSchemaVersion = 1;

/// SQL for the package-owned tables. Exported for teams that manage migrations
/// themselves.
const List<String> kSyncSchemaSql = [
  '''
  CREATE TABLE IF NOT EXISTS us_meta (
    key   TEXT NOT NULL PRIMARY KEY,
    value TEXT NOT NULL
  )''',
  '''
  CREATE TABLE IF NOT EXISTS us_outbox (
    sequence          INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    entity            TEXT    NOT NULL,
    key_hash          BLOB    NOT NULL,
    key_json          TEXT    NOT NULL,
    kind              TEXT    NOT NULL,
    row_json          TEXT,
    delta_json        TEXT,
    state             TEXT    NOT NULL,
    delivered_maybe   INTEGER NOT NULL DEFAULT 0,
    attempts          INTEGER NOT NULL DEFAULT 0,
    failures          INTEGER NOT NULL DEFAULT 0,
    next_attempt_at   INTEGER NOT NULL,
    lease_until       INTEGER,
    leased_by         TEXT,
    last_failure_json TEXT,
    created_at        INTEGER NOT NULL,
    updated_at        INTEGER NOT NULL
  )''',
  '''
  CREATE UNIQUE INDEX IF NOT EXISTS us_outbox_coalesce_uq
    ON us_outbox(entity, key_hash)
    WHERE state = 'pending' AND delivered_maybe = 0''',
  '''
  CREATE INDEX IF NOT EXISTS us_outbox_ready
    ON us_outbox(state, next_attempt_at, sequence)''',
  '''
  CREATE INDEX IF NOT EXISTS us_outbox_key
    ON us_outbox(entity, key_hash, sequence)''',
  '''
  CREATE TABLE IF NOT EXISTS us_cursors (
    entity      TEXT NOT NULL PRIMARY KEY,
    cursor_json TEXT,
    updated_at  INTEGER NOT NULL
  )''',
  '''
  CREATE TABLE IF NOT EXISTS us_tombstones (
    entity     TEXT NOT NULL,
    key_hash   BLOB NOT NULL,
    key_json   TEXT NOT NULL,
    source     TEXT NOT NULL,
    deleted_at INTEGER NOT NULL,
    acked_at   INTEGER,
    PRIMARY KEY (entity, key_hash)
  )''',
  '''
  CREATE INDEX IF NOT EXISTS us_tombstones_purge
    ON us_tombstones(acked_at, deleted_at)''',
  '''
  CREATE TABLE IF NOT EXISTS us_conflicts (
    id           INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    entity       TEXT NOT NULL,
    key_hash     BLOB NOT NULL,
    key_json     TEXT NOT NULL,
    local_json   TEXT,
    remote_json  TEXT NOT NULL,
    local_status TEXT NOT NULL,
    detected_at  INTEGER NOT NULL,
    resolved_at  INTEGER
  )''',
  '''
  CREATE UNIQUE INDEX IF NOT EXISTS us_conflicts_open_uq
    ON us_conflicts(entity, key_hash) WHERE resolved_at IS NULL''',
  '''
  CREATE TABLE IF NOT EXISTS us_dead_letters (
    sequence     INTEGER NOT NULL PRIMARY KEY,
    entity       TEXT NOT NULL,
    key_hash     BLOB NOT NULL,
    key_json     TEXT NOT NULL,
    kind         TEXT NOT NULL,
    payload_json TEXT,
    failure_json TEXT NOT NULL,
    failed_at    INTEGER NOT NULL
  )''',
  '''
  CREATE INDEX IF NOT EXISTS us_dead_letters_age
    ON us_dead_letters(failed_at)''',
];

/// Thrown when the database contains a newer sync schema than this package.
class SyncSchemaTooNew implements Exception {
  const SyncSchemaTooNew({required this.found, required this.supported});

  final int found;
  final int supported;

  @override
  String toString() =>
      'SyncSchemaTooNew: database has schema v$found, this package supports '
      'v$supported. Upgrade universal_sync instead of downgrading it.';
}

/// Thrown when a package-owned table is missing expected columns.
class SyncSchemaMismatch implements Exception {
  const SyncSchemaMismatch({
    required this.table,
    required this.missing,
    required this.actual,
  });

  final String table;
  final Set<String> missing;
  final Set<String> actual;

  @override
  String toString() =>
      'SyncSchemaMismatch: table "$table" is missing columns $missing '
      '(found: $actual). Did another migration overwrite the sync schema?';
}

/// Table infos for the sync schema, bound to the caller's database.
final class SyncSchema {
  SyncSchema._({
    required this.db,
    required this.meta,
    required this.outbox,
    required this.cursors,
    required this.tombstones,
    required this.conflicts,
    required this.deadLetters,
  });

  final GeneratedDatabase db;
  final MetaTable meta;
  final OutboxTable outbox;
  final CursorsTable cursors;
  final TombstonesTable tombstones;
  final ConflictsTable conflicts;
  final DeadLettersTable deadLetters;

  /// Installs or upgrades the sync schema and binds its table infos to [db].
  static Future<SyncSchema> install(
    GeneratedDatabase db, {
    bool validate = true,
  }) async {
    await db.transaction(() async {
      for (final statement in kSyncSchemaSql) {
        await db.customStatement(statement);
      }

      final versionRows = await db
          .customSelect(
            "SELECT value FROM us_meta WHERE key = 'schema_version'",
          )
          .get();
      if (versionRows.isNotEmpty) {
        final found = int.tryParse(versionRows.first.read<String>('value'));
        if (found != null && found > kSyncSchemaVersion) {
          throw SyncSchemaTooNew(found: found, supported: kSyncSchemaVersion);
        }
      }

      await db.customStatement(
        "INSERT OR IGNORE INTO us_meta (key, value) VALUES ('schema_version', ?)",
        ['$kSyncSchemaVersion'],
      );
      await db.customStatement(
        "INSERT OR IGNORE INTO us_meta (key, value) VALUES ('install_id', ?)",
        [_newInstallId()],
      );
    });

    final schema = SyncSchema._(
      db: db,
      meta: MetaTable(db),
      outbox: OutboxTable(db),
      cursors: CursorsTable(db),
      tombstones: TombstonesTable(db),
      conflicts: ConflictsTable(db),
      deadLetters: DeadLettersTable(db),
    );
    if (validate) {
      await schema.validate();
    }
    return schema;
  }

  /// Verifies that the physical tables match the generated table infos.
  Future<void> validate() async {
    final tables = <TableInfo>[
      meta,
      outbox,
      cursors,
      tombstones,
      conflicts,
      deadLetters,
    ];
    for (final table in tables) {
      final expected = table.$columns.map((c) => c.name).toSet();
      final actual = await _columnsOf(table.actualTableName);
      final missing = expected.difference(actual);
      if (missing.isNotEmpty) {
        throw SyncSchemaMismatch(
          table: table.actualTableName,
          missing: missing,
          actual: actual,
        );
      }
    }
  }

  Future<Set<String>> _columnsOf(String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return rows.map((row) => row.read<String>('name')).toSet();
  }

  /// Reads a `us_meta` value, or `null` when absent.
  Future<String?> metaValue(String key) async {
    final rows = await db
        .customSelect(
          'SELECT value FROM us_meta WHERE key = ?',
          variables: [Variable.withString(key)],
        )
        .get();
    return rows.isEmpty ? null : rows.first.read<String>('value');
  }

  /// Writes a `us_meta` value.
  Future<void> setMetaValue(String key, String value) async {
    await db.customStatement(
      'INSERT OR REPLACE INTO us_meta (key, value) VALUES (?, ?)',
      [key, value],
    );
  }

  static String _newInstallId() {
    final random = Random.secure();
    final entropy = List<int>.generate(8, (_) => random.nextInt(256));
    final hex = entropy.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${DateTime.now().toUtc().microsecondsSinceEpoch.toRadixString(36)}-$hex';
  }
}
