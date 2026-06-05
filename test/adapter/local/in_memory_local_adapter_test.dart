import 'package:test/test.dart';
import 'package:universal_sync/src/adapter/local/in_memory_local_adapter.dart';
import 'package:universal_sync/src/model/sync_queue_entry.dart';
import 'package:universal_sync/src/model/sync_checkpoint.dart';
import 'package:universal_sync/src/model/sync_entity.dart';

class _TestEntity extends SyncEntity {
  @override
  final String id;
  @override
  final int version;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? deletedAt;

  _TestEntity({
    required this.id,
    this.version = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : deletedAt = null,
       createdAt = createdAt ?? DateTime(2024),
       updatedAt = updatedAt ?? DateTime(2024);

  @override
  Map<String, dynamic> toSyncJson() => {'id': id};
}

class _NoteEntity extends SyncEntity {
  @override
  final String id;
  @override
  final int version;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? deletedAt;

  _NoteEntity({
    required this.id,
    // ignore: unused_element_parameter
    this.version = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : deletedAt = null,
       createdAt = createdAt ?? DateTime(2024),
       updatedAt = updatedAt ?? DateTime(2024);

  @override
  Map<String, dynamic> toSyncJson() => {'id': id};
}

SyncQueueEntry<_TestEntity> _entry({
  required String id,
  required String entityId,
  SyncOperation operation = SyncOperation.insert,
  int localSequence = 0,
  SyncEntryStatus status = SyncEntryStatus.pending,
}) {
  return SyncQueueEntry<_TestEntity>(
    id: id,
    idempotencyKey: id,
    data: _TestEntity(id: entityId, version: 1),
    operation: operation,
    version: 1,
    localSequence: localSequence,
    createdAt: DateTime(2024),
    status: status,
  );
}

void main() {
  late InMemoryLocalAdapter adapter;

  setUp(() {
    adapter = InMemoryLocalAdapter();
  });

  group('nextSequence', () {
    test('starts at 0', () async {
      expect(await adapter.nextSequence(), 0);
    });

    test('increments each call', () async {
      expect(await adapter.nextSequence(), 0);
      expect(await adapter.nextSequence(), 1);
      expect(await adapter.nextSequence(), 2);
    });
  });

  group('enqueue and fetchPendingEntries', () {
    test('returns entries in sequence order', () async {
      await adapter.enqueue(_entry(id: 'e1', entityId: 't1', localSequence: 2));
      await adapter.enqueue(_entry(id: 'e2', entityId: 't2', localSequence: 1));

      final entries = await adapter.fetchPendingEntries('_TestEntity', 10);
      expect(entries.length, 2);
      expect(entries[0].id, 'e2');
      expect(entries[1].id, 'e1');
    });

    test('filters by entity type', () async {
      await adapter.enqueue(_entry(id: 'e1', entityId: 't1'));
      await adapter.enqueue(
        SyncQueueEntry<_NoteEntity>(
          id: 'e2',
          idempotencyKey: 'e2',
          data: _NoteEntity(id: 'n1'),
          operation: SyncOperation.insert,
          version: 1,
          localSequence: 0,
          createdAt: DateTime(2024),
        ),
      );

      expect((await adapter.fetchPendingEntries('_TestEntity', 10)).length, 1);
      expect((await adapter.fetchPendingEntries('_NoteEntity', 10)).length, 1);
    });

    test('filters by status (only pending)', () async {
      await adapter.enqueue(_entry(id: 'e1', entityId: 't1', status: SyncEntryStatus.pending));
      await adapter.enqueue(_entry(id: 'e2', entityId: 't2', status: SyncEntryStatus.synced));

      expect((await adapter.fetchPendingEntries('_TestEntity', 10)).length, 1);
    });

    test('respects limit parameter', () async {
      await adapter.enqueue(_entry(id: 'e1', entityId: 't1', localSequence: 1));
      await adapter.enqueue(_entry(id: 'e2', entityId: 't2', localSequence: 2));
      await adapter.enqueue(_entry(id: 'e3', entityId: 't3', localSequence: 3));

      expect((await adapter.fetchPendingEntries('_TestEntity', 2)).length, 2);
    });
  });

  group('updateQueueEntryStatus', () {
    test('updates status', () async {
      await adapter.enqueue(_entry(id: 'e1', entityId: 't1', localSequence: 1));

      await adapter.updateQueueEntryStatus('e1', SyncEntryStatus.failed);

      final pending = await adapter.fetchPendingEntries('_TestEntity', 10);
      expect(pending, isEmpty);

      await adapter.enqueue(_entry(id: 'e2', entityId: 't2', localSequence: 2));
      final entries = await adapter.fetchPendingEntries('_TestEntity', 10);
      expect(entries.length, 1);
      expect(entries[0].id, 'e2');
    });
  });

  group('readCheckpoint / writeCheckpoint', () {
    test('readCheckpoint returns null when no checkpoint exists', () async {
      expect(await adapter.readCheckpoint('_TestEntity'), isNull);
    });

    test('writeCheckpoint stores and readCheckpoint retrieves', () async {
      final cp = SyncCheckpoint(id: 'cp1', entityType: '_TestEntity', lastServerSequence: 42);
      await adapter.writeCheckpoint(cp);
      final retrieved = await adapter.readCheckpoint('_TestEntity');
      expect(retrieved, isNotNull);
      expect(retrieved!.lastServerSequence, 42);
    });

    test('writeCheckpoint overwrites existing', () async {
      final cp1 = SyncCheckpoint(id: 'cp1', entityType: '_TestEntity', lastServerSequence: 10);
      final cp2 = SyncCheckpoint(id: 'cp2', entityType: '_TestEntity', lastServerSequence: 20);
      await adapter.writeCheckpoint(cp1);
      await adapter.writeCheckpoint(cp2);
      final retrieved = await adapter.readCheckpoint('_TestEntity');
      expect(retrieved!.lastServerSequence, 20);
    });
  });

  group('upsertEntity', () {
    test('creates new entity', () async {
      await adapter.upsertEntity('_TestEntity', {'id': 't1', 'title': 'hello'});
    });

    test('overwrites existing with same ID', () async {
      await adapter.upsertEntity('_TestEntity', {'id': 't1', 'title': 'hello'});
      await adapter.upsertEntity('_TestEntity', {'id': 't1', 'title': 'world'});
    });
  });

  group('softDeleteEntity', () {
    test('is no-op when entity does not exist', () async {
      await adapter.softDeleteEntity('_TestEntity', 'nonexistent');
    });

    test('sets deletedAt on existing entity', () async {
      await adapter.upsertEntity('_TestEntity', {'id': 't1', 'title': 'hello'});
      await adapter.softDeleteEntity('_TestEntity', 't1');
    });

    test('softDeleteEntity sets deletedAt', () async {
      await adapter.upsertEntity('_TestEntity', {'id': 'e1'});
      await adapter.softDeleteEntity('_TestEntity', 'e1');
      final stored = adapter.entities['_TestEntity']!['e1']!;
      expect(stored['deletedAt'], isNotNull);
    });
  });

  group('transaction', () {
    test('executes callback and returns result', () async {
      final result = await adapter.transaction(() async => 42);
      expect(result, 42);
    });
  });

  group('reset', () {
    test('clears all state', () async {
      await adapter.enqueue(_entry(id: 'e1', entityId: 't1'));
      await adapter.nextSequence();
      await adapter.writeCheckpoint(
        SyncCheckpoint(id: 'cp1', entityType: '_TestEntity', lastServerSequence: 1),
      );

      adapter.reset();

      expect(await adapter.nextSequence(), 0);
      expect((await adapter.fetchPendingEntries('_TestEntity', 10)).length, 0);
      expect(await adapter.readCheckpoint('_TestEntity'), isNull);
    });
  });
}
