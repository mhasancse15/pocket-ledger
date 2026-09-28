enum BudgetWarningLevel { none, warning75, warning90, reached100, exceeded }

BudgetWarningLevel calculateWarningLevel({
  required double spent,
  required double limit,
}) {
  if (limit <= 0) return BudgetWarningLevel.none;
  if (spent > limit) return BudgetWarningLevel.exceeded;
  if (spent >= limit) return BudgetWarningLevel.reached100;

  final percentage = spent / limit * 100;
  if (percentage >= 90) return BudgetWarningLevel.warning90;
  if (percentage >= 75) return BudgetWarningLevel.warning75;
  return BudgetWarningLevel.none;
}
