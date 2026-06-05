import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:universal_sync/universal_sync.dart';
import '../shared/mocks.dart';

SyncConfig singleConfig() => SyncConfig(
  entityOrder: {0: String},
  entityFromJson: {'String': (_) => throw UnimplementedError('not used in puller tests')},
);
SyncConfig multiConfig() => SyncConfig(
  entityOrder: {0: String, 1: int},
  entityFromJson: {
    'String': (_) => throw UnimplementedError('not used in puller tests'),
    'int': (_) => throw UnimplementedError('not used in puller tests'),
  },
);

RemoteOperation _op({
  required SyncOperation operation,
  int serverSequence = 1,
  String entityId = '1',
  Map<String, dynamic> payload = const {},
}) {
  return RemoteOperation(
    entityType: 'String',
    entityId: entityId,
    operation: operation,
    payload: payload,
    serverSequence: serverSequence,
  );
}

void main() {
  late InMemoryLocalAdapter localAdapter;
  late MockRemoteAdapter remoteAdapter;

  setUpAll(() {
    registerFallbackValue(
      PullRequest(entityType: '', sinceSequence: 0),
    );
    registerFallbackValue(PushRequest([]));
  });

  setUp(() {
    localAdapter = InMemoryLocalAdapter();
    remoteAdapter = MockRemoteAdapter();
  });

  group('empty pull response', () {
    test('updates checkpoint and returns SyncResult(pulled: 0)', () async {
      when(() => remoteAdapter.pull(any())).thenAnswer((_) async => PullResponse(operations: [], latestSequence: 5));

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
      );

      final result = await engine.pull();

      expect(result.pulled, 0);
      final cp = await localAdapter.readCheckpoint('String');
      expect(cp, isNotNull);
      expect(cp!.lastServerSequence, 5);
    });

    test('creates checkpoint when no existing checkpoint and no operations', () async {
      when(() => remoteAdapter.pull(any())).thenAnswer((_) async => PullResponse(operations: [], latestSequence: 0));

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
      );

      await engine.pull();

      final cp = await localAdapter.readCheckpoint('String');
      expect(cp, isNotNull);
      expect(cp!.lastServerSequence, 0);
    });
  });

  group('remote insert', () {
    test('creates entity via upsertEntity and updates checkpoint', () async {
      when(() => remoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(
          operations: [
            _op(
              operation: SyncOperation.insert,
              payload: {'id': '1', 'name': 'test'},
              serverSequence: 1,
            ),
          ],
          latestSequence: 1,
        ),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
      );

      final result = await engine.pull();

      expect(result.pulled, 1);
      final cp = await localAdapter.readCheckpoint('String');
      expect(cp!.lastServerSequence, 1);
      expect(localAdapter.entities['String']?['1'], {'id': '1', 'name': 'test'});
    });
  });

  group('remote update', () {
    test('updates entity via upsertEntity and updates checkpoint', () async {
      when(() => remoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(
          operations: [
            _op(
              operation: SyncOperation.update,
              entityId: '1',
              payload: {'id': '1', 'name': 'updated'},
              serverSequence: 2,
            ),
          ],
          latestSequence: 2,
        ),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
      );

      final result = await engine.pull();

      expect(result.pulled, 1);
      expect(localAdapter.entities['String']?['1'], {'id': '1', 'name': 'updated'});
    });
  });

  group('remote delete', () {
    test('soft-deletes entity and updates checkpoint', () async {
      await localAdapter.upsertEntity('String', {'id': '1', 'name': 'test'});

      when(() => remoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(
          operations: [
            _op(
              operation: SyncOperation.delete,
              entityId: '1',
              serverSequence: 3,
            ),
          ],
          latestSequence: 3,
        ),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
      );

      final result = await engine.pull();

      expect(result.pulled, 1);
      expect(
        localAdapter.entities['String']?['1']?['deletedAt'],
        isNotNull,
      );
    });
  });

  group('multiple entity types', () {
    test('processes each type in entityOrder', () async {
      final calls = <String>[];
      when(() => remoteAdapter.pull(any())).thenAnswer((invocation) async {
        final request = invocation.positionalArguments[0] as PullRequest;
        calls.add(request.entityType);
        return PullResponse(operations: [], latestSequence: 0);
      });

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: multiConfig(),
      );

      await engine.pull();
      expect(calls, ['String', 'int']);
    });

    test('accumulates pulled count across types', () async {
      when(() => remoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(
          operations: [
            _op(
              operation: SyncOperation.insert,
              payload: {'id': '1'},
              serverSequence: 1,
            ),
          ],
          latestSequence: 1,
        ),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: multiConfig(),
      );

      final result = await engine.pull();
      expect(result.pulled, 2);
    });
  });

  group('initial pull', () {
    test('uses sinceSequence=0 when no checkpoint exists', () async {
      PullRequest? captured;
      when(() => remoteAdapter.pull(any())).thenAnswer((invocation) async {
        captured = invocation.positionalArguments[0] as PullRequest;
        return PullResponse(operations: [], latestSequence: 0);
      });

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
      );

      await engine.pull();
      expect(captured!.sinceSequence, 0);
    });
  });

  group('incremental pull', () {
    test('uses stored sinceSequence from checkpoint', () async {
      await localAdapter.writeCheckpoint(
        SyncCheckpoint(
          id: 'String',
          entityType: 'String',
          lastServerSequence: 10,
        ),
      );

      PullRequest? captured;
      when(() => remoteAdapter.pull(any())).thenAnswer((invocation) async {
        captured = invocation.positionalArguments[0] as PullRequest;
        return PullResponse(operations: [], latestSequence: 10);
      });

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
      );

      await engine.pull();
      expect(captured!.sinceSequence, 10);
    });
  });

  group('no re-enqueuing', () {
    test('upsertEntity is used and queue remains empty', () async {
      when(() => remoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(
          operations: [
            _op(
              operation: SyncOperation.insert,
              payload: {'id': '1'},
              serverSequence: 1,
            ),
          ],
          latestSequence: 1,
        ),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
      );

      await engine.pull();

      expect(await localAdapter.fetchPendingEntries('String', 10), isEmpty);
      verifyNever(() => remoteAdapter.push(any()));
    });
  });

  group('progress callback', () {
    test('called with correct (processed, total) per type', () async {
      when(() => remoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(
          operations: [
            _op(
              operation: SyncOperation.insert,
              payload: {'id': '1'},
              serverSequence: 1,
            ),
            _op(
              operation: SyncOperation.insert,
              payload: {'id': '2'},
              serverSequence: 2,
            ),
            _op(
              operation: SyncOperation.insert,
              payload: {'id': '3'},
              serverSequence: 3,
            ),
          ],
          latestSequence: 3,
        ),
      );

      final calls = <List<int>>[];
      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
      );

      final sub = engine.state.listen((s) {
        if (s is SyncInProgress && s.phase == SyncPhase.pulling && s.processed > 0) {
          calls.add([s.processed, s.total]);
        }
      });

      await engine.pull();
      await sub.cancel();

      expect(calls, [
        [1, 3],
        [2, 3],
        [3, 3],
      ]);
    });
  });

  group('cancellation', () {
    test('stops after current entity type when cancelled', () async {
      final callCount = <String, int>{};

      when(() => remoteAdapter.pull(any())).thenAnswer((invocation) async {
        final request = invocation.positionalArguments[0] as PullRequest;
        callCount[request.entityType] = (callCount[request.entityType] ?? 0) + 1;
        return PullResponse(
          operations: [
            _op(
              operation: SyncOperation.insert,
              payload: {'id': '1'},
              serverSequence: 1,
            ),
          ],
          latestSequence: 1,
        );
      });

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: multiConfig(),
      );

      final sub = engine.state.listen((s) {
        if (s is SyncInProgress && s.phase == SyncPhase.pulling && s.processed > 0) {
          engine.cancel();
        }
      });

      final result = await engine.pull();
      await sub.cancel();

      expect(callCount.containsKey('int'), false);
      expect(await localAdapter.readCheckpoint('String'), isNotNull);
      expect(await localAdapter.readCheckpoint('int'), isNull);
      expect(result.pulled, 1);
    });
  });

  group('operations are sorted by serverSequence', () {
    test('applies operations in ascending serverSequence order', () async {
      when(() => remoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(
          operations: [
            _op(
              operation: SyncOperation.insert,
              entityId: '2',
              payload: {'id': '2', 'seq': 3},
              serverSequence: 3,
            ),
            _op(
              operation: SyncOperation.insert,
              entityId: '1',
              payload: {'id': '1', 'seq': 1},
              serverSequence: 1,
            ),
            _op(
              operation: SyncOperation.insert,
              entityId: '3',
              payload: {'id': '3', 'seq': 2},
              serverSequence: 2,
            ),
          ],
          latestSequence: 3,
        ),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
      );

      await engine.pull();

      expect(localAdapter.entities['String']?['1']?['seq'], 1);
      expect(localAdapter.entities['String']?['3']?['seq'], 2);
      expect(localAdapter.entities['String']?['2']?['seq'], 3);
    });
  });

  group('checkpoint with existing sequence', () {
    test('does not write checkpoint when no ops and sequence unchanged', () async {
      await localAdapter.writeCheckpoint(
        SyncCheckpoint(
          id: 'String',
          entityType: 'String',
          lastServerSequence: 5,
        ),
      );

      when(() => remoteAdapter.pull(any())).thenAnswer((_) async => PullResponse(operations: [], latestSequence: 5));

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
      );

      await engine.pull();

      final cp = await localAdapter.readCheckpoint('String');
      expect(cp!.lastSyncedAt, isNull);
    });
  });

  group('entity type mismatch', () {
    test('operation is applied under config entity type ignoring op.entityType', () async {
      when(() => remoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(
          operations: [
            RemoteOperation(
              entityType: 'WrongType',
              entityId: '1',
              operation: SyncOperation.insert,
              payload: {'id': '1'},
              serverSequence: 1,
            ),
          ],
          latestSequence: 1,
        ),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
      );

      final result = await engine.pull();
      expect(result.pulled, 1);
      expect(localAdapter.entities['String']?['1'], isNotNull);
    });
  });

  group('checkpoint not advanced on adapter error', () {
    test('checkpoint lastServerSequence unchanged after pull error', () async {
      await localAdapter.writeCheckpoint(
        SyncCheckpoint(id: 'String', entityType: 'String', lastServerSequence: 10),
      );

      when(() => remoteAdapter.pull(any())).thenThrow(Exception('network'));

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
      );

      await expectLater(engine.pull(), throwsA(isA<Exception>()));

      final cp = await localAdapter.readCheckpoint('String');
      expect(cp!.lastServerSequence, 10);
    });
  });

  group('remote insert/update/delete edge cases', () {
    test('remote insert does not create a queue entry', () async {
      when(() => remoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(
          operations: [
            _op(operation: SyncOperation.insert, payload: {'id': '1'}, serverSequence: 1),
          ],
          latestSequence: 1,
        ),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
      );

      await engine.pull();
      expect(await localAdapter.fetchPendingEntries('String', 10), isEmpty);
    });

    test('remote update of non-existent entity upserts it', () async {
      when(() => remoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(
          operations: [
            _op(operation: SyncOperation.update, payload: {'id': '99'}, serverSequence: 1),
          ],
          latestSequence: 1,
        ),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
      );

      await engine.pull();
      expect(localAdapter.entities['String']?['99'], isNotNull);
    });

    test('remote delete of non-existent entity is handled gracefully', () async {
      when(() => remoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(
          operations: [
            _op(operation: SyncOperation.delete, entityId: 'nonexistent', serverSequence: 3),
          ],
          latestSequence: 3,
        ),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
      );

      await expectLater(engine.pull(), completes);
    });
  });

  group('checkpoint lastSyncedAt', () {
    test('is set after pull with operations', () async {
      when(() => remoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(
          operations: [
            _op(operation: SyncOperation.insert, payload: {'id': 's1'}, serverSequence: 1),
          ],
          latestSequence: 1,
        ),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
      );

      await engine.pull();
      final cp = await localAdapter.readCheckpoint('String');
      expect(cp!.lastSyncedAt, isNotNull);
    });

    test('is updated on subsequent pull with operations', () async {
      when(() => remoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(
          operations: [
            _op(operation: SyncOperation.insert, payload: {'id': 's1'}, serverSequence: 1),
          ],
          latestSequence: 1,
        ),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
      );

      await engine.pull();
      final cp1 = await localAdapter.readCheckpoint('String');

      when(() => remoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(
          operations: [
            _op(operation: SyncOperation.insert, payload: {'id': 's2'}, serverSequence: 2),
          ],
          latestSequence: 2,
        ),
      );

      await Future.delayed(Duration(milliseconds: 1));
      await engine.pull();
      final cp2 = await localAdapter.readCheckpoint('String');
      expect(cp2!.lastSyncedAt!.isAfter(cp1!.lastSyncedAt!), isTrue);
    });
  });

  group('payload field verification', () {
    test('remote insert payload fields are stored correctly', () async {
      when(() => remoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(
          operations: [
            _op(
              operation: SyncOperation.insert,
              payload: {'id': 'f1', 'value': 42, 'active': true},
              serverSequence: 1,
            ),
          ],
          latestSequence: 1,
        ),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
      );

      await engine.pull();
      final stored = localAdapter.entities['String']?['f1'];
      expect(stored?['value'], 42);
      expect(stored?['active'], isTrue);
    });

    test('insert then update resolves to final state', () async {
      when(() => remoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(
          operations: [
            RemoteOperation(
              entityType: 'String',
              entityId: 's1',
              operation: SyncOperation.insert,
              payload: {'id': 's1', 'value': 1},
              serverSequence: 1,
            ),
            RemoteOperation(
              entityType: 'String',
              entityId: 's1',
              operation: SyncOperation.update,
              payload: {'id': 's1', 'value': 99},
              serverSequence: 2,
            ),
          ],
          latestSequence: 2,
        ),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
      );

      await engine.pull();
      expect(localAdapter.entities['String']?['s1']?['value'], 99);
    });
  });

  group('progress callback', () {
    test('onProgress is called with correct values', () async {
      when(() => remoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(
          operations: [
            _op(operation: SyncOperation.insert, payload: {'id': 'a'}, serverSequence: 1),
            _op(operation: SyncOperation.insert, payload: {'id': 'b'}, serverSequence: 2),
            _op(operation: SyncOperation.delete, entityId: 'c', serverSequence: 3),
          ],
          latestSequence: 3,
        ),
      );

      final progress = <int>[];
      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
      );

      final sub = engine.state.listen((s) {
        if (s is SyncInProgress && s.phase == SyncPhase.pulling && s.processed > 0) {
          progress.add(s.processed);
        }
      });

      await engine.pull();
      await sub.cancel();

      expect(progress, [1, 2, 3]);
    });
  });
}
