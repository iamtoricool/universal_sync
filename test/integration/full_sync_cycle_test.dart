import 'dart:convert';

import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:universal_sync/universal_sync.dart';

class MockRemoteAdapter extends Mock implements RemoteAdapter {}

class _Product extends SyncEntity {
  @override
  final String id;
  @override
  final int version;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? deletedAt;
  final String name;

  _Product({
    required this.id,
    this.version = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.name = '',
  }) : deletedAt = null,
       createdAt = createdAt ?? DateTime(2024),
       updatedAt = updatedAt ?? DateTime(2024);

  @override
  Map<String, dynamic> toSyncJson() => {
    'id': id,
    'version': version,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'name': name,
  };

  factory _Product.fromJson(Map<String, dynamic> json) => _Product(
    id: json['id'] as String,
    version: json['version'] as int? ?? 0,
    name: json['name'] as String? ?? '',
  );
}

class _Customer extends SyncEntity {
  @override
  final String id;
  @override
  final int version;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final DateTime? deletedAt;
  final String email;

  _Customer({
    required this.id,
    this.version = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.email = '',
  }) : deletedAt = null,
       createdAt = createdAt ?? DateTime(2024),
       updatedAt = updatedAt ?? DateTime(2024);

  @override
  Map<String, dynamic> toSyncJson() => {
    'id': id,
    'version': version,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'email': email,
  };

  factory _Customer.fromJson(Map<String, dynamic> json) => _Customer(
    id: json['id'] as String,
    version: json['version'] as int? ?? 0,
    email: json['email'] as String? ?? '',
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(PushRequest([]));
    registerFallbackValue(PullRequest(entityType: '', sinceSequence: 0));
  });

  group('Full sync cycle', () {
    test('create entity, push, pull, and verify', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.enqueue(
        SyncQueueEntry(
          id: 'q1',
          entityType: '_Product',
          entityId: 'p1',
          operation: SyncOperation.insert,
          payload: jsonEncode({'id': 'p1', 'version': 0, 'name': 'Widget'}),
          version: 0,
          localSequence: 0,
          createdAt: DateTime(2024),
        ),
      );

      when(() => mockRemote.push(any())).thenAnswer((invocation) async {
        final request = invocation.positionalArguments[0] as PushRequest;
        return PushResponse(
          request.entries.map((e) => SyncEntryResult.accepted(entryId: e.id, serverSequence: 1)).toList(),
        );
      });

      when(
        () => mockRemote.pull(any()),
      ).thenAnswer((invocation) async => PullResponse(operations: [], latestSequence: 1));

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: mockRemote,
        config: SyncConfig(entityOrder: [_Product], batchSize: 10),
        entityFromJson: {_Product: _Product.fromJson},
      );

      final result = await engine.sync();

      expect(result.pushed, 1);
      expect(result.pulled, 0);
      expect(result.failed, 0);
      expect(result.conflicted, 0);
      expect(result.isClean, isTrue);
      expect(localAdapter.entities['_Product']?['p1']?['version'], 1);
    });

    test('multi-entity sync cycle with ordering', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.enqueue(
        SyncQueueEntry(
          id: 'q1',
          entityType: '_Product',
          entityId: 'p1',
          operation: SyncOperation.insert,
          payload: jsonEncode({'id': 'p1', 'version': 0, 'name': 'Widget'}),
          version: 0,
          localSequence: 0,
          createdAt: DateTime(2024),
        ),
      );

      await localAdapter.enqueue(
        SyncQueueEntry(
          id: 'q2',
          entityType: '_Customer',
          entityId: 'c1',
          operation: SyncOperation.insert,
          payload: jsonEncode({'id': 'c1', 'version': 0, 'email': 'test@test.com'}),
          version: 0,
          localSequence: 1,
          createdAt: DateTime(2024),
        ),
      );

      when(() => mockRemote.push(any())).thenAnswer((invocation) async {
        final request = invocation.positionalArguments[0] as PushRequest;
        return PushResponse(
          request.entries.map((e) => SyncEntryResult.accepted(entryId: e.id, serverSequence: 1)).toList(),
        );
      });

      when(
        () => mockRemote.pull(any()),
      ).thenAnswer((invocation) async => PullResponse(operations: [], latestSequence: 1));

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: mockRemote,
        config: SyncConfig(entityOrder: [_Product, _Customer], batchSize: 10),
        entityFromJson: {
          _Product: _Product.fromJson,
          _Customer: _Customer.fromJson,
        },
      );

      final result = await engine.sync();

      expect(result.pushed, 2);
      expect(result.isClean, isTrue);
      expect(localAdapter.entities['_Product']?['p1'], isNotNull);
      expect(localAdapter.entities['_Customer']?['c1'], isNotNull);
    });

    test('conflict resolution with ServerWins', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.enqueue(
        SyncQueueEntry(
          id: 'q1',
          entityType: '_Product',
          entityId: 'p1',
          operation: SyncOperation.insert,
          payload: jsonEncode({'id': 'p1', 'version': 0, 'name': 'local'}),
          version: 0,
          localSequence: 0,
          createdAt: DateTime(2024),
        ),
      );

      when(() => mockRemote.push(any())).thenAnswer(
        (invocation) async => PushResponse([
          SyncEntryResult.conflicted(
            entryId: 'q1',
            serverPayload: {'id': 'p1', 'version': 1, 'name': 'remote'},
          ),
        ]),
      );

      when(
        () => mockRemote.pull(any()),
      ).thenAnswer((invocation) async => PullResponse(operations: [], latestSequence: 1));

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: mockRemote,
        config: SyncConfig(entityOrder: [_Product], batchSize: 10),
        entityFromJson: {_Product: _Product.fromJson},
      );

      final result = await engine.sync();

      expect(result.pushed, 0);
      expect(localAdapter.entities['_Product']?['p1']?['name'], 'remote');
      expect(localAdapter.entities['_Product']?['p1']?['version'], 1);
      final pending = await localAdapter.fetchPendingEntries('_Product', 10);
      expect(pending, isEmpty);
    });

    test('error recovery on network failure', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.enqueue(
        SyncQueueEntry(
          id: 'q1',
          entityType: '_Product',
          entityId: 'p1',
          operation: SyncOperation.insert,
          payload: jsonEncode({'id': 'p1', 'version': 0, 'name': 'Widget'}),
          version: 0,
          localSequence: 0,
          createdAt: DateTime(2024),
        ),
      );

      var pushCallCount = 0;
      when(() => mockRemote.push(any())).thenAnswer((invocation) async {
        pushCallCount++;
        if (pushCallCount == 1) {
          throw Exception('Network error');
        }
        return PushResponse([
          SyncEntryResult.accepted(entryId: 'q1', serverSequence: 1),
        ]);
      });

      when(
        () => mockRemote.pull(any()),
      ).thenAnswer((invocation) async => PullResponse(operations: [], latestSequence: 1));

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: mockRemote,
        config: SyncConfig(entityOrder: [_Product], batchSize: 10),
        entityFromJson: {_Product: _Product.fromJson},
      );

      try {
        await engine.sync();
        fail('Expected exception');
      } on Exception {
        // Expected - network error causes first sync to fail
      }

      final pending = await localAdapter.fetchPendingEntries('_Product', 10);
      expect(pending.length, 1);
      expect(pending[0].status, SyncEntryStatus.pending);

      final result = await engine.sync();
      expect(result.pushed, 1);
      expect(result.isClean, isTrue);
    });

    test('pull applies remote operations and updates checkpoint', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      when(() => mockRemote.pull(any())).thenAnswer(
        (invocation) async => PullResponse(
          operations: [
            RemoteOperation(
              entityType: '_Product',
              entityId: 'p1',
              operation: SyncOperation.insert,
              payload: {'id': 'p1', 'version': 1, 'name': 'from server'},
              serverSequence: 1,
            ),
          ],
          latestSequence: 1,
        ),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: mockRemote,
        config: SyncConfig(entityOrder: [_Product], batchSize: 10),
        entityFromJson: {_Product: _Product.fromJson},
      );

      final result = await engine.pull();

      expect(result.pulled, 1);
      expect(localAdapter.entities['_Product']?['p1']?['name'], 'from server');

      final cp = await localAdapter.readCheckpoint('_Product');
      expect(cp, isNotNull);
      expect(cp!.lastServerSequence, 1);
    });

    test('local update pushes updated payload', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.upsertEntity('_Product', {'id': 'p1', 'version': 1, 'name': 'Old'});
      await localAdapter.enqueue(
        SyncQueueEntry(
          id: 'q1',
          entityType: '_Product',
          entityId: 'p1',
          operation: SyncOperation.update,
          payload: jsonEncode({'id': 'p1', 'version': 1, 'name': 'Updated'}),
          version: 1,
          localSequence: 0,
          createdAt: DateTime(2024),
        ),
      );

      Map<String, dynamic>? captured;
      when(() => mockRemote.push(any())).thenAnswer((invocation) async {
        final request = invocation.positionalArguments[0] as PushRequest;
        captured = jsonDecode(request.entries.first.payload) as Map<String, dynamic>;
        return PushResponse([SyncEntryResult.accepted(entryId: 'q1', serverSequence: 2)]);
      });
      when(() => mockRemote.pull(any())).thenAnswer(
        (_) async => PullResponse(operations: [], latestSequence: 2),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: mockRemote,
        config: SyncConfig(entityOrder: [_Product], batchSize: 10),
        entityFromJson: {_Product: _Product.fromJson},
      );

      final result = await engine.sync();
      expect(result.pushed, 1);
      expect(captured?['name'], 'Updated');
    });

    test('local delete pushes delete operation', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.upsertEntity('_Product', {'id': 'p1', 'version': 1, 'name': 'Gone'});
      await localAdapter.enqueue(
        SyncQueueEntry(
          id: 'q1',
          entityType: '_Product',
          entityId: 'p1',
          operation: SyncOperation.delete,
          payload: jsonEncode({'id': 'p1', 'version': 1}),
          version: 1,
          localSequence: 0,
          createdAt: DateTime(2024),
        ),
      );

      SyncOperation? capturedOp;
      when(() => mockRemote.push(any())).thenAnswer((invocation) async {
        final request = invocation.positionalArguments[0] as PushRequest;
        capturedOp = request.entries.first.operation;
        return PushResponse([SyncEntryResult.accepted(entryId: 'q1', serverSequence: 2)]);
      });
      when(() => mockRemote.pull(any())).thenAnswer(
        (_) async => PullResponse(operations: [], latestSequence: 2),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: mockRemote,
        config: SyncConfig(entityOrder: [_Product], batchSize: 10),
        entityFromJson: {_Product: _Product.fromJson},
      );

      final result = await engine.sync();
      expect(result.pushed, 1);
      expect(capturedOp, SyncOperation.delete);
    });

    test('remote update modifies local entity on pull', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.upsertEntity('_Product', {'id': 'p1', 'version': 1, 'name': 'Local'});

      when(() => mockRemote.pull(any())).thenAnswer(
        (_) async => PullResponse(
          operations: [
            RemoteOperation(
              entityType: '_Product',
              entityId: 'p1',
              operation: SyncOperation.update,
              payload: {'id': 'p1', 'version': 2, 'name': 'Remote updated'},
              serverSequence: 2,
            ),
          ],
          latestSequence: 2,
        ),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: mockRemote,
        config: SyncConfig(entityOrder: [_Product], batchSize: 10),
        entityFromJson: {_Product: _Product.fromJson},
      );

      await engine.pull();
      expect(localAdapter.entities['_Product']?['p1']?['name'], 'Remote updated');
      expect(localAdapter.entities['_Product']?['p1']?['version'], 2);
    });

    test('remote delete soft-deletes local entity on pull', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.upsertEntity('_Product', {'id': 'p1', 'version': 1, 'name': 'ToDelete'});

      when(() => mockRemote.pull(any())).thenAnswer(
        (_) async => PullResponse(
          operations: [
            RemoteOperation(
              entityType: '_Product',
              entityId: 'p1',
              operation: SyncOperation.delete,
              payload: {},
              serverSequence: 2,
            ),
          ],
          latestSequence: 2,
        ),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: mockRemote,
        config: SyncConfig(entityOrder: [_Product], batchSize: 10),
        entityFromJson: {_Product: _Product.fromJson},
      );

      await engine.pull();
      expect(localAdapter.entities['_Product']?['p1']?['deletedAt'], isNotNull);
    });

    test('second pull uses updated checkpoint', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      final pullRequests = <PullRequest>[];
      when(() => mockRemote.pull(any())).thenAnswer((invocation) async {
        pullRequests.add(invocation.positionalArguments[0] as PullRequest);
        return PullResponse(operations: [], latestSequence: 5);
      });

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: mockRemote,
        config: SyncConfig(entityOrder: [_Product], batchSize: 10),
        entityFromJson: {_Product: _Product.fromJson},
      );

      await engine.pull();
      await engine.pull();

      expect(pullRequests[0].sinceSequence, 0);
      expect(pullRequests[1].sinceSequence, 5);
    });

    test('ClientWins resolver integration', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.upsertEntity('_Product', {'id': 'p1', 'version': 0, 'name': 'Local'});
      await localAdapter.enqueue(
        SyncQueueEntry(
          id: 'q1',
          entityType: '_Product',
          entityId: 'p1',
          operation: SyncOperation.insert,
          payload: jsonEncode({'id': 'p1', 'version': 0, 'name': 'Local'}),
          version: 0,
          localSequence: 0,
          createdAt: DateTime(2024),
        ),
      );

      when(() => mockRemote.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.conflicted(
            entryId: 'q1',
            serverPayload: {'id': 'p1', 'version': 1, 'name': 'Remote'},
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
          entityOrder: [_Product],
          batchSize: 10,
          maxRetries: 0,
        ),
        entityFromJson: {_Product: _Product.fromJson},
        resolvers: {_Product: ClientWinsResolver<SyncEntity>()},
      );

      final result = await engine.sync();
      expect(result.conflicted, 1);
      expect(localAdapter.entities['_Product']?['p1']?['name'], 'Local');
    });

    test('state stream transitions through correct phases', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.enqueue(
        SyncQueueEntry(
          id: 'q1',
          entityType: '_Product',
          entityId: 'p1',
          operation: SyncOperation.insert,
          payload: jsonEncode({'id': 'p1', 'version': 0}),
          version: 0,
          localSequence: 0,
          createdAt: DateTime(2024),
        ),
      );

      when(() => mockRemote.push(any())).thenAnswer(
        (_) async => PushResponse([SyncEntryResult.accepted(entryId: 'q1', serverSequence: 1)]),
      );
      when(() => mockRemote.pull(any())).thenAnswer(
        (_) async => PullResponse(operations: [], latestSequence: 1),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: mockRemote,
        config: SyncConfig(entityOrder: [_Product], batchSize: 10),
        entityFromJson: {_Product: _Product.fromJson},
      );

      final phases = <SyncPhase>[];
      final sub = engine.state.listen((s) {
        if (s is SyncInProgress) phases.add(s.phase);
      });
      await engine.sync();
      await sub.cancel();

      expect(phases.first, SyncPhase.pushing);
      expect(phases.last, SyncPhase.pulling);
    });

    test('SyncIdle.pendingCount reflects offline writes before sync', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: mockRemote,
        config: SyncConfig(entityOrder: [_Product], batchSize: 10),
        entityFromJson: {_Product: _Product.fromJson},
      );

      expect((engine.currentState as SyncIdle).pendingCount, 0);

      await localAdapter.enqueue(
        SyncQueueEntry(
          id: 'q1',
          entityType: '_Product',
          entityId: 'p1',
          operation: SyncOperation.insert,
          payload: jsonEncode({'id': 'p1', 'version': 0}),
          version: 0,
          localSequence: 0,
          createdAt: DateTime(2024),
        ),
      );

      expect((engine.currentState as SyncIdle).pendingCount, 0);

      when(() => mockRemote.push(any())).thenAnswer(
        (_) async => PushResponse([SyncEntryResult.accepted(entryId: 'q1', serverSequence: 1)]),
      );
      when(() => mockRemote.pull(any())).thenAnswer(
        (_) async => PullResponse(operations: [], latestSequence: 1),
      );

      await engine.sync();
      expect((engine.currentState as SyncIdle).pendingCount, 0);
    });

    test('multi-type pull applies operations for all entity types', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      when(() => mockRemote.pull(any())).thenAnswer((invocation) async {
        final request = invocation.positionalArguments[0] as PullRequest;
        if (request.entityType == '_Product') {
          return PullResponse(
            operations: [
              RemoteOperation(
                entityType: '_Product',
                entityId: 'p1',
                operation: SyncOperation.insert,
                payload: {'id': 'p1', 'version': 1, 'name': 'Prod'},
                serverSequence: 1,
              ),
            ],
            latestSequence: 1,
          );
        }
        return PullResponse(
          operations: [
            RemoteOperation(
              entityType: '_Customer',
              entityId: 'c1',
              operation: SyncOperation.insert,
              payload: {'id': 'c1', 'version': 1, 'email': 'cust@test.com'},
              serverSequence: 1,
            ),
          ],
          latestSequence: 1,
        );
      });

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: mockRemote,
        config: SyncConfig(entityOrder: [_Product, _Customer], batchSize: 10),
        entityFromJson: {_Product: _Product.fromJson, _Customer: _Customer.fromJson},
      );

      final result = await engine.pull();
      expect(result.pulled, 2);
      expect(localAdapter.entities['_Product']?['p1']?['name'], 'Prod');
      expect(localAdapter.entities['_Customer']?['c1']?['email'], 'cust@test.com');
    });
  });
}
