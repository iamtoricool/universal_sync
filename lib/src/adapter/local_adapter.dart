import '../model/sync_queue_entry.dart';
import '../model/sync_checkpoint.dart';
import '../model/sync_entity.dart';
import '../internal/type_utils.dart';

abstract class LocalAdapter {
  Future<T> transaction<T>(Future<T> Function() callback);

  Future<void> enqueue<T extends SyncEntity>(SyncQueueEntry<T> entry);

  Future<void> updateQueueEntryStatus(String entryId, SyncEntryStatus status);

  Future<List<SyncQueueEntry<SyncEntity>>> fetchPendingEntries(String entityType, int limit);

  Future<int> nextSequence();

  Future<SyncCheckpoint?> readCheckpoint(String entityType);

  Future<void> writeCheckpoint(SyncCheckpoint checkpoint);

  Future<void> upsertEntity(String entityType, Map<String, dynamic> data);

  Future<void> softDeleteEntity(String entityType, String entityId);
}

extension LocalAdapterX on LocalAdapter {
  Future<void> upsertEntityFor<T extends SyncEntity>(Map<String, dynamic> data) {
    return upsertEntity(entityTypeName(T), data);
  }

  Future<void> softDeleteEntityFor<T extends SyncEntity>(String entityId) {
    return softDeleteEntity(entityTypeName(T), entityId);
  }

  Future<void> enqueueFor<T extends SyncEntity>(
    T entity,
    SyncOperation operation, {
    String? idempotencyKey,
  }) async {
    final seq = await nextSequence();
    final id = '${entity.id}_$seq';
    return enqueue(
      SyncQueueEntry<T>(
        id: id,
        idempotencyKey: idempotencyKey ?? id,
        data: entity,
        operation: operation,
        version: entity.version,
        localSequence: seq,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<SyncCheckpoint?> readCheckpointForm<T extends SyncEntity>() => readCheckpoint(entityTypeName(T));
}
