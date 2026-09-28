import 'package:flutter_test/flutter_test.dart';
import 'package:my_wallet/domain/entities/budget.dart';
import 'package:my_wallet/domain/entities/transaction.dart';
import 'package:my_wallet/domain/usecases/budget_calculations.dart';

void main() {
  final timestamp = DateTime(2026, 9, 10);

  Budget budget({
    BudgetScope scope = BudgetScope.monthly,
    String scopeKey = 'all',
    int month = 9,
    double amount = 1000,
    bool rollover = false,
  }) {
    return Budget(
      id: 'budget-$month',
      year: 2026,
      month: month,
      scope: scope,
      scopeKey: scopeKey,
      amount: amount,
      rollover: rollover,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  Transaction transaction({
    String id = 'transaction',
    TransactionType type = TransactionType.expense,
    String categoryId = 'food',
    PaymentMethod paymentMethod = PaymentMethod.cash,
    DateTime? date,
    double amount = 100,
  }) {
    return Transaction(
      id: id,
      type: type,
      amount: amount,
      categoryId: categoryId,
      date: date ?? timestamp,
      paymentMethod: paymentMethod,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  test('monthly budget counts current-month expenses only', () {
    final monthly = budget();
    expect(
      calculateBudgetSpent(
        budget: monthly,
        transactions: [
          transaction(amount: 100),
          transaction(id: 'income', type: TransactionType.income),
          transaction(id: 'previous-month', date: DateTime(2026, 8, 30)),
        ],
      ),
      100,
    );
  });

  test('category and payment method scopes match only their own expenses', () {
    final transactions = [
      transaction(id: 'matching-category', categoryId: 'food', amount: 30),
      transaction(id: 'other-category', categoryId: 'travel', amount: 50),
      transaction(
        id: 'matching-payment',
        categoryId: 'travel',
        paymentMethod: PaymentMethod.debitCard,
        amount: 20,
      ),
    ];

    expect(
      calculateBudgetSpent(
        budget: budget(scope: BudgetScope.category, scopeKey: 'food'),
        transactions: transactions,
      ),
      30,
    );
    expect(
      calculateBudgetSpent(
        budget: budget(scope: BudgetScope.wallet, scopeKey: 'debitCard'),
        transactions: transactions,
      ),
      20,
    );
  });

  test('rollover limit adds only the previous month unused amount', () {
    final previous = budget(month: 8, amount: 1000);
    final current = budget(month: 9, amount: 500, rollover: true);

    expect(
      calculateEffectiveBudgetLimit(
        budget: current,
        allBudgets: [previous, current],
        transactions: [transaction(date: DateTime(2026, 8, 10), amount: 700)],
      ),
      800,
    );
  });
}
