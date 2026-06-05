import 'dart:convert';

import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:universal_sync/universal_sync.dart';
import '../shared/mocks.dart';
import '../shared/test_entities.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(PushRequest([]));
    registerFallbackValue(PullRequest(entityType: '', sinceSequence: 0));
  });

  final engines = <SyncEngine>[];

  tearDown(() {
    for (final e in engines) {
      try {
        e.dispose();
      } catch (_) {}
    }
    engines.clear();
  });

  group('Full sync cycle', () {
    test('create entity, push, pull, and verify', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.enqueue(
        SyncQueueEntry<Product>(
          id: 'q1',
          idempotencyKey: 'q1',
          data: Product(id: 'p1', version: 0, name: 'Widget'),
          operation: SyncOperation.insert,
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
        config: SyncConfig(
          entityOrder: {0: Product},
          entityFromJson: {entityTypeName(Product): Product.fromJson},
          batchSize: 10,
        ),
      );
      engines.add(engine);

      final result = await engine.sync();

      expect(result.pushed, 1);
      expect(result.pulled, 0);
      expect(result.failed, 0);
      expect(result.conflicted, 0);
      expect(result.isClean, isTrue);
      expect(localAdapter.entities['Product']?['p1']?['version'], 1);
    });

    test('multi-entity sync cycle with ordering', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.enqueue(
        SyncQueueEntry<Product>(
          id: 'q1',
          idempotencyKey: 'q1',
          data: Product(id: 'p1', version: 0, name: 'Widget'),
          operation: SyncOperation.insert,
          version: 0,
          localSequence: 0,
          createdAt: DateTime(2024),
        ),
      );

      await localAdapter.enqueue(
        SyncQueueEntry<Customer>(
          id: 'q2',
          idempotencyKey: 'q2',
          data: Customer(id: 'c1', version: 0, email: 'test@test.com'),
          operation: SyncOperation.insert,
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
        config: SyncConfig(
          entityOrder: {0: Product, 1: Customer},
          entityFromJson: {
            entityTypeName(Product): Product.fromJson,
            entityTypeName(Customer): Customer.fromJson,
          },
          batchSize: 10,
        ),
      );
      engines.add(engine);

      final result = await engine.sync();

      expect(result.pushed, 2);
      expect(result.isClean, isTrue);
      expect(localAdapter.entities['Product']?['p1'], isNotNull);
      expect(localAdapter.entities['Customer']?['c1'], isNotNull);
    });

    test('conflict resolution with ServerWins', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.enqueue(
        SyncQueueEntry<Product>(
          id: 'q1',
          idempotencyKey: 'q1',
          data: Product(id: 'p1', version: 0, name: 'local'),
          operation: SyncOperation.insert,
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
        config: SyncConfig(
          entityOrder: {0: Product},
          entityFromJson: {entityTypeName(Product): Product.fromJson},
          batchSize: 10,
        ),
      );
      engines.add(engine);

      final result = await engine.sync();

      expect(result.pushed, 0);
      expect(localAdapter.entities['Product']?['p1']?['name'], 'remote');
      expect(localAdapter.entities['Product']?['p1']?['version'], 1);
      final pending = await localAdapter.fetchPendingEntries('Product', 10);
      expect(pending, isEmpty);
    });

    test('error recovery on network failure', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.enqueue(
        SyncQueueEntry<Product>(
          id: 'q1',
          idempotencyKey: 'q1',
          data: Product(id: 'p1', version: 0, name: 'Widget'),
          operation: SyncOperation.insert,
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
        config: SyncConfig(
          entityOrder: {0: Product},
          entityFromJson: {entityTypeName(Product): Product.fromJson},
          batchSize: 10,
        ),
      );
      engines.add(engine);

      try {
        await engine.sync();
        fail('Expected exception');
      } on Exception {
        // Expected - network error causes first sync to fail
      }

      final pending = await localAdapter.fetchPendingEntries('Product', 10);
      expect(pending.length, 1);

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
              entityType: 'Product',
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
        config: SyncConfig(
          entityOrder: {0: Product},
          entityFromJson: {entityTypeName(Product): Product.fromJson},
          batchSize: 10,
        ),
      );
      engines.add(engine);

      final result = await engine.pull();

      expect(result.pulled, 1);
      expect(localAdapter.entities['Product']?['p1']?['name'], 'from server');

      final cp = await localAdapter.readCheckpoint('Product');
      expect(cp, isNotNull);
      expect(cp!.lastServerSequence, 1);
    });

    test('local update pushes updated payload', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.upsertEntity('Product', {'id': 'p1', 'version': 1, 'name': 'Old'});
      await localAdapter.enqueue(
        SyncQueueEntry<Product>(
          id: 'q1',
          idempotencyKey: 'q1',
          data: Product(id: 'p1', version: 1, name: 'Updated'),
          operation: SyncOperation.update,
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
        config: SyncConfig(
          entityOrder: {0: Product},
          entityFromJson: {entityTypeName(Product): Product.fromJson},
          batchSize: 10,
        ),
      );
      engines.add(engine);

      final result = await engine.sync();
      expect(result.pushed, 1);
      expect(captured?['name'], 'Updated');
    });

    test('local delete pushes delete operation', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.upsertEntity('Product', {'id': 'p1', 'version': 1, 'name': 'Gone'});
      await localAdapter.enqueue(
        SyncQueueEntry<Product>(
          id: 'q1',
          idempotencyKey: 'q1',
          data: Product(id: 'p1', version: 1),
          operation: SyncOperation.delete,
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
        config: SyncConfig(
          entityOrder: {0: Product},
          entityFromJson: {entityTypeName(Product): Product.fromJson},
          batchSize: 10,
        ),
      );
      engines.add(engine);

      final result = await engine.sync();
      expect(result.pushed, 1);
      expect(capturedOp, SyncOperation.delete);
    });

    test('remote update modifies local entity on pull', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.upsertEntity('Product', {'id': 'p1', 'version': 1, 'name': 'Local'});

      when(() => mockRemote.pull(any())).thenAnswer(
        (_) async => PullResponse(
          operations: [
            RemoteOperation(
              entityType: 'Product',
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
        config: SyncConfig(
          entityOrder: {0: Product},
          entityFromJson: {entityTypeName(Product): Product.fromJson},
          batchSize: 10,
        ),
      );
      engines.add(engine);

      await engine.pull();
      expect(localAdapter.entities['Product']?['p1']?['name'], 'Remote updated');
      expect(localAdapter.entities['Product']?['p1']?['version'], 2);
    });

    test('remote delete soft-deletes local entity on pull', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.upsertEntity('Product', {'id': 'p1', 'version': 1, 'name': 'ToDelete'});

      when(() => mockRemote.pull(any())).thenAnswer(
        (_) async => PullResponse(
          operations: [
            RemoteOperation(
              entityType: 'Product',
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
        config: SyncConfig(
          entityOrder: {0: Product},
          entityFromJson: {entityTypeName(Product): Product.fromJson},
          batchSize: 10,
        ),
      );
      engines.add(engine);

      await engine.pull();
      expect(localAdapter.entities['Product']?['p1']?['deletedAt'], isNotNull);
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
        config: SyncConfig(
          entityOrder: {0: Product},
          entityFromJson: {entityTypeName(Product): Product.fromJson},
          batchSize: 10,
        ),
      );
      engines.add(engine);

      await engine.pull();
      await engine.pull();

      expect(pullRequests[0].sinceSequence, 0);
      expect(pullRequests[1].sinceSequence, 5);
    });

    test('ClientWins resolver integration', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.upsertEntity('Product', {'id': 'p1', 'version': 0, 'name': 'Local'});
      await localAdapter.enqueue(
        SyncQueueEntry<Product>(
          id: 'q1',
          idempotencyKey: 'q1',
          data: Product(id: 'p1', version: 0, name: 'Local'),
          operation: SyncOperation.insert,
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
          entityOrder: {0: Product},
          entityFromJson: {entityTypeName(Product): Product.fromJson},
          batchSize: 10,
          resolvers: {entityTypeName(Product): clientWinsResolver},
        ),
      );
      engines.add(engine);

      final result = await engine.sync();
      expect(result.conflicted, 1);
      expect(localAdapter.entities['Product']?['p1']?['name'], 'Local');
      final pending = await localAdapter.fetchPendingEntries('Product', 10);
      expect(pending, isEmpty);
    });

    test('state stream transitions through correct phases', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      await localAdapter.enqueue(
        SyncQueueEntry<Product>(
          id: 'q1',
          idempotencyKey: 'q1',
          data: Product(id: 'p1', version: 0),
          operation: SyncOperation.insert,
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
        config: SyncConfig(
          entityOrder: {0: Product},
          entityFromJson: {entityTypeName(Product): Product.fromJson},
          batchSize: 10,
        ),
      );
      engines.add(engine);

      final phases = <SyncPhase>[];
      final sub = engine.state.listen((s) {
        if (s is SyncInProgress) phases.add(s.phase);
      });
      await engine.sync();
      await sub.cancel();

      expect(phases.first, SyncPhase.pushing);
      expect(phases.last, SyncPhase.pulling);
    });

    test('multi-type pull applies operations for all entity types', () async {
      final localAdapter = InMemoryLocalAdapter();
      final mockRemote = MockRemoteAdapter();

      when(() => mockRemote.pull(any())).thenAnswer((invocation) async {
        final request = invocation.positionalArguments[0] as PullRequest;
        if (request.entityType == 'Product') {
          return PullResponse(
            operations: [
              RemoteOperation(
                entityType: 'Product',
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
              entityType: 'Customer',
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
        config: SyncConfig(
          entityOrder: {0: Product, 1: Customer},
          entityFromJson: {
            entityTypeName(Product): Product.fromJson,
            entityTypeName(Customer): Customer.fromJson,
          },
          batchSize: 10,
        ),
      );
      engines.add(engine);

      final result = await engine.pull();
      expect(result.pulled, 2);
      expect(localAdapter.entities['Product']?['p1']?['name'], 'Prod');
      expect(localAdapter.entities['Customer']?['c1']?['email'], 'cust@test.com');
    });
  });
}
