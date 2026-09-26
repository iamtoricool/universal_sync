/// Cooperative cancellation token for long drain/pull cycles.
final class SyncCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void throwIfCancelled() {
    if (_cancelled) {
      throw StateError('Sync operation cancelled');
    }
  }
}
