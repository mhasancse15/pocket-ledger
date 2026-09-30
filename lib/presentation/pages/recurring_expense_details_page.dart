import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/routes/app_router.dart';
import '../../core/utils/constants.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/recurring_rule.dart';
import '../../domain/entities/transaction.dart';
import '../providers/category_provider.dart';
import '../providers/recurring_provider.dart';
import '../widgets/error_view.dart';

const _brandIndigo = Color(0xFF4338CA);

class RecurringExpenseDetailsPage extends ConsumerWidget {
  const RecurringExpenseDetailsPage({required this.ruleId, super.key});

  final String ruleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ruleAsync = ref.watch(recurringRuleProvider(ruleId));
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final occurrencesAsync = ref.watch(recurringOccurrencesProvider(ruleId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring expense'),
        backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: .8),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _DetailsBackdrop()),
          ruleAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                ErrorView(message: 'Unable to load recurring rule\n$error'),
            data: (rule) {
              if (rule == null) {
                return const Center(child: Text('Recurring rule not found.'));
              }
              final categories =
                  categoriesAsync.valueOrNull ?? const <Category>[];
              final categoryName = categories
                  .where((category) => category.id == rule.categoryId)
                  .map((category) => category.name)
                  .firstOrNull;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
                children: [
                  _RuleOverview(rule: rule),
                  const SizedBox(height: 18),
                  _InformationCard(
                    rows: [
                      _DetailRowData(
                        'Frequency',
                        _frequencyLabel(rule),
                        icon: Icons.repeat_rounded,
                      ),
                      _DetailRowData(
                        'Category',
                        categoryName ?? rule.categoryId,
                        icon: Icons.category_outlined,
                        tone: _DetailTone.amber,
                      ),
                      _DetailRowData(
                        'Payment method',
                        _paymentMethodLabel(rule.paymentMethod),
                        icon: _paymentMethodIcon(rule.paymentMethod),
                      ),
                      _DetailRowData(
                        'Next payment',
                        _date(rule.nextOccurrenceDate),
                        icon: Icons.event_outlined,
                      ),
                      _DetailRowData(
                        'Started',
                        _date(rule.startDate),
                        icon: Icons.play_arrow_rounded,
                      ),
                      _DetailRowData(
                        'Ends',
                        rule.endDate == null
                            ? 'No end date'
                            : _date(rule.endDate!),
                      ),
                      _DetailRowData(
                        'Auto-create expense',
                        rule.autoCreateTransaction ? 'On' : 'Off',
                        icon: rule.autoCreateTransaction
                            ? Icons.check_rounded
                            : Icons.close_rounded,
                        tone: _DetailTone.indigo,
                      ),
                      _DetailRowData(
                        'Reminder',
                        _reminderLabel(rule.reminderDays),
                        icon: Icons.notifications_none_rounded,
                      ),
                      _DetailRowData(
                        'Status',
                        rule.isActive ? 'Active' : 'Paused',
                        icon: rule.isActive
                            ? Icons.check_circle_outline_rounded
                            : Icons.pause_circle_outline_rounded,
                        tone: rule.isActive
                            ? _DetailTone.green
                            : _DetailTone.muted,
                      ),
                    ],
                  ),
                  if (rule.note?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 14),
                    _NoteCard(note: rule.note!),
                  ],
                  const SizedBox(height: 20),
                  _SectionHeading(
                    title: 'Occurrence history',
                    trailing: occurrencesAsync.whenOrNull(
                      data: (occurrences) =>
                          '${occurrences.length} '
                          '${occurrences.length == 1 ? 'entry' : 'entries'}',
                    ),
                  ),
                  const SizedBox(height: 10),
                  occurrencesAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(22),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => _HistoryErrorCard(error: error),
                    data: (occurrences) {
                      if (occurrences.isEmpty) {
                        return const _EmptyHistory();
                      }
                      return Column(
                        children: [
                          for (final occurrence in occurrences)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _OccurrenceCard(
                                rule: rule,
                                occurrence: occurrence,
                                onTap: occurrence.transactionId == null
                                    ? null
                                    : () => context.pushNamed(
                                        AppRoutes.transactionDetailsName,
                                        pathParameters: {
                                          'id': occurrence.transactionId!,
                                        },
                                      ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _UpcomingPaymentCard(
                    rule: rule,
                    date: rule.nextOccurrenceDate.toLocal(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: ruleAsync.valueOrNull == null
          ? null
          : _EditRuleFooter(
              onPressed: () => context.pushNamed(
                AppRoutes.recurringExpenseEditName,
                pathParameters: {'id': ruleId},
              ),
            ),
    );
  }

  static String _date(DateTime value) =>
      DateFormat('d MMMM yyyy').format(value.toLocal());

  static String _frequencyLabel(RecurringRule rule) => switch (rule.frequency) {
    RecurringFrequency.daily => 'Every day',
    RecurringFrequency.weekly => 'Every week',
    RecurringFrequency.monthly => 'Every month on day ${rule.anchorDay}',
    RecurringFrequency.quarterly => 'Every 3 months on day ${rule.anchorDay}',
    RecurringFrequency.yearly => 'Every year',
  };

  static String _paymentMethodLabel(String value) {
    for (final method in PaymentMethod.values) {
      if (method.name == value) {
        return switch (method) {
          PaymentMethod.cash => 'Cash',
          PaymentMethod.bankTransfer => 'Bank transfer',
          PaymentMethod.debitCard => 'Debit card',
          PaymentMethod.creditCard => 'Credit card',
          PaymentMethod.mobileWallet => 'Mobile wallet',
          PaymentMethod.other => 'Other',
        };
      }
    }
    return value;
  }

  static IconData _paymentMethodIcon(String value) => switch (value) {
    'cash' => Icons.payments_outlined,
    'bankTransfer' => Icons.account_balance_outlined,
    'debitCard' || 'creditCard' => Icons.credit_card_outlined,
    'mobileWallet' => Icons.account_balance_wallet_outlined,
    _ => Icons.wallet_outlined,
  };

  static String _reminderLabel(int? days) => switch (days) {
    null => 'None',
    0 => 'On the due date',
    1 => '1 day before',
    3 => '3 days before',
    7 => '7 days before',
    _ => '$days days before',
  };
}

class _RuleOverview extends StatelessWidget {
  const _RuleOverview({required this.rule});

  final RecurringRule rule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statusColor = rule.isActive
        ? const Color(0xFF69F0B5)
        : scheme.outline;
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
            color: _brandIndigo.withValues(alpha: .24),
            blurRadius: 28,
            offset: const Offset(0, 13),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -92,
            right: -64,
            child: _OverviewRing(size: 230),
          ),
          const Positioned(
            top: -42,
            right: -120,
            child: _OverviewRing(size: 270),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'POCKET LEDGER',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: const Color(0xFFD0CEFF),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.15,
                        ),
                      ),
                    ),
                    _PillBadge(
                      label: rule.isActive ? 'ACTIVE' : 'PAUSED',
                      color: statusColor,
                      filled: true,
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .25),
                        ),
                      ),
                      child: const Icon(
                        Icons.wifi_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        rule.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFFD0CEFF),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      rule.isActive ? 'Active rule' : 'Paused rule',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          AppUtils.formatCurrency(rule.amount),
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '/ cycle',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFFC7C5FF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: .18),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: _OverviewMetric(
                        icon: Icons.sync_rounded,
                        label: 'Frequency',
                        value: _frequencyShortLabel(rule.frequency),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 42,
                      color: Colors.white.withValues(alpha: .17),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _OverviewMetric(
                        icon: Icons.calendar_month_outlined,
                        label: 'Next payment',
                        value: DateFormat('d MMM')
                            .format(rule.nextOccurrenceDate.toLocal()),
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

  String _frequencyShortLabel(RecurringFrequency frequency) =>
      switch (frequency) {
        RecurringFrequency.daily => 'Daily',
        RecurringFrequency.weekly => 'Weekly',
        RecurringFrequency.monthly => 'Monthly',
        RecurringFrequency.quarterly => 'Quarterly',
        RecurringFrequency.yearly => 'Yearly',
      };
}

class _OverviewRing extends StatelessWidget {
  const _OverviewRing({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: .1),
            width: 18,
          ),
        ),
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({
    required this.label,
    required this.color,
    this.filled = false,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled
            ? Colors.white.withValues(alpha: .17)
            : color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: filled
              ? Colors.white.withValues(alpha: .18)
              : color.withValues(alpha: .3),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: filled ? Colors.white : color,
          fontWeight: FontWeight.w800,
          letterSpacing: .3,
        ),
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white.withValues(alpha: .12)),
          ),
          child: Icon(icon, color: const Color(0xFFD0CEFF), size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFFC7C5FF),
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _DetailTone { neutral, amber, indigo, green, muted }

class _DetailRowData {
  const _DetailRowData(
    this.label,
    this.value, {
    this.icon,
    this.tone = _DetailTone.neutral,
  });

  final String label;
  final String value;
  final IconData? icon;
  final _DetailTone tone;
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({required this.rows});

  final List<_DetailRowData> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: _glassDecoration(context, radius: 26),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: scheme.outlineVariant.withValues(alpha: .32),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[index].label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(child: _DetailValue(row: rows[index])),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailValue extends StatelessWidget {
  const _DetailValue({required this.row});

  final _DetailRowData row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    if (row.tone == _DetailTone.neutral && row.icon == null) {
      return Text(
        row.value,
        textAlign: TextAlign.end,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    final (foreground, background, border) = switch (row.tone) {
      _DetailTone.amber => (
        isDark ? const Color(0xFFFFD166) : const Color(0xFF9A5B00),
        isDark ? const Color(0xFF3A2D14) : const Color(0xFFFFF8E7),
        isDark ? const Color(0xFF72551D) : const Color(0xFFFFDF8A),
      ),
      _DetailTone.indigo => (
        isDark ? scheme.primary : _brandIndigo,
        isDark
            ? scheme.primaryContainer.withValues(alpha: .35)
            : const Color(0xFFF0F1FF),
        isDark ? scheme.primary.withValues(alpha: .3) : const Color(0xFFD9DDFF),
      ),
      _DetailTone.green => (
        isDark ? scheme.tertiary : const Color(0xFF007B55),
        isDark
            ? scheme.tertiaryContainer.withValues(alpha: .3)
            : const Color(0xFFECFBF4),
        isDark
            ? scheme.tertiary.withValues(alpha: .3)
            : const Color(0xFF9CEFCB),
      ),
      _DetailTone.muted => (
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHighest.withValues(alpha: .6),
        scheme.outlineVariant.withValues(alpha: .4),
      ),
      _DetailTone.neutral => (
        scheme.onSurface,
        scheme.surfaceContainerHighest.withValues(alpha: .35),
        scheme.outlineVariant.withValues(alpha: .3),
      ),
    };
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 190),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (row.icon != null) ...[
              Icon(row.icon, size: 14, color: foreground),
              const SizedBox(width: 5),
            ] else ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: foreground,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: Text(
                row.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _glassDecoration(context, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_rounded, size: 17, color: scheme.primary),
              const SizedBox(width: 7),
              Text(
                'Note',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -.4,
            ),
          ),
        ),
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              trailing!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _OccurrenceCard extends StatelessWidget {
  const _OccurrenceCard({
    required this.rule,
    required this.occurrence,
    required this.onTap,
  });

  final RecurringRule rule;
  final RecurringOccurrence occurrence;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isGenerated = occurrence.transactionId != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(23),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: _glassDecoration(context, radius: 23),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: .12),
                  ),
                ),
                child: Icon(
                  isGenerated
                      ? Icons.receipt_long_outlined
                      : Icons.notifications_none_rounded,
                  color: scheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _date(occurrence.scheduledDate),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isGenerated
                          ? 'Expense generated'
                          : 'No expense generated',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isGenerated ? AppUtils.formatCurrency(rule.amount) : '—',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isGenerated
                            ? Icons.check_rounded
                            : Icons.remove_rounded,
                        color: isGenerated
                            ? const Color(0xFF059669)
                            : scheme.outline,
                        size: 14,
                      ),
                      Text(
                        isGenerated ? 'Logged' : 'Skipped',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isGenerated
                              ? const Color(0xFF059669)
                              : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: scheme.outline,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _date(DateTime value) =>
      DateFormat('d MMMM yyyy').format(value.toLocal());
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _glassDecoration(context, radius: 22),
      child: Row(
        children: [
          Icon(Icons.history_rounded, color: scheme.outline, size: 22),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'No occurrences have been processed yet. Your payment history will appear here.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryErrorCard extends StatelessWidget {
  const _HistoryErrorCard({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: .2),
        ),
      ),
      child: Text(
        'Unable to load occurrence history: $error',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}

class _UpcomingPaymentCard extends StatelessWidget {
  const _UpcomingPaymentCard({required this.rule, required this.date});

  final RecurringRule rule;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final days = date.difference(_dateOnly(DateTime.now())).inDays;
    final statusText = !rule.isActive
        ? 'Paused'
        : days < 0
        ? 'Overdue'
        : days == 0
        ? 'Due today'
        : 'Due in $days ${days == 1 ? 'day' : 'days'}';
    final statusColor = !rule.isActive
        ? scheme.onSurfaceVariant
        : days < 0
        ? scheme.error
        : scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: .45),
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 7, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Upcoming: ${DateFormat('d MMMM yyyy').format(date)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            statusText,
            style: theme.textTheme.labelSmall?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

DateTime _dateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

class _EditRuleFooter extends StatelessWidget {
  const _EditRuleFooter({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.scaffoldBackgroundColor.withValues(alpha: .72),
              theme.scaffoldBackgroundColor.withValues(alpha: .98),
            ],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            boxShadow: [
              BoxShadow(
                color: _brandIndigo.withValues(alpha: .3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SizedBox(
            height: 58,
            child: FilledButton.icon(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: _brandIndigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(19),
                ),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: const Text(
                'Edit rule',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailsBackdrop extends StatelessWidget {
  const _DetailsBackdrop();

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
                        Color(0xFFF7FBFF),
                      ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 80,
          right: -145,
          child: _glow(
            dark ? const Color(0xFF5148D7) : const Color(0xFFC3C0FF),
            dark ? .1 : .2,
          ),
        ),
        Positioned(
          bottom: 40,
          left: -160,
          child: _glow(
            dark ? const Color(0xFF005E40) : const Color(0xFF99F6E4),
            dark ? .08 : .15,
          ),
        ),
      ],
    );
  }

  Widget _glow(Color color, double opacity) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
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

BoxDecoration _glassDecoration(BuildContext context, {double radius = 22}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final dark = theme.brightness == Brightness.dark;
  return BoxDecoration(
    color: scheme.surface.withValues(alpha: dark ? .96 : .88),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: dark
          ? scheme.outlineVariant.withValues(alpha: .3)
          : Colors.white.withValues(alpha: .86),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: dark ? .12 : .045),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  );
}
