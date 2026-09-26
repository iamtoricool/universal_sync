/// Aggregate result of a drain or pull cycle.
final class SyncReport {
  const SyncReport({
    this.pushed = 0,
    this.failed = 0,
    this.parked = 0,
    this.pulled = 0,
    this.conflicts = 0,
    this.coalesced = 0,
    this.cancelled = 0,
    this.elapsed = Duration.zero,
  });

  final int pushed;
  final int failed;
  final int parked;
  final int pulled;
  final int conflicts;
  final int coalesced;
  final int cancelled;
  final Duration elapsed;

  bool get isEmpty => pushed == 0 && failed == 0 && parked == 0 && pulled == 0 && conflicts == 0;

  @override
  String toString() =>
      'SyncReport(pushed: $pushed, failed: $failed, '
      'parked: $parked, pulled: $pulled, conflicts: $conflicts, '
      'coalesced: $coalesced, cancelled: $cancelled, elapsed: $elapsed)';
}

/// Current engine activity, suitable for building an offline/sync indicator.
enum SyncStatus { idle, draining, pulling, offline, authRequired, schemaError }

/// Snapshot of queue health for diagnostics and bug reports.
final class SyncDiagnostics {
  const SyncDiagnostics({
    required this.pending,
    required this.inflight,
    required this.tombstones,
    required this.conflicts,
    required this.parked,
    required this.outboxBytes,
    required this.installId,
    required this.schemaVersion,
    required this.lastError,
  });

  final int pending;
  final int inflight;
  final int tombstones;
  final int conflicts;
  final int parked;
  final int outboxBytes;
  final String installId;
  final int schemaVersion;
  final String? lastError;

  @override
  String toString() =>
      'SyncDiagnostics(pending: $pending, '
      'inflight: $inflight, tombstones: $tombstones, conflicts: $conflicts, '
      'parked: $parked, outboxBytes: $outboxBytes)';
}
