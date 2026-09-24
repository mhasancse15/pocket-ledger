import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  TransactionTable,
  CategoryTable,
  MonthlyLimitTable,
  BudgetTable,
  RecurringRuleTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(budgetTable);
        }
      },
    );
  }

  // --- Transaction Table Queries ---

  Future<int> insertTransaction(TransactionTableCompanion transaction) {
    return into(transactionTable).insert(transaction);
  }

  Future<bool> updateTransaction(TransactionTableData transaction) {
    return update(transactionTable).replace(transaction);
  }

  Future<int> deleteTransactionById(String id) {
    return (delete(transactionTable)..where((t) => t.id.equals(id))).go();
  }

  Future<TransactionTableData?> getTransactionById(String id) {
    return (select(transactionTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<TransactionTableData>> getAllTransactions() {
    return select(transactionTable).get();
  }

  Future<List<TransactionTableData>> getTransactionsByMonth(
      int year, int month) {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 1);

    return (select(transactionTable)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(startOfMonth) &
              t.date.isSmallerThanValue(endOfMonth))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  // --- Category Table Queries ---

  Future<int> insertCategory(CategoryTableCompanion category) {
    return into(categoryTable).insert(category);
  }

  Future<bool> updateCategory(CategoryTableData category) {
    return update(categoryTable).replace(category);
  }

  Future<int> deleteCategoryById(String id) {
    return (delete(categoryTable)..where((c) => c.id.equals(id))).go();
  }

  Future<List<CategoryTableData>> getAllCategories() {
    return (select(categoryTable)
          ..where((c) => c.isArchived.equals(false)))
        .get();
  }

  Future<List<CategoryTableData>> getCategoriesByType(String type) {
    return (select(categoryTable)
          ..where((c) => c.type.equals(type) & c.isArchived.equals(false)))
        .get();
  }

  // --- Monthly Limit Table Queries ---

  Future<int> setMonthlyLimit(MonthlyLimitTableCompanion limit) {
    return into(monthlyLimitTable).insertOnConflictUpdate(limit);
  }

  Future<bool> updateMonthlyLimit(MonthlyLimitTableData limit) {
    return update(monthlyLimitTable).replace(limit);
  }

  Future<MonthlyLimitTableData?> getMonthlyLimit(int year, int month) {
    return (select(monthlyLimitTable)
          ..where((l) => l.year.equals(year) & l.month.equals(month)))
        .getSingleOrNull();
  }

  Future<int> deleteMonthlyLimit(int year, int month) {
    return (delete(monthlyLimitTable)
          ..where((l) => l.year.equals(year) & l.month.equals(month)))
        .go();
  }

  Future<List<MonthlyLimitTableData>> getAllMonthlyLimits() {
    return select(monthlyLimitTable).get();
  }

  Future<BudgetTableData?> getBudget(
    int year,
    int month,
    String scope,
    String scopeKey,
  ) {
    return (select(budgetTable)
          ..where((b) =>
              b.year.equals(year) &
              b.month.equals(month) &
              b.scope.equals(scope) &
              b.scopeKey.equals(scopeKey)))
        .getSingleOrNull();
  }

  Future<List<BudgetTableData>> getAllBudgets() => select(budgetTable).get();

  Future<int> upsertBudget(BudgetTableCompanion budget) =>
      into(budgetTable).insertOnConflictUpdate(budget);

  Future<int> deleteBudgetById(String id) =>
      (delete(budgetTable)..where((b) => b.id.equals(id))).go();

  // --- Recurring Rule Table Queries ---

  Future<int> insertRecurringRule(RecurringRuleTableCompanion rule) {
    return into(recurringRuleTable).insert(rule);
  }

  Future<bool> updateRecurringRule(RecurringRuleTableData rule) {
    return update(recurringRuleTable).replace(rule);
  }

  Future<int> deleteRecurringRuleById(String id) {
    return (delete(recurringRuleTable)..where((r) => r.id.equals(id))).go();
  }

  Future<List<RecurringRuleTableData>> getAllRecurringRules() {
    return select(recurringRuleTable).get();
  }

  Future<List<RecurringRuleTableData>> getActiveRecurringRules() {
    return (select(recurringRuleTable)..where((r) => r.isActive.equals(true)))
        .get();
  }

  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(transactionTable).go();
      await delete(categoryTable).go();
      await delete(monthlyLimitTable).go();
      await delete(budgetTable).go();
      await delete(recurringRuleTable).go();
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'pocket_ledger.db'));
    return NativeDatabase.createInBackground(file);
  });
}
