import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/drift/database.dart';
import '../../domain/entities/recurring_rule.dart';
import 'database_provider.dart';

class RecurringRuleStore {
  final AppDatabase _database;

  RecurringRuleStore(this._database);

  RecurringRule _map(RecurringRuleTableData row) => RecurringRule(
        id: row.id,
        title: row.title,
        amount: row.amount,
        categoryId: row.categoryId,
        paymentMethod: row.paymentMethod,
        frequency: RecurringFrequency.values.firstWhere(
          (value) => value.name == row.frequency,
          orElse: () => RecurringFrequency.monthly,
        ),
        startDate: row.startDate,
        nextOccurrenceDate: row.nextOccurrenceDate,
        endDate: row.endDate,
        isActive: row.isActive,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );

  RecurringRuleTableCompanion _insert(RecurringRule rule) =>
      RecurringRuleTableCompanion.insert(
        id: rule.id,
        title: rule.title,
        amount: rule.amount,
        categoryId: rule.categoryId,
        paymentMethod: rule.paymentMethod,
        frequency: rule.frequency.name,
        startDate: rule.startDate,
        nextOccurrenceDate: rule.nextOccurrenceDate,
        endDate: drift.Value(rule.endDate),
        isActive: drift.Value(rule.isActive),
        createdAt: rule.createdAt,
        updatedAt: rule.updatedAt,
      );

  RecurringRuleTableData _data(RecurringRule rule) => RecurringRuleTableData(
        id: rule.id,
        title: rule.title,
        amount: rule.amount,
        categoryId: rule.categoryId,
        paymentMethod: rule.paymentMethod,
        frequency: rule.frequency.name,
        startDate: rule.startDate,
        nextOccurrenceDate: rule.nextOccurrenceDate,
        endDate: rule.endDate,
        isActive: rule.isActive,
        createdAt: rule.createdAt,
        updatedAt: rule.updatedAt,
      );

  Future<RecurringRule> addRecurringRule(RecurringRule rule) async {
    await _database.insertRecurringRule(_insert(rule));
    return rule;
  }

  Future<RecurringRule> updateRecurringRule(RecurringRule rule) async {
    await _database.updateRecurringRule(_data(rule));
    return rule;
  }

  Future<void> deleteRecurringRule(String id) =>
      _database.deleteRecurringRuleById(id);

  Future<List<RecurringRule>> getAllRecurringRules() async =>
      (await _database.getAllRecurringRules()).map(_map).toList();

  Future<List<RecurringRule>> getActiveRecurringRules() async =>
      (await _database.getActiveRecurringRules()).map(_map).toList();
}

final recurringRepositoryProvider = Provider<RecurringRuleStore>(
  (ref) => RecurringRuleStore(ref.watch(databaseProvider)),
);

final allRecurringRulesProvider = FutureProvider<List<RecurringRule>>(
  (ref) => ref.watch(recurringRepositoryProvider).getAllRecurringRules(),
);

final activeRecurringRulesProvider = FutureProvider<List<RecurringRule>>(
  (ref) => ref.watch(recurringRepositoryProvider).getActiveRecurringRules(),
);

class RecurringNotifier extends StateNotifier<AsyncValue<RecurringRule>> {
  final RecurringRuleStore _store;
  final Ref _ref;

  RecurringNotifier(this._store, this._ref)
      : super(const AsyncValue.loading());

  void _refresh() {
    _ref.invalidate(allRecurringRulesProvider);
    _ref.invalidate(activeRecurringRulesProvider);
  }

  Future<void> addRecurringRule(RecurringRule rule) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _store.addRecurringRule(rule));
      _refresh();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateRecurringRule(RecurringRule rule) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _store.updateRecurringRule(rule));
      _refresh();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> deleteRecurringRule(String id) async {
    try {
      await _store.deleteRecurringRule(id);
      _refresh();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final recurringNotifierProvider =
    StateNotifierProvider<RecurringNotifier, AsyncValue<RecurringRule>>(
  (ref) => RecurringNotifier(ref.watch(recurringRepositoryProvider), ref),
);
