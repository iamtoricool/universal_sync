import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:universal_sync/universal_sync.dart';

import 'package:example/todos/todo.dart';

class MockRemoteAdapter extends Mock implements RemoteAdapter {}

SyncQueueEntry<Todo> todoEntry({
  required String id,
  required String entityId,
  required SyncOperation operation,
  required int version,
  required int localSequence,
  String title = 'Test',
  bool isDone = false,
  String? idempotencyKey,
}) {
  final now = DateTime(2024);
  return SyncQueueEntry<Todo>(
    id: id,
    idempotencyKey: idempotencyKey ?? id,
    data: Todo(
      id: entityId,
      version: version,
      createdAt: now,
      updatedAt: now,
      title: title,
      description: '',
      isDone: isDone,
    ),
    operation: operation,
    version: version,
    localSequence: localSequence,
    createdAt: now,
  );
}

Map<String, dynamic> todoJson({
  required String id,
  int version = 0,
  String title = 'Test',
  bool isDone = false,
}) {
  return {
    'id': id,
    'version': version,
    'createdAt': DateTime(2024).toIso8601String(),
    'updatedAt': DateTime(2024).toIso8601String(),
    'title': title,
    'description': '',
    'isDone': isDone,
  };
}

void main() {
  setUpAll(() {
    registerFallbackValue(PushRequest([]));
    registerFallbackValue(PullRequest(entityType: '', sinceSequence: 0));
  });

  group('Complete flow', () {
    test('write, push, pull, and verify', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.enqueue(
        todoEntry(
          id: 'q1',
          entityId: 't1',
          operation: SyncOperation.insert,
          version: 0,
          localSequence: 0,
          title: 'My Todo',
        ),
      );

      when(() => mockRemote.push(any())).thenAnswer((inv) async {
        final req = inv.positionalArguments[0] as PushRequest;
        return PushResponse(
          req.entries
              .map(
                (e) =>
                    SyncEntryResult.accepted(entryId: e.id, serverSequence: 1),
              )
              .toList(),
        );
      });

      when(() => mockRemote.pull(any())).thenAnswer(
        (_) async => PullResponse(operations: [], latestSequence: 1),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: mockRemote,
        config: SyncConfig(
          entityOrder: {0: Todo},
          batchSize: 10,
          entityFromJson: {entityTypeName(Todo): Todo.fromJson},
        ),
      );

      final result = await engine.sync();

      expect(result.pushed, 1);
      expect(result.pulled, 0);
      expect(result.failed, 0);
      expect(result.conflicted, 0);
      expect(result.isClean, isTrue);

      final entity = localAdapter.entities['Todo']?['t1'];
      expect(entity, isNotNull);
      expect(entity!['version'], 1);
      expect(entity['title'], 'My Todo');

      final pending = await localAdapter.fetchPendingEntries('Todo', 10);
      expect(pending, isEmpty);
    });

    test('pull creates local entities from remote', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      when(() => mockRemote.pull(any())).thenAnswer(
        (_) async => PullResponse(
          operations: [
            RemoteOperation(
              entityType: 'Todo',
              entityId: 't1',
              operation: SyncOperation.insert,
              payload: todoJson(id: 't1', version: 1, title: 'Pulled'),
              serverSequence: 1,
            ),
          ],
          latestSequence: 1,
        ),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: mockRemote,
        config: SyncConfig(
          entityOrder: {0: Todo},
          batchSize: 10,
          entityFromJson: {entityTypeName(Todo): Todo.fromJson},
        ),
      );

      final result = await engine.pull();

      expect(result.pulled, 1);
      expect(localAdapter.entities['Todo']?['t1']?['title'], 'Pulled');
      expect(localAdapter.entities['Todo']?['t1']?['version'], 1);

      final cp = await localAdapter.readCheckpoint('Todo');
      expect(cp, isNotNull);
      expect(cp!.lastServerSequence, 1);
    });
  });

  group('Conflict resolution', () {
    test('ServerWins — remote overwrites local on conflict', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.upsertEntity(
        'Todo',
        todoJson(id: 't1', version: 0, title: 'Local'),
      );
      await localAdapter.enqueue(
        todoEntry(
          id: 'q1',
          entityId: 't1',
          operation: SyncOperation.update,
          version: 0,
          localSequence: 0,
          title: 'Local Updated',
        ),
      );

      when(() => mockRemote.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.conflicted(
            entryId: 'q1',
            serverPayload: todoJson(
              id: 't1',
              version: 2,
              title: 'Remote',
              isDone: true,
            ),
          ),
        ]),
      );
      when(() => mockRemote.pull(any())).thenAnswer(
        (_) async => PullResponse(operations: [], latestSequence: 1),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: mockRemote,
        config: SyncConfig(
          entityOrder: {0: Todo},
          batchSize: 10,
          entityFromJson: {entityTypeName(Todo): Todo.fromJson},
          resolvers: {'Todo': serverWinsResolver},
        ),
      );

      final result = await engine.sync();

      expect(result.conflicted, 1);
      expect(localAdapter.entities['Todo']?['t1']?['title'], 'Remote');
      expect(localAdapter.entities['Todo']?['t1']?['version'], 2);
      expect(localAdapter.entities['Todo']?['t1']?['isDone'], true);
    });

    test('ClientWins — local data kept on conflict', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.upsertEntity(
        'Todo',
        todoJson(id: 't1', version: 0, title: 'Local'),
      );
      await localAdapter.enqueue(
        todoEntry(
          id: 'q1',
          entityId: 't1',
          operation: SyncOperation.update,
          version: 0,
          localSequence: 0,
          title: 'Local Updated',
        ),
      );

      when(() => mockRemote.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.conflicted(
            entryId: 'q1',
            serverPayload: todoJson(
              id: 't1',
              version: 2,
              title: 'Remote',
              isDone: true,
            ),
          ),
        ]),
      );
      when(() => mockRemote.pull(any())).thenAnswer(
        (_) async => PullResponse(operations: [], latestSequence: 1),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: mockRemote,
        config: SyncConfig(
          entityOrder: {0: Todo},
          batchSize: 10,
          entityFromJson: {entityTypeName(Todo): Todo.fromJson},
          resolvers: {'Todo': clientWinsResolver},
        ),
      );

      final result = await engine.sync();

      expect(result.conflicted, 1);
      expect(localAdapter.entities['Todo']?['t1']?['title'], 'Local');

      final pending = await localAdapter.fetchPendingEntries('Todo', 10);
      expect(pending, isEmpty);
    });
  });

  group('Error recovery', () {
    test('network failure preserves pending, retry succeeds', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.enqueue(
        todoEntry(
          id: 'q1',
          entityId: 't1',
          operation: SyncOperation.insert,
          version: 0,
          localSequence: 0,
        ),
      );

      var pushCalls = 0;
      when(() => mockRemote.push(any())).thenAnswer((inv) async {
        pushCalls++;
        if (pushCalls == 1) throw Exception('Network error');
        final req = inv.positionalArguments[0] as PushRequest;
        return PushResponse(
          req.entries
              .map(
                (e) =>
                    SyncEntryResult.accepted(entryId: e.id, serverSequence: 1),
              )
              .toList(),
        );
      });
      when(() => mockRemote.pull(any())).thenAnswer(
        (_) async => PullResponse(operations: [], latestSequence: 1),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: mockRemote,
        config: SyncConfig(
          entityOrder: {0: Todo},
          batchSize: 10,
          entityFromJson: {entityTypeName(Todo): Todo.fromJson},
        ),
      );

      try {
        await engine.sync();
        fail('Expected exception');
      } on Exception {
        // Expected — first sync fails
      }

      var pending = await localAdapter.fetchPendingEntries('Todo', 10);
      expect(pending.length, 1);
      expect(pending[0].status, SyncEntryStatus.pending);

      final result = await engine.sync();
      expect(result.pushed, 1);
      expect(result.isClean, isTrue);

      pending = await localAdapter.fetchPendingEntries('Todo', 10);
      expect(pending, isEmpty);
    });
  });

  group('State management', () {
    test('engine emits phases: pushing → pulling', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.enqueue(
        todoEntry(
          id: 'q1',
          entityId: 't1',
          operation: SyncOperation.insert,
          version: 0,
          localSequence: 0,
        ),
      );

      when(() => mockRemote.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.accepted(entryId: 'q1', serverSequence: 1),
        ]),
      );
      when(() => mockRemote.pull(any())).thenAnswer(
        (_) async => PullResponse(operations: [], latestSequence: 1),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: mockRemote,
        config: SyncConfig(
          entityOrder: {0: Todo},
          batchSize: 10,
          entityFromJson: {entityTypeName(Todo): Todo.fromJson},
        ),
      );

      final phases = <SyncPhase>[];
      final states = <SyncState>[];
      final sub = engine.state.listen((s) {
        states.add(s);
        if (s is SyncInProgress) phases.add(s.phase);
      });
      final result = await engine.sync();
      await sub.cancel();

      expect(phases.first, SyncPhase.pushing);
      expect(phases.last, SyncPhase.pulling);
      expect(result.isClean, isTrue);
    });
  });

  group('Pending count', () {
    test('reflects queue state through provider lifecycle', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      when(() => mockRemote.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.accepted(entryId: 'q1', serverSequence: 1),
        ]),
      );
      when(() => mockRemote.pull(any())).thenAnswer(
        (_) async => PullResponse(operations: [], latestSequence: 1),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: mockRemote,
        config: SyncConfig(
          entityOrder: {0: Todo},
          batchSize: 10,
          entityFromJson: {entityTypeName(Todo): Todo.fromJson},
        ),
      );

      var pending0 = await localAdapter.fetchPendingEntries('Todo', 10);
      expect(pending0, isEmpty);

      await localAdapter.enqueue(
        todoEntry(
          id: 'q1',
          entityId: 't1',
          operation: SyncOperation.insert,
          version: 0,
          localSequence: 0,
          title: 'Pending Todo',
        ),
      );

      var pending1 = await localAdapter.fetchPendingEntries('Todo', 10);
      expect(pending1.length, 1);

      await engine.sync();

      var pending2 = await localAdapter.fetchPendingEntries('Todo', 10);
      expect(pending2, isEmpty);
    });
  });

  group('Complex multi-op flow', () {
    test('insert then update then delete across push', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.enqueue(
        todoEntry(
          id: 'q1',
          entityId: 't1',
          operation: SyncOperation.insert,
          version: 0,
          localSequence: 0,
          title: 'First',
        ),
      );

      await localAdapter.enqueue(
        todoEntry(
          id: 'q2',
          entityId: 't1',
          operation: SyncOperation.update,
          version: 0,
          localSequence: 1,
          title: 'Updated',
          isDone: true,
        ),
      );

      await localAdapter.enqueue(
        todoEntry(
          id: 'q3',
          entityId: 't2',
          operation: SyncOperation.insert,
          version: 0,
          localSequence: 2,
          title: 'Second',
        ),
      );

      final pushReqs = <PushRequest>[];
      when(() => mockRemote.push(any())).thenAnswer((inv) async {
        final req = inv.positionalArguments[0] as PushRequest;
        pushReqs.add(req);
        return PushResponse(
          req.entries.map((e) {
            final seq = switch (e.id) {
              'q1' => 1,
              'q2' => 2,
              'q3' => 1,
              _ => 0,
            };
            return SyncEntryResult.accepted(entryId: e.id, serverSequence: seq);
          }).toList(),
        );
      });

      when(() => mockRemote.pull(any())).thenAnswer(
        (_) async => PullResponse(operations: [], latestSequence: 2),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: mockRemote,
        config: SyncConfig(
          entityOrder: {0: Todo},
          batchSize: 10,
          entityFromJson: {entityTypeName(Todo): Todo.fromJson},
        ),
      );

      final result = await engine.sync();

      expect(result.pushed, 3);
      expect(result.isClean, isTrue);

      expect(pushReqs.length, 1);
      expect(pushReqs[0].entries.length, 3);

      final e1 = localAdapter.entities['Todo']?['t1'];
      expect(e1, isNotNull);
      expect(e1!['title'], 'Updated');
      // Both entries had version=0 in payload, so each bumps to 1.
      // The update overwrites the insert result, yielding version 1.
      expect(e1['version'], 1);
      expect(e1['isDone'], true);

      final e2 = localAdapter.entities['Todo']?['t2'];
      expect(e2, isNotNull);
      expect(e2!['title'], 'Second');
      expect(e2['version'], 1);

      final pending = await localAdapter.fetchPendingEntries('Todo', 10);
      expect(pending, isEmpty);
    });
  });
}
