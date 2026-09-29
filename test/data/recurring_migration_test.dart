import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_wallet/data/datasources/drift/database.dart';
import 'package:my_wallet/domain/entities/monthly_saving.dart';

void main() {
  test(
    'upgrades existing recurring rules and preserves their anchor day',
    () async {
      final executor = NativeDatabase.memory(
        setup: (database) {
          database.execute('''
          CREATE TABLE recurring_rule_table (
            id TEXT NOT NULL PRIMARY KEY,
            title TEXT NOT NULL,
            amount REAL NOT NULL,
            category_id TEXT NOT NULL,
            payment_method TEXT NOT NULL,
            frequency TEXT NOT NULL,
            start_date INTEGER NOT NULL,
            next_occurrence_date INTEGER NOT NULL,
            end_date INTEGER,
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
          database.execute('''
          INSERT INTO recurring_rule_table (
            id, title, amount, category_id, payment_method, frequency,
            start_date, next_occurrence_date, end_date, is_active,
            created_at, updated_at
          ) VALUES (
            'rent', 'House rent', 15000, 'housing', 'cash', 'monthly',
            1769817600000, 1769817600000, NULL, 1, 1769817600000,
            1769817600000
          )
        ''');
          database.execute('''
            CREATE TABLE transaction_table (
              id TEXT NOT NULL PRIMARY KEY,
              type TEXT NOT NULL,
              amount REAL NOT NULL,
              category_id TEXT NOT NULL,
              date INTEGER NOT NULL,
              payment_method TEXT NOT NULL,
              note TEXT,
              recurring_rule_id TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          database.execute('''
            CREATE TABLE category_table (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              type TEXT NOT NULL,
              icon TEXT,
              color TEXT,
              is_archived INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL
            )
          ''');
          database.execute('PRAGMA user_version = 3');
        },
      );
      final appDatabase = AppDatabase.forTesting(executor);

      addTearDown(appDatabase.close);
      final rule = await appDatabase.getRecurringRuleById('rent');

      expect(rule?.anchorDay, 31);
      expect(rule?.autoCreateTransaction, isTrue);
      expect(rule?.note, isNull);
      expect(rule?.reminderDays, isNull);
      expect(rule?.notificationId, isNull);

      await appDatabase.insertMonthlySavingEntry(
        MonthlySavingEntryTableCompanion.insert(
          id: 'monthly-saving',
          year: 2026,
          month: 9,
          amount: 1200,
          date: DateTime(2026, 9, 10),
          createdAt: DateTime(2026, 9, 10),
          updatedAt: DateTime(2026, 9, 10),
        ),
      );
      final savings = await appDatabase.getMonthlySavingEntries(2026, 9);
      expect(savings, hasLength(1));
      expect(savings.single.amount, 1200);

      await appDatabase.insertMonthlySavingEntry(
        MonthlySavingEntryTableCompanion.insert(
          id: 'monthly-surplus-2026-9',
          year: 2026,
          month: 9,
          amount: 500,
          date: DateTime(2026, 9, 30),
          source: const Value('monthlySurplusRollover'),
          note: const Value('Previous month surplus automatically saved'),
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 1),
        ),
      );
      await appDatabase
          .into(appDatabase.monthlySavingFinalizationTable)
          .insert(
            MonthlySavingFinalizationTableCompanion.insert(
              year: 2026,
              month: 9,
              finalizedAt: DateTime(2026, 10, 1),
            ),
          );

      final previousMonthSummary = MonthlySavingSummary(
        year: 2026,
        month: 9,
        income: 60000,
        expenses: 42000,
        saved: 1700,
      );
      final rolloverAmount =
          previousMonthSummary.surplus > previousMonthSummary.saved
          ? previousMonthSummary.surplus
          : previousMonthSummary.saved;
      final firstFinalization = await appDatabase.carryForwardMonthlySurplus(
        sourceYear: previousMonthSummary.year,
        sourceMonth: previousMonthSummary.month,
        incomeDate: DateTime(2026, 10, 1),
        amount: rolloverAmount,
        alreadySaved: previousMonthSummary.saved,
        createdAt: DateTime(2026, 10, 1),
      );
      final repeatedFinalization = await appDatabase.carryForwardMonthlySurplus(
        sourceYear: 2026,
        sourceMonth: 9,
        incomeDate: DateTime(2026, 10, 1),
        amount: 500,
        alreadySaved: previousMonthSummary.saved,
        createdAt: DateTime(2026, 10, 2),
      );
      expect(firstFinalization, isTrue);
      expect(repeatedFinalization, isFalse);

      final remainingSavings = await appDatabase.getMonthlySavingEntries(
        2026,
        9,
      );
      expect(remainingSavings, hasLength(2));
      expect(
        remainingSavings.any((entry) => entry.id == 'monthly-saving'),
        isTrue,
      );

      final carriedIncome = await appDatabase.getTransactionById(
        'monthly-surplus-income-2026-9',
      );
      expect(carriedIncome?.type, 'income');
      expect(carriedIncome?.amount, 18000);
      expect(carriedIncome?.categoryId, 'system_previous_month_savings');
      expect(carriedIncome?.date, DateTime(2026, 10, 1));
      final savedEntries = await appDatabase.getMonthlySavingEntries(2026, 9);
      expect(savedEntries, hasLength(2));
      final automaticSaving = savedEntries.singleWhere(
        (entry) => entry.id == 'monthly-saving-rollover-2026-9',
      );
      expect(automaticSaving.amount, 16800);
      expect(automaticSaving.source, 'monthlySurplusRollover');
      expect(
        await appDatabase
            .getCategoriesByType('income')
            .then(
              (categories) => categories.any(
                (category) => category.id == 'system_previous_month_savings',
              ),
            ),
        isTrue,
      );
    },
  );

  test('adds rollover tracking to an existing monthly savings table', () async {
    final executor = NativeDatabase.memory(
      setup: (database) {
        database.execute('''
          CREATE TABLE monthly_saving_entry_table (
            id TEXT NOT NULL PRIMARY KEY,
            year INTEGER NOT NULL,
            month INTEGER NOT NULL,
            amount REAL NOT NULL,
            date INTEGER NOT NULL,
            note TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        database.execute('''
          INSERT INTO monthly_saving_entry_table (
            id, year, month, amount, date, note, created_at, updated_at
          ) VALUES (
            'existing-saving', 2026, 8, 300, 1788220800, NULL,
            1788220800, 1788220800
          )
        ''');
        database.execute('PRAGMA user_version = 7');
      },
    );
    final appDatabase = AppDatabase.forTesting(executor);
    addTearDown(appDatabase.close);

    final entries = await appDatabase.getMonthlySavingEntries(2026, 8);
    expect(entries, hasLength(1));
    expect(entries.single.amount, 300);
    expect(entries.single.source, 'manual');

    final columns = await appDatabase
        .customSelect("PRAGMA table_info('monthly_saving_finalization_table')")
        .get();
    expect(columns, isNotEmpty);
  });

  test(
    'does not re-add source when an existing version-7 database already has it',
    () async {
      final executor = NativeDatabase.memory(
        setup: (database) {
          database.execute('''
            CREATE TABLE monthly_saving_entry_table (
              id TEXT NOT NULL PRIMARY KEY,
              year INTEGER NOT NULL,
              month INTEGER NOT NULL,
              amount REAL NOT NULL,
              date INTEGER NOT NULL,
              source TEXT NOT NULL DEFAULT 'manual',
              note TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          database.execute('''
            INSERT INTO monthly_saving_entry_table (
              id, year, month, amount, date, source, created_at, updated_at
            ) VALUES (
              'existing-saving', 2026, 8, 300, 1788220800, 'manual',
              1788220800, 1788220800
            )
          ''');
          database.execute('PRAGMA user_version = 7');
        },
      );
      final appDatabase = AppDatabase.forTesting(executor);
      addTearDown(appDatabase.close);

      final entries = await appDatabase.getMonthlySavingEntries(2026, 8);
      expect(entries, hasLength(1));
      expect(entries.single.source, 'manual');

      final columns = await appDatabase
          .customSelect(
            "PRAGMA table_info('monthly_saving_finalization_table')",
          )
          .get();
      expect(columns, isNotEmpty);
    },
  );

  test('clearAllData deletes monthly savings and rollover markers', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await database.customSelect('SELECT 1').get();

    await database.insertMonthlySavingEntry(
      MonthlySavingEntryTableCompanion.insert(
        id: 'saved-entry',
        year: 2026,
        month: 9,
        amount: 15000,
        date: DateTime(2026, 9, 30),
        createdAt: DateTime(2026, 9, 30),
        updatedAt: DateTime(2026, 9, 30),
      ),
    );
    await database
        .into(database.monthlySavingFinalizationTable)
        .insert(
          MonthlySavingFinalizationTableCompanion.insert(
            year: 2026,
            month: 9,
            finalizedAt: DateTime(2026, 10, 1),
          ),
        );

    await database.clearAllData();

    expect(await database.getAllMonthlySavingEntries(), isEmpty);
    expect(
      await database.select(database.monthlySavingFinalizationTable).get(),
      isEmpty,
    );
  });
}
