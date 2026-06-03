import 'package:test/test.dart';
import 'package:universal_sync/universal_sync.dart';

void main() {
  group('SyncConfig', () {
    test('applies default values', () {
      final config = SyncConfig(entityOrder: [String]);
      expect(config.entityOrder, [String]);
      expect(config.batchSize, 50);
      expect(config.resolvers, isNull);
    });

    test('accepts custom values', () {
      final config = SyncConfig(
        entityOrder: [int, double],
        batchSize: 10,
      );
      expect(config.entityOrder, [int, double]);
      expect(config.batchSize, 10);
    });

    test('throws on empty entityOrder', () {
      expect(
        () => SyncConfig(entityOrder: []),
        throwsArgumentError,
      );
    });

    test('entityOrder error message is descriptive', () {
      try {
        SyncConfig(entityOrder: []);
        fail('Should have thrown');
      } on ArgumentError catch (e) {
        expect(e.message, contains('entityOrder must not be empty'));
      }
    });

    test('batchSize = 1 is accepted', () {
      final config = SyncConfig(entityOrder: [String], batchSize: 1);
      expect(config.batchSize, 1);
    });

    test('batchSize error message is descriptive', () {
      try {
        SyncConfig(entityOrder: [String], batchSize: 0);
        fail('Should have thrown');
      } on ArgumentError catch (e) {
        expect(e.message, equals('batchSize must be > 0'));
      }
    });

    test('throws on batchSize <= 0', () {
      expect(
        () => SyncConfig(entityOrder: [String], batchSize: 0),
        throwsArgumentError,
      );
    });

    test('accepts resolvers with matching keys', () {
      final resolver = ServerWinsResolver<SyncEntity>();
      final config = SyncConfig(
        entityOrder: [String, int],
        resolvers: {String: resolver},
      );
      expect(config.resolvers, isNotNull);
      expect(config.resolvers!.keys, contains(String));
    });

    test('resolvers null is accepted', () {
      final config = SyncConfig(entityOrder: [String], resolvers: null);
      expect(config.resolvers, isNull);
    });

    test('throws when a resolver key is not in entityOrder', () {
      final resolver = ServerWinsResolver<SyncEntity>();
      expect(
        () => SyncConfig(
          entityOrder: [String],
          resolvers: {int: resolver},
        ),
        throwsArgumentError,
      );
    });

    test('throws when only one resolver key is missing from entityOrder', () {
      final resolver = ServerWinsResolver<SyncEntity>();
      expect(
        () => SyncConfig(
          entityOrder: [String],
          resolvers: {String: resolver, int: resolver},
        ),
        throwsArgumentError,
      );
    });

    test('throws when all resolver keys are missing from entityOrder', () {
      final resolver = ServerWinsResolver<SyncEntity>();
      expect(
        () => SyncConfig(
          entityOrder: [String],
          resolvers: {int: resolver, double: resolver},
        ),
        throwsArgumentError,
      );
    });

    test('resolver error message mentions entityOrder', () {
      final resolver = ServerWinsResolver<SyncEntity>();
      try {
        SyncConfig(
          entityOrder: [String],
          resolvers: {int: resolver},
        );
        fail('Should have thrown');
      } on ArgumentError catch (e) {
        expect(e.message, equals('All resolver types must be in entityOrder'));
      }
    });
  });
}
