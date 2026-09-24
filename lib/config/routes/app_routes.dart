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
  static const String previousExpanse = '/previous-expenses';

  static const String dashboardName = 'dashboard';
  static const String transactionsName = 'transactions';
  static const String reportsName = 'reports';
  static const String settingsName = 'settings';
  static const String addTransactionName = 'addTransaction';
  static const String editTransactionName = 'editTransaction';
  static const String monthlyHistoryName = 'monthlyHistory';
  static const String categoriesName = 'categories';
  static const String recurringExpensesName = 'recurringExpenses';
  static const String previousExpanseName = 'previousExpanse';
  static const String transactionDetails = '/transaction/:id';
  static const String transactionDetailsName = 'transactionDetails';
}
