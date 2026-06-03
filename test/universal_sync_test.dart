import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:universal_sync/universal_sync.dart';
import 'package:universal_sync/src/engine/sync_engine.dart';

class MockRemoteAdapter extends Mock implements RemoteAdapter {}

class _TestEntity extends SyncEntity {
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

  _TestEntity({
    required this.id,
    this.version = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
  }) : createdAt = createdAt ?? DateTime(2024),
       updatedAt = updatedAt ?? DateTime(2024);

  @override
  Map<String, dynamic> toSyncJson() => {
    'id': id,
    'version': version,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory _TestEntity.fromJson(Map<String, dynamic> json) => _TestEntity(
    id: json['id'] as String,
    version: json['version'] as int? ?? 0,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(PushRequest([]));
    registerFallbackValue(PullRequest(entityType: '', sinceSequence: 0));
  });

  late InMemoryLocalAdapter localAdapter;
  late MockRemoteAdapter mockRemoteAdapter;

  setUp(() {
    localAdapter = InMemoryLocalAdapter();
    mockRemoteAdapter = MockRemoteAdapter();
  });

  group('UniversalSync', () {
    test('constructor stores references, init then engine returns valid engine', () async {
      final us = UniversalSync(
        localAdapter: localAdapter,
        remoteAdapter: mockRemoteAdapter,
        config: SyncConfig(entityOrder: [_TestEntity]),
        entityFromJson: {_TestEntity: _TestEntity.fromJson},
      );

      await us.init();
      expect(us.engine, isA<SyncEngine>());
    });

    test('init() succeeds with complete fromJson map', () async {
      final us = UniversalSync(
        localAdapter: localAdapter,
        remoteAdapter: mockRemoteAdapter,
        config: SyncConfig(entityOrder: [_TestEntity]),
        entityFromJson: {_TestEntity: _TestEntity.fromJson},
      );

      await us.init();
      // No error thrown
    });

    test('init() throws ArgumentError with missing fromJson entry', () async {
      final us = UniversalSync(
        localAdapter: localAdapter,
        remoteAdapter: mockRemoteAdapter,
        config: SyncConfig(entityOrder: [_TestEntity]),
        entityFromJson: {},
      );

      await expectLater(
        us.init(),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('engine getter is lazy - returns same instance', () async {
      final us = UniversalSync(
        localAdapter: localAdapter,
        remoteAdapter: mockRemoteAdapter,
        config: SyncConfig(entityOrder: [_TestEntity]),
        entityFromJson: {_TestEntity: _TestEntity.fromJson},
      );

      await us.init();
      expect(identical(us.engine, us.engine), isTrue);
    });

    test('engine getter throws StateError before init()', () {
      final us = UniversalSync(
        localAdapter: localAdapter,
        remoteAdapter: mockRemoteAdapter,
        config: SyncConfig(entityOrder: [_TestEntity]),
        entityFromJson: {_TestEntity: _TestEntity.fromJson},
      );

      expect(
        () => us.engine,
        throwsA(isA<StateError>()),
      );
    });

    test('dispose() shuts down engine', () async {
      final us = UniversalSync(
        localAdapter: localAdapter,
        remoteAdapter: mockRemoteAdapter,
        config: SyncConfig(entityOrder: [_TestEntity]),
        entityFromJson: {_TestEntity: _TestEntity.fromJson},
      );

      await us.init();
      final engine = us.engine;
      await us.dispose();

      expect(
        () => engine.sync(),
        throwsA(isA<StateError>()),
      );
    });

    test('full lifecycle: init -> engine.sync() -> dispose', () async {
      when(() => mockRemoteAdapter.push(any())).thenAnswer(
        (_) async => PushResponse([]),
      );
      when(() => mockRemoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(operations: [], latestSequence: 0),
      );

      final us = UniversalSync(
        localAdapter: localAdapter,
        remoteAdapter: mockRemoteAdapter,
        config: SyncConfig(entityOrder: [_TestEntity]),
        entityFromJson: {_TestEntity: _TestEntity.fromJson},
      );

      await us.init();
      final result = await us.engine.sync();

      expect(result.pushed, 0);
      expect(result.pulled, 0);
      expect(result.failed, 0);
      expect(result.conflicted, 0);

      await us.dispose();
      expect(
        () => us.engine,
        throwsA(isA<StateError>()),
      );
    });
  });
}
