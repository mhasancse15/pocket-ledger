import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/routes/app_router.dart';
import '../../core/utils/constants.dart';
import '../../domain/entities/recurring_rule.dart';
import '../../domain/entities/transaction.dart';
import '../providers/category_provider.dart';
import '../providers/recurring_provider.dart';
import '../widgets/error_view.dart';
import '../widgets/financial_summary_card.dart';

class RecurringExpenseDetailsPage extends ConsumerWidget {
  const RecurringExpenseDetailsPage({required this.ruleId, super.key});

  final String ruleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ruleAsync = ref.watch(recurringRuleProvider(ruleId));
    final categories = ref.watch(allCategoriesProvider).valueOrNull ?? const [];
    final categoryNames = {for (final item in categories) item.id: item.name};
    final occurrencesAsync = ref.watch(recurringOccurrencesProvider(ruleId));

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring expense')),
      body: ruleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            ErrorView(message: 'Unable to load recurring rule\n$error'),
        data: (rule) {
          if (rule == null) {
            return const Center(child: Text('Recurring rule not found.'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _RuleOverview(rule: rule),
              const SizedBox(height: 14),
              _InformationCard(
                rows: [
                  ('Frequency', _frequencyLabel(rule)),
                  (
                    'Category',
                    categoryNames[rule.categoryId] ?? rule.categoryId,
                  ),
                  ('Payment method', _paymentMethodLabel(rule.paymentMethod)),
                  ('Next payment', _date(rule.nextOccurrenceDate)),
                  ('Started', _date(rule.startDate)),
                  (
                    'Ends',
                    rule.endDate == null ? 'No end date' : _date(rule.endDate!),
                  ),
                  (
                    'Auto-create expense',
                    rule.autoCreateTransaction ? 'On' : 'Off',
                  ),
                  ('Reminder', _reminderLabel(rule.reminderDays)),
                  ('Status', rule.isActive ? 'Active' : 'Paused'),
                ],
              ),
              if (rule.note?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                _InformationCard(rows: [('Note', rule.note!)]),
              ],
              const SizedBox(height: 20),
              Text(
                'Occurrence history',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              occurrencesAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, _) =>
                    Text('Unable to load occurrence history: $error'),
                data: (occurrences) {
                  if (occurrences.isEmpty) {
                    return const _EmptyHistory();
                  }
                  return Card(
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < occurrences.length;
                          index++
                        ) ...[
                          if (index > 0)
                            const Divider(height: 1, indent: 16, endIndent: 16),
                          ListTile(
                            leading: Icon(
                              occurrences[index].transactionId == null
                                  ? Icons.notifications_none
                                  : Icons.receipt_long_outlined,
                            ),
                            title: Text(
                              _date(occurrences[index].scheduledDate),
                            ),
                            subtitle: Text(
                              occurrences[index].transactionId == null
                                  ? 'Reminder only'
                                  : 'Expense generated',
                            ),
                            trailing: occurrences[index].transactionId == null
                                ? null
                                : Text(AppUtils.formatCurrency(rule.amount)),
                            onTap: occurrences[index].transactionId == null
                                ? null
                                : () => context.pushNamed(
                                    AppRoutes.transactionDetailsName,
                                    pathParameters: {
                                      'id': occurrences[index].transactionId!,
                                    },
                                  ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => context.pushNamed(
                  AppRoutes.recurringExpenseEditName,
                  pathParameters: {'id': rule.id},
                ),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit rule'),
              ),
            ],
          );
        },
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
    return FinancialSummaryCard(
      label: '${rule.title} • ${rule.isActive ? 'Active' : 'Paused'}',
      amount: rule.amount,
      metrics: [
        FinancialSummaryMetric(
          label: 'Frequency',
          value: rule.frequency.name,
          icon: Icons.repeat,
        ),
        FinancialSummaryMetric(
          label: 'Next payment',
          value: DateFormat('d MMM').format(rule.nextOccurrenceDate.toLocal()),
          icon: Icons.event_outlined,
        ),
      ],
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        rows[index].$1,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        rows[index].$2,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            'No occurrences have been processed yet.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}
