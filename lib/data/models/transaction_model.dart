import '../../domain/entities/transaction.dart';

/// Transaction model - data layer


class TransactionModel extends Transaction {
  const TransactionModel({
    required super.id,
    required super.type,
    required super.amount,
    required super.categoryId,
    required super.date,
    required super.paymentMethod,
    super.note,
    super.recurringRuleId,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Convert to JSON for Drift storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.toString().split('.').last,
    'amount': amount,
    'categoryId': categoryId,
    'date': date.toIso8601String(),
    'paymentMethod': paymentMethod.toString().split('.').last,
    'note': note,
    'recurringRuleId': recurringRuleId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// Convert from JSON (from Drift database)
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      type: json['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      amount: (json['amount'] as num).toDouble(),
      categoryId: json['categoryId'] as String,
      date: DateTime.parse(json['date'] as String),
      paymentMethod: _parsePaymentMethod(json['paymentMethod'] as String),
      note: json['note'] as String?,
      recurringRuleId: json['recurringRuleId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Convert to domain entity
  Transaction toEntity() => Transaction(
    id: id,
    type: type,
    amount: amount,
    categoryId: categoryId,
    date: date,
    paymentMethod: paymentMethod,
    note: note,
    recurringRuleId: recurringRuleId,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  static PaymentMethod _parsePaymentMethod(String value) {
    return PaymentMethod.values.firstWhere(
      (e) => e.toString().split('.').last == value,
      orElse: () => PaymentMethod.other,
    );
  }
}
