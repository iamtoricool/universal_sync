import 'package:test/test.dart';
import 'package:universal_sync/src/model/sync_queue_entry.dart';

void main() {
  group('SyncQueueEntry', () {
    final now = DateTime(2024);

    test('constructor assigns all fields correctly', () {
      final entry = SyncQueueEntry(
        id: '1',
        idempotencyKey: '1',
        entityType: 'note',
        entityId: 'n1',
        operation: SyncOperation.insert,
        payload: '{"title":"hello"}',
        version: 1,
        localSequence: 10,
        status: SyncEntryStatus.pending,
        createdAt: now,
        syncedAt: now,
      );

      expect(entry.id, '1');
      expect(entry.idempotencyKey, '1');
      expect(entry.entityType, 'note');
      expect(entry.entityId, 'n1');
      expect(entry.operation, SyncOperation.insert);
      expect(entry.payload, '{"title":"hello"}');
      expect(entry.version, 1);
      expect(entry.localSequence, 10);
      expect(entry.status, SyncEntryStatus.pending);
      expect(entry.createdAt, now);
      expect(entry.syncedAt, now);
    });

    test('constructor defaults are applied correctly', () {
      final entry = SyncQueueEntry(
        id: '2',
        idempotencyKey: '2',
        entityType: 'note',
        entityId: 'n2',
        operation: SyncOperation.update,
        payload: '{}',
        version: 0,
        localSequence: 0,
        createdAt: now,
      );

      expect(entry.status, SyncEntryStatus.pending);
      expect(entry.syncedAt, isNull);
    });

    test('copyWith preserves unset fields', () {
      final entry = SyncQueueEntry(
        id: '3',
        idempotencyKey: '3',
        entityType: 'note',
        entityId: 'n3',
        operation: SyncOperation.delete,
        payload: '{"id":"n3"}',
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
      expect(copied.payload, entry.payload);
      expect(copied.version, entry.version);
      expect(copied.localSequence, entry.localSequence);
      expect(copied.status, entry.status);
      expect(copied.createdAt, entry.createdAt);
      expect(copied.syncedAt, entry.syncedAt);
    });

    test('copyWith overrides set fields', () {
      final entry = SyncQueueEntry(
        id: '4',
        idempotencyKey: '4',
        entityType: 'note',
        entityId: 'n4',
        operation: SyncOperation.insert,
        payload: 'old',
        version: 1,
        localSequence: 30,
        createdAt: now,
      );

      final newTime = DateTime(2025);
      final copied = entry.copyWith(
        payload: 'new',
        version: 2,
        syncedAt: newTime,
      );

      expect(copied.payload, 'new');
      expect(copied.version, 2);
      expect(copied.syncedAt, newTime);
      expect(copied.id, entry.id);
      expect(copied.entityType, entry.entityType);
    });

    test('copyWith with explicit null clears nullable fields', () {
      final entry = SyncQueueEntry(
        id: '5',
        idempotencyKey: '5',
        entityType: 'note',
        entityId: 'n5',
        operation: SyncOperation.update,
        payload: '{}',
        version: 3,
        localSequence: 40,
        createdAt: now,
        syncedAt: now,
      );

      final copied = entry.copyWith(
        syncedAt: null,
      );

      expect(copied.syncedAt, isNull);
    });

    test('SyncOperation contains all expected values', () {
      expect(
        SyncOperation.values,
        containsAll([
          SyncOperation.insert,
          SyncOperation.update,
          SyncOperation.delete,
        ]),
      );
    });

    test('SyncEntryStatus contains all expected values', () {
      expect(
        SyncEntryStatus.values,
        containsAll([
          SyncEntryStatus.pending,
          SyncEntryStatus.synced,
          SyncEntryStatus.failed,
        ]),
      );
    });

    test('identical entries have matching fields', () {
      final a = SyncQueueEntry(
        id: 'e1',
        idempotencyKey: 'e1',
        entityType: 't',
        entityId: '1',
        operation: SyncOperation.insert,
        payload: '{}',
        version: 0,
        localSequence: 0,
        createdAt: now,
      );
      final b = SyncQueueEntry(
        id: 'e1',
        idempotencyKey: 'e1',
        entityType: 't',
        entityId: '1',
        operation: SyncOperation.insert,
        payload: '{}',
        version: 0,
        localSequence: 0,
        createdAt: now,
      );
      expect(a.id, b.id);
      expect(a.entityType, b.entityType);
      expect(a.operation, b.operation);
    });

    test('entries with different ids are distinct references', () {
      final a = SyncQueueEntry(
        id: 'e1',
        idempotencyKey: 'e1',
        entityType: 't',
        entityId: '1',
        operation: SyncOperation.insert,
        payload: '{}',
        version: 0,
        localSequence: 0,
        createdAt: now,
      );
      final b = SyncQueueEntry(
        id: 'e2',
        idempotencyKey: 'e2',
        entityType: 't',
        entityId: '1',
        operation: SyncOperation.insert,
        payload: '{}',
        version: 0,
        localSequence: 0,
        createdAt: now,
      );
      expect(identical(a, b), isFalse);
      expect(a.id, isNot(b.id));
    });
  });
}
