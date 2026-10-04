import 'package:drift/drift.dart';

part 'sync_tables.g.dart';

/// Internal key/value store for schema version, install id and bootstrap state.
class UsMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Durable outbox of local changes waiting to be pushed.
class UsOutbox extends Table {
  IntColumn get sequence => integer().autoIncrement()();

  /// SQL name of the synced entity (the user's table).
  TextColumn get entity => text()();

  /// Stable digest of [keyJson], used for indexed lookups.
  BlobColumn get keyHash => blob()();

  /// Canonical JSON array of primary-key values.
  TextColumn get keyJson => text()();

  /// `upsert` | `update` | `delete`.
  TextColumn get kind => text()();

  /// Full after-image for `upsert` changes.
  TextColumn get rowJson => text().nullable()();

  /// Changed-column map for `update` changes.
  TextColumn get deltaJson => text().nullable()();

  /// `pending` | `inflight`.
  TextColumn get state => text()();

  /// 1 when the change may have reached the server; such rows are immutable.
  IntColumn get deliveredMaybe => integer().withDefault(const Constant(0))();

  /// Number of claims/sends (observability only).
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Non-transient failures, bounded by `SyncOptions.maxAttempts`.
  IntColumn get failures => integer().withDefault(const Constant(0))();

  IntColumn get nextAttemptAt => integer()();
  IntColumn get leaseUntil => integer().nullable()();
  TextColumn get leasedBy => text().nullable()();
  TextColumn get lastFailureJson => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}

/// Per-entity pull cursor.
class UsCursors extends Table {
  TextColumn get entity => text()();
  TextColumn get cursorJson => text().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {entity};
}

/// Local deletions that must be suppressed on pull until cursors pass them.
class UsTombstones extends Table {
  TextColumn get entity => text()();
  BlobColumn get keyHash => blob()();
  TextColumn get keyJson => text()();

  /// `local` | `remote`.
  TextColumn get source => text()();
  IntColumn get deletedAt => integer()();
  IntColumn get ackedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {entity, keyHash};
}

/// Remote rows that lost to a manual conflict policy and await resolution.
class UsConflicts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entity => text()();
  BlobColumn get keyHash => blob()();
  TextColumn get keyJson => text()();
  TextColumn get localJson => text().nullable()();
  TextColumn get remoteJson => text()();
  TextColumn get localStatus => text()();
  IntColumn get detectedAt => integer()();
  IntColumn get resolvedAt => integer().nullable()();
}

/// Changes that exhausted their failure budget. Never deleted automatically.
class UsDeadLetters extends Table {
  IntColumn get sequence => integer()();
  TextColumn get entity => text()();
  BlobColumn get keyHash => blob()();
  TextColumn get keyJson => text()();
  TextColumn get kind => text()();
  TextColumn get payloadJson => text().nullable()();
  TextColumn get failureJson => text()();
  IntColumn get failedAt => integer()();

  @override
  Set<Column> get primaryKey => {sequence};
}

/// Package-private database used only to make drift generate the table info
/// for the sync schema. Consumers never open this database.
@DriftDatabase(
  tables: [
    UsMeta,
    UsOutbox,
    UsCursors,
    UsTombstones,
    UsConflicts,
    UsDeadLetters,
  ],
)
class SyncServiceDatabase extends _$SyncServiceDatabase {
  SyncServiceDatabase(super.e);

  @override
  int get schemaVersion => 1;
}

/// Table infos bound to the consumer's database at runtime.
final class MetaTable extends $UsMetaTable {
  MetaTable(super.attachedDatabase);
}

final class OutboxTable extends $UsOutboxTable {
  OutboxTable(super.attachedDatabase);
}

final class CursorsTable extends $UsCursorsTable {
  CursorsTable(super.attachedDatabase);
}

final class TombstonesTable extends $UsTombstonesTable {
  TombstonesTable(super.attachedDatabase);
}

final class ConflictsTable extends $UsConflictsTable {
  ConflictsTable(super.attachedDatabase);
}

final class DeadLettersTable extends $UsDeadLettersTable {
  DeadLettersTable(super.attachedDatabase);
}
