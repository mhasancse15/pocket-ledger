import 'package:drift/drift.dart' as drift;

import 'package:my_wallet/core/errors/failures.dart';
import 'package:my_wallet/data/datasources/drift/database.dart';
import 'package:my_wallet/data/models/transaction_model.dart';
import 'package:my_wallet/domain/entities/transaction.dart';
import 'package:my_wallet/domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final AppDatabase _database;

  TransactionRepositoryImpl(this._database);

  TransactionModel _model(TransactionTableData row) => TransactionModel.fromJson({
        'id': row.id,
        'type': row.type,
        'amount': row.amount,
        'categoryId': row.categoryId,
        'date': row.date.toIso8601String(),
        'paymentMethod': row.paymentMethod,
        'note': row.note,
        'recurringRuleId': row.recurringRuleId,
        'createdAt': row.createdAt.toIso8601String(),
        'updatedAt': row.updatedAt.toIso8601String(),
      });

  TransactionTableCompanion _companion(Transaction transaction) {
    return TransactionTableCompanion.insert(
      id: transaction.id,
      type: transaction.type.name,
      amount: transaction.amount,
      categoryId: transaction.categoryId,
      date: transaction.date,
      paymentMethod: transaction.paymentMethod.name,
      note: drift.Value(transaction.note),
      recurringRuleId: drift.Value(transaction.recurringRuleId),
      createdAt: transaction.createdAt,
      updatedAt: transaction.updatedAt,
    );
  }

  @override
  Future<Either<Failure, Transaction>> addTransaction(Transaction transaction) async {
    try {
      final value = transaction.id.isEmpty
          ? transaction.copyWith(id: DateTime.now().microsecondsSinceEpoch.toString())
          : transaction;
      await _database.insertTransaction(_companion(value));
      return Either.right(value);
    } catch (error) {
      return Either.left(DatabaseFailure('Failed to add transaction: $error'));
    }
  }

  @override
  Future<Either<Failure, Transaction>> updateTransaction(Transaction transaction) async {
    try {
      final updated = transaction.copyWith(updatedAt: DateTime.now());
      final changed = await _database.updateTransaction(
        _modelToData(updated),
      );
      return changed
          ? Either.right(updated)
          : Either.left(NotFoundFailure('Transaction not found'));
    } catch (error) {
      return Either.left(DatabaseFailure('Failed to update transaction: $error'));
    }
  }

  TransactionTableData _modelToData(Transaction transaction) {
    return TransactionTableData(
      id: transaction.id,
      type: transaction.type.name,
      amount: transaction.amount,
      categoryId: transaction.categoryId,
      date: transaction.date,
      paymentMethod: transaction.paymentMethod.name,
      note: transaction.note,
      recurringRuleId: transaction.recurringRuleId,
      createdAt: transaction.createdAt,
      updatedAt: transaction.updatedAt,
    );
  }

  @override
  Future<Either<Failure, void>> deleteTransaction(String transactionId) async {
    try {
      final deleted = await _database.deleteTransactionById(transactionId);
      return deleted == 0
          ? Either.left(NotFoundFailure('Transaction not found'))
          : Either.right(null);
    } catch (error) {
      return Either.left(DatabaseFailure('Failed to delete transaction: $error'));
    }
  }

  @override
  Future<Either<Failure, Transaction>> getTransaction(String id) async {
    try {
      final row = await _database.getTransactionById(id);
      return row == null
          ? Either.left(NotFoundFailure('Transaction not found'))
          : Either.right(_model(row));
    } catch (error) {
      return Either.left(DatabaseFailure('Failed to fetch transaction: $error'));
    }
  }

  @override
  Future<Either<Failure, List<Transaction>>> getAllTransactions() async {
    try {
      final rows = await _database.getAllTransactions();
      return Either.right(rows.map(_model).toList());
    } catch (error) {
      return Either.left(DatabaseFailure('Failed to fetch transactions: $error'));
    }
  }

  @override
  Future<Either<Failure, List<Transaction>>> getTransactionsByMonth(
      int year, int month) async {
    try {
      final rows = await _database.getTransactionsByMonth(year, month);
      return Either.right(rows.map(_model).toList());
    } catch (error) {
      return Either.left(DatabaseFailure('Failed to fetch transactions: $error'));
    }
  }

  @override
  Future<Either<Failure, List<Transaction>>> searchTransactions({
    required DateTime startDate,
    required DateTime endDate,
    String? categoryId,
    String? paymentMethod,
    TransactionType? type,
    String? keyword,
  }) async {
    final result = await getAllTransactions();
    return result.fold(
      Either.left,
      (transactions) => Either.right(transactions.where((transaction) {
        final inRange = !transaction.date.isBefore(startDate) &&
            transaction.date.isBefore(endDate);
        final matchesCategory =
            categoryId == null || transaction.categoryId == categoryId;
        final matchesMethod = paymentMethod == null ||
            transaction.paymentMethod.name == paymentMethod;
        final matchesType = type == null || transaction.type == type;
        final matchesKeyword = keyword == null ||
            (transaction.note ?? '').toLowerCase().contains(keyword.toLowerCase());
        return inRange &&
            matchesCategory &&
            matchesMethod &&
            matchesType &&
            matchesKeyword;
      }).toList()),
    );
  }

  @override
  Future<Either<Failure, double>> getMonthlyTotal(
      int year, int month, TransactionType type) async {
    final result = await getTransactionsByMonth(year, month);
    return result.fold(
      Either.left,
      (transactions) => Either.right(transactions
          .where((transaction) => transaction.type == type)
          .fold<double>(0.0, (sum, transaction) => sum + transaction.amount)),
    );
  }
}
