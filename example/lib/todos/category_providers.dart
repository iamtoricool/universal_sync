import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_sync/universal_sync.dart';
import 'package:uuid/uuid.dart';

import 'category.dart';
import 'providers.dart';

final pendingCategoryCountProvider = FutureProvider<int>((ref) async {
  final adapter = ref.watch(adapterProvider);
  final pending = await adapter.fetchPendingEntries('TodoCategory', 9999);
  return pending.length;
});

class CategoryListNotifier extends AsyncNotifier<List<TodoCategory>> {
  @override
  Future<List<TodoCategory>> build() async {
    ref.watch(syncStateProvider);
    final adapter = ref.read(adapterProvider);
    final entities = adapter.entities;
    final categoryMaps =
        entities['TodoCategory']?.values ?? <Map<String, dynamic>>[];
    final categories = categoryMaps
        .where((m) => m['deletedAt'] == null)
        .map((m) => TodoCategory.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    categories.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return categories;
  }

  Future<void> addCategory(
    String name,
    String description,
    String color,
    int sortOrder,
  ) async {
    final adapter = ref.read(adapterProvider);
    final id = const Uuid().v4();
    final now = DateTime.now();
    final category = TodoCategory(
      id: id,
      version: 0,
      createdAt: now,
      updatedAt: now,
      name: name,
      description: description,
      color: color,
      sortOrder: sortOrder,
    );
    final data = category.toSyncJson();
    final seq = await adapter.nextSequence();
    await adapter.transaction(() async {
      await adapter.upsertEntity('TodoCategory', data);
      await adapter.enqueue(
        SyncQueueEntry(
          id: const Uuid().v4(),
          idempotencyKey: const Uuid().v4(),
          entityType: 'TodoCategory',
          entityId: id,
          operation: SyncOperation.insert,
          payload: jsonEncode(data),
          version: 0,
          localSequence: seq,
          createdAt: now,
        ),
      );
    });
    ref.invalidateSelf();
    ref.invalidate(pendingCategoryCountProvider);
  }

  Future<void> updateCategory(
    String id,
    String name,
    String description,
    String color,
    int sortOrder,
  ) async {
    final adapter = ref.read(adapterProvider);
    final map = adapter.entities['TodoCategory']?[id];
    if (map == null) return;
    final category = TodoCategory.fromJson(Map<String, dynamic>.from(map));
    final now = DateTime.now();
    final updated = category.copyWith(
      name: name,
      description: description,
      color: color,
      sortOrder: sortOrder,
      updatedAt: now,
    );
    final data = updated.toSyncJson();
    final seq = await adapter.nextSequence();
    await adapter.transaction(() async {
      await adapter.upsertEntity('TodoCategory', data);
      await adapter.enqueue(
        SyncQueueEntry(
          id: const Uuid().v4(),
          idempotencyKey: const Uuid().v4(),
          entityType: 'TodoCategory',
          entityId: id,
          operation: SyncOperation.update,
          payload: jsonEncode(data),
          version: category.version,
          localSequence: seq,
          createdAt: now,
        ),
      );
    });
    ref.invalidateSelf();
    ref.invalidate(pendingCategoryCountProvider);
  }

  Future<void> deleteCategory(TodoCategory category) async {
    final adapter = ref.read(adapterProvider);
    await adapter.softDeleteEntity('TodoCategory', category.id);
    final map = adapter.entities['TodoCategory']?[category.id];
    if (map == null) return;
    final seq = await adapter.nextSequence();
    await adapter.enqueue(
      SyncQueueEntry(
        id: const Uuid().v4(),
        idempotencyKey: const Uuid().v4(),
        entityType: 'TodoCategory',
        entityId: category.id,
        operation: SyncOperation.delete,
        payload: jsonEncode(Map<String, dynamic>.from(map)),
        version: category.version,
        localSequence: seq,
        createdAt: DateTime.now(),
      ),
    );
    ref.invalidateSelf();
    ref.invalidate(pendingCategoryCountProvider);
  }

  Future<void> triggerSync() async {
    try {
      final sync = await ref.read(universalSyncProvider.future);
      await sync.engine.sync();
    } catch (_) {}
    ref.invalidateSelf();
    ref.invalidate(pendingCategoryCountProvider);
    ref.invalidate(pendingCountProvider);
  }

  void resetAndInvalidate() {
    ref.invalidateSelf();
    ref.invalidate(pendingCategoryCountProvider);
    ref.invalidate(pendingCountProvider);
  }
}

final categoryListProvider =
    AsyncNotifierProvider<CategoryListNotifier, List<TodoCategory>>(
      CategoryListNotifier.new,
    );
