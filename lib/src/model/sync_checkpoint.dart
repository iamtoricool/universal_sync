import 'package:universal_sync/src/internal/sentinel.dart';

class SyncCheckpoint {
  final String id;
  final String entityType;
  final int lastServerSequence;
  final DateTime? lastSyncedAt;

  const SyncCheckpoint({
    required this.id,
    required this.entityType,
    required this.lastServerSequence,
    this.lastSyncedAt,
  });

  SyncCheckpoint copyWith({
    String? id,
    String? entityType,
    int? lastServerSequence,
    Object? lastSyncedAt = sentinel,
  }) {
    return SyncCheckpoint(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      lastServerSequence: lastServerSequence ?? this.lastServerSequence,
      lastSyncedAt: identical(lastSyncedAt, sentinel) ? this.lastSyncedAt : lastSyncedAt as DateTime?,
    );
  }
}
