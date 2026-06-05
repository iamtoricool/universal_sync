import '../../model/sync_entity.dart';
import '../../model/sync_queue_entry.dart';
import '../../model/sync_checkpoint.dart';
import '../local_adapter.dart';

class InMemoryLocalAdapter implements LocalAdapter {
  final _entities = <String, Map<String, Map<String, dynamic>>>{};
  final _queue = <SyncQueueEntry<SyncEntity>>[];
  final _checkpoints = <String, SyncCheckpoint>{};
  int _sequence = 0;

  @override
  Future<T> transaction<T>(Future<T> Function() callback) async {
    return callback();
  }

  @override
  Future<void> enqueue<T extends SyncEntity>(SyncQueueEntry<T> entry) async {
    _queue.add(entry);
  }

  @override
  Future<void> updateQueueEntryStatus(
    String entryId,
    SyncEntryStatus status,
  ) async {
    final index = _queue.indexWhere((e) => e.id == entryId);
    if (index == -1) return;
    _queue[index] = _queue[index].copyWith(
      status: status,
      syncedAt: status == SyncEntryStatus.synced ? DateTime.now() : null,
    );
  }

  @override
  Future<List<SyncQueueEntry<SyncEntity>>> fetchPendingEntries(String entityType, int limit) async {
    final entries = _queue.where((e) => e.entityType == entityType && e.status == SyncEntryStatus.pending).toList();
    entries.sort((a, b) => a.localSequence.compareTo(b.localSequence));
    return entries.take(limit).toList();
  }

  @override
  Future<int> nextSequence() async {
    return _sequence++;
  }

  @override
  Future<SyncCheckpoint?> readCheckpoint(String entityType) async {
    return _checkpoints[entityType];
  }

  @override
  Future<void> writeCheckpoint(SyncCheckpoint checkpoint) async {
    _checkpoints[checkpoint.entityType] = checkpoint;
  }

  @override
  Future<void> upsertEntity(String entityType, Map<String, dynamic> data) async {
    _entities.putIfAbsent(entityType, () => {});
    _entities[entityType]![data['id'] as String] = data;
  }

  @override
  Future<void> softDeleteEntity(String entityType, String entityId) async {
    final entity = _entities[entityType]?[entityId];
    if (entity != null) {
      entity['deletedAt'] = DateTime.now().toIso8601String();
    }
  }

  Map<String, Map<String, Map<String, dynamic>>> get entities => _entities;

  void reset() {
    _entities.clear();
    _queue.clear();
    _checkpoints.clear();
    _sequence = 0;
  }
}
