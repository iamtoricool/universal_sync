import 'package:universal_sync/src/model/sync_entity.dart';
import 'package:universal_sync/src/internal/type_utils.dart';
import 'package:universal_sync/src/internal/sentinel.dart';

enum SyncOperation { insert, update, delete }

enum SyncEntryStatus { pending, synced, failed }

class SyncQueueEntry<T extends SyncEntity> {
  final String id;
  final String idempotencyKey;
  final String entityType;
  final String entityId;
  final T data;
  final SyncOperation operation;
  final int version;
  final int localSequence;
  final SyncEntryStatus status;
  final DateTime createdAt;
  final DateTime? syncedAt;

  SyncQueueEntry({
    required this.id,
    required this.idempotencyKey,
    required this.data,
    required this.operation,
    required this.version,
    required this.localSequence,
    this.status = SyncEntryStatus.pending,
    required this.createdAt,
    this.syncedAt,
  }) : entityType = T == SyncEntity ? entityTypeName(data.runtimeType) : entityTypeName(T),
       entityId = data.id;

  SyncQueueEntry<T> copyWith({
    String? id,
    String? idempotencyKey,
    T? data,
    SyncOperation? operation,
    int? version,
    int? localSequence,
    SyncEntryStatus? status,
    DateTime? createdAt,
    Object? syncedAt = sentinel,
  }) {
    return SyncQueueEntry<T>(
      id: id ?? this.id,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      data: data ?? this.data,
      operation: operation ?? this.operation,
      version: version ?? this.version,
      localSequence: localSequence ?? this.localSequence,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: identical(syncedAt, sentinel) ? this.syncedAt : syncedAt as DateTime?,
    );
  }
}
