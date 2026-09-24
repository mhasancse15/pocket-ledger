/// Core utilities and constants
class AppConstants {
  // Currency
  static const String defaultCurrency = '৳';
  static const String currencyCode = 'BDT';

  // Validation
  static const int maxNoteLength = 250;
  static const double minAmount = 0.01;

  // Date format
  static const String dateFormat = 'yyyy-MM-dd';
  static const String dateTimeFormat = 'yyyy-MM-dd HH:mm:ss';

  // Payment methods
  static const List<String> paymentMethods = [
    'Cash',
    'Bank Transfer',
    'Debit Card',
    'Credit Card',
    'Mobile Wallet',
    'Other',
  ];

  // Categories (predefined)
  static const List<String> expenseCategories = [
    'Food',
    'Transport',
    'Shopping',
    'Bills',
    'Health',
    'Entertainment',
    'Education',
    'Mobile/Internet',
    'House Rent',
    'Fatema Salary',
    'Bike Oil',
    'Baby Medicine',
    'Baby Food',
    'Monthly Bazaar',
    'Daliy Bazaar',
    'Baby Food',
    'Baby Milk',
    'Other',
  ];

  static const List<String> incomeCategories = [
    'Salary',
    'Freelance',
    'Bonus',
    'Investment',
    'Refund',
    'Gift',
    'Other',
  ];

  // Recurring frequencies
  static const List<String> frequencies = [
    'Weekly',
    'Monthly',
    'Quarterly',
    'Yearly',
  ];

  // App settings
  static const String appName = 'Pocket Ledger';
  static const String appVersion = '1.0.0';
}

/// Utility functions for common operations
class AppUtils {
  /// Format double as currency
  static String formatCurrency(double amount, {String symbol = '৳'}) {
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  /// Parse currency string to double
  static double parseCurrency(String value) {
    return double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
  }

  /// Format date to string
  static String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get month name
  static String getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  /// Get day name
  static String getDayName(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }

  /// Check if two dates are same day
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  /// Get start of month
  static DateTime getStartOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// Get end of month
  static DateTime getEndOfMonth(DateTime date) {
    final firstDayNextMonth = DateTime(date.year, date.month + 1, 1);
    return firstDayNextMonth.subtract(const Duration(days: 1));
  }

  /// Get previous month
  static DateTime getPreviousMonth(DateTime date) {
    if (date.month == 1) {
      return DateTime(date.year - 1, 12, 1);
    }
    return DateTime(date.year, date.month - 1, 1);
  }

  /// Get next month
  static DateTime getNextMonth(DateTime date) {
    if (date.month == 12) {
      return DateTime(date.year + 1, 1, 1);
    }
    return DateTime(date.year, date.month + 1, 1);
  }

  /// Calculate difference between two months
  static int getMonthsDifference(DateTime from, DateTime to) {
    return (to.year - from.year) * 12 + (to.month - from.month);
  }

  /// Validate amount
  static bool isValidAmount(double amount) {
    return amount > 0;
  }

  /// Validate note length
  static bool isValidNote(String? note) {
    if (note == null) return true;
    return note.length <= AppConstants.maxNoteLength;
  }

  /// Get budget status percentage
  static double getBudgetPercentage(double spent, double limit) {
    if (limit <= 0) return 0;
    return (spent / limit) * 100;
  }

  /// Generate unique ID
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}
