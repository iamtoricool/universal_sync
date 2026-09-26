import 'change.dart';
import 'pull.dart';

/// What a transport implementation supports. Cross-checked at `open()`.
final class SyncTransportCapabilities {
  const SyncTransportCapabilities({
    this.serverTimestamps = false,
    this.tombstones = false,
    this.idempotency = false,
    this.atomicMultiEntity = false,
    this.deliveryCertainty = false,
    this.cursors = const {CursorKind.opaque, CursorKind.keyset},
  });

  /// The backend echoes the applied row, including server timestamps.
  final bool serverTimestamps;

  /// The backend reports deletions during pull.
  final bool tombstones;

  /// The backend dedupes `(entity, idempotencyKey)`.
  final bool idempotency;

  /// [SyncTransport.pushMany] applies multiple entities atomically.
  final bool atomicMultiEntity;

  /// The adapter can distinguish [DeliveryCertainty.notSent] from
  /// `maybeApplied`.
  final bool deliveryCertainty;

  final Set<CursorKind> cursors;
}

/// Thrown at `open()` when a transport cannot satisfy a registered entity.
class SyncCapabilityMismatch implements Exception {
  const SyncCapabilityMismatch({
    required this.entity,
    required this.requirement,
  });

  final String entity;
  final String requirement;

  @override
  String toString() =>
      'SyncCapabilityMismatch: entity "$entity" requires '
      '$requirement, which the transport does not advertise.';
}

/// The contract every backend adapter package implements.
///
/// Extend this class to inherit the [pushMany] and [close] defaults.
abstract base class SyncTransport {
  const SyncTransport();

  SyncTransportCapabilities get capabilities;

  Future<PushOutcome> push(PushBatch batch);

  Future<PullPage> pull(PullPageRequest request);

  /// Default implementation loops [push]. Override when the backend can apply
  /// multiple entities atomically.
  Future<Map<SyncEntityRef, PushOutcome>> pushMany(
    List<PushBatch> batches,
  ) async {
    final results = <SyncEntityRef, PushOutcome>{};
    for (final batch in batches) {
      results[batch.entity] = await push(batch);
    }
    return results;
  }

  /// Release sockets/clients. Never closes the consumer's database.
  Future<void> close() async {}
}
