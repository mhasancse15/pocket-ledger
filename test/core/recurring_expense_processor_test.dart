import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:my_wallet/core/services/recurring_expense_processor.dart';
import 'package:my_wallet/data/datasources/drift/database.dart';

void main() {
  late AppDatabase database;
  final today = DateTime(2026, 3, 1);

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'creates each missed monthly expense once and preserves anchor day',
    () async {
      await database.insertRecurringRule(
        RecurringRuleTableCompanion.insert(
          id: 'rent',
          title: 'House rent',
          amount: 15000,
          categoryId: 'housing',
          paymentMethod: 'cash',
          frequency: 'monthly',
          startDate: DateTime(2026, 1, 31),
          nextOccurrenceDate: DateTime(2026, 1, 31),
          anchorDay: const Value(31),
          createdAt: today,
          updatedAt: today,
        ),
      );
      final processor = RecurringExpenseProcessor(database, clock: () => today);

      expect(await processor.processDueRules(), 2);
      expect(await processor.processDueRules(), 0);
      expect((await database.getAllTransactions()).length, 2);
      expect((await database.getRecurringOccurrences('rent')).length, 2);
      expect(
        (await database.getRecurringRuleById('rent'))?.nextOccurrenceDate,
        DateTime(2026, 3, 31),
      );
    },
  );

  test(
    'records reminder-only occurrences without creating transactions',
    () async {
      await database.insertRecurringRule(
        RecurringRuleTableCompanion.insert(
          id: 'subscription',
          title: 'Streaming',
          amount: 1200,
          categoryId: 'entertainment',
          paymentMethod: 'mobileWallet',
          frequency: 'monthly',
          startDate: DateTime(2026, 2, 1),
          nextOccurrenceDate: DateTime(2026, 2, 1),
          autoCreateTransaction: const Value(false),
          createdAt: today,
          updatedAt: today,
        ),
      );

      final count = await RecurringExpenseProcessor(
        database,
        clock: () => today,
      ).processDueRules();

      expect(count, 2);
      expect(await database.getAllTransactions(), isEmpty);
      final occurrences = await database.getRecurringOccurrences(
        'subscription',
      );
      expect(occurrences, hasLength(2));
      expect(occurrences.every((item) => item.status == 'skipped'), isTrue);
      expect(occurrences.every((item) => item.transactionId == null), isTrue);
    },
  );

  test(
    'rolls back occurrence and rule updates when transaction insert fails',
    () async {
      await database.insertRecurringRule(
        RecurringRuleTableCompanion.insert(
          id: 'atomic',
          title: 'Internet',
          amount: 1200,
          categoryId: 'utilities',
          paymentMethod: 'cash',
          frequency: 'monthly',
          startDate: DateTime(2026, 2, 1),
          nextOccurrenceDate: DateTime(2026, 2, 1),
          createdAt: today,
          updatedAt: today,
        ),
      );
      await database.insertTransaction(
        TransactionTableCompanion.insert(
          id: 'duplicate-id',
          type: 'expense',
          amount: 1,
          categoryId: 'other',
          date: today,
          paymentMethod: 'cash',
          createdAt: today,
          updatedAt: today,
        ),
      );

      await expectLater(
        database.recordRecurringOccurrence(
          ruleId: 'atomic',
          scheduledDate: DateTime(2026, 2, 1),
          nextOccurrenceDate: DateTime(2026, 3, 1),
          occurrence: RecurringOccurrenceTableCompanion.insert(
            id: 'occurrence-id',
            recurringRuleId: 'atomic',
            scheduledDate: DateTime(2026, 2, 1),
            transactionId: const Value('duplicate-id'),
            status: 'generated',
            createdAt: today,
          ),
          generatedTransaction: TransactionTableCompanion.insert(
            id: 'duplicate-id',
            type: 'expense',
            amount: 1200,
            categoryId: 'utilities',
            date: DateTime(2026, 2, 1),
            paymentMethod: 'cash',
            createdAt: today,
            updatedAt: today,
          ),
          deactivateRule: false,
        ),
        throwsA(isA<Exception>()),
      );

      expect(await database.getRecurringOccurrences('atomic'), isEmpty);
      expect(
        (await database.getRecurringRuleById('atomic'))?.nextOccurrenceDate,
        DateTime(2026, 2, 1),
      );
    },
  );

  test(
    'generate now is idempotent until the scheduled date advances',
    () async {
      await database.insertRecurringRule(
        RecurringRuleTableCompanion.insert(
          id: 'electricity',
          title: 'Electricity',
          amount: 900,
          categoryId: 'utilities',
          paymentMethod: 'cash',
          frequency: 'weekly',
          startDate: DateTime(2026, 3, 10),
          nextOccurrenceDate: DateTime(2026, 3, 10),
          createdAt: today,
          updatedAt: today,
        ),
      );
      final processor = RecurringExpenseProcessor(database, clock: () => today);

      expect(await processor.generateNow('electricity'), isTrue);
      expect(await processor.generateNow('electricity'), isFalse);
      expect(await database.getAllTransactions(), hasLength(1));
      expect(
        (await database.getRecurringRuleById('electricity'))
            ?.nextOccurrenceDate,
        DateTime(2026, 3, 10),
      );

      final dueProcessor = RecurringExpenseProcessor(
        database,
        clock: () => DateTime(2026, 3, 10),
      );
      expect(await dueProcessor.processDueRules(), 1);
      expect(await database.getAllTransactions(), hasLength(1));
      expect(
        (await database.getRecurringRuleById('electricity'))
            ?.nextOccurrenceDate,
        DateTime(2026, 3, 17),
      );
    },
  );
}
