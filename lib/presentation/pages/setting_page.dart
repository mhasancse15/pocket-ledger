import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/routes/app_router.dart';
import '../providers/category_provider.dart';
import '../providers/database_provider.dart';
import '../providers/limit_provider.dart';
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
                icon: Icons.repeat_outlined,
                title: 'Recurring expenses',
                subtitle: 'Manage subscriptions and recurring bills',
                onTap: () => context.pushNamed(
                  AppRoutes.recurringExpensesName,
                ),
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
                onTap: () => _comingSoon(context, 'Export data'),
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

Future<void> _clearLocalDatabase(
    BuildContext context,
    WidgetRef ref,
    ) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Clear local database?'),
        content: const Text(
          'All transactions, categories, recurring expenses, '
              'payment methods, and monthly limits will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
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
    await ref.read(databaseProvider).clearAllData();

    ref.invalidate(allTransactionsProvider);
    ref.invalidate(allCategoriesProvider);
    ref.invalidate(allRecurringRulesProvider);
    ref.invalidate(allLimitsProvider);
    ref.invalidate(monthlyLimitProvider);

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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall,
          ),
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
