import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../logic/dates.dart';
import '../logic/models.dart';
import '../logic/validation.dart';
import 'app_data.dart';
import 'backup.dart';
import 'database.dart';
import 'seed.dart';

/// What the student entered in the Add sheet.
class TxnDraft {
  const TxnDraft({
    required this.kind,
    required this.amount,
    required this.date,
    this.note = '',
    this.categoryId,
    this.goalId,
  });

  final TxnKind kind;
  final int amount;
  final DateTime date;
  final String note;
  final String? categoryId;
  final String? goalId;

  /// Checks the rules for each kind; returns an error message or null.
  String? validate(DateTime today) {
    if (amount <= 0) return 'Enter an amount above R0';
    if (amount > 1000000000) return 'Enter an amount up to R10 000 000';
    final dateError = Validation.date(date, today);
    if (dateError != null) return dateError;
    final noteError = Validation.note(note);
    if (noteError != null) return noteError;
    switch (kind) {
      case TxnKind.income:
      case TxnKind.expense:
        if (categoryId == null) return 'Pick a category';
      case TxnKind.toSavings:
      case TxnKind.fromSavings:
        if (goalId == null) return 'Pick a goal';
    }
    return null;
  }
}

/// Holds the latest [AppData] and performs every change to the database.
/// Screens listen to it and rebuild when [data] changes.
class BudgetStore extends ChangeNotifier {
  BudgetStore(this.db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _clock;
  static const _uuid = Uuid();

  AppData? _data;

  /// The latest snapshot. Only null before [init] completes.
  AppData get data => _data!;
  bool get isReady => _data != null;

  DateTime now() => _clock();
  DateTime today() => dateOnly(_clock());

  /// Seeds the starter budget on first launch and loads everything.
  Future<void> init() async {
    await seedIfEmpty(db, now: now());
    await reload();
  }

  Future<void> reload() async {
    final results = await Future.wait([
      db.select(db.settings).getSingle(),
      db.select(db.categoryGroups).get(),
      db.select(db.categories).get(),
      db.select(db.transactions).get(),
      db.select(db.savingsGoals).get(),
      db.select(db.debts).get(),
    ]);
    _data = AppData(
      settings: results[0] as AppSettings,
      groups: results[1] as List<CategoryGroup>,
      categories: results[2] as List<BudgetCategory>,
      transactions: results[3] as List<Txn>,
      goals: results[4] as List<SavingsGoal>,
      debts: results[5] as List<Debt>,
    );
    notifyListeners();
  }

  // Transactions -----------------------------------------------------------

  Future<Txn> addTransaction(TxnDraft draft) async {
    final error = draft.validate(today());
    if (error != null) throw ArgumentError(error);
    final row = Txn(
      id: _uuid.v4(),
      createdAt: now().toUtc(),
      kind: draft.kind,
      amount: draft.amount,
      date: dateOnly(draft.date),
      note: draft.note.trim(),
      categoryId: draft.kind == TxnKind.toSavings ? null : draft.categoryId,
      goalId: draft.kind == TxnKind.income || draft.kind == TxnKind.expense ? null : draft.goalId,
    );
    await db.into(db.transactions).insert(row);
    await reload();
    return row;
  }

  Future<Txn> updateTransaction(String id, TxnDraft draft) async {
    final error = draft.validate(today());
    if (error != null) throw ArgumentError(error);
    final existing = data.transactions.firstWhere((t) => t.id == id);
    final row = existing.copyWith(
      kind: draft.kind,
      amount: draft.amount,
      date: dateOnly(draft.date),
      note: draft.note.trim(),
      categoryId: Value(draft.kind == TxnKind.toSavings ? null : draft.categoryId),
      goalId: Value(draft.kind == TxnKind.income || draft.kind == TxnKind.expense ? null : draft.goalId),
    );
    await db.update(db.transactions).replace(row);
    await reload();
    return row;
  }

  /// Deletes a transaction and returns it so it can be put back with
  /// [restoreTransaction].
  Future<Txn?> deleteTransaction(String id) async {
    final existing = data.transactions.where((t) => t.id == id).firstOrNull;
    if (existing == null) return null;
    await (db.delete(db.transactions)..where((t) => t.id.equals(id))).go();
    await reload();
    return existing;
  }

  Future<void> restoreTransaction(Txn row) async {
    await db.into(db.transactions).insertOnConflictUpdate(row);
    await reload();
  }

  // Categories and groups --------------------------------------------------

  String? categoryNameError(String name, {String? exceptId}) => Validation.categoryName(
        name,
        data.categories.where((c) => c.id != exceptId).map((c) => c.name),
      );

  Future<BudgetCategory> addCategory({
    required String groupId,
    required String name,
    required String emoji,
    int monthlyBudget = 0,
  }) async {
    final error = categoryNameError(name);
    if (error != null) throw ArgumentError(error);
    final siblings = data.categoriesIn(groupId, includeArchived: true);
    final row = BudgetCategory(
      id: _uuid.v4(),
      createdAt: now().toUtc(),
      name: name.trim(),
      emoji: emoji,
      groupId: groupId,
      monthlyBudget: monthlyBudget,
      sortOrder: siblings.isEmpty ? 0 : siblings.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b) + 1,
      isArchived: false,
    );
    await db.into(db.categories).insert(row);
    await reload();
    return row;
  }

  Future<void> updateCategory(BudgetCategory category, {String? name, String? emoji, String? groupId}) async {
    if (name != null) {
      final error = categoryNameError(name, exceptId: category.id);
      if (error != null) throw ArgumentError(error);
    }
    await db.update(db.categories).replace(category.copyWith(
          name: name?.trim() ?? category.name,
          emoji: emoji ?? category.emoji,
          groupId: groupId ?? category.groupId,
        ));
    await reload();
  }

  Future<void> setCategoryBudget(String categoryId, int cents) async {
    await (db.update(db.categories)..where((c) => c.id.equals(categoryId)))
        .write(CategoriesCompanion(monthlyBudget: Value(cents)));
    await reload();
  }

  /// Sets several budgets at once (used by onboarding).
  Future<void> setCategoryBudgets(Map<String, int> budgets) async {
    await db.transaction(() async {
      for (final entry in budgets.entries) {
        await (db.update(db.categories)..where((c) => c.id.equals(entry.key)))
            .write(CategoriesCompanion(monthlyBudget: Value(entry.value)));
      }
    });
    await reload();
  }

  Future<void> setCategoryArchived(String categoryId, bool archived) async {
    await (db.update(db.categories)..where((c) => c.id.equals(categoryId)))
        .write(CategoriesCompanion(isArchived: Value(archived)));
    await reload();
  }

  /// Saves the order of the categories in [orderedIds].
  Future<void> reorderCategories(List<String> orderedIds) async {
    await db.transaction(() async {
      for (final (i, id) in orderedIds.indexed) {
        await (db.update(db.categories)..where((c) => c.id.equals(id))).write(CategoriesCompanion(sortOrder: Value(i)));
      }
    });
    await reload();
  }

  Future<CategoryGroup> addGroup({required String name, required String icon}) async {
    final error = Validation.name(name, thing: 'the group');
    if (error != null) throw ArgumentError(error);
    final row = CategoryGroup(
      id: _uuid.v4(),
      createdAt: now().toUtc(),
      name: name.trim(),
      icon: icon,
      sortOrder: data.groups.isEmpty ? 0 : data.groups.map((g) => g.sortOrder).reduce((a, b) => a > b ? a : b) + 1,
      kind: GroupKind.spending,
    );
    await db.into(db.categoryGroups).insert(row);
    await reload();
    return row;
  }

  Future<void> updateGroup(CategoryGroup group, {String? name, String? icon}) async {
    if (name != null) {
      final error = Validation.name(name, thing: 'the group');
      if (error != null) throw ArgumentError(error);
    }
    await db.update(db.categoryGroups).replace(group.copyWith(name: name?.trim() ?? group.name, icon: icon ?? group.icon));
    await reload();
  }

  // Goals ------------------------------------------------------------------

  Future<SavingsGoal> saveGoal({
    String? id,
    required String name,
    required String emoji,
    int? targetAmount,
    DateTime? targetDate,
    int startingBalance = 0,
  }) async {
    final error = Validation.name(name, thing: 'the goal');
    if (error != null) throw ArgumentError(error);
    final existing = id == null ? null : data.goalById[id];
    final row = SavingsGoal(
      id: existing?.id ?? _uuid.v4(),
      createdAt: existing?.createdAt ?? now().toUtc(),
      name: name.trim(),
      emoji: emoji,
      targetAmount: targetAmount,
      targetDate: targetDate == null ? null : dateOnly(targetDate),
      startingBalance: startingBalance,
      sortOrder: existing?.sortOrder ??
          (data.goals.isEmpty ? 0 : data.goals.map((g) => g.sortOrder).reduce((a, b) => a > b ? a : b) + 1),
      isArchived: existing?.isArchived ?? false,
    );
    await db.into(db.savingsGoals).insertOnConflictUpdate(row);
    await reload();
    return row;
  }

  Future<void> setGoalArchived(String goalId, bool archived) async {
    await (db.update(db.savingsGoals)..where((g) => g.id.equals(goalId)))
        .write(SavingsGoalsCompanion(isArchived: Value(archived)));
    await reload();
  }

  // Debts ------------------------------------------------------------------

  Future<Debt> saveDebt({
    String? id,
    required String name,
    String? lender,
    required int balanceOnStartDate,
    required DateTime startDate,
    required double annualInterestRatePercent,
    String? linkedCategoryId,
    int? latestStatementBalance,
    DateTime? latestStatementDate,
  }) async {
    final error = Validation.name(name, thing: 'the debt');
    if (error != null) throw ArgumentError(error);
    final existing = id == null ? null : data.debts.where((d) => d.id == id).firstOrNull;
    final row = Debt(
      id: existing?.id ?? _uuid.v4(),
      createdAt: existing?.createdAt ?? now().toUtc(),
      name: name.trim(),
      lender: (lender == null || lender.trim().isEmpty) ? null : lender.trim(),
      balanceOnStartDate: balanceOnStartDate,
      startDate: dateOnly(startDate),
      annualInterestRatePercent: annualInterestRatePercent,
      linkedCategoryId: linkedCategoryId,
      latestStatementBalance: latestStatementBalance,
      latestStatementDate: latestStatementDate == null ? null : dateOnly(latestStatementDate),
    );
    await db.into(db.debts).insertOnConflictUpdate(row);
    await reload();
    return row;
  }

  Future<void> deleteDebt(String id) async {
    await (db.delete(db.debts)..where((d) => d.id.equals(id))).go();
    await reload();
  }

  // Settings ---------------------------------------------------------------

  Future<void> _writeSettings(SettingsCompanion companion) async {
    await (db.update(db.settings)..where((s) => s.id.equals(1))).write(companion);
    await reload();
  }

  Future<void> setBudgetMonthStartDay(int day) {
    if (!Validation.startDay(day)) throw ArgumentError('Pick a day from 1 to 28');
    return _writeSettings(SettingsCompanion(budgetMonthStartDay: Value(day)));
  }

  Future<void> setAppLockEnabled(bool enabled) => _writeSettings(SettingsCompanion(appLockEnabled: Value(enabled)));

  Future<void> completeOnboarding() => _writeSettings(const SettingsCompanion(hasCompletedOnboarding: Value(true)));

  Future<void> markBackedUp() => _writeSettings(SettingsCompanion(lastBackupAt: Value(now().toUtc())));

  /// Hides the backup reminder for 7 days.
  Future<void> hideBackupReminder() => _writeSettings(
        SettingsCompanion(backupReminderHiddenUntil: Value(now().toUtc().add(const Duration(days: 7)))),
      );

  /// True when the last backup is more than 14 days old (or there is none),
  /// there are 20+ transactions and the reminder isn't hidden.
  bool get shouldShowBackupReminder {
    final s = data.settings;
    if (data.transactions.length < 20) return false;
    final current = now().toUtc();
    if (s.backupReminderHiddenUntil != null && current.isBefore(s.backupReminderHiddenUntil!)) return false;
    final last = s.lastBackupAt;
    return last == null || current.difference(last) > const Duration(days: 14);
  }

  // Backup, restore and reset ---------------------------------------------

  BackupData snapshot() => BackupData(
        settings: data.settings,
        groups: data.groups,
        categories: data.categories,
        transactions: data.transactions,
        goals: data.goals,
        debts: data.debts,
      );

  String exportBackupJson() => encodeBackup(snapshot(), exportedAt: now());

  String exportCsv(int year) => transactionsCsv(snapshot(), year);

  /// Replaces everything with [backup] in one database transaction. If
  /// anything fails, the existing data is left as it was.
  Future<void> restore(BackupData backup) async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    try {
      await db.transaction(() async {
        for (final TableInfo<Table, dynamic> table in [
          db.transactions,
          db.debts,
          db.savingsGoals,
          db.categories,
          db.categoryGroups,
          db.settings,
        ]) {
          await db.delete(table).go();
        }
        await db.batch((b) {
          b.insert(db.settings, backup.settings);
          b.insertAll(db.categoryGroups, backup.groups);
          b.insertAll(db.categories, backup.categories);
          b.insertAll(db.savingsGoals, backup.goals);
          b.insertAll(db.transactions, backup.transactions);
          b.insertAll(db.debts, backup.debts);
        });
      });
    } finally {
      await db.customStatement('PRAGMA foreign_keys = ON');
    }
    await reload();
  }

  /// Deletes everything and puts the starter budget back. Onboarding shows
  /// again afterwards.
  Future<void> resetAll() async {
    await db.wipe();
    await seedDefaults(db, now: now());
    await reload();
  }
}
