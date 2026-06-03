import 'package:test/test.dart';
import 'package:universal_sync/universal_sync.dart';

void main() {
  group('SyncConfig', () {
    test('applies default values', () {
      final config = SyncConfig(entityOrder: [String]);
      expect(config.entityOrder, [String]);
      expect(config.batchSize, 50);
      expect(config.maxRetries, 3);
      expect(config.retryDelay, Duration(seconds: 5));
      expect(config.resolvers, isNull);
    });

    test('accepts custom values', () {
      final config = SyncConfig(
        entityOrder: [int, double],
        batchSize: 10,
        maxRetries: 5,
        retryDelay: Duration(seconds: 10),
      );
      expect(config.entityOrder, [int, double]);
      expect(config.batchSize, 10);
      expect(config.maxRetries, 5);
      expect(config.retryDelay, Duration(seconds: 10));
    });

    test('throws on empty entityOrder', () {
      expect(
        () => SyncConfig(entityOrder: []),
        throwsArgumentError,
      );
    });

    test('throws on batchSize <= 0', () {
      expect(
        () => SyncConfig(entityOrder: [String], batchSize: 0),
        throwsArgumentError,
      );
    });

    test('throws on negative maxRetries', () {
      expect(
        () => SyncConfig(entityOrder: [String], maxRetries: -1),
        throwsArgumentError,
      );
    });

    test('throws on zero retryDelay', () {
      expect(
        () => SyncConfig(entityOrder: [String], retryDelay: Duration.zero),
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
  });
}
