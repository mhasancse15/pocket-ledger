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
    {year, month},
  ];
}

class BudgetTable extends Table {
  TextColumn get id => text()();
  IntColumn get year => integer()();
  IntColumn get month => integer()();
  TextColumn get scope => text()(); // monthly, category, wallet
  TextColumn get scopeKey => text()(); // all, category id, payment method
  RealColumn get amount => real()();
  BoolColumn get rollover => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {year, month, scope, scopeKey},
  ];
}

/// Drift table definition for Recurring Rules
class RecurringRuleTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  RealColumn get amount => real()();
  TextColumn get categoryId => text()();
  TextColumn get paymentMethod => text()();
  TextColumn get frequency =>
      text()(); // 'weekly', 'monthly', 'quarterly', 'yearly'
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get nextOccurrenceDate => dateTime()();
  IntColumn get anchorDay => integer().withDefault(const Constant(1))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get autoCreateTransaction =>
      boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastGeneratedAt => dateTime().nullable()();
  IntColumn get reminderDays => integer().nullable()();
  IntColumn get notificationId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class RecurringOccurrenceTable extends Table {
  TextColumn get id => text()();
  TextColumn get recurringRuleId =>
      text().references(RecurringRuleTable, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get scheduledDate => dateTime()();
  TextColumn get transactionId => text().nullable()();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {recurringRuleId, scheduledDate},
  ];
}

class BudgetNotificationStates extends Table {
  TextColumn get sourceId => text()();
  IntColumn get year => integer()();
  IntColumn get month => integer()();
  IntColumn get warningLevel => integer()();
  DateTimeColumn get notifiedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {sourceId, year, month};
}

class MonthlySavingEntryTable extends Table {
  TextColumn get id => text()();
  IntColumn get year => integer()();
  IntColumn get month => integer()();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class MonthlySavingFinalizationTable extends Table {
  IntColumn get year => integer()();
  IntColumn get month => integer()();
  DateTimeColumn get finalizedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {year, month};
}
