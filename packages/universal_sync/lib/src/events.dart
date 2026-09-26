import 'contract/change.dart';
import 'contract/failures.dart';

/// Lifecycle event emitted by the engine.
sealed class SyncEvent {
  const SyncEvent({required this.at});

  final DateTime at;
}

final class DrainStarted extends SyncEvent {
  const DrainStarted({required super.at});
}

final class DrainCompleted extends SyncEvent {
  const DrainCompleted({
    required super.at,
    required this.pushed,
    required this.failed,
  });

  final int pushed;
  final int failed;
}

final class ChangePushed extends SyncEvent {
  const ChangePushed({
    required super.at,
    required this.entity,
    required this.keyJson,
    required this.kind,
  });

  final String entity;
  final String keyJson;
  final SyncChangeKind kind;
}

final class ChangeCoalesced extends SyncEvent {
  const ChangeCoalesced({
    required super.at,
    required this.entity,
    required this.keyJson,
  });

  final String entity;
  final String keyJson;
}

final class ChangeCancelled extends SyncEvent {
  const ChangeCancelled({
    required super.at,
    required this.entity,
    required this.keyJson,
  });

  final String entity;
  final String keyJson;
}

final class ChangeParked extends SyncEvent {
  const ChangeParked({
    required super.at,
    required this.entity,
    required this.keyJson,
    required this.failure,
  });

  final String entity;
  final String keyJson;
  final SyncFailure failure;
}

final class ChangePromoted extends SyncEvent {
  const ChangePromoted({
    required super.at,
    required this.entity,
    required this.keyJson,
  });

  final String entity;
  final String keyJson;
}

final class RetryScheduled extends SyncEvent {
  const RetryScheduled({
    required super.at,
    required this.entity,
    required this.keyJson,
    required this.nextAttemptAt,
    required this.failure,
  });

  final String entity;
  final String keyJson;
  final DateTime nextAttemptAt;
  final SyncFailure failure;
}

final class RowsPulled extends SyncEvent {
  const RowsPulled({
    required super.at,
    required this.entity,
    required this.rowCount,
    required this.hadMore,
  });

  final String entity;
  final int rowCount;
  final bool hadMore;
}

final class ConflictDetected extends SyncEvent {
  const ConflictDetected({
    required super.at,
    required this.entity,
    required this.keyJson,
    required this.policy,
  });

  final String entity;
  final String keyJson;
  final String policy;
}

final class ConflictResolved extends SyncEvent {
  const ConflictResolved({
    required super.at,
    required this.entity,
    required this.keyJson,
    required this.serverWon,
  });

  final String entity;
  final String keyJson;
  final bool serverWon;
}

final class AuthRequired extends SyncEvent {
  const AuthRequired({required super.at, required this.error});

  final Object error;
}

final class OfflineDetected extends SyncEvent {
  const OfflineDetected({required super.at, required this.error});

  final Object error;
}

final class OutboxPressure extends SyncEvent {
  const OutboxPressure({
    required super.at,
    required this.bytes,
    required this.limit,
  });

  final int bytes;
  final int limit;
}

final class TransportContractViolation extends SyncEvent {
  const TransportContractViolation({required super.at, required this.message});

  final String message;
}

final class SyncRowRejected extends SyncEvent {
  const SyncRowRejected({
    required super.at,
    required this.entity,
    required this.message,
  });

  final String entity;
  final String message;
}

final class SyncSchemaMismatchEvent extends SyncEvent {
  const SyncSchemaMismatchEvent({required super.at, required this.message});

  final String message;
}
