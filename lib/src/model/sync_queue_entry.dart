enum SyncOperation { insert, update, delete }

enum SyncEntryStatus { pending, synced, failed }

class SyncQueueEntry {
  final String id;
  final String idempotencyKey;
  final String entityType;
  final String entityId;
  final SyncOperation operation;
  final String payload;
  final int version;
  final int localSequence;
  final SyncEntryStatus status;
  final DateTime createdAt;
  final DateTime? syncedAt;

  const SyncQueueEntry({
    required this.id,
    required this.idempotencyKey,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.version,
    required this.localSequence,
    this.status = SyncEntryStatus.pending,
    required this.createdAt,
    this.syncedAt,
  });

  SyncQueueEntry copyWith({
    String? id,
    String? idempotencyKey,
    String? entityType,
    String? entityId,
    SyncOperation? operation,
    String? payload,
    int? version,
    int? localSequence,
    SyncEntryStatus? status,
    DateTime? createdAt,
    Object? syncedAt = _unset,
  }) {
    return SyncQueueEntry(
      id: id ?? this.id,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      version: version ?? this.version,
      localSequence: localSequence ?? this.localSequence,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: identical(syncedAt, _unset) ? this.syncedAt : syncedAt as DateTime?,
    );
  }
}

const _unset = _Unset();

class _Unset {
  const _Unset();
}
