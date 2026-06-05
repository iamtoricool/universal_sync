import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'manage_todo_page.dart';
import 'providers.dart';
import 'todo.dart';

class TodoTile extends ConsumerWidget {
  final Todo todo;
  const TodoTile({super.key, required this.todo});

  Color? _categoryColor(WidgetRef ref) {
    if (todo.categoryId == null) return null;
    final adapter = ref.read(adapterProvider);
    final map = adapter.entities['TodoCategory']?[todo.categoryId];
    if (map == null) return null;
    final colorStr = map['color'] as String? ?? '#1976D2';
    return Color(int.parse(colorStr.replaceFirst('#', '0xFF')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catColor = _categoryColor(ref);
    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (catColor != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: CircleAvatar(backgroundColor: catColor, radius: 5),
            ),
          Checkbox(
            value: todo.isDone,
            onChanged: (_) =>
                ref.read(todoListProvider.notifier).toggleDone(todo),
          ),
        ],
      ),
      title: Text(
        todo.title,
        style: TextStyle(
          decoration: todo.isDone ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: todo.description.isNotEmpty ? Text(todo.description) : null,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () =>
            ref.read(todoListProvider.notifier).deleteTodo(todo.id),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ManageTodoPage(todo: todo)),
      ),
    );
  }
}
