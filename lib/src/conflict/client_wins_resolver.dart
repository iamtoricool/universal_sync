import 'package:universal_sync/universal_sync.dart';

class ClientWinsResolver<T extends SyncEntity> implements ConflictResolver<T> {
  const ClientWinsResolver();

  @override
  ConflictResolution<T> resolve(ConflictContext<T> context) {
    return ConflictResolution.acceptLocal(context.local);
  }
}
