import '../entities/recurring_rule.dart';

abstract class RecurringRuleRepository {
  Future<List<RecurringRule>> getAllRules();

  Future<List<RecurringRule>> getActiveRules();

  Stream<List<RecurringRule>> watchAllRules();

  Future<RecurringRule?> getRule(String id);

  Future<void> addRule(RecurringRule rule);

  Future<void> updateRule(RecurringRule rule);

  Future<void> pauseRule(String id);

  Future<void> resumeRule(String id);

  Future<void> deleteRule(String id);

  Future<List<RecurringOccurrence>> getOccurrences(String ruleId);

  Future<bool> occurrenceExists({
    required String ruleId,
    required DateTime scheduledDate,
  });

  Future<void> saveOccurrence(RecurringOccurrence occurrence);
}
