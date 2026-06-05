import 'package:test/test.dart';
import 'package:universal_sync/universal_sync.dart';

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
  Map<String, dynamic> toSyncJson() => {'id': id, 'version': version};
}

void main() {
  group('SyncQueueEntry', () {
    final now = DateTime(2024);
    final testEntity = _TestEntity(id: 'n1', version: 1);

    test('constructor assigns all fields correctly', () {
      final entry = SyncQueueEntry<_TestEntity>(
        id: '1',
        idempotencyKey: '1',
        data: testEntity,
        operation: SyncOperation.insert,
        version: 1,
        localSequence: 10,
        status: SyncEntryStatus.pending,
        createdAt: now,
        syncedAt: now,
      );

      expect(entry.id, '1');
      expect(entry.idempotencyKey, '1');
      expect(entry.entityType, '_TestEntity');
      expect(entry.entityId, 'n1');
      expect(entry.operation, SyncOperation.insert);
      expect(entry.data.id, 'n1');
      expect(entry.version, 1);
      expect(entry.localSequence, 10);
      expect(entry.status, SyncEntryStatus.pending);
      expect(entry.createdAt, now);
      expect(entry.syncedAt, now);
    });

    test('constructor defaults are applied correctly', () {
      final entry = SyncQueueEntry<_TestEntity>(
        id: '2',
        idempotencyKey: '2',
        data: _TestEntity(id: 'n2'),
        operation: SyncOperation.update,
        version: 0,
        localSequence: 0,
        createdAt: now,
      );

      expect(entry.status, SyncEntryStatus.pending);
      expect(entry.syncedAt, isNull);
    });

    test('copyWith preserves unset fields', () {
      final entry = SyncQueueEntry<_TestEntity>(
        id: '3',
        idempotencyKey: '3',
        data: _TestEntity(id: 'n3'),
        operation: SyncOperation.delete,
        version: 2,
        localSequence: 20,
        createdAt: now,
        syncedAt: now,
      );

      final copied = entry.copyWith();
      expect(copied.id, entry.id);
      expect(copied.idempotencyKey, entry.idempotencyKey);
      expect(copied.entityType, entry.entityType);
      expect(copied.entityId, entry.entityId);
      expect(copied.operation, entry.operation);
      expect(copied.data.id, entry.data.id);
      expect(copied.version, entry.version);
      expect(copied.localSequence, entry.localSequence);
      expect(copied.status, entry.status);
      expect(copied.createdAt, entry.createdAt);
      expect(copied.syncedAt, entry.syncedAt);
    });

    test('copyWith overrides set fields', () {
      final entry = SyncQueueEntry<_TestEntity>(
        id: '4',
        idempotencyKey: '4',
        data: _TestEntity(id: 'n4'),
        operation: SyncOperation.insert,
        version: 1,
        localSequence: 30,
        createdAt: now,
      );

      final newEntity = _TestEntity(id: 'n4', version: 2);
      final newTime = DateTime(2025);
      final copied = entry.copyWith(
        data: newEntity,
        version: 2,
        syncedAt: newTime,
      );

      expect(copied.data.version, 2);
      expect(copied.version, 2);
      expect(copied.syncedAt, newTime);
      expect(copied.id, entry.id);
      expect(copied.entityType, entry.entityType);
    });

    test('copyWith with explicit null clears nullable fields', () {
      final entry = SyncQueueEntry<_TestEntity>(
        id: '5',
        idempotencyKey: '5',
        data: _TestEntity(id: 'n5'),
        operation: SyncOperation.update,
        version: 3,
        localSequence: 40,
        createdAt: now,
        syncedAt: now,
      );

      final copied = entry.copyWith(syncedAt: null);
      expect(copied.syncedAt, isNull);
    });

    test('SyncOperation contains all expected values', () {
      expect(
        SyncOperation.values,
        containsAll([SyncOperation.insert, SyncOperation.update, SyncOperation.delete]),
      );
    });

    test('SyncEntryStatus contains all expected values', () {
      expect(
        SyncEntryStatus.values,
        containsAll([SyncEntryStatus.pending, SyncEntryStatus.synced, SyncEntryStatus.failed]),
      );
    });

    test('identical entries have matching fields', () {
      final a = SyncQueueEntry<_TestEntity>(
        id: 'e1',
        idempotencyKey: 'e1',
        data: _TestEntity(id: '1'),
        operation: SyncOperation.insert,
        version: 0,
        localSequence: 0,
        createdAt: now,
      );
      final b = SyncQueueEntry<_TestEntity>(
        id: 'e1',
        idempotencyKey: 'e1',
        data: _TestEntity(id: '1'),
        operation: SyncOperation.insert,
        version: 0,
        localSequence: 0,
        createdAt: now,
      );
      expect(a.id, b.id);
      expect(a.entityType, b.entityType);
      expect(a.operation, b.operation);
    });

    test('entries with different ids are distinct references', () {
      final a = SyncQueueEntry<_TestEntity>(
        id: 'e1',
        idempotencyKey: 'e1',
        data: _TestEntity(id: '1'),
        operation: SyncOperation.insert,
        version: 0,
        localSequence: 0,
        createdAt: now,
      );
      final b = SyncQueueEntry<_TestEntity>(
        id: 'e2',
        idempotencyKey: 'e2',
        data: _TestEntity(id: '1'),
        operation: SyncOperation.insert,
        version: 0,
        localSequence: 0,
        createdAt: now,
      );
      expect(identical(a, b), isFalse);
      expect(a.id, isNot(b.id));
    });
  });
}
