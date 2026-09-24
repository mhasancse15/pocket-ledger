part of 'app_router.dart';

/// Route paths for the app
class AppRoutes {
  // Private constructor to prevent instantiation
  AppRoutes._();

  // Route paths
  static const String dashboard = '/';
  static const String addTransaction = '/add-transaction';
  static const String editTransaction = '/edit-transaction/:id';
  static const String transactions = '/transactions';
  static const String monthlyHistory = '/monthly-history';
  static const String reports = '/reports';
  static const String categories = '/categories';
  static const String settings = '/settings';
  static const String recurringExpenses = '/recurring-expenses';
  static const String  previousExpanse = '/previous-expenses';
}
