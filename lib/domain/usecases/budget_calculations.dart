import '../entities/budget.dart';
import '../entities/transaction.dart';

bool transactionMatchesBudget({
  required Transaction transaction,
  required Budget budget,
}) {
  final date = transaction.date.toLocal();
  final sameMonth = date.year == budget.year && date.month == budget.month;

  final scopeMatches =
      budget.scope == BudgetScope.monthly ||
      budget.scope == BudgetScope.category &&
          transaction.categoryId == budget.scopeKey ||
      budget.scope == BudgetScope.wallet &&
          transaction.paymentMethod.name == budget.scopeKey;

  return sameMonth &&
      transaction.type == TransactionType.expense &&
      scopeMatches;
}

double calculateBudgetSpent({
  required Budget budget,
  required List<Transaction> transactions,
}) {
  return transactions
      .where(
        (transaction) =>
            transactionMatchesBudget(transaction: transaction, budget: budget),
      )
      .fold<double>(0, (sum, transaction) => sum + transaction.amount);
}

double calculateEffectiveBudgetLimit({
  required Budget budget,
  required List<Budget> allBudgets,
  required List<Transaction> transactions,
}) {
  if (!budget.rollover) return budget.amount;

  final previousMonth = DateTime(budget.year, budget.month - 1);
  final previousBudget = allBudgets.where(
    (candidate) =>
        candidate.scope == budget.scope &&
        candidate.scopeKey == budget.scopeKey &&
        candidate.year == previousMonth.year &&
        candidate.month == previousMonth.month,
  );
  if (previousBudget.isEmpty) return budget.amount;

  final previous = previousBudget.first;
  final unused =
      previous.amount -
      calculateBudgetSpent(budget: previous, transactions: transactions);
  return budget.amount + (unused > 0 ? unused : 0);
}
