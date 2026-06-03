import 'package:test/test.dart';
import 'package:universal_sync/src/model/sync_checkpoint.dart';

void main() {
  group('SyncCheckpoint', () {
    test('constructor assigns fields', () {
      final cp = SyncCheckpoint(
        id: '1',
        entityType: 'note',
        lastServerSequence: 42,
        lastSyncedAt: DateTime(2024),
      );

      expect(cp.id, '1');
      expect(cp.entityType, 'note');
      expect(cp.lastServerSequence, 42);
      expect(cp.lastSyncedAt, DateTime(2024));
    });

    test('copyWith works correctly', () {
      final cp = SyncCheckpoint(
        id: '2',
        entityType: 'note',
        lastServerSequence: 10,
        lastSyncedAt: DateTime(2024),
      );

      final copied = cp.copyWith(lastServerSequence: 20);

      expect(copied.lastServerSequence, 20);
      expect(copied.id, cp.id);
      expect(copied.entityType, cp.entityType);
      expect(copied.lastSyncedAt, cp.lastSyncedAt);
    });

    test('copyWith clears lastSyncedAt with null', () {
      final cp = SyncCheckpoint(
        id: '3',
        entityType: 'note',
        lastServerSequence: 15,
        lastSyncedAt: DateTime(2024),
      );

      final copied = cp.copyWith(lastSyncedAt: null);
      expect(copied.lastSyncedAt, isNull);
    });

    test('copyWith with no args returns identical copy', () {
      final cp = SyncCheckpoint(
        id: '4',
        entityType: 'note',
        lastServerSequence: 10,
        lastSyncedAt: DateTime(2024),
      );

      final copied = cp.copyWith();
      expect(copied.id, cp.id);
      expect(copied.entityType, cp.entityType);
      expect(copied.lastServerSequence, cp.lastServerSequence);
      expect(copied.lastSyncedAt, cp.lastSyncedAt);
    });

    test('copyWith does not mutate the original', () {
      final cp = SyncCheckpoint(
        id: '5',
        entityType: 'note',
        lastServerSequence: 0,
      );

      cp.copyWith(lastServerSequence: 99, lastSyncedAt: DateTime.now());
      expect(cp.lastServerSequence, 0);
      expect(cp.lastSyncedAt, isNull);
    });

    test('copyWith with non-null lastSyncedAt sets the field', () {
      final cp = SyncCheckpoint(
        id: '6',
        entityType: 'note',
        lastServerSequence: 5,
      );

      final later = DateTime(2025);
      final copied = cp.copyWith(lastSyncedAt: later);
      expect(copied.lastSyncedAt, later);
    });

    test('identical checkpoints have matching fields', () {
      final a = SyncCheckpoint(
        id: 'eq1',
        entityType: 'type',
        lastServerSequence: 10,
      );
      final b = SyncCheckpoint(
        id: 'eq1',
        entityType: 'type',
        lastServerSequence: 10,
      );
      expect(a.id, b.id);
      expect(a.entityType, b.entityType);
      expect(a.lastServerSequence, b.lastServerSequence);
    });

    test('checkpoints with different ids are distinct', () {
      final a = SyncCheckpoint(
        id: 'a',
        entityType: 'type',
        lastServerSequence: 10,
      );
      final b = SyncCheckpoint(
        id: 'b',
        entityType: 'type',
        lastServerSequence: 10,
      );
      expect(identical(a, b), isFalse);
      expect(a.id, isNot(b.id));
    });
  });
}
