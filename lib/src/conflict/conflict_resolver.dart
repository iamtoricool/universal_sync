import 'package:universal_sync/universal_sync.dart';

enum ConflictStrategy { acceptRemote, acceptLocal, merge }

class ConflictContext {
  final SyncEntity local;
  final SyncEntity remote;
  final SyncOperation operation;

  const ConflictContext({
    required this.local,
    required this.remote,
    required this.operation,
  });
}

class ConflictResolution {
  final ConflictStrategy strategy;
  final SyncEntity entity;

  const ConflictResolution._({
    required this.strategy,
    required this.entity,
  });

  factory ConflictResolution.acceptLocal(SyncEntity entity) =>
      ConflictResolution._(strategy: ConflictStrategy.acceptLocal, entity: entity);

  factory ConflictResolution.acceptRemote(SyncEntity entity) =>
      ConflictResolution._(strategy: ConflictStrategy.acceptRemote, entity: entity);

  factory ConflictResolution.merge(SyncEntity entity) =>
      ConflictResolution._(strategy: ConflictStrategy.merge, entity: entity);
}

abstract class ConflictResolver {
  ConflictResolution resolve(ConflictContext context);
}

class _SimpleResolver implements ConflictResolver {
  final ConflictStrategy strategy;
  const _SimpleResolver(this.strategy);

  @override
  ConflictResolution resolve(ConflictContext context) {
    switch (strategy) {
      case ConflictStrategy.acceptRemote:
        return ConflictResolution.acceptRemote(context.remote);
      case ConflictStrategy.acceptLocal:
        return ConflictResolution.acceptLocal(context.local);
      case ConflictStrategy.merge:
        throw UnimplementedError('Merge strategy requires a custom resolver');
    }
  }
}

const ConflictResolver serverWinsResolver = _SimpleResolver(ConflictStrategy.acceptRemote);
const ConflictResolver clientWinsResolver = _SimpleResolver(ConflictStrategy.acceptLocal);
