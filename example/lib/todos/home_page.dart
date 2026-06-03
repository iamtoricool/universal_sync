import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import 'manage_todo_page.dart';
import 'providers.dart';
import 'sync_status_indicator.dart';
import 'todo_tile.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosAsync = ref.watch(todoListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('universal_sync — Todos'),
        actions: [
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
          Expanded(
            child: todosAsync.when(
              data: (todos) => todos.isEmpty
                  ? const Center(child: Text('No todos yet. Tap + to add one.'))
                  : ListView.builder(
                      itemCount: todos.length,
                      itemBuilder: (_, i) => TodoTile(todo: todos[i]),
                    ),
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
    await ref.read(authNotifierProvider.notifier).signout();
  }
}
