import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/routes/app_router.dart';
import '../../core/utils/constants.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../providers/category_provider.dart';
import '../providers/database_provider.dart';
import '../providers/preferences_provider.dart';
import '../providers/limit_provider.dart';
import '../providers/recurring_provider.dart';
import '../providers/transaction_provider.dart';
import '../widgets/category_helper.dart';

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
        error: (error, _) => _ErrorView(message: 'Unable to load categories\n$error'),
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
                const _EmptyView(
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
        error: (error, _) => _ErrorView(message: 'Unable to load history\n$error'),
        data: (items) {
          final months = <DateTime>{
            for (final item in items)
              DateTime(item.date.year, item.date.month),
          }.toList()
            ..sort((a, b) => b.compareTo(a));

          if (months.isEmpty) {
            return const _EmptyView(
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

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  DateTime selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  final colors = const [
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
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(allTransactionsProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reports',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: transactionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, _) => _ErrorView(
          message: 'Unable to load transactions\n$error',
        ),
        data: (transactions) {
          return categoriesAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, _) => _ErrorView(
              message: 'Unable to load categories\n$error',
            ),
            data: (categories) {
              return _reportBody(
                context,
                transactions,
                categories,
              );
            },
          );
        },
      ),
    );
  }

  Widget _reportBody(
      BuildContext context,
      List<Transaction> transactions,
      List<Category> categories,
      ) {
    // Convert category ID into readable category name.
    final categoryNames = <String, String>{
      for (final category in categories)
        category.id: category.name,
    };

    final expenses = transactions.where((item) {
      final date = item.date.toLocal();

      return item.type == TransactionType.expense &&
          date.year == selectedMonth.year &&
          date.month == selectedMonth.month;
    }).toList();

    final totals = <String, double>{};

    for (final item in expenses) {
      final categoryName =
      categoryNames[item.categoryId]?.trim().isNotEmpty == true
          ? categoryNames[item.categoryId]!
          : 'Other';

      totals.update(
        categoryName,
            (value) => value + item.amount,
        ifAbsent: () => item.amount,
      );
    }

    final entries = totals.entries.toList()
      ..sort(
            (a, b) => b.value.compareTo(a.value),
      );

    final totalExpense = expenses.fold<double>(
      0,
          (sum, item) => sum + item.amount,
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(allTransactionsProvider);
        ref.invalidate(allCategoriesProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _MonthSelector(
            month: selectedMonth,
            onPrevious: () {
              setState(() {
                selectedMonth = DateTime(
                  selectedMonth.year,
                  selectedMonth.month - 1,
                );
              });
            },
            onNext: () {
              setState(() {
                selectedMonth = DateTime(
                  selectedMonth.year,
                  selectedMonth.month + 1,
                );
              });
            },
          ),

          const SizedBox(height: 16),

          _ReportHeader(
            total: totalExpense,
            count: expenses.length,
            topCategory: entries.isEmpty ? null : entries.first.key,
          ),

          const SizedBox(height: 20),

          if (entries.isEmpty)
            const _EmptyView(
              icon: Icons.pie_chart_outline,
              title: 'No report data',
              message: 'Add expenses for this month to see your report.',
            )
          else ...[
            Text(
              'Spending breakdown',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Card(
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
                            for (var index = 0;
                            index < entries.length;
                            index++)
                              PieChartSectionData(
                                value: entries[index].value,
                                color: colors[index % colors.length],
                                radius: 76,
                                title: _percentage(
                                  entries[index].value,
                                  totalExpense,
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
                        for (var index = 0;
                        index < entries.length;
                        index++)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 5,
                                backgroundColor:
                                colors[index % colors.length],
                              ),
                              const SizedBox(width: 5),
                              Text(
                                entries[index].key,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Category details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            ...entries.asMap().entries.map(
                  (entry) => _CategoryBreakdown(
                name: entry.value.key,
                amount: entry.value.value,
                total: totalExpense,
                color: colors[entry.key % colors.length],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _percentage(double value, double total) {
    if (total == 0) return '0%';

    return '${(value / total * 100).round()}%';
  }
}

/// Commercial-style settings page. Page name unchanged.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final preferences = ref.watch(preferencesNotifierProvider);
    final darkMode = preferences['isDarkMode'] as bool? ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
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
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: Colors.white24,
                  child: Icon(
                    Icons.settings_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pocket Ledger',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Customize your finance tracker',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SettingsSection(
            title: 'Appearance',
            subtitle: 'Personalize the app experience',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Dark theme'),
                subtitle: const Text('Use a darker appearance'),
                value: darkMode,
                onChanged: (value) {
                  ref
                      .read(preferencesNotifierProvider.notifier)
                      .setDarkMode(value);
                },
              ),
              const Divider(height: 24),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.currency_exchange),
                title: Text('Currency'),
                subtitle: Text('Bangladeshi Taka'),
                trailing: Text(
                  '৳ BDT',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Manage',
            subtitle: 'Configure your finance tracking options',
            children: [
              _SettingsTile(
                icon: Icons.category_outlined,
                title: 'Categories',
                subtitle: 'Manage income and expense categories',
                onTap: () => context.push(AppRoutes.categories),
              ),
              _SettingsTile(
                icon: Icons.repeat_outlined,
                title: 'Recurring expenses',
                subtitle: 'Manage subscriptions and recurring bills',
                onTap: () => context.push('/recurring-expenses'),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Data',
            subtitle: 'Protect and manage your finance data',
            children: [
              _SettingsTile(
                icon: Icons.file_download_outlined,
                title: 'Export data',
                subtitle: 'Export transactions as CSV or PDF',
                onTap: () => _comingSoon(context, 'Export data'),
              ),
              _SettingsTile(
                icon: Icons.backup_outlined,
                title: 'Backup and restore',
                subtitle: 'Protect your local expense data',
                onTap: () => _comingSoon(context, 'Backup and restore'),
              ),
              _SettingsTile(
                icon: Icons.delete_forever_outlined,
                title: 'Clear local database',
                subtitle: 'Delete all transactions and app data',
                onTap: () => _clearLocalDatabase(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature will be available soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

Future<void> _clearLocalDatabase(
    BuildContext context,
    WidgetRef ref,
    ) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Clear local database?'),
        content: const Text(
          'All transactions, categories, recurring expenses, '
              'payment methods, and monthly limits will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Clear everything'),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(databaseProvider).clearAllData();

    ref.invalidate(allTransactionsProvider);
    ref.invalidate(allCategoriesProvider);
    ref.invalidate(allRecurringRulesProvider);
    ref.invalidate(allLimitsProvider);
    ref.invalidate(monthlyLimitProvider);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Local database cleared successfully'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (error) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unable to clear database: $error'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
        error: (error, _) => _ErrorView(
          message: 'Unable to load recurring expenses\n$error',
        ),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyView(
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

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
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
                DateFormat('MMMM yyyy').format(month),
                style: const TextStyle(fontWeight: FontWeight.bold),
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

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({
    required this.total,
    required this.count,
    required this.topCategory,
  });

  final double total;
  final int count;
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
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 5),
          Text(
            AppUtils.formatCurrency(total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 29,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _WhiteMetric(
                  label: 'Transactions',
                  value: '$count',
                ),
              ),
              Expanded(
                child: _WhiteMetric(
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

class _WhiteMetric extends StatelessWidget {
  const _WhiteMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
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

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({
    required this.name,
    required this.amount,
    required this.total,
    required this.color,
  });

  final String name;
  final double amount;
  final double total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percentage = total <= 0 ? 0.0 : amount / total;

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
                  child: Icon(Icons.category_outlined, color: color, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  AppUtils.formatCurrency(amount),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(8),
                    color: color,
                  ),
                ),
                const SizedBox(width: 10),
                Text('${(percentage * 100).round()}%'),
              ],
            ),
          ],
        ),
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

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 58,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
