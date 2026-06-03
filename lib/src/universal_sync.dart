import 'package:universal_sync/universal_sync.dart';

class UniversalSync {
  final LocalAdapter localAdapter;
  final RemoteAdapter remoteAdapter;
  final SyncConfig config;
  final Map<Type, SyncEntity Function(Map<String, dynamic>)> entityFromJson;
  final Map<Type, ConflictResolver<SyncEntity>>? resolvers;
  final OnSyncStart? onSyncStart;
  final OnSyncComplete? onSyncComplete;
  final OnError? onError;

  bool _initialized = false;
  SyncEngine? _engine;

  UniversalSync({
    required this.localAdapter,
    required this.remoteAdapter,
    required this.config,
    required this.entityFromJson,
    this.resolvers,
    this.onSyncStart,
    this.onSyncComplete,
    this.onError,
  });

  Future<void> init() async {
    for (final type in config.entityOrder) {
      if (!entityFromJson.containsKey(type)) {
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
      localAdapter: localAdapter,
      remoteAdapter: remoteAdapter,
      config: config,
      entityFromJson: entityFromJson,
      resolvers: resolvers,
      onSyncStart: onSyncStart,
      onSyncComplete: onSyncComplete,
      onError: onError,
    );
    return _engine!;
  }

  void dispose() {
    _engine?.dispose();
    _engine = null;
    _initialized = false;
  }
}
