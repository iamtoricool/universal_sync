import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import 'category_list_page.dart';
import 'category_providers.dart';
import 'manage_todo_page.dart';
import 'providers.dart';
import 'sync_status_indicator.dart';
import 'todo_tile.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosAsync = ref.watch(todoListProvider);
    final categoriesAsync = ref.watch(categoryListProvider);
    final selectedCategoryId = ref.watch(selectedCategoryIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('universal_sync — Todos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            tooltip: 'Categories',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CategoryListPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync',
            onPressed: () => ref.read(todoListProvider.notifier).triggerSync(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => _signOut(ref),
          ),
        ],
      ),
      body: Column(
        children: [
          const SyncStatusIndicator(),
          categoriesAsync.when(
            data: (categories) {
              if (categories.isEmpty) return const SizedBox.shrink();
              return SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: selectedCategoryId == null,
                      onSelected: (_) =>
                          ref.read(selectedCategoryIdProvider.notifier).state =
                              null,
                    ),
                    const SizedBox(width: 6),
                    ...categories.map(
                      (cat) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(cat.name),
                          selected: selectedCategoryId == cat.id,
                          onSelected: (_) =>
                              ref
                                      .read(selectedCategoryIdProvider.notifier)
                                      .state =
                                  cat.id,
                          avatar: CircleAvatar(
                            backgroundColor: Color(
                              int.parse(cat.color.replaceFirst('#', '0xFF')),
                            ),
                            radius: 6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox(height: 4),
            error: (_, _) => const SizedBox.shrink(),
          ),
          Expanded(
            child: todosAsync.when(
              data: (todos) {
                final filtered = selectedCategoryId == null
                    ? todos
                    : todos
                          .where((t) => t.categoryId == selectedCategoryId)
                          .toList();
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No todos yet. Tap + to add one.'),
                  );
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => TodoTile(todo: filtered[i]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ManageTodoPage()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _signOut(WidgetRef ref) async {
    try {
      final sync = await ref.read(universalSyncProvider.future);
      sync.dispose();
    } catch (_) {}
    final adapter = ref.read(adapterProvider);
    adapter.reset();
    ref.invalidate(universalSyncProvider);
    ref.invalidate(adapterProvider);
    ref.invalidate(todoListProvider);
    ref.invalidate(pendingCountProvider);
    ref.invalidate(syncStateProvider);
    ref.invalidate(categoryListProvider);
    ref.invalidate(pendingCategoryCountProvider);
    ref.invalidate(selectedCategoryIdProvider);
    await ref.read(authNotifierProvider.notifier).signout();
  }
}
