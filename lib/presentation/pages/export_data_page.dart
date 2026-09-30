import 'dart:ui';

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
  bool savingToDevice = false;

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(allTransactionsProvider);

    final categoriesAsync = ref.watch(allCategoriesProvider);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        toolbarHeight: 58,
        titleSpacing: 16,
        backgroundColor: background.withValues(alpha: .82),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Export data',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _ExportAmbient()),
          transactionsAsync.when(
            loading: () =>
                Center(child: CircularProgressIndicator(color: purple)),
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
        ],
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
    final canExport = previewTransactions.isNotEmpty && _isDateSelectionValid();
    final scheme = Theme.of(context).colorScheme;

    final availableCategories = categories.where((category) {
      if (transactionType == null) {
        return true;
      }

      if (transactionType == TransactionType.expense) {
        return category.type == CategoryType.expense;
      }

      return category.type == CategoryType.income;
    }).toList();
    final now = DateTime.now();
    final periodDetail = switch (period) {
      ExportPeriod.currentMonth =>
        '${DateFormat('d MMM').format(DateTime(now.year, now.month, 1))} – '
            '${DateFormat('d MMM yyyy').format(now)}',
      ExportPeriod.selectedMonth => DateFormat(
        'MMM yyyy',
      ).format(selectedMonth),
      ExportPeriod.customRange when customRange != null =>
        '${DateFormat('d MMM').format(customRange!.start)} – '
            '${DateFormat('d MMM yyyy').format(customRange!.end)}',
      ExportPeriod.customRange => 'Choose start and end dates',
      ExportPeriod.all => 'Complete transaction history',
    };

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Text(
            'Export your transactions',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: textColor,
              fontSize: 25,
              letterSpacing: -.55,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Choose a format and filter the data you want to share.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: mutedColor, height: 1.4),
          ),
          const SizedBox(height: 18),
          _sectionHeading('Export format', trailing: _selectedFormatBadge()),
          const SizedBox(height: 9),
          _formatSelector(),
          const SizedBox(height: 18),
          _sectionHeading(
            'Filter records',
            trailing: TextButton(
              onPressed: exporting ? null : _resetFilters,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Reset filters'),
            ),
          ),
          const SizedBox(height: 8),
          _selectionField(
            label: 'Export period',
            value: _periodLabel(),
            detail: periodDetail,
            icon: Icons.date_range_outlined,
            iconColor: const Color(0xFF4F46E5),
            onTap: exporting ? null : _showPeriodPicker,
          ),
          if (period == ExportPeriod.selectedMonth) ...[
            const SizedBox(height: 10),
            _monthSelector(),
          ],
          if (period == ExportPeriod.customRange) ...[
            const SizedBox(height: 10),
            _dateRangeSelector(),
          ],
          const SizedBox(height: 10),
          _selectionField(
            label: 'Transaction type',
            value: _transactionTypeLabel(),
            detail: transactionType == null
                ? 'Income & Expense'
                : transactionType == TransactionType.income
                ? 'Income only'
                : 'Expense only',
            icon: Icons.swap_vert_rounded,
            iconColor: const Color(0xFF9333EA),
            onTap: exporting ? null : _showTransactionTypePicker,
          ),
          const SizedBox(height: 10),
          _selectionField(
            label: 'Category',
            value: _categoryLabel(categories),
            detail: categoryId == null
                ? '${availableCategories.length} selected'
                : '1 selected',
            icon: Icons.category_outlined,
            iconColor: const Color(0xFF7C3AED),
            onTap: exporting
                ? null
                : () {
                    _showCategoryPicker(availableCategories);
                  },
          ),
          const SizedBox(height: 16),
          _previewCard(
            transactionCount: previewTransactions.length,
            income: previewIncome,
            expense: previewExpense,
            transactions: previewTransactions,
            categories: categories,
            onView: () => _showFullPreview(
              transactions: previewTransactions,
              categories: categories,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: canExport
                      ? [purple, scheme.secondary]
                      : [
                          scheme.surfaceContainerHighest,
                          scheme.surfaceContainerHighest,
                        ],
                ),
                borderRadius: BorderRadius.circular(19),
                boxShadow: canExport
                    ? [
                        BoxShadow(
                          color: purple.withValues(alpha: .22),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: FilledButton.icon(
                onPressed: exporting || !canExport
                    ? null
                    : () {
                        _export(
                          transactions: transactions,
                          categories: categories,
                        );
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  foregroundColor: canExport
                      ? scheme.onPrimary
                      : scheme.onSurfaceVariant,
                  disabledForegroundColor: scheme.onSurfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(19),
                  ),
                  shadowColor: Colors.transparent,
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
                  savingToDevice
                      ? 'Saving file...'
                      : exporting
                      ? 'Generating export...'
                      : 'Export & Share File',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 56,
            child: OutlinedButton.icon(
              onPressed: exporting || !canExport
                  ? null
                  : () {
                      _saveToDevice(
                        transactions: transactions,
                        categories: categories,
                      );
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: textColor,
                backgroundColor: Theme.of(context).colorScheme.surface
                    .withValues(alpha: .72),
                side: BorderSide(color: borderColor.withValues(alpha: .45)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: savingToDevice
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined, size: 18),
              label: Text(
                savingToDevice ? 'Saving file...' : 'Save to Device / Files',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (previewTransactions.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'No transactions found for the selected filters.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _formatSelector() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _formatButton(
            type: ExportFileType.csv,
            label: 'CSV',
            subtitle: 'Spreadsheet data',
            description: 'Raw table for Excel or Sheets.',
            icon: Icons.table_chart_outlined,
            color: const Color(0xFF059669),
            paleColor: const Color(0xFFECFDF5),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _formatButton(
            type: ExportFileType.pdf,
            label: 'PDF',
            subtitle: 'Official statement',
            description: 'Formatted ledger report.',
            icon: Icons.picture_as_pdf_outlined,
            color: const Color(0xFFE11D48),
            paleColor: const Color(0xFFFFF1F2),
          ),
        ),
      ],
    );
  }

  Widget _formatButton({
    required ExportFileType type,
    required String label,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color color,
    required Color paleColor,
  }) {
    final selected = fileType == type;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: exporting
          ? null
          : () {
              setState(() {
                fileType = type;
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: dark
              ? theme.colorScheme.surface
              : Colors.white.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? color
                : dark
                ? theme.colorScheme.outlineVariant.withValues(alpha: .3)
                : const Color(0xFFE3E8F0),
            width: selected ? 1.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? color.withValues(alpha: .09)
                  : theme.colorScheme.primary.withValues(alpha: .035),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withValues(alpha: .11)
                        : paleColor.withValues(alpha: dark ? .16 : .9),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: color.withValues(alpha: .16)),
                  ),
                  child: Icon(icon, size: 21, color: color),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: selected ? color : Colors.transparent,
                    shape: BoxShape.circle,
                    border: selected
                        ? null
                        : Border.all(
                            color: theme.colorScheme.outlineVariant,
                            width: 2,
                          ),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 15,
                          color: theme.colorScheme.onPrimary,
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '.${label.toLowerCase()}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: mutedColor,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: .35),
            ),
            const SizedBox(height: 8),
            Text(
              type == ExportFileType.csv
                  ? 'Tabular export'
                  : 'Print-ready report',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: mutedColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeading(String title, {Widget? trailing}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: mutedColor,
              fontWeight: FontWeight.w700,
              letterSpacing: .8,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _selectedFormatBadge() {
    final color = fileType == ExportFileType.csv
        ? const Color(0xFF059669)
        : const Color(0xFFE11D48);
    final label = fileType == ExportFileType.csv
        ? 'CSV selected'
        : 'PDF selected';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      period = ExportPeriod.currentMonth;
      selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
      customRange = null;
      transactionType = null;
      categoryId = null;
    });
  }

  Widget _selectionField({
    required String label,
    required String value,
    required String detail,
    required IconData icon,
    required Color iconColor,
    required VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surface.withValues(alpha: .96)
                : Colors.white.withValues(alpha: .93),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: isDark
                  ? borderColor.withValues(alpha: .28)
                  : const Color(0xFFE4EAF2),
            ),
            boxShadow: [
              BoxShadow(
                color: purple.withValues(alpha: isDark ? .035 : .04),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: iconColor.withValues(alpha: .1)),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: mutedColor.withValues(alpha: .75),
                        fontWeight: FontWeight.w600,
                        letterSpacing: .7,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 7,
                      runSpacing: 3,
                      children: [
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: .5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: mutedColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.expand_more_rounded, color: mutedColor, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthSelector() {
    final theme = Theme.of(context);
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor.withValues(alpha: .28)),
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
            child: Text(
              DateFormat('MMMM yyyy').format(selectedMonth),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
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
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: exporting ? null : _selectDateRange,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: .94),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor.withValues(alpha: .28)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined, color: purple),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DATE RANGE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: mutedColor,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .6,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    customRange == null
                        ? 'Select a date range'
                        : '${DateFormat('d MMM yyyy').format(customRange!.start)}'
                              ' - '
                              '${DateFormat('d MMM yyyy').format(customRange!.end)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: customRange == null ? mutedColor : textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: mutedColor),
          ],
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
    required List<Transaction> transactions,
    required List<Category> categories,
    required VoidCallback onView,
  }) {
    final balance = income - expense;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final categoryNames = {
      for (final category in categories) category.id: category.name,
    };

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? scheme.surface.withValues(alpha: .96)
            : Colors.white.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? borderColor.withValues(alpha: .28)
              : Colors.white.withValues(alpha: .94),
        ),
        boxShadow: [
          BoxShadow(
            color: purple.withValues(alpha: .05),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: .018),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: purple.withValues(alpha: .1)),
                ),
                child: Icon(Icons.preview_outlined, color: purple, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Export Preview',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: purple.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: purple.withValues(alpha: .12),
                            ),
                          ),
                          child: Text(
                            '$transactionCount records',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: purple,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${fileType == ExportFileType.csv ? 'CSV' : 'PDF'} · ${period == ExportPeriod.all ? 'Full history' : _periodLabel()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: onView,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: purple,
                  backgroundColor: purple.withValues(alpha: .07),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: purple.withValues(alpha: .12)),
                  ),
                ),
                icon: const Icon(Icons.visibility_outlined, size: 15),
                label: const Text(
                  'View',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 7),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? scheme.surfaceContainerHighest.withValues(alpha: .24)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: theme.brightness == Brightness.dark
                    ? borderColor.withValues(alpha: .2)
                    : const Color(0xFFE7ECF3),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    children: [
                      SizedBox(width: 48, child: _previewTableHeader('DATE')),
                      Expanded(child: _previewTableHeader('TITLE · CATEGORY')),
                      SizedBox(
                        width: 100,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _previewTableHeader('AMOUNT', alignEnd: true),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 11,
                  color: scheme.outlineVariant.withValues(alpha: .35),
                ),
                if (transactions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      'No records match these filters.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: mutedColor,
                      ),
                    ),
                  )
                else
                  for (final transaction in transactions.take(3))
                    _previewTransactionRow(
                      transaction,
                      categoryNames[transaction.categoryId] ?? 'Other',
                    ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: .32),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _previewValue(
                  label: 'Income',
                  value: AppUtils.formatCurrency(income),
                  color: scheme.tertiary,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _previewValue(
                  label: 'Expense',
                  value: AppUtils.formatCurrency(expense),
                  color: scheme.error,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _previewValue(
                  label: 'Net total',
                  value: AppUtils.formatCurrency(balance),
                  color: balance >= 0 ? scheme.tertiary : scheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: .3),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 15, color: mutedColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Includes date, title, category and amount',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: mutedColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewTableHeader(String text, {bool alignEnd = false}) {
    return Text(
      text,
      textAlign: alignEnd ? TextAlign.end : TextAlign.start,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: mutedColor.withValues(alpha: .78),
        fontWeight: FontWeight.w700,
        letterSpacing: .35,
      ),
    );
  }

  Widget _previewTransactionRow(Transaction transaction, String category) {
    final theme = Theme.of(context);
    final isIncome = transaction.type == TransactionType.income;
    final amountColor = isIncome
        ? theme.colorScheme.tertiary
        : theme.colorScheme.error;
    final title = transaction.note?.trim().isNotEmpty == true
        ? transaction.note!.trim()
        : category;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              DateFormat('d MMM').format(transaction.date.toLocal()),
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(
                color: mutedColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: mutedColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 100,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '${isIncome ? '+' : '−'}${AppUtils.formatCurrency(transaction.amount)}',
                  maxLines: 1,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: .24,
                  )
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: .2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: mutedColor.withValues(alpha: .8),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
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

  Future<void> _showFullPreview({
    required List<Transaction> transactions,
    required List<Category> categories,
  }) async {
    final theme = Theme.of(context);
    final categoryNames = {
      for (final category in categories) category.id: category.name,
    };

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: theme.colorScheme.surface,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: .82,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Export preview',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${transactions.length} filtered transactions',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close preview',
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(color: borderColor.withValues(alpha: .45)),
                Expanded(
                  child: transactions.isEmpty
                      ? Center(
                          child: Text(
                            'No transactions match these filters.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: mutedColor,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: transactions.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            color: borderColor.withValues(alpha: .28),
                          ),
                          itemBuilder: (context, index) {
                            final transaction = transactions[index];
                            return _previewTransactionRow(
                              transaction,
                              categoryNames[transaction.categoryId] ?? 'Other',
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _export({
    required List<Transaction> transactions,
    required List<Category> categories,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      exporting = true;
      savingToDevice = false;
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
          backgroundColor: Theme.of(context).colorScheme.error,
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

  Future<void> _saveToDevice({
    required List<Transaction> transactions,
    required List<Category> categories,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      exporting = true;
      savingToDevice = true;
    });

    try {
      final saved = await exportService.saveToDevice(
        transactions: transactions,
        categories: categories,
        options: _currentOptions(),
      );

      if (!mounted || !saved) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${fileType == ExportFileType.csv ? 'CSV' : 'PDF'} saved to device',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save export: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          exporting = false;
          savingToDevice = false;
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

class _ExportAmbient extends StatelessWidget {
  const _ExportAmbient();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 30,
          left: -80,
          child: _orb(colors.primary.withValues(alpha: .16), 260),
        ),
        Positioned(
          top: 320,
          right: -110,
          child: _orb(colors.secondary.withValues(alpha: .11), 300),
        ),
        Positioned(
          bottom: 80,
          left: 15,
          child: _orb(colors.tertiary.withValues(alpha: .09), 250),
        ),
      ],
    );
  }

  Widget _orb(Color color, double size) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 54, sigmaY: 54),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
