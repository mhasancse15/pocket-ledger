import 'dart:ui';

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
        backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: .82),
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: IgnorePointer(child: _SettingsAmbient())),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 112),
            children: [
              _SettingsBrandCard(theme: theme),
              const SizedBox(height: 20),
              _SettingsSection(
                title: 'Appearance',
                subtitle: 'Personalize the app experience',
                children: [
                  _SettingsSwitchTile(
                    icon: Icons.dark_mode_outlined,
                    title: 'Dark theme',
                    subtitle: 'Use a darker appearance',
                    value: darkMode,
                    onChanged: (value) {
                      ref
                          .read(preferencesNotifierProvider.notifier)
                          .setDarkMode(value);
                    },
                  ),
                  const Divider(height: 24),
                  const _SettingsValueTile(
                    icon: Icons.swap_horiz,
                    title: 'Currency',
                    subtitle: 'Bangladeshi Taka',
                    value: '৳ BDT',
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
                  const Divider(height: 1, indent: 56),
                  _SettingsTile(
                    icon: Icons.track_changes_outlined,
                    title: 'Budgets',
                    subtitle: 'Monthly, category, and wallet budgets',
                    onTap: () => context.pushNamed(AppRoutes.budgetsName),
                  ),
                  const Divider(height: 1, indent: 56),
                  _SettingsTile(
                    icon: Icons.repeat_outlined,
                    title: 'Recurring expenses',
                    subtitle: 'Manage subscriptions and recurring bills',
                    onTap: () =>
                        context.pushNamed(AppRoutes.recurringExpensesName),
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
                  const Divider(height: 1, indent: 56),
                  _SettingsTile(
                    icon: Icons.backup_outlined,
                    title: 'Backup and restore',
                    subtitle: 'Protect your local expense data',
                    onTap: () => _comingSoon(context, 'Backup and restore'),
                  ),
                  const Divider(height: 1, indent: 56),
                  _SettingsTile(
                    icon: Icons.delete_forever_outlined,
                    title: 'Clear local database',
                    subtitle: 'Delete all transactions and app data',
                    onTap: () => _clearLocalDatabase(context, ref),
                    destructive: true,
                  ),
                ],
              ),
              _SettingsSection(
                title: 'Notifications',
                subtitle: 'Get alerts as you approach spending limits',
                children: [
                  _SettingsSwitchTile(
                    icon: Icons.pie_chart_outline,
                    title: 'Budget notifications',
                    subtitle: 'Alerts at 75%, 90%, and when a budget is reached or exceeded',
                    value: budgetNotificationsEnabled,
                    onChanged: (enabled) => _setNotificationPreference(
                      context,
                      ref,
                      enabled: enabled,
                      isMonthlyTarget: false,
                    ),
                  ),
                  const Divider(height: 24),
                  _SettingsSwitchTile(
                    icon: Icons.adjust_outlined,
                    title: 'Monthly target notifications',
                    subtitle:
                        'Get alerts as spending approaches your monthly target',
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
              const _SettingsFooter(),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 9),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(
                alpha: isDark ? .94 : .82,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? theme.colorScheme.outlineVariant.withValues(alpha: .42)
                    : Colors.white.withValues(alpha: .72),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? .14 : .045),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(children: children),
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
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            _SettingsIconBadge(
              icon: icon,
              foregroundColor: color,
              backgroundColor: destructive
                  ? theme.colorScheme.errorContainer.withValues(alpha: .55)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: destructive ? color : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: color.withValues(alpha: .8)),
          ],
        ),
      ),
    );
  }
}

class _SettingsAmbient extends StatelessWidget {
  const _SettingsAmbient();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 30,
          right: -80,
          child: _SettingsGlowOrb(colors.primary.withValues(alpha: .17), 250),
        ),
        Positioned(
          top: 360,
          left: -100,
          child: _SettingsGlowOrb(colors.secondary.withValues(alpha: .12), 280),
        ),
        Positioned(
          top: 760,
          right: -90,
          child: _SettingsGlowOrb(colors.tertiary.withValues(alpha: .10), 260),
        ),
      ],
    );
  }
}

class _SettingsGlowOrb extends StatelessWidget {
  const _SettingsGlowOrb(this.color, this.size);

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 54, sigmaY: 54),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _SettingsBrandCard extends StatelessWidget {
  const _SettingsBrandCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.secondary, .62)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: .22),
            blurRadius: 24,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -46,
            child: _BrandRing(
              size: 150,
              color: Colors.white.withValues(alpha: .14),
            ),
          ),
          Positioned(
            right: 24,
            top: -24,
            child: _BrandRing(
              size: 112,
              color: Colors.white.withValues(alpha: .12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .35),
                    ),
                  ),
                  child: const Icon(
                    Icons.settings_outlined,
                    color: Colors.white,
                    size: 29,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pocket Ledger',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Customize your finance tracker',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: .82),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandRing extends StatelessWidget {
  const _BrandRing({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color),
        ),
      ),
    );
  }
}

class _SettingsIconBadge extends StatelessWidget {
  const _SettingsIconBadge({
    required this.icon,
    this.foregroundColor,
    this.backgroundColor,
  });

  final IconData icon;
  final Color? foregroundColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            scheme.surfaceContainerLow.withValues(alpha: .86),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: foregroundColor ?? scheme.onSurface, size: 21),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$title. $subtitle',
      toggled: value,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _SettingsIconBadge(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsValueTile extends StatelessWidget {
  const _SettingsValueTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _SettingsIconBadge(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: .58),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              value,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _SettingsFooter extends StatelessWidget {
  const _SettingsFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: scheme.primary,
                size: 18,
              ),
              const SizedBox(width: 7),
              Text(
                'Pocket Ledger',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow.withValues(alpha: .8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Local-first • Your data stays on this device',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Pocket Ledger',
            ),
            child: const Text('Open source licenses'),
          ),
          Text(
            '© ${DateTime.now().year} Pocket Ledger',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: .72),
            ),
          ),
        ],
      ),
    );
  }
}
