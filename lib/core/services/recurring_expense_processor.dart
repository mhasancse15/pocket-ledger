import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

import 'local_notification_service.dart';
import '../../data/datasources/drift/database.dart';
import '../../domain/entities/recurring_rule.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/usecases/recurring_date_calculator.dart';
import '../utils/constants.dart';

class RecurringExpenseProcessor {
  RecurringExpenseProcessor(
    this._database, {
    this._calculator = const RecurringDateCalculator(),
    this._notifications,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _database;
  final RecurringDateCalculator _calculator;
  final LocalNotificationService? _notifications;
  final DateTime Function() _clock;
  static const _uuid = Uuid();
  Future<void> _lastRun = Future<void>.value();

  Future<int> processDueRules() async {
    final previousRun = _lastRun;
    final completed = Completer<void>();
    _lastRun = completed.future;
    await previousRun;

    try {
      return await _processDueRules();
    } finally {
      completed.complete();
    }
  }

  Future<bool> generateNow(String ruleId) async {
    final rule = await _database.getRecurringRuleById(ruleId);
    if (rule == null || !rule.isActive) {
      throw StateError('Recurring rule is unavailable: $ruleId');
    }
    final scheduledDate = _dateOnly(rule.nextOccurrenceDate);
    final endDate = rule.endDate == null ? null : _dateOnly(rule.endDate!);
    if (endDate != null && scheduledDate.isAfter(endDate)) {
      throw StateError('The recurring rule has passed its end date.');
    }
    final frequency = RecurringFrequency.values.byName(rule.frequency);
    final nextDate = _calculator.calculateNextDate(
      currentDate: scheduledDate,
      frequency: frequency,
      anchorDay: rule.anchorDay,
    );
    final now = _clock();
    final transactionId = _uuid.v4();
    final generated = await _database.recordRecurringOccurrence(
      ruleId: rule.id,
      scheduledDate: scheduledDate,
      nextOccurrenceDate: nextDate,
      occurrence: RecurringOccurrenceTableCompanion.insert(
        id: _uuid.v4(),
        recurringRuleId: rule.id,
        scheduledDate: scheduledDate,
        transactionId: drift.Value(transactionId),
        status: RecurringOccurrenceStatus.generated.name,
        createdAt: now,
      ),
      generatedTransaction: TransactionTableCompanion.insert(
        id: transactionId,
        type: TransactionType.expense.name,
        amount: rule.amount,
        categoryId: rule.categoryId,
        date: _dateOnly(now),
        paymentMethod: _paymentMethod(rule.paymentMethod).name,
        note: drift.Value(
          rule.note?.trim().isNotEmpty == true ? rule.note : rule.title,
        ),
        recurringRuleId: drift.Value(rule.id),
        createdAt: now,
        updatedAt: now,
      ),
      deactivateRule: endDate != null && nextDate.isAfter(endDate),
      advanceRule: false,
    );
    await syncReminders();
    return generated;
  }

  Future<void> syncReminders() async {
    final notifications = _notifications;
    if (notifications == null) return;
    final rules = await _database.getAllRecurringRules();
    for (final rule in rules) {
      final reminderDays = rule.reminderDays;
      if (!rule.isActive || reminderDays == null) {
        await notifications.cancelRecurringReminder(
          rule.id,
          notificationId: rule.notificationId,
        );
        continue;
      }
      final dueDate = _dateOnly(rule.nextOccurrenceDate);
      final hasGeneratedOccurrence = await _database.recurringOccurrenceExists(
        ruleId: rule.id,
        scheduledDate: dueDate,
      );
      final reminderDate = hasGeneratedOccurrence
          ? _calculator.calculateNextDate(
              currentDate: dueDate,
              frequency: RecurringFrequency.values.byName(rule.frequency),
              anchorDay: rule.anchorDay,
            )
          : dueDate;
      final endDate = rule.endDate == null ? null : _dateOnly(rule.endDate!);
      if (endDate != null && reminderDate.isAfter(endDate)) {
        await notifications.cancelRecurringReminder(
          rule.id,
          notificationId: rule.notificationId,
        );
        continue;
      }
      await notifications.scheduleRecurringReminder(
        ruleId: rule.id,
        notificationId:
            rule.notificationId ??
            notifications.recurringNotificationId(rule.id),
        title: rule.title,
        amount: AppUtils.formatCurrency(rule.amount),
        scheduledDate: reminderDate,
        reminderDays: reminderDays,
      );
    }
  }

  Future<int> _processDueRules() async {
    final today = _dateOnly(_clock());
    final rules = await _database.getActiveRecurringRules();
    var processedOccurrences = 0;

    for (final initialRule in rules) {
      var scheduledDate = _dateOnly(initialRule.nextOccurrenceDate);
      final initialEndDate = initialRule.endDate == null
          ? null
          : _dateOnly(initialRule.endDate!);
      if (initialEndDate != null && scheduledDate.isAfter(initialEndDate)) {
        await _deactivate(initialRule.id);
        continue;
      }
      while (!scheduledDate.isAfter(today)) {
        final rule = await _database.getRecurringRuleById(initialRule.id);
        if (rule == null || !rule.isActive) break;

        final currentDate = _dateOnly(rule.nextOccurrenceDate);
        if (currentDate.isAfter(today)) break;

        final endDate = rule.endDate == null ? null : _dateOnly(rule.endDate!);
        if (endDate != null && currentDate.isAfter(endDate)) {
          await _deactivate(rule.id);
          break;
        }

        final nextDate = _calculator.calculateNextDate(
          currentDate: currentDate,
          frequency: RecurringFrequency.values.byName(rule.frequency),
          anchorDay: rule.anchorDay,
        );
        final shouldDeactivate = endDate != null && nextDate.isAfter(endDate);
        final now = _clock();
        final transactionId = rule.autoCreateTransaction ? _uuid.v4() : null;

        final generatedTransaction = transactionId == null
            ? null
            : TransactionTableCompanion.insert(
                id: transactionId,
                type: TransactionType.expense.name,
                amount: rule.amount,
                categoryId: rule.categoryId,
                date: currentDate,
                paymentMethod: _paymentMethod(rule.paymentMethod).name,
                note: drift.Value(
                  rule.note?.trim().isNotEmpty == true ? rule.note : rule.title,
                ),
                recurringRuleId: drift.Value(rule.id),
                createdAt: now,
                updatedAt: now,
              );

        final advanced = await _database.recordRecurringOccurrence(
          ruleId: rule.id,
          scheduledDate: currentDate,
          nextOccurrenceDate: nextDate,
          occurrence: RecurringOccurrenceTableCompanion.insert(
            id: _uuid.v4(),
            recurringRuleId: rule.id,
            scheduledDate: currentDate,
            transactionId: drift.Value(transactionId),
            status: transactionId == null
                ? RecurringOccurrenceStatus.skipped.name
                : RecurringOccurrenceStatus.generated.name,
            createdAt: now,
          ),
          generatedTransaction: generatedTransaction,
          deactivateRule: shouldDeactivate,
        );
        if (advanced) processedOccurrences++;

        final latestRule = await _database.getRecurringRuleById(rule.id);
        if (latestRule == null || !latestRule.isActive) break;
        final latestDate = _dateOnly(latestRule.nextOccurrenceDate);
        if (!latestDate.isAfter(currentDate) && !advanced) break;
        scheduledDate = latestDate;
      }
    }

    await syncReminders();
    return processedOccurrences;
  }

  Future<void> _deactivate(String ruleId) async {
    await (_database.update(
      _database.recurringRuleTable,
    )..where((rule) => rule.id.equals(ruleId))).write(
      RecurringRuleTableCompanion(
        isActive: const drift.Value(false),
        updatedAt: drift.Value(_clock()),
      ),
    );
  }

  PaymentMethod _paymentMethod(String value) {
    for (final method in PaymentMethod.values) {
      if (method.name == value) return method;
    }
    throw FormatException('Unknown recurring payment method: $value');
  }

  DateTime _dateOnly(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}
