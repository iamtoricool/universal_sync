import 'package:universal_sync/src/model/sync_entity.dart';
import 'package:universal_sync/src/conflict/conflict_resolver.dart';

class SyncConfig {
  final List<Type> entityOrder;
  final int batchSize;
  final int maxRetries;
  final Duration retryDelay;
  final Map<Type, ConflictResolver<SyncEntity>>? resolvers;

  SyncConfig({
    required this.entityOrder,
    this.batchSize = 50,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 5),
    this.resolvers,
  }) {
    if (entityOrder.isEmpty) {
      throw ArgumentError('entityOrder must not be empty');
    }
    if (batchSize <= 0) {
      throw ArgumentError('batchSize must be > 0');
    }
    if (maxRetries < 0) {
      throw ArgumentError('maxRetries must be >= 0');
    }
    if (retryDelay <= Duration.zero) {
      throw ArgumentError('retryDelay must be positive');
    }
    if (resolvers != null && !resolvers!.keys.every((k) => entityOrder.contains(k))) {
      throw ArgumentError('All resolver types must be in entityOrder');
    }
  }
}
