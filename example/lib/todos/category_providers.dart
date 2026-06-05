import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'category.dart';
import 'entity_notifier.dart';
import 'providers.dart';

final pendingCategoryCountProvider = FutureProvider<int>((ref) async {
  final adapter = ref.watch(adapterProvider);
  final pending = await adapter.fetchPendingEntries('TodoCategory', 9999);
  return pending.length;
});

class CategoryListNotifier extends EntityNotifier<TodoCategory> {
  @override
  String get entityType => 'TodoCategory';

  @override
  TodoCategory Function(Map<String, dynamic>) get fromJson =>
      TodoCategory.fromJson;

  @override
  int Function(TodoCategory, TodoCategory) get sortComparator =>
      (a, b) => a.sortOrder.compareTo(b.sortOrder);

  Future<void> addCategory(
    String name,
    String description,
    String color,
    int sortOrder,
  ) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    await insert(
      TodoCategory(
        id: id,
        version: 0,
        createdAt: now,
        updatedAt: now,
        name: name,
        description: description,
        color: color,
        sortOrder: sortOrder,
      ),
    );
  }

  Future<void> updateCategory(
    String id,
    String name,
    String description,
    String color,
    int sortOrder,
  ) async {
    await modify(
      id,
      (current) => current.copyWith(
        name: name,
        description: description,
        color: color,
        sortOrder: sortOrder,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteCategory(String id) async {
    await delete(id);
  }
}

final categoryListProvider =
    AsyncNotifierProvider<CategoryListNotifier, List<TodoCategory>>(
      CategoryListNotifier.new,
    );
