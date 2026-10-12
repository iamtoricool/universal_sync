import 'dart:convert';

import 'package:drift/drift.dart';

import '../contract/change.dart';
import '../contract/failures.dart';
import '../contract/pull.dart';
import '../contract/session.dart';
import '../schema/schema.dart';
import '../schema/sync_tables.dart';
import '../entity/key_codec.dart';
import '../options.dart';

/// Snapshot of one outbox row.
final class OutboxEntry {
  const OutboxEntry({
    required this.sequence,
    required this.entity,
    required this.keyHash,
    required this.keyJson,
    required this.kind,
    required this.row,
    required this.delta,
    required this.state,
    required this.deliveredMaybe,
    required this.attempts,
    required this.failures,
    required this.nextAttemptAt,
    required this.leaseUntil,
    required this.lastFailure,
    required this.createdAt,
    required this.updatedAt,
  });

  final int sequence;
  final String entity;
  final Uint8List keyHash;
  final String keyJson;
  final SyncChangeKind kind;
  final Map<String, Object?>? row;
  final Map<String, Object?>? delta;
  final String state;
  final bool deliveredMaybe;
  final int attempts;
  final int failures;
  final DateTime nextAttemptAt;
  final DateTime? leaseUntil;
  final SyncFailure? lastFailure;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get payloadJson => jsonEncode(row ?? delta ?? const <String, Object?>{});

  SyncChange toChange(String installId, SyncEntityRef ref) {
    final parts = (jsonDecode(keyJson) as List).cast<Object?>();
    return SyncChange(
      sequence: sequence,
      kind: kind,
      idempotencyKey: '$installId:$sequence',
      key: {
        for (var i = 0; i < ref.primaryKey.length && i < parts.length; i++) ref.primaryKey[i]: parts[i],
      },
      row: row ?? const {},
      delta: delta,
    );
  }
}

/// Outcome of an enqueue call.
final class EnqueueResult {
  const EnqueueResult({
    this.sequence,
    this.coalesced = false,
    this.cancelled = false,
  });

  final int? sequence;
  final bool coalesced;
  final bool cancelled;
}

/// A stored manual conflict.
final class ConflictRecord {
  const ConflictRecord({
    required this.id,
    required this.entity,
    required this.keyJson,
    required this.local,
    required this.remote,
    required this.detectedAt,
  });

  final int id;
  final String entity;
  final String keyJson;
  final Map<String, Object?>? local;
  final Map<String, Object?> remote;
  final DateTime detectedAt;
}

/// Durable outbox, cursor, tombstone, conflict and dead-letter storage.
///
/// All mutating methods are expected to be called inside a caller-owned
/// transaction; the engine composes them with the user's write.
final class SyncJournal {
  SyncJournal({
    required this.db,
    required this.schema,
    required this.options,
    required this.clock,
  });

  final GeneratedDatabase db;
  final SyncSchema schema;
  final SyncOptions options;
  final SyncClock clock;

  int _claimCounter = 0;

  DateTime get _now => clock.now().toUtc();
  int get _nowMs => _now.millisecondsSinceEpoch;

  static const _outbox = 'us_outbox';

  // ── Enqueue ───────────────────────────────────────────────────────────────

  Future<EnqueueResult> enqueueUpsert(
    String entity,
    List<Object?> keyParts,
    Map<String, Object?> row,
  ) => _enqueue(
    entity: entity,
    keyParts: keyParts,
    kind: SyncChangeKind.upsert,
    row: row,
  );

  Future<EnqueueResult> enqueueUpdate(
    String entity,
    List<Object?> keyParts,
    Map<String, Object?> delta,
  ) => _enqueue(
    entity: entity,
    keyParts: keyParts,
    kind: SyncChangeKind.update,
    delta: delta,
  );

  Future<EnqueueResult> enqueueDelete(String entity, List<Object?> keyParts) =>
      _enqueue(entity: entity, keyParts: keyParts, kind: SyncChangeKind.delete);

  Future<EnqueueResult> _enqueue({
    required String entity,
    required List<Object?> keyParts,
    required SyncChangeKind kind,
    Map<String, Object?>? row,
    Map<String, Object?>? delta,
  }) async {
    final keyJson = encodeKeyJson(keyParts);
    final hash = keyHashOf(keyJson);
    final nowMs = _nowMs;

    final existing = await _findCoalescible(entity, hash);

    if (existing == null) {
      final sequence = await db
          .into(schema.outbox)
          .insert(
            UsOutboxCompanion.insert(
              entity: entity,
              keyHash: hash,
              keyJson: keyJson,
              kind: kind.name,
              state: 'pending',
              nextAttemptAt: nowMs,
              createdAt: nowMs,
              updatedAt: nowMs,
              rowJson: Value(row == null ? null : jsonEncode(row)),
              deltaJson: Value(delta == null ? null : jsonEncode(delta)),
            ),
          );
      return EnqueueResult(sequence: sequence);
    }

    var newKind = kind;
    Map<String, Object?>? newRow = row;
    Map<String, Object?>? newDelta = delta;

    switch (existing.kind) {
      case SyncChangeKind.upsert:
        switch (kind) {
          case SyncChangeKind.update:
            newKind = SyncChangeKind.upsert;
            newRow = {...?existing.row, ...?delta};
            newDelta = null;
          case SyncChangeKind.upsert:
            newKind = SyncChangeKind.upsert;
            newDelta = null;
          case SyncChangeKind.delete:
            if (options.cancelUnsyncedCreateThenDelete) {
              await _deleteOutboxRow(existing.sequence);
              await clearTombstone(entity, keyParts);
              return EnqueueResult(
                sequence: existing.sequence,
                coalesced: true,
                cancelled: true,
              );
            }
            newKind = SyncChangeKind.delete;
            newRow = null;
            newDelta = null;
        }
      case SyncChangeKind.update:
        switch (kind) {
          case SyncChangeKind.update:
            newKind = SyncChangeKind.update;
            newRow = null;
            newDelta = {...?existing.delta, ...?delta};
          case SyncChangeKind.upsert:
            newKind = SyncChangeKind.upsert;
            newDelta = null;
          case SyncChangeKind.delete:
            newKind = SyncChangeKind.delete;
            newRow = null;
            newDelta = null;
        }
      case SyncChangeKind.delete:
        switch (kind) {
          case SyncChangeKind.upsert:
            newKind = SyncChangeKind.upsert;
            newDelta = null;
            await clearTombstone(entity, keyParts);
          case SyncChangeKind.update:
            // A patch for a deleted row is not a valid state; deletes win.
            newKind = SyncChangeKind.delete;
            newRow = null;
            newDelta = null;
          case SyncChangeKind.delete:
            newKind = SyncChangeKind.delete;
            newRow = null;
            newDelta = null;
        }
    }

    await (db.update(
      schema.outbox,
    )..where((t) => t.sequence.equals(existing.sequence))).write(
      UsOutboxCompanion(
        kind: Value(newKind.name),
        rowJson: Value(newRow == null ? null : jsonEncode(newRow)),
        deltaJson: Value(newDelta == null ? null : jsonEncode(newDelta)),
        updatedAt: Value(nowMs),
      ),
    );

    return EnqueueResult(sequence: existing.sequence, coalesced: true);
  }

  Future<OutboxEntry?> _findCoalescible(String entity, Uint8List hash) async {
    final row =
        await (db.select(schema.outbox)
              ..where(
                (t) =>
                    t.entity.equals(entity) &
                    t.keyHash.equals(hash) &
                    t.state.equals('pending') &
                    t.deliveredMaybe.equals(0),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.sequence)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toEntry(row);
  }

  /// All pending/inflight entries for a key, newest first.
  Future<List<OutboxEntry>> entriesForKey(
    String entity,
    List<Object?> keyParts,
  ) async {
    final keyJson = encodeKeyJson(keyParts);
    final hash = keyHashOf(keyJson);
    final rows =
        await (db.select(schema.outbox)
              ..where(
                (t) => t.entity.equals(entity) & t.keyHash.equals(hash) & t.state.isIn(const ['pending', 'inflight']),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.sequence)]))
            .get();
    return [for (final row in rows) _toEntry(row)];
  }

  /// First (oldest) pending entry for a key, if any.
  Future<OutboxEntry?> nextPendingForKey(
    String entity,
    Uint8List hash, {
    int? newerThan,
  }) async {
    final query = db.select(schema.outbox)
      ..where(
        (t) => t.entity.equals(entity) & t.keyHash.equals(hash) & t.state.equals('pending'),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.sequence)])
      ..limit(1);
    if (newerThan != null) {
      query.where((t) => t.sequence.isBiggerThanValue(newerThan));
    }
    final row = await query.getSingleOrNull();
    return row == null ? null : _toEntry(row);
  }

  // ── Claim / retry / ack ───────────────────────────────────────────────────

  /// Atomically claims claimable rows with the per-key head-of-line rule.
  Future<List<OutboxEntry>> claim({
    required int limit,
    required String instanceId,
    required Duration lease,
  }) async {
    final nowMs = _nowMs;
    final token = '$instanceId:${_claimCounter++}:$nowMs';

    await db.transaction(() async {
      await db.customStatement(
        '''
        UPDATE $_outbox
        SET state = 'inflight',
            delivered_maybe = 1,
            attempts = attempts + 1,
            lease_until = ?,
            leased_by = ?,
            updated_at = ?
        WHERE sequence IN (
          SELECT o.sequence FROM $_outbox o
          WHERE o.state = 'pending'
            AND o.next_attempt_at <= ?
            AND NOT EXISTS (
              SELECT 1 FROM $_outbox p
              WHERE p.entity = o.entity
                AND p.key_hash = o.key_hash
                AND p.sequence < o.sequence
                AND p.state IN ('pending', 'inflight')
            )
          ORDER BY o.sequence
          LIMIT ?
        )''',
        [nowMs + lease.inMilliseconds, token, nowMs, nowMs, limit],
      );
    });

    final rows =
        await (db.select(schema.outbox)
              ..where(
                (t) => t.leasedBy.equals(token) & t.state.equals('inflight'),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.sequence)]))
            .get();
    return [for (final row in rows) _toEntry(row)];
  }

  /// A not-sent failure: the change may stay coalescible. Returns the newer
  /// pending entry that supersedes this one, if any.
  Future<OutboxEntry?> releaseNotSent(
    OutboxEntry entry,
    SyncFailure failure,
    DateTime nextAttemptAt,
  ) async {
    final newer = await nextPendingForKey(
      entry.entity,
      entry.keyHash,
      newerThan: entry.sequence,
    );
    if (newer != null) {
      await _deleteOutboxRow(entry.sequence);
      return newer;
    }
    await _release(
      entry,
      failure,
      nextAttemptAt,
      deliveredMaybe: false,
      countFailure: false,
    );
    return null;
  }

  /// A maybe-applied failure: the row is immutable and must replay as-is.
  Future<void> releaseMaybeApplied(
    OutboxEntry entry,
    SyncFailure failure,
    DateTime nextAttemptAt, {
    required bool countFailure,
  }) async {
    await _release(
      entry,
      failure,
      nextAttemptAt,
      deliveredMaybe: true,
      countFailure: countFailure,
    );
  }

  Future<void> _release(
    OutboxEntry entry,
    SyncFailure failure,
    DateTime nextAttemptAt, {
    required bool deliveredMaybe,
    required bool countFailure,
  }) async {
    await (db.update(
      schema.outbox,
    )..where((t) => t.sequence.equals(entry.sequence))).write(
      UsOutboxCompanion(
        state: const Value('pending'),
        deliveredMaybe: Value(deliveredMaybe ? 1 : 0),
        leaseUntil: const Value(null),
        leasedBy: const Value(null),
        failures: Value(entry.failures + (countFailure ? 1 : 0)),
        nextAttemptAt: Value(nextAttemptAt.millisecondsSinceEpoch),
        lastFailureJson: Value(jsonEncode(failure.toJson())),
        updatedAt: Value(_nowMs),
      ),
    );
  }

  /// Removes an acknowledged row and supersedes older pending rows for the key.
  Future<void> ack(OutboxEntry entry) async {
    await _deleteOutboxRow(entry.sequence);
    if (entry.kind != SyncChangeKind.update) {
      await (db.delete(schema.outbox)..where(
            (t) =>
                t.entity.equals(entry.entity) &
                t.keyHash.equals(entry.keyHash) &
                t.sequence.isSmallerThanValue(entry.sequence) &
                t.state.equals('pending'),
          ))
          .go();
    }
    if (entry.kind == SyncChangeKind.delete) {
      await markTombstoneAcked(entry.entity, entry.keyJson);
    }
  }

  Future<void> _deleteOutboxRow(int sequence) async {
    await (db.delete(
      schema.outbox,
    )..where((t) => t.sequence.equals(sequence))).go();
  }

  /// Moves a change to the dead-letter table. Never deletes user data silently.
  Future<void> park(OutboxEntry entry, SyncFailure failure) async {
    await db
        .into(schema.deadLetters)
        .insert(
          UsDeadLettersCompanion.insert(
            sequence: Value(entry.sequence),
            entity: entry.entity,
            keyHash: entry.keyHash,
            keyJson: entry.keyJson,
            kind: entry.kind.name,
            failureJson: jsonEncode(failure.toJson()),
            failedAt: _nowMs,
            payloadJson: Value(
              entry.kind == SyncChangeKind.update
                  ? jsonEncode(entry.delta ?? const {})
                  : jsonEncode(entry.row ?? const {}),
            ),
          ),
        );
    await _deleteOutboxRow(entry.sequence);
  }

  /// Rewrites a pending delta as a full upsert (used when its base is gone).
  Future<void> promoteToUpsert(int sequence, Map<String, Object?> row) async {
    await (db.update(
      schema.outbox,
    )..where((t) => t.sequence.equals(sequence))).write(
      UsOutboxCompanion(
        kind: const Value('upsert'),
        rowJson: Value(jsonEncode(row)),
        deltaJson: const Value(null),
        updatedAt: Value(_nowMs),
      ),
    );
  }

  Future<void> deleteOutboxForKey(String entity, List<Object?> keyParts) async {
    final hash = keyHashOf(encodeKeyJson(keyParts));
    await (db.delete(
      schema.outbox,
    )..where((t) => t.entity.equals(entity) & t.keyHash.equals(hash))).go();
  }

  /// Reclaims leases left behind by a killed process.
  Future<int> recoverLeases() async {
    final nowMs = _nowMs;
    return (db.update(schema.outbox)..where(
          (t) => t.state.equals('inflight') & (t.leaseUntil.isNull() | t.leaseUntil.isSmallerThanValue(nowMs)),
        ))
        .write(
          const UsOutboxCompanion(
            state: Value('pending'),
            deliveredMaybe: Value(1),
            leaseUntil: Value(null),
            leasedBy: Value(null),
          ),
        );
  }

  // ── Tombstones ────────────────────────────────────────────────────────────

  Future<void> recordLocalTombstone(
    String entity,
    List<Object?> keyParts,
  ) async {
    final keyJson = encodeKeyJson(keyParts);
    await db
        .into(schema.tombstones)
        .insert(
          UsTombstonesCompanion.insert(
            entity: entity,
            keyHash: keyHashOf(keyJson),
            keyJson: keyJson,
            source: 'local',
            deletedAt: _nowMs,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> recordRemoteTombstone(
    String entity,
    List<Object?> keyParts,
  ) async {
    final keyJson = encodeKeyJson(keyParts);
    await db
        .into(schema.tombstones)
        .insert(
          UsTombstonesCompanion.insert(
            entity: entity,
            keyHash: keyHashOf(keyJson),
            keyJson: keyJson,
            source: 'remote',
            deletedAt: _nowMs,
            ackedAt: Value(_nowMs),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> markTombstoneAcked(String entity, String keyJson) async {
    await (db.update(schema.tombstones)..where((t) => t.entity.equals(entity) & t.keyJson.equals(keyJson))).write(
      UsTombstonesCompanion(ackedAt: Value(_nowMs)),
    );
  }

  Future<void> clearTombstone(String entity, List<Object?> keyParts) async {
    final keyJson = encodeKeyJson(keyParts);
    final hash = keyHashOf(keyJson);
    await (db.delete(
      schema.tombstones,
    )..where((t) => t.entity.equals(entity) & t.keyHash.equals(hash))).go();
  }

  /// Tombstone key JSONs present for the given keys.
  Future<Set<String>> tombstoneKeys(
    String entity,
    Iterable<String> keyJsons,
  ) async {
    final keys = keyJsons.toList();
    if (keys.isEmpty) return const {};
    final rows = await (db.select(
      schema.tombstones,
    )..where((t) => t.entity.equals(entity) & t.keyJson.isIn(keys))).get();
    return {for (final row in rows) row.keyJson};
  }

  Future<void> purgeTombstones() async {
    final cutoff = _nowMs - options.tombstoneRetention.inMilliseconds;
    await (db.delete(schema.tombstones)..where(
          (t) => t.ackedAt.isNotNull() & t.deletedAt.isSmallerThanValue(cutoff),
        ))
        .go();
  }

  // ── Cursors ───────────────────────────────────────────────────────────────

  Future<SyncCursor?> cursorFor(String entity) async {
    final row = await (db.select(
      schema.cursors,
    )..where((t) => t.entity.equals(entity))).getSingleOrNull();
    return SyncCursor.decode(row?.cursorJson);
  }

  Future<void> setCursor(String entity, SyncCursor? cursor) async {
    await db
        .into(schema.cursors)
        .insert(
          UsCursorsCompanion.insert(
            entity: entity,
            cursorJson: Value(cursor?.encode()),
            updatedAt: _nowMs,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  Future<void> resetCursors() async {
    await db.delete(schema.cursors).go();
  }

  // ── Pending lookup ────────────────────────────────────────────────────────

  /// Key JSONs with a pending or inflight change.
  Future<Set<String>> pendingKeys(
    String entity,
    Iterable<String> keyJsons,
  ) async {
    final keys = keyJsons.toList();
    if (keys.isEmpty) return const {};
    final rows =
        await (db.select(schema.outbox)..where(
              (t) => t.entity.equals(entity) & t.keyJson.isIn(keys) & t.state.isIn(const ['pending', 'inflight']),
            ))
            .get();
    return {for (final row in rows) row.keyJson};
  }

  // ── Conflicts ─────────────────────────────────────────────────────────────

  Future<void> openConflict({
    required String entity,
    required List<Object?> keyParts,
    required Map<String, Object?>? local,
    required Map<String, Object?> remote,
    required String localStatus,
  }) async {
    final keyJson = encodeKeyJson(keyParts);
    final hash = keyHashOf(keyJson);
    final existing =
        await (db.select(schema.conflicts)..where(
              (t) => t.entity.equals(entity) & t.keyHash.equals(hash) & t.resolvedAt.isNull(),
            ))
            .getSingleOrNull();
    if (existing != null) {
      await (db.update(
        schema.conflicts,
      )..where((t) => t.id.equals(existing.id))).write(
        UsConflictsCompanion(
          localJson: Value(local == null ? null : jsonEncode(local)),
          remoteJson: Value(jsonEncode(remote)),
          localStatus: Value(localStatus),
          detectedAt: Value(_nowMs),
        ),
      );
      return;
    }
    await db
        .into(schema.conflicts)
        .insert(
          UsConflictsCompanion.insert(
            entity: entity,
            keyHash: hash,
            keyJson: keyJson,
            remoteJson: jsonEncode(remote),
            localStatus: localStatus,
            detectedAt: _nowMs,
            localJson: Value(local == null ? null : jsonEncode(local)),
          ),
        );
  }

  Future<List<ConflictRecord>> listConflicts() async {
    final rows =
        await (db.select(schema.conflicts)
              ..where((t) => t.resolvedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get();
    return [
      for (final row in rows)
        ConflictRecord(
          id: row.id,
          entity: row.entity,
          keyJson: row.keyJson,
          local: row.localJson == null ? null : (jsonDecode(row.localJson!) as Map).cast<String, Object?>(),
          remote: (jsonDecode(row.remoteJson) as Map).cast<String, Object?>(),
          detectedAt: DateTime.fromMillisecondsSinceEpoch(
            row.detectedAt,
            isUtc: true,
          ),
        ),
    ];
  }

  Future<ConflictRecord?> conflictById(int id) async {
    final row = await (db.select(
      schema.conflicts,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return ConflictRecord(
      id: row.id,
      entity: row.entity,
      keyJson: row.keyJson,
      local: row.localJson == null ? null : (jsonDecode(row.localJson!) as Map).cast<String, Object?>(),
      remote: (jsonDecode(row.remoteJson) as Map).cast<String, Object?>(),
      detectedAt: DateTime.fromMillisecondsSinceEpoch(
        row.detectedAt,
        isUtc: true,
      ),
    );
  }

  Future<void> resolveConflictRow(int id) async {
    await (db.update(schema.conflicts)..where((t) => t.id.equals(id))).write(
      UsConflictsCompanion(resolvedAt: Value(_nowMs)),
    );
  }

  // ── Maintenance / diagnostics ─────────────────────────────────────────────

  Future<int> countOutbox(String state) async {
    final rows = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM $_outbox WHERE state = ?',
          variables: [Variable.withString(state)],
        )
        .get();
    return rows.first.read<int>('c');
  }

  Future<int> countTombstones() async => _countTable(schema.tombstones.actualTableName);

  Future<int> countDeadLetters() async => _countTable(schema.deadLetters.actualTableName);

  Future<int> countConflicts() async {
    final rows = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM ${schema.conflicts.actualTableName} '
          'WHERE resolved_at IS NULL',
        )
        .get();
    return rows.first.read<int>('c');
  }

  Future<int> outboxBytes() async {
    final rows = await db
        .customSelect(
          'SELECT COALESCE(SUM(LENGTH(row_json) + LENGTH(delta_json)), 0) AS b '
          'FROM $_outbox',
        )
        .get();
    return rows.first.read<int>('b');
  }

  Future<int> _countTable(String table) async {
    final rows = await db.customSelect('SELECT COUNT(*) AS c FROM $table').get();
    return rows.first.read<int>('c');
  }

  Future<int> retryParked() async {
    final nowMs = _nowMs;
    return db.transaction(() async {
      final letters = await db.select(schema.deadLetters).get();
      for (final letter in letters) {
        final isDelta = letter.kind == SyncChangeKind.update.name;
        await db
            .into(schema.outbox)
            .insert(
              UsOutboxCompanion.insert(
                entity: letter.entity,
                keyHash: letter.keyHash,
                keyJson: letter.keyJson,
                kind: letter.kind,
                state: 'pending',
                nextAttemptAt: nowMs,
                createdAt: nowMs,
                updatedAt: nowMs,
                rowJson: Value(isDelta ? null : letter.payloadJson),
                deltaJson: Value(isDelta ? letter.payloadJson : null),
              ),
            );
      }
      await db.delete(schema.deadLetters).go();
      return letters.length;
    });
  }

  Future<int> discardParked() async {
    final letters = await db.select(schema.deadLetters).get();
    await db.delete(schema.deadLetters).go();
    return letters.length;
  }

  /// Wipes all sync state. Keeps install id and schema version.
  Future<void> purgeAll() async {
    await db.transaction(() async {
      await db.delete(schema.outbox).go();
      await db.delete(schema.cursors).go();
      await db.delete(schema.tombstones).go();
      await db.delete(schema.conflicts).go();
      await db.delete(schema.deadLetters).go();
    });
  }

  // ── Mapping ───────────────────────────────────────────────────────────────

  OutboxEntry _toEntry(UsOutboxData row) => OutboxEntry(
    sequence: row.sequence,
    entity: row.entity,
    keyHash: row.keyHash,
    keyJson: row.keyJson,
    kind: SyncChangeKind.values.byName(row.kind),
    row: row.rowJson == null ? null : (jsonDecode(row.rowJson!) as Map).cast<String, Object?>(),
    delta: row.deltaJson == null ? null : (jsonDecode(row.deltaJson!) as Map).cast<String, Object?>(),
    state: row.state,
    deliveredMaybe: row.deliveredMaybe != 0,
    attempts: row.attempts,
    failures: row.failures,
    nextAttemptAt: DateTime.fromMillisecondsSinceEpoch(
      row.nextAttemptAt,
      isUtc: true,
    ),
    leaseUntil: row.leaseUntil == null ? null : DateTime.fromMillisecondsSinceEpoch(row.leaseUntil!, isUtc: true),
    lastFailure: row.lastFailureJson == null
        ? null
        : SyncFailure.fromJson(
            (jsonDecode(row.lastFailureJson!) as Map).cast<String, Object?>(),
          ),
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
  );
}
