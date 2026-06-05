import 'package:universal_sync/src/model/sync_entity.dart';
import 'package:universal_sync/src/conflict/conflict_resolver.dart';
import 'package:universal_sync/src/internal/type_utils.dart';

class SyncConfig {
  final Map<int, Type> entityOrder;
  final int batchSize;
  final Map<String, SyncEntity Function(Map<String, dynamic>)> entityFromJson;
  final Map<String, ConflictResolver> resolvers;

  SyncConfig({
    required this.entityOrder,
    this.batchSize = 50,
    required this.entityFromJson,
    this.resolvers = const {},
  }) {
    if (entityOrder.isEmpty) throw ArgumentError('entityOrder must not be empty');
    if (batchSize <= 0) throw ArgumentError('batchSize must be > 0');
    for (final type in types) {
      final name = entityTypeName(type);
      if (!entityFromJson.containsKey(name)) {
        throw ArgumentError('Missing fromJson factory for type: $type');
      }
    }
    if (resolvers.keys.any((k) => !entityFromJson.containsKey(k))) {
      throw ArgumentError('All resolver types must be in entityOrder');
    }
  }

  List<Type> get types {
    final sorted = entityOrder.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) => e.value).toList();
  }
}
