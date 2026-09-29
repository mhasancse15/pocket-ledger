import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    TransactionTable,
    CategoryTable,
    MonthlyLimitTable,
    BudgetTable,
    RecurringRuleTable,
    RecurringOccurrenceTable,
    BudgetNotificationStates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

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
        if (from < 3) {
          await m.createTable(budgetNotificationStates);
        }
        if (from < 4) {
          await m.addColumn(recurringRuleTable, recurringRuleTable.anchorDay);
          await m.addColumn(recurringRuleTable, recurringRuleTable.note);
          await m.addColumn(
            recurringRuleTable,
            recurringRuleTable.autoCreateTransaction,
          );
          await m.addColumn(
            recurringRuleTable,
            recurringRuleTable.lastGeneratedAt,
          );
          await m.createTable(recurringOccurrenceTable);
          await customStatement('''
            UPDATE recurring_rule_table
            SET anchor_day = CAST(
              strftime('%d', start_date / 1000, 'unixepoch') AS INTEGER
            )
          ''');
        }
        if (from < 5) {
          await m.addColumn(
            recurringRuleTable,
            recurringRuleTable.reminderDays,
          );
        }
        if (from < 6) {
          await m.addColumn(
            recurringRuleTable,
            recurringRuleTable.notificationId,
          );
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
    return (select(
      transactionTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<TransactionTableData>> getAllTransactions() {
    return select(transactionTable).get();
  }

  Future<List<TransactionTableData>> getTransactionsByMonth(
    int year,
    int month,
  ) {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 1);

    return (select(transactionTable)
          ..where(
            (t) =>
                t.date.isBiggerOrEqualValue(startOfMonth) &
                t.date.isSmallerThanValue(endOfMonth),
          )
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
    return (select(
      categoryTable,
    )..where((c) => c.isArchived.equals(false))).get();
  }

  Future<List<CategoryTableData>> getAllCategoriesIncludingArchived() {
    return select(categoryTable).get();
  }

  Future<List<CategoryTableData>> getCategoriesByType(String type) {
    return (select(
      categoryTable,
    )..where((c) => c.type.equals(type) & c.isArchived.equals(false))).get();
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
    return (delete(
      monthlyLimitTable,
    )..where((l) => l.year.equals(year) & l.month.equals(month))).go();
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
    return (select(budgetTable)..where(
          (b) =>
              b.year.equals(year) &
              b.month.equals(month) &
              b.scope.equals(scope) &
              b.scopeKey.equals(scopeKey),
        ))
        .getSingleOrNull();
  }

  Future<List<BudgetTableData>> getAllBudgets() => select(budgetTable).get();

  Future<int> getHighestBudgetWarning({
    required String sourceId,
    required int year,
    required int month,
  }) async {
    final result =
        await (select(budgetNotificationStates)..where(
              (row) =>
                  row.sourceId.equals(sourceId) &
                  row.year.equals(year) &
                  row.month.equals(month),
            ))
            .getSingleOrNull();

    return result?.warningLevel ?? 0;
  }

  Future<void> saveBudgetWarning({
    required String sourceId,
    required int year,
    required int month,
    required int warningLevel,
  }) async {
    final existingLevel = await getHighestBudgetWarning(
      sourceId: sourceId,
      year: year,
      month: month,
    );
    if (warningLevel <= existingLevel) return;

    await into(budgetNotificationStates).insertOnConflictUpdate(
      BudgetNotificationStatesCompanion.insert(
        sourceId: sourceId,
        year: year,
        month: month,
        warningLevel: warningLevel,
        notifiedAt: DateTime.now(),
      ),
    );
  }

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

  Stream<List<RecurringRuleTableData>> watchAllRecurringRules() {
    return select(recurringRuleTable).watch();
  }

  Future<List<RecurringRuleTableData>> getActiveRecurringRules() {
    return (select(
      recurringRuleTable,
    )..where((r) => r.isActive.equals(true))).get();
  }

  Future<RecurringRuleTableData?> getRecurringRuleById(String id) {
    return (select(
      recurringRuleTable,
    )..where((rule) => rule.id.equals(id))).getSingleOrNull();
  }

  Future<bool> setRecurringRuleActive(String id, bool isActive) async {
    final changed =
        await (update(
          recurringRuleTable,
        )..where((row) => row.id.equals(id))).write(
          RecurringRuleTableCompanion(
            isActive: Value(isActive),
            updatedAt: Value(DateTime.now()),
          ),
        );
    return changed > 0;
  }

  Future<List<RecurringOccurrenceTableData>> getRecurringOccurrences(
    String ruleId,
  ) {
    return (select(recurringOccurrenceTable)
          ..where((occurrence) => occurrence.recurringRuleId.equals(ruleId))
          ..orderBy([
            (occurrence) => OrderingTerm.desc(occurrence.scheduledDate),
          ]))
        .get();
  }

  Future<bool> recurringOccurrenceExists({
    required String ruleId,
    required DateTime scheduledDate,
  }) async {
    final occurrence =
        await (select(recurringOccurrenceTable)..where(
              (row) =>
                  row.recurringRuleId.equals(ruleId) &
                  row.scheduledDate.equals(scheduledDate),
            ))
            .getSingleOrNull();
    return occurrence != null;
  }

  Future<void> saveRecurringOccurrence(
    RecurringOccurrenceTableCompanion occurrence,
  ) async {
    await into(recurringOccurrenceTable).insert(occurrence);
  }

  Future<bool> recordRecurringOccurrence({
    required String ruleId,
    required DateTime scheduledDate,
    required DateTime nextOccurrenceDate,
    required RecurringOccurrenceTableCompanion occurrence,
    required TransactionTableCompanion? generatedTransaction,
    required bool deactivateRule,
    bool advanceRule = true,
  }) {
    return transaction(() async {
      final rule = await (select(
        recurringRuleTable,
      )..where((row) => row.id.equals(ruleId))).getSingleOrNull();
      if (rule == null ||
          !rule.isActive ||
          rule.nextOccurrenceDate.year != scheduledDate.year ||
          rule.nextOccurrenceDate.month != scheduledDate.month ||
          rule.nextOccurrenceDate.day != scheduledDate.day) {
        return false;
      }

      final existing =
          await (select(recurringOccurrenceTable)..where(
                (row) =>
                    row.recurringRuleId.equals(ruleId) &
                    row.scheduledDate.equals(scheduledDate),
              ))
              .getSingleOrNull();
      var transactionCreated = false;
      if (existing == null) {
        if (generatedTransaction != null) {
          await into(transactionTable).insert(generatedTransaction);
          transactionCreated = true;
        }
        await into(recurringOccurrenceTable).insert(occurrence);
      } else if (generatedTransaction != null &&
          existing.transactionId == null &&
          existing.status == 'skipped') {
        await into(transactionTable).insert(generatedTransaction);
        await (update(
          recurringOccurrenceTable,
        )..where((row) => row.id.equals(existing.id))).write(
          RecurringOccurrenceTableCompanion(
            transactionId: Value(generatedTransaction.id.value),
            status: const Value('generated'),
          ),
        );
        transactionCreated = true;
      }

      await (update(
        recurringRuleTable,
      )..where((row) => row.id.equals(ruleId))).write(
        RecurringRuleTableCompanion(
          lastGeneratedAt: transactionCreated
              ? Value(DateTime.now())
              : const Value.absent(),
          isActive: Value(
            advanceRule ? rule.isActive && !deactivateRule : rule.isActive,
          ),
          nextOccurrenceDate: advanceRule
              ? Value(nextOccurrenceDate)
              : Value(rule.nextOccurrenceDate),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return advanceRule || existing == null || transactionCreated;
    });
  }

  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(transactionTable).go();
      await delete(categoryTable).go();
      await delete(monthlyLimitTable).go();
      await delete(budgetTable).go();
      await delete(recurringRuleTable).go();
      await delete(recurringOccurrenceTable).go();
      await delete(budgetNotificationStates).go();
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
