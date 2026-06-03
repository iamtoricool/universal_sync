import 'dart:convert';

import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:universal_sync/universal_sync.dart';
import 'package:universal_sync/src/engine/sync_engine.dart';

class MockRemoteAdapter extends Mock implements RemoteAdapter {}

class _Product extends SyncEntity {
  final String id;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
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
  final String id;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
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
  });
}
