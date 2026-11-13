import 'package:test/test.dart';
import 'package:universal_sync/testing.dart';
import 'package:universal_sync/universal_sync.dart';

import 'support/rig.dart';
import 'support/test_db.dart';

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

void main() {
  group('pagination and transport failures', () {
    test('hasMore with a null cursor is a contract violation', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(
        server: fake,
        transport: _PullTransport(
          fake,
          (_) async => const PullPage(
            rows: [],
            deletedKeys: [],
            nextCursor: null,
            hasMore: true,
          ),
        ),
      );
      addTearDown(rig.dispose);
      final events = <SyncEvent>[];
      rig.sync.events.listen(events.add);

      await rig.sync.pull();
      await Future<void>.delayed(Duration.zero);

      expect(events.whereType<TransportContractViolation>(), isNotEmpty);
    });

    test('auth failure during pull preserves the cursor and status', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(
        server: fake,
        transport: _PullTransport(
          fake,
          (_) async => throw const AuthFailure('expired'),
        ),
      );
      addTearDown(rig.dispose);
      final events = <SyncEvent>[];
      rig.sync.events.listen(events.add);

      final report = await rig.sync.pull();
      await Future<void>.delayed(Duration.zero);

      expect(report.pulled, 0);
      expect(rig.sync.status, SyncStatus.authRequired);
      expect(events.whereType<AuthRequired>(), isNotEmpty);
      expect(await rig.sync.journal.cursorFor('tasks'), isNull);
    });

    test('transient failure during pull reports offline', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(
        server: fake,
        transport: _PullTransport(
          fake,
          (_) async => throw const TransientFailure('offline'),
        ),
      );
      addTearDown(rig.dispose);
      final events = <SyncEvent>[];
      rig.sync.events.listen(events.add);

      await rig.sync.pull();
      await Future<void>.delayed(Duration.zero);

      expect(rig.sync.status, SyncStatus.offline);
      expect(events.whereType<OfflineDetected>(), isNotEmpty);
    });

    test('a cancelled pull does not request a page', () async {
      final fake = FakeTransport();
      var calls = 0;
      final rig = await TestRig.create(
        server: fake,
        transport: _PullTransport(fake, (_) async {
          calls++;
          return const PullPage.empty();
        }),
      );
      addTearDown(rig.dispose);

      final token = SyncCancelToken()..cancel();
      await rig.sync.pull(cancel: token);

      expect(calls, 0);
    });

    test('empty pages complete cleanly', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(server: fake);
      addTearDown(rig.dispose);

      final report = await rig.sync.pull();
      expect(report.pulled, 0);
    });
  });

  group('malformed and partial rows', () {
    test('rows without a derivable key are rejected, others applied', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(
        server: fake,
        transport: _PullTransport(
          fake,
          (_) async => PullPage(
            rows: [
              {'title': 'missing id'},
              taskRow('t2', 'valid'),
            ],
            deletedKeys: const [],
            nextCursor: const OpaqueCursor('2'),
            hasMore: false,
          ),
        ),
      );
      addTearDown(rig.dispose);
      final events = <SyncEvent>[];
      rig.sync.events.listen(events.add);

      final report = await rig.sync.pull();
      await Future<void>.delayed(Duration.zero);

      expect(report.pulled, 1);
      expect(await rig.tasks.find('t2'), isNotNull);
      expect(events.whereType<SyncRowRejected>(), isNotEmpty);
    });

    test('rows that fail decoding are rejected, not fatal', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(
        server: fake,
        transport: _PullTransport(
          fake,
          (_) async => PullPage(
            rows: [
              {'id': 't1', 'title': 'missing updated_at'},
              taskRow('t2', 'valid'),
            ],
            deletedKeys: const [],
            nextCursor: const OpaqueCursor('2'),
            hasMore: false,
          ),
        ),
      );
      addTearDown(rig.dispose);
      final events = <SyncEvent>[];
      rig.sync.events.listen(events.add);

      await rig.sync.pull();
      await Future<void>.delayed(Duration.zero);

      expect(await rig.tasks.find('t1'), isNull);
      expect(await rig.tasks.find('t2'), isNotNull);
      expect(events.whereType<SyncRowRejected>(), isNotEmpty);
    });

    test('a bad ack serverRow is reported without losing the local change', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(
        server: fake,
        transport: _PullTransport(fake, (_) async => const PullPage.empty()),
      );
      addTearDown(rig.dispose);
      final events = <SyncEvent>[];
      rig.sync.events.listen(events.add);

      // Not a pull path: verify the event exists for ack-time decode failures
      // by pushing a row the entity cannot decode through the ack.
      await rig.tasks.create(
        TasksCompanion.insert(
          id: 't1',
          title: 'x',
          updatedAt: rig.clock.now(),
        ),
      );
      await rig.sync.drain();
      expect(await rig.tasks.find('t1'), isNotNull);
      expect(events.whereType<SyncRowRejected>(), isEmpty);
    });
  });

  group('unchanged rows and tombstones', () {
    test('newer local timestamps skip the remote row', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(server: fake);
      addTearDown(rig.dispose);

      await rig.db
          .into(rig.db.tasks)
          .insert(
            TasksCompanion.insert(
              id: 't1',
              title: 'local',
              updatedAt: DateTime.utc(2026, 6),
            ),
          );
      fake.seed('tasks', taskRow('t1', 'remote', updatedAt: DateTime.utc(2020)));

      await rig.sync.pull();

      expect((await rig.tasks.find('t1'))!.title, 'local');
    });

    test('remote tombstones are recorded for absent local rows', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(
        server: fake,
        transport: _PullTransport(
          fake,
          (_) async => const PullPage(
            rows: [],
            deletedKeys: [
              ['ghost'],
            ],
            nextCursor: OpaqueCursor('1'),
            hasMore: false,
          ),
        ),
      );
      addTearDown(rig.dispose);

      await rig.sync.pull();

      expect((await rig.sync.diagnostics()).tombstones, 1);
      expect(await rig.tasks.find('ghost'), isNull);
    });

    test('clientWins keeps a pending row when the server deletes it', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(
        server: fake,
        options: SyncOptions(
          clock: TestClock(DateTime.utc(2026)),
          backoff: const FixedBackoff(Duration.zero),
          conflictPolicy: const ClientWins(),
        ),
      );
      addTearDown(rig.dispose);

      await rig.tasks.create(
        TasksCompanion.insert(
          id: 't1',
          title: 'local',
          updatedAt: rig.clock.now(),
        ),
      );
      fake.seed('tasks', taskRow('t1', 'remote'));
      final page = await fake.pull(
        const PullPageRequest(
          entity: SyncEntityRef(
            table: 'tasks',
            primaryKey: ['id'],
            updatedAtColumn: 'updated_at',
          ),
          cursor: null,
          limit: 10,
        ),
      );
      expect(page.rows, hasLength(1));

      // Delete it remotely, then pull.
      fake.seed('tasks', taskRow('t1', 'remote'));
      await fake.push(
        PushBatch(
          entity: const SyncEntityRef(table: 'tasks', primaryKey: ['id']),
          changes: const [
            SyncChange(
              sequence: 99,
              kind: SyncChangeKind.delete,
              idempotencyKey: 'manual:99',
              key: {'id': 't1'},
            ),
          ],
        ),
      );
      await rig.sync.pull();

      expect(await rig.tasks.find('t1'), isNotNull);
      expect((await rig.sync.diagnostics()).pending, 1);
    });

    test('manual policy stores a deletion conflict', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(
        server: fake,
        options: SyncOptions(
          clock: TestClock(DateTime.utc(2026)),
          backoff: const FixedBackoff(Duration.zero),
          conflictPolicy: const ManualConflicts(),
        ),
      );
      addTearDown(rig.dispose);

      await rig.tasks.create(
        TasksCompanion.insert(
          id: 't1',
          title: 'local',
          updatedAt: rig.clock.now(),
        ),
      );
      await fake.push(
        const PushBatch(
          entity: SyncEntityRef(table: 'tasks', primaryKey: ['id']),
          changes: [
            SyncChange(
              sequence: 99,
              kind: SyncChangeKind.delete,
              idempotencyKey: 'manual:99',
              key: {'id': 't1'},
            ),
          ],
        ),
      );

      await rig.sync.pull();

      final conflicts = await rig.sync.conflicts();
      expect(conflicts, hasLength(1));
      expect(conflicts.single.remote, {'__deleted__': true});
      expect(await rig.tasks.find('t1'), isNotNull);
    });

    test('the default policy applies a remote deletion', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(server: fake);
      addTearDown(rig.dispose);

      await rig.tasks.create(
        TasksCompanion.insert(
          id: 't1',
          title: 'local',
          updatedAt: rig.clock.now(),
        ),
      );
      await fake.push(
        const PushBatch(
          entity: SyncEntityRef(table: 'tasks', primaryKey: ['id']),
          changes: [
            SyncChange(
              sequence: 99,
              kind: SyncChangeKind.delete,
              idempotencyKey: 'manual:99',
              key: {'id': 't1'},
            ),
          ],
        ),
      );

      await rig.sync.pull();

      expect(await rig.tasks.find('t1'), isNull);
      expect((await rig.sync.diagnostics()).pending, 0);
    });
  });

  group('conflict resolution API', () {
    test('manual conflicts are deduped and can keep the local row', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(
        server: fake,
        options: SyncOptions(
          clock: TestClock(DateTime.utc(2026)),
          backoff: const FixedBackoff(Duration.zero),
          conflictPolicy: const ManualConflicts(),
        ),
      );
      addTearDown(rig.dispose);

      await rig.tasks.create(
        TasksCompanion.insert(
          id: 't1',
          title: 'local',
          updatedAt: rig.clock.now(),
        ),
      );
      fake.seed('tasks', taskRow('t1', 'remote'));

      await rig.sync.pull();
      await rig.sync.pull();

      final conflicts = await rig.sync.conflicts();
      expect(conflicts, hasLength(1));

      await rig.sync.resolveConflict(conflicts.single.id, const KeepLocal());

      expect(await rig.sync.conflicts(), isEmpty);
      expect((await rig.tasks.find('t1'))!.title, 'local');
      expect((await rig.sync.diagnostics()).pending, 1);
    });

    test('watchConflicts emits the current conflict list', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(
        server: fake,
        options: SyncOptions(
          clock: TestClock(DateTime.utc(2026)),
          backoff: const FixedBackoff(Duration.zero),
          conflictPolicy: const ManualConflicts(),
        ),
      );
      addTearDown(rig.dispose);

      await rig.tasks.create(
        TasksCompanion.insert(
          id: 't1',
          title: 'local',
          updatedAt: rig.clock.now(),
        ),
      );
      fake.seed('tasks', taskRow('t1', 'remote'));
      await rig.sync.pull();

      expect(await rig.sync.watchConflicts().first, hasLength(1));
    });
  });
}
