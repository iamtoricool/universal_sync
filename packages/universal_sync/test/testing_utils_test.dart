import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:universal_sync/testing.dart';
import 'package:universal_sync/universal_sync.dart';

import 'support/entities.dart';
import 'support/rig.dart';
import 'support/test_db.dart';

void main() {
  test('FakeTransport seeds, paginates and reports tombstones', () async {
    final transport = FakeTransport();
    for (var i = 0; i < 3; i++) {
      transport.seed('tasks', taskRow('t$i', 'title $i'));
    }

    final first = await transport.pull(
      const PullPageRequest(
        entity: SyncEntityRef(table: 'tasks', primaryKey: ['id']),
        cursor: null,
        limit: 2,
      ),
    );
    expect(first.rows, hasLength(2));
    expect(first.hasMore, isTrue);
    expect(first.nextCursor, isNotNull);

    final second = await transport.pull(
      PullPageRequest(
        entity: const SyncEntityRef(table: 'tasks', primaryKey: ['id']),
        cursor: first.nextCursor,
        limit: 2,
      ),
    );
    expect(second.rows, hasLength(1));
    expect(second.hasMore, isFalse);

    transport.seed('tasks', taskRow('deleted', 'x'));
    await transport.push(
      const PushBatch(
        entity: SyncEntityRef(table: 'tasks', primaryKey: ['id']),
        changes: [
          SyncChange(
            sequence: 1,
            kind: SyncChangeKind.delete,
            idempotencyKey: 'i:1',
            key: {'id': 'deleted'},
          ),
        ],
      ),
    );
    expect(transport.tombstonesFor('tasks'), isNotEmpty);
  });

  test('FakeTransport exposes ids, batches and injected failures', () async {
    final transport = FakeTransport();
    final batch = PushBatch(
      entity: const SyncEntityRef(table: 'tasks', primaryKey: ['id']),
      changes: const [
        SyncChange(
          sequence: 1,
          kind: SyncChangeKind.upsert,
          idempotencyKey: 'i:1',
          key: {'id': 't1'},
          row: {'id': 't1', 'title': 'a'},
        ),
      ],
    );

    transport.rejectNext(1, const PermanentFailure('bad'));
    final rejected = await transport.push(batch);
    expect(rejected.normalizedAcks.single.status, ChangeStatus.rejected);
    expect(transport.pushedBatches, hasLength(1));

    transport.failNextPush(const TransientFailure('offline'));
    await expectLater(
      transport.push(batch),
      throwsA(isA<TransientFailure>()),
    );

    await transport.push(batch);
    expect(transport.pushedSequences, [1]);
    expect(transport.rowsFor('tasks'), hasLength(1));
  });

  test('FakeTransport dedupes idempotency keys when enabled', () async {
    final transport = FakeTransport()..dedupeByIdempotency = true;
    const batch = PushBatch(
      entity: SyncEntityRef(table: 'tasks', primaryKey: ['id']),
      changes: [
        SyncChange(
          sequence: 1,
          kind: SyncChangeKind.upsert,
          idempotencyKey: 'i:1',
          key: {'id': 't1'},
          row: {'id': 't1', 'title': 'a'},
        ),
      ],
    );

    await transport.push(batch);
    final replay = await transport.push(batch);

    expect(replay.normalizedAcks.single.status, ChangeStatus.superseded);
    expect(transport.rowsFor('tasks'), hasLength(1));
  });

  test('FakeTransport honours latency', () async {
    final transport = FakeTransport(latency: const Duration(milliseconds: 5));
    final stopwatch = Stopwatch()..start();
    await transport.pull(
      const PullPageRequest(
        entity: SyncEntityRef(table: 'tasks', primaryKey: ['id']),
        cursor: null,
        limit: 1,
      ),
    );
    stopwatch.stop();
    expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(4));
  });

  test('SyncTestHarness wires the engine and settles the queue', () async {
    final db = TestDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final entity = tasksEntity(db);
    final harness = await SyncTestHarness.create(
      database: db,
      entities: <SyncEntityBase>[entity],
    );
    addTearDown(harness.sync.dispose);

    await harness.sync
        .table(entity)
        .create(
          TasksCompanion.insert(
            id: 't1',
            title: 'harness',
            updatedAt: DateTime.utc(2026),
          ),
        );

    await harness.settle();

    expect(harness.server.rowsFor('tasks').single['title'], 'harness');
    expect((await harness.sync.diagnostics()).pending, 0);
  });
}
