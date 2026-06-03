// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'package:universal_sync/universal_sync.dart';
import 'package:universal_sync/src/internal/type_utils.dart';

class PushResult {
  final int pushed;
  final int failed;
  final int conflicted;

  const PushResult({
    this.pushed = 0,
    this.failed = 0,
    this.conflicted = 0,
  });

  PushResult operator +(PushResult other) => PushResult(
    pushed: pushed + other.pushed,
    failed: failed + other.failed,
    conflicted: conflicted + other.conflicted,
  );
}

class SyncPusher {
  final LocalAdapter _localAdapter;
  final RemoteAdapter _remoteAdapter;
  final SyncConfig _config;
  final Map<Type, SyncEntity Function(Map<String, dynamic>)> _entityFromJson;
  final Map<Type, ConflictResolver<SyncEntity>>? _resolvers;

  SyncPusher({
    required LocalAdapter localAdapter,
    required RemoteAdapter remoteAdapter,
    required SyncConfig config,
    required Map<Type, SyncEntity Function(Map<String, dynamic>)> entityFromJson,
    Map<Type, ConflictResolver<SyncEntity>>? resolvers,
  }) : _localAdapter = localAdapter,
       _remoteAdapter = remoteAdapter,
       _config = config,
       _entityFromJson = entityFromJson,
       _resolvers = resolvers ?? config.resolvers;

  Future<PushResult> run({
    void Function(int processed, int total)? onProgress,
    Future<bool> Function()? isCancelled,
  }) async {
    var totalPushed = 0;
    var totalFailed = 0;
    var totalConflicted = 0;

    for (final type in _config.entityOrder) {
      final typeName = entityTypeName(type);

      while (true) {
        if (isCancelled != null && await isCancelled()) {
          return PushResult(
            pushed: totalPushed,
            failed: totalFailed,
            conflicted: totalConflicted,
          );
        }

        final entries = await _localAdapter.fetchPendingEntries(
          typeName,
          _config.batchSize,
        );
        if (entries.isEmpty) break;

        for (final entry in entries) {
          await _localAdapter.updateQueueEntryStatus(
            entry.id,
            SyncEntryStatus.processing,
          );
        }

        try {
          final pushEntries = entries
              .map(
                (e) => PushEntry(
                  id: e.id,
                  entityType: e.entityType,
                  entityId: e.entityId,
                  operation: e.operation,
                  payload: e.payload,
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
                final data = jsonDecode(entry.payload) as Map<String, dynamic>;
                data['version'] = entry.version + 1;
                await _localAdapter.upsertEntity(typeName, data);
                await _localAdapter.updateQueueEntryStatus(
                  entry.id,
                  SyncEntryStatus.synced,
                );
                totalPushed++;
                break;

              case SyncOutcome.conflicted:
                final localData = jsonDecode(entry.payload) as Map<String, dynamic>;
                final fromJson = _entityFromJson[type]!;
                final localEntity = fromJson(localData);
                final remoteEntity = fromJson(result.serverPayload!);
                final resolver = _resolvers?[type] ?? ServerWinsResolver<SyncEntity>();
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
                    await _localAdapter.updateQueueEntryStatus(
                      entry.id,
                      SyncEntryStatus.synced,
                    );
                    break;

                  case ConflictStrategy.acceptLocal:
                    final newRetryCount = entry.retryCount + 1;
                    if (newRetryCount >= _config.maxRetries) {
                      await _localAdapter.updateQueueEntryStatus(
                        entry.id,
                        SyncEntryStatus.failed,
                        retryCount: newRetryCount,
                        errorMessage: 'Max retries reached after conflict',
                      );
                    } else {
                      await _localAdapter.updateQueueEntryStatus(
                        entry.id,
                        SyncEntryStatus.pending,
                        retryCount: newRetryCount,
                        errorMessage: 'Conflict - re-queued',
                      );
                    }
                    break;

                  case ConflictStrategy.merge:
                    final mergedData = resolution.entity.toSyncJson();
                    await _localAdapter.upsertEntity(typeName, mergedData);
                    final nextSeq = await _localAdapter.nextSequence();
                    final mergedEntry = SyncQueueEntry(
                      id: 'merged_$nextSeq',
                      entityType: typeName,
                      entityId: mergedData['id'] as String,
                      operation: SyncOperation.update,
                      payload: jsonEncode(mergedData),
                      version: entry.version + 1,
                      localSequence: nextSeq,
                      createdAt: DateTime.now(),
                    );
                    await _localAdapter.enqueue(mergedEntry);
                    await _localAdapter.updateQueueEntryStatus(
                      entry.id,
                      SyncEntryStatus.synced,
                    );
                    break;
                }

                totalConflicted++;
                break;

              case SyncOutcome.rejected:
                final newRetryCount = entry.retryCount + 1;
                if (newRetryCount >= _config.maxRetries) {
                  await _localAdapter.updateQueueEntryStatus(
                    entry.id,
                    SyncEntryStatus.failed,
                    retryCount: newRetryCount,
                    errorMessage: result.errorMessage,
                  );
                } else {
                  await _localAdapter.updateQueueEntryStatus(
                    entry.id,
                    SyncEntryStatus.pending,
                    retryCount: newRetryCount,
                    errorMessage: result.errorMessage,
                  );
                }
                totalFailed++;
                break;
            }

            onProgress?.call(i + 1, entries.length);
          }
        } catch (_) {
          for (final entry in entries) {
            await _localAdapter.updateQueueEntryStatus(
              entry.id,
              SyncEntryStatus.pending,
            );
          }
          rethrow;
        }
      }
    }

    return PushResult(
      pushed: totalPushed,
      failed: totalFailed,
      conflicted: totalConflicted,
    );
  }
}
