import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'manage_todo_page.dart';
import 'providers.dart';
import 'todo.dart';

class TodoTile extends ConsumerWidget {
  final Todo todo;
  const TodoTile({super.key, required this.todo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Checkbox(
        value: todo.isDone,
        onChanged: (_) => ref.read(todoListProvider.notifier).toggleDone(todo),
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
        onPressed: () => ref.read(todoListProvider.notifier).deleteTodo(todo),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ManageTodoPage(todo: todo)),
      ),
    );
  }
}
