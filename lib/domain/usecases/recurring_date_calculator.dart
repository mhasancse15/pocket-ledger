import '../entities/recurring_rule.dart';

class RecurringDateCalculator {
  const RecurringDateCalculator();

  DateTime calculateNextDate({
    required DateTime currentDate,
    required RecurringFrequency frequency,
    required int anchorDay,
  }) {
    return switch (frequency) {
      RecurringFrequency.daily => _date(
        currentDate.year,
        currentDate.month,
        currentDate.day + 1,
      ),
      RecurringFrequency.weekly => _date(
        currentDate.year,
        currentDate.month,
        currentDate.day + 7,
      ),
      RecurringFrequency.monthly => _anchoredMonth(
        currentDate,
        monthsToAdd: 1,
        anchorDay: anchorDay,
      ),
      RecurringFrequency.quarterly => _anchoredMonth(
        currentDate,
        monthsToAdd: 3,
        anchorDay: anchorDay,
      ),
      RecurringFrequency.yearly => _anchoredMonth(
        currentDate,
        monthsToAdd: 12,
        anchorDay: anchorDay,
      ),
    };
  }

  DateTime _anchoredMonth(
    DateTime currentDate, {
    required int monthsToAdd,
    required int anchorDay,
  }) {
    final month = currentDate.month + monthsToAdd;
    final firstOfMonth = DateTime(currentDate.year, month);
    final lastDay = DateTime(firstOfMonth.year, firstOfMonth.month + 1, 0).day;
    return DateTime(
      firstOfMonth.year,
      firstOfMonth.month,
      anchorDay.clamp(1, lastDay).toInt(),
    );
  }

  DateTime _date(int year, int month, int day) => DateTime(year, month, day);
}
