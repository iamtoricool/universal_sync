sealed class SyncState {
  const SyncState();
}

class SyncIdle extends SyncState {
  final DateTime? lastSyncedAt;
  final int pendingCount;

  const SyncIdle({this.lastSyncedAt, this.pendingCount = 0});
}

class SyncInProgress extends SyncState {
  final SyncPhase phase;
  final int processed;
  final int total;

  const SyncInProgress({
    required this.phase,
    required this.processed,
    required this.total,
  });

  double get progress => total == 0 ? 0.0 : processed / total;
}

class SyncError extends SyncState {
  final Object error;
  final StackTrace stackTrace;
  final int pendingCount;

  const SyncError({
    required this.error,
    required this.stackTrace,
    required this.pendingCount,
  });
}

enum SyncPhase { pushing, pulling }
