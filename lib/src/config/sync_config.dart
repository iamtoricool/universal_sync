import 'package:universal_sync/src/model/sync_entity.dart';
import 'package:universal_sync/src/conflict/conflict_resolver.dart';

class SyncConfig {
  final List<Type> entityOrder;
  final int batchSize;
  final Map<Type, ConflictResolver<SyncEntity>>? resolvers;

  SyncConfig({
    required this.entityOrder,
    this.batchSize = 50,
    this.resolvers,
  }) {
    if (entityOrder.isEmpty) {
      throw ArgumentError('entityOrder must not be empty');
    }
    if (batchSize <= 0) {
      throw ArgumentError('batchSize must be > 0');
    }
    if (resolvers != null && !resolvers!.keys.every((k) => entityOrder.contains(k))) {
      throw ArgumentError('All resolver types must be in entityOrder');
    }
  }
}
