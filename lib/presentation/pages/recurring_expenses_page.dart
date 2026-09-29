import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/routes/app_router.dart';
import '../../core/utils/constants.dart';
import '../../domain/entities/recurring_rule.dart';
import '../providers/category_provider.dart';
import '../providers/recurring_provider.dart';
import '../widgets/empty_view.dart';
import '../widgets/error_view.dart';
import '../widgets/financial_summary_card.dart';

enum _RuleFilter { all, active, paused }

class RecurringExpensesPage extends ConsumerStatefulWidget {
  const RecurringExpensesPage({super.key});

  @override
  ConsumerState<RecurringExpensesPage> createState() =>
      _RecurringExpensesPageState();
}

class _RecurringExpensesPageState extends ConsumerState<RecurringExpensesPage> {
  _RuleFilter _filter = _RuleFilter.all;

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(watchAllRecurringRulesProvider);
    final categories = ref.watch(allCategoriesProvider).valueOrNull ?? const [];
    final categoryNames = {for (final item in categories) item.id: item.name};

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring expenses')),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.pushNamed(AppRoutes.recurringExpenseCreateName),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add recurring'),
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            ErrorView(message: 'Unable to load recurring expenses\n$error'),
        data: (rules) {
          final activeRules = rules.where((rule) => rule.isActive).toList();
          final now = DateTime.now();
          final monthlyTotal = activeRules.fold<double>(
            0,
            (sum, rule) => sum + _monthlyEquivalent(rule),
          );
          final dueThisMonth = activeRules.where((rule) {
            final next = rule.nextOccurrenceDate.toLocal();
            return next.year == now.year && next.month == now.month;
          }).length;
          final visibleRules =
              rules.where((rule) {
                return switch (_filter) {
                  _RuleFilter.all => true,
                  _RuleFilter.active => rule.isActive,
                  _RuleFilter.paused => !rule.isActive,
                };
              }).toList()..sort((first, second) {
                if (first.isActive != second.isActive) {
                  return first.isActive ? -1 : 1;
                }
                return first.nextOccurrenceDate.compareTo(
                  second.nextOccurrenceDate,
                );
              });

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
            children: [
              FinancialSummaryCard(
                label: 'Estimated monthly total',
                amount: monthlyTotal,
                metrics: [
                  FinancialSummaryMetric(
                    label: 'Active rules',
                    value: '${activeRules.length}',
                    icon: Icons.repeat,
                  ),
                  FinancialSummaryMetric(
                    label: 'Due this month',
                    value: '$dueThisMonth',
                    icon: Icons.event_available_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'SHOW RULES',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .7,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filterChip(
                    filter: _RuleFilter.all,
                    label: 'All',
                    count: rules.length,
                    icon: Icons.grid_view_rounded,
                  ),
                  _filterChip(
                    filter: _RuleFilter.active,
                    label: 'Active',
                    count: activeRules.length,
                    icon: Icons.check_circle_outline_rounded,
                  ),
                  _filterChip(
                    filter: _RuleFilter.paused,
                    label: 'Paused',
                    count: rules.length - activeRules.length,
                    icon: Icons.pause_circle_outline_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recurring rules',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '${visibleRules.length} ${visibleRules.length == 1 ? 'rule' : 'rules'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (visibleRules.isEmpty)
                EmptyView(
                  icon: Icons.repeat_outlined,
                  title: rules.isEmpty
                      ? 'No recurring expenses'
                      : 'No ${_filter.name} rules',
                  message: rules.isEmpty
                      ? 'Add subscriptions and regular bills to keep them on schedule.'
                      : 'Change the filter to see other recurring expenses.',
                )
              else
                for (final rule in visibleRules)
                  _RuleCard(
                    rule: rule,
                    categoryName:
                        categoryNames[rule.categoryId] ?? rule.categoryId,
                    onTap: () => context.pushNamed(
                      AppRoutes.recurringExpenseDetailsName,
                      pathParameters: {'id': rule.id},
                    ),
                    onMenu: (action) => _handleRuleAction(rule, action),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterChip({
    required _RuleFilter filter,
    required String label,
    required int count,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final selected = _filter == filter;
    final foreground = selected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() => _filter = filter),
      avatar: Icon(icon, size: 17, color: foreground),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.onPrimaryContainer.withValues(alpha: .12)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      selectedColor: theme.colorScheme.primaryContainer,
      backgroundColor: theme.colorScheme.surface,
      side: BorderSide(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: .35)
            : theme.colorScheme.outlineVariant,
      ),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        color: foreground,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  Future<void> _handleRuleAction(RecurringRule rule, _RuleAction action) async {
    if (!mounted) return;
    try {
      switch (action) {
        case _RuleAction.details:
          await context.pushNamed(
            AppRoutes.recurringExpenseDetailsName,
            pathParameters: {'id': rule.id},
          );
        case _RuleAction.edit:
          await context.pushNamed(
            AppRoutes.recurringExpenseEditName,
            pathParameters: {'id': rule.id},
          );
        case _RuleAction.generate:
          final generated = await ref
              .read(recurringProcessorControllerProvider)
              .generateNow(rule.id);
          _message(
            generated
                ? 'Recurring expense generated.'
                : 'This occurrence has already been processed.',
          );
        case _RuleAction.pause:
        case _RuleAction.resume:
          await ref
              .read(recurringNotifierProvider.notifier)
              .setActive(rule.id, action == _RuleAction.resume);
        case _RuleAction.delete:
          final confirmed = await _confirmDelete(rule);
          if (!confirmed || !mounted) return;
          await ref
              .read(recurringNotifierProvider.notifier)
              .deleteRecurringRule(rule.id);
      }
    } catch (error) {
      if (mounted) _message('Unable to update recurring rule: $error');
    }
  }

  Future<bool> _confirmDelete(RecurringRule rule) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete recurring rule?'),
            content: Text(
              'Delete "${rule.title}"? Previously generated transactions will not be deleted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value), behavior: SnackBarBehavior.floating),
    );
  }

  double _monthlyEquivalent(RecurringRule rule) => switch (rule.frequency) {
    RecurringFrequency.daily => rule.amount * (365.2425 / 12),
    RecurringFrequency.weekly => rule.amount * (52.1775 / 12),
    RecurringFrequency.monthly => rule.amount,
    RecurringFrequency.quarterly => rule.amount / 3,
    RecurringFrequency.yearly => rule.amount / 12,
  };
}

enum _RuleAction { details, edit, generate, pause, resume, delete }

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    required this.categoryName,
    required this.onTap,
    required this.onMenu,
  });

  final RecurringRule rule;
  final String categoryName;
  final VoidCallback onTap;
  final ValueChanged<_RuleAction> onMenu;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context);
    final frequency = switch (rule.frequency) {
      RecurringFrequency.daily => 'Daily',
      RecurringFrequency.weekly => 'Weekly',
      RecurringFrequency.monthly => 'Monthly',
      RecurringFrequency.quarterly => 'Every 3 months',
      RecurringFrequency.yearly => 'Yearly',
    };
    final nextDate = DateFormat('d MMMM')
        .format(rule.nextOccurrenceDate.toLocal());

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.fromLTRB(14, 5, 4, 5),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          child: Icon(Icons.repeat, color: color),
        ),
        title: Text(
          rule.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '$frequency • Next: $nextDate\n$categoryName • ${rule.isActive ? _statusLabel() : 'Paused'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppUtils.formatCurrency(rule.amount),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            PopupMenuButton<_RuleAction>(
              tooltip: 'Rule actions',
              onSelected: onMenu,
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: _RuleAction.details,
                  child: Text('View details'),
                ),
                const PopupMenuItem(
                  value: _RuleAction.edit,
                  child: Text('Edit rule'),
                ),
                if (rule.isActive)
                  const PopupMenuItem(
                    value: _RuleAction.generate,
                    child: Text('Generate expense now'),
                  ),
                PopupMenuItem(
                  value: rule.isActive ? _RuleAction.pause : _RuleAction.resume,
                  child: Text(rule.isActive ? 'Pause rule' : 'Resume rule'),
                ),
                const PopupMenuItem(
                  value: _RuleAction.delete,
                  child: Text('Delete rule'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(BuildContext context) {
    if (!rule.isActive) return Theme.of(context).colorScheme.outline;
    final today = DateTime.now();
    final due = DateTime(
      rule.nextOccurrenceDate.toLocal().year,
      rule.nextOccurrenceDate.toLocal().month,
      rule.nextOccurrenceDate.toLocal().day,
    );
    final days = due
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    if (days < 0) return Theme.of(context).colorScheme.error;
    if (days <= 3) return Colors.deepOrange;
    return Colors.green;
  }

  String _statusLabel() {
    final today = DateTime.now();
    final due = rule.nextOccurrenceDate.toLocal();
    final days = DateTime(
      due.year,
      due.month,
      due.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
    if (days < 0) return 'Overdue';
    if (days <= 3) return 'Due soon';
    return 'Active';
  }
}
