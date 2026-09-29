import 'package:drift/drift.dart' as drift;

import '../datasources/drift/database.dart';
import '../../domain/entities/recurring_rule.dart';
import '../../domain/repositories/recurring_rule_repository.dart';

class RecurringRuleRepositoryImpl implements RecurringRuleRepository {
  RecurringRuleRepositoryImpl(this._database);

  final AppDatabase _database;

  RecurringRule _ruleFromRow(RecurringRuleTableData row) => RecurringRule(
    id: row.id,
    title: row.title,
    amount: row.amount,
    categoryId: row.categoryId,
    paymentMethod: row.paymentMethod,
    frequency: RecurringFrequency.values.byName(row.frequency),
    startDate: row.startDate,
    nextOccurrenceDate: row.nextOccurrenceDate,
    anchorDay: row.anchorDay,
    note: row.note,
    endDate: row.endDate,
    isActive: row.isActive,
    autoCreateTransaction: row.autoCreateTransaction,
    lastGeneratedAt: row.lastGeneratedAt,
    reminderDays: row.reminderDays,
    notificationId: row.notificationId,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );

  RecurringRuleTableCompanion _ruleCompanion(RecurringRule rule) =>
      RecurringRuleTableCompanion.insert(
        id: rule.id,
        title: rule.title,
        amount: rule.amount,
        categoryId: rule.categoryId,
        paymentMethod: rule.paymentMethod,
        frequency: rule.frequency.name,
        startDate: rule.startDate,
        nextOccurrenceDate: rule.nextOccurrenceDate,
        anchorDay: drift.Value(rule.anchorDay),
        note: drift.Value(rule.note),
        endDate: drift.Value(rule.endDate),
        isActive: drift.Value(rule.isActive),
        autoCreateTransaction: drift.Value(rule.autoCreateTransaction),
        lastGeneratedAt: drift.Value(rule.lastGeneratedAt),
        reminderDays: drift.Value(rule.reminderDays),
        notificationId: drift.Value(rule.notificationId),
        createdAt: rule.createdAt,
        updatedAt: rule.updatedAt,
      );

  RecurringOccurrence _occurrenceFromRow(RecurringOccurrenceTableData row) =>
      RecurringOccurrence(
        id: row.id,
        recurringRuleId: row.recurringRuleId,
        scheduledDate: row.scheduledDate,
        transactionId: row.transactionId,
        status: RecurringOccurrenceStatus.values.byName(row.status),
        createdAt: row.createdAt,
      );

  @override
  Future<List<RecurringRule>> getAllRules() async =>
      (await _database.getAllRecurringRules()).map(_ruleFromRow).toList();

  @override
  Stream<List<RecurringRule>> watchAllRules() => _database
      .watchAllRecurringRules()
      .map((rows) => rows.map(_ruleFromRow).toList());

  @override
  Future<List<RecurringRule>> getActiveRules() async =>
      (await _database.getActiveRecurringRules()).map(_ruleFromRow).toList();

  @override
  Future<RecurringRule?> getRule(String id) async {
    final row = await _database.getRecurringRuleById(id);
    return row == null ? null : _ruleFromRow(row);
  }

  @override
  Future<void> addRule(RecurringRule rule) async {
    await _database.insertRecurringRule(_ruleCompanion(rule));
  }

  @override
  Future<void> updateRule(RecurringRule rule) async {
    final changed = await _database.updateRecurringRule(
      RecurringRuleTableData(
        id: rule.id,
        title: rule.title,
        amount: rule.amount,
        categoryId: rule.categoryId,
        paymentMethod: rule.paymentMethod,
        frequency: rule.frequency.name,
        startDate: rule.startDate,
        nextOccurrenceDate: rule.nextOccurrenceDate,
        anchorDay: rule.anchorDay,
        note: rule.note,
        endDate: rule.endDate,
        isActive: rule.isActive,
        autoCreateTransaction: rule.autoCreateTransaction,
        lastGeneratedAt: rule.lastGeneratedAt,
        reminderDays: rule.reminderDays,
        notificationId: rule.notificationId,
        createdAt: rule.createdAt,
        updatedAt: rule.updatedAt,
      ),
    );
    if (!changed) throw StateError('Recurring rule not found: ${rule.id}');
  }

  @override
  Future<void> pauseRule(String id) async {
    if (!await _database.setRecurringRuleActive(id, false)) {
      throw StateError('Recurring rule not found: $id');
    }
  }

  @override
  Future<void> resumeRule(String id) async {
    if (!await _database.setRecurringRuleActive(id, true)) {
      throw StateError('Recurring rule not found: $id');
    }
  }

  @override
  Future<void> deleteRule(String id) async {
    if (await _database.deleteRecurringRuleById(id) == 0) {
      throw StateError('Recurring rule not found: $id');
    }
  }

  @override
  Future<List<RecurringOccurrence>> getOccurrences(String ruleId) async =>
      (await _database.getRecurringOccurrences(ruleId))
          .map(_occurrenceFromRow)
          .toList();

  @override
  Future<bool> occurrenceExists({
    required String ruleId,
    required DateTime scheduledDate,
  }) => _database.recurringOccurrenceExists(
    ruleId: ruleId,
    scheduledDate: scheduledDate,
  );

  @override
  Future<void> saveOccurrence(RecurringOccurrence occurrence) =>
      _database.saveRecurringOccurrence(
        RecurringOccurrenceTableCompanion.insert(
          id: occurrence.id,
          recurringRuleId: occurrence.recurringRuleId,
          scheduledDate: occurrence.scheduledDate,
          transactionId: drift.Value(occurrence.transactionId),
          status: occurrence.status.name,
          createdAt: occurrence.createdAt,
        ),
      );
}
