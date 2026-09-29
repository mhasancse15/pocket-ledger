import 'package:flutter_test/flutter_test.dart';
import 'package:my_wallet/domain/entities/recurring_rule.dart';
import 'package:my_wallet/domain/usecases/recurring_date_calculator.dart';

void main() {
  const calculator = RecurringDateCalculator();

  test('monthly recurrence preserves the anchor day across short months', () {
    final february = calculator.calculateNextDate(
      currentDate: DateTime(2026, 1, 31),
      frequency: RecurringFrequency.monthly,
      anchorDay: 31,
    );
    final march = calculator.calculateNextDate(
      currentDate: february,
      frequency: RecurringFrequency.monthly,
      anchorDay: 31,
    );

    expect(february, DateTime(2026, 2, 28));
    expect(march, DateTime(2026, 3, 31));
  });

  test('yearly recurrence clamps leap day and restores it in leap years', () {
    final nonLeapYear = calculator.calculateNextDate(
      currentDate: DateTime(2024, 2, 29),
      frequency: RecurringFrequency.yearly,
      anchorDay: 29,
    );
    final nextYear = calculator.calculateNextDate(
      currentDate: nonLeapYear,
      frequency: RecurringFrequency.yearly,
      anchorDay: 29,
    );
    final followingLeapYear = calculator.calculateNextDate(
      currentDate: DateTime(2027, 2, 28),
      frequency: RecurringFrequency.yearly,
      anchorDay: 29,
    );

    expect(nonLeapYear, DateTime(2025, 2, 28));
    expect(nextYear, DateTime(2026, 2, 28));
    expect(followingLeapYear, DateTime(2028, 2, 29));
  });

  test('daily and weekly dates advance by calendar days', () {
    expect(
      calculator.calculateNextDate(
        currentDate: DateTime(2026, 6, 10),
        frequency: RecurringFrequency.daily,
        anchorDay: 10,
      ),
      DateTime(2026, 6, 11),
    );
    expect(
      calculator.calculateNextDate(
        currentDate: DateTime(2026, 6, 8),
        frequency: RecurringFrequency.weekly,
        anchorDay: 8,
      ),
      DateTime(2026, 6, 15),
    );
  });
}
