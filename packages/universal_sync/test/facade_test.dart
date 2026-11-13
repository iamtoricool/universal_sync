import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
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

void main() {
  group('typed write facade', () {
    test('save inserts and upserts', () async {
      final rig = await TestRig.create();
      addTearDown(rig.dispose);

      final first = await rig.tasks.save(
        TasksCompanion.insert(
          id: 't1',
          title: 'a',
          updatedAt: rig.clock.now(),
        ),
      );
      expect(first.title, 'a');

      final second = await rig.tasks.save(
        TasksCompanion.insert(
          id: 't1',
          title: 'b',
          updatedAt: rig.clock.now(),
        ),
      );
      expect(second.title, 'b');
      expect(await rig.tasks.query().get(), hasLength(1));
      expect((await rig.sync.diagnostics()).pending, 1);
    });

    test('saveAll and removeMany batch through one transaction', () async {
      final rig = await TestRig.create();
      addTearDown(rig.dispose);

      final written = await rig.tasks.saveAll([
        for (var i = 0; i < 3; i++)
          TasksCompanion.insert(
            id: 't$i',
            title: 'title $i',
            updatedAt: rig.clock.now(),
          ),
      ]);
      expect(written, 3);
      expect(await rig.tasks.query().get(), hasLength(3));

      final removed = await rig.tasks.removeMany(['t0', 't1', 'missing']);
      expect(removed, 2);
      expect(await rig.tasks.query().get(), hasLength(1));
    });

    test('remove returns false when nothing was deleted', () async {
      final rig = await TestRig.create();
      addTearDown(rig.dispose);
      expect(await rig.tasks.remove('missing'), isFalse);
      expect((await rig.sync.diagnostics()).pending, 1);
    });

    test('find, query and watch observe local writes', () async {
      final rig = await TestRig.create();
      addTearDown(rig.dispose);

      expect(await rig.tasks.find('t1'), isNull);
      await rig.tasks.create(
        TasksCompanion.insert(
          id: 't1',
          title: 'a',
          updatedAt: rig.clock.now(),
        ),
      );

      expect((await rig.tasks.find('t1'))!.title, 'a');
      expect(await rig.tasks.watch().first, hasLength(1));
      final filtered = await (rig.tasks.query()..where((t) => t.title.equals('a'))).get();
      expect(filtered, hasLength(1));
    });

    test('markDirty queues upsert, update and delete for DAO writes', () async {
      final rig = await TestRig.create();
      addTearDown(rig.dispose);

      await rig.db
          .into(rig.db.tasks)
          .insert(
            TasksCompanion.insert(
              id: 't1',
              title: 'dao',
              updatedAt: rig.clock.now(),
            ),
          );
      await rig.tasks.markDirty('t1', kind: SyncChangeKind.upsert);
      expect((await rig.sync.diagnostics()).pending, 1);

      await rig.tasks.patch('t1', TasksCompanion(title: const Value('v2')));
      await rig.db
          .into(rig.db.tasks)
          .insertOnConflictUpdate(
            TasksCompanion.insert(
              id: 't1',
              title: 'v3',
              updatedAt: rig.clock.now(),
            ),
          );
      await rig.tasks.markDirty('t1', kind: SyncChangeKind.update);
      expect((await rig.sync.diagnostics()).pending, 1);

      await rig.db.delete(rig.db.tasks).go();
      await rig.tasks.markDirty('t1', kind: SyncChangeKind.delete);
      expect((await rig.sync.diagnostics()).tombstones, 1);

      await rig.sync.drain();
      expect(rig.server.rowsFor('tasks'), isEmpty);
    });

    test('markDirty asserts when the local row is missing', () async {
      final rig = await TestRig.create();
      addTearDown(rig.dispose);
      await expectLater(
        rig.tasks.markDirty('missing', kind: SyncChangeKind.upsert),
        throwsA(isA<AssertionError>()),
      );
    });

    test('patch stamps updatedAt only when absent', () async {
      final rig = await TestRig.create();
      addTearDown(rig.dispose);
      await rig.tasks.create(
        TasksCompanion.insert(
          id: 't1',
          title: 'a',
          updatedAt: DateTime.utc(2020),
        ),
      );

      await rig.tasks.patch('t1', TasksCompanion(title: const Value('stamped')));
      expect(
        (await rig.tasks.find('t1'))!.updatedAt.millisecondsSinceEpoch,
        rig.clock.now().millisecondsSinceEpoch,
      );

      await rig.tasks.patch(
        't1',
        TasksCompanion(updatedAt: Value(DateTime.utc(2030))),
      );
      expect(
        (await rig.tasks.find('t1'))!.updatedAt.millisecondsSinceEpoch,
        DateTime.utc(2030).millisecondsSinceEpoch,
      );
    });

    test('owner autofill and ownership rejection', () async {
      final session = _MutableSession('u1');
      addTearDown(session.close);
      final rig = await TestRig.create(session: session);
      addTearDown(rig.dispose);

      final row = await rig.tasks.create(
        TasksCompanion.insert(
          id: 't1',
          title: 'a',
          updatedAt: rig.clock.now(),
        ),
      );
      expect(row.userId, 'u1');

      await expectLater(
        rig.tasks.create(
          TasksCompanion.insert(
            id: 't2',
            title: 'foreign',
            updatedAt: rig.clock.now(),
            userId: const Value('u2'),
          ),
        ),
        throwsA(isA<OwnershipViolation>()),
      );
    });

    test('payload size limits are enforced before writing', () async {
      final rig = await TestRig.create(
        options: SyncOptions(
          clock: TestClock(DateTime.utc(2026)),
          backoff: const FixedBackoff(Duration.zero),
          maxPayloadBytes: 10,
        ),
      );
      addTearDown(rig.dispose);

      await expectLater(
        rig.tasks.create(
          TasksCompanion.insert(
            id: 't1',
            title: 'this payload is far too large',
            updatedAt: rig.clock.now(),
          ),
        ),
        throwsA(isA<PayloadTooLargeException>()),
      );
      expect(await rig.tasks.query().get(), isEmpty);
    });
  });
}
