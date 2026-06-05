import 'dart:async';

import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:universal_sync/universal_sync.dart';
import '../shared/mocks.dart';
import '../shared/test_entities.dart';

class _MergeEntityResolver implements ConflictResolver {
  const _MergeEntityResolver();

  @override
  ConflictResolution resolve(ConflictContext context) {
    return ConflictResolution.merge(context.local);
  }
}

SyncQueueEntry<T> _entry<T extends SyncEntity>({
  required String id,
  required T data,
  SyncOperation operation = SyncOperation.insert,
  int localSequence = 0,
}) {
  return SyncQueueEntry<T>(
    id: id,
    idempotencyKey: id,
    data: data,
    operation: operation,
    version: data.version,
    localSequence: localSequence,
    createdAt: DateTime(2024),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(PushRequest([]));
  });

  group('SyncPusher (via SyncEngine)', () {
    test('returns empty result when queue is empty', () async {
      final adapter = InMemoryLocalAdapter();
      final mock = MockRemoteAdapter();
      final config = SyncConfig(
        entityOrder: {0: Product},
        entityFromJson: {entityTypeName(Product): Product.fromJson},
      );
      final engine = SyncEngine(
        localAdapter: adapter,
        remoteAdapter: mock,
        config: config,
      );

      final result = await engine.push();

      expect(result.pushed, 0);
      expect(result.failed, 0);
      expect(result.conflicted, 0);
      verifyNever(() => mock.push(any()));
    });

    test('handles single accepted entry', () async {
      final adapter = InMemoryLocalAdapter();
      final mock = MockRemoteAdapter();
      final config = SyncConfig(
        entityOrder: {0: Product},
        entityFromJson: {entityTypeName(Product): Product.fromJson},
      );

      await adapter.enqueue(
        _entry(
          id: 'e1',
          data: Product(id: 'p1'),
        ),
      );

      when(() => mock.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.accepted(entryId: 'e1', serverSequence: 1),
        ]),
      );

      final engine = SyncEngine(
        localAdapter: adapter,
        remoteAdapter: mock,
        config: config,
      );

      final result = await engine.push();

      expect(result.pushed, 1);
      expect(result.failed, 0);
      expect(result.conflicted, 0);
      verify(() => mock.push(any())).called(1);
      expect(
        (await adapter.fetchPendingEntries('Product', 10)),
        isEmpty,
      );
    });

    test('handles multiple accepted entries', () async {
      final adapter = InMemoryLocalAdapter();
      final mock = MockRemoteAdapter();
      final config = SyncConfig(
        entityOrder: {0: Product},
        entityFromJson: {entityTypeName(Product): Product.fromJson},
      );

      await adapter.enqueue(
        _entry(
          id: 'e1',
          data: Product(id: 'p1'),
          localSequence: 0,
        ),
      );
      await adapter.enqueue(
        _entry(
          id: 'e2',
          data: Product(id: 'p2'),
          localSequence: 1,
        ),
      );

      when(() => mock.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.accepted(entryId: 'e1', serverSequence: 1),
          SyncEntryResult.accepted(entryId: 'e2', serverSequence: 2),
        ]),
      );

      final engine = SyncEngine(
        localAdapter: adapter,
        remoteAdapter: mock,
        config: config,
      );

      final result = await engine.push();

      expect(result.pushed, 2);
      expect(result.failed, 0);
      expect(result.conflicted, 0);
      verify(() => mock.push(any())).called(1);
    });

    test('uses ServerWins on conflict', () async {
      final adapter = InMemoryLocalAdapter();
      final mock = MockRemoteAdapter();
      final config = SyncConfig(
        entityOrder: {0: Product},
        entityFromJson: {entityTypeName(Product): Product.fromJson},
      );

      await adapter.enqueue(
        _entry(
          id: 'e1',
          data: Product(id: 'p1', version: 0, name: 'local'),
        ),
      );

      when(() => mock.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.conflicted(
            entryId: 'e1',
            serverPayload: {'id': 'p1', 'version': 1, 'name': 'remote'},
          ),
        ]),
      );

      final engine = SyncEngine(
        localAdapter: adapter,
        remoteAdapter: mock,
        config: config,
      );

      final result = await engine.push();

      expect(result.pushed, 0);
      expect(result.failed, 0);
      expect(result.conflicted, 1);
      expect(
        (await adapter.fetchPendingEntries('Product', 10)),
        isEmpty,
      );
    });

    test('uses ClientWins on conflict and marks entry as synced', () async {
      final adapter = InMemoryLocalAdapter();
      final mock = MockRemoteAdapter();
      final config = SyncConfig(
        entityOrder: {0: Product},
        entityFromJson: {entityTypeName(Product): Product.fromJson},
        resolvers: {entityTypeName(Product): clientWinsResolver},
      );

      await adapter.enqueue(
        _entry(
          id: 'e1',
          data: Product(id: 'p1'),
        ),
      );

      when(() => mock.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.conflicted(
            entryId: 'e1',
            serverPayload: {'id': 'p1', 'version': 1},
          ),
        ]),
      );

      final engine = SyncEngine(
        localAdapter: adapter,
        remoteAdapter: mock,
        config: config,
      );

      final result = await engine.push();

      expect(result.pushed, 0);
      expect(result.failed, 0);
      expect(result.conflicted, 1);
      verify(() => mock.push(any())).called(1);
      expect(
        (await adapter.fetchPendingEntries('Product', 10)),
        isEmpty,
      );
    });

    test('handles merge resolution', () async {
      final adapter = InMemoryLocalAdapter();
      final mock = MockRemoteAdapter();
      final config = SyncConfig(
        entityOrder: {0: Product},
        entityFromJson: {entityTypeName(Product): Product.fromJson},
        resolvers: {entityTypeName(Product): _MergeEntityResolver()},
      );

      await adapter.enqueue(
        _entry(
          id: 'e1',
          data: Product(id: 'p1', version: 0, name: 'local'),
        ),
      );

      var callCount = 0;
      when(() => mock.push(any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return PushResponse([
            SyncEntryResult.conflicted(
              entryId: 'e1',
              serverPayload: {'id': 'p1', 'version': 1, 'name': 'remote'},
            ),
          ]);
        }
        return PushResponse([
          SyncEntryResult.accepted(entryId: 'merged_0', serverSequence: 2),
        ]);
      });

      final engine = SyncEngine(
        localAdapter: adapter,
        remoteAdapter: mock,
        config: config,
      );

      final result = await engine.push();

      expect(result.pushed, 1);
      expect(result.failed, 0);
      expect(result.conflicted, 1);
      verify(() => mock.push(any())).called(2);
      expect(
        (await adapter.fetchPendingEntries('Product', 10)),
        isEmpty,
      );
    });

    test('marks rejected entry as failed', () async {
      final adapter = InMemoryLocalAdapter();
      final mock = MockRemoteAdapter();
      final config = SyncConfig(
        entityOrder: {0: Product},
        entityFromJson: {entityTypeName(Product): Product.fromJson},
      );

      await adapter.enqueue(
        _entry(
          id: 'e1',
          data: Product(id: 'p1'),
        ),
      );

      when(() => mock.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.rejected(entryId: 'e1', errorMessage: 'server error'),
        ]),
      );

      final engine = SyncEngine(
        localAdapter: adapter,
        remoteAdapter: mock,
        config: config,
      );

      final result = await engine.push();

      expect(result.pushed, 0);
      expect(result.failed, 1);
      expect(result.conflicted, 0);
      expect(
        (await adapter.fetchPendingEntries('Product', 10)),
        isEmpty,
      );
    });

    test('keeps entries pending on adapter error', () async {
      final adapter = InMemoryLocalAdapter();
      final mock = MockRemoteAdapter();
      final config = SyncConfig(
        entityOrder: {0: Product},
        entityFromJson: {entityTypeName(Product): Product.fromJson},
      );

      await adapter.enqueue(
        _entry(
          id: 'e1',
          data: Product(id: 'p1'),
        ),
      );

      when(() => mock.push(any())).thenThrow(Exception('Network error'));

      final engine = SyncEngine(
        localAdapter: adapter,
        remoteAdapter: mock,
        config: config,
      );

      await expectLater(engine.push(), throwsA(isA<Exception>()));

      final pending = await adapter.fetchPendingEntries('Product', 10);
      expect(pending.length, 1);
      expect(pending[0].id, 'e1');
    });

    test('calls progress callback with correct counts', () async {
      final adapter = InMemoryLocalAdapter();
      final mock = MockRemoteAdapter();
      final config = SyncConfig(
        entityOrder: {0: Product},
        entityFromJson: {entityTypeName(Product): Product.fromJson},
      );

      await adapter.enqueue(
        _entry(
          id: 'e1',
          data: Product(id: 'p1'),
          localSequence: 0,
        ),
      );
      await adapter.enqueue(
        _entry(
          id: 'e2',
          data: Product(id: 'p2'),
          localSequence: 1,
        ),
      );

      when(() => mock.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.accepted(entryId: 'e1', serverSequence: 1),
          SyncEntryResult.accepted(entryId: 'e2', serverSequence: 2),
        ]),
      );

      final engine = SyncEngine(
        localAdapter: adapter,
        remoteAdapter: mock,
        config: config,
      );

      final progressCalls = <List<int>>[];
      final sub = engine.state.listen((s) {
        if (s is SyncInProgress && s.phase == SyncPhase.pushing && s.processed > 0) {
          progressCalls.add([s.processed, s.total]);
        }
      });
      final result = await engine.push();
      await sub.cancel();

      expect(result.pushed, 2);
      expect(progressCalls, [
        [1, 2],
        [2, 2],
      ]);
    });

    test('stops processing when cancelled', () async {
      final adapter = InMemoryLocalAdapter();
      final mock = MockRemoteAdapter();
      final config = SyncConfig(
        entityOrder: {0: Product},
        entityFromJson: {entityTypeName(Product): Product.fromJson},
        batchSize: 1,
      );

      await adapter.enqueue(
        _entry(
          id: 'e1',
          data: Product(id: 'p1'),
          localSequence: 0,
        ),
      );
      await adapter.enqueue(
        _entry(
          id: 'e2',
          data: Product(id: 'p2'),
          localSequence: 1,
        ),
      );

      final gate = Completer<void>();
      when(() => mock.push(any())).thenAnswer((_) async {
        await gate.future;
        return PushResponse([
          SyncEntryResult.accepted(entryId: 'e1', serverSequence: 1),
        ]);
      });

      final engine = SyncEngine(
        localAdapter: adapter,
        remoteAdapter: mock,
        config: config,
      );

      final pushFuture = engine.push();
      engine.cancel();
      gate.complete();
      final result = await pushFuture;

      expect(result.pushed, 1);
      expect(result.failed, 0);
      expect(result.conflicted, 0);
    });

    group('batch processing', () {
      test('pushes entries in batches of config.batchSize', () async {
        final adapter = InMemoryLocalAdapter();
        final mock = MockRemoteAdapter();
        final config = SyncConfig(
          entityOrder: {0: Product},
          entityFromJson: {entityTypeName(Product): Product.fromJson},
          batchSize: 2,
        );

        for (int i = 0; i < 5; i++) {
          await adapter.enqueue(
            _entry(
              id: 'e$i',
              data: Product(id: 'p$i'),
              localSequence: i,
            ),
          );
        }

        final batchSizes = <int>[];
        when(() => mock.push(any())).thenAnswer((invocation) async {
          final request = invocation.positionalArguments[0] as PushRequest;
          batchSizes.add(request.entries.length);
          return PushResponse(
            request.entries.map((e) => SyncEntryResult.accepted(entryId: e.id, serverSequence: 1)).toList(),
          );
        });

        final engine = SyncEngine(
          localAdapter: adapter,
          remoteAdapter: mock,
          config: config,
        );

        final result = await engine.push();
        expect(result.pushed, 5);
        expect(batchSizes, [2, 2, 1]);
        verify(() => mock.push(any())).called(3);
      });

      test('processes all entries across multiple batches', () async {
        final adapter = InMemoryLocalAdapter();
        final mock = MockRemoteAdapter();
        final config = SyncConfig(
          entityOrder: {0: Product},
          entityFromJson: {entityTypeName(Product): Product.fromJson},
          batchSize: 3,
        );

        for (int i = 0; i < 7; i++) {
          await adapter.enqueue(
            _entry(
              id: 'e$i',
              data: Product(id: 'p$i'),
              localSequence: i,
            ),
          );
        }

        when(() => mock.push(any())).thenAnswer((invocation) async {
          final request = invocation.positionalArguments[0] as PushRequest;
          return PushResponse(
            request.entries.map((e) => SyncEntryResult.accepted(entryId: e.id, serverSequence: 1)).toList(),
          );
        });

        final engine = SyncEngine(
          localAdapter: adapter,
          remoteAdapter: mock,
          config: config,
        );

        final result = await engine.push();
        expect(result.pushed, 7);
      });
    });

    group('entity order', () {
      test('pushes entries in entityOrder sequence', () async {
        final adapter = InMemoryLocalAdapter();
        final mock = MockRemoteAdapter();
        final config = SyncConfig(
          entityOrder: {0: Product, 1: Customer},
          entityFromJson: {
            entityTypeName(Product): Product.fromJson,
            entityTypeName(Customer): Customer.fromJson,
          },
        );

        await adapter.enqueue(
          _entry(
            id: 'e1',
            data: Product(id: 'p1'),
            localSequence: 2,
          ),
        );
        await adapter.enqueue(
          _entry<Customer>(
            id: 'e2',
            data: Customer(id: 'c1'),
            localSequence: 1,
          ),
        );

        final pushedTypes = <String>[];
        when(() => mock.push(any())).thenAnswer((invocation) async {
          final request = invocation.positionalArguments[0] as PushRequest;
          pushedTypes.addAll(request.entries.map((e) => e.entityType));
          return PushResponse(
            request.entries.map((e) => SyncEntryResult.accepted(entryId: e.id, serverSequence: 1)).toList(),
          );
        });

        final engine = SyncEngine(
          localAdapter: adapter,
          remoteAdapter: mock,
          config: config,
        );

        await engine.push();
        expect(pushedTypes, ['Product', 'Customer']);
      });

      test('does not push entries for entity type not in entityOrder', () async {
        final adapter = InMemoryLocalAdapter();
        final mock = MockRemoteAdapter();
        final config = SyncConfig(
          entityOrder: {0: Product},
          entityFromJson: {entityTypeName(Product): Product.fromJson},
        );

        await adapter.enqueue(
          _entry(
            id: 'e1',
            data: Product(id: 'p1'),
            localSequence: 1,
          ),
        );
        await adapter.enqueue(
          _entry<Customer>(
            id: 'e2',
            data: Customer(id: 'c1'),
            localSequence: 2,
          ),
        );

        final pushedTypes = <String>[];
        when(() => mock.push(any())).thenAnswer((invocation) async {
          final request = invocation.positionalArguments[0] as PushRequest;
          pushedTypes.addAll(request.entries.map((e) => e.entityType));
          return PushResponse(
            request.entries.map((e) => SyncEntryResult.accepted(entryId: e.id, serverSequence: 1)).toList(),
          );
        });

        final engine = SyncEngine(
          localAdapter: adapter,
          remoteAdapter: mock,
          config: config,
        );

        await engine.push();
        expect(pushedTypes, ['Product']);
      });
    });

    group('order and dedup', () {
      test('entries pushed in localSequence ascending order', () async {
        final adapter = InMemoryLocalAdapter();
        final mock = MockRemoteAdapter();
        final config = SyncConfig(
          entityOrder: {0: Product},
          entityFromJson: {entityTypeName(Product): Product.fromJson},
        );

        await adapter.enqueue(
          _entry(
            id: 'e2',
            data: Product(id: 'p2'),
            localSequence: 2,
          ),
        );
        await adapter.enqueue(
          _entry(
            id: 'e1',
            data: Product(id: 'p1'),
            localSequence: 1,
          ),
        );

        final order = <String>[];
        when(() => mock.push(any())).thenAnswer((invocation) async {
          final request = invocation.positionalArguments[0] as PushRequest;
          order.addAll(request.entries.map((e) => e.id));
          return PushResponse(
            request.entries.map((e) => SyncEntryResult.accepted(entryId: e.id, serverSequence: 1)).toList(),
          );
        });

        final engine = SyncEngine(
          localAdapter: adapter,
          remoteAdapter: mock,
          config: config,
        );

        await engine.push();
        expect(order, ['e1', 'e2']);
      });

      test('ClientWins preserves local data in the database', () async {
        final adapter = InMemoryLocalAdapter();
        final mock = MockRemoteAdapter();
        final config = SyncConfig(
          entityOrder: {0: Product},
          entityFromJson: {entityTypeName(Product): Product.fromJson},
          resolvers: {entityTypeName(Product): clientWinsResolver},
        );

        await adapter.upsertEntity('Product', {'id': 'p1', 'version': 2, 'name': 'Local'});
        await adapter.enqueue(
          _entry(
            id: 'e1',
            data: Product(id: 'p1', version: 2),
          ),
        );

        when(() => mock.push(any())).thenAnswer(
          (_) async => PushResponse([
            SyncEntryResult.conflicted(
              entryId: 'e1',
              serverPayload: {'id': 'p1', 'version': 3, 'name': 'Remote'},
            ),
          ]),
        );

        expect(adapter.entities['Product']?['p1']?['name'], 'Local');

        final engine = SyncEngine(
          localAdapter: adapter,
          remoteAdapter: mock,
          config: config,
        );

        final result = await engine.push();
        expect(result.pushed, 0);
        expect(result.failed, 0);
        expect(result.conflicted, 1);

        final stored = adapter.entities['Product']?['p1'];
        expect(stored?['name'], 'Local');
      });

      test('second batch is sent only after first batch is confirmed', () async {
        final adapter = InMemoryLocalAdapter();
        final mock = MockRemoteAdapter();
        final config = SyncConfig(
          entityOrder: {0: Product},
          entityFromJson: {entityTypeName(Product): Product.fromJson},
          batchSize: 2,
        );

        for (int i = 0; i < 4; i++) {
          await adapter.enqueue(
            _entry(
              id: 'e$i',
              data: Product(id: 'p$i'),
              localSequence: i,
            ),
          );
        }

        final callOrder = <int>[];
        when(() => mock.push(any())).thenAnswer((invocation) async {
          final request = invocation.positionalArguments[0] as PushRequest;
          callOrder.add(request.entries.length);
          return PushResponse(
            request.entries.map((e) => SyncEntryResult.accepted(entryId: e.id, serverSequence: 1)).toList(),
          );
        });

        final engine = SyncEngine(
          localAdapter: adapter,
          remoteAdapter: mock,
          config: config,
        );

        await engine.push();
        expect(callOrder, [2, 2]);
        verify(() => mock.push(any())).called(2);
      });

      test('onProgress callback receives correct counts', () async {
        final adapter = InMemoryLocalAdapter();
        final mock = MockRemoteAdapter();
        final config = SyncConfig(
          entityOrder: {0: Product},
          entityFromJson: {entityTypeName(Product): Product.fromJson},
        );

        for (int i = 0; i < 3; i++) {
          await adapter.enqueue(
            _entry(
              id: 'e$i',
              data: Product(id: 'p$i'),
              localSequence: i,
            ),
          );
        }

        when(() => mock.push(any())).thenAnswer(
          (_) async => PushResponse([
            SyncEntryResult.accepted(entryId: 'e0', serverSequence: 1),
            SyncEntryResult.accepted(entryId: 'e1', serverSequence: 2),
            SyncEntryResult.accepted(entryId: 'e2', serverSequence: 3),
          ]),
        );

        final progressValues = <int>[];
        final engine = SyncEngine(
          localAdapter: adapter,
          remoteAdapter: mock,
          config: config,
        );

        final sub = engine.state.listen((s) {
          if (s is SyncInProgress && s.phase == SyncPhase.pushing && s.processed > 0) {
            progressValues.add(s.processed);
          }
        });

        await engine.push();
        await sub.cancel();

        expect(progressValues, [1, 2, 3]);
      });
    });
  });
}
