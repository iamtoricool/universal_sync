import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:test/test.dart';
import 'package:universal_sync/testing.dart';
import 'package:universal_sync/universal_sync.dart';

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

final class _ThrowingTransport extends SyncTransport {
  _ThrowingTransport(this.inner, this.error);

  final SyncTransport inner;
  final Object error;

  @override
  SyncTransportCapabilities get capabilities => inner.capabilities;

  @override
  Future<PushOutcome> push(PushBatch batch) async => throw error;

  @override
  Future<PullPage> pull(PullPageRequest request) => inner.pull(request);
}

void main() {
  group('ack contract', () {
    test('applied ack without serverRow is a contract violation', () async {
      final fake = FakeTransport()..omitServerRow = true;
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
      await rig.sync.drain();
      await Future<void>.delayed(Duration.zero);

      expect((await rig.sync.diagnostics()).pending, 1);
      expect(events.whereType<TransportContractViolation>(), isNotEmpty);
    });

    test('duplicate acks are a contract violation', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(
        server: fake,
        transport: _MutatingTransport(
          fake,
          (acks, batch) => [...acks, ...acks],
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
      await rig.sync.drain();
      await Future<void>.delayed(Duration.zero);

      expect((await rig.sync.diagnostics()).pending, 1);
      expect(events.whereType<TransportContractViolation>(), isNotEmpty);
    });

    test('acks for unknown sequences are a contract violation', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(
        server: fake,
        transport: _MutatingTransport(
          fake,
          (acks, batch) => [...acks, const ChangeAck.applied(9999)],
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
      await rig.sync.drain();

      expect((await rig.sync.diagnostics()).pending, 1);
    });

    test('rejected ack without a failure is a contract violation', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(
        server: fake,
        transport: _MutatingTransport(
          fake,
          (acks, batch) => [
            for (final ack in acks) ChangeAck(sequence: ack.sequence, status: ChangeStatus.rejected),
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
      await rig.sync.drain();
      await Future<void>.delayed(Duration.zero);

      expect((await rig.sync.diagnostics()).pending, 1);
      expect(events.whereType<TransportContractViolation>(), isNotEmpty);
    });
  });

  group('retry scheduling', () {
    test('rate limits honour retryAfter', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(server: fake);
      addTearDown(rig.dispose);

      await rig.tasks.create(
        TasksCompanion.insert(
          id: 't1',
          title: 'x',
          updatedAt: rig.clock.now(),
        ),
      );
      fake.rejectNext(1, const RateLimited('slow', retryAfter: Duration(seconds: 30)));
      await rig.sync.drain();

      final entry = (await rig.sync.journal.entriesForKey('tasks', ['t1'])).single;
      expect(
        entry.nextAttemptAt,
        rig.clock.now().add(const Duration(seconds: 30)),
      );

      expect(
        await rig.sync.journal.claim(
          limit: 10,
          instanceId: 'test',
          lease: const Duration(minutes: 1),
        ),
        isEmpty,
      );

      rig.clock.advance(const Duration(seconds: 31));
      expect(
        await rig.sync.journal.claim(
          limit: 10,
          instanceId: 'test',
          lease: const Duration(minutes: 1),
        ),
        hasLength(1),
      );
    });

    test('revision conflicts accept the server row', () async {
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
      fake.rejectNext(
        1,
        RevisionConflict('conflict', serverRow: taskRow('t1', 'server')),
      );

      final report = await rig.sync.drain();

      expect(report.pushed, 1);
      expect((await rig.tasks.find('t1'))!.title, 'server');
      expect((await rig.sync.diagnostics()).pending, 0);
    });

    test('revision conflicts without a server row still converge', () async {
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
      fake.rejectNext(1, const RevisionConflict('conflict'));

      await rig.sync.drain();
      expect((await rig.sync.diagnostics()).pending, 0);
    });

    test('non-SyncFailure transport errors are treated as transient', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(
        server: fake,
        transport: _ThrowingTransport(fake, StateError('socket exploded')),
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
      await rig.sync.drain();
      await Future<void>.delayed(Duration.zero);

      expect((await rig.sync.diagnostics()).pending, 1);
      expect(events.whereType<OfflineDetected>(), isNotEmpty);
    });

    test('maxAttempts is consumed across drains before parking', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(
        server: fake,
        options: SyncOptions(
          clock: TestClock(DateTime.utc(2026)),
          backoff: const FixedBackoff(Duration.zero),
          maxAttempts: 2,
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

      fake.rejectNext(1, const PermanentFailure('bad'));
      await rig.sync.drain();
      expect((await rig.sync.diagnostics()).parked, 0);
      expect((await rig.sync.diagnostics()).pending, 1);

      fake.rejectNext(1, const PermanentFailure('bad'));
      await rig.sync.drain();
      expect((await rig.sync.diagnostics()).parked, 1);
    });
  });

  group('promotion', () {
    test('a parked change promotes the next pending delta to upsert', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(
        server: fake,
        options: SyncOptions(
          clock: TestClock(DateTime.utc(2026)),
          backoff: const FixedBackoff(Duration.zero),
          maxAttempts: 1,
        ),
      );
      addTearDown(rig.dispose);

      await rig.tasks.create(
        TasksCompanion.insert(
          id: 't1',
          title: 'v1',
          updatedAt: rig.clock.now(),
        ),
      );
      fake.failNextPush(const TransientFailure('timeout'));
      await rig.sync.drain();

      await rig.tasks.patch('t1', TasksCompanion(title: const Value('v2')));
      fake.rejectNext(1, const PermanentFailure('bad'));
      await rig.sync.drain();

      final entries = await rig.sync.journal.entriesForKey('tasks', ['t1']);
      expect(entries, hasLength(1));
      expect(entries.single.kind, SyncChangeKind.upsert);
      expect(entries.single.row!['title'], 'v2');
    });

    test('a dependent delta is parked when the local row is gone', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(
        server: fake,
        options: SyncOptions(
          clock: TestClock(DateTime.utc(2026)),
          backoff: const FixedBackoff(Duration.zero),
          maxAttempts: 1,
        ),
      );
      addTearDown(rig.dispose);

      await rig.tasks.create(
        TasksCompanion.insert(
          id: 't1',
          title: 'v1',
          updatedAt: rig.clock.now(),
        ),
      );
      fake.failNextPush(const TransientFailure('timeout'));
      await rig.sync.drain();

      await rig.tasks.patch('t1', TasksCompanion(title: const Value('v2')));
      await rig.db.delete(rig.db.tasks).go();

      fake.rejectNext(1, const PermanentFailure('bad'));
      await rig.sync.drain();

      expect((await rig.sync.diagnostics()).parked, 2);
      expect(await rig.sync.journal.entriesForKey('tasks', ['t1']), isEmpty);
    });
  });

  group('batching and budgets', () {
    test('maxBatchBytes splits a push into several requests', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(
        server: fake,
        options: SyncOptions(
          clock: TestClock(DateTime.utc(2026)),
          backoff: const FixedBackoff(Duration.zero),
          maxBatchBytes: 20,
        ),
      );
      addTearDown(rig.dispose);

      for (var i = 0; i < 3; i++) {
        await rig.tasks.create(
          TasksCompanion.insert(
            id: 't$i',
            title: 'title that is long enough to force chunking',
            updatedAt: rig.clock.now(),
          ),
        );
      }

      final report = await rig.sync.drain();
      expect(report.pushed, 3);
      expect(fake.pushedBatches.length, greaterThan(1));
    });

    test('maxDrainIterations bounds a single drain call', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(
        server: fake,
        options: SyncOptions(
          clock: TestClock(DateTime.utc(2026)),
          backoff: const FixedBackoff(Duration.zero),
          pushBatchSize: 1,
          maxDrainIterations: 1,
        ),
      );
      addTearDown(rig.dispose);

      for (var i = 0; i < 2; i++) {
        await rig.tasks.create(
          TasksCompanion.insert(
            id: 't$i',
            title: 'x',
            updatedAt: rig.clock.now(),
          ),
        );
      }

      expect((await rig.sync.drain()).pushed, 1);
      expect((await rig.sync.diagnostics()).pending, 1);
      expect((await rig.sync.drain()).pushed, 1);
    });

    test('outbox pressure is reported without dropping changes', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(
        server: fake,
        options: SyncOptions(
          clock: TestClock(DateTime.utc(2026)),
          backoff: const FixedBackoff(Duration.zero),
          maxOutboxBytes: 0,
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
      fake.failNextPush(const TransientFailure('offline'));
      await rig.sync.drain();
      await Future<void>.delayed(Duration.zero);

      expect(events.whereType<OutboxPressure>(), isNotEmpty);
      expect((await rig.sync.diagnostics()).pending, 1);
    });
  });

  group('single-flight and lifecycle', () {
    test('concurrent drain calls share one future', () async {
      final fake = FakeTransport(latency: const Duration(milliseconds: 20));
      final rig = await TestRig.create(server: fake);
      addTearDown(rig.dispose);

      await rig.tasks.create(
        TasksCompanion.insert(
          id: 't1',
          title: 'x',
          updatedAt: rig.clock.now(),
        ),
      );

      final first = rig.sync.drain();
      final second = rig.sync.drain();
      expect(identical(first, second), isTrue);
      await first;
      expect((await rig.sync.diagnostics()).pending, 0);
    });

    test('a cancelled drain leaves the outbox untouched', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(server: fake);
      addTearDown(rig.dispose);

      await rig.tasks.create(
        TasksCompanion.insert(
          id: 't1',
          title: 'x',
          updatedAt: rig.clock.now(),
        ),
      );
      final token = SyncCancelToken()..cancel();
      final report = await rig.sync.drain(cancel: token);

      expect(report.pushed, 0);
      expect((await rig.sync.diagnostics()).pending, 1);
    });

    test('syncNow can run push and pull independently', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(server: fake);
      addTearDown(rig.dispose);

      await rig.tasks.create(
        TasksCompanion.insert(
          id: 't1',
          title: 'x',
          updatedAt: rig.clock.now(),
        ),
      );
      await rig.sync.syncNow(push: false, pull: true);
      expect((await rig.sync.diagnostics()).pending, 1);

      await rig.sync.syncNow(push: true, pull: false);
      expect((await rig.sync.diagnostics()).pending, 0);
    });

    test('status stream reports draining and idle', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(server: fake);
      addTearDown(rig.dispose);
      final statuses = <SyncStatus>[];
      rig.sync.statusStream.listen(statuses.add);

      await rig.tasks.create(
        TasksCompanion.insert(
          id: 't1',
          title: 'x',
          updatedAt: rig.clock.now(),
        ),
      );
      await rig.sync.drain();
      await Future<void>.delayed(Duration.zero);

      expect(statuses, contains(SyncStatus.draining));
      expect(statuses, contains(SyncStatus.idle));
    });

    test('dispose returns leased rows to pending', () async {
      final fake = FakeTransport();
      final rig = await TestRig.create(server: fake);
      addTearDown(rig.db.close);

      await rig.tasks.create(
        TasksCompanion.insert(
          id: 't1',
          title: 'x',
          updatedAt: rig.clock.now(),
        ),
      );
      await rig.sync.journal.claim(
        limit: 10,
        instanceId: 'test',
        lease: const Duration(minutes: 5),
      );
      expect(
        (await rig.sync.journal.entriesForKey('tasks', ['t1'])).single.state,
        'inflight',
      );

      await rig.sync.dispose();

      final entry = (await rig.sync.journal.entriesForKey('tasks', ['t1'])).single;
      expect(entry.state, 'pending');
    });
  });
}
