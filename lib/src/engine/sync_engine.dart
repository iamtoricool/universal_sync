import 'dart:async';
import 'package:universal_sync/universal_sync.dart';
import 'package:universal_sync/src/engine/sync_puller.dart';

typedef OnSyncStart = void Function();
typedef OnSyncComplete = void Function(SyncResult result);
typedef OnError = void Function(Object error, StackTrace stackTrace);

class SyncEngine {
  final OnSyncStart? _onSyncStart;
  final OnSyncComplete? _onSyncComplete;
  final OnError? _onError;

  late final SyncPusher _pusher;
  late final SyncPuller _puller;
  late final StreamController<SyncState> _controller;
  bool _isRunning = false;
  bool _disposed = false;
  bool _cancelled = false;
  SyncState _currentState = SyncIdle();

  SyncEngine({
    required LocalAdapter localAdapter,
    required RemoteAdapter remoteAdapter,
    required SyncConfig config,
    required Map<Type, SyncEntity Function(Map<String, dynamic>)> entityFromJson,
    Map<Type, ConflictResolver<SyncEntity>>? resolvers,
    OnSyncStart? onSyncStart,
    OnSyncComplete? onSyncComplete,
    OnError? onError,
  }) : _onSyncStart = onSyncStart,
       _onSyncComplete = onSyncComplete,
       _onError = onError {
    _controller = StreamController<SyncState>.broadcast(
      onListen: () => _controller.add(_currentState),
    );
    _pusher = SyncPusher(
      localAdapter: localAdapter,
      remoteAdapter: remoteAdapter,
      config: config,
      entityFromJson: entityFromJson,
      resolvers: resolvers,
    );
    _puller = SyncPuller(
      localAdapter: localAdapter,
      remoteAdapter: remoteAdapter,
      config: config,
      entityFromJson: entityFromJson,
    );
  }

  Stream<SyncState> get state => _controller.stream;
  SyncState get currentState => _currentState;

  void _emitState(SyncState state) {
    _currentState = state;
    if (!_controller.isClosed) {
      _controller.add(state);
    }
  }

  void cancel() {
    _cancelled = true;
  }

  Future<SyncResult> sync() {
    return _runGuarded(() async {
      final startTime = DateTime.now();
      _cancelled = false;
      _onSyncStart?.call();

      _emitState(SyncInProgress(phase: SyncPhase.pushing, processed: 0, total: 0));
      final pushResult = await _pusher.run(
        onProgress: (processed, total) {
          _emitState(SyncInProgress(phase: SyncPhase.pushing, processed: processed, total: total));
        },
        isCancelled: () async => _cancelled,
      );

      if (_cancelled) {
        return _finishWithIdle(
          startTime,
          pushResult.pushed,
          0,
          failed: pushResult.failed,
          conflicted: pushResult.conflicted,
        );
      }

      _emitState(SyncInProgress(phase: SyncPhase.pulling, processed: 0, total: 0));
      final pullResult = await _puller.run(
        onProgress: (processed, total) {
          _emitState(SyncInProgress(phase: SyncPhase.pulling, processed: processed, total: total));
        },
        isCancelled: () async => _cancelled,
      );

      return _finishWithIdle(
        startTime,
        pushResult.pushed,
        pullResult.pulled,
        failed: pushResult.failed,
        conflicted: pushResult.conflicted,
      );
    });
  }

  Future<SyncResult> push() {
    return _runGuarded(() async {
      final startTime = DateTime.now();
      _cancelled = false;
      _onSyncStart?.call();

      _emitState(SyncInProgress(phase: SyncPhase.pushing, processed: 0, total: 0));
      final pushResult = await _pusher.run(
        onProgress: (processed, total) {
          _emitState(SyncInProgress(phase: SyncPhase.pushing, processed: processed, total: total));
        },
        isCancelled: () async => _cancelled,
      );

      return _finishWithIdle(
        startTime,
        pushResult.pushed,
        0,
        failed: pushResult.failed,
        conflicted: pushResult.conflicted,
      );
    });
  }

  Future<SyncResult> pull() {
    return _runGuarded(() async {
      final startTime = DateTime.now();
      _cancelled = false;
      _onSyncStart?.call();

      _emitState(SyncInProgress(phase: SyncPhase.pulling, processed: 0, total: 0));
      final pullResult = await _puller.run(
        onProgress: (processed, total) {
          _emitState(SyncInProgress(phase: SyncPhase.pulling, processed: processed, total: total));
        },
        isCancelled: () async => _cancelled,
      );

      return _finishWithIdle(startTime, 0, pullResult.pulled);
    });
  }

  Future<SyncResult> _runGuarded(Future<SyncResult> Function() fn) async {
    if (_disposed) throw StateError('SyncEngine is disposed');
    if (_isRunning) {
      throw StateError('Sync is already in progress');
    }
    _isRunning = true;
    try {
      return await fn();
    } catch (e, s) {
      _emitState(SyncError(error: e, stackTrace: s, pendingCount: 0));
      _onError?.call(e, s);
      rethrow;
    } finally {
      _isRunning = false;
    }
  }

  SyncResult _finishWithIdle(DateTime startTime, int pushed, int pulled, {int failed = 0, int conflicted = 0}) {
    final duration = DateTime.now().difference(startTime);
    final result = SyncResult(
      pushed: pushed,
      pulled: pulled,
      failed: failed,
      conflicted: conflicted,
      duration: duration,
    );
    _emitState(SyncIdle(lastSyncedAt: DateTime.now()));
    _onSyncComplete?.call(result);
    return result;
  }

  void dispose() {
    _disposed = true;
    _controller.close();
  }
}
