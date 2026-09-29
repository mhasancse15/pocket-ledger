import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/routes/app_router.dart';
import '../../core/services/local_notification_service.dart';
import '../providers/budget_notification_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/database_provider.dart';
import '../providers/limit_provider.dart';
import '../providers/monthly_saving_provider.dart';
import '../providers/preferences_provider.dart';
import '../providers/recurring_provider.dart';
import '../providers/transaction_provider.dart';

/// Commercial-style settings page. Page name unchanged.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final preferences = ref.watch(preferencesNotifierProvider);
    final darkMode = preferences['isDarkMode'] as bool? ?? false;
    final budgetNotificationsEnabled =
        preferences['budgetNotificationsEnabled'] as bool? ?? false;
    final monthlyTargetNotificationsEnabled =
        preferences['monthlyTargetNotificationsEnabled'] as bool? ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withOpacity(0.72),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: Colors.white24,
                  child: Icon(
                    Icons.settings_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pocket Ledger',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Customize your finance tracker',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SettingsSection(
            title: 'Appearance',
            subtitle: 'Personalize the app experience',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Dark theme'),
                subtitle: const Text('Use a darker appearance'),
                value: darkMode,
                onChanged: (value) {
                  ref
                      .read(preferencesNotifierProvider.notifier)
                      .setDarkMode(value);
                },
              ),
              const Divider(height: 24),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.currency_exchange),
                title: Text('Currency'),
                subtitle: Text('Bangladeshi Taka'),
                trailing: Text(
                  '৳ BDT',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Manage',
            subtitle: 'Configure your finance tracking options',
            children: [
              _SettingsTile(
                icon: Icons.category_outlined,
                title: 'Categories',
                subtitle: 'Manage income and expense categories',
                onTap: () => context.push(AppRoutes.categories),
              ),
              _SettingsTile(
                icon: Icons.track_changes_outlined,
                title: 'Budgets',
                subtitle: 'Monthly, category, and wallet budgets',
                onTap: () => context.pushNamed(AppRoutes.budgetsName),
              ),
              _SettingsTile(
                icon: Icons.repeat_outlined,
                title: 'Recurring expenses',
                subtitle: 'Manage subscriptions and recurring bills',
                onTap: () => context.pushNamed(AppRoutes.recurringExpensesName),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Dashboard',
            subtitle: 'Choose which sections appear on your dashboard',
            children: [
              _SettingsTile(
                icon: Icons.dashboard_customize_outlined,
                title: 'Customize dashboard',
                subtitle: 'Choose which sections are shown',
                onTap: () => _showDashboardSections(context, ref),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Data',
            subtitle: 'Protect and manage your finance data',
            children: [
              _SettingsTile(
                icon: Icons.file_download_outlined,
                title: 'Export data',
                subtitle: 'Export transactions as CSV or PDF',
                onTap: () => context.pushNamed(AppRoutes.exportDataName),
              ),
              _SettingsTile(
                icon: Icons.backup_outlined,
                title: 'Backup and restore',
                subtitle: 'Protect your local expense data',
                onTap: () => _comingSoon(context, 'Backup and restore'),
              ),
              _SettingsTile(
                icon: Icons.delete_forever_outlined,
                title: 'Clear local database',
                subtitle: 'Delete all transactions and app data',
                onTap: () => _clearLocalDatabase(context, ref),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Notifications',
            subtitle: 'Get alerts as you approach spending limits',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.pie_chart_outline),
                title: const Text('Budget notifications'),
                subtitle: const Text(
                  'Alerts at 75%, 90%, and when a budget is reached or exceeded',
                ),
                value: budgetNotificationsEnabled,
                onChanged: (enabled) => _setNotificationPreference(
                  context,
                  ref,
                  enabled: enabled,
                  isMonthlyTarget: false,
                ),
              ),
              const Divider(height: 24),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.track_changes_outlined),
                title: const Text('Monthly target notifications'),
                subtitle: const Text(
                  'Get alerts as spending approaches your monthly target',
                ),
                value: monthlyTargetNotificationsEnabled,
                onChanged: (enabled) => _setNotificationPreference(
                  context,
                  ref,
                  enabled: enabled,
                  isMonthlyTarget: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature will be available soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

Future<void> _showDashboardSections(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => _DashboardSectionsSheet(
      onChanged: (section, visible) =>
          _setDashboardSectionVisibility(sheetContext, ref, section, visible),
    ),
  );
}

class _DashboardSectionsSheet extends ConsumerWidget {
  const _DashboardSectionsSheet({required this.onChanged});

  final Future<void> Function(DashboardSection section, bool visible) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesNotifierProvider);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Text(
                'Dashboard sections',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            for (final section in DashboardSection.values)
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(section.label),
                value: preferences[section.preferenceKey] as bool? ?? true,
                onChanged: (visible) => onChanged(section, visible),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _setDashboardSectionVisibility(
  BuildContext context,
  WidgetRef ref,
  DashboardSection section,
  bool visible,
) async {
  try {
    await ref
        .read(preferencesNotifierProvider.notifier)
        .setDashboardSectionVisible(section, visible);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unable to update dashboard: $error'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

Future<void> _setNotificationPreference(
  BuildContext context,
  WidgetRef ref, {
  required bool enabled,
  required bool isMonthlyTarget,
}) async {
  if (enabled) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enable spending alerts?'),
        content: const Text(
          'Pocket Ledger can notify you when spending reaches 75%, 90%, '
          'or 100% of a budget or monthly target.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final bool permissionGranted;
    try {
      permissionGranted = await LocalNotificationService.instance
          .requestPermission();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to request notification permission: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!context.mounted) return;
    if (!permissionGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification permission was not granted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
  }

  try {
    final notifier = ref.read(preferencesNotifierProvider.notifier);
    if (isMonthlyTarget) {
      await notifier.setMonthlyTargetNotificationsEnabled(enabled);
    } else {
      await notifier.setBudgetNotificationsEnabled(enabled);
    }
    if (enabled) await reportWidgetBudgetNotificationCheck(ref);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unable to update notification settings: $error'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

Future<void> _clearLocalDatabase(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Clear local database?'),
        content: const Text(
          'All transactions, categories, recurring expenses, '
          'budgets, monthly savings, payment methods, and monthly limits '
          'will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Clear everything'),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final recurringRules = await ref
        .read(recurringRepositoryProvider)
        .getAllRules();
    for (final rule in recurringRules) {
      await LocalNotificationService.instance.cancelRecurringReminder(
        rule.id,
        notificationId: rule.notificationId,
      );
    }
    await ref.read(databaseProvider).clearAllData();

    ref.invalidate(allTransactionsProvider);
    ref.invalidate(monthlyTransactionsProvider);
    ref.invalidate(monthlyTotalProvider);
    ref.invalidate(allCategoriesProvider);
    ref.invalidate(categoriesByTypeProvider);
    ref.invalidate(allRecurringRulesProvider);
    ref.invalidate(activeRecurringRulesProvider);
    ref.invalidate(watchAllRecurringRulesProvider);
    ref.invalidate(recurringMonthlyTotalProvider);
    ref.invalidate(allLimitsProvider);
    ref.invalidate(monthlyLimitProvider);
    ref.invalidate(budgetsProvider);
    ref.invalidate(monthlySavingEntriesProvider);
    ref.invalidate(allMonthlySavingEntriesProvider);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Local database cleared successfully'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (error) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unable to clear database: $error'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 3),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              child: Column(children: children),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
