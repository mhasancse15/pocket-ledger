import '../../core/errors/failures.dart';
import '../entities/transaction.dart';
import '../repositories/transaction_repository.dart';

abstract class UseCase<Type, Params> {
  Future<Either<Failure, Type>> call(Params params);
}

class AddTransactionUseCase implements UseCase<Transaction, AddTransactionParams> {
  final TransactionRepository repository;

  AddTransactionUseCase(this.repository);

  @override
  Future<Either<Failure, Transaction>> call(AddTransactionParams params) async {
    return repository.addTransaction(params.toTransaction());
  }
}

class AddTransactionParams {
  final TransactionType type;
  final double amount;
  final String categoryId;
  final DateTime date;
  final PaymentMethod paymentMethod;
  final String? note;
  final String? recurringRuleId;

  AddTransactionParams({
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.date,
    required this.paymentMethod,
    this.note,
    this.recurringRuleId,
  });

  Transaction toTransaction() => Transaction(
    id: '',
    type: type,
    amount: amount,
    categoryId: categoryId,
    date: date,
    paymentMethod: paymentMethod,
    note: note,
    recurringRuleId: recurringRuleId,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}
