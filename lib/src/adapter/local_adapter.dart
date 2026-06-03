import '../model/sync_queue_entry.dart';
import '../model/sync_checkpoint.dart';

abstract class LocalAdapter {
  Future<T> transaction<T>(Future<T> Function() callback);

  Future<void> enqueue(SyncQueueEntry entry);

  Future<void> updateQueueEntryStatus(String entryId, SyncEntryStatus status);

  Future<List<SyncQueueEntry>> fetchPendingEntries(String entityType, int limit);

  Future<int> nextSequence();

  Future<SyncCheckpoint?> readCheckpoint(String entityType);

  Future<void> writeCheckpoint(SyncCheckpoint checkpoint);

  Future<void> upsertEntity(String entityType, Map<String, dynamic> data);

  Future<void> softDeleteEntity(String entityType, String entityId);
}
