/// Domain Entity for Monthly Limit
import 'package:equatable/equatable.dart';

class MonthlyLimit extends Equatable {
  final String id;
  final int year;
  final int month;
  final double amount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MonthlyLimit({
    required this.id,
    required this.year,
    required this.month,
    required this.amount,
    required this.createdAt,
    required this.updatedAt,
  });

  MonthlyLimit copyWith({
    String? id,
    int? year,
    int? month,
    double? amount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MonthlyLimit(
      id: id ?? this.id,
      year: year ?? this.year,
      month: month ?? this.month,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object> get props => [id, year, month, amount, createdAt, updatedAt];
}
