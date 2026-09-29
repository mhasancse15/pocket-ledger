import 'package:equatable/equatable.dart';

enum RecurringFrequency { daily, weekly, monthly, quarterly, yearly }

/// A rule that describes an expense generated on a recurring schedule.
class RecurringRule extends Equatable {
  final String id;
  final String title;
  final double amount;
  final String categoryId;
  final String paymentMethod;
  final RecurringFrequency frequency;
  final DateTime startDate;
  final DateTime nextOccurrenceDate;
  final int anchorDay;
  final String? note;
  final DateTime? endDate;
  final bool isActive;
  final bool autoCreateTransaction;
  final DateTime? lastGeneratedAt;
  final int? reminderDays;
  final int? notificationId;
  final DateTime createdAt;
  final DateTime updatedAt;

  RecurringRule({
    required this.id,
    required this.title,
    required this.amount,
    required this.categoryId,
    required this.paymentMethod,
    required this.frequency,
    required this.startDate,
    required this.nextOccurrenceDate,
    int? anchorDay,
    this.note,
    this.endDate,
    this.isActive = true,
    this.autoCreateTransaction = true,
    this.lastGeneratedAt,
    this.reminderDays,
    this.notificationId,
    required this.createdAt,
    required this.updatedAt,
  }) : anchorDay = anchorDay ?? startDate.day;

  RecurringRule copyWith({
    String? id,
    String? title,
    double? amount,
    String? categoryId,
    String? paymentMethod,
    RecurringFrequency? frequency,
    DateTime? startDate,
    DateTime? nextOccurrenceDate,
    int? anchorDay,
    String? note,
    bool clearNote = false,
    DateTime? endDate,
    bool clearEndDate = false,
    bool? isActive,
    bool? autoCreateTransaction,
    DateTime? lastGeneratedAt,
    bool clearLastGeneratedAt = false,
    int? reminderDays,
    bool clearReminder = false,
    int? notificationId,
    bool clearNotificationId = false,
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
      anchorDay: anchorDay ?? this.anchorDay,
      note: clearNote ? null : note ?? this.note,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      autoCreateTransaction:
          autoCreateTransaction ?? this.autoCreateTransaction,
      lastGeneratedAt: clearLastGeneratedAt
          ? null
          : lastGeneratedAt ?? this.lastGeneratedAt,
      reminderDays: clearReminder ? null : reminderDays ?? this.reminderDays,
      notificationId: clearNotificationId
          ? null
          : notificationId ?? this.notificationId,
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
    anchorDay,
    note,
    endDate,
    isActive,
    autoCreateTransaction,
    lastGeneratedAt,
    reminderDays,
    notificationId,
    createdAt,
    updatedAt,
  ];
}

enum RecurringOccurrenceStatus { generated, skipped }

class RecurringOccurrence extends Equatable {
  const RecurringOccurrence({
    required this.id,
    required this.recurringRuleId,
    required this.scheduledDate,
    required this.status,
    required this.createdAt,
    this.transactionId,
  });

  final String id;
  final String recurringRuleId;
  final DateTime scheduledDate;
  final String? transactionId;
  final RecurringOccurrenceStatus status;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    recurringRuleId,
    scheduledDate,
    transactionId,
    status,
    createdAt,
  ];
}
