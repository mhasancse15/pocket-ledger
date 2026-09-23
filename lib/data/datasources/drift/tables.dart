import 'package:drift/drift.dart';

/// Drift table definition for Transactions
class TransactionTable extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // 'income' or 'expense'
  RealColumn get amount => real()();
  TextColumn get categoryId => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get paymentMethod => text()();
  TextColumn get note => text().nullable()();
  TextColumn get recurringRuleId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Drift table definition for Categories
class CategoryTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // 'income' or 'expense'
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Drift table definition for Monthly Limits / Budgets
class MonthlyLimitTable extends Table {
  TextColumn get id => text()();
  IntColumn get year => integer()();
  IntColumn get month => integer()();
  RealColumn get amount => real()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {year, month}
      ];
}

/// Drift table definition for Recurring Rules
class RecurringRuleTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  RealColumn get amount => real()();
  TextColumn get categoryId => text()();
  TextColumn get paymentMethod => text()();
  TextColumn get frequency => text()(); // 'weekly', 'monthly', 'quarterly', 'yearly'
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get nextOccurrenceDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
