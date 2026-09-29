import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/monthly_saving_constants.dart';
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
    MonthlySavingEntryTable,
    MonthlySavingFinalizationTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 8;

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
        if (from < 7) {
          await m.createTable(monthlySavingEntryTable);
        }
        if (from >= 7 && from < 8) {
          final columns = await customSelect(
            "PRAGMA table_info('monthly_saving_entry_table')",
          ).get();
          final hasSourceColumn = columns.any(
            (column) => column.data['name'] == 'source',
          );
          if (!hasSourceColumn) {
            await m.addColumn(
              monthlySavingEntryTable,
              monthlySavingEntryTable.source,
            );
          }
        }
        if (from < 8) {
          await m.createTable(monthlySavingFinalizationTable);
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

  Future<int> insertMonthlySavingEntry(
    MonthlySavingEntryTableCompanion entry,
  ) => into(monthlySavingEntryTable).insert(entry);

  Future<bool> updateMonthlySavingEntry(MonthlySavingEntryTableData entry) =>
      update(monthlySavingEntryTable).replace(entry);

  Future<List<MonthlySavingEntryTableData>> getMonthlySavingEntries(
    int year,
    int month,
  ) =>
      (select(monthlySavingEntryTable)
            ..where(
              (entry) => entry.year.equals(year) & entry.month.equals(month),
            )
            ..orderBy([(entry) => OrderingTerm.desc(entry.date)]))
          .get();

  Future<List<MonthlySavingEntryTableData>> getAllMonthlySavingEntries() =>
      (select(monthlySavingEntryTable)..orderBy([
            (entry) => OrderingTerm.desc(entry.year),
            (entry) => OrderingTerm.desc(entry.month),
            (entry) => OrderingTerm.desc(entry.date),
          ]))
          .get();

  Future<int> deleteMonthlySavingEntry(String id) => (delete(
    monthlySavingEntryTable,
  )..where((entry) => entry.id.equals(id))).go();

  Future<bool> carryForwardMonthlySurplus({
    required int sourceYear,
    required int sourceMonth,
    required DateTime incomeDate,
    required double amount,
    required double alreadySaved,
    required DateTime createdAt,
  }) {
    return transaction(() async {
      var previousSavedAmount = alreadySaved;
      final existing =
          await (select(monthlySavingFinalizationTable)..where(
                (row) =>
                    row.year.equals(sourceYear) & row.month.equals(sourceMonth),
              ))
              .getSingleOrNull();
      if (existing != null) {
        final carriedIncome = await getTransactionById(
          'monthly-surplus-income-$sourceYear-$sourceMonth',
        );
        if (carriedIncome != null) return false;
        final legacyEntry =
            await (select(monthlySavingEntryTable)..where(
                  (entry) => entry.id.equals(
                    'monthly-surplus-$sourceYear-$sourceMonth',
                  ),
                ))
                .getSingleOrNull();
        if (legacyEntry != null) {
          previousSavedAmount -= legacyEntry.amount;
          await deleteMonthlySavingEntry(legacyEntry.id);
        }
        await (delete(monthlySavingFinalizationTable)..where(
              (row) =>
                  row.year.equals(sourceYear) & row.month.equals(sourceMonth),
            ))
            .go();
      }

      await into(monthlySavingFinalizationTable).insert(
        MonthlySavingFinalizationTableCompanion.insert(
          year: sourceYear,
          month: sourceMonth,
          finalizedAt: createdAt,
        ),
      );

      if (amount > 0) {
        final additionalSaving = amount - previousSavedAmount;
        if (additionalSaving > 0) {
          await into(monthlySavingEntryTable).insert(
            MonthlySavingEntryTableCompanion.insert(
              id: 'monthly-saving-rollover-$sourceYear-$sourceMonth',
              year: sourceYear,
              month: sourceMonth,
              amount: additionalSaving,
              date: DateTime(sourceYear, sourceMonth + 1, 0),
              source: const Value('monthlySurplusRollover'),
              note: const Value('Surplus automatically saved at month end'),
              createdAt: createdAt,
              updatedAt: createdAt,
            ),
          );
        }
        await into(categoryTable).insertOnConflictUpdate(
          CategoryTableCompanion.insert(
            id: monthlySurplusIncomeCategoryId,
            name: 'Previous month savings',
            type: 'income',
            icon: const Value('savings'),
            color: const Value('#2F6F5E'),
            isArchived: const Value(false),
            createdAt: createdAt,
          ),
        );
        await into(transactionTable).insert(
          TransactionTableCompanion.insert(
            id: 'monthly-surplus-income-$sourceYear-$sourceMonth',
            type: 'income',
            amount: amount,
            categoryId: monthlySurplusIncomeCategoryId,
            date: incomeDate,
            paymentMethod: 'other',
            note: const Value('Previous month savings carried forward'),
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
        );
      }

      return true;
    });
  }

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
