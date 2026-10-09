// drift's check() constraints refer to the column they belong to.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import '../logic/dates.dart';
import '../logic/models.dart';

/// Stores a calendar day as `YYYY-MM-DD` text and reads it back as UTC
/// midnight, so dates never shift with time zones.
class DateOnlyConverter extends TypeConverter<DateTime, String> {
  const DateOnlyConverter();

  @override
  DateTime fromSql(String fromDb) => parseIsoDate(fromDb)!;

  @override
  String toSql(DateTime value) => isoDate(value);
}

/// Groups such as Accommodation, Studies, Transport. Income has one group.
@DataClassName('CategoryGroup')
class CategoryGroups extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get name => text().withLength(min: 1, max: 40)();

  /// An emoji.
  TextColumn get icon => text()();
  IntColumn get sortOrder => integer()();
  TextColumn get kind => textEnum<GroupKind>()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Income or spending categories. Names are unique ignoring case (checked
/// in code and by a unique index on lower(name)).
@DataClassName('BudgetCategory')
@TableIndex.sql('CREATE UNIQUE INDEX IF NOT EXISTS categories_name_unique ON categories (lower(name))')
class Categories extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get emoji => text()();
  TextColumn get groupId => text().references(CategoryGroups, #id)();

  /// Whole cents.
  IntColumn get monthlyBudget => integer().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Money in, money out, and moves into or out of savings.
@DataClassName('Txn')
class Transactions extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get kind => textEnum<TxnKind>()();

  /// Whole cents, above zero.
  IntColumn get amount => integer().check(amount.isBiggerThanValue(0))();
  TextColumn get date => text().map(const DateOnlyConverter())();
  TextColumn get note => text().withLength(max: 60).withDefault(const Constant(''))();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get goalId => text().nullable().references(SavingsGoals, #id)();

  /// Who the money belongs to (added in schema 2).
  TextColumn get person => textEnum<Person>().withDefault(const Constant('joint'))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SavingsGoal')
class SavingsGoals extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get emoji => text()();

  /// Whole cents; null means the goal is just a pot.
  IntColumn get targetAmount => integer().nullable()();
  TextColumn get targetDate => text().map(const DateOnlyConverter()).nullable()();
  IntColumn get startingBalance => integer().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Debt')
class Debts extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get lender => text().nullable()();

  /// Whole cents.
  IntColumn get balanceOnStartDate => integer().withDefault(const Constant(0))();
  TextColumn get startDate => text().map(const DateOnlyConverter())();
  RealColumn get annualInterestRatePercent => real().withDefault(const Constant(0))();
  TextColumn get linkedCategoryId => text().nullable().references(Categories, #id)();
  IntColumn get latestStatementBalance => integer().nullable()();
  TextColumn get latestStatementDate => text().map(const DateOnlyConverter()).nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One part of a mortgage (a Dutch mortgage often has several parts with
/// their own type and rate). The schedule runs from [balance] on
/// [balanceDate], with one payment a month until [endDate]. When the rate
/// changes, the balance, date and rate are updated together.
@DataClassName('Mortgage')
class Mortgages extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get lender => text().nullable()();
  TextColumn get type => textEnum<MortgageType>()();

  /// Whole cents still owed on [balanceDate].
  IntColumn get balance => integer()();
  TextColumn get balanceDate => text().map(const DateOnlyConverter())();

  /// The month of the last payment.
  TextColumn get endDate => text().map(const DateOnlyConverter())();
  RealColumn get annualInterestRatePercent => real()();
  TextColumn get fixedRateUntil => text().map(const DateOnlyConverter()).nullable()();

  /// Expenses in this category are the actual payments.
  TextColumn get linkedCategoryId => text().nullable().references(Categories, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One-row settings table (id is always 1).
@DataClassName('AppSettings')
class Settings extends Table {
  IntColumn get id => integer()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get budgetMonthStartDay =>
      integer().withDefault(const Constant(1)).check(budgetMonthStartDay.isBetweenValues(1, 28))();
  BoolColumn get appLockEnabled => boolean().withDefault(const Constant(false))();
  BoolColumn get hasCompletedOnboarding => boolean().withDefault(const Constant(false))();

  /// When the student last saved a backup.
  DateTimeColumn get lastBackupAt => dateTime().nullable()();

  /// The backup reminder stays hidden until this moment.
  DateTimeColumn get backupReminderHiddenUntil => dateTime().nullable()();

  /// The two people in the household (added in schema 2).
  TextColumn get partner1Name => text().withDefault(const Constant('Partner 1'))();
  TextColumn get partner2Name => text().withDefault(const Constant('Partner 2'))();

  @override
  Set<Column> get primaryKey => {id};
}
