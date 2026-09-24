import 'package:flutter/material.dart';

import '../../domain/entities/category.dart';

class CategoryEditorResult {
  const CategoryEditorResult({
    required this.name,
    required this.type,
  });

  final String name;
  final CategoryType type;
}

class CategoryEditorDialog extends StatefulWidget {
  const CategoryEditorDialog({
    super.key,
    required this.initialName,
    required this.initialType,
    required this.isEditing,
  });

  final String initialName;
  final CategoryType initialType;
  final bool isEditing;

  @override
  State<CategoryEditorDialog> createState() =>
      _CategoryEditorDialogState();
}

class _CategoryEditorDialogState
    extends State<CategoryEditorDialog> {
  late final TextEditingController _nameController;

  late CategoryType _selectedType;
  String? _error;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.initialName,
    );

    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _error = 'Please enter a category name';
      });
      return;
    }

    Navigator.of(context).pop(
      CategoryEditorResult(
        name: name,
        type: _selectedType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(
        widget.isEditing ? 'Edit category' : 'Create category',
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                autofocus: true,
                maxLength: 40,
                textCapitalization:
                TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Category name',
                  hintText: 'Example: Groceries',
                  prefixIcon: const Icon(Icons.label_outline),
                  errorText: _error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onChanged: (_) {
                  if (_error != null) {
                    setState(() {
                      _error = null;
                    });
                  }
                },
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              Text(
                'Category type',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<CategoryType>(
                  segments: const [
                    ButtonSegment<CategoryType>(
                      value: CategoryType.expense,
                      label: Text('Expense'),
                      icon: Icon(Icons.arrow_upward),
                    ),
                    ButtonSegment<CategoryType>(
                      value: CategoryType.income,
                      label: Text('Income'),
                      icon: Icon(Icons.arrow_downward),
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (value) {
                    setState(() {
                      _selectedType = value.first;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: Icon(widget.isEditing ? Icons.save_outlined : Icons.add),
          label: Text(widget.isEditing ? 'Save changes' : 'Create'),
        ),
      ],
    );
  }
}