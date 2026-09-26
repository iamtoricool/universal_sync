/// Identity of the authenticated user, plus a stream of identity changes.
abstract interface class SyncSession {
  String? get userId;

  /// Emits the new user id (or `null` on sign-out).
  Stream<String?> get userIdChanges;
}

/// Default session: no authenticated user.
final class AnonymousSession implements SyncSession {
  const AnonymousSession();

  @override
  String? get userId => null;

  @override
  Stream<String?> get userIdChanges => const Stream.empty();
}

/// Injectable time source. All persisted timestamps are UTC epoch millis.
abstract interface class SyncClock {
  DateTime now();
}

/// Wall-clock implementation.
final class SystemClock implements SyncClock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

/// Deterministic clock for tests.
final class TestClock implements SyncClock {
  TestClock([DateTime? start]) : _now = (start ?? DateTime.utc(2026)).toUtc();

  DateTime _now;

  @override
  DateTime now() => _now;

  /// Advances the clock.
  void advance(Duration by) => _now = _now.add(by);

  /// Sets an absolute time.
  void set(DateTime value) => _now = value.toUtc();
}
