import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_wallet/data/datasources/drift/database.dart';

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
    },
  );
}
