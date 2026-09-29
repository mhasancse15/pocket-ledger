import 'package:equatable/equatable.dart';

import '../../core/constants/monthly_saving_constants.dart';
import 'transaction.dart';

enum MonthlySavingSource { manual, monthlySurplusRollover }

class MonthlySavingEntry extends Equatable {
  const MonthlySavingEntry({
    required this.id,
    required this.year,
    required this.month,
    required this.amount,
    required this.date,
    this.source = MonthlySavingSource.manual,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final int year;
  final int month;
  final double amount;
  final DateTime date;
  final MonthlySavingSource source;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    id,
    year,
    month,
    amount,
    date,
    source,
    note,
    createdAt,
    updatedAt,
  ];
}

class MonthlySavingSummary extends Equatable {
  const MonthlySavingSummary({
    required this.year,
    required this.month,
    required this.income,
    required this.expenses,
    required this.saved,
    this.carriedSavingsIncome = 0,
  });

  final int year;
  final int month;
  final double income;
  final double expenses;
  final double saved;
  final double carriedSavingsIncome;

  double get surplus => income - expenses;
  double get unallocatedSurplus => surplus - saved;
  double get availableToSave =>
      unallocatedSurplus.clamp(0.0, double.infinity).toDouble();
  double get savingRate => income <= 0 ? 0 : saved / income * 100;
  bool get hasDeficit => surplus < 0;
  bool get isOverAllocated => unallocatedSurplus < 0;

  @override
  List<Object?> get props => [
    year,
    month,
    income,
    expenses,
    saved,
    carriedSavingsIncome,
  ];
}

MonthlySavingSummary calculateMonthlySavingSummary({
  required int year,
  required int month,
  required Iterable<Transaction> transactions,
  required Iterable<MonthlySavingEntry> entries,
}) {
  var income = 0.0;
  var carriedSavingsIncome = 0.0;
  var expenses = 0.0;
  for (final transaction in transactions) {
    final date = transaction.date.toLocal();
    if (date.year != year || date.month != month) continue;
    if (transaction.type == TransactionType.income) {
      income += transaction.amount;
      if (transaction.categoryId == monthlySurplusIncomeCategoryId) {
        carriedSavingsIncome += transaction.amount;
      }
    } else {
      expenses += transaction.amount;
    }
  }

  final saved = entries
      .where((entry) => entry.year == year && entry.month == month)
      .fold<double>(0, (sum, entry) => sum + entry.amount);

  return MonthlySavingSummary(
    year: year,
    month: month,
    income: income,
    expenses: expenses,
    saved: saved,
    carriedSavingsIncome: carriedSavingsIncome,
  );
}
