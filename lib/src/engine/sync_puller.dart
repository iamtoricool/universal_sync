import 'package:universal_sync/src/adapter/local_adapter.dart';
import 'package:universal_sync/src/adapter/remote_adapter.dart';
import 'package:universal_sync/src/config/sync_config.dart';
import 'package:universal_sync/src/internal/type_utils.dart';
import 'package:universal_sync/src/model/sync_checkpoint.dart';
import 'package:universal_sync/src/model/sync_entity.dart';
import 'package:universal_sync/src/model/sync_queue_entry.dart';

class PullResult {
  final int pulled;
  const PullResult({this.pulled = 0});
  PullResult operator +(PullResult other) => PullResult(pulled: pulled + other.pulled);
}

class SyncPuller {
  final LocalAdapter localAdapter;
  final RemoteAdapter remoteAdapter;
  final SyncConfig config;
  final Map<Type, SyncEntity Function(Map<String, dynamic>)> entityFromJson;

  SyncPuller({
    required this.localAdapter,
    required this.remoteAdapter,
    required this.config,
    required this.entityFromJson,
  });

  Future<PullResult> run({
    void Function(int processed, int total)? onProgress,
    Future<bool> Function()? isCancelled,
  }) async {
    var totalPulled = 0;

    for (final type in config.entityOrder) {
      if (isCancelled != null && await isCancelled()) break;

      final typeName = entityTypeName(type);

      final checkpoint = await localAdapter.readCheckpoint(typeName);
      final sinceSequence = checkpoint?.lastServerSequence ?? 0;

      final response = await remoteAdapter.pull(
        PullRequest(entityType: typeName, sinceSequence: sinceSequence),
      );

      if (response.operations.isNotEmpty) {
        final sortedOps = List<RemoteOperation>.from(response.operations)
          ..sort((a, b) => a.serverSequence.compareTo(b.serverSequence));

        await localAdapter.transaction(() async {
          for (var i = 0; i < sortedOps.length; i++) {
            final op = sortedOps[i];
            switch (op.operation) {
              case SyncOperation.insert:
              case SyncOperation.update:
                await localAdapter.upsertEntity(typeName, op.payload);
              case SyncOperation.delete:
                await localAdapter.softDeleteEntity(typeName, op.entityId);
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
          await localAdapter.writeCheckpoint(newCheckpoint);
        });
      } else if (checkpoint == null || response.latestSequence > sinceSequence) {
        final newCheckpoint = SyncCheckpoint(
          id: typeName,
          entityType: typeName,
          lastServerSequence: response.latestSequence,
          lastSyncedAt: checkpoint?.lastSyncedAt,
        );
        await localAdapter.writeCheckpoint(newCheckpoint);
      }
    }

    return PullResult(pulled: totalPulled);
  }
}
