import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/category.dart';
import '../../domain/entities/transaction.dart';

enum ExportFileType {
  csv,
  pdf,
}

enum ExportPeriod {
  currentMonth,
  selectedMonth,
  customRange,
  all,
}

class ExportOptions {
  const ExportOptions({
    required this.fileType,
    required this.period,
    this.selectedMonth,
    this.startDate,
    this.endDate,
    this.transactionType,
    this.categoryId,
  });

  final ExportFileType fileType;
  final ExportPeriod period;

  final DateTime? selectedMonth;
  final DateTime? startDate;
  final DateTime? endDate;

  final TransactionType? transactionType;
  final String? categoryId;
}

class ExportService {
  const ExportService();

  List<Transaction> filterTransactions({
    required List<Transaction> transactions,
    required ExportOptions options,
  }) {
    final now = DateTime.now();

    final filtered = transactions.where((transaction) {
      final transactionDate = transaction.date.toLocal();

      final dateOnly = DateTime(
        transactionDate.year,
        transactionDate.month,
        transactionDate.day,
      );

      bool matchesPeriod;

      switch (options.period) {
        case ExportPeriod.currentMonth:
          matchesPeriod =
              transactionDate.year == now.year &&
                  transactionDate.month == now.month;
          break;

        case ExportPeriod.selectedMonth:
          final month = options.selectedMonth;

          matchesPeriod = month != null &&
              transactionDate.year == month.year &&
              transactionDate.month == month.month;
          break;

        case ExportPeriod.customRange:
          final startDate = options.startDate;
          final endDate = options.endDate;

          if (startDate == null || endDate == null) {
            matchesPeriod = false;
          } else {
            final normalizedStart = DateTime(
              startDate.year,
              startDate.month,
              startDate.day,
            );

            final normalizedEnd = DateTime(
              endDate.year,
              endDate.month,
              endDate.day,
            );

            matchesPeriod =
                !dateOnly.isBefore(normalizedStart) &&
                    !dateOnly.isAfter(normalizedEnd);
          }
          break;

        case ExportPeriod.all:
          matchesPeriod = true;
          break;
      }

      final matchesType =
          options.transactionType == null ||
              transaction.type == options.transactionType;

      final matchesCategory =
          options.categoryId == null ||
              transaction.categoryId == options.categoryId;

      return matchesPeriod &&
          matchesType &&
          matchesCategory;
    }).toList();

    filtered.sort(
          (a, b) => b.date.compareTo(a.date),
    );

    return filtered;
  }

  Future<File> exportAndShare({
    required List<Transaction> transactions,
    required List<Category> categories,
    required ExportOptions options,
  }) async {
    final file = await generateExport(
      transactions: transactions,
      categories: categories,
      options: options,
    );

    final mimeType = options.fileType == ExportFileType.csv
        ? 'text/csv'
        : 'application/pdf';

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType: mimeType,
          ),
        ],
        subject: 'Pocket Ledger export',
        text:
        'Pocket Ledger transaction export — '
            '${_periodLabel(options)}',
      ),
    );

    return file;
  }

  Future<bool> saveToDevice({
    required List<Transaction> transactions,
    required List<Category> categories,
    required ExportOptions options,
  }) async {
    final file = await generateExport(
      transactions: transactions,
      categories: categories,
      options: options,
    );
    final extension = options.fileType == ExportFileType.csv
        ? 'csv'
        : 'pdf';
    final savePath = await FilePicker.platform.saveFile(
      fileName:
          'pocket_ledger_${_filePeriodName(options)}.$extension',
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: Platform.isAndroid || Platform.isIOS
          ? await file.readAsBytes()
          : null,
    );

    if (savePath == null) {
      return false;
    }

    if (!Platform.isAndroid && !Platform.isIOS) {
      await File(savePath).writeAsBytes(
        await file.readAsBytes(),
        flush: true,
      );
    }

    return true;
  }

  Future<File> generateExport({
    required List<Transaction> transactions,
    required List<Category> categories,
    required ExportOptions options,
  }) async {
    final filtered = filterTransactions(
      transactions: transactions,
      options: options,
    );

    if (filtered.isEmpty) {
      throw Exception(
        'No transactions found for the selected filters.',
      );
    }

    final categoryNames = <String, String>{
      for (final category in categories)
        category.id: category.name,
    };

    late final File file;

    switch (options.fileType) {
      case ExportFileType.csv:
        file = await _generateCsv(
          transactions: filtered,
          categoryNames: categoryNames,
          options: options,
        );
        break;

      case ExportFileType.pdf:
        file = await _generatePdf(
          transactions: filtered,
          categoryNames: categoryNames,
          options: options,
        );
        break;
    }

    return file;
  }

  Future<File> _generateCsv({
    required List<Transaction> transactions,
    required Map<String, String> categoryNames,
    required ExportOptions options,
  }) async {
    final dateFormatter = DateFormat(
      'yyyy-MM-dd HH:mm',
    );

    final rows = <List<dynamic>>[
      [
        'Transaction ID',
        'Type',
        'Amount',
        'Currency',
        'Category',
        'Date',
        'Payment Method',
        'Title or Note',
        'Created At',
        'Updated At',
      ],
    ];

    for (final transaction in transactions) {
      rows.add([
        _safeCsvValue(transaction.id),
        _transactionTypeLabel(transaction.type),
        transaction.amount.toStringAsFixed(2),
        'BDT',
        _safeCsvValue(
          categoryNames[transaction.categoryId] ??
              transaction.categoryId,
        ),
        dateFormatter.format(
          transaction.date.toLocal(),
        ),
        _safeCsvValue(
          _formatLabel(
            transaction.paymentMethod.name,
          ),
        ),
        _safeCsvValue(transaction.note ?? ''),
        dateFormatter.format(
          transaction.createdAt.toLocal(),
        ),
        dateFormatter.format(
          transaction.updatedAt.toLocal(),
        ),
      ]);
    }

    final csvText = const CsvEncoder().convert(rows);

    final bytes = utf8.encode(
      '\uFEFF$csvText',
    );

    final fileName =
        'pocket_ledger_${_filePeriodName(options)}.csv';

    return _writeTemporaryFile(
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
    );
  }

  Future<File> _generatePdf({
    required List<Transaction> transactions,
    required Map<String, String> categoryNames,
    required ExportOptions options,
  }) async {
    final regularFontData = await rootBundle.load(
      'assets/fonts/NotoSansBengali-Regular.ttf',
    );

    final boldFontData = await rootBundle.load(
      'assets/fonts/NotoSansBengali-Bold.ttf',
    );

    final regularFont = pw.Font.ttf(regularFontData);
    final boldFont = pw.Font.ttf(boldFontData);

    final pdfTheme = pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
    );

    final document = pw.Document(
      theme: pdfTheme,
    );

    final totalIncome = transactions
        .where(
          (transaction) =>
      transaction.type == TransactionType.income,
    )
        .fold<double>(
      0,
          (sum, transaction) =>
      sum + transaction.amount,
    );

    final totalExpense = transactions
        .where(
          (transaction) =>
      transaction.type == TransactionType.expense,
    )
        .fold<double>(
      0,
          (sum, transaction) =>
      sum + transaction.amount,
    );

    final balance = totalIncome - totalExpense;
    final generatedAt = DateTime.now();

    final reportNumber =
        'PL-${DateFormat('yyyyMMdd-HHmm').format(generatedAt)}';

    final categoryFilterName =
    options.categoryId == null
        ? 'All categories'
        : categoryNames[options.categoryId] ??
        options.categoryId!;

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.fromLTRB(
            30,
            24,
            30,
            28,
          ),
          theme: pdfTheme,
        ),
        header: (context) {
          return _buildPdfHeader(
            reportNumber: reportNumber,
          );
        },
        footer: (context) {
          return _buildPdfFooter(
            context: context,
            generatedAt: generatedAt,
          );
        },
        build: (context) {
          return [
            pw.SizedBox(height: 6),
            _buildReportInformation(
              options: options,
              categoryName: categoryFilterName,
              transactionCount: transactions.length,
            ),
            pw.SizedBox(height: 18),
            _buildSummaryCards(
              income: totalIncome,
              expense: totalExpense,
              balance: balance,
              transactionCount: transactions.length,
            ),
            pw.SizedBox(height: 22),
            _buildTransactionSectionHeader(
              transactionCount: transactions.length,
            ),
            pw.SizedBox(height: 10),
            _buildTransactionTable(
              transactions: transactions,
              categoryNames: categoryNames,
            ),
            pw.SizedBox(height: 18),
            _buildFinalTotals(
              income: totalIncome,
              expense: totalExpense,
              balance: balance,
            ),
            pw.SizedBox(height: 18),
            _buildReportNote(),
          ];
        },
      ),
    );

    final bytes = await document.save();

    final fileName =
        'pocket_ledger_${_filePeriodName(options)}.pdf';

    return _writeTemporaryFile(
      fileName: fileName,
      bytes: bytes,
    );
  }

  pw.Widget _buildPdfHeader({
    required String reportNumber,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(
        bottom: 12,
      ),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            color: PdfColors.grey300,
            width: .7,
          ),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment:
        pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 42,
                height: 42,
                alignment: pw.Alignment.center,
                decoration: pw.BoxDecoration(
                  color: PdfColors.deepPurple700,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Text(
                  'PL',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 11),
              pw.Column(
                crossAxisAlignment:
                pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Pocket Ledger',
                    style: pw.TextStyle(
                      color: PdfColors.deepPurple700,
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Personal Finance Management',
                    style: const pw.TextStyle(
                      color: PdfColors.grey600,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment:
            pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'FINANCIAL STATEMENT',
                style: pw.TextStyle(
                  color: PdfColors.grey900,
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Report No: $reportNumber',
                style: const pw.TextStyle(
                  color: PdfColors.grey600,
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfFooter({
    required pw.Context context,
    required DateTime generatedAt,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
            color: PdfColors.grey300,
            width: .5,
          ),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment:
        pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated: '
                '${DateFormat('d MMM yyyy, h:mm a').format(generatedAt)}',
            style: const pw.TextStyle(
              color: PdfColors.grey600,
              fontSize: 8,
            ),
          ),
          pw.Text(
            'Pocket Ledger • Page '
                '${context.pageNumber} of '
                '${context.pagesCount}',
            style: const pw.TextStyle(
              color: PdfColors.grey600,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildReportInformation({
    required ExportOptions options,
    required String categoryName,
    required int transactionCount,
  }) {
    final typeLabel =
    options.transactionType == null
        ? 'All transactions'
        : options.transactionType ==
        TransactionType.income
        ? 'Income only'
        : 'Expenses only';

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(
          color: PdfColors.grey300,
          width: .5,
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: _reportInfoItem(
              label: 'REPORT PERIOD',
              value: _periodLabel(options),
            ),
          ),
          _verticalDivider(),
          pw.Expanded(
            child: _reportInfoItem(
              label: 'TRANSACTION TYPE',
              value: typeLabel,
            ),
          ),
          _verticalDivider(),
          pw.Expanded(
            child: _reportInfoItem(
              label: 'CATEGORY',
              value: categoryName,
            ),
          ),
          _verticalDivider(),
          pw.Expanded(
            child: _reportInfoItem(
              label: 'TOTAL RECORDS',
              value: '$transactionCount',
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _reportInfoItem({
    required String label,
    required String value,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 10,
      ),
      child: pw.Column(
        crossAxisAlignment:
        pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              color: PdfColors.grey600,
              fontSize: 7,
              letterSpacing: .5,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            maxLines: 2,
            style: pw.TextStyle(
              color: PdfColors.grey900,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _verticalDivider() {
    return pw.Container(
      width: .6,
      height: 30,
      color: PdfColors.grey300,
    );
  }

  pw.Widget _buildSummaryCards({
    required double income,
    required double expense,
    required double balance,
    required int transactionCount,
  }) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: _summaryCard(
            label: 'TOTAL INCOME',
            value: '+${_currency(income)}',
            color: PdfColors.green700,
            backgroundColor: PdfColors.green50,
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: _summaryCard(
            label: 'TOTAL EXPENSE',
            value: '-${_currency(expense)}',
            color: PdfColors.red700,
            backgroundColor: PdfColors.red50,
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: _summaryCard(
            label: 'NET BALANCE',
            value:
            '${balance >= 0 ? '+' : '-'}'
                '${_currency(balance.abs())}',
            color: balance >= 0
                ? PdfColors.blue700
                : PdfColors.red700,
            backgroundColor: balance >= 0
                ? PdfColors.blue50
                : PdfColors.red50,
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: _summaryCard(
            label: 'TRANSACTIONS',
            value: '$transactionCount',
            color: PdfColors.deepPurple700,
            backgroundColor:
            PdfColors.deepPurple50,
          ),
        ),
      ],
    );
  }

  pw.Widget _summaryCard({
    required String label,
    required String value,
    required PdfColor color,
    required PdfColor backgroundColor,
  }) {
    return pw.Container(
      height: 66,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: backgroundColor,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(
          color: PdfColors.grey300,
          width: .5,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment:
        pw.CrossAxisAlignment.start,
        mainAxisAlignment:
        pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              color: PdfColors.grey600,
              fontSize: 7,
              letterSpacing: .4,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            child: pw.Text(
              value,
              style: pw.TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTransactionSectionHeader({
    required int transactionCount,
  }) {
    return pw.Row(
      mainAxisAlignment:
      pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment:
          pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Transaction Details',
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'Detailed income and expense records',
              style: const pw.TextStyle(
                color: PdfColors.grey600,
                fontSize: 9,
              ),
            ),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          decoration: pw.BoxDecoration(
            color: PdfColors.deepPurple50,
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Text(
            '$transactionCount transactions',
            style: pw.TextStyle(
              color: PdfColors.deepPurple700,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildTransactionTable({
    required List<Transaction> transactions,
    required Map<String, String> categoryNames,
  }) {
    final dateFormatter = DateFormat(
      'd MMM yyyy',
    );

    return pw.Table(
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(
          color: PdfColors.grey300,
          width: .5,
        ),
        top: pw.BorderSide(
          color: PdfColors.grey300,
          width: .5,
        ),
        bottom: pw.BorderSide(
          color: PdfColors.grey300,
          width: .5,
        ),
        left: pw.BorderSide(
          color: PdfColors.grey300,
          width: .5,
        ),
        right: pw.BorderSide(
          color: PdfColors.grey300,
          width: .5,
        ),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.1),
        1: pw.FlexColumnWidth(.9),
        2: pw.FlexColumnWidth(1.3),
        3: pw.FlexColumnWidth(1.3),
        4: pw.FlexColumnWidth(2.2),
        5: pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColors.deepPurple700,
          ),
          children: [
            _tableHeaderCell('DATE'),
            _tableHeaderCell('TYPE'),
            _tableHeaderCell('CATEGORY'),
            _tableHeaderCell('PAYMENT'),
            _tableHeaderCell('DESCRIPTION'),
            _tableHeaderCell(
              'AMOUNT',
              alignRight: true,
            ),
          ],
        ),
        ...transactions.asMap().entries.map(
              (entry) {
            final index = entry.key;
            final transaction = entry.value;

            final isIncome =
                transaction.type ==
                    TransactionType.income;

            final categoryName =
                categoryNames[
                transaction.categoryId] ??
                    transaction.categoryId;

            return pw.TableRow(
              decoration: pw.BoxDecoration(
                color: index.isEven
                    ? PdfColors.white
                    : PdfColors.grey50,
              ),
              children: [
                _tableCell(
                  dateFormatter.format(
                    transaction.date.toLocal(),
                  ),
                ),
                _tableCell(
                  isIncome ? 'Income' : 'Expense',
                  color: isIncome
                      ? PdfColors.green700
                      : PdfColors.red700,
                  bold: true,
                ),
                _tableCell(categoryName),
                _tableCell(
                  _formatLabel(
                    transaction.paymentMethod.name,
                  ),
                ),
                _tableCell(
                  transaction.note
                      ?.trim()
                      .isNotEmpty ==
                      true
                      ? transaction.note!.trim()
                      : '-',
                ),
                _tableCell(
                  '${isIncome ? '+' : '-'}'
                      '${_currency(transaction.amount)}',
                  color: isIncome
                      ? PdfColors.green700
                      : PdfColors.red700,
                  bold: true,
                  alignRight: true,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  pw.Widget _tableHeaderCell(
      String value, {
        bool alignRight = false,
      }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 9,
      ),
      alignment: alignRight
          ? pw.Alignment.centerRight
          : pw.Alignment.centerLeft,
      child: pw.Text(
        value,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: .3,
        ),
      ),
    );
  }

  pw.Widget _tableCell(
      String value, {
        PdfColor? color,
        bool bold = false,
        bool alignRight = false,
      }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 8,
      ),
      alignment: alignRight
          ? pw.Alignment.centerRight
          : pw.Alignment.centerLeft,
      child: pw.Text(
        value,
        maxLines: 2,
        textAlign: alignRight
            ? pw.TextAlign.right
            : pw.TextAlign.left,
        style: pw.TextStyle(
          color: color ?? PdfColors.grey900,
          fontSize: 8,
          fontWeight: bold
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _buildFinalTotals({
    required double income,
    required double expense,
    required double balance,
  }) {
    return pw.Row(
      mainAxisAlignment:
      pw.MainAxisAlignment.end,
      children: [
        pw.Container(
          width: 265,
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(
              color: PdfColors.grey300,
            ),
          ),
          child: pw.Column(
            children: [
              _totalRow(
                label: 'Total income',
                value: _currency(income),
                color: PdfColors.green700,
              ),
              pw.SizedBox(height: 7),
              _totalRow(
                label: 'Total expense',
                value: _currency(expense),
                color: PdfColors.red700,
              ),
              pw.Divider(
                height: 18,
                color: PdfColors.grey400,
              ),
              _totalRow(
                label: 'Net balance',
                value:
                '${balance < 0 ? '-' : ''}'
                    '${_currency(balance.abs())}',
                color: balance >= 0
                    ? PdfColors.blue700
                    : PdfColors.red700,
                bold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _totalRow({
    required String label,
    required String value,
    required PdfColor color,
    bool bold = false,
  }) {
    return pw.Row(
      mainAxisAlignment:
      pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            color: PdfColors.grey700,
            fontSize: 9,
            fontWeight: bold
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: color,
            fontSize: bold ? 12 : 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildReportNote() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        'This financial statement was automatically generated '
            'from the transaction data stored in Pocket Ledger.',
        style: const pw.TextStyle(
          color: PdfColors.blueGrey700,
          fontSize: 8,
        ),
      ),
    );
  }

  Future<File> _writeTemporaryFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final directory =
    await getTemporaryDirectory();

    final file = File(
      '${directory.path}/$fileName',
    );

    await file.writeAsBytes(
      bytes,
      flush: true,
    );

    return file;
  }

  String _safeCsvValue(String value) {
    final trimmed = value.trimLeft();

    if (trimmed.startsWith('=') ||
        trimmed.startsWith('+') ||
        trimmed.startsWith('-') ||
        trimmed.startsWith('@')) {
      return "'$value";
    }

    return value;
  }

  String _transactionTypeLabel(
      TransactionType type,
      ) {
    switch (type) {
      case TransactionType.income:
        return 'Income';

      case TransactionType.expense:
        return 'Expense';
    }
  }

  String _periodLabel(
      ExportOptions options,
      ) {
    switch (options.period) {
      case ExportPeriod.currentMonth:
        return DateFormat('MMMM yyyy').format(
          DateTime.now(),
        );

      case ExportPeriod.selectedMonth:
        return DateFormat('MMMM yyyy').format(
          options.selectedMonth ??
              DateTime.now(),
        );

      case ExportPeriod.customRange:
        final start = options.startDate;
        final end = options.endDate;

        if (start == null || end == null) {
          return 'Custom period';
        }

        return '${DateFormat('d MMM yyyy').format(start)}'
            ' - '
            '${DateFormat('d MMM yyyy').format(end)}';

      case ExportPeriod.all:
        return 'All transactions';
    }
  }

  String _filePeriodName(
      ExportOptions options,
      ) {
    switch (options.period) {
      case ExportPeriod.currentMonth:
        return DateFormat('yyyy-MM').format(
          DateTime.now(),
        );

      case ExportPeriod.selectedMonth:
        return DateFormat('yyyy-MM').format(
          options.selectedMonth ??
              DateTime.now(),
        );

      case ExportPeriod.customRange:
        final start = options.startDate;
        final end = options.endDate;

        if (start == null || end == null) {
          return 'custom';
        }

        return '${DateFormat('yyyy-MM-dd').format(start)}'
            '_to_'
            '${DateFormat('yyyy-MM-dd').format(end)}';

      case ExportPeriod.all:
        return 'all_transactions';
    }
  }

  String _currency(double amount) {
    final formatter = NumberFormat(
      '#,##0.00',
      'en_US',
    );

    return '৳${formatter.format(amount)}';
  }

  String _formatLabel(String value) {
    return value
        .replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
          (match) {
        return '${match.group(1)} '
            '${match.group(2)}';
      },
    )
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
          ? word
          : '${word[0].toUpperCase()}'
          '${word.substring(1)}',
    )
        .join(' ');
  }
}