import 'dart:async';

import 'package:test/test.dart';
import 'package:universal_sync/universal_sync.dart';

import 'support/rig.dart';
import 'support/test_db.dart';

final class _MutableSession implements SyncSession {
  _MutableSession(this._userId);

  final StreamController<String?> _controller = StreamController<String?>.broadcast();
  String? _userId;

  @override
  String? get userId => _userId;

  @override
  Stream<String?> get userIdChanges => _controller.stream;

  void switchTo(String? id) {
    _userId = id;
    _controller.add(id);
  }

  Future<void> close() => _controller.close();
}

Future<void> legacyTask(TestDatabase db) => db
    .into(db.tasks)
    .insert(
      TasksCompanion.insert(
        id: 'legacy',
        title: 'existing',
        updatedAt: DateTime.utc(2025),
      ),
    );

void main() {
  test('SkipBootstrap marks the first run done exactly once', () async {
    final rig = await TestRig.create(bootstrap: const SkipBootstrap());
    addTearDown(rig.dispose);

    expect((await rig.sync.bootstrap()).pushed, 0);
    expect(await rig.sync.schema.metaValue('bootstrap_done'), '1');
    expect((await rig.sync.bootstrap()).coalesced, 0);
  });

  test('UploadLocal queues existing rows and pushes them', () async {
    final rig = await TestRig.create(
      bootstrap: const UploadLocal(),
      prepare: legacyTask,
    );
    addTearDown(rig.dispose);

    final bootstrapReport = await rig.sync.bootstrap();
    expect(bootstrapReport.coalesced, 1);
    expect((await rig.sync.diagnostics()).pending, 1);

    await rig.sync.drain();
    expect(rig.server.rowsFor('tasks').single['id'], 'legacy');
  });

  test('MergeByUpdatedAt uses the same upload path', () async {
    final rig = await TestRig.create(
      bootstrap: const MergeByUpdatedAt(),
      prepare: legacyTask,
    );
    addTearDown(rig.dispose);

    final report = await rig.sync.syncNow(push: true, pull: true);

    expect(report.pushed, 1);
    expect(rig.server.rowsFor('tasks').single['id'], 'legacy');
  });

  test('ServerWinsBootstrap resets existing cursors', () async {
    final rig = await TestRig.create(bootstrap: const ServerWinsBootstrap());
    addTearDown(rig.dispose);
    await rig.sync.journal.setCursor('tasks', const OpaqueCursor('42'));

    await rig.sync.bootstrap();

    expect(await rig.sync.journal.cursorFor('tasks'), isNull);
    expect(await rig.sync.schema.metaValue('bootstrap_done'), '1');
  });

  test('syncNow runs bootstrap once then syncs', () async {
    final rig = await TestRig.create(
      bootstrap: const UploadLocal(),
      prepare: legacyTask,
    );
    addTearDown(rig.dispose);

    await rig.sync.syncNow(push: true, pull: true);
    await rig.sync.syncNow(push: true, pull: true);

    expect(rig.server.rowsFor('tasks'), hasLength(1));
    expect(rig.server.pushedSequences, hasLength(1));
  });

  test('user changes purge sync state when configured', () async {
    final session = _MutableSession('u1');
    addTearDown(session.close);
    final rig = await TestRig.create(session: session);
    addTearDown(rig.dispose);

    await rig.tasks.create(
      TasksCompanion.insert(
        id: 't1',
        title: 'x',
        updatedAt: rig.clock.now(),
      ),
    );
    expect((await rig.sync.diagnostics()).pending, 1);

    session.switchTo('u2');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect((await rig.sync.diagnostics()).pending, 0);
    // purge() does not delete local data unless asked to.
    expect(await rig.tasks.find('t1'), isNotNull);
  });

  test('user changes keep state when purging is disabled', () async {
    final session = _MutableSession('u1');
    addTearDown(session.close);
    final rig = await TestRig.create(
      session: session,
      options: SyncOptions(
        clock: TestClock(DateTime.utc(2026)),
        backoff: const FixedBackoff(Duration.zero),
        purgeOnUserChange: false,
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
    session.switchTo('u2');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect((await rig.sync.diagnostics()).pending, 1);
  });

  test('discardParked drops engine dead letters', () async {
    final rig = await TestRig.create(
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
        title: 'x',
        updatedAt: rig.clock.now(),
      ),
    );
    rig.server.rejectNext(1, const PermanentFailure('bad'));
    await rig.sync.drain();
    expect((await rig.sync.diagnostics()).parked, 1);

    expect(await rig.sync.discardParked(), 1);
    expect((await rig.sync.diagnostics()).parked, 0);
  });
}
