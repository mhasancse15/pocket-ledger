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
  static const background = Color(0xFFF7F7FB);
  static const textColor = Color(0xFF23232B);
  static const mutedColor = Color(0xFF70707B);
  static const borderColor = Color(0xFFE4E4EA);

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
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Export data',
          style: TextStyle(
            color: textColor,
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
          return _errorView(
            'Unable to load transactions\n$error',
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
              return _errorView(
                'Unable to load categories\n$error',
              );
            },
            data: (categories) {
              return _buildContent(
                transactions: transactions,
                categories: categories,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContent({
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
      transaction.type ==
          TransactionType.income,
    )
        .fold<double>(
      0,
          (sum, transaction) =>
      sum + transaction.amount,
    );

    final previewExpense = previewTransactions
        .where(
          (transaction) =>
      transaction.type ==
          TransactionType.expense,
    )
        .fold<double>(
      0,
          (sum, transaction) =>
      sum + transaction.amount,
    );

    final availableCategories = categories.where(
          (category) {
        if (transactionType == null) {
          return true;
        }

        if (transactionType ==
            TransactionType.expense) {
          return category.type ==
              CategoryType.expense;
        }

        return category.type ==
            CategoryType.income;
      },
    ).toList();

    final validCategoryId =
    availableCategories.any(
          (category) =>
      category.id == categoryId,
    )
        ? categoryId
        : null;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          8,
          16,
          28,
        ),
        children: [
          const Text(
            'Export your transactions',
            style: TextStyle(
              color: textColor,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose a format and filter the data you want to share.',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          _formatSelector(),
          const SizedBox(height: 14),
          DropdownButtonFormField<ExportPeriod>(
            value: period,
            isExpanded: true,
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
          if (period ==
              ExportPeriod.selectedMonth) ...[
            const SizedBox(height: 12),
            _monthSelector(),
          ],
          if (period ==
              ExportPeriod.customRange) ...[
            const SizedBox(height: 12),
            _dateRangeSelector(),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<TransactionType?>(
            value: transactionType,
            isExpanded: true,
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
            value: validCategoryId,
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
                      child: Text(
                        category.name,
                        overflow: TextOverflow.ellipsis,
                      ),
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
          const SizedBox(height: 18),
          _previewCard(
            transactionCount:
            previewTransactions.length,
            income: previewIncome,
            expense: previewExpense,
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: exporting ||
                  previewTransactions.isEmpty ||
                  !_isDateSelectionValid()
                  ? null
                  : () {
                _export(
                  transactions: transactions,
                  categories: categories,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: purple,
                disabledBackgroundColor:
                purple.withOpacity(.50),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(16),
                ),
              ),
              icon: exporting
                  ? const SizedBox(
                width: 19,
                height: 19,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : Icon(
                fileType ==
                    ExportFileType.csv
                    ? Icons.table_view_outlined
                    : Icons
                    .picture_as_pdf_outlined,
              ),
              label: Text(
                exporting
                    ? 'Generating export...'
                    : 'Export and share',
                style: const TextStyle(
                  fontSize: 15,
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
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _formatSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _formatButton(
              type: ExportFileType.csv,
              label: 'CSV',
              subtitle: 'Spreadsheet',
              icon: Icons.table_view_outlined,
              color: const Color(0xFF00A578),
            ),
          ),
          Expanded(
            child: _formatButton(
              type: ExportFileType.pdf,
              label: 'PDF',
              subtitle: 'Statement',
              icon: Icons.picture_as_pdf_outlined,
              color: const Color(0xFFE85E6F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formatButton({
    required ExportFileType type,
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final selected = fileType == type;

    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: exporting
          ? null
          : () {
        setState(() {
          fileType = type;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 180,
        ),
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 21,
              color: selected
                  ? color
                  : Colors.black45,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? color
                          : Colors.black54,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow:
                    TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? color.withOpacity(.75)
                          : Colors.black38,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthSelector() {
    return Ink(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
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
            icon: const Icon(
              Icons.chevron_left,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Selected month',
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMMM yyyy').format(
                    selectedMonth,
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Next month',
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
            icon: const Icon(
              Icons.chevron_right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateRangeSelector() {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: exporting
          ? null
          : _selectDateRange,
      child: InputDecorator(
        decoration: _inputDecoration(
          label: 'Date range',
          icon: Icons.calendar_today_outlined,
          suffix: const Icon(
            Icons.chevron_right,
          ),
        ),
        child: Text(
          customRange == null
              ? 'Select a date range'
              : '${DateFormat('d MMM yyyy').format(customRange!.start)}'
              ' - '
              '${DateFormat('d MMM yyyy').format(customRange!.end)}',
          style: TextStyle(
            color: customRange == null
                ? Colors.black54
                : textColor,
            fontWeight:
            customRange == null
                ? FontWeight.normal
                : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: customRange,
      helpText: 'Select export date range',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme:
            Theme.of(context)
                .colorScheme
                .copyWith(
              primary: purple,
            ),
          ),
          child: child!,
        );
      },
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
    final balance = income - expense;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: purple.withOpacity(.10),
                  borderRadius:
                  BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.preview_outlined,
                  color: purple,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Export preview',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Summary of selected records',
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: purple.withOpacity(.10),
                  borderRadius:
                  BorderRadius.circular(20),
                ),
                child: Text(
                  '$transactionCount records',
                  style: const TextStyle(
                    color: purple,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _previewValue(
                  label: 'Income',
                  value:
                  AppUtils.formatCurrency(income),
                  color: const Color(0xFF00A578),
                ),
              ),
              Container(
                width: 1,
                height: 38,
                color: borderColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _previewValue(
                  label: 'Expense',
                  value:
                  AppUtils.formatCurrency(expense),
                  color: const Color(0xFFE85E6F),
                ),
              ),
              Container(
                width: 1,
                height: 38,
                color: borderColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _previewValue(
                  label: 'Balance',
                  value:
                  AppUtils.formatCurrency(balance),
                  color: balance >= 0
                      ? const Color(0xFF3182CE)
                      : Colors.redAccent,
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
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: mutedColor,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
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
    if (period !=
        ExportPeriod.customRange) {
      return true;
    }

    return customRange != null;
  }

  Future<void> _export({
    required List<Transaction> transactions,
    required List<Category> categories,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();

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
          behavior:
          SnackBarBehavior.floating,
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
          behavior:
          SnackBarBehavior.floating,
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
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: borderColor,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: borderColor,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: purple,
          width: 1.5,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: borderColor,
        ),
      ),
      contentPadding:
      const EdgeInsets.symmetric(
        vertical: 14,
      ),
    );
  }

  Widget _errorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 50,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load export data',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: mutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}