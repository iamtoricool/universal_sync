import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_sync/universal_sync.dart';

import 'category_providers.dart';
import 'providers.dart';

abstract class EntityNotifier<T extends SyncEntity>
    extends AsyncNotifier<List<T>> {
  String get entityType;
  T Function(Map<String, dynamic>) get fromJson;
  int Function(T, T) get sortComparator;

  @override
  Future<List<T>> build() async {
    ref.watch(syncStateProvider);
    final adapter = ref.read(adapterProvider);
    final entities = adapter.entities;
    final maps = entities[entityType]?.values ?? <Map<String, dynamic>>[];
    final items = maps
        .where((m) => m['deletedAt'] == null)
        .map((m) => fromJson(Map<String, dynamic>.from(m)))
        .toList();
    items.sort(sortComparator);
    return items;
  }

  Future<void> insert(T entity) async {
    final adapter = ref.read(adapterProvider);
    await adapter.transaction(() async {
      await adapter.upsertEntityFor<T>(entity.toSyncJson());
      await adapter.enqueueFor(entity, SyncOperation.insert);
    });
    ref.invalidateSelf();
    _invalidateCounts();
  }

  Future<void> modify(String id, T Function(T current) updater) async {
    final adapter = ref.read(adapterProvider);
    final map = adapter.entities[entityType]?[id];
    if (map == null) return;
    final current = fromJson(Map<String, dynamic>.from(map));
    final updated = updater(current);
    await adapter.transaction(() async {
      await adapter.upsertEntityFor<T>(updated.toSyncJson());
      await adapter.enqueueFor(updated, SyncOperation.update);
    });
    ref.invalidateSelf();
    _invalidateCounts();
  }

  Future<void> delete(String id) async {
    final adapter = ref.read(adapterProvider);
    final map = adapter.entities[entityType]?[id];
    if (map == null) return;
    final curr = fromJson(Map<String, dynamic>.from(map));
    await adapter.softDeleteEntityFor<T>(id);
    await adapter.enqueueFor(curr, SyncOperation.delete);
    ref.invalidateSelf();
    _invalidateCounts();
  }

  Future<SyncResult?> triggerSync() async {
    try {
      final engine = await ref.read(syncEngineProvider.future);
      return await engine.sync();
    } catch (_) {
      return null;
    }
  }

  void resetAndInvalidate() {
    ref.invalidateSelf();
    _invalidateCounts();
  }

  void _invalidateCounts() {
    ref.invalidate(pendingCountProvider);
    ref.invalidate(pendingCategoryCountProvider);
  }
}
