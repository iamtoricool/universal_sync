import 'dart:async';
import 'dart:convert';
import 'package:universal_sync/src/adapter/local_adapter.dart';
import 'package:universal_sync/src/adapter/remote_adapter.dart';
import 'package:universal_sync/src/config/sync_config.dart';
import 'package:universal_sync/src/conflict/conflict_resolver.dart';
import 'package:universal_sync/src/internal/type_utils.dart';
import 'package:universal_sync/src/model/sync_checkpoint.dart';
import 'package:universal_sync/src/model/sync_queue_entry.dart';
import 'package:universal_sync/src/model/sync_result.dart';
import 'package:universal_sync/src/model/sync_state.dart';

typedef OnSyncStart = void Function();
typedef OnSyncComplete = void Function(SyncResult result);
typedef OnError = void Function(Object error, StackTrace stackTrace);

class SyncEngine {
  final LocalAdapter _localAdapter;
  final RemoteAdapter _remoteAdapter;
  final SyncConfig _config;
  final OnSyncStart? onSyncStart;
  final OnSyncComplete? onSyncComplete;
  final OnError? onError;

  late final StreamController<SyncState> _controller;
  bool _isRunning = false;
  bool _disposed = false;
  bool _cancelled = false;
  SyncState _currentState = const SyncIdle();

  SyncEngine({
    required this._localAdapter,
    required this._remoteAdapter,
    required this._config,
    this.onSyncStart,
    this.onSyncComplete,
    this.onError,
  }) {
    _controller = StreamController<SyncState>.broadcast(
      onListen: () => _controller.add(_currentState),
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
      onSyncStart?.call();

      _emitState(SyncInProgress(phase: SyncPhase.pushing, processed: 0, total: 0));
      final pushResult = await _runPush(
        onProgress: (processed, total) {
          _emitState(SyncInProgress(phase: SyncPhase.pushing, processed: processed, total: total));
        },
        isCancelled: () async => _cancelled,
      );

      if (_cancelled) {
        return _finishWithIdle(
          startTime,
          pushResult.$1,
          0,
          failed: pushResult.$2,
          conflicted: pushResult.$3,
        );
      }

      _emitState(SyncInProgress(phase: SyncPhase.pulling, processed: 0, total: 0));
      final pulled = await _runPull(
        onProgress: (processed, total) {
          _emitState(SyncInProgress(phase: SyncPhase.pulling, processed: processed, total: total));
        },
        isCancelled: () async => _cancelled,
      );

      return _finishWithIdle(
        startTime,
        pushResult.$1,
        pulled,
        failed: pushResult.$2,
        conflicted: pushResult.$3,
      );
    });
  }

  Future<SyncResult> push() {
    return _runGuarded(() async {
      final startTime = DateTime.now();
      _cancelled = false;
      onSyncStart?.call();

      _emitState(SyncInProgress(phase: SyncPhase.pushing, processed: 0, total: 0));
      final pushResult = await _runPush(
        onProgress: (processed, total) {
          _emitState(SyncInProgress(phase: SyncPhase.pushing, processed: processed, total: total));
        },
        isCancelled: () async => _cancelled,
      );

      return _finishWithIdle(
        startTime,
        pushResult.$1,
        0,
        failed: pushResult.$2,
        conflicted: pushResult.$3,
      );
    });
  }

  Future<SyncResult> pull() {
    return _runGuarded(() async {
      final startTime = DateTime.now();
      _cancelled = false;
      onSyncStart?.call();

      _emitState(SyncInProgress(phase: SyncPhase.pulling, processed: 0, total: 0));
      final pulled = await _runPull(
        onProgress: (processed, total) {
          _emitState(SyncInProgress(phase: SyncPhase.pulling, processed: processed, total: total));
        },
        isCancelled: () async => _cancelled,
      );

      return _finishWithIdle(startTime, 0, pulled);
    });
  }

  Future<(int pushed, int failed, int conflicted)> _runPush({
    void Function(int processed, int total)? onProgress,
    Future<bool> Function()? isCancelled,
  }) async {
    var totalPushed = 0;
    var totalFailed = 0;
    var totalConflicted = 0;

    for (final type in _config.types) {
      final typeName = entityTypeName(type);

      while (true) {
        if (isCancelled != null && await isCancelled()) {
          return (totalPushed, totalFailed, totalConflicted);
        }

        final entries = await _localAdapter.fetchPendingEntries(typeName, _config.batchSize);
        if (entries.isEmpty) break;

        final pushEntries = entries
            .map(
              (e) => PushEntry(
                id: e.id,
                idempotencyKey: e.idempotencyKey,
                entityType: e.entityType,
                entityId: e.entityId,
                operation: e.operation,
                payload: jsonEncode(e.data.toSyncJson()),
                localSequence: e.localSequence,
              ),
            )
            .toList();

        final response = await _remoteAdapter.push(PushRequest(pushEntries));
        final results = response.results;

        for (var i = 0; i < results.length; i++) {
          final entry = entries[i];
          final result = results[i];

          switch (result.outcome) {
            case SyncOutcome.accepted:
              final data = entry.data.toSyncJson();
              data['version'] = entry.version + 1;
              await _localAdapter.upsertEntity(typeName, data);
              await _localAdapter.updateQueueEntryStatus(entry.id, SyncEntryStatus.synced);
              totalPushed++;
              break;

            case SyncOutcome.conflicted:
              final localEntity = entry.data;
              final fromJson = _config.entityFromJson[typeName]!;
              final remoteEntity = fromJson(result.serverPayload!);
              final resolver = _config.resolvers[typeName] ?? serverWinsResolver;
              final resolution = resolver.resolve(
                ConflictContext(
                  local: localEntity,
                  remote: remoteEntity,
                  operation: entry.operation,
                ),
              );

              switch (resolution.strategy) {
                case ConflictStrategy.acceptRemote:
                  final remoteData = result.serverPayload!;
                  await _localAdapter.upsertEntity(typeName, remoteData);
                  await _localAdapter.updateQueueEntryStatus(entry.id, SyncEntryStatus.synced);
                  break;

                case ConflictStrategy.acceptLocal:
                  await _localAdapter.updateQueueEntryStatus(entry.id, SyncEntryStatus.synced);
                  break;

                case ConflictStrategy.merge:
                  final mergedData = resolution.entity.toSyncJson();
                  await _localAdapter.upsertEntity(typeName, mergedData);
                  final nextSeq = await _localAdapter.nextSequence();
                  final mergedEntity = fromJson(mergedData);
                  final mergedEntry = SyncQueueEntry(
                    id: 'merged_$nextSeq',
                    idempotencyKey: 'merged_$nextSeq',
                    data: mergedEntity,
                    operation: SyncOperation.update,
                    version: entry.version + 1,
                    localSequence: nextSeq,
                    createdAt: DateTime.now(),
                  );
                  await _localAdapter.enqueue(mergedEntry);
                  await _localAdapter.updateQueueEntryStatus(entry.id, SyncEntryStatus.synced);
                  break;
              }

              totalConflicted++;
              break;

            case SyncOutcome.rejected:
              await _localAdapter.updateQueueEntryStatus(entry.id, SyncEntryStatus.failed);
              totalFailed++;
              break;
          }

          onProgress?.call(i + 1, entries.length);
        }
      }
    }

    return (totalPushed, totalFailed, totalConflicted);
  }

  Future<int> _runPull({
    void Function(int processed, int total)? onProgress,
    Future<bool> Function()? isCancelled,
  }) async {
    var totalPulled = 0;

    for (final type in _config.types) {
      if (isCancelled != null && await isCancelled()) break;

      final typeName = entityTypeName(type);
      final checkpoint = await _localAdapter.readCheckpoint(typeName);
      final sinceSequence = checkpoint?.lastServerSequence ?? 0;

      final response = await _remoteAdapter.pull(
        PullRequest(entityType: typeName, sinceSequence: sinceSequence),
      );

      if (response.operations.isNotEmpty) {
        final sortedOps = List<RemoteOperation>.from(response.operations)
          ..sort((a, b) => a.serverSequence.compareTo(b.serverSequence));

        await _localAdapter.transaction(() async {
          for (var i = 0; i < sortedOps.length; i++) {
            final op = sortedOps[i];
            switch (op.operation) {
              case SyncOperation.insert:
              case SyncOperation.update:
                await _localAdapter.upsertEntity(typeName, op.payload);
              case SyncOperation.delete:
                await _localAdapter.softDeleteEntity(typeName, op.entityId);
            }
            totalPulled++;
            onProgress?.call(i + 1, sortedOps.length);
          }

          final newCheckpoint = SyncCheckpoint(
            id: typeName,
            entityType: typeName,
            lastServerSequence: response.latestSequence,
            lastSyncedAt: DateTime.now(),
          );
          await _localAdapter.writeCheckpoint(newCheckpoint);
        });
      } else if (checkpoint == null || response.latestSequence > sinceSequence) {
        final newCheckpoint = SyncCheckpoint(
          id: typeName,
          entityType: typeName,
          lastServerSequence: response.latestSequence,
          lastSyncedAt: checkpoint?.lastSyncedAt,
        );
        await _localAdapter.writeCheckpoint(newCheckpoint);
      }
    }

    return totalPulled;
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
      _emitState(SyncError(error: e, stackTrace: s));
      onError?.call(e, s);
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
    onSyncComplete?.call(result);
    return result;
  }

  void dispose() {
    _disposed = true;
    _controller.close();
  }
}
