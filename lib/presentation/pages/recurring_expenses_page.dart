import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/routes/app_router.dart';
import '../../core/utils/constants.dart';
import '../../domain/entities/recurring_rule.dart';
import '../../domain/usecases/recurring_date_calculator.dart';
import '../providers/category_provider.dart';
import '../providers/recurring_provider.dart';
import '../widgets/error_view.dart';

enum _RuleFilter { all, active, paused }

enum _RuleSort { dueDate, amount, name }

const _brandIndigo = Color(0xFF4338CA);

class RecurringExpensesPage extends ConsumerStatefulWidget {
  const RecurringExpensesPage({super.key});

  @override
  ConsumerState<RecurringExpensesPage> createState() =>
      _RecurringExpensesPageState();
}

class _RecurringExpensesPageState extends ConsumerState<RecurringExpensesPage> {
  static const _dateCalculator = RecurringDateCalculator();
  _RuleFilter _filter = _RuleFilter.all;
  _RuleSort _sort = _RuleSort.dueDate;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rulesAsync = ref.watch(watchAllRecurringRulesProvider);
    final categories = ref.watch(allCategoriesProvider).valueOrNull ?? const [];
    final categoryNames = {for (final item in categories) item.id: item.name};

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: .76),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recurring expenses',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -.55,
              ),
            ),
            Row(
              children: [
                Text(
                  'Pocket Ledger',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Icon(
                    Icons.circle,
                    size: 4,
                    color: theme.colorScheme.outline,
                  ),
                ),
                Text(
                  'Subscriptions & Bills',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _AddRecurringButton(
        onPressed: () =>
            context.pushNamed(AppRoutes.recurringExpenseCreateName),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _RecurringBackdrop()),
          rulesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                ErrorView(message: 'Unable to load recurring expenses\n$error'),
            data: (rules) => _buildContent(
              context,
              rules: rules,
              categoryNames: categoryNames,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required List<RecurringRule> rules,
    required Map<String, String> categoryNames,
  }) {
    final activeRules = rules.where((rule) => rule.isActive).toList();
    final monthlyTotal = activeRules.fold<double>(
      0,
      (sum, rule) => sum + _monthlyEquivalent(rule),
    );
    final dueThisMonth = <(DateTime, RecurringRule)>[
      for (final rule in activeRules)
        for (final date in _occurrencesInMonth(rule, _month)) (date, rule),
    ]..sort((first, second) => first.$1.compareTo(second.$1));
    final dayRules = <DateTime, List<RecurringRule>>{};
    final scheduledDatesByRule = <String, Set<DateTime>>{};
    for (final occurrence in dueThisMonth) {
      final date = occurrence.$1;
      final rule = occurrence.$2;
      dayRules.putIfAbsent(date, () => []).add(rule);
      scheduledDatesByRule.putIfAbsent(rule.id, () => {}).add(date);
    }
    final scheduledDays = dayRules.keys.toList()..sort();

    final filteredRules = rules.where((rule) {
      final passesFilter = switch (_filter) {
        _RuleFilter.all => true,
        _RuleFilter.active => rule.isActive,
        _RuleFilter.paused => !rule.isActive,
      };
      final passesDay =
          _selectedDay == null ||
          (scheduledDatesByRule[rule.id]?.contains(_selectedDay) ?? false);
      return passesFilter && passesDay;
    }).toList()..sort(_compareRules);

    final activeCategoryTotals = <String, double>{};
    for (final rule in activeRules) {
      final categoryName = categoryNames[rule.categoryId] ?? rule.categoryId;
      activeCategoryTotals.update(
        categoryName,
        (amount) => amount + _monthlyEquivalent(rule),
        ifAbsent: () => _monthlyEquivalent(rule),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(watchAllRecurringRulesProvider);
        ref.invalidate(allCategoriesProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 112),
        children: [
          _MonthAndActivityRow(
            month: _month,
            onPrevious: () => _changeMonth(-1),
            onNext: () => _changeMonth(1),
          ),
          const SizedBox(height: 18),
          _DueTimeline(
            month: _month,
            scheduledDays: scheduledDays,
            dayRules: dayRules,
            selectedDay: _selectedDay,
            onDaySelected: (day) =>
                setState(() => _selectedDay = _selectedDay == day ? null : day),
          ),
          const SizedBox(height: 16),
          _RuleFilterBar(
            filter: _filter,
            sort: _sort,
            allCount: rules.length,
            activeCount: activeRules.length,
            pausedCount: rules.length - activeRules.length,
            onFilterChanged: (filter) => setState(() => _filter = filter),
            onSortChanged: (sort) => setState(() => _sort = sort),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recurring rules',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.5,
                  ),
                ),
              ),
              Text(
                '${filteredRules.length} ${filteredRules.length == 1 ? 'rule' : 'rules'} listed',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (filteredRules.isEmpty)
            _RecurringEmptyState(
              hasRules: rules.isNotEmpty,
              selectedDay: _selectedDay,
              onClear: () => setState(() {
                _filter = _RuleFilter.all;
                _selectedDay = null;
              }),
              onAdd: () =>
                  context.pushNamed(AppRoutes.recurringExpenseCreateName),
            )
          else
            for (final rule in filteredRules)
              _RuleCard(
                rule: rule,
                categoryName: categoryNames[rule.categoryId] ?? rule.categoryId,
                onTap: () => _openRuleDetails(rule),
                onMenu: (action) => _handleRuleAction(rule, action),
              ),
          const SizedBox(height: 6),
          _CostDistributionCard(
            totals: activeCategoryTotals,
            monthlyTotal: monthlyTotal,
          ),
          const SizedBox(height: 12),
          _ReminderInfoCard(
            configuredCount: activeRules
                .where((rule) => rule.reminderDays != null)
                .length,
            activeCount: activeRules.length,
          ),
        ],
      ),
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      _month = DateTime(_month.year, _month.month + offset);
      _selectedDay = null;
    });
  }

  int _compareDueDate(RecurringRule first, RecurringRule second) {
    return first.nextOccurrenceDate.compareTo(second.nextOccurrenceDate);
  }

  int _compareRules(RecurringRule first, RecurringRule second) {
    return switch (_sort) {
      _RuleSort.dueDate => _compareDueDate(first, second),
      _RuleSort.amount => second.amount.compareTo(first.amount),
      _RuleSort.name => first.title.toLowerCase().compareTo(
        second.title.toLowerCase(),
      ),
    };
  }

  double _monthlyEquivalent(RecurringRule rule) => switch (rule.frequency) {
    RecurringFrequency.daily => rule.amount * (365.2425 / 12),
    RecurringFrequency.weekly => rule.amount * (52.1775 / 12),
    RecurringFrequency.monthly => rule.amount,
    RecurringFrequency.quarterly => rule.amount / 3,
    RecurringFrequency.yearly => rule.amount / 12,
  };

  Future<void> _openRuleDetails(RecurringRule rule) async {
    await context.pushNamed(
      AppRoutes.recurringExpenseDetailsName,
      pathParameters: {'id': rule.id},
    );
  }

  Future<void> _handleRuleAction(RecurringRule rule, _RuleAction action) async {
    if (!mounted) return;
    try {
      switch (action) {
        case _RuleAction.details:
          await _openRuleDetails(rule);
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

  List<DateTime> _occurrencesInMonth(RecurringRule rule, DateTime month) {
    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1);
    final endDate = rule.endDate == null ? null : _dateOnly(rule.endDate!);
    var occurrence = _dateOnly(rule.nextOccurrenceDate);

    while (occurrence.isBefore(monthStart)) {
      if (endDate != null && occurrence.isAfter(endDate)) return const [];
      occurrence = _dateCalculator.calculateNextDate(
        currentDate: occurrence,
        frequency: rule.frequency,
        anchorDay: rule.anchorDay,
      );
    }

    final dates = <DateTime>[];
    while (occurrence.isBefore(monthEnd) &&
        (endDate == null || !occurrence.isAfter(endDate))) {
      dates.add(occurrence);
      occurrence = _dateCalculator.calculateNextDate(
        currentDate: occurrence,
        frequency: rule.frequency,
        anchorDay: rule.anchorDay,
      );
    }
    return dates;
  }
}

DateTime _dateOnly(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String _frequencyLabel(RecurringRule rule) => switch (rule.frequency) {
  RecurringFrequency.daily => 'Daily',
  RecurringFrequency.weekly => 'Weekly',
  RecurringFrequency.monthly => 'Monthly on ${_ordinal(rule.anchorDay)}',
  RecurringFrequency.quarterly =>
    'Every 3 months on ${_ordinal(rule.anchorDay)}',
  RecurringFrequency.yearly => 'Yearly',
};

String _ordinal(int day) {
  final suffix = switch (day % 100) {
    11 || 12 || 13 => 'th',
    _ => switch (day % 10) {
      1 => 'st',
      2 => 'nd',
      3 => 'rd',
      _ => 'th',
    },
  };
  return '$day$suffix';
}

String _paymentMethodLabel(String value) => switch (value) {
  'cash' => 'Cash',
  'bankTransfer' => 'Bank transfer',
  'debitCard' => 'Debit card',
  'creditCard' => 'Credit card',
  'mobileWallet' => 'Mobile wallet',
  'other' => 'Other',
  _ => value,
};

enum _RuleAction { details, edit, generate, pause, resume, delete }

class _RecurringBackdrop extends StatelessWidget {
  const _RecurringBackdrop();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: dark
                    ? const [
                        Color(0xFF101114),
                        Color(0xFF171522),
                        Color(0xFF101114),
                      ]
                    : const [
                        Color(0xFFFAF8FF),
                        Color(0xFFF1EEFF),
                        Color(0xFFF1F8FC),
                      ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -110,
          right: -110,
          child: _orb(
            dark ? const Color(0xFF5148D7) : const Color(0xFFC3C0FF),
            dark ? .14 : .3,
          ),
        ),
        Positioned(
          top: 330,
          left: -160,
          child: _orb(
            dark ? const Color(0xFF712AE2) : const Color(0xFFD2BBFF),
            dark ? .12 : .25,
          ),
        ),
        Positioned(
          bottom: 60,
          right: -130,
          child: _orb(
            dark ? const Color(0xFF005E40) : const Color(0xFF99F6E4),
            dark ? .1 : .23,
          ),
        ),
      ],
    );
  }

  Widget _orb(Color color, double opacity) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 65, sigmaY: 65),
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          color: color.withValues(alpha: opacity),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _MonthAndActivityRow extends StatelessWidget {
  const _MonthAndActivityRow({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: isDark ? .96 : .88),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? .32 : .42),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: isDark ? .08 : .045),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
          ),
          Expanded(
            child: Center(
              child: Text(
                DateFormat('MMMM yyyy').format(month),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded, size: 28),
          ),
        ],
      ),
    );
  }
}

class RecurringExpensesSummaryCard extends StatelessWidget {
  const RecurringExpensesSummaryCard({
    super.key,
    required this.monthlyTotal,
    required this.activeCount,
    required this.dueRules,
    required this.dueAmount,
    required this.nextDueDate,
    required this.onDetails,
  });

  final double monthlyTotal;
  final int activeCount;
  final List<RecurringRule> dueRules;
  final double dueAmount;
  final DateTime? nextDueDate;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final next = dueRules.isEmpty ? null : dueRules.first;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5146D8), Color(0xFF3924B5), Color(0xFF281787)],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: .22)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: .27),
            blurRadius: 28,
            offset: const Offset(0, 13),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(top: -65, right: -58, child: _HeroRing(size: 190)),
          Positioned(top: -92, right: -86, child: _HeroRing(size: 245)),
          Positioned(
            bottom: -75,
            right: 72,
            child: Container(
              width: 170,
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFF9C63FF).withValues(alpha: .24),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9C63FF).withValues(alpha: .34),
                    blurRadius: 48,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'POCKET LEDGER',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFFD0CEFF),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        'BILLS',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .25),
                        ),
                      ),
                      child: const Icon(
                        Icons.contactless_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                Text(
                  'Estimated monthly total',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFC7C5FF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          AppUtils.formatCurrency(monthlyTotal),
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.1,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '/ month',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: const Color(0xFFC7C5FF)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: .16),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: _HeroMetric(
                        icon: Icons.sync_alt_rounded,
                        label: 'Active rules',
                        value:
                            '$activeCount ${activeCount == 1 ? 'rule' : 'rules'}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _HeroMetric(
                        icon: Icons.event_available_rounded,
                        label: 'Due this month',
                        value: dueRules.isEmpty
                            ? 'None scheduled'
                            : AppUtils.formatCurrency(dueAmount),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: .13),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_outlined,
                      color: Color(0xFF91F0CC),
                      size: 16,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        next == null
                            ? 'No upcoming payments this month'
                            : 'Next: ${next.title} (${AppUtils.formatCurrency(next.amount)}) on ${DateFormat('d MMM').format(nextDueDate!)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: const Color(0xFFD0CEFF),
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                    if (onDetails != null)
                      TextButton(
                        onPressed: onDetails,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          minimumSize: const Size(0, 34),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Details',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroRing extends StatelessWidget {
  const _HeroRing({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: .1)),
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: .14),
          ),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: const Color(0xFFC7C5FF),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DueTimeline extends StatelessWidget {
  const _DueTimeline({
    required this.month,
    required this.scheduledDays,
    required this.dayRules,
    required this.selectedDay,
    required this.onDaySelected,
  });

  final DateTime month;
  final List<DateTime> scheduledDays;
  final Map<DateTime, List<RecurringRule>> dayRules;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${DateFormat('MMMM').format(month)} timeline',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .7,
                ),
              ),
            ),
            Text(
              '${scheduledDays.length} ${scheduledDays.length == 1 ? 'debit' : 'debits'} scheduled',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_forward_rounded, size: 16, color: scheme.primary),
          ],
        ),
        const SizedBox(height: 8),
        if (scheduledDays.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: _glassDecoration(context, radius: 18),
            child: Row(
              children: [
                Icon(
                  Icons.event_available_outlined,
                  size: 19,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'No active payments scheduled for ${DateFormat('MMMM').format(month)}.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: scheduledDays.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final day = scheduledDays[index];
                final selected = selectedDay == day;
                final count = dayRules[day]?.length ?? 0;
                final daysUntil = day
                    .difference(_dateOnly(DateTime.now()))
                    .inDays;
                final dueSoon = daysUntil >= 0 && daysUntil <= 3;
                final color = dueSoon
                    ? const Color(0xFFF59E0B)
                    : scheme.primary;
                return _TimelineDay(
                  day: day,
                  count: count,
                  selected: selected,
                  color: color,
                  onTap: () => onDaySelected(day),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _TimelineDay extends StatelessWidget {
  const _TimelineDay({
    required this.day,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final DateTime day;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '${DateFormat('EEEE d MMMM').format(day)}, $count scheduled',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 58,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _brandIndigo : color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: selected ? _brandIndigo : color.withValues(alpha: .28),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: .18),
                      blurRadius: 11,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('EEE').format(day).toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected ? Colors.white : color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                '${day.day}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: selected ? Colors.white : scheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white
                      : count > 0
                      ? color
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleFilterBar extends StatelessWidget {
  const _RuleFilterBar({
    required this.filter,
    required this.sort,
    required this.allCount,
    required this.activeCount,
    required this.pausedCount,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  final _RuleFilter filter;
  final _RuleSort sort;
  final int allCount;
  final int activeCount;
  final int pausedCount;
  final ValueChanged<_RuleFilter> onFilterChanged;
  final ValueChanged<_RuleSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune_rounded, size: 17, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'SHOW RULES',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .7,
                ),
              ),
            ),
            PopupMenuButton<_RuleSort>(
              tooltip: 'Sort recurring rules',
              initialValue: sort,
              onSelected: onSortChanged,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _RuleSort.dueDate,
                  child: Text('Due date'),
                ),
                PopupMenuItem(value: _RuleSort.amount, child: Text('Amount')),
                PopupMenuItem(value: _RuleSort.name, child: Text('Name')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sort: ${switch (sort) {
                        _RuleSort.dueDate => 'Due date',
                        _RuleSort.amount => 'Amount',
                        _RuleSort.name => 'Name',
                      }}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      color: scheme.primary,
                      size: 19,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _RuleFilterChip(
                filter: _RuleFilter.all,
                selected: filter == _RuleFilter.all,
                label: 'All',
                count: allCount,
                icon: Icons.grid_view_rounded,
                onTap: () => onFilterChanged(_RuleFilter.all),
              ),
              const SizedBox(width: 8),
              _RuleFilterChip(
                filter: _RuleFilter.active,
                selected: filter == _RuleFilter.active,
                label: 'Active',
                count: activeCount,
                icon: Icons.check_circle_outline_rounded,
                onTap: () => onFilterChanged(_RuleFilter.active),
              ),
              const SizedBox(width: 8),
              _RuleFilterChip(
                filter: _RuleFilter.paused,
                selected: filter == _RuleFilter.paused,
                label: 'Paused',
                count: pausedCount,
                icon: Icons.pause_circle_outline_rounded,
                onTap: () => onFilterChanged(_RuleFilter.paused),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RuleFilterChip extends StatelessWidget {
  const _RuleFilterChip({
    required this.filter,
    required this.selected,
    required this.label,
    required this.count,
    required this.icon,
    required this.onTap,
  });

  final _RuleFilter filter;
  final bool selected;
  final String label;
  final int count;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected ? Colors.white : scheme.onSurface;
    return Material(
      color: selected ? _brandIndigo : scheme.surface.withValues(alpha: .85),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? _brandIndigo : Colors.white.withValues(alpha: .7),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? foreground : scheme.tertiary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: .2)
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dueDate = _dateOnly(rule.nextOccurrenceDate);
    final today = _dateOnly(DateTime.now());
    final daysUntil = dueDate.difference(today).inDays;
    final dueSoon = rule.isActive && daysUntil >= 0 && daysUntil <= 3;
    final overdue = rule.isActive && daysUntil < 0;
    final paused = !rule.isActive;
    final accent = paused
        ? scheme.outline
        : overdue
        ? scheme.error
        : dueSoon
        ? const Color(0xFFB96A00)
        : scheme.tertiary;
    final icon = _ruleIcon('$categoryName ${rule.title}');
    final surface = paused
        ? scheme.surfaceContainerLow.withValues(alpha: .74)
        : scheme.surface.withValues(alpha: .88);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: dueSoon
              ? const Color(0xFFF5C05A).withValues(alpha: .65)
              : Colors.white.withValues(alpha: .78),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: paused ? .025 : .045),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 15, 10, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent.withValues(alpha: .16)),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          rule.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: paused ? scheme.onSurfaceVariant : null,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.2,
                          ),
                        ),
                        _StatusBadge(
                          label: paused
                              ? 'Paused'
                              : overdue
                              ? 'Overdue'
                              : dueSoon
                              ? daysUntil == 0
                                    ? 'Due today'
                                    : 'Due in $daysUntil ${daysUntil == 1 ? 'day' : 'days'}'
                              : 'Active',
                          color: accent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      rule.note?.trim().isNotEmpty == true
                          ? '$categoryName • ${rule.note}'
                          : categoryName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: paused
                            ? scheme.onSurfaceVariant
                            : scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _RuleMeta(
                          icon: paused
                              ? Icons.pause_rounded
                              : Icons.event_repeat_rounded,
                          text: paused
                              ? 'Next date: ${DateFormat('d MMM').format(dueDate)}'
                              : _frequencyLabel(rule),
                          color: paused
                              ? scheme.onSurfaceVariant
                              : scheme.primary,
                        ),
                        _MetaDot(color: scheme.outlineVariant),
                        _RuleMeta(
                          icon: Icons.account_balance_wallet_outlined,
                          text: _paymentMethodLabel(rule.paymentMethod),
                          color: scheme.onSurfaceVariant,
                        ),
                        _MetaDot(color: scheme.outlineVariant),
                        _RuleMeta(
                          icon: rule.autoCreateTransaction
                              ? Icons.autorenew_rounded
                              : Icons.touch_app_outlined,
                          text: rule.autoCreateTransaction
                              ? 'Auto-create'
                              : 'Manual',
                          color: rule.autoCreateTransaction
                              ? scheme.tertiary
                              : scheme.onSurfaceVariant,
                        ),
                        if (rule.reminderDays != null) ...[
                          _MetaDot(color: scheme.outlineVariant),
                          _RuleMeta(
                            icon: Icons.notifications_active_outlined,
                            text: _reminderLabel(rule.reminderDays),
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              SizedBox(
                width: 82,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        AppUtils.formatCurrency(rule.amount),
                        maxLines: 1,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: paused
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      paused
                          ? 'Paused'
                          : overdue
                          ? 'Past due'
                          : dueSoon
                          ? 'Action soon'
                          : DateFormat('d MMM').format(dueDate),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (paused)
                      TextButton(
                        onPressed: () => onMenu(_RuleAction.resume),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 7),
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Resume'),
                      )
                    else
                      PopupMenuButton<_RuleAction>(
                        tooltip: 'Rule actions',
                        padding: EdgeInsets.zero,
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
                          const PopupMenuItem(
                            value: _RuleAction.generate,
                            child: Text('Generate expense now'),
                          ),
                          const PopupMenuItem(
                            value: _RuleAction.pause,
                            child: Text('Pause rule'),
                          ),
                          const PopupMenuItem(
                            value: _RuleAction.delete,
                            child: Text('Delete rule'),
                          ),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Icon(
                            Icons.more_vert_rounded,
                            color: scheme.outline,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _ruleIcon(String source) {
  final value = source.toLowerCase();
  if (value.contains('bill') ||
      value.contains('utility') ||
      value.contains('internet')) {
    return Icons.sync_alt_rounded;
  }
  if (value.contains('health') ||
      value.contains('fitness') ||
      value.contains('gym')) {
    return Icons.fitness_center_rounded;
  }
  if (value.contains('cloud') || value.contains('software')) {
    return Icons.cloud_sync_rounded;
  }
  if (value.contains('stream') || value.contains('entertain')) {
    return Icons.play_circle_outline_rounded;
  }
  if (value.contains('food') || value.contains('grocer')) {
    return Icons.restaurant_rounded;
  }
  return Icons.repeat_rounded;
}

String _reminderLabel(int? days) => switch (days) {
  null => 'No reminder',
  0 => 'Due day reminder',
  1 => '1 day reminder',
  _ => '$days day${days == 1 ? '' : 's'} reminder',
};

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _RuleMeta extends StatelessWidget {
  const _RuleMeta({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _MetaDot extends StatelessWidget {
  const _MetaDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _RecurringEmptyState extends StatelessWidget {
  const _RecurringEmptyState({
    required this.hasRules,
    required this.selectedDay,
    required this.onClear,
    required this.onAdd,
  });

  final bool hasRules;
  final DateTime? selectedDay;
  final VoidCallback onClear;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = !hasRules
        ? 'No recurring expenses'
        : selectedDay != null
        ? 'Nothing scheduled this day'
        : 'No rules in this view';
    final message = !hasRules
        ? 'Add subscriptions and regular bills to keep them on schedule.'
        : 'Clear the current date or status filter to see other rules.';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: _glassDecoration(context, radius: 24),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.repeat_rounded, color: scheme.primary, size: 23),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (hasRules)
            OutlinedButton(
              onPressed: onClear,
              child: const Text('Clear filters'),
            )
          else
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add recurring'),
            ),
        ],
      ),
    );
  }
}

class _CostDistributionCard extends StatelessWidget {
  const _CostDistributionCard({
    required this.totals,
    required this.monthlyTotal,
  });

  final Map<String, double> totals;
  final double monthlyTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = [
      _brandIndigo,
      const Color(0xFFF59E0B),
      scheme.secondary,
      scheme.tertiary,
      const Color(0xFFE45C7A),
      const Color(0xFF168AAD),
    ];
    final entries = totals.entries.toList()
      ..sort((first, second) => second.value.compareTo(first.value));

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _glassDecoration(context, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cost distribution',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'Monthly active',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          if (entries.isEmpty || monthlyTotal <= 0)
            Text(
              'Active recurring costs will be grouped by category here.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 11,
                child: Row(
                  children: [
                    for (var i = 0; i < entries.length; i++)
                      Expanded(
                        flex: (entries[i].value / monthlyTotal * 10000)
                            .round()
                            .clamp(1, 10000),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          color: colors[i % colors.length],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 13),
            Container(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: .35),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final visibleCount = constraints.maxWidth < 340 ? 2 : 3;
                final shownEntries = entries.take(visibleCount).toList();
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < shownEntries.length; i++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: i == shownEntries.length - 1 ? 0 : 8,
                          ),
                          child: _CostLegend(
                            label: shownEntries[i].key,
                            amount: shownEntries[i].value,
                            percentage: shownEntries[i].value / monthlyTotal,
                            color: colors[i % colors.length],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _CostLegend extends StatelessWidget {
  const _CostLegend({
    required this.label,
    required this.amount,
    required this.percentage,
    required this.color,
  });

  final String label;
  final double amount;
  final double percentage;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          AppUtils.formatCurrency(amount),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          '${(percentage * 100).toStringAsFixed(1)}%',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ReminderInfoCard extends StatelessWidget {
  const _ReminderInfoCard({
    required this.configuredCount,
    required this.activeCount,
  });

  final int configuredCount;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: .43),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: Colors.white.withValues(alpha: .72)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_user_outlined,
              color: scheme.onPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  configuredCount == 0
                      ? 'No local reminders configured'
                      : 'Local reminders configured',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  activeCount == 0
                      ? 'Add an active rule and choose a reminder to receive an alert on this device.'
                      : '$configuredCount of $activeCount active ${activeCount == 1 ? 'rule has' : 'rules have'} a reminder set. Alerts are delivered locally on this device.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
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

class _AddRecurringButton extends StatelessWidget {
  const _AddRecurringButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: _brandIndigo.withValues(alpha: .32),
            blurRadius: 21,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: _brandIndigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add recurring',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

BoxDecoration _glassDecoration(BuildContext context, {double radius = 22}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final dark = theme.brightness == Brightness.dark;
  return BoxDecoration(
    color: scheme.surface.withValues(alpha: dark ? .94 : .84),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: dark
          ? scheme.outlineVariant.withValues(alpha: .3)
          : Colors.white.withValues(alpha: .8),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? .12 : .035),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );
}
