/// Extension methods for DateTime
extension DateTimeExt on DateTime {
  DateTime get startOfDay => DateTime(year, month, day);

  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59);

  DateTime get startOfMonth => DateTime(year, month, 1);

  DateTime get endOfMonth {
    final firstDayNextMonth = DateTime(year, month + 1, 1);
    return firstDayNextMonth.subtract(const Duration(days: 1));
  }

  DateTime get startOfYear => DateTime(year, 1, 1);

  DateTime previousMonth() {
    if (month == 1) {
      return DateTime(year - 1, 12, 1);
    }
    return DateTime(year, month - 1, 1);
  }

  bool isSameDay(DateTime other) {
    return year == other.year && month == other.month && day == other.day;
  }

  bool isSameMonth(DateTime other) {
    return year == other.year && month == other.month;
  }
}

extension DoubleExt on double {
  String toFormattedCurrency({String symbol = '৳'}) {
    return '$symbol${toStringAsFixed(2)}';
  }
}
