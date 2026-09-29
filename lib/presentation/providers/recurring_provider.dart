import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/local_notification_service.dart';
import '../../core/services/recurring_expense_processor.dart';
import '../../data/repositories/recurring_rule_repository_impl.dart';
import '../../domain/entities/recurring_rule.dart';
import '../../domain/repositories/recurring_rule_repository.dart';
import 'budget_notification_provider.dart';
import 'budget_provider.dart';
import 'database_provider.dart';
import 'transaction_provider.dart';

final recurringRepositoryProvider = Provider<RecurringRuleRepository>(
  (ref) => RecurringRuleRepositoryImpl(ref.watch(databaseProvider)),
);

final allRecurringRulesProvider = FutureProvider<List<RecurringRule>>(
  (ref) => ref.watch(recurringRepositoryProvider).getAllRules(),
);

final watchAllRecurringRulesProvider = StreamProvider<List<RecurringRule>>(
  (ref) => ref.watch(recurringRepositoryProvider).watchAllRules(),
);

final activeRecurringRulesProvider = FutureProvider<List<RecurringRule>>(
  (ref) => ref.watch(recurringRepositoryProvider).getActiveRules(),
);

final recurringRuleProvider = FutureProvider.family<RecurringRule?, String>(
  (ref, id) => ref.watch(recurringRepositoryProvider).getRule(id),
);

final recurringOccurrencesProvider =
    FutureProvider.family<List<RecurringOccurrence>, String>(
      (ref, id) => ref.watch(recurringRepositoryProvider).getOccurrences(id),
    );

final recurringMonthlyTotalProvider = Provider<double>((ref) {
  final rules = ref.watch(activeRecurringRulesProvider).valueOrNull ?? const [];
  return rules.fold<double>(0, (sum, rule) => sum + _monthlyEquivalent(rule));
});

double _monthlyEquivalent(RecurringRule rule) => switch (rule.frequency) {
  RecurringFrequency.daily => rule.amount * (365.2425 / 12),
  RecurringFrequency.weekly => rule.amount * (52.1775 / 12),
  RecurringFrequency.monthly => rule.amount,
  RecurringFrequency.quarterly => rule.amount / 3,
  RecurringFrequency.yearly => rule.amount / 12,
};

final recurringExpenseProcessorProvider = Provider<RecurringExpenseProcessor>(
  (ref) => RecurringExpenseProcessor(
    ref.watch(databaseProvider),
    notifications: LocalNotificationService.instance,
  ),
);

class RecurringProcessorController {
  const RecurringProcessorController(this._processor, this._ref);

  final RecurringExpenseProcessor _processor;
  final Ref _ref;

  Future<int> processDueRules() async {
    final processed = await _processor.processDueRules();
    _ref.invalidate(allRecurringRulesProvider);
    _ref.invalidate(activeRecurringRulesProvider);
    _ref.invalidate(recurringMonthlyTotalProvider);
    _ref.invalidate(recurringRuleProvider);
    _ref.invalidate(recurringOccurrencesProvider);
    if (processed > 0) await _refreshGeneratedExpenses();
    return processed;
  }

  Future<bool> generateNow(String ruleId) async {
    final generated = await _processor.generateNow(ruleId);
    if (generated) {
      _ref.invalidate(recurringOccurrencesProvider(ruleId));
      await _refreshGeneratedExpenses();
    }
    return generated;
  }

  Future<void> _refreshGeneratedExpenses() async {
    _ref.invalidate(allTransactionsProvider);
    _ref.invalidate(monthlyTransactionsProvider);
    _ref.invalidate(monthlyTotalProvider);
    _ref.invalidate(budgetsProvider);
    _ref.invalidate(allRecurringRulesProvider);
    _ref.invalidate(watchAllRecurringRulesProvider);
    _ref.invalidate(activeRecurringRulesProvider);
    _ref.invalidate(recurringMonthlyTotalProvider);
    _ref.invalidate(recurringRuleProvider);
    _ref.invalidate(recurringOccurrencesProvider);
    await reportBudgetNotificationCheck(_ref);
  }
}

final recurringProcessorControllerProvider =
    Provider<RecurringProcessorController>(
      (ref) => RecurringProcessorController(
        ref.watch(recurringExpenseProcessorProvider),
        ref,
      ),
    );

class RecurringNotifier extends StateNotifier<AsyncValue<RecurringRule>> {
  RecurringNotifier(this._repository, this._ref)
    : super(const AsyncValue.loading());

  final RecurringRuleRepository _repository;
  final Ref _ref;

  void _refresh(String? ruleId) {
    _ref.invalidate(allRecurringRulesProvider);
    _ref.invalidate(watchAllRecurringRulesProvider);
    _ref.invalidate(activeRecurringRulesProvider);
    _ref.invalidate(recurringMonthlyTotalProvider);
    _ref.invalidate(recurringRuleProvider);
    if (ruleId != null) _ref.invalidate(recurringOccurrencesProvider(ruleId));
  }

  Future<void> addRecurringRule(RecurringRule rule) async {
    state = const AsyncValue.loading();
    try {
      await _repository.addRule(rule);
      state = AsyncValue.data(rule);
      _refresh(rule.id);
      await _ref.read(recurringProcessorControllerProvider).processDueRules();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> updateRecurringRule(RecurringRule rule) async {
    state = const AsyncValue.loading();
    try {
      final previous = await _repository.getRule(rule.id);
      await _repository.updateRule(rule);
      if (previous?.notificationId != rule.notificationId) {
        await LocalNotificationService.instance.cancelRecurringReminder(
          rule.id,
          notificationId: previous?.notificationId,
        );
      }
      state = AsyncValue.data(rule);
      _refresh(rule.id);
      await _ref.read(recurringProcessorControllerProvider).processDueRules();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> deleteRecurringRule(String id) async {
    try {
      final rule = await _repository.getRule(id);
      await _repository.deleteRule(id);
      await LocalNotificationService.instance.cancelRecurringReminder(
        id,
        notificationId: rule?.notificationId,
      );
      _refresh(id);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> setActive(String id, bool isActive) async {
    try {
      final rule = await _repository.getRule(id);
      if (rule == null) throw StateError('Recurring rule not found: $id');
      if (isActive) {
        await _repository.resumeRule(id);
      } else {
        await _repository.pauseRule(id);
      }
      state = AsyncValue.data(
        rule.copyWith(isActive: isActive, updatedAt: DateTime.now()),
      );
      _refresh(id);
      if (isActive) {
        await _ref.read(recurringProcessorControllerProvider).processDueRules();
      } else {
        await LocalNotificationService.instance.cancelRecurringReminder(
          id,
          notificationId: rule.notificationId,
        );
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }
}

final recurringNotifierProvider =
    StateNotifierProvider<RecurringNotifier, AsyncValue<RecurringRule>>(
      (ref) => RecurringNotifier(ref.watch(recurringRepositoryProvider), ref),
    );
