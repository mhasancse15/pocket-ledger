import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/drift/database.dart';
import '../../domain/entities/monthly_saving.dart';
import 'database_provider.dart';
import 'transaction_provider.dart';

final monthlySavingEntriesProvider =
    FutureProvider.family<List<MonthlySavingEntry>, (int, int)>((
      ref,
      month,
    ) async {
      final rows = await ref
          .watch(databaseProvider)
          .getMonthlySavingEntries(month.$1, month.$2);
      return rows.map(_fromRow).toList();
    });

final allMonthlySavingEntriesProvider =
    FutureProvider<List<MonthlySavingEntry>>((ref) async {
      final rows = await ref
          .watch(databaseProvider)
          .getAllMonthlySavingEntries();
      return rows.map(_fromRow).toList();
    });

final monthlySavingStoreProvider = Provider<MonthlySavingStore>(
  (ref) => MonthlySavingStore(ref.watch(databaseProvider), ref),
);

class MonthlySavingStore {
  MonthlySavingStore(this._database, this._ref);

  final AppDatabase _database;
  final Ref _ref;

  Future<void> add(MonthlySavingEntry entry) async {
    await _database.insertMonthlySavingEntry(
      MonthlySavingEntryTableCompanion.insert(
        id: entry.id,
        year: entry.year,
        month: entry.month,
        amount: entry.amount,
        date: entry.date,
        note: Value(entry.note),
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt,
      ),
    );
    _ref.invalidate(monthlySavingEntriesProvider((entry.year, entry.month)));
    _ref.invalidate(allMonthlySavingEntriesProvider);
  }

  Future<void> delete(MonthlySavingEntry entry) async {
    await _database.deleteMonthlySavingEntry(entry.id);
    _ref.invalidate(monthlySavingEntriesProvider((entry.year, entry.month)));
    _ref.invalidate(allMonthlySavingEntriesProvider);
  }

  Future<bool> carryForwardMonth({
    required MonthlySavingSummary summary,
    required DateTime incomeDate,
  }) async {
    final finalized = await _database.carryForwardMonthlySurplus(
      sourceYear: summary.year,
      sourceMonth: summary.month,
      incomeDate: incomeDate,
      amount: summary.surplus > summary.saved ? summary.surplus : summary.saved,
      alreadySaved: summary.saved,
      createdAt: DateTime.now(),
    );
    if (finalized) {
      _ref.invalidate(monthlyTransactionsProvider);
      _ref.invalidate(monthlyTotalProvider);
      _ref.invalidate(allTransactionsProvider);
      _ref.invalidate(allMonthlySavingEntriesProvider);
      _ref.invalidate(
        monthlySavingEntriesProvider((summary.year, summary.month)),
      );
    }
    return finalized;
  }
}

MonthlySavingEntry _fromRow(MonthlySavingEntryTableData row) =>
    MonthlySavingEntry(
      id: row.id,
      year: row.year,
      month: row.month,
      amount: row.amount,
      date: row.date,
      source: MonthlySavingSource.values.firstWhere(
        (source) => source.name == row.source,
        orElse: () => MonthlySavingSource.manual,
      ),
      note: row.note,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
