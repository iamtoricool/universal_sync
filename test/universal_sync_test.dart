import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:universal_sync/universal_sync.dart';
import 'shared/mocks.dart';
import 'shared/test_entities.dart';

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

  setUp(() {
    localAdapter = InMemoryLocalAdapter();
    mockRemoteAdapter = MockRemoteAdapter();
  });

  group('SyncEngine', () {
    test('dispose() shuts down engine', () async {
      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: mockRemoteAdapter,
        config: _testConfig(),
      );

      engine.dispose();

      await expectLater(
        engine.sync(),
        throwsA(isA<StateError>()),
      );
    });

    test('full lifecycle: engine.sync() -> dispose', () async {
      when(() => mockRemoteAdapter.push(any())).thenAnswer(
        (_) async => PushResponse([]),
      );
      when(() => mockRemoteAdapter.pull(any())).thenAnswer(
        (_) async => PullResponse(operations: [], latestSequence: 0),
      );

      final engine = SyncEngine(
        localAdapter: localAdapter,
        remoteAdapter: mockRemoteAdapter,
        config: _testConfig(),
      );

      final result = await engine.sync();

      expect(result.pushed, 0);
      expect(result.pulled, 0);
      expect(result.failed, 0);
      expect(result.conflicted, 0);

      engine.dispose();
    });
  });
}
