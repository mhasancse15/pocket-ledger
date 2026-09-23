import '../../domain/entities/monthly_limit.dart';

/// Monthly Limit model - data layer


class MonthlyLimitModel extends MonthlyLimit {
  const MonthlyLimitModel({
    required super.id,
    required super.year,
    required super.month,
    required super.amount,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Convert to JSON for Drift storage
  Map<String, dynamic> toJson() => {
    'id': id,
    'year': year,
    'month': month,
    'amount': amount,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// Convert from JSON (from Drift database)
  factory MonthlyLimitModel.fromJson(Map<String, dynamic> json) {
    return MonthlyLimitModel(
      id: json['id'] as String,
      year: json['year'] as int,
      month: json['month'] as int,
      amount: (json['amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Convert to domain entity
  MonthlyLimit toEntity() => MonthlyLimit(
    id: id,
    year: year,
    month: month,
    amount: amount,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  /// Copy with modifications
  MonthlyLimitModel copyWith({
    String? id,
    int? year,
    int? month,
    double? amount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MonthlyLimitModel(
      id: id ?? this.id,
      year: year ?? this.year,
      month: month ?? this.month,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
