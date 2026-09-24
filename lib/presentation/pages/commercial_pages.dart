import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/utils/constants.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../providers/category_provider.dart';
import '../providers/recurring_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/category_helper.dart';
import '../widgets/empty_view.dart';
import '../widgets/error_view.dart';

/// Commercial-style Categories screen. Page name unchanged.
class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  final searchController = TextEditingController();
  CategoryType selectedType = CategoryType.expense;
  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> editCategory([Category? existing]) async {
    final result = await showDialog<CategoryEditorResult>(
      context: context,
      builder: (_) => CategoryEditorDialog(
        initialName: existing?.name ?? '',
        initialType: existing?.type ?? selectedType,
        isEditing: existing != null,
      ),
    );

    if (result == null || !mounted) return;

    final now = DateTime.now();
    final category = Category(
      id: existing?.id ?? AppUtils.generateId(),
      name: result.name,
      type: result.type,
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
    if (!mounted) return;
    outcome.fold(
          (failure) => _message(failure.message),
          (_) {
        ref.invalidate(allCategoriesProvider);
        ref.invalidate(categoriesByTypeProvider(CategoryType.expense));
        ref.invalidate(categoriesByTypeProvider(CategoryType.income));
        _message(existing == null ? 'Category created' : 'Category updated');
      },
    );
  }

  Future<void> archiveCategory(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive category?'),
        content: Text(
          '“${category.name}” will remain available on historical transactions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await ref
        .read(categoryRepositoryProvider)
        .deleteCategory(category.id);

    result.fold(
          (failure) => _message(failure.message),
          (_) {
        ref.invalidate(allCategoriesProvider);
        _message('Category archived');
      },
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(allCategoriesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Categories',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editCategory(),
        icon: const Icon(Icons.add),
        label: const Text('New category'),
      ),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(message: 'Unable to load categories\n$error'),
        data: (items) {
          final filtered = items.where((category) {
            return category.type == selectedType &&
                category.name.toLowerCase().contains(query.toLowerCase());
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              Text(
                'Organize your money',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Create categories that match the way you earn and spend.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: searchController,
                onChanged: (value) => setState(() => query = value),
                decoration: InputDecoration(
                  hintText: 'Search categories',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                    onPressed: () {
                      searchController.clear();
                      setState(() => query = '');
                    },
                    icon: const Icon(Icons.clear),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SegmentedButton<CategoryType>(
                segments: const [
                  ButtonSegment(
                    value: CategoryType.expense,
                    label: Text('Expenses'),
                    icon: Icon(Icons.arrow_upward),
                  ),
                  ButtonSegment(
                    value: CategoryType.income,
                    label: Text('Income'),
                    icon: Icon(Icons.arrow_downward),
                  ),
                ],
                selected: {selectedType},
                onSelectionChanged: (value) {
                  setState(() => selectedType = value.first);
                },
              ),
              const SizedBox(height: 18),
              if (filtered.isEmpty)
                const EmptyView(
                  icon: Icons.category_outlined,
                  title: 'No categories found',
                  message: 'Create a category to keep your transactions organized.',
                )
              else
                ...filtered.map(
                      (category) => Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(
                          selectedType == CategoryType.income
                              ? Icons.trending_up
                              : Icons.category_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        category.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        category.isArchived ? 'Archived' : 'Active category',
                      ),
                      trailing: category.isArchived
                          ? const Chip(label: Text('Archived'))
                          : PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') editCategory(category);
                          if (value == 'archive') archiveCategory(category);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          PopupMenuItem(
                            value: 'archive',
                            child: Text('Archive'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Commercial-style monthly history. Page name unchanged.
class MonthlyHistoryPage extends ConsumerWidget {
  const MonthlyHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(allTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Monthly history',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: transactions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(message: 'Unable to load history\n$error'),
        data: (items) {
          final months = <DateTime>{
            for (final item in items)
              DateTime(item.date.year, item.date.month),
          }.toList()
            ..sort((a, b) => b.compareTo(a));

          if (months.isEmpty) {
            return const EmptyView(
              icon: Icons.calendar_month_outlined,
              title: 'No monthly history yet',
              message: 'Add transactions to start building your history.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: months.length,
            itemBuilder: (context, index) {
              final month = months[index];
              final monthItems = items.where((item) {
                return item.date.year == month.year &&
                    item.date.month == month.month;
              }).toList();

              final income = _total(monthItems, TransactionType.income);
              final expense = _total(monthItems, TransactionType.expense);
              final balance = income - expense;
              final ratio = income <= 0 ? 0.0 : (expense / income).clamp(0.0, 1.0);

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat('MMMM yyyy').format(month),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            '${monthItems.length} transactions',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _MiniMetric(
                              label: 'Income',
                              value: AppUtils.formatCurrency(income),
                              color: Colors.green,
                            ),
                          ),
                          Expanded(
                            child: _MiniMetric(
                              label: 'Expense',
                              value: AppUtils.formatCurrency(expense),
                              color: Colors.redAccent,
                            ),
                          ),
                          Expanded(
                            child: _MiniMetric(
                              label: 'Balance',
                              value: AppUtils.formatCurrency(balance),
                              color: balance >= 0 ? Colors.blue : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: ratio,
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(8),
                        color: ratio >= 1 ? Colors.red : Colors.teal,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        ratio == 0
                            ? 'No expense data'
                            : '${(ratio * 100).round()}% of income spent',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  double _total(List<Transaction> items, TransactionType type) {
    return items
        .where((item) => item.type == type)
        .fold<double>(0, (sum, item) => sum + item.amount);
  }
}





/// Commercial-style recurring expenses page. Page name unchanged.
class RecurringExpensesPage extends ConsumerWidget {
  const RecurringExpensesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(allRecurringRulesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Recurring expenses',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recurring expense form coming soon')),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add recurring'),
      ),
      body: rules.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          message: 'Unable to load recurring expenses\n$error',
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyView(
              icon: Icons.repeat_outlined,
              title: 'No recurring expenses',
              message: 'Add subscriptions and regular bills to automate tracking.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final rule = items[index];

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.repeat,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    rule.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      '${rule.frequency.name} • next ${AppUtils.formatDate(rule.nextOccurrenceDate)}',
                    ),
                  ),
                  trailing: Text(
                    AppUtils.formatCurrency(rule.amount),
                    style: const TextStyle(fontWeight: FontWeight.bold),
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







class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 5),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}






