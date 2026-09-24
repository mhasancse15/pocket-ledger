import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/drift/database.dart';
import '../../domain/entities/budget.dart';
import 'database_provider.dart';

final budgetsProvider = FutureProvider<List<Budget>>((ref) async {
  final rows = await ref.watch(databaseProvider).getAllBudgets();
  return rows.map(_fromRow).toList();
});

final budgetStoreProvider = Provider<BudgetStore>(
  (ref) => BudgetStore(ref.watch(databaseProvider), ref),
);

class BudgetStore {
  BudgetStore(this._database, this._ref);
  final AppDatabase _database;
  final Ref _ref;

  Future<void> save(Budget budget) async {
    await _database.upsertBudget(
      BudgetTableCompanion.insert(
        id: budget.id,
        year: budget.year,
        month: budget.month,
        scope: budget.scope.name,
        scopeKey: budget.scopeKey,
        amount: budget.amount,
        rollover: Value(budget.rollover),
        createdAt: budget.createdAt,
        updatedAt: budget.updatedAt,
      ),
    );
    _ref.invalidate(budgetsProvider);
  }

  Future<void> delete(Budget budget) async {
    await _database.deleteBudgetById(budget.id);
    _ref.invalidate(budgetsProvider);
  }
}

Budget _fromRow(BudgetTableData row) => Budget(
      id: row.id,
      year: row.year,
      month: row.month,
      scope: BudgetScope.values.firstWhere(
        (value) => value.name == row.scope,
        orElse: () => BudgetScope.monthly,
      ),
      scopeKey: row.scopeKey,
      amount: row.amount,
      rollover: row.rollover,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
