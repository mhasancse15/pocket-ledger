import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/services/export_service.dart';
import '../../core/utils/constants.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';

class ExportDataPage extends ConsumerStatefulWidget {
  const ExportDataPage({super.key});

  @override
  ConsumerState<ExportDataPage> createState() =>
      _ExportDataPageState();
}

class _ExportDataPageState
    extends ConsumerState<ExportDataPage> {
  static const purple = Color(0xFF5D56AA);

  final exportService = const ExportService();

  ExportFileType fileType = ExportFileType.csv;
  ExportPeriod period = ExportPeriod.currentMonth;

  DateTime selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  DateTimeRange? customRange;
  TransactionType? transactionType;
  String? categoryId;

  bool exporting = false;

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(
      allTransactionsProvider,
    );

    final categoriesAsync = ref.watch(
      allCategoriesProvider,
    );

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Export data',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: transactionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: purple,
          ),
        ),
        error: (error, _) {
          return Center(
            child: Text(
              'Unable to load transactions\n$error',
              textAlign: TextAlign.center,
            ),
          );
        },
        data: (transactions) {
          return categoriesAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                color: purple,
              ),
            ),
            error: (error, _) {
              return Center(
                child: Text(
                  'Unable to load categories\n$error',
                  textAlign: TextAlign.center,
                ),
              );
            },
            data: (categories) {
              return _buildContent(
                context,
                transactions: transactions,
                categories: categories,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, {
        required List<Transaction> transactions,
        required List<Category> categories,
      }) {
    final options = _currentOptions();

    final previewTransactions =
    exportService.filterTransactions(
      transactions: transactions,
      options: options,
    );

    final previewIncome = previewTransactions
        .where(
          (transaction) =>
      transaction.type == TransactionType.income,
    )
        .fold<double>(
      0,
          (sum, transaction) =>
      sum + transaction.amount,
    );

    final previewExpense = previewTransactions
        .where(
          (transaction) =>
      transaction.type == TransactionType.expense,
    )
        .fold<double>(
      0,
          (sum, transaction) =>
      sum + transaction.amount,
    );

    final availableCategories = categories.where(
          (category) {
        if (transactionType == null) return true;

        if (transactionType == TransactionType.expense) {
          return category.type == CategoryType.expense;
        }

        return category.type == CategoryType.income;
      },
    ).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        32,
      ),
      children: [
        const Text(
          'Export transactions',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Choose a format and filter the data you want to export.',
          style: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'File format',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<ExportFileType>(
          segments: const [
            ButtonSegment(
              value: ExportFileType.csv,
              label: Text('CSV'),
              icon: Icon(Icons.table_view_outlined),
            ),
            ButtonSegment(
              value: ExportFileType.pdf,
              label: Text('PDF'),
              icon: Icon(Icons.picture_as_pdf_outlined),
            ),
          ],
          selected: {
            fileType,
          },
          onSelectionChanged: exporting
              ? null
              : (selection) {
            setState(() {
              fileType = selection.first;
            });
          },
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<ExportPeriod>(
          value: period,
          decoration: _inputDecoration(
            label: 'Export period',
            icon: Icons.date_range_outlined,
          ),
          items: const [
            DropdownMenuItem(
              value: ExportPeriod.currentMonth,
              child: Text('Current month'),
            ),
            DropdownMenuItem(
              value: ExportPeriod.selectedMonth,
              child: Text('Selected month'),
            ),
            DropdownMenuItem(
              value: ExportPeriod.customRange,
              child: Text('Custom date range'),
            ),
            DropdownMenuItem(
              value: ExportPeriod.all,
              child: Text('All transactions'),
            ),
          ],
          onChanged: exporting
              ? null
              : (value) {
            if (value == null) return;

            setState(() {
              period = value;
            });
          },
        ),
        if (period == ExportPeriod.selectedMonth) ...[
          const SizedBox(height: 12),
          _monthSelector(),
        ],
        if (period == ExportPeriod.customRange) ...[
          const SizedBox(height: 12),
          _dateRangeSelector(),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<TransactionType?>(
          value: transactionType,
          decoration: _inputDecoration(
            label: 'Transaction type',
            icon: Icons.swap_vert,
          ),
          items: const [
            DropdownMenuItem<TransactionType?>(
              value: null,
              child: Text('All transactions'),
            ),
            DropdownMenuItem<TransactionType?>(
              value: TransactionType.expense,
              child: Text('Expenses only'),
            ),
            DropdownMenuItem<TransactionType?>(
              value: TransactionType.income,
              child: Text('Income only'),
            ),
          ],
          onChanged: exporting
              ? null
              : (value) {
            setState(() {
              transactionType = value;
              categoryId = null;
            });
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          value: categoryId,
          isExpanded: true,
          decoration: _inputDecoration(
            label: 'Category',
            icon: Icons.category_outlined,
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('All categories'),
            ),
            ...availableCategories.map(
                  (category) =>
                  DropdownMenuItem<String?>(
                    value: category.id,
                    child: Text(category.name),
                  ),
            ),
          ],
          onChanged: exporting
              ? null
              : (value) {
            setState(() {
              categoryId = value;
            });
          },
        ),
        const SizedBox(height: 20),
        _previewCard(
          transactionCount: previewTransactions.length,
          income: previewIncome,
          expense: previewExpense,
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: exporting ||
                previewTransactions.isEmpty ||
                !_isDateSelectionValid()
                ? null
                : () => _export(
              transactions: transactions,
              categories: categories,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: purple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: exporting
                ? const SizedBox(
              width: 19,
              height: 19,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : Icon(
              fileType == ExportFileType.csv
                  ? Icons.table_view_outlined
                  : Icons.picture_as_pdf_outlined,
            ),
            label: Text(
              exporting
                  ? 'Generating export...'
                  : 'Export and share',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        if (previewTransactions.isEmpty) ...[
          const SizedBox(height: 10),
          const Text(
            'No transactions found for the selected filters.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.redAccent,
            ),
          ),
        ],
      ],
    );
  }

  ExportOptions _currentOptions() {
    return ExportOptions(
      fileType: fileType,
      period: period,
      selectedMonth: selectedMonth,
      startDate: customRange?.start,
      endDate: customRange?.end,
      transactionType: transactionType,
      categoryId: categoryId,
    );
  }

  bool _isDateSelectionValid() {
    if (period != ExportPeriod.customRange) {
      return true;
    }

    return customRange != null;
  }

  Widget _monthSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: exporting
                ? null
                : () {
              setState(() {
                selectedMonth = DateTime(
                  selectedMonth.year,
                  selectedMonth.month - 1,
                );
              });
            },
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              DateFormat('MMMM yyyy').format(
                selectedMonth,
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: exporting
                ? null
                : () {
              setState(() {
                selectedMonth = DateTime(
                  selectedMonth.year,
                  selectedMonth.month + 1,
                );
              });
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _dateRangeSelector() {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: exporting ? null : _selectDateRange,
      child: InputDecorator(
        decoration: _inputDecoration(
          label: 'Date range',
          icon: Icons.calendar_today_outlined,
          suffix: const Icon(Icons.chevron_right),
        ),
        child: Text(
          customRange == null
              ? 'Select a date range'
              : '${DateFormat('d MMM yyyy').format(customRange!.start)}'
              ' - '
              '${DateFormat('d MMM yyyy').format(customRange!.end)}',
        ),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();

    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: customRange,
      helpText: 'Select export date range',
    );

    if (result == null || !mounted) return;

    setState(() {
      customRange = result;
    });
  }

  Widget _previewCard({
    required int transactionCount,
    required double income,
    required double expense,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Export preview',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _previewValue(
                  label: 'Transactions',
                  value: '$transactionCount',
                  color: purple,
                ),
              ),
              Expanded(
                child: _previewValue(
                  label: 'Income',
                  value:
                  AppUtils.formatCurrency(income),
                  color: Colors.green,
                ),
              ),
              Expanded(
                child: _previewValue(
                  label: 'Expense',
                  value:
                  AppUtils.formatCurrency(expense),
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewValue({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _export({
    required List<Transaction> transactions,
    required List<Category> categories,
  }) async {
    setState(() {
      exporting = true;
    });

    try {
      await exportService.exportAndShare(
        transactions: transactions,
        categories: categories,
        options: _currentOptions(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fileType == ExportFileType.csv
                ? 'CSV export created'
                : 'PDF export created',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to export data: $error',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          exporting = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: purple,
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: Theme.of(context).dividerColor,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: purple,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        vertical: 14,
      ),
    );
  }
}