sealed class SyncState {
  const SyncState();
}

class SyncIdle extends SyncState {
  final DateTime? lastSyncedAt;

  const SyncIdle({this.lastSyncedAt});
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

  const SyncError({
    required this.error,
    required this.stackTrace,
  });
}

enum SyncPhase { pushing, pulling }
