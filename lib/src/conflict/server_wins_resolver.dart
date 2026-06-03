import 'package:universal_sync/universal_sync.dart';

class ServerWinsResolver<T extends SyncEntity> implements ConflictResolver<T> {
  const ServerWinsResolver();

  @override
  ConflictResolution<T> resolve(ConflictContext<T> context) {
    return ConflictResolution.acceptRemote(context.remote);
  }
}
