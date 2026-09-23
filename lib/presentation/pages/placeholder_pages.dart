import 'package:fl_chart/fl_chart.dart';
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


class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  late DateTime _selectedMonth;

  final _monthFormatter = DateFormat('MMMM yyyy');

  final List<Color> _chartColors = [
    Colors.teal,
    Colors.orange,
    Colors.indigo,
    Colors.pink,
    Colors.amber,
    Colors.purple,
    Colors.blue,
    Colors.green,
  ];

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(allTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reports',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Understand your spending habits',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: transactionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Unable to load reports:\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (transactions) {
          return _buildReport(context, transactions);
        },
      ),
    );
  }

  Widget _buildReport(
      BuildContext context,
      List<Transaction> transactions,
      ) {
    final monthlyExpenses = transactions.where((transaction) {
      final date = transaction.date.toLocal();

      return transaction.type == TransactionType.expense &&
          date.year == _selectedMonth.year &&
          date.month == _selectedMonth.month;
    }).toList();

    final totals = <String, double>{};

    for (final transaction in monthlyExpenses) {
      totals.update(
        transaction.categoryId,
            (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }

    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalExpense = monthlyExpenses.fold<double>(
      0,
          (sum, transaction) => sum + transaction.amount,
    );

    final topCategory = entries.isEmpty ? null : entries.first;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(allTransactionsProvider);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _MonthSelector(
                  month: _selectedMonth,
                  formatter: _monthFormatter,
                  onPrevious: () => _changeMonth(-1),
                  onNext: () => _changeMonth(1),
                ),
                const SizedBox(height: 16),
                _OverviewCard(
                  totalExpense: totalExpense,
                  transactionCount: monthlyExpenses.length,
                  topCategory: topCategory?.key,
                ),
                const SizedBox(height: 16),
                if (entries.isEmpty)
                  const _EmptyReportState()
                else ...[
                  _SectionTitle(
                    title: 'Spending by category',
                    subtitle: 'Where your money went this month',
                  ),
                  const SizedBox(height: 12),
                  _CategoryChart(
                    entries: entries,
                    total: totalExpense,
                    colors: _chartColors,
                  ),
                  const SizedBox(height: 20),
                  _SectionTitle(
                    title: 'Category breakdown',
                    subtitle: 'Detailed spending distribution',
                  ),
                  const SizedBox(height: 12),
                  ...entries.asMap().entries.map(
                        (entry) => _CategoryProgressTile(
                      category: entry.value.key,
                      amount: entry.value.value,
                      total: totalExpense,
                      color: _chartColors[
                      entry.key % _chartColors.length],
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.month,
    required this.formatter,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final DateFormat formatter;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: Text(
                formatter.format(month),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.totalExpense,
    required this.transactionCount,
    required this.topCategory,
  });

  final double totalExpense;
  final int transactionCount;
  final String? topCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withOpacity(0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total expense',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppUtils.formatCurrency(totalExpense),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _OverviewMetric(
                  label: 'Transactions',
                  value: '$transactionCount',
                ),
              ),
              Expanded(
                child: _OverviewMetric(
                  label: 'Top category',
                  value: topCategory ?? 'N/A',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _CategoryChart extends StatelessWidget {
  const _CategoryChart({
    required this.entries,
    required this.total,
    required this.colors,
  });

  final List<MapEntry<String, double>> entries;
  final double total;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 230,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 48,
                  sectionsSpace: 3,
                  sections: [
                    for (var index = 0; index < entries.length; index++)
                      PieChartSectionData(
                        value: entries[index].value,
                        color: colors[index % colors.length],
                        radius: 76,
                        title: _percentage(
                          entries[index].value,
                          total,
                        ),
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                for (var index = 0; index < entries.length; index++)
                  _ChartLegendItem(
                    label: entries[index].key,
                    color: colors[index % colors.length],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _percentage(double amount, double total) {
    if (total == 0) return '0%';

    return '${(amount / total * 100).round()}%';
  }
}

class _ChartLegendItem extends StatelessWidget {
  const _ChartLegendItem({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _CategoryProgressTile extends StatelessWidget {
  const _CategoryProgressTile({
    required this.category,
    required this.amount,
    required this.total,
    required this.color,
  });

  final String category;
  final double amount;
  final double total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percentage = total == 0 ? 0.0 : amount / total;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(
                    Icons.category_outlined,
                    size: 19,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  AppUtils.formatCurrency(amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: percentage,
                      minHeight: 7,
                      backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(percentage * 100).round()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _EmptyReportState extends StatelessWidget {
  const _EmptyReportState();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.pie_chart_outline,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 14),
            const Text(
              'No expense data available',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Add expenses for this month to see your spending report.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
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
