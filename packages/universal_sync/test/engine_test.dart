import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'package:universal_sync/testing.dart';

import 'package:universal_sync/universal_sync.dart';

import 'support/entities.dart';
import 'support/test_db.dart';

final class _StaticSession implements SyncSession {
  const _StaticSession(this._userId);

  final String? _userId;

  @override
  String? get userId => _userId;

  @override
  Stream<String?> get userIdChanges => const Stream.empty();
}

Map<String, Object?> taskRow(
  String id,
  String title, {
  DateTime? updatedAt,
  String? userId,
}) => {
  'id': id,
  'title': title,
  'done': false,
  'user_id': userId,
  'updated_at': (updatedAt ?? DateTime.utc(2024)).toIso8601String(),
};

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late TestDatabase db;
  late TestClock clock;
  late FakeTransport server;
  late SyncEntity<Tasks, Task, String> entity;
  late UniversalSync<TestDatabase> sync;
  late SyncTable<Tasks, Task, String> tasks;

  SyncOptions options({
    int maxAttempts = 3,
    int pullPageSize = 2,
    ConflictPolicy conflictPolicy = const NewestWins(),
  }) => SyncOptions(
    clock: clock,
    backoff: const FixedBackoff(Duration.zero),
    autoDrain: false,
    maxAttempts: maxAttempts,
    pullPageSize: pullPageSize,
    conflictPolicy: conflictPolicy,
  );

  setUp(() async {
    db = TestDatabase(NativeDatabase.memory());
    clock = TestClock(DateTime.utc(2026, 1, 1));
    server = FakeTransport();
    entity = tasksEntity(db);
    sync = await UniversalSync.open<TestDatabase>(
      database: db,
      entities: <SyncEntityBase>[entity],
      transport: server,
      options: options(),
    );
    tasks = sync.table(entity);
  });

  tearDown(() async {
    await sync.dispose();
    await db.close();
  });

  group('offline sequences', () {
    test('create + update + delete of t1 collapses into one delete', () async {
      await tasks.create(
        TasksCompanion.insert(id: 't1', title: 'v1', updatedAt: clock.now()),
      );
      await tasks.patch('t1', TasksCompanion(title: const Value('v2')));
      await tasks.create(
        TasksCompanion.insert(id: 't2', title: 'w1', updatedAt: clock.now()),
      );
      await tasks.patch('t2', TasksCompanion(title: const Value('w2')));
      await tasks.remove('t1');

      expect((await sync.diagnostics()).pending, 2);

      final report = await sync.drain();

      expect(report.pushed, 2);
      expect(server.rowsFor('tasks'), hasLength(1));
      final remaining = server.rowsFor('tasks').single;
      expect(remaining['id'], 't2');
      expect(remaining['title'], 'w2');
      expect(await tasks.find('t1'), isNull);
      expect((await sync.diagnostics()).pending, 0);
    });

    test('create + update coalesces into a single upsert', () async {
      await tasks.create(
        TasksCompanion.insert(id: 't1', title: 'v1', updatedAt: clock.now()),
      );
      await tasks.patch('t1', TasksCompanion(title: const Value('v2')));

      expect((await sync.diagnostics()).pending, 1);

      await sync.drain();

      expect(server.rowsFor('tasks').single['title'], 'v2');
      expect(server.pushedSequences, hasLength(1));
    });

    test('delete then re-create clears the tombstone and upserts', () async {
      await tasks.create(
        TasksCompanion.insert(id: 't1', title: 'v1', updatedAt: clock.now()),
      );
      await sync.drain();

      await tasks.remove('t1');
      await tasks.create(
        TasksCompanion.insert(id: 't1', title: 'v2', updatedAt: clock.now()),
      );

      await sync.drain();

      expect(server.rowsFor('tasks').single['title'], 'v2');
      expect((await sync.diagnostics()).tombstones, 0);
      expect(await tasks.find('t1'), isNotNull);
    });
  });

  group('delivery certainty', () {
    test('notSent keeps the row coalescible across a failure', () async {
      await tasks.create(
        TasksCompanion.insert(id: 't1', title: 'v1', updatedAt: clock.now()),
      );

      server.failNextPush(
        const TransientFailure(
          'airplane mode',
          certainty: DeliveryCertainty.notSent,
        ),
      );
      await sync.drain();
      expect((await sync.diagnostics()).pending, 1);

      await tasks.patch('t1', TasksCompanion(title: const Value('v2')));
      expect((await sync.diagnostics()).pending, 1);

      await sync.drain();
      expect(server.rowsFor('tasks').single['title'], 'v2');
    });

    test(
      'maybeApplied freezes the row and orders the newer change after it',
      () async {
        await tasks.create(
          TasksCompanion.insert(id: 't1', title: 'v1', updatedAt: clock.now()),
        );

        server.failNextPush(
          const TransientFailure(
            'timeout',
            certainty: DeliveryCertainty.maybeApplied,
          ),
        );
        await sync.drain();

        await tasks.patch('t1', TasksCompanion(title: const Value('v2')));
        expect((await sync.diagnostics()).pending, 2);

        await sync.drain();

        expect(server.rowsFor('tasks').single['title'], 'v2');
        expect(server.pushedSequences, hasLength(2));
        expect(
          server.pushedSequences.first,
          lessThan(server.pushedSequences[1]),
        );
        expect((await sync.diagnostics()).pending, 0);
      },
    );

    test('transient failure emits a retry and preserves the row', () async {
      final events = <SyncEvent>[];
      final sub = sync.events.listen(events.add);
      addTearDown(sub.cancel);

      await tasks.create(
        TasksCompanion.insert(id: 't1', title: 'v1', updatedAt: clock.now()),
      );
      server.failNextPush(
        const TransientFailure(
          'offline',
          certainty: DeliveryCertainty.maybeApplied,
        ),
      );

      final report = await sync.drain();
      await Future<void>.delayed(Duration.zero);

      expect(report.failed, 1);
      expect((await sync.diagnostics()).pending, 1);
      expect(events.whereType<RetryScheduled>(), isNotEmpty);
      expect(events.whereType<OfflineDetected>(), isNotEmpty);
    });
  });

  group('tombstones and deletes', () {
    test('an acked tombstone still suppresses a stale remote row', () async {
      await tasks.create(
        TasksCompanion.insert(id: 't1', title: 'v1', updatedAt: clock.now()),
      );
      await sync.drain();

      await tasks.remove('t1');
      await sync.drain();
      expect(server.rowsFor('tasks'), isEmpty);
      expect((await sync.diagnostics()).tombstones, 1);

      server.seed('tasks', taskRow('t1', 'stale'));

      await sync.pull();

      expect(await tasks.find('t1'), isNull);
    });

    test('a remote tombstone deletes the local row and is recorded', () async {
      await tasks.create(
        TasksCompanion.insert(id: 't1', title: 'v1', updatedAt: clock.now()),
      );
      await sync.drain();

      // Another device deletes the row and our next pull sees the tombstone.
      server.seed('tasks', taskRow('t1', 'v1'));
      await sync.pull();
      expect(await tasks.find('t1'), isNotNull);

      await sync.table(entity).remove('t1');
      // Push the delete so the fake server records a tombstone, then make a
      // fresh local copy to prove the pull path applies the remote tombstone.
      await sync.drain();
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: 't1',
              title: 'resurrected',
              updatedAt: clock.now(),
            ),
          );
      await db.customStatement('DELETE FROM us_tombstones WHERE entity = ?', [
        'tasks',
      ]);

      await sync.pull();

      expect(await tasks.find('t1'), isNull);
    });
  });

  group('conflicts', () {
    test('newestWins keeps a newer local change pending', () async {
      server.seed(
        'tasks',
        taskRow('t1', 'server', updatedAt: DateTime.utc(2020)),
      );

      await tasks.create(
        TasksCompanion.insert(id: 't1', title: 'local', updatedAt: clock.now()),
      );

      await sync.pull();

      expect((await tasks.find('t1'))!.title, 'local');
      expect((await sync.diagnostics()).pending, 1);
    });

    test(
      'newestWins applies a newer server row and clears the outbox',
      () async {
        server.seed(
          'tasks',
          taskRow('t1', 'server', updatedAt: DateTime.utc(2027)),
        );

        await tasks.create(
          TasksCompanion.insert(
            id: 't1',
            title: 'local',
            updatedAt: clock.now(),
          ),
        );

        await sync.pull();

        expect((await tasks.find('t1'))!.title, 'server');
        expect((await sync.diagnostics()).pending, 0);
      },
    );

    test('serverWins always replaces the local row', () async {
      final serverWinsSync = await UniversalSync.open<TestDatabase>(
        database: db,
        entities: <SyncEntityBase>[entity],
        transport: server,
        options: options(conflictPolicy: const ServerWins()),
      );
      addTearDown(serverWinsSync.dispose);

      server.seed('tasks', taskRow('t1', 'server'));
      await tasks.create(
        TasksCompanion.insert(id: 't1', title: 'local', updatedAt: clock.now()),
      );

      await serverWinsSync.pull();

      expect((await tasks.find('t1'))!.title, 'server');
      expect((await serverWinsSync.diagnostics()).pending, 0);
    });

    test('manual policy stores a durable conflict', () async {
      final manualSync = await UniversalSync.open<TestDatabase>(
        database: db,
        entities: <SyncEntityBase>[entity],
        transport: server,
        options: options(conflictPolicy: const ManualConflicts()),
      );
      addTearDown(manualSync.dispose);

      server.seed('tasks', taskRow('t1', 'server'));
      await tasks.create(
        TasksCompanion.insert(id: 't1', title: 'local', updatedAt: clock.now()),
      );

      await manualSync.pull();

      final conflicts = await manualSync.conflicts();
      expect(conflicts, hasLength(1));
      expect(conflicts.single.entity, 'tasks');
      expect((await manualSync.diagnostics()).conflicts, 1);

      await manualSync.resolveConflict(
        conflicts.single.id,
        const AcceptServer(),
      );

      expect(await manualSync.conflicts(), isEmpty);
      expect((await tasks.find('t1'))!.title, 'server');
    });
  });

  group('pull', () {
    test('paginates without skipping rows', () async {
      for (var i = 0; i < 5; i++) {
        server.seed(
          'tasks',
          taskRow('t$i', 'title $i', updatedAt: DateTime.utc(2024, 1, i + 1)),
        );
      }

      final report = await sync.pull();

      expect(report.pulled, 5);
      expect((await tasks.query().get()), hasLength(5));
    });

    test('skips rows owned by another user', () async {
      final userSync = await UniversalSync.open<TestDatabase>(
        database: db,
        entities: <SyncEntityBase>[entity],
        transport: server,
        session: const _StaticSession('u1'),
        options: options(),
      );
      addTearDown(userSync.dispose);

      server.seed('tasks', taskRow('t1', 'foreign', userId: 'u2'));
      server.seed('tasks', taskRow('t2', 'mine', userId: 'u1'));

      await userSync.pull();

      expect(await tasks.find('t1'), isNull);
      expect(await tasks.find('t2'), isNotNull);
    });

    test('equal timestamps do not skip rows (revision cursor)', () async {
      final ts = DateTime.utc(2024);
      for (var i = 0; i < 3; i++) {
        server.seed('tasks', taskRow('t$i', 't', updatedAt: ts));
      }

      await sync.pull();

      expect(await tasks.query().get(), hasLength(3));
    });
  });

  group('durability and failure isolation', () {
    test('local write and outbox append roll back together', () async {
      await expectLater(
        db.transaction(() async {
          await tasks.create(
            TasksCompanion.insert(
              id: 't1',
              title: 'v1',
              updatedAt: clock.now(),
            ),
          );
          throw StateError('boom');
        }),
        throwsStateError,
      );

      expect(await tasks.query().get(), isEmpty);
      expect((await sync.diagnostics()).pending, 0);
    });

    test('permanent failure parks the change instead of dropping it', () async {
      final strictSync = await UniversalSync.open<TestDatabase>(
        database: db,
        entities: <SyncEntityBase>[entity],
        transport: server,
        options: options(maxAttempts: 1),
      );
      addTearDown(strictSync.dispose);
      final strictTasks = strictSync.table(entity);

      await strictTasks.create(
        TasksCompanion.insert(id: 't1', title: 'v1', updatedAt: clock.now()),
      );
      server.rejectNext(1, const PermanentFailure('bad row'));

      final report = await strictSync.drain();

      expect(report.parked, 1);
      expect((await strictSync.diagnostics()).pending, 0);
      expect((await strictSync.diagnostics()).parked, 1);

      expect(await strictSync.retryParked(), 1);
      expect((await strictSync.diagnostics()).pending, 1);

      await strictSync.drain();
      expect(server.rowsFor('tasks'), hasLength(1));
    });

    test(
      'incomplete acks are a contract violation and keep the rows',
      () async {
        final events = <SyncEvent>[];
        final sub = sync.events.listen(events.add);
        addTearDown(sub.cancel);

        server.dropLastAck = true;
        await tasks.create(
          TasksCompanion.insert(id: 't1', title: 'v1', updatedAt: clock.now()),
        );

        await sync.drain();
        await Future<void>.delayed(Duration.zero);

        expect((await sync.diagnostics()).pending, 1);
        expect(events.whereType<TransportContractViolation>(), isNotEmpty);

        server.dropLastAck = false;
        await sync.drain();
        expect(server.rowsFor('tasks'), hasLength(1));
      },
    );

    test('missing auth stops the drain and preserves the row', () async {
      final events = <SyncEvent>[];
      final sub = sync.events.listen(events.add);
      addTearDown(sub.cancel);

      server.failNextPush(const AuthFailure('token expired'));
      await tasks.create(
        TasksCompanion.insert(id: 't1', title: 'v1', updatedAt: clock.now()),
      );

      await sync.drain();
      await Future<void>.delayed(Duration.zero);

      expect((await sync.diagnostics()).pending, 1);
      expect(events.whereType<AuthRequired>(), isNotEmpty);
      expect(sync.status, SyncStatus.authRequired);
    });
  });

  group('adoption and lifecycle', () {
    test('bootstrap uploads pre-existing local rows', () async {
      final db2 = TestDatabase(NativeDatabase.memory());
      addTearDown(db2.close);
      await db2
          .into(db2.tasks)
          .insert(
            TasksCompanion.insert(
              id: 'legacy',
              title: 'existing',
              updatedAt: clock.now(),
            ),
          );

      final server2 = FakeTransport();
      final entity2 = tasksEntity(db2);
      final sync2 = await UniversalSync.open<TestDatabase>(
        database: db2,
        entities: <SyncEntityBase>[entity2],
        transport: server2,
        options: options(),
        bootstrap: const UploadLocal(),
      );
      addTearDown(sync2.dispose);

      final report = await sync2.syncNow(push: true, pull: true);

      expect(report.pushed, 1);
      expect(server2.rowsFor('tasks').single['id'], 'legacy');
    });

    test('purge wipes queue, tombstones and local data', () async {
      await tasks.create(
        TasksCompanion.insert(id: 't1', title: 'v1', updatedAt: clock.now()),
      );
      await sync.drain();
      await tasks.remove('t1');
      await sync.drain();

      await sync.purge(localData: true);

      final diagnostics = await sync.diagnostics();
      expect(diagnostics.pending, 0);
      expect(diagnostics.tombstones, 0);
      expect(await tasks.query().get(), isEmpty);
    });

    test('markDirty picks up a row written by an existing DAO', () async {
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: 't1',
              title: 'dao',
              updatedAt: clock.now(),
            ),
          );

      await tasks.markDirty('t1', kind: SyncChangeKind.upsert);
      await sync.drain();

      expect(server.rowsFor('tasks').single['title'], 'dao');
    });

    test('schema install is idempotent and keeps the install id', () async {
      final firstId = (await sync.diagnostics()).installId;
      final second = await UniversalSync.open<TestDatabase>(
        database: db,
        entities: <SyncEntityBase>[entity],
        transport: server,
        options: options(),
      );
      addTearDown(second.dispose);

      final secondId = (await second.diagnostics()).installId;
      expect(secondId, firstId);
      expect((await second.diagnostics()).schemaVersion, kSyncSchemaVersion);
    });

    test('a transport without server timestamps is rejected', () async {
      final db2 = TestDatabase(NativeDatabase.memory());
      addTearDown(db2.close);
      final weak = FakeTransport(
        capabilities: const SyncTransportCapabilities(serverTimestamps: false),
      );

      await expectLater(
        UniversalSync.open<TestDatabase>(
          database: db2,
          entities: <SyncEntityBase>[tasksEntity(db2)],
          transport: weak,
        ),
        throwsA(isA<SyncCapabilityMismatch>()),
      );
    });
  });

  group('failure serialization', () {
    test('every failure round-trips through JSON', () {
      final failures = <SyncFailure>[
        const AuthFailure('auth'),
        const ForbiddenFailure('forbidden'),
        const RateLimited('rate', retryAfter: Duration(seconds: 3)),
        const TransientFailure(
          'transient',
          certainty: DeliveryCertainty.notSent,
        ),
        const RevisionConflict('conflict', serverRow: {'id': 't1'}),
        const PermanentFailure('permanent'),
        const UnknownFailure('unknown'),
      ];

      for (final failure in failures) {
        final restored = SyncFailure.fromJson(failure.toJson());
        expect(restored.code, failure.code);
        expect(restored.message, failure.message);
        expect(restored.certainty, failure.certainty);
        expect(restored.retryAfter, failure.retryAfter);
      }
    });

    test('unknown codes remain loadable', () {
      final restored = SyncFailure.fromJson({'code': 'fromTheFuture'});
      expect(restored, isA<UnknownFailure>());
    });
  });
}
