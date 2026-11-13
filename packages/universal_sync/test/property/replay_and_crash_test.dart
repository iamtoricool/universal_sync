import 'package:test/test.dart';
import 'package:universal_sync/testing.dart';
import 'package:universal_sync/universal_sync.dart';

import '../support/entities.dart';
import '../support/rig.dart';
import '../support/test_db.dart';

final class _FlakyPullTransport extends SyncTransport {
  _FlakyPullTransport(this.inner, this.pages);

  final SyncTransport inner;
  final List<PullPage> pages;
  int calls = 0;

  @override
  SyncTransportCapabilities get capabilities => inner.capabilities;

  @override
  Future<PushOutcome> push(PushBatch batch) => inner.push(batch);

  @override
  Future<PullPage> pull(PullPageRequest request) async {
    calls++;
    if (calls == 2) throw const TransientFailure('connection dropped');
    return pages[(calls - 1).clamp(0, pages.length - 1)];
  }
}

void main() {
  test('a lost ack replays idempotently', () async {
    final rig = await TestRig.create();
    addTearDown(rig.dispose);

    await rig.tasks.create(
      TasksCompanion.insert(
        id: 't1',
        title: 'v1',
        updatedAt: rig.clock.now(),
      ),
    );
    rig.server.dropLastAck = true;
    await rig.sync.drain();
    expect((await rig.sync.diagnostics()).pending, 1);

    rig.server.dropLastAck = false;
    await rig.sync.drain();

    expect(rig.server.rowsFor('tasks'), hasLength(1));
    expect(rig.server.rowsFor('tasks').single['title'], 'v1');
    expect((await rig.sync.diagnostics()).pending, 0);
  });

  test('a crash between pages resumes from the committed cursor', () async {
    final fake = FakeTransport();
    final rig = await TestRig.create(
      server: fake,
      transport: _FlakyPullTransport(fake, [
        PullPage(
          rows: [taskRow('t1', 'one')],
          deletedKeys: const [],
          nextCursor: const OpaqueCursor('1'),
          hasMore: true,
        ),
        PullPage(
          rows: [taskRow('t2', 'two')],
          deletedKeys: const [],
          nextCursor: const OpaqueCursor('2'),
          hasMore: false,
        ),
      ]),
    );
    addTearDown(rig.dispose);

    await rig.sync.pull();
    expect(await rig.tasks.find('t1'), isNotNull);
    expect(await rig.tasks.find('t2'), isNull);
    expect(
      await rig.sync.journal.cursorFor('tasks'),
      const OpaqueCursor('1'),
    );

    await rig.sync.pull();
    expect(await rig.tasks.find('t2'), isNotNull);
    expect(await rig.tasks.find('t1'), isNotNull);
  });

  test('a new engine recovers an expired lease and pushes exactly once', () async {
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
      instanceId: 'crashed',
      lease: const Duration(minutes: 1),
    );
    rig.clock.advance(const Duration(minutes: 2));

    final restarted = await UniversalSync.open<TestDatabase>(
      database: rig.db,
      entities: <SyncEntityBase>[tasksEntity(rig.db)],
      transport: fake,
      options: SyncOptions(
        clock: rig.clock,
        backoff: const FixedBackoff(Duration.zero),
      ),
    );
    addTearDown(restarted.dispose);

    await restarted.drain();

    expect(fake.rowsFor('tasks'), hasLength(1));
    expect(fake.pushedSequences, hasLength(1));
    expect((await restarted.diagnostics()).pending, 0);
  });
}
