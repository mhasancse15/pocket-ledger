

import '../../core/errors/failures.dart';
import '../entities/transaction.dart';

abstract class TransactionRepository {
  Future<Either<Failure, Transaction>> addTransaction(Transaction transaction);
  Future<Either<Failure, Transaction>> updateTransaction(Transaction transaction);
  Future<Either<Failure, void>> deleteTransaction(String transactionId);
  Future<Either<Failure, Transaction>> getTransaction(String id);
  Future<Either<Failure, List<Transaction>>> getAllTransactions();
  Future<Either<Failure, List<Transaction>>> getTransactionsByMonth(int year, int month);
  Future<Either<Failure, List<Transaction>>> searchTransactions({
    required DateTime startDate,
    required DateTime endDate,
    String? categoryId,
    String? paymentMethod,
    TransactionType? type,
    String? keyword,
  });
  Future<Either<Failure, double>> getMonthlyTotal(int year, int month, TransactionType type);
}

class Either<L, R> {
  final L? _left;
  final R? _right;
  final bool _isRight;

  Either.left(this._left) : _right = null, _isRight = false;
  Either.right(this._right) : _left = null, _isRight = true;

  T fold<T>(T Function(L) ifLeft, T Function(R) ifRight) {
    return _isRight ? ifRight(_right as R) : ifLeft(_left as L);
  }

  bool get isRight => _isRight;
  bool get isLeft => !_isRight;
}
