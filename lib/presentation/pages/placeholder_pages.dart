import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/constants.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/category.dart';
import '../providers/category_provider.dart';
import '../providers/recurring_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/preferences_provider.dart';

class _CategoryEditorDialog extends StatefulWidget {
  final TextEditingController controller;
  final CategoryType initialType;
  final bool isEditing;

  const _CategoryEditorDialog({
    required this.controller,
    required this.initialType,
    required this.isEditing,
  });

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  late CategoryType _type = widget.initialType;
  String? _error;

  void _submit() {
    final name = widget.controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a category name');
      return;
    }
    Navigator.of(context).pop((name, _type));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEditing ? 'Edit category' : 'New category'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: widget.controller,
              autofocus: true,
              maxLength: 40,
              decoration: InputDecoration(
                labelText: 'Category name',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            SegmentedButton<CategoryType>(
              segments: const [
                ButtonSegment(
                  value: CategoryType.expense,
                  label: Text('Expense'),
                ),
                ButtonSegment(
                  value: CategoryType.income,
                  label: Text('Income'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (value) =>
                  setState(() => _type = value.first),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }
}

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  Future<void> _editCategory([Category? existing]) async {
    final nameController = TextEditingController(text: existing?.name);
    final result = await showDialog<(String, CategoryType)>(
      context: context,
      builder: (dialogContext) => _CategoryEditorDialog(
        controller: nameController,
        initialType: existing?.type ?? CategoryType.expense,
        isEditing: existing != null,
      ),
    );
    nameController.dispose();
    if (result == null || !mounted) return;
    final now = DateTime.now();
    final category = Category(
      id: existing?.id ?? AppUtils.generateId(),
      name: result.$1,
      type: result.$2,
      icon: existing?.icon,
      color: existing?.color,
      isArchived: false,
      createdAt: existing?.createdAt ?? now,
    );
    final repository = ref.read(categoryRepositoryProvider);
    final operation = existing == null
        ? repository.addCategory(category)
        : repository.updateCategory(category);
    final outcome = await operation;
    outcome.fold(
      (failure) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message))),
      (_) {
        ref.invalidate(allCategoriesProvider);
        ref.invalidate(categoriesByTypeProvider(CategoryType.expense));
        ref.invalidate(categoriesByTypeProvider(CategoryType.income));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existing == null
                  ? 'Category created successfully'
                  : 'Category updated successfully',
            ),
          ),
        );
      },
    );
  }

  Future<void> _archiveCategory(Category category) async {
    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive category?'),
        content: Text('“${category.name}” will remain on historical transactions.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Archive')),
        ],
      ),
    );
    if (shouldArchive != true || !mounted) return;
    final result = await ref.read(categoryRepositoryProvider).deleteCategory(category.id);
    result.fold(
      (failure) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message))),
      (_) => ref.invalidate(allCategoriesProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(allCategoriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(onPressed: _editCategory, icon: const Icon(Icons.add)),
        ],
      ),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Unable to load categories: $error')),
        data: (items) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Organize your money', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('Create categories that match the way you spend.',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            for (final category in items)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Icon(
                    category.type == CategoryType.income
                        ? Icons.trending_up
                        : Icons.category,
                  ),
                  title: Text(category.name),
                  subtitle: Text(category.type.name),
                  trailing: category.isArchived
                      ? const Chip(label: Text('Archived'))
                      : PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _editCategory(category);
                            if (value == 'archive') _archiveCategory(category);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'archive', child: Text('Archive')),
                          ],
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MonthlyHistoryPage extends ConsumerWidget {
  const MonthlyHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(allTransactionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Monthly History')),
      body: transactions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Unable to load history: $error')),
        data: (items) {
          final months = <DateTime>{
            for (final item in items) DateTime(item.date.year, item.date.month),
          }.toList()
            ..sort((a, b) => b.compareTo(a));
          if (months.isEmpty) {
            return const Center(child: Text('Add transactions to see monthly history.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: months.length,
            itemBuilder: (context, index) {
              final month = months[index];
              final monthItems = items.where((item) =>
                  item.date.year == month.year && item.date.month == month.month);
              final income = monthItems
                  .where((item) => item.type == TransactionType.income)
                  .fold<double>(0, (sum, item) => sum + item.amount);
              final expense = monthItems
                  .where((item) => item.type == TransactionType.expense)
                  .fold<double>(0, (sum, item) => sum + item.amount);
              return Card(
                child: ListTile(
                  title: Text(DateFormat('MMMM yyyy').format(month)),
                  subtitle: Text(
                    'Income ${AppUtils.formatCurrency(income)} • '
                    'Expense ${AppUtils.formatCurrency(expense)}',
                  ),
                  trailing: Text(
                    AppUtils.formatCurrency(income - expense),
                    style: TextStyle(
                      color: income >= expense ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(allTransactionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: transactions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Unable to load reports: $error')),
        data: (items) {
          final expenses = items.where((item) => item.type == TransactionType.expense);
          final totals = <String, double>{};
          for (final item in expenses) {
            totals.update(item.categoryId, (value) => value + item.amount,
                ifAbsent: () => item.amount);
          }
          final entries = totals.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          if (entries.isEmpty) {
            return const Center(child: Text('Add expenses to see reports.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Spending by category',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final entry in entries)
                ListTile(
                  title: Text(entry.key),
                  trailing: Text(AppUtils.formatCurrency(entry.value)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkMode = ref.watch(preferencesNotifierProvider)['isDarkMode'] as bool;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Dark theme'),
            subtitle: const Text('Use a dark appearance'),
            value: darkMode,
            onChanged: (value) =>
                ref.read(preferencesNotifierProvider.notifier).setDarkMode(value),
          ),
          const ListTile(
            title: Text('Currency'),
            subtitle: Text('Bangladeshi Taka (BDT)'),
            leading: Icon(Icons.currency_exchange),
          ),
        ],
      ),
    );
  }
}

class RecurringExpensesPage extends ConsumerWidget {
  const RecurringExpensesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(allRecurringRulesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Expenses')),
      body: rules.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Unable to load recurring rules: $error')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No recurring expenses configured.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final rule = items[index];
                  return Card(
                    child: ListTile(
                      title: Text(rule.title),
                      subtitle: Text(
                        '${rule.frequency.name} • next ${AppUtils.formatDate(rule.nextOccurrenceDate)}',
                      ),
                      trailing: Text(AppUtils.formatCurrency(rule.amount)),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
