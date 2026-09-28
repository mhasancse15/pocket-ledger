import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_wallet/data/datasources/drift/database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('warning level is persisted and never lowered within a month', () async {
    const sourceId = 'budget:food';

    expect(
      await database.getHighestBudgetWarning(
        sourceId: sourceId,
        year: 2026,
        month: 9,
      ),
      0,
    );

    await database.saveBudgetWarning(
      sourceId: sourceId,
      year: 2026,
      month: 9,
      warningLevel: 2,
    );
    await database.saveBudgetWarning(
      sourceId: sourceId,
      year: 2026,
      month: 9,
      warningLevel: 1,
    );

    expect(
      await database.getHighestBudgetWarning(
        sourceId: sourceId,
        year: 2026,
        month: 9,
      ),
      2,
    );
    expect(
      await database.getHighestBudgetWarning(
        sourceId: sourceId,
        year: 2026,
        month: 10,
      ),
      0,
    );
  });
}
