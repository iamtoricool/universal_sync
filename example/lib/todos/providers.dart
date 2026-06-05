import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_sync/universal_sync.dart';
import 'package:uuid/uuid.dart';

import '../auth/auth_provider.dart';
import 'category.dart';
import 'category_providers.dart';
import 'entity_notifier.dart';
import 'rest_remote_adapter.dart';
import 'todo.dart';

final adapterProvider = Provider<InMemoryLocalAdapter>((ref) {
  return InMemoryLocalAdapter();
});

final syncEngineProvider = FutureProvider<SyncEngine>((ref) async {
  final adapter = ref.watch(adapterProvider);
  final dio = ref.watch(dioProvider);
  final remote = RestRemoteAdapter(dio: dio);
  final engine = SyncEngine(
    localAdapter: adapter,
    remoteAdapter: remote,
    config: SyncConfig(
      entityOrder: {0: TodoCategory, 1: Todo},
      entityFromJson: {
        entityTypeName(TodoCategory): TodoCategory.fromJson,
        entityTypeName(Todo): Todo.fromJson,
      },
    ),
  );
  ref.onDispose(() => engine.dispose());
  return engine;
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

class TodoListNotifier extends EntityNotifier<Todo> {
  @override
  String get entityType => 'Todo';

  @override
  Todo Function(Map<String, dynamic>) get fromJson => Todo.fromJson;

  @override
  int Function(Todo, Todo) get sortComparator =>
      (a, b) => b.createdAt.compareTo(a.createdAt);

  Future<void> toggleDone(Todo todo) async {
    await modify(
      todo.id,
      (current) =>
          current.copyWith(isDone: !current.isDone, updatedAt: DateTime.now()),
    );
  }

  Future<void> addTodo(
    String title,
    String description, {
    String? categoryId,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    await insert(
      Todo(
        id: id,
        version: 0,
        createdAt: now,
        updatedAt: now,
        title: title,
        description: description,
        categoryId: categoryId,
      ),
    );
  }

  Future<void> updateTodo(
    String id,
    String title,
    String description, {
    String? categoryId,
  }) async {
    await modify(
      id,
      (current) => current.copyWith(
        title: title,
        description: description,
        categoryId: categoryId,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteTodo(String id) async {
    await delete(id);
  }
}

final todoListProvider = AsyncNotifierProvider<TodoListNotifier, List<Todo>>(
  TodoListNotifier.new,
);

final syncStateProvider = StreamProvider<SyncState>((ref) {
  final async = ref.watch(syncEngineProvider);
  final engine = async.valueOrNull;
  if (engine == null) return const Stream.empty();
  return _syncStates(engine);
});

Stream<SyncState> _syncStates(SyncEngine engine) async* {
  yield engine.currentState;
  await for (final state in engine.state) {
    yield state;
  }
}
