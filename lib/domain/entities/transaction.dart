/// Domain Entity for Transaction
import 'package:equatable/equatable.dart';

enum TransactionType { income, expense }

enum PaymentMethod { cash, bankTransfer, debitCard, creditCard, mobileWallet, other }

class Transaction extends Equatable {
  final String id;
  final TransactionType type;
  final double amount;
  final String categoryId;
  final DateTime date;
  final PaymentMethod paymentMethod;
  final String? note;
  final String? recurringRuleId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.date,
    required this.paymentMethod,
    this.note,
    this.recurringRuleId,
    required this.createdAt,
    required this.updatedAt,
  });

  Transaction copyWith({
    String? id,
    TransactionType? type,
    double? amount,
    String? categoryId,
    DateTime? date,
    PaymentMethod? paymentMethod,
    String? note,
    String? recurringRuleId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      note: note ?? this.note,
      recurringRuleId: recurringRuleId ?? this.recurringRuleId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    amount,
    categoryId,
    date,
    paymentMethod,
    note,
    recurringRuleId,
    createdAt,
    updatedAt,
  ];
}
