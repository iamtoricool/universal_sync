import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:universal_sync/universal_sync.dart';

class MockRemoteAdapter extends Mock implements RemoteAdapter {}

SyncConfig singleConfig() => SyncConfig(entityOrder: [String]);
SyncConfig multiConfig() => SyncConfig(entityOrder: [String, int]);

Map<Type, SyncEntity Function(Map<String, dynamic>)> fromJson = {
  String: (_) => throw UnimplementedError('not used in puller tests'),
  int: (_) => throw UnimplementedError('not used in puller tests'),
};

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

  group('PullResult', () {
    test('defaults to pulled=0', () {
      expect(const PullResult().pulled, 0);
    });

    test('operator + sums pulled counts', () {
      final a = PullResult(pulled: 3);
      final b = PullResult(pulled: 7);
      expect((a + b).pulled, 10);
    });
  });

  group('empty pull response', () {
    test('updates checkpoint and returns PullResult(pulled: 0)', () async {
      when(() => remoteAdapter.pull(any())).thenAnswer((_) async => PullResponse(operations: [], latestSequence: 5));

      final puller = SyncPuller(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
        entityFromJson: fromJson,
      );

      final result = await puller.run();

      expect(result.pulled, 0);
      final cp = await localAdapter.readCheckpoint('String');
      expect(cp, isNotNull);
      expect(cp!.lastServerSequence, 5);
    });

    test('creates checkpoint when no existing checkpoint and no operations', () async {
      when(() => remoteAdapter.pull(any())).thenAnswer((_) async => PullResponse(operations: [], latestSequence: 0));

      final puller = SyncPuller(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
        entityFromJson: fromJson,
      );

      await puller.run();

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

      final puller = SyncPuller(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
        entityFromJson: fromJson,
      );

      final result = await puller.run();

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

      final puller = SyncPuller(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
        entityFromJson: fromJson,
      );

      final result = await puller.run();

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

      final puller = SyncPuller(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
        entityFromJson: fromJson,
      );

      final result = await puller.run();

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

      final puller = SyncPuller(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: multiConfig(),
        entityFromJson: fromJson,
      );

      await puller.run();
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

      final puller = SyncPuller(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: multiConfig(),
        entityFromJson: fromJson,
      );

      final result = await puller.run();
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

      final puller = SyncPuller(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
        entityFromJson: fromJson,
      );

      await puller.run();
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

      final puller = SyncPuller(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
        entityFromJson: fromJson,
      );

      await puller.run();
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

      final puller = SyncPuller(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
        entityFromJson: fromJson,
      );

      await puller.run();

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
      final puller = SyncPuller(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
        entityFromJson: fromJson,
      );

      await puller.run(
        onProgress: (processed, total) {
          calls.add([processed, total]);
        },
      );

      expect(calls, [
        [1, 3],
        [2, 3],
        [3, 3],
      ]);
    });
  });

  group('cancellation', () {
    test('stops after current entity type when cancelled', () async {
      final callCount = {};

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

      var checked = 0;
      final puller = SyncPuller(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: multiConfig(),
        entityFromJson: fromJson,
      );

      final result = await puller.run(
        isCancelled: () async {
          checked++;
          return checked > 1;
        },
      );

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

      final applied = <int>[];
      final puller = SyncPuller(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
        entityFromJson: fromJson,
      );

      await puller.run(
        onProgress: (processed, total) {
          applied.add(localAdapter.entities['String']!.length);
        },
      );

      expect(applied, [1, 2, 3]);
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

      final puller = SyncPuller(
        localAdapter: localAdapter,
        remoteAdapter: remoteAdapter,
        config: singleConfig(),
        entityFromJson: fromJson,
      );

      await puller.run();

      final cp = await localAdapter.readCheckpoint('String');
      expect(cp!.lastSyncedAt, isNull);
    });
  });
}
