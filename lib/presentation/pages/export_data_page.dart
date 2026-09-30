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
  ConsumerState<ExportDataPage> createState() => _ExportDataPageState();
}

class _ExportDataPageState extends ConsumerState<ExportDataPage> {
  Color get purple => Theme.of(context).colorScheme.primary;
  Color get background => Theme.of(context).scaffoldBackgroundColor;
  Color get textColor => Theme.of(context).colorScheme.onSurface;
  Color get mutedColor => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get borderColor => Theme.of(context).colorScheme.outlineVariant;

  final exportService = const ExportService();

  ExportFileType fileType = ExportFileType.csv;
  ExportPeriod period = ExportPeriod.currentMonth;

  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  DateTimeRange? customRange;
  TransactionType? transactionType;
  String? categoryId;

  bool exporting = false;

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(allTransactionsProvider);

    final categoriesAsync = ref.watch(allCategoriesProvider);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Export data',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
        ),
      ),
      body: transactionsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: purple)),
        error: (error, _) {
          return _errorView('Unable to load transactions\n$error');
        },
        data: (transactions) {
          return categoriesAsync.when(
            loading: () =>
                Center(child: CircularProgressIndicator(color: purple)),
            error: (error, _) {
              return _errorView('Unable to load categories\n$error');
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

    final previewTransactions = exportService.filterTransactions(
      transactions: transactions,
      options: options,
    );

    final previewIncome = previewTransactions
        .where((transaction) => transaction.type == TransactionType.income)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);

    final previewExpense = previewTransactions
        .where((transaction) => transaction.type == TransactionType.expense)
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);

    final availableCategories = categories.where((category) {
      if (transactionType == null) {
        return true;
      }

      if (transactionType == TransactionType.expense) {
        return category.type == CategoryType.expense;
      }

      return category.type == CategoryType.income;
    }).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Text(
            'Export your transactions',
            style: TextStyle(
              color: textColor,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a format and filter the data you want to share.',
            style: TextStyle(color: mutedColor, fontSize: 14),
          ),
          const SizedBox(height: 18),
          _formatSelector(),
          const SizedBox(height: 14),
          _selectionField(
            label: 'Export period',
            value: _periodLabel(),
            icon: Icons.date_range_outlined,
            onTap: exporting ? null : _showPeriodPicker,
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
          _selectionField(
            label: 'Transaction type',
            value: _transactionTypeLabel(),
            icon: Icons.swap_vert,
            onTap: exporting ? null : _showTransactionTypePicker,
          ),
          const SizedBox(height: 12),
          _selectionField(
            label: 'Category',
            value: _categoryLabel(categories),
            icon: Icons.category_outlined,
            onTap: exporting
                ? null
                : () {
                    _showCategoryPicker(availableCategories);
                  },
          ),
          const SizedBox(height: 18),
          _previewCard(
            transactionCount: previewTransactions.length,
            income: previewIncome,
            expense: previewExpense,
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed:
                  exporting ||
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
                disabledBackgroundColor: purple.withValues(alpha: .50),
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: exporting
                  ? SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : Icon(
                      fileType == ExportFileType.csv
                          ? Icons.table_view_outlined
                          : Icons.picture_as_pdf_outlined,
                    ),
              label: Text(
                exporting ? 'Generating export...' : 'Export and share',
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
              style: TextStyle(color: Colors.redAccent, fontSize: 13),
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
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
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: .10) : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 21, color: selected ? color : muted),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? color : muted,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? color.withValues(alpha: .75)
                          : muted.withValues(alpha: .72),
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

  Widget _selectionField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: purple, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(color: mutedColor, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.keyboard_arrow_down_rounded, color: mutedColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: borderColor),
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
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Selected month',
                  style: TextStyle(color: mutedColor, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMMM yyyy').format(selectedMonth),
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
        decoration: InputDecoration(
          labelText: 'Date range',
          prefixIcon: Icon(Icons.calendar_today_outlined, color: purple),
          suffixIcon: const Icon(Icons.chevron_right),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: borderColor),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(
          customRange == null
              ? 'Select a date range'
              : '${DateFormat('d MMM yyyy').format(customRange!.start)}'
                    ' - '
                    '${DateFormat('d MMM yyyy').format(customRange!.end)}',
          style: TextStyle(
            color: customRange == null ? mutedColor : textColor,
            fontWeight: customRange == null
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
            colorScheme: Theme.of(context).colorScheme
                .copyWith(primary: purple),
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

  Future<void> _showPeriodPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Export period',
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose which transactions to export.',
                style: TextStyle(color: mutedColor, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _bottomSheetOption(
                title: 'Current month',
                subtitle: DateFormat('MMMM yyyy').format(DateTime.now()),
                icon: Icons.today_outlined,
                selected: period == ExportPeriod.currentMonth,
                onTap: () {
                  _closeSheetAndUpdate(sheetContext, () {
                    period = ExportPeriod.currentMonth;
                  });
                },
              ),
              _bottomSheetOption(
                title: 'Selected month',
                subtitle: 'Choose a specific month',
                icon: Icons.calendar_month_outlined,
                selected: period == ExportPeriod.selectedMonth,
                onTap: () {
                  _closeSheetAndUpdate(sheetContext, () {
                    period = ExportPeriod.selectedMonth;
                  });
                },
              ),
              _bottomSheetOption(
                title: 'Custom date range',
                subtitle: 'Select a start and end date',
                icon: Icons.date_range_outlined,
                selected: period == ExportPeriod.customRange,
                onTap: () {
                  _closeSheetAndUpdate(sheetContext, () {
                    period = ExportPeriod.customRange;
                  });
                },
              ),
              _bottomSheetOption(
                title: 'All transactions',
                subtitle: 'Export your complete history',
                icon: Icons.history_outlined,
                selected: period == ExportPeriod.all,
                onTap: () {
                  _closeSheetAndUpdate(sheetContext, () {
                    period = ExportPeriod.all;
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showTransactionTypePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transaction type',
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose the transaction type to export.',
                style: TextStyle(color: mutedColor, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _bottomSheetOption(
                title: 'All transactions',
                subtitle: 'Include income and expenses',
                icon: Icons.swap_vert,
                selected: transactionType == null,
                onTap: () {
                  _closeSheetAndUpdate(sheetContext, () {
                    transactionType = null;
                    categoryId = null;
                  });
                },
              ),
              _bottomSheetOption(
                title: 'Expenses only',
                subtitle: 'Export expense transactions',
                icon: Icons.north_east,
                iconColor: const Color(0xFFE85E6F),
                selected: transactionType == TransactionType.expense,
                onTap: () {
                  _closeSheetAndUpdate(sheetContext, () {
                    transactionType = TransactionType.expense;
                    categoryId = null;
                  });
                },
              ),
              _bottomSheetOption(
                title: 'Income only',
                subtitle: 'Export income transactions',
                icon: Icons.south_west,
                iconColor: const Color(0xFF00A578),
                selected: transactionType == TransactionType.income,
                onTap: () {
                  _closeSheetAndUpdate(sheetContext, () {
                    transactionType = TransactionType.income;
                    categoryId = null;
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCategoryPicker(List<Category> categories) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .72,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Category',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Choose a category to export.',
                      style: TextStyle(color: mutedColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    _bottomSheetOption(
                      title: 'All categories',
                      subtitle: 'Include every category',
                      icon: Icons.category_outlined,
                      selected: categoryId == null,
                      onTap: () {
                        _closeSheetAndUpdate(sheetContext, () {
                          categoryId = null;
                        });
                      },
                    ),
                    ...categories.map((category) {
                      final isIncome = category.type == CategoryType.income;

                      return _bottomSheetOption(
                        title: category.name,
                        subtitle: isIncome
                            ? 'Income category'
                            : 'Expense category',
                        icon: isIncome
                            ? Icons.trending_up
                            : Icons.category_outlined,
                        iconColor: isIncome
                            ? const Color(0xFF00A578)
                            : const Color(0xFFE85E6F),
                        selected: categoryId == category.id,
                        onTap: () {
                          _closeSheetAndUpdate(sheetContext, () {
                            categoryId = category.id;
                          });
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bottomSheetOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final color = iconColor ?? purple;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? color.withValues(alpha: .08) : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: selected ? color : textColor,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(color: mutedColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 17,
                    ),
                  )
                else
                  Icon(Icons.chevron_right, color: mutedColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _closeSheetAndUpdate(BuildContext sheetContext, VoidCallback update) {
    Navigator.of(sheetContext).pop();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(update);
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
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.preview_outlined, color: purple, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      style: TextStyle(color: mutedColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$transactionCount records',
                  style: TextStyle(
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
                  value: AppUtils.formatCurrency(income),
                  color: const Color(0xFF00A578),
                ),
              ),
              Container(width: 1, height: 38, color: borderColor),
              const SizedBox(width: 10),
              Expanded(
                child: _previewValue(
                  label: 'Expense',
                  value: AppUtils.formatCurrency(expense),
                  color: const Color(0xFFE85E6F),
                ),
              ),
              Container(width: 1, height: 38, color: borderColor),
              const SizedBox(width: 10),
              Expanded(
                child: _previewValue(
                  label: 'Balance',
                  value: AppUtils.formatCurrency(balance),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: mutedColor, fontSize: 11)),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
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
    if (period != ExportPeriod.customRange) {
      return true;
    }

    return customRange != null;
  }

  String _periodLabel() {
    switch (period) {
      case ExportPeriod.currentMonth:
        return 'Current month';

      case ExportPeriod.selectedMonth:
        return DateFormat('MMMM yyyy').format(selectedMonth);

      case ExportPeriod.customRange:
        if (customRange == null) {
          return 'Select a custom date range';
        }

        return '${DateFormat('d MMM yyyy').format(customRange!.start)}'
            ' - '
            '${DateFormat('d MMM yyyy').format(customRange!.end)}';

      case ExportPeriod.all:
        return 'All transactions';
    }
  }

  String _transactionTypeLabel() {
    switch (transactionType) {
      case TransactionType.expense:
        return 'Expenses only';

      case TransactionType.income:
        return 'Income only';

      case null:
        return 'All transactions';
    }
  }

  String _categoryLabel(List<Category> categories) {
    if (categoryId == null) {
      return 'All categories';
    }

    final matches = categories.where((category) => category.id == categoryId);

    if (matches.isEmpty) {
      return 'All categories';
    }

    return matches.first.name;
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
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to export data: $error'),
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

  Widget _errorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 50, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              'Unable to load export data',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: mutedColor),
            ),
          ],
        ),
      ),
    );
  }
}
