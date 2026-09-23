import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/drift/database.dart';
import '../../data/models/monthly_limit_model.dart';
import '../../domain/entities/monthly_limit.dart';
import 'database_provider.dart';

class MonthlyLimitStore {
  final AppDatabase _database;

  MonthlyLimitStore(this._database);

  Future<MonthlyLimit?> getMonthlyLimit(int year, int month) async {
    final row = await _database.getMonthlyLimit(year, month);
    return row == null
        ? null
        : MonthlyLimitModel.fromJson({
            'id': row.id,
            'year': row.year,
            'month': row.month,
            'amount': row.amount,
            'createdAt': row.createdAt.toIso8601String(),
            'updatedAt': row.updatedAt.toIso8601String(),
          });
  }

  Future<MonthlyLimit> setMonthlyLimit(MonthlyLimit limit) async {
    final existing = await _database.getMonthlyLimit(limit.year, limit.month);
    if (existing == null) {
      await _database.setMonthlyLimit(MonthlyLimitTableCompanion.insert(
        id: limit.id,
        year: limit.year,
        month: limit.month,
        amount: limit.amount,
        createdAt: limit.createdAt,
        updatedAt: limit.updatedAt,
      ));
    } else {
      final updated = await _database.updateMonthlyLimit(
        MonthlyLimitTableData(
          id: existing.id,
          year: limit.year,
          month: limit.month,
          amount: limit.amount,
          createdAt: existing.createdAt,
          updatedAt: limit.updatedAt,
        ),
      );
      if (!updated) {
        throw StateError('The monthly target could not be updated.');
      }
    }
    return limit;
  }

  Future<void> deleteMonthlyLimit(int year, int month) =>
      _database.deleteMonthlyLimit(year, month);

  Future<List<MonthlyLimit>> getAllLimits() async {
    final rows = await _database.getAllMonthlyLimits();
    return rows
        .map((row) => MonthlyLimitModel.fromJson({
              'id': row.id,
              'year': row.year,
              'month': row.month,
              'amount': row.amount,
              'createdAt': row.createdAt.toIso8601String(),
              'updatedAt': row.updatedAt.toIso8601String(),
            }))
        .toList();
  }
}

final limitRepositoryProvider = Provider<MonthlyLimitStore>(
  (ref) => MonthlyLimitStore(ref.watch(databaseProvider)),
);

final monthlyLimitProvider =
    FutureProvider.family<MonthlyLimit?, (int, int)>((ref, params) {
  return ref.watch(limitRepositoryProvider).getMonthlyLimit(params.$1, params.$2);
});

final allLimitsProvider = FutureProvider<List<MonthlyLimit>>(
  (ref) => ref.watch(limitRepositoryProvider).getAllLimits(),
);

class LimitNotifier extends StateNotifier<AsyncValue<MonthlyLimit>> {
  final MonthlyLimitStore _store;
  final Ref _ref;

  LimitNotifier(this._store, this._ref) : super(const AsyncValue.loading());

  Future<void> setMonthlyLimit(MonthlyLimit limit) async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _store.setMonthlyLimit(limit));
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
    _ref.invalidate(monthlyLimitProvider((limit.year, limit.month)));
    _ref.invalidate(allLimitsProvider);
  }

  Future<void> deleteMonthlyLimit(int year, int month) async {
    try {
      await _store.deleteMonthlyLimit(year, month);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      Error.throwWithStackTrace(error, stackTrace);
    }
    _ref.invalidate(monthlyLimitProvider((year, month)));
    _ref.invalidate(allLimitsProvider);
  }
}

final limitNotifierProvider =
    StateNotifierProvider<LimitNotifier, AsyncValue<MonthlyLimit>>(
  (ref) => LimitNotifier(ref.watch(limitRepositoryProvider), ref),
);
