import 'package:universal_sync/universal_sync.dart';

enum ConflictStrategy { acceptRemote, acceptLocal, merge }

class ConflictContext<T extends SyncEntity> {
  final T local;
  final T remote;
  final SyncOperation operation;

  const ConflictContext({
    required this.local,
    required this.remote,
    required this.operation,
  });
}

class ConflictResolution<T extends SyncEntity> {
  final ConflictStrategy strategy;
  final T entity;

  const ConflictResolution._({
    required this.strategy,
    required this.entity,
  });

  factory ConflictResolution.acceptRemote(T entity) =>
      ConflictResolution._(strategy: ConflictStrategy.acceptRemote, entity: entity);

  factory ConflictResolution.acceptLocal(T entity) =>
      ConflictResolution._(strategy: ConflictStrategy.acceptLocal, entity: entity);

  factory ConflictResolution.merge(T entity) => ConflictResolution._(strategy: ConflictStrategy.merge, entity: entity);
}

abstract class ConflictResolver<T extends SyncEntity> {
  ConflictResolution<T> resolve(ConflictContext<T> context);
}
