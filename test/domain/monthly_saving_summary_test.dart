import 'package:flutter_test/flutter_test.dart';
import 'package:my_wallet/domain/entities/monthly_saving.dart';
import 'package:my_wallet/domain/entities/transaction.dart';

void main() {
  final timestamp = DateTime(2026, 9, 10);

  Transaction transaction({
    required String id,
    required TransactionType type,
    required double amount,
    DateTime? date,
  }) {
    return Transaction(
      id: id,
      type: type,
      amount: amount,
      categoryId: 'general',
      date: date ?? timestamp,
      paymentMethod: PaymentMethod.cash,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  MonthlySavingEntry entry({
    required String id,
    required int month,
    required double amount,
  }) {
    return MonthlySavingEntry(
      id: id,
      year: 2026,
      month: month,
      amount: amount,
      date: DateTime(2026, month, 10),
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  test('calculates surplus and confirmed allocations without expenses', () {
    final summary = calculateMonthlySavingSummary(
      year: 2026,
      month: 9,
      transactions: [
        transaction(id: 'salary', type: TransactionType.income, amount: 60000),
        transaction(id: 'rent', type: TransactionType.expense, amount: 20000),
        transaction(
          id: 'other-month',
          type: TransactionType.income,
          amount: 5000,
          date: DateTime(2026, 8, 10),
        ),
      ],
      entries: [
        entry(id: 'saved', month: 9, amount: 12000),
        entry(id: 'other-month-saved', month: 8, amount: 1000),
      ],
    );

    expect(summary.income, 60000);
    expect(summary.expenses, 20000);
    expect(summary.surplus, 40000);
    expect(summary.saved, 12000);
    expect(summary.availableToSave, 28000);
    expect(summary.savingRate, 20);
  });

  test('does not offer surplus during a deficit or when overallocated', () {
    final deficit = calculateMonthlySavingSummary(
      year: 2026,
      month: 9,
      transactions: [
        transaction(id: 'salary', type: TransactionType.income, amount: 1000),
        transaction(id: 'bills', type: TransactionType.expense, amount: 1200),
      ],
      entries: const [],
    );
    expect(deficit.hasDeficit, isTrue);
    expect(deficit.availableToSave, 0);

    final overallocated = MonthlySavingSummary(
      year: 2026,
      month: 9,
      income: 10000,
      expenses: 5000,
      saved: 6000,
    );
    expect(overallocated.isOverAllocated, isTrue);
    expect(overallocated.availableToSave, 0);
    expect(overallocated.unallocatedSurplus, -1000);
  });

  test('includes carried savings income when calculating monthly surplus', () {
    final summary = calculateMonthlySavingSummary(
      year: 2026,
      month: 10,
      transactions: [
        transaction(
          id: 'carried-savings',
          type: TransactionType.income,
          amount: 5000,
          date: DateTime(2026, 10, 1),
        ).copyWith(categoryId: 'system_previous_month_savings'),
        transaction(
          id: 'new-salary',
          type: TransactionType.income,
          amount: 20000,
          date: DateTime(2026, 10, 10),
        ),
        transaction(
          id: 'expenses',
          type: TransactionType.expense,
          amount: 10000,
          date: DateTime(2026, 10, 10),
        ),
      ],
      entries: const [],
    );

    expect(summary.income, 25000);
    expect(summary.carriedSavingsIncome, 5000);
    expect(summary.surplus, 15000);
    expect(summary.hasDeficit, isFalse);

    final afterExpenses = calculateMonthlySavingSummary(
      year: 2026,
      month: 10,
      transactions: [
        transaction(
          id: 'carried-savings',
          type: TransactionType.income,
          amount: 5000,
          date: DateTime(2026, 10, 1),
        ).copyWith(categoryId: 'system_previous_month_savings'),
        transaction(
          id: 'salary',
          type: TransactionType.income,
          amount: 10000,
          date: DateTime(2026, 10, 10),
        ),
        transaction(
          id: 'expenses',
          type: TransactionType.expense,
          amount: 12000,
          date: DateTime(2026, 10, 10),
        ),
      ],
      entries: const [],
    );
    expect(afterExpenses.surplus, 3000);
    expect(afterExpenses.hasDeficit, isFalse);
  });
}
