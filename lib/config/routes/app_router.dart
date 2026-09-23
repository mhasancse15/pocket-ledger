import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/pages/add_transaction_page.dart';
import '../../presentation/pages/dashboard_page.dart';
import '../../presentation/pages/edit_transaction_page.dart';
import '../../presentation/pages/placeholder_pages.dart';
import '../../presentation/pages/transactions_page.dart';


part 'app_routes.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.dashboard,
    routes: [
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: AppRoutes.addTransaction,
        name: 'addTransaction',
        builder: (context, state) => const AddTransactionPage(),
      ),
      GoRoute(
        path: AppRoutes.editTransaction,
        name: 'editTransaction',
        builder: (context, state) {
          final transactionId = state.pathParameters['id'];
          return EditTransactionPage(transactionId: transactionId ?? '');
        },
      ),
      GoRoute(
        path: AppRoutes.transactions,
        name: 'transactions',
        builder: (context, state) => const TransactionsPage(),
      ),
      GoRoute(
        path: AppRoutes.monthlyHistory,
        name: 'monthlyHistory',
        builder: (context, state) => const MonthlyHistoryPage(),
      ),
      GoRoute(
        path: AppRoutes.reports,
        name: 'reports',
        builder: (context, state) => const ReportsPage(),
      ),
      GoRoute(
        path: AppRoutes.categories,
        name: 'categories',
        builder: (context, state) => const CategoriesPage(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.recurringExpenses,
        name: 'recurringExpenses',
        builder: (context, state) => const RecurringExpensesPage(),
      ),
    ],
    errorBuilder: (context, state) => const Scaffold(
      body: Center(child: Text('Page not found')),
    ),
  );
}
