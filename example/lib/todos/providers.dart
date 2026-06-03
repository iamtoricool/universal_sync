import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_sync/universal_sync.dart';
import 'package:uuid/uuid.dart';

import '../auth/auth_provider.dart';
import 'category.dart';
import 'category_providers.dart';
import 'rest_remote_adapter.dart';
import 'todo.dart';

final adapterProvider = Provider<InMemoryLocalAdapter>((ref) {
  return InMemoryLocalAdapter();
});

final universalSyncProvider = FutureProvider<UniversalSync>((ref) async {
  final adapter = ref.watch(adapterProvider);
  final dio = ref.watch(dioProvider);
  final remote = RestRemoteAdapter(dio: dio);
  final sync = UniversalSync(
    localAdapter: adapter,
    remoteAdapter: remote,
    config: SyncConfig(entityOrder: [TodoCategory, Todo]),
    entityFromJson: {Todo: Todo.fromJson, TodoCategory: TodoCategory.fromJson},
  );
  await sync.init();
  ref.onDispose(() => sync.dispose());
  return sync;
});

final pendingCountProvider = FutureProvider<int>((ref) async {
  final adapter = ref.watch(adapterProvider);
  final pending = await adapter.fetchPendingEntries('Todo', 9999);
  return pending.length;
});

final selectedCategoryIdProvider = StateProvider<String?>((ref) => null);

final totalPendingCountProvider = FutureProvider<int>((ref) async {
  final todoPending = await ref.watch(pendingCountProvider.future);
  final catPending = await ref.watch(pendingCategoryCountProvider.future);
  return todoPending + catPending;
});

class TodoListNotifier extends AsyncNotifier<List<Todo>> {
  @override
  Future<List<Todo>> build() async {
    ref.watch(syncStateProvider);
    final adapter = ref.read(adapterProvider);
    final entities = adapter.entities;
    final todoMaps = entities['Todo']?.values ?? <Map<String, dynamic>>[];
    final todos = todoMaps
        .where((m) => m['deletedAt'] == null)
        .map((m) => Todo.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    todos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return todos;
  }

  Future<void> addTodo(
    String title,
    String description, {
    String? categoryId,
  }) async {
    final adapter = ref.read(adapterProvider);
    final id = const Uuid().v4();
    final now = DateTime.now();
    final todo = Todo(
      id: id,
      version: 0,
      createdAt: now,
      updatedAt: now,
      title: title,
      description: description,
      categoryId: categoryId,
    );
    final data = todo.toSyncJson();
    final seq = await adapter.nextSequence();
    await adapter.transaction(() async {
      await adapter.upsertEntity('Todo', data);
      await adapter.enqueue(
        SyncQueueEntry(
          id: const Uuid().v4(),
          idempotencyKey: const Uuid().v4(),
          entityType: 'Todo',
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
    ref.invalidate(pendingCountProvider);
  }

  Future<void> updateTodo(
    String id,
    String title,
    String description, {
    String? categoryId,
  }) async {
    final adapter = ref.read(adapterProvider);
    final map = adapter.entities['Todo']?[id];
    if (map == null) return;
    final todo = Todo.fromJson(Map<String, dynamic>.from(map));
    final now = DateTime.now();
    final updated = todo.copyWith(
      title: title,
      description: description,
      categoryId: categoryId,
      updatedAt: now,
    );
    final data = updated.toSyncJson();
    final seq = await adapter.nextSequence();
    await adapter.transaction(() async {
      await adapter.upsertEntity('Todo', data);
      await adapter.enqueue(
        SyncQueueEntry(
          id: const Uuid().v4(),
          idempotencyKey: const Uuid().v4(),
          entityType: 'Todo',
          entityId: id,
          operation: SyncOperation.update,
          payload: jsonEncode(data),
          version: todo.version,
          localSequence: seq,
          createdAt: now,
        ),
      );
    });
    ref.invalidateSelf();
    ref.invalidate(pendingCountProvider);
  }

  Future<void> toggleDone(Todo todo) async {
    final adapter = ref.read(adapterProvider);
    final map = adapter.entities['Todo']?[todo.id];
    if (map == null) return;
    final current = Todo.fromJson(Map<String, dynamic>.from(map));
    final now = DateTime.now();
    final updated = current.copyWith(isDone: !current.isDone, updatedAt: now);
    final data = updated.toSyncJson();
    final seq = await adapter.nextSequence();
    await adapter.transaction(() async {
      await adapter.upsertEntity('Todo', data);
      await adapter.enqueue(
        SyncQueueEntry(
          id: const Uuid().v4(),
          idempotencyKey: const Uuid().v4(),
          entityType: 'Todo',
          entityId: todo.id,
          operation: SyncOperation.update,
          payload: jsonEncode(data),
          version: current.version,
          localSequence: seq,
          createdAt: now,
        ),
      );
    });
    ref.invalidateSelf();
    ref.invalidate(pendingCountProvider);
  }

  Future<void> deleteTodo(Todo todo) async {
    final adapter = ref.read(adapterProvider);
    await adapter.softDeleteEntity('Todo', todo.id);
    final map = adapter.entities['Todo']?[todo.id];
    if (map == null) return;
    final seq = await adapter.nextSequence();
    await adapter.enqueue(
      SyncQueueEntry(
        id: const Uuid().v4(),
        idempotencyKey: const Uuid().v4(),
        entityType: 'Todo',
        entityId: todo.id,
        operation: SyncOperation.delete,
        payload: jsonEncode(Map<String, dynamic>.from(map)),
        version: todo.version,
        localSequence: seq,
        createdAt: DateTime.now(),
      ),
    );
    ref.invalidateSelf();
    ref.invalidate(pendingCountProvider);
  }

  Future<void> triggerSync() async {
    try {
      final sync = await ref.read(universalSyncProvider.future);
      await sync.engine.sync();
    } catch (_) {}
    ref.invalidateSelf();
    ref.invalidate(pendingCountProvider);
    ref.invalidate(pendingCategoryCountProvider);
  }

  void resetAndInvalidate() {
    ref.invalidateSelf();
    ref.invalidate(pendingCountProvider);
    ref.invalidate(pendingCategoryCountProvider);
  }
}

final todoListProvider = AsyncNotifierProvider<TodoListNotifier, List<Todo>>(
  TodoListNotifier.new,
);

final syncStateProvider = StreamProvider<SyncState>((ref) {
  final async = ref.watch(universalSyncProvider);
  final sync = async.valueOrNull;
  if (sync == null) return const Stream.empty();
  return _syncStates(sync.engine);
});

Stream<SyncState> _syncStates(SyncEngine engine) async* {
  yield engine.currentState;
  await for (final state in engine.state) {
    yield state;
  }
}
