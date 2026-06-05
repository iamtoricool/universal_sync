import 'package:test/test.dart';
import 'package:universal_sync/universal_sync.dart';

void main() {
  group('SyncConfig', () {
    test('applies default values', () {
      final config = SyncConfig(
        entityOrder: {0: String},
        entityFromJson: {'String': (_) => throw UnimplementedError()},
      );
      expect(config.entityOrder, {0: String});
      expect(config.batchSize, 50);
      expect(config.resolvers, {});
    });

    test('accepts custom values', () {
      final config = SyncConfig(
        entityOrder: {0: int, 1: double},
        batchSize: 10,
        entityFromJson: {
          'int': (_) => throw UnimplementedError(),
          'double': (_) => throw UnimplementedError(),
        },
      );
      expect(config.entityOrder, {0: int, 1: double});
      expect(config.batchSize, 10);
    });

    test('throws on empty entityOrder', () {
      expect(
        () => SyncConfig(
          entityOrder: {},
          entityFromJson: {},
        ),
        throwsArgumentError,
      );
    });

    test('entityOrder error message is descriptive', () {
      try {
        SyncConfig(entityOrder: {}, entityFromJson: {});
        fail('Should have thrown');
      } on ArgumentError catch (e) {
        expect(e.message, contains('entityOrder must not be empty'));
      }
    });

    test('batchSize = 1 is accepted', () {
      final config = SyncConfig(
        entityOrder: {0: String},
        batchSize: 1,
        entityFromJson: {'String': (_) => throw UnimplementedError()},
      );
      expect(config.batchSize, 1);
    });

    test('batchSize error message is descriptive', () {
      try {
        SyncConfig(
          entityOrder: {0: String},
          batchSize: 0,
          entityFromJson: {'String': (_) => throw UnimplementedError()},
        );
        fail('Should have thrown');
      } on ArgumentError catch (e) {
        expect(e.message, equals('batchSize must be > 0'));
      }
    });

    test('throws on batchSize <= 0', () {
      expect(
        () => SyncConfig(
          entityOrder: {0: String},
          batchSize: 0,
          entityFromJson: {'String': (_) => throw UnimplementedError()},
        ),
        throwsArgumentError,
      );
    });

    test('accepts resolvers with matching keys', () {
      final config = SyncConfig(
        entityOrder: {0: String, 1: int},
        entityFromJson: {
          'String': (_) => throw UnimplementedError(),
          'int': (_) => throw UnimplementedError(),
        },
        resolvers: {'String': serverWinsResolver},
      );
      expect(config.resolvers, isNotEmpty);
      expect(config.resolvers.keys, contains('String'));
    });

    test('resolvers defaults to empty map', () {
      final config = SyncConfig(
        entityOrder: {0: String},
        entityFromJson: {'String': (_) => throw UnimplementedError()},
      );
      expect(config.resolvers, {});
    });

    test('throws when a resolver key is not in entityOrder', () {
      expect(
        () => SyncConfig(
          entityOrder: {0: String},
          entityFromJson: {'String': (_) => throw UnimplementedError()},
          resolvers: {'int': serverWinsResolver},
        ),
        throwsArgumentError,
      );
    });

    test('throws when missing fromJson for a type', () {
      expect(
        () => SyncConfig(
          entityOrder: {0: String},
          entityFromJson: {},
        ),
        throwsArgumentError,
      );
    });
  });
}
