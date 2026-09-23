/// Recurring expense entity
import 'package:equatable/equatable.dart';

enum RecurringFrequency { weekly, monthly, quarterly, yearly }

class RecurringRule extends Equatable {
  final String id;
  final String title;
  final double amount;
  final String categoryId;
  final String paymentMethod;
  final RecurringFrequency frequency;
  final DateTime startDate;
  final DateTime nextOccurrenceDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecurringRule({
    required this.id,
    required this.title,
    required this.amount,
    required this.categoryId,
    required this.paymentMethod,
    required this.frequency,
    required this.startDate,
    required this.nextOccurrenceDate,
    this.endDate,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  RecurringRule copyWith({
    String? id,
    String? title,
    double? amount,
    String? categoryId,
    String? paymentMethod,
    RecurringFrequency? frequency,
    DateTime? startDate,
    DateTime? nextOccurrenceDate,
    DateTime? endDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecurringRule(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      nextOccurrenceDate: nextOccurrenceDate ?? this.nextOccurrenceDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    amount,
    categoryId,
    paymentMethod,
    frequency,
    startDate,
    nextOccurrenceDate,
    endDate,
    isActive,
    createdAt,
    updatedAt,
  ];
}
