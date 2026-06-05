import 'package:test/test.dart';
import 'package:universal_sync/src/adapter/local_adapter.dart';
import 'package:universal_sync/src/model/sync_queue_entry.dart';
import 'package:universal_sync/src/model/sync_checkpoint.dart';
import 'package:universal_sync/src/model/sync_entity.dart';

class _ConcreteLocalAdapter implements LocalAdapter {
  @override
  Future<T> transaction<T>(Future<T> Function() callback) async => callback();

  @override
  Future<void> enqueue<T extends SyncEntity>(SyncQueueEntry<T> entry) async {}

  @override
  Future<void> updateQueueEntryStatus(String entryId, SyncEntryStatus status) async {}

  @override
  Future<List<SyncQueueEntry<SyncEntity>>> fetchPendingEntries(String entityType, int limit) async => [];

  @override
  Future<int> nextSequence() async => 0;

  @override
  Future<SyncCheckpoint?> readCheckpoint(String entityType) async => null;

  @override
  Future<void> writeCheckpoint(SyncCheckpoint checkpoint) async {}

  @override
  Future<void> upsertEntity(String entityType, Map<String, dynamic> data) async {}

  @override
  Future<void> softDeleteEntity(String entityType, String entityId) async {}
}

void main() {
  test('LocalAdapter can be implemented with all 9 methods', () {
    final adapter = _ConcreteLocalAdapter();
    expect(adapter, isA<LocalAdapter>());
  });
}
