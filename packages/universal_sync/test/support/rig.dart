import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:universal_sync/testing.dart';
import 'package:universal_sync/universal_sync.dart';

import 'entities.dart';
import 'test_db.dart';

/// Shared setup for engine/journal tests.
final class TestRig {
  TestRig._({
    required this.db,
    required this.clock,
    required this.server,
    required this.sync,
  }) : entity = tasksEntity(db);

  final TestDatabase db;
  final TestClock clock;
  final FakeTransport server;
  final UniversalSync<TestDatabase> sync;
  final SyncEntity<Tasks, Task, String> entity;

  SyncTable<Tasks, Task, String> get tasks => sync.table(entity);

  static Future<TestRig> create({
    SyncOptions? options,
    SyncSession session = const AnonymousSession(),
    FakeTransport? server,
    SyncTransport? transport,
    SyncBootstrap bootstrap = const SkipBootstrap(),
    List<SyncEntityBase>? entities,
    TestClock? clock,
    Future<void> Function(TestDatabase db)? prepare,
  }) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = TestDatabase(NativeDatabase.memory());
    final resolvedClock = clock ?? TestClock(DateTime.utc(2026));
    final resolvedServer = server ?? FakeTransport();
    final resolvedTransport = transport ?? resolvedServer;
    if (prepare != null) await prepare(db);
    final initialEntity = tasksEntity(db);
    final sync = await UniversalSync.open<TestDatabase>(
      database: db,
      entities: entities ?? <SyncEntityBase>[initialEntity],
      transport: resolvedTransport,
      session: session,
      options:
          options ??
          SyncOptions(
            clock: resolvedClock,
            backoff: const FixedBackoff(Duration.zero),
            autoDrain: false,
            pullPageSize: 2,
          ),
      bootstrap: bootstrap,
    );
    return TestRig._(
      db: db,
      clock: resolvedClock,
      server: resolvedServer,
      sync: sync,
    );
  }

  Future<void> dispose() async {
    await sync.dispose();
    await db.close();
  }
}

Map<String, Object?> taskRow(
  String id,
  String title, {
  DateTime? updatedAt,
  String? userId,
  bool done = false,
}) => {
  'id': id,
  'title': title,
  'done': done,
  'user_id': userId,
  'updated_at': (updatedAt ?? DateTime.utc(2024)).toIso8601String(),
};
