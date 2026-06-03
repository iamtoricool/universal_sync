import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'category_providers.dart';
import 'providers.dart';
import 'todo.dart';

class ManageTodoPage extends ConsumerStatefulWidget {
  final Todo? todo;
  const ManageTodoPage({super.key, this.todo});

  @override
  ConsumerState<ManageTodoPage> createState() => _ManageTodoPageState();
}

class _ManageTodoPageState extends ConsumerState<ManageTodoPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  String? _selectedCategoryId;
  bool _initialized = false;

  bool get _isEditing => widget.todo != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.todo?.description ?? '',
    );
    _selectedCategoryId = widget.todo?.categoryId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      if (widget.todo == null && _selectedCategoryId == null) {
        _selectedCategoryId = ref.read(selectedCategoryIdProvider);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isEditing) {
      await ref
          .read(todoListProvider.notifier)
          .updateTodo(
            widget.todo!.id,
            _titleController.text.trim(),
            _descriptionController.text.trim(),
            categoryId: _selectedCategoryId,
          );
    } else {
      await ref
          .read(todoListProvider.notifier)
          .addTodo(
            _titleController.text.trim(),
            _descriptionController.text.trim(),
            categoryId: _selectedCategoryId,
          );
    }
    if (mounted) Navigator.pop(context);
  }

  Widget _buildCategoryDropdown() {
    final categoriesAsync = ref.watch(categoryListProvider);
    return categoriesAsync.when(
      data: (categories) => DropdownButtonFormField<String?>(
        initialValue: _selectedCategoryId,
        decoration: const InputDecoration(labelText: 'Category'),
        items: [
          const DropdownMenuItem(value: null, child: Text('None')),
          ...categories.map(
            (cat) => DropdownMenuItem(
              value: cat.id,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Color(
                      int.parse(cat.color.replaceFirst('#', '0xFF')),
                    ),
                    radius: 6,
                  ),
                  const SizedBox(width: 8),
                  Text(cat.name),
                ],
              ),
            ),
          ),
        ],
        onChanged: (v) => setState(() => _selectedCategoryId = v),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Todo' : 'New Todo')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Title is required'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              _buildCategoryDropdown(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(_isEditing ? 'Update' : 'Create'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
