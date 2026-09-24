import 'package:equatable/equatable.dart';

enum BudgetScope { monthly, category, wallet }

class Budget extends Equatable {
  const Budget({
    required this.id,
    required this.year,
    required this.month,
    required this.scope,
    required this.scopeKey,
    required this.amount,
    required this.rollover,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final int year;
  final int month;
  final BudgetScope scope;
  final String scopeKey;
  final double amount;
  final bool rollover;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
        id,
        year,
        month,
        scope,
        scopeKey,
        amount,
        rollover,
        createdAt,
        updatedAt,
      ];
}
