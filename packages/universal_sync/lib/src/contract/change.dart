import 'failures.dart';
import 'pull.dart';

/// The kind of change sent to a transport.
///
/// `insert` is deliberately absent: every create is an upsert so retries are
/// idempotent.
enum SyncChangeKind { upsert, update, delete }

/// One outbox row, as seen by the transport.
final class SyncChange {
  const SyncChange({
    required this.sequence,
    required this.kind,
    required this.idempotencyKey,
    this.key = const {},
    this.row = const {},
    this.delta,
  });

  /// Local outbox sequence; unique per install and used for ack correlation.
  final int sequence;

  final SyncChangeKind kind;

  /// `'<installId>:<sequence>'`, stable across retries.
  final String idempotencyKey;

  /// Primary-key column values. Always present, including for deletes.
  final Map<String, Object?> key;

  /// Full after-image, keyed by SQL column name. Empty for deletes.
  final Map<String, Object?> row;

  /// Changed columns only, for [SyncChangeKind.update].
  final Map<String, Object?>? delta;
}

/// A batch of changes for exactly one entity.
final class PushBatch {
  const PushBatch({
    required this.entity,
    required this.changes,
    this.attempt = 1,
  });

  final SyncEntityRef entity;
  final List<SyncChange> changes;
  final int attempt;
}

/// Transport-side result for one change.
enum ChangeStatus { applied, rejected, superseded }

/// Acknowledgement for a single change.
final class ChangeAck {
  const ChangeAck({
    required this.sequence,
    required this.status,
    this.serverRow,
    this.failure,
  });

  const ChangeAck.applied(int sequence, {Map<String, Object?>? serverRow})
    : this(
        sequence: sequence,
        status: ChangeStatus.applied,
        serverRow: serverRow,
      );

  const ChangeAck.superseded(int sequence, {Map<String, Object?>? serverRow})
    : this(
        sequence: sequence,
        status: ChangeStatus.superseded,
        serverRow: serverRow,
      );

  const ChangeAck.rejected(int sequence, SyncFailure failure)
    : this(sequence: sequence, status: ChangeStatus.rejected, failure: failure);

  final int sequence;
  final ChangeStatus status;

  /// Authoritative row returned by the server (required when the entity has
  /// server-managed columns).
  final Map<String, Object?>? serverRow;

  /// Present when [status] is [ChangeStatus.rejected].
  final SyncFailure? failure;
}

/// The complete result of [SyncTransport.push]. Acks must cover every change.
final class PushOutcome {
  const PushOutcome(this.acks);

  PushOutcome.appliedAll(Iterable<int> sequences)
    : acks = [for (final sequence in sequences) ChangeAck.applied(sequence)];

  final List<ChangeAck> acks;

  /// Convenience alias used by the engine.
  List<ChangeAck> get normalizedAcks => acks;
}
