import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:universal_sync/testing.dart';
import 'package:universal_sync/universal_sync.dart';

import 'support/entities.dart';
import 'support/rig.dart';
import 'support/test_db.dart';

final class _MutatingTransport extends SyncTransport {
  _MutatingTransport(this.inner, this.mutate);

  final SyncTransport inner;
  final List<ChangeAck> Function(List<ChangeAck> acks, PushBatch batch) mutate;

  @override
  SyncTransportCapabilities get capabilities => inner.capabilities;

  @override
  Future<PushOutcome> push(PushBatch batch) async {
    final outcome = await inner.push(batch);
    return PushOutcome(mutate(outcome.normalizedAcks, batch));
  }

  @override
  Future<PullPage> pull(PullPageRequest request) => inner.pull(request);
}

final class _PullTransport extends SyncTransport {
  _PullTransport(this.inner, this.pullPage);

  final SyncTransport inner;
  final Future<PullPage> Function(PullPageRequest request) pullPage;

  @override
  SyncTransportCapabilities get capabilities => inner.capabilities;

  @override
  Future<PushOutcome> push(PushBatch batch) => inner.push(batch);

  @override
  Future<PullPage> pull(PullPageRequest request) => pullPage(request);
}

final class _PullAndCancel extends SyncTransport {
  _PullAndCancel(this.inner, this.token);

  final SyncTransport inner;
  final SyncCancelToken token;

  @override
  SyncTransportCapabilities get capabilities => inner.capabilities;

  @override
  Future<PushOutcome> push(PushBatch batch) => inner.push(batch);

  @override
  Future<PullPage> pull(PullPageRequest request) async {
    token.cancel();
    return PullPage(
      rows: [taskRow('t1', 'one')],
      deletedKeys: const [],
      nextCursor: const OpaqueCursor('1'),
      hasMore: true,
    );
  }
}

void main() {
  test('open rejects duplicate entity registration', () async {
    final db = TestDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final entity = tasksEntity(db);

    await expectLater(
      UniversalSync.open<TestDatabase>(
        database: db,
        entities: <SyncEntityBase>[entity, tasksEntity(db)],
        transport: FakeTransport(),
      ),
      throwsArgumentError,
    );
  });

  test('open checks generated column expectations', () async {
    final db = TestDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final normal = tasksEntity(db);
    final broken = SyncEntity<Tasks, Task, String>(
      table: db.tasks,
      keyColumns: const ['id'],
      keyOf: normal.keyOf,
      whereKey: normal.whereKey,
      encode: normal.encode,
      decode: normal.decode,
      keyParts: normal.keyParts,
      keyFromParts: normal.keyFromParts,
      expectedColumns: const ['not_a_column'],
    );

    await expectLater(
      UniversalSync.open<TestDatabase>(
        database: db,
        entities: <SyncEntityBase>[broken],
        transport: FakeTransport(),
      ),
      throwsA(isA<SyncSchemaMismatch>()),
    );
  });

  test('autoDrain debounces and drains after a write', () async {
    final rig = await TestRig.create(
      options: SyncOptions(
        clock: TestClock(DateTime.utc(2026)),
        backoff: const FixedBackoff(Duration.zero),
        autoDrain: true,
        autoDrainDebounce: const Duration(milliseconds: 1),
      ),
    );
    addTearDown(rig.dispose);

    await rig.tasks.create(
      TasksCompanion.insert(
        id: 't1',
        title: 'x',
        updatedAt: rig.clock.now(),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(rig.server.rowsFor('tasks'), hasLength(1));
    expect((await rig.sync.diagnostics()).pending, 0);
  });

  test('auth failures delivered as acks stop the drain', () async {
    final fake = FakeTransport();
    final rig = await TestRig.create(server: fake);
    addTearDown(rig.dispose);
    final events = <SyncEvent>[];
    rig.sync.events.listen(events.add);

    await rig.tasks.create(
      TasksCompanion.insert(
        id: 't1',
        title: 'x',
        updatedAt: rig.clock.now(),
      ),
    );
    fake.rejectNext(1, const AuthFailure('expired'));
    await rig.sync.drain();
    await Future<void>.delayed(Duration.zero);

    expect((await rig.sync.diagnostics()).pending, 1);
    expect(rig.sync.status, SyncStatus.authRequired);
    expect(events.whereType<AuthRequired>(), isNotEmpty);
  });

  test('not-sent rejections keep a row coalescible', () async {
    final fake = FakeTransport();
    final rig = await TestRig.create(server: fake);
    addTearDown(rig.dispose);

    await rig.tasks.create(
      TasksCompanion.insert(
        id: 't1',
        title: 'v1',
        updatedAt: rig.clock.now(),
      ),
    );
    fake.rejectNext(
      1,
      const TransientFailure('offline', certainty: DeliveryCertainty.notSent),
    );
    await rig.sync.drain();

    await rig.tasks.patch('t1', TasksCompanion(title: const Value('v2')));
    expect((await rig.sync.diagnostics()).pending, 1);

    await rig.sync.drain();
    expect(rig.server.rowsFor('tasks').single['title'], 'v2');
  });

  test('an invalid serverRow in an ack is reported but not fatal', () async {
    final fake = FakeTransport();
    final rig = await TestRig.create(
      server: fake,
      transport: _MutatingTransport(
        fake,
        (acks, batch) => [
          for (final ack in acks) ChangeAck.applied(ack.sequence, serverRow: const {'id': 't1'}),
        ],
      ),
    );
    addTearDown(rig.dispose);
    final events = <SyncEvent>[];
    rig.sync.events.listen(events.add);

    await rig.tasks.create(
      TasksCompanion.insert(
        id: 't1',
        title: 'x',
        updatedAt: rig.clock.now(),
      ),
    );
    final report = await rig.sync.drain();
    await Future<void>.delayed(Duration.zero);

    expect(report.pushed, 1);
    expect(events.whereType<SyncRowRejected>(), isNotEmpty);
  });

  test('cancelling during the first pull page stops before the next', () async {
    final fake = FakeTransport();
    final token = SyncCancelToken();
    final rig = await TestRig.create(
      server: fake,
      transport: _PullAndCancel(fake, token),
    );
    addTearDown(rig.dispose);

    await rig.sync.pull(cancel: token);

    expect(await rig.tasks.find('t1'), isNotNull);
    expect(await rig.sync.journal.cursorFor('tasks'), const OpaqueCursor('1'));
  });

  test('a row that cannot even produce a key is rejected', () async {
    final db = TestDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final normal = tasksEntity(db);
    final fallback = SyncEntity<Tasks, Task, String>(
      table: db.tasks,
      keyColumns: const ['id'],
      keyOf: normal.keyOf,
      whereKey: normal.whereKey,
      encode: normal.encode,
      decode: normal.decode,
      keyParts: normal.keyParts,
      keyFromParts: normal.keyFromParts,
    );
    final fake = FakeTransport();
    final transport = _PullTransport(
      fake,
      (_) async => PullPage(
        rows: const [
          {'title': 'no id or decodeable fields'},
        ],
        deletedKeys: const [],
        nextCursor: const OpaqueCursor('1'),
        hasMore: false,
      ),
    );

    final sync = await UniversalSync.open<TestDatabase>(
      database: db,
      entities: <SyncEntityBase>[fallback],
      transport: transport,
      options: SyncOptions(
        clock: TestClock(DateTime.utc(2026)),
        backoff: const FixedBackoff(Duration.zero),
      ),
    );
    addTearDown(sync.dispose);
    final events = <SyncEvent>[];
    sync.events.listen(events.add);

    await sync.pull();
    await Future<void>.delayed(Duration.zero);

    expect(events.whereType<SyncRowRejected>(), isNotEmpty);
  });

  test('the cancellation option emits ChangeCancelled', () async {
    final rig = await TestRig.create(
      options: SyncOptions(
        clock: TestClock(DateTime.utc(2026)),
        backoff: const FixedBackoff(Duration.zero),
        cancelUnsyncedCreateThenDelete: true,
      ),
    );
    addTearDown(rig.dispose);
    final events = <SyncEvent>[];
    rig.sync.events.listen(events.add);

    await rig.tasks.create(
      TasksCompanion.insert(
        id: 't1',
        title: 'x',
        updatedAt: rig.clock.now(),
      ),
    );
    await rig.tasks.remove('t1');
    await Future<void>.delayed(Duration.zero);

    expect(events.whereType<ChangeCancelled>(), isNotEmpty);
    expect((await rig.sync.diagnostics()).pending, 0);
  });

  test('FakeTransport rejects an update for a missing row', () async {
    final transport = FakeTransport();
    final outcome = await transport.push(
      const PushBatch(
        entity: SyncEntityRef(table: 'tasks', primaryKey: ['id']),
        changes: [
          SyncChange(
            sequence: 1,
            kind: SyncChangeKind.update,
            idempotencyKey: 'i:1',
            key: {'id': 'missing'},
            delta: {'title': 'x'},
          ),
        ],
      ),
    );
    expect(outcome.normalizedAcks.single.status, ChangeStatus.rejected);
    expect(
      outcome.normalizedAcks.single.failure!.code,
      SyncFailureCode.permanent,
    );
  });

  test('annotation values are readable', () {
    const syncable = Syncable(
      key: #id,
      updatedAt: #updatedAt,
      owner: #userId,
      serverManagedColumns: [#updatedAt],
      dataClassName: 'Row',
      companionName: 'RowCompanion',
    );
    expect(syncable.key, #id);
    expect(syncable.updatedAt, #updatedAt);
    expect(syncable.owner, #userId);
    expect(syncable.serverManagedColumns, [#updatedAt]);
    expect(syncable.dataClassName, 'Row');
    expect(syncable.companionName, 'RowCompanion');

    const database = SyncDatabase(prefix: 'Us');
    expect(database.prefix, 'Us');
  });

  test('conflict policies render stable names', () {
    expect(const ServerWins().toString(), 'serverWins');
    expect(const ClientWins().toString(), 'clientWins');
    expect(const NewestWins().toString(), 'newestWins');
    expect(const ManualConflicts().toString(), 'manual');
  });

  test('schema and capability errors explain themselves', () {
    expect(
      const SyncSchemaTooNew(found: 2, supported: 1).toString(),
      contains('v2'),
    );
    expect(
      const SyncSchemaMismatch(
        table: 'tasks',
        missing: {'id'},
        actual: {'title'},
      ).toString(),
      contains('tasks'),
    );
    expect(
      const SyncCapabilityMismatch(
        entity: 'tasks',
        requirement: 'tombstones',
      ).toString(),
      contains('tombstones'),
    );
  });

  test('cursor edge cases', () {
    expect(const OpaqueCursor('x').toString(), contains('x'));
    expect(
      KeysetCursor(updatedAt: DateTime.utc(2026), key: const ['a']).toString(),
      contains('KeysetCursor'),
    );
    expect(
      SyncCursor.decode('{"type":"keyset","updatedAt":"2026-01-01T00:00:00Z","key":[]}'),
      isA<KeysetCursor>(),
    );
    expect(
      SyncCursor.decode('{"type":"keyset","updatedAt":"bad","key":[]}'),
      isNull,
    );
    expect(
      SyncCursor.decode('{"type":"opaque","token":5}'),
      isNull,
    );
    const empty = PullPage.empty();
    expect(empty.rows, isEmpty);
    expect(empty.deletedKeys, isEmpty);
    expect(empty.hasMore, isFalse);
  });

  test('rare events can be constructed', () {
    final now = DateTime.utc(2026);
    expect(
      ChangeCancelled(at: now, entity: 'tasks', keyJson: '["t1"]').entity,
      'tasks',
    );
    expect(
      SyncSchemaMismatchEvent(at: now, message: 'mismatch').message,
      'mismatch',
    );
  });
}
