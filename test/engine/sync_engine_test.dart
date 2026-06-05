import 'dart:async';

import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:universal_sync/universal_sync.dart';
import '../shared/mocks.dart';
import '../shared/test_entities.dart';

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

SyncConfig _testConfig() => SyncConfig(
  entityOrder: {0: TestEntity},
  entityFromJson: {entityTypeName(TestEntity): TestEntity.fromJson},
);

void main() {
  setUpAll(() {
    registerFallbackValue(PushRequest([]));
    registerFallbackValue(PullRequest(entityType: '', sinceSequence: 0));
  });

  late InMemoryLocalAdapter localAdapter;
  late MockRemoteAdapter mockRemoteAdapter;
  final engines = <SyncEngine>[];

  setUp(() {
    localAdapter = InMemoryLocalAdapter();
    mockRemoteAdapter = MockRemoteAdapter();
  });

  tearDown(() {
    for (final e in engines) {
      try {
        e.dispose();
      } catch (_) {}
    }
    engines.clear();
  });

  SyncEngine engine({
    OnSyncStart? onSyncStart,
    OnSyncComplete? onSyncComplete,
    OnError? onError,
  }) {
    final e = SyncEngine(
      localAdapter: localAdapter,
      remoteAdapter: mockRemoteAdapter,
      config: _testConfig(),
      onSyncStart: onSyncStart,
      onSyncComplete: onSyncComplete,
      onError: onError,
    );
    engines.add(e);
    return e;
  }

  group('SyncEngine', () {
    test('initial state is SyncIdle', () {
      final e = engine();
      expect(e.currentState, isA<SyncIdle>());
    });

    test('SyncIdle.lastSyncedAt is null before first sync', () {
      final e = engine();
      final state = e.currentState as SyncIdle;
      expect(state.lastSyncedAt, isNull);
    });

    test('sync() runs push then pull', () async {
      await localAdapter.enqueue(
        _entry(
          id: 'e1',
          data: TestEntity(id: 'p1'),
        ),
      );

      when(() => mockRemoteAdapter.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.accepted(entryId: 'e1', serverSequence: 1),
        ]),
      );
      when(() => mockRemoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(operations: [], latestSequence: 0),
      );

      final e = engine();
      final result = await e.sync();

      expect(result.pushed, 1);
      expect(result.pulled, 0);
      verify(() => mockRemoteAdapter.push(any())).called(1);
      verify(() => mockRemoteAdapter.pull(any())).called(1);
    });

    test('push() runs push only', () async {
      await localAdapter.enqueue(
        _entry(
          id: 'e1',
          data: TestEntity(id: 'p1'),
        ),
      );

      when(() => mockRemoteAdapter.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.accepted(entryId: 'e1', serverSequence: 1),
        ]),
      );

      final e = engine();
      final result = await e.push();

      expect(result.pushed, 1);
      expect(result.pulled, 0);
      verify(() => mockRemoteAdapter.push(any())).called(1);
      verifyNever(() => mockRemoteAdapter.pull(any()));
    });

    test('pull() runs pull only', () async {
      when(() => mockRemoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(operations: [], latestSequence: 0),
      );

      final e = engine();
      final result = await e.pull();

      expect(result.pushed, 0);
      expect(result.pulled, 0);
      verifyNever(() => mockRemoteAdapter.push(any()));
      verify(() => mockRemoteAdapter.pull(any())).called(1);
    });

    test('sync() returns isClean when no errors or conflicts', () async {
      when(() => mockRemoteAdapter.push(any())).thenAnswer(
        (_) async => PushResponse([]),
      );
      when(() => mockRemoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(operations: [], latestSequence: 0),
      );

      final e = engine();
      final result = await e.sync();

      expect(result.isClean, isTrue);
    });

    test('SyncIdle.lastSyncedAt is set after successful sync', () async {
      when(() => mockRemoteAdapter.push(any())).thenAnswer(
        (_) async => PushResponse([]),
      );
      when(() => mockRemoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(operations: [], latestSequence: 0),
      );

      final e = engine();
      await e.sync();

      final state = e.currentState as SyncIdle;
      expect(state.lastSyncedAt, isNotNull);
    });

    test('concurrent sync() throws StateError', () async {
      await localAdapter.enqueue(
        _entry(
          id: 'e1',
          data: TestEntity(id: 'p1'),
        ),
      );

      late Completer<void> gate;
      gate = Completer<void>();
      when(() => mockRemoteAdapter.push(any())).thenAnswer((inv) async {
        final req = inv.positionalArguments[0] as PushRequest;
        await gate.future;
        return PushResponse(
          req.entries
              .map(
                (e) => SyncEntryResult.accepted(entryId: e.id, serverSequence: 1),
              )
              .toList(),
        );
      });
      when(() => mockRemoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(operations: [], latestSequence: 0),
      );

      final e = engine();
      final sync1 = e.sync();

      await expectLater(
        e.sync(),
        throwsA(isA<StateError>()),
      );

      gate.complete();
      await sync1;
    });

    test('error in push emits SyncError', () async {
      await localAdapter.enqueue(
        _entry(
          id: 'e1',
          data: TestEntity(id: 'p1'),
        ),
      );

      when(() => mockRemoteAdapter.push(any())).thenThrow(Exception('Push failed'));

      final emitted = <SyncState>[];
      final e = engine();
      final sub = e.state.listen(emitted.add);

      await expectLater(
        e.sync(),
        throwsA(isA<Exception>()),
      );
      await Future.delayed(Duration.zero);

      expect(emitted.any((s) => s is SyncError), isTrue);
      expect(e.currentState, isA<SyncError>());
      await sub.cancel();
    });

    test('error in pull emits SyncError', () async {
      await localAdapter.enqueue(
        _entry(
          id: 'e1',
          data: TestEntity(id: 'p1'),
        ),
      );

      when(() => mockRemoteAdapter.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.accepted(entryId: 'e1', serverSequence: 1),
        ]),
      );
      when(() => mockRemoteAdapter.pull(any())).thenThrow(Exception('Pull failed'));

      final emitted = <SyncState>[];
      final e = engine();
      final sub = e.state.listen(emitted.add);

      await expectLater(
        e.sync(),
        throwsA(isA<Exception>()),
      );
      await Future.delayed(Duration.zero);

      expect(emitted.any((s) => s is SyncError), isTrue);
      expect(e.currentState, isA<SyncError>());
      await sub.cancel();
    });

    test('state stream emits correct sequence for sync()', () async {
      await localAdapter.enqueue(
        _entry(
          id: 'e1',
          data: TestEntity(id: 'p1'),
        ),
      );

      when(() => mockRemoteAdapter.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.accepted(entryId: 'e1', serverSequence: 1),
        ]),
      );
      when(() => mockRemoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(operations: [], latestSequence: 0),
      );

      final states = <SyncState>[];
      final e = engine();
      final sub = e.state.listen(states.add);

      await e.sync();
      await Future.delayed(Duration.zero);

      expect(states.length, greaterThanOrEqualTo(4));
      expect(states[0], isA<SyncIdle>());
      expect(states[1], isA<SyncInProgress>());
      expect((states[1] as SyncInProgress).phase, SyncPhase.pushing);
      expect(states[states.length - 2], isA<SyncInProgress>());
      expect((states[states.length - 2] as SyncInProgress).phase, SyncPhase.pulling);
      expect(states.last, isA<SyncIdle>());

      await sub.cancel();
    });

    test('cancel() stops sync and returns partial result', () async {
      await localAdapter.enqueue(
        _entry(
          id: 'e1',
          data: TestEntity(id: 'p1'),
        ),
      );

      when(() => mockRemoteAdapter.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.accepted(entryId: 'e1', serverSequence: 1),
        ]),
      );

      final e = engine();
      final syncFuture = e.sync();
      e.cancel();
      final result = await syncFuture;

      expect(result.pushed, 1);
      expect(result.pulled, 0);
      verifyNever(() => mockRemoteAdapter.pull(any()));
    });

    test('event hooks fire at correct times', () async {
      await localAdapter.enqueue(
        _entry(
          id: 'e1',
          data: TestEntity(id: 'p1'),
        ),
      );

      when(() => mockRemoteAdapter.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.accepted(entryId: 'e1', serverSequence: 1),
        ]),
      );
      when(() => mockRemoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(operations: [], latestSequence: 0),
      );

      final hookOrder = <String>[];
      final e = engine(
        onSyncStart: () => hookOrder.add('start'),
        onSyncComplete: (_) => hookOrder.add('complete'),
      );

      await e.sync();

      expect(hookOrder, ['start', 'complete']);
    });

    test('disposed engine throws StateError on sync()', () async {
      final e = engine();
      e.dispose();

      await expectLater(
        e.sync(),
        throwsA(isA<StateError>()),
      );
    });

    test('state returns to SyncIdle after error on next successful sync', () async {
      await localAdapter.enqueue(
        _entry(
          id: 'e1',
          data: TestEntity(id: 'p1'),
        ),
      );

      when(() => mockRemoteAdapter.push(any())).thenThrow(Exception('Push failed'));
      final e1 = engine();
      await expectLater(e1.sync(), throwsA(isA<Exception>()));

      final e2 = engine();
      await localAdapter.enqueue(
        _entry(
          id: 'e2',
          data: TestEntity(id: 'p2'),
        ),
      );
      when(() => mockRemoteAdapter.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.accepted(entryId: 'e2', serverSequence: 1),
        ]),
      );
      when(() => mockRemoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(operations: [], latestSequence: 0),
      );

      await e2.sync();
      expect(e2.currentState, isA<SyncIdle>());
    });

    test('SyncInProgress reports processed and total during push', () async {
      await localAdapter.enqueue(
        _entry(
          id: 'e1',
          data: TestEntity(id: 'p1'),
        ),
      );
      await localAdapter.enqueue(
        _entry(
          id: 'e2',
          data: TestEntity(id: 'p2'),
        ),
      );

      when(() => mockRemoteAdapter.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.accepted(entryId: 'e1', serverSequence: 1),
          SyncEntryResult.accepted(entryId: 'e2', serverSequence: 2),
        ]),
      );
      when(() => mockRemoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(operations: [], latestSequence: 0),
      );

      final states = <SyncInProgress>[];
      final e = engine();
      final sub = e.state.where((s) => s is SyncInProgress).cast<SyncInProgress>().listen(states.add);
      await e.sync();
      await sub.cancel();

      final pushStates = states.where((s) => s.phase == SyncPhase.pushing).toList();
      expect(pushStates.length, greaterThanOrEqualTo(2));
      expect(pushStates.last.processed, 2);
      expect(pushStates.last.total, 2);
      expect(pushStates.last.progress, 1.0);
    });

    test('isClean is false when push has errors', () async {
      await localAdapter.enqueue(
        _entry(
          id: 'e1',
          data: TestEntity(id: 'p1'),
        ),
      );

      when(() => mockRemoteAdapter.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.rejected(entryId: 'e1'),
        ]),
      );

      final e = engine();
      final result = await e.push();
      expect(result.isClean, isFalse);
    });

    test('skip push when queue is empty, still pull remote', () async {
      when(() => mockRemoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(operations: [], latestSequence: 0),
      );

      final result = await engine().sync();
      expect(result.pushed, 0);
      expect(result.pulled, 0);
      verifyNever(() => mockRemoteAdapter.push(any()));
      verify(() => mockRemoteAdapter.pull(any())).called(1);
    });

    test('dispose closes the state stream', () async {
      final e = engine();
      final done = e.state.drain<dynamic>();
      e.dispose();
      await expectLater(done, completes);
    });

    test('SyncResult duration is greater than zero after sync', () async {
      when(() => mockRemoteAdapter.push(any())).thenAnswer(
        (_) async => PushResponse([]),
      );
      when(() => mockRemoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(operations: [], latestSequence: 0),
      );

      final result = await engine().sync();
      expect(result.duration, greaterThan(Duration.zero));
    });
  });
}
