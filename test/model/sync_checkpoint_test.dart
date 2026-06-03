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
  });
}
