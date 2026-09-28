import 'package:flutter_test/flutter_test.dart';
import 'package:my_wallet/domain/usecases/budget_warning_level.dart';

void main() {
  group('calculateWarningLevel', () {
    test('does not warn below 75 percent or for invalid limits', () {
      expect(
        calculateWarningLevel(spent: 74, limit: 100),
        BudgetWarningLevel.none,
      );
      expect(
        calculateWarningLevel(spent: 100, limit: 0),
        BudgetWarningLevel.none,
      );
    });

    test('uses the highest crossed threshold', () {
      expect(
        calculateWarningLevel(spent: 75, limit: 100),
        BudgetWarningLevel.warning75,
      );
      expect(
        calculateWarningLevel(spent: 95, limit: 100),
        BudgetWarningLevel.warning90,
      );
    });

    test('distinguishes exactly reaching and exceeding the limit', () {
      expect(
        calculateWarningLevel(spent: 100, limit: 100),
        BudgetWarningLevel.reached100,
      );
      expect(
        calculateWarningLevel(spent: 100.01, limit: 100),
        BudgetWarningLevel.exceeded,
      );
    });
  });
}
