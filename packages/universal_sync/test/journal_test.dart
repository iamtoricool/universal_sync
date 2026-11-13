import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:universal_sync/src/journal/sync_journal.dart';
import 'package:universal_sync/universal_sync.dart';

import 'support/entities.dart';
import 'support/test_db.dart';

void main() {
  late TestDatabase db;
  late SyncSchema schema;
  late TestClock clock;
  late SyncOptions options;
  late SyncJournal journal;

  setUp(() async {
    db = TestDatabase(NativeDatabase.memory());
    schema = await SyncSchema.install(db);
    clock = TestClock(DateTime.utc(2026));
    options = SyncOptions(
      clock: clock,
      backoff: const FixedBackoff(Duration.zero),
      tombstoneRetention: const Duration(days: 30),
    );
    journal = SyncJournal(
      db: db,
      schema: schema,
      options: options,
      clock: clock,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<OutboxEntry>> entries(String id) => journal.entriesForKey('tasks', [id]);

  Future<OutboxEntry> single(String id) async {
    final list = await entries(id);
    expect(list, hasLength(1));
    return list.single;
  }

  group('coalescing matrix', () {
    test('upsert + update merges the delta into the after-image', () async {
      await journal.enqueueUpsert('tasks', ['t1'], {'id': 't1', 'title': 'a'});
      final result = await journal.enqueueUpdate(
        'tasks',
        ['t1'],
        {
          'title': 'b',
        },
      );
      expect(result.coalesced, isTrue);

      final entry = await single('t1');
      expect(entry.kind, SyncChangeKind.upsert);
      expect(entry.row, {'id': 't1', 'title': 'b'});
      expect(entry.delta, isNull);
    });

    test('update + update merges deltas', () async {
      await journal.enqueueUpdate('tasks', ['t1'], {'title': 'a'});
      await journal.enqueueUpdate('tasks', ['t1'], {'done': true});

      final entry = await single('t1');
      expect(entry.kind, SyncChangeKind.update);
      expect(entry.delta, {'title': 'a', 'done': true});
    });

    test('update + upsert keeps the full after-image', () async {
      await journal.enqueueUpdate('tasks', ['t1'], {'title': 'a'});
      await journal.enqueueUpsert('tasks', ['t1'], {'id': 't1', 'title': 'b'});

      final entry = await single('t1');
      expect(entry.kind, SyncChangeKind.upsert);
      expect(entry.row, {'id': 't1', 'title': 'b'});
      expect(entry.delta, isNull);
    });

    test('upsert + upsert keeps the latest after-image', () async {
      await journal.enqueueUpsert('tasks', ['t1'], {'id': 't1', 'title': 'a'});
      await journal.enqueueUpsert('tasks', ['t1'], {'id': 't1', 'title': 'b'});

      final entry = await single('t1');
      expect(entry.row, {'id': 't1', 'title': 'b'});
    });

    test('upsert + delete becomes an idempotent delete by default', () async {
      await journal.enqueueUpsert('tasks', ['t1'], {'id': 't1'});
      await journal.enqueueDelete('tasks', ['t1']);

      final entry = await single('t1');
      expect(entry.kind, SyncChangeKind.delete);
      expect(entry.row, isNull);
    });

    test('cancellation option drops an unsent create and its tombstone', () async {
      final cancelling = SyncJournal(
        db: db,
        schema: schema,
        options: SyncOptions(
          clock: clock,
          cancelUnsyncedCreateThenDelete: true,
        ),
        clock: clock,
      );

      await cancelling.enqueueUpsert('tasks', ['t1'], {'id': 't1'});
      await cancelling.recordLocalTombstone('tasks', ['t1']);
      final result = await cancelling.enqueueDelete('tasks', ['t1']);

      expect(result.cancelled, isTrue);
      expect(await cancelling.entriesForKey('tasks', ['t1']), isEmpty);
      expect(await cancelling.tombstoneKeys('tasks', ['["t1"]']), isEmpty);
    });

    test('update + delete becomes a delete', () async {
      await journal.enqueueUpdate('tasks', ['t1'], {'title': 'a'});
      await journal.enqueueDelete('tasks', ['t1']);

      final entry = await single('t1');
      expect(entry.kind, SyncChangeKind.delete);
    });

    test('delete + upsert replaces with an upsert and clears the tombstone', () async {
      await journal.enqueueDelete('tasks', ['t1']);
      await journal.recordLocalTombstone('tasks', ['t1']);

      await journal.enqueueUpsert('tasks', ['t1'], {'id': 't1', 'title': 'a'});

      final entry = await single('t1');
      expect(entry.kind, SyncChangeKind.upsert);
      expect(await journal.tombstoneKeys('tasks', ['["t1"]']), isEmpty);
    });

    test('delete + delete stays a single delete', () async {
      await journal.enqueueDelete('tasks', ['t1']);
      await journal.enqueueDelete('tasks', ['t1']);

      final entry = await single('t1');
      expect(entry.kind, SyncChangeKind.delete);
    });
  });

  group('claim, release and recovery', () {
    test('claim leases, counts attempts and blocks newer changes per key', () async {
      await journal.enqueueUpsert('tasks', ['t1'], {'id': 't1'});
      final first = await journal.claim(
        limit: 10,
        instanceId: 'i1',
        lease: const Duration(minutes: 1),
      );
      expect(first, hasLength(1));
      expect(first.single.attempts, 1);
      expect(first.single.deliveredMaybe, isTrue);
      expect(first.single.state, 'inflight');

      await journal.enqueueUpdate('tasks', ['t1'], {'title': 'b'});
      final blocked = await journal.claim(
        limit: 10,
        instanceId: 'i2',
        lease: const Duration(minutes: 1),
      );
      expect(blocked, isEmpty);
    });

    test('different keys are claimed independently', () async {
      await journal.enqueueUpsert('tasks', ['t1'], {'id': 't1'});
      await journal.enqueueUpsert('tasks', ['t2'], {'id': 't2'});
      final claimed = await journal.claim(
        limit: 10,
        instanceId: 'i',
        lease: const Duration(minutes: 1),
      );
      expect(claimed, hasLength(2));
    });

    test('nextAttemptAt gates claiming until the clock advances', () async {
      await journal.enqueueUpsert('tasks', ['t1'], {'id': 't1'});
      final claimed = await journal.claim(
        limit: 10,
        instanceId: 'i',
        lease: const Duration(minutes: 1),
      );
      await journal.releaseMaybeApplied(
        claimed.single,
        const TransientFailure('later'),
        clock.now().add(const Duration(seconds: 5)),
        countFailure: true,
      );

      expect(
        await journal.claim(
          limit: 10,
          instanceId: 'i',
          lease: const Duration(minutes: 1),
        ),
        isEmpty,
      );

      clock.advance(const Duration(seconds: 6));
      final again = await journal.claim(
        limit: 10,
        instanceId: 'i',
        lease: const Duration(minutes: 1),
      );
      expect(again, hasLength(1));
      expect(again.single.failures, 1);
    });

    test('notSent release keeps a row coalescible when nothing is newer', () async {
      await journal.enqueueUpsert('tasks', ['t1'], {'id': 't1'});
      final claimed = await journal.claim(
        limit: 10,
        instanceId: 'i',
        lease: const Duration(minutes: 1),
      );
      final newer = await journal.releaseNotSent(
        claimed.single,
        const TransientFailure('offline', certainty: DeliveryCertainty.notSent),
        clock.now(),
      );
      expect(newer, isNull);

      await journal.enqueueUpdate('tasks', ['t1'], {'title': 'b'});
      expect(await entries('t1'), hasLength(1));
    });

    test('notSent release supersedes an undelivered row with a newer change', () async {
      await journal.enqueueUpsert('tasks', ['t1'], {'id': 't1'});
      final claimed = await journal.claim(
        limit: 10,
        instanceId: 'i',
        lease: const Duration(minutes: 1),
      );
      await journal.enqueueUpdate('tasks', ['t1'], {'title': 'b'});

      final newer = await journal.releaseNotSent(
        claimed.single,
        const TransientFailure('offline', certainty: DeliveryCertainty.notSent),
        clock.now(),
      );

      expect(newer, isNotNull);
      final list = await entries('t1');
      expect(list, hasLength(1));
      expect(list.single.sequence, newer!.sequence);
      expect(list.single.kind, SyncChangeKind.update);
    });

    test('expired leases are reclaimed, active leases are not', () async {
      await journal.enqueueUpsert('tasks', ['t1'], {'id': 't1'});
      await journal.claim(
        limit: 10,
        instanceId: 'i',
        lease: const Duration(minutes: 1),
      );

      expect(await journal.recoverLeases(), 0);
      clock.advance(const Duration(minutes: 2));
      expect(await journal.recoverLeases(), 1);
      final reclaimed = await journal.claim(
        limit: 10,
        instanceId: 'i2',
        lease: const Duration(minutes: 1),
      );
      expect(reclaimed, hasLength(1));
    });

    test('ack removes the row and supersedes older pending rows', () async {
      await journal.enqueueUpsert('tasks', ['t1'], {'id': 't1'});
      final claimed = await journal.claim(
        limit: 10,
        instanceId: 'i',
        lease: const Duration(minutes: 1),
      );
      await journal.ack(claimed.single);
      expect(await entries('t1'), isEmpty);
    });

    test('ack of an update leaves newer rows intact', () async {
      await journal.enqueueUpdate('tasks', ['t1'], {'title': 'a'});
      final claimed = await journal.claim(
        limit: 10,
        instanceId: 'i',
        lease: const Duration(minutes: 1),
      );
      await journal.enqueueUpdate('tasks', ['t1'], {'title': 'b'});
      await journal.ack(claimed.single);
      expect(await entries('t1'), hasLength(1));
    });

    test('promoteToUpsert rewrites a delta row', () async {
      await journal.enqueueUpdate('tasks', ['t1'], {'title': 'a'});
      final entry = await single('t1');
      await journal.promoteToUpsert(
        entry.sequence,
        {'id': 't1', 'title': 'full'},
      );
      final promoted = await single('t1');
      expect(promoted.kind, SyncChangeKind.upsert);
      expect(promoted.row, {'id': 't1', 'title': 'full'});
      expect(promoted.delta, isNull);
    });

    test('parking moves a change to dead letters', () async {
      await journal.enqueueUpsert('tasks', ['t1'], {'id': 't1'});
      final claimed = await journal.claim(
        limit: 10,
        instanceId: 'i',
        lease: const Duration(minutes: 1),
      );
      await journal.park(
        claimed.single,
        const PermanentFailure('validation'),
      );

      expect(await journal.countDeadLetters(), 1);
      expect(await entries('t1'), isEmpty);
      expect(
        await journal.retryParked(),
        1,
      );
      expect(await entries('t1'), hasLength(1));
    });

    test('discardParked drops dead letters', () async {
      await journal.enqueueUpsert('tasks', ['t1'], {'id': 't1'});
      final claimed = await journal.claim(
        limit: 10,
        instanceId: 'i',
        lease: const Duration(minutes: 1),
      );
      await journal.park(claimed.single, const PermanentFailure('bad'));
      expect(await journal.discardParked(), 1);
      expect(await journal.countDeadLetters(), 0);
    });
  });

  group('tombstones and cursors', () {
    test('local tombstones can be queried, acked and purged', () async {
      await journal.recordLocalTombstone('tasks', ['t1']);
      expect(await journal.tombstoneKeys('tasks', ['["t1"]']), {'["t1"]'});
      expect(await journal.tombstoneKeys('tasks', const []), isEmpty);

      await journal.markTombstoneAcked('tasks', '["t1"]');
      clock.advance(const Duration(days: 31));
      await journal.purgeTombstones();
      expect(await journal.countTombstones(), 0);
    });

    test('remote tombstones are recorded as acknowledged', () async {
      await journal.recordRemoteTombstone('tasks', ['t1']);
      expect(await journal.countTombstones(), 1);
    });

    test('cursors round-trip and reset', () async {
      expect(await journal.cursorFor('tasks'), isNull);
      await journal.setCursor('tasks', const OpaqueCursor('7'));
      expect(await journal.cursorFor('tasks'), const OpaqueCursor('7'));
      await journal.resetCursors();
      expect(await journal.cursorFor('tasks'), isNull);
    });

    test('clearTombstone removes a local deletion', () async {
      await journal.recordLocalTombstone('tasks', ['t1']);
      await journal.clearTombstone('tasks', ['t1']);
      expect(await journal.tombstoneKeys('tasks', ['["t1"]']), isEmpty);
    });
  });

  group('conflicts', () {
    Future<void> open({String local = 'local'}) => journal.openConflict(
      entity: 'tasks',
      keyParts: const ['t1'],
      local: {'id': 't1', 'title': local},
      remote: {'id': 't1', 'title': 'remote'},
      localStatus: 'pending',
    );

    test('opening twice updates the existing open conflict', () async {
      await open();
      await open(local: 'newer');
      final conflicts = await journal.listConflicts();
      expect(conflicts, hasLength(1));
      expect(conflicts.single.local, {'id': 't1', 'title': 'newer'});
      expect(await journal.countConflicts(), 1);
    });

    test('conflicts can be fetched by id and resolved', () async {
      await open();
      final record = (await journal.listConflicts()).single;
      expect(await journal.conflictById(record.id), isNotNull);
      expect(await journal.conflictById(-1), isNull);

      await journal.resolveConflictRow(record.id);
      expect(await journal.listConflicts(), isEmpty);
      expect(await journal.countConflicts(), 0);
    });

    test('a conflict with no local row stores null', () async {
      await journal.openConflict(
        entity: 'tasks',
        keyParts: const ['t2'],
        local: null,
        remote: {'id': 't2'},
        localStatus: 'absent',
      );
      expect((await journal.listConflicts()).single.local, isNull);
    });
  });

  group('maintenance and diagnostics', () {
    test('purgeAll clears state but keeps the install id', () async {
      final before = await schema.metaValue('install_id');
      await journal.enqueueUpsert('tasks', ['t1'], {'id': 't1'});
      await journal.recordLocalTombstone('tasks', ['t1']);
      await journal.setCursor('tasks', const OpaqueCursor('1'));

      await journal.purgeAll();

      expect(await journal.countOutbox('pending'), 0);
      expect(await journal.countTombstones(), 0);
      expect(await schema.metaValue('install_id'), before);
    });

    test('counts and byte estimates are correct on an empty and full queue', () async {
      expect(await journal.countOutbox('pending'), 0);
      expect(await journal.outboxBytes(), 0);

      await journal.enqueueUpsert('tasks', ['t1'], {'id': 't1', 'title': 'a'});
      expect(await journal.countOutbox('pending'), 1);
      expect(await journal.outboxBytes(), greaterThan(0));
      expect(await journal.countConflicts(), 0);
    });

    test('nextPendingForKey can look past a sequence', () async {
      await journal.enqueueUpsert('tasks', ['t1'], {'id': 't1'});
      final first = await single('t1');
      await journal.claim(
        limit: 10,
        instanceId: 'i',
        lease: const Duration(minutes: 1),
      );
      expect(
        await journal.nextPendingForKey('tasks', first.keyHash),
        isNull,
      );
    });
  });

  test('entry conversion builds the wire key from the entity ref', () async {
    final entity = tasksEntity(db);
    await journal.enqueueDelete('tasks', ['t1']);
    final entry = await single('t1');
    final change = entry.toChange('install', entity.ref);
    expect(change.idempotencyKey, 'install:${entry.sequence}');
    expect(change.key, {'id': 't1'});
    expect(change.kind, SyncChangeKind.delete);
  });
}
