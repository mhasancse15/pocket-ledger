import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/pages/add_transaction_page.dart';
import '../../presentation/pages/budget_page.dart';
import '../../presentation/pages/commercial_pages.dart';
import '../../presentation/pages/dashboard_page.dart';
import '../../presentation/pages/edit_transaction_page.dart';
import '../../presentation/pages/previous_month_summary_page.dart';
import '../../presentation/pages/report_page.dart';
import '../../presentation/pages/setting_page.dart';
import '../../presentation/pages/transactions_page.dart';
import '../../presentation/pages/transaction_details_page.dart';


part 'app_routes.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.dashboard,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                name: AppRoutes.dashboardName,
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.transactions,
                name: AppRoutes.transactionsName,
                builder: (context, state) => const TransactionsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reports,
                name: AppRoutes.reportsName,
                builder: (context, state) => const ReportsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                name: AppRoutes.settingsName,
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.addTransaction,
        name: AppRoutes.addTransactionName,
        builder: (context, state) => const AddTransactionPage(),
      ),
      GoRoute(
        path: AppRoutes.editTransaction,
        name: AppRoutes.editTransactionName,
        builder: (context, state) => EditTransactionPage(
          transactionId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.transactionDetails,
        name: AppRoutes.transactionDetailsName,
        builder: (context, state) => TransactionDetailsPage(
          transactionId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.monthlyHistory,
        name: AppRoutes.monthlyHistoryName,
        builder: (context, state) => const MonthlyHistoryPage(),
      ),
      GoRoute(
        path: AppRoutes.categories,
        name: AppRoutes.categoriesName,
        builder: (context, state) => const CategoriesPage(),
      ),
      GoRoute(
        path: AppRoutes.recurringExpenses,
        name: AppRoutes.recurringExpensesName,
        builder: (context, state) => const RecurringExpensesPage(),
      ),
      GoRoute(
        path: AppRoutes.previousExpanse,
        name: AppRoutes.previousExpanseName,
        builder: (context, state) => const PreviousMonthSummaryPage(),
      ),
      GoRoute(
        path: AppRoutes.budgets,
        name: AppRoutes.budgetsName,
        builder: (context, state) => const BudgetPage(),
      ),
    ],
    errorBuilder: (context, state) => const Scaffold(
      body: Center(child: Text('Page not found')),
    ),
  );
}

class AppShell extends StatelessWidget {
  const AppShell({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  void _onTabSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTabSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
