import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'category.dart';
import 'category_providers.dart';

class CategoryListPage extends ConsumerWidget {
  const CategoryListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: categoriesAsync.when(
        data: (categories) => categories.isEmpty
            ? const Center(child: Text('No categories yet. Tap + to add one.'))
            : ListView.builder(
                itemCount: categories.length,
                itemBuilder: (_, i) => _CategoryTile(category: categories[i]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showCategoryDialog(
    BuildContext context,
    WidgetRef ref, [
    TodoCategory? existing,
  ]) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descController = TextEditingController(
      text: existing?.description ?? '',
    );
    final colorController = TextEditingController(
      text: existing?.color ?? '#1976D2',
    );
    final sortController = TextEditingController(
      text: (existing?.sortOrder ?? 0).toString(),
    );
    final isEditing = existing != null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Edit Category' : 'New Category'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: colorController,
                decoration: const InputDecoration(labelText: 'Color (hex)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: sortController,
                decoration: const InputDecoration(labelText: 'Sort Order'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isEditing ? 'Update' : 'Create'),
          ),
        ],
      ),
    );

    if (saved != true) return;
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    final color = colorController.text.trim();
    final sortOrder = int.tryParse(sortController.text.trim()) ?? 0;

    if (isEditing) {
      await ref
          .read(categoryListProvider.notifier)
          .updateCategory(
            existing.id,
            name,
            descController.text.trim(),
            color,
            sortOrder,
          );
    } else {
      await ref
          .read(categoryListProvider.notifier)
          .addCategory(name, descController.text.trim(), color, sortOrder);
    }
  }
}

class _CategoryTile extends ConsumerWidget {
  final TodoCategory category;
  const _CategoryTile({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Color(int.parse(category.color.replaceFirst('#', '0xFF')));
    return ListTile(
      leading: CircleAvatar(backgroundColor: color, radius: 16),
      title: Text(category.name),
      subtitle: category.description.isNotEmpty
          ? Text(category.description)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              final page = CategoryListPage();
              page._showCategoryDialog(context, ref, category);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => ref
                .read(categoryListProvider.notifier)
                .deleteCategory(category.id),
          ),
        ],
      ),
    );
  }
}
