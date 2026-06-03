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

class _MergeEntityResolver implements ConflictResolver<SyncEntity> {
  const _MergeEntityResolver();

  @override
  ConflictResolution<SyncEntity> resolve(ConflictContext<SyncEntity> context) {
    return ConflictResolution.merge(context.local);
  }
}

SyncQueueEntry _entry({
  required String id,
  required String entityId,
  int version = 0,
  String? payload,
  SyncOperation operation = SyncOperation.insert,
  int localSequence = 0,
  int retryCount = 0,
}) {
  return SyncQueueEntry(
    id: id,
    entityType: '_Product',
    entityId: entityId,
    operation: operation,
    payload: payload ?? jsonEncode({'id': entityId, 'version': version}),
    version: version,
    localSequence: localSequence,
    createdAt: DateTime(2024),
    retryCount: retryCount,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(PushRequest([]));
  });

  group('SyncPusher', () {
    test('returns empty result when queue is empty', () async {
      final adapter = InMemoryLocalAdapter();
      final mock = MockRemoteAdapter();
      final config = SyncConfig(entityOrder: [_Product]);
      final pusher = SyncPusher(
        localAdapter: adapter,
        remoteAdapter: mock,
        config: config,
        entityFromJson: {_Product: _Product.fromJson},
      );

      final result = await pusher.run();

      expect(result.pushed, 0);
      expect(result.failed, 0);
      expect(result.conflicted, 0);
      verifyNever(() => mock.push(any()));
    });

    test('handles single accepted entry', () async {
      final adapter = InMemoryLocalAdapter();
      final mock = MockRemoteAdapter();
      final config = SyncConfig(entityOrder: [_Product]);

      await adapter.enqueue(_entry(id: 'e1', entityId: 'p1'));

      when(() => mock.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.accepted(entryId: 'e1', serverSequence: 1),
        ]),
      );

      final pusher = SyncPusher(
        localAdapter: adapter,
        remoteAdapter: mock,
        config: config,
        entityFromJson: {_Product: _Product.fromJson},
      );

      final result = await pusher.run();

      expect(result.pushed, 1);
      expect(result.failed, 0);
      expect(result.conflicted, 0);
      verify(() => mock.push(any())).called(1);
      expect(
        (await adapter.fetchPendingEntries('_Product', 10)),
        isEmpty,
      );
    });

    test('handles multiple accepted entries', () async {
      final adapter = InMemoryLocalAdapter();
      final mock = MockRemoteAdapter();
      final config = SyncConfig(entityOrder: [_Product]);

      await adapter.enqueue(_entry(id: 'e1', entityId: 'p1', localSequence: 0));
      await adapter.enqueue(_entry(id: 'e2', entityId: 'p2', localSequence: 1));

      when(() => mock.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.accepted(entryId: 'e1', serverSequence: 1),
          SyncEntryResult.accepted(entryId: 'e2', serverSequence: 2),
        ]),
      );

      final pusher = SyncPusher(
        localAdapter: adapter,
        remoteAdapter: mock,
        config: config,
        entityFromJson: {_Product: _Product.fromJson},
      );

      final result = await pusher.run();

      expect(result.pushed, 2);
      expect(result.failed, 0);
      expect(result.conflicted, 0);
      verify(() => mock.push(any())).called(1);
    });

    test('uses ServerWins on conflict', () async {
      final adapter = InMemoryLocalAdapter();
      final mock = MockRemoteAdapter();
      final config = SyncConfig(entityOrder: [_Product]);

      await adapter.enqueue(
        _entry(
          id: 'e1',
          entityId: 'p1',
          payload: jsonEncode({'id': 'p1', 'version': 0, 'name': 'local'}),
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

      final pusher = SyncPusher(
        localAdapter: adapter,
        remoteAdapter: mock,
        config: config,
        entityFromJson: {_Product: _Product.fromJson},
      );

      final result = await pusher.run();

      expect(result.pushed, 0);
      expect(result.failed, 0);
      expect(result.conflicted, 1);
      expect(
        (await adapter.fetchPendingEntries('_Product', 10)),
        isEmpty,
      );
    });

    test('uses ClientWins on conflict and re-queues entry', () async {
      final adapter = InMemoryLocalAdapter();
      final mock = MockRemoteAdapter();
      final config = SyncConfig(entityOrder: [_Product], maxRetries: 3);

      await adapter.enqueue(_entry(id: 'e1', entityId: 'p1', retryCount: 0));

      var callCount = 0;
      when(() => mock.push(any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return PushResponse([
            SyncEntryResult.conflicted(
              entryId: 'e1',
              serverPayload: {'id': 'p1', 'version': 1},
            ),
          ]);
        }
        return PushResponse([
          SyncEntryResult.accepted(entryId: 'e1', serverSequence: 2),
        ]);
      });

      final pusher = SyncPusher(
        localAdapter: adapter,
        remoteAdapter: mock,
        config: config,
        entityFromJson: {_Product: _Product.fromJson},
        resolvers: {_Product: ClientWinsResolver<SyncEntity>()},
      );

      final result = await pusher.run();

      expect(result.pushed, 1);
      expect(result.failed, 0);
      expect(result.conflicted, 1);
    });

    test('marks entry as failed when ClientWins exceeds max retries', () async {
      final adapter = InMemoryLocalAdapter();
      final mock = MockRemoteAdapter();
      final config = SyncConfig(entityOrder: [_Product], maxRetries: 3);

      await adapter.enqueue(_entry(id: 'e1', entityId: 'p1', retryCount: 2));

      when(() => mock.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.conflicted(
            entryId: 'e1',
            serverPayload: {'id': 'p1', 'version': 2},
          ),
        ]),
      );

      final pusher = SyncPusher(
        localAdapter: adapter,
        remoteAdapter: mock,
        config: config,
        entityFromJson: {_Product: _Product.fromJson},
        resolvers: {_Product: ClientWinsResolver<SyncEntity>()},
      );

      final result = await pusher.run();

      expect(result.pushed, 0);
      expect(result.failed, 0);
      expect(result.conflicted, 1);
      expect(
        (await adapter.fetchPendingEntries('_Product', 10)),
        isEmpty,
      );
    });

    test('handles merge resolution', () async {
      final adapter = InMemoryLocalAdapter();
      final mock = MockRemoteAdapter();
      final config = SyncConfig(entityOrder: [_Product]);

      await adapter.enqueue(
        _entry(
          id: 'e1',
          entityId: 'p1',
          payload: jsonEncode({'id': 'p1', 'version': 0, 'name': 'local'}),
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

      final pusher = SyncPusher(
        localAdapter: adapter,
        remoteAdapter: mock,
        config: config,
        entityFromJson: {_Product: _Product.fromJson},
        resolvers: {_Product: _MergeEntityResolver()},
      );

      final result = await pusher.run();

      expect(result.pushed, 1);
      expect(result.failed, 0);
      expect(result.conflicted, 1);
      verify(() => mock.push(any())).called(2);
      expect(
        (await adapter.fetchPendingEntries('_Product', 10)),
        isEmpty,
      );
    });

    test('re-queues rejected entry with retryCount incremented', () async {
      final adapter = InMemoryLocalAdapter();
      final mock = MockRemoteAdapter();
      final config = SyncConfig(entityOrder: [_Product], maxRetries: 3);

      await adapter.enqueue(_entry(id: 'e1', entityId: 'p1', retryCount: 0));

      var callCount = 0;
      when(() => mock.push(any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return PushResponse([
            SyncEntryResult.rejected(entryId: 'e1', errorMessage: 'server error'),
          ]);
        }
        return PushResponse([
          SyncEntryResult.accepted(entryId: 'e1', serverSequence: 1),
        ]);
      });

      final pusher = SyncPusher(
        localAdapter: adapter,
        remoteAdapter: mock,
        config: config,
        entityFromJson: {_Product: _Product.fromJson},
      );

      final result = await pusher.run();

      expect(result.pushed, 1);
      expect(result.failed, 1);
      expect(result.conflicted, 0);
    });

    test('marks rejected entry as failed when max retries reached', () async {
      final adapter = InMemoryLocalAdapter();
      final mock = MockRemoteAdapter();
      final config = SyncConfig(entityOrder: [_Product], maxRetries: 3);

      await adapter.enqueue(_entry(id: 'e1', entityId: 'p1', retryCount: 2));

      when(() => mock.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.rejected(entryId: 'e1', errorMessage: 'server error'),
        ]),
      );

      final pusher = SyncPusher(
        localAdapter: adapter,
        remoteAdapter: mock,
        config: config,
        entityFromJson: {_Product: _Product.fromJson},
      );

      final result = await pusher.run();

      expect(result.pushed, 0);
      expect(result.failed, 1);
      expect(result.conflicted, 0);
      expect(
        (await adapter.fetchPendingEntries('_Product', 10)),
        isEmpty,
      );
    });

    test('resets processing entries on adapter error', () async {
      final adapter = InMemoryLocalAdapter();
      final mock = MockRemoteAdapter();
      final config = SyncConfig(entityOrder: [_Product]);

      await adapter.enqueue(_entry(id: 'e1', entityId: 'p1'));

      when(() => mock.push(any())).thenThrow(Exception('Network error'));

      final pusher = SyncPusher(
        localAdapter: adapter,
        remoteAdapter: mock,
        config: config,
        entityFromJson: {_Product: _Product.fromJson},
      );

      await expectLater(pusher.run(), throwsA(isA<Exception>()));

      final pending = await adapter.fetchPendingEntries('_Product', 10);
      expect(pending.length, 1);
      expect(pending[0].id, 'e1');
    });

    test('calls progress callback with correct counts', () async {
      final adapter = InMemoryLocalAdapter();
      final mock = MockRemoteAdapter();
      final config = SyncConfig(entityOrder: [_Product]);

      await adapter.enqueue(_entry(id: 'e1', entityId: 'p1', localSequence: 0));
      await adapter.enqueue(_entry(id: 'e2', entityId: 'p2', localSequence: 1));

      when(() => mock.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.accepted(entryId: 'e1', serverSequence: 1),
          SyncEntryResult.accepted(entryId: 'e2', serverSequence: 2),
        ]),
      );

      final pusher = SyncPusher(
        localAdapter: adapter,
        remoteAdapter: mock,
        config: config,
        entityFromJson: {_Product: _Product.fromJson},
      );

      final progressCalls = <List<int>>[];
      final result = await pusher.run(
        onProgress: (processed, total) => progressCalls.add([processed, total]),
      );

      expect(result.pushed, 2);
      expect(progressCalls, [
        [1, 2],
        [2, 2],
      ]);
    });

    test('stops processing when cancelled', () async {
      final adapter = InMemoryLocalAdapter();
      final mock = MockRemoteAdapter();
      final config = SyncConfig(entityOrder: [_Product], batchSize: 1);

      await adapter.enqueue(_entry(id: 'e1', entityId: 'p1', localSequence: 0));
      await adapter.enqueue(_entry(id: 'e2', entityId: 'p2', localSequence: 1));

      when(() => mock.push(any())).thenAnswer(
        (_) async => PushResponse([
          SyncEntryResult.accepted(entryId: 'e1', serverSequence: 1),
        ]),
      );

      var cancel = false;
      final pusher = SyncPusher(
        localAdapter: adapter,
        remoteAdapter: mock,
        config: config,
        entityFromJson: {_Product: _Product.fromJson},
      );

      final result = await pusher.run(
        isCancelled: () async {
          if (cancel) return true;
          cancel = true;
          return false;
        },
      );

      expect(result.pushed, 1);
      expect(result.failed, 0);
      expect(result.conflicted, 0);
    });
  });
}
