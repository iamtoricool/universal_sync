import 'dart:convert';

import 'package:drift/drift.dart';

import 'context.dart';
import 'contract/change.dart';
import 'contract/failures.dart';
import 'entity/sync_entity.dart';
import 'events.dart';
import 'journal/sync_journal.dart';

/// Typed write facade for one synced entity.
///
/// Every write runs in a single Drift transaction that includes the outbox
/// append, so a local write and its pending remote change commit together.
final class SyncTable<Tbl extends Table, Row extends DataClass, Key extends Object> {
  SyncTable(this._context, this.entity);

  final SyncContext _context;
  final SyncEntity<Tbl, Row, Key> entity;

  GeneratedDatabase get _db => _context.db;
  SyncJournal get _journal => _context.journal;

  /// Insert a new row and queue an upsert.
  Future<Row> create(Insertable<Row> companion) async {
    final prepared = _prepare(companion);
    final row = await _db.transaction(() async {
      final inserted = await _db.into(entity.table).insertReturning(prepared);
      await _recordUpsert(inserted);
      return inserted;
    });
    _context.onWrite?.call();
    return row;
  }

  /// Insert or update a row and queue an upsert.
  Future<Row> save(Insertable<Row> companion) async {
    final prepared = _prepare(companion);
    final row = await _db.transaction(() async {
      final inserted = await _db
          .into(entity.table)
          .insertReturning(
            prepared,
            onConflict: DoUpdate<Tbl, Row>((old) => prepared),
          );
      await _recordUpsert(inserted);
      return inserted;
    });
    _context.onWrite?.call();
    return row;
  }

  /// Update the given key with only the columns present in [companion].
  ///
  /// Returns the updated row, or `null` when no local row matched.
  Future<Row?> patch(Key key, Insertable<Row> companion) async {
    final prepared = _prepare(companion);
    final changedColumns = prepared.toColumns(true).keys.toSet();

    final row = await _db.transaction(() async {
      final affected = await (_db.update(
        entity.table,
      )..where((t) => entity.whereKey(t, key))).write(prepared);
      if (affected == 0) return null;

      final local = await (_db.select(
        entity.table,
      )..where((t) => entity.whereKey(t, key))).getSingleOrNull();
      if (local == null) return null;

      final json = entity.encode(local);
      _validate(json);

      final delta = <String, Object?>{
        for (final column in changedColumns)
          if (json.containsKey(column)) column: json[column],
      };

      final parts = entity.keyParts(key);
      final result = await _journal.enqueueUpdate(
        entity.ref.table,
        parts,
        delta,
      );
      _emitEnqueue(result, entity.ref.table, entity.keyJsonOfParts(parts));
      return local;
    });

    if (row != null) _context.onWrite?.call();
    return row;
  }

  /// Delete a row locally, record a tombstone and queue the deletion.
  Future<bool> remove(Key key) async {
    final parts = entity.keyParts(key);
    final deleted = await _db.transaction(() async {
      final affected = await (_db.delete(
        entity.table,
      )..where((t) => entity.whereKey(t, key))).go();
      await _journal.recordLocalTombstone(entity.ref.table, parts);
      final result = await _journal.enqueueDelete(entity.ref.table, parts);
      _emitEnqueue(result, entity.ref.table, entity.keyJsonOfParts(parts));
      return affected > 0;
    });
    _context.onWrite?.call();
    return deleted;
  }

  /// Batched variant of [save]; one outer transaction.
  Future<int> saveAll(Iterable<Insertable<Row>> companions) async {
    final count = await _db.transaction(() async {
      var written = 0;
      for (final companion in companions) {
        final prepared = _prepare(companion);
        final inserted = await _db
            .into(entity.table)
            .insertReturning(
              prepared,
              onConflict: DoUpdate<Tbl, Row>((old) => prepared),
            );
        await _recordUpsert(inserted);
        written++;
      }
      return written;
    });
    _context.onWrite?.call();
    return count;
  }

  /// Batched variant of [remove].
  Future<int> removeMany(Iterable<Key> keys) async {
    final count = await _db.transaction(() async {
      var removed = 0;
      for (final key in keys) {
        final parts = entity.keyParts(key);
        final affected = await (_db.delete(
          entity.table,
        )..where((t) => entity.whereKey(t, key))).go();
        await _journal.recordLocalTombstone(entity.ref.table, parts);
        final result = await _journal.enqueueDelete(entity.ref.table, parts);
        _emitEnqueue(result, entity.ref.table, entity.keyJsonOfParts(parts));
        if (affected > 0) removed++;
      }
      return removed;
    });
    _context.onWrite?.call();
    return count;
  }

  /// Queue a change for a row written through your own DAO.
  ///
  /// Not atomic with that write; prefer [create]/[save]/[patch]/[remove].
  Future<void> markDirty(Key key, {required SyncChangeKind kind}) async {
    final parts = entity.keyParts(key);
    await _db.transaction(() async {
      if (kind == SyncChangeKind.delete) {
        await _journal.recordLocalTombstone(entity.ref.table, parts);
        final result = await _journal.enqueueDelete(entity.ref.table, parts);
        _emitEnqueue(result, entity.ref.table, entity.keyJsonOfParts(parts));
        return;
      }

      final local = await (_db.select(
        entity.table,
      )..where((t) => entity.whereKey(t, key))).getSingleOrNull();
      assert(
        local != null,
        'markDirty(${entity.ref.table}, $key) called for a row that does not '
        'exist. Write the row first, or use SyncChangeKind.delete.',
      );
      if (local == null) return;

      final json = entity.encode(local);
      _validate(json);
      final result = kind == SyncChangeKind.upsert
          ? await _journal.enqueueUpsert(entity.ref.table, parts, json)
          : await _journal.enqueueUpdate(entity.ref.table, parts, json);
      _emitEnqueue(result, entity.ref.table, entity.keyJsonOfParts(parts));
    });
    _context.onWrite?.call();
  }

  /// Read one row by key.
  Future<Row?> find(Key key) => (_db.select(
    entity.table,
  )..where((t) => entity.whereKey(t, key))).getSingleOrNull();

  /// Watch all rows of this entity.
  Stream<List<Row>> watch() => _db.select(entity.table).watch();

  /// Escape hatch to plain Drift querying.
  SimpleSelectStatement<Tbl, Row> query() => _db.select(entity.table);

  // ── Internals ─────────────────────────────────────────────────────────────

  Insertable<Row> _prepare(Insertable<Row> companion) {
    var prepared = companion;
    final present = prepared.toColumns(true);
    final now = _context.options.clock.now().toUtc();

    final stampUpdatedAt = entity.stampUpdatedAt;
    final updatedAtColumn = entity.updatedAtColumn;
    if (_context.options.stampUpdatedAt &&
        stampUpdatedAt != null &&
        updatedAtColumn != null &&
        !present.containsKey(updatedAtColumn)) {
      prepared = stampUpdatedAt(prepared, now);
    }

    final owner = _context.session.userId;
    final stampOwner = entity.stampOwner;
    final ownerColumn = entity.ownerColumn;
    if (owner != null && stampOwner != null && ownerColumn != null && !present.containsKey(ownerColumn)) {
      prepared = stampOwner(prepared, owner);
    }
    return prepared;
  }

  Future<void> _recordUpsert(Row row) async {
    final json = entity.encode(row);
    _validate(json);
    final parts = entity.keyParts(entity.keyOf(row));
    final result = await _journal.enqueueUpsert(entity.ref.table, parts, json);
    _emitEnqueue(result, entity.ref.table, entity.keyJsonOfParts(parts));
  }

  void _validate(Map<String, Object?> json) {
    final bytes = utf8.encode(jsonEncode(json)).length;
    if (bytes > _context.options.maxPayloadBytes) {
      throw PayloadTooLargeException(
        bytes: bytes,
        limit: _context.options.maxPayloadBytes,
      );
    }

    final ownerColumn = entity.ownerColumn;
    final user = _context.session.userId;
    if (ownerColumn != null && user != null) {
      final owner = json[ownerColumn];
      if (owner != null && owner.toString() != user) {
        throw OwnershipViolation(table: entity.ref.table, owner: owner);
      }
    }
  }

  void _emitEnqueue(EnqueueResult result, String table, String keyJson) {
    final now = _context.options.clock.now().toUtc();
    if (result.cancelled) {
      _context.emit(ChangeCancelled(at: now, entity: table, keyJson: keyJson));
    } else if (result.coalesced) {
      _context.emit(ChangeCoalesced(at: now, entity: table, keyJson: keyJson));
    }
  }
}
