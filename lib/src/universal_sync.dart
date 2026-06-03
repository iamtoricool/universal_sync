import 'package:universal_sync/universal_sync.dart';
import 'package:universal_sync/src/engine/sync_engine.dart';

class UniversalSync {
  final LocalAdapter _localAdapter;
  final RemoteAdapter _remoteAdapter;
  final SyncConfig _config;
  final Map<Type, SyncEntity Function(Map<String, dynamic>)> _entityFromJson;
  final Map<Type, ConflictResolver<SyncEntity>>? _resolvers;
  final OnSyncStart? _onSyncStart;
  final OnSyncComplete? _onSyncComplete;
  final OnError? _onError;

  bool _initialized = false;
  SyncEngine? _engine;

  UniversalSync({
    required LocalAdapter localAdapter,
    required RemoteAdapter remoteAdapter,
    required SyncConfig config,
    required Map<Type, SyncEntity Function(Map<String, dynamic>)> entityFromJson,
    Map<Type, ConflictResolver<SyncEntity>>? resolvers,
    OnSyncStart? onSyncStart,
    OnSyncComplete? onSyncComplete,
    OnError? onError,
  }) : _localAdapter = localAdapter,
       _remoteAdapter = remoteAdapter,
       _config = config,
       _entityFromJson = entityFromJson,
       _resolvers = resolvers,
       _onSyncStart = onSyncStart,
       _onSyncComplete = onSyncComplete,
       _onError = onError;

  Future<void> init() async {
    for (final type in _config.entityOrder) {
      if (!_entityFromJson.containsKey(type)) {
        throw ArgumentError(
          'Missing fromJson factory for type: $type. '
          'All types in entityOrder must have a corresponding fromJson factory.',
        );
      }
    }
    _initialized = true;
  }

  SyncEngine get engine {
    if (!_initialized) {
      throw StateError('UniversalSync not initialized. Call init() first.');
    }
    _engine ??= SyncEngine(
      localAdapter: _localAdapter,
      remoteAdapter: _remoteAdapter,
      config: _config,
      entityFromJson: _entityFromJson,
      resolvers: _resolvers,
      onSyncStart: _onSyncStart,
      onSyncComplete: _onSyncComplete,
      onError: _onError,
    );
    return _engine!;
  }

  Future<void> dispose() async {
    _engine?.dispose();
    _engine = null;
    _initialized = false;
  }
}
