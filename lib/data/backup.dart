import 'dart:convert';

import '../app_info.dart';
import '../logic/dates.dart';
import '../logic/models.dart';
import '../logic/money.dart';
import '../logic/validation.dart';
import 'database.dart';

/// The backup file format version. Bump it (and teach [decodeBackup] to read
/// the old one) whenever the format changes.
const int backupSchemaVersion = 1;

/// Everything in the database, ready to write to or read from a file.
class BackupData {
  const BackupData({
    required this.settings,
    required this.groups,
    required this.categories,
    required this.transactions,
    required this.goals,
    required this.debts,
  });

  final AppSettings settings;
  final List<CategoryGroup> groups;
  final List<BudgetCategory> categories;
  final List<Txn> transactions;
  final List<SavingsGoal> goals;
  final List<Debt> debts;

  DateTime? get lastEntryDate {
    if (transactions.isEmpty) return null;
    return transactions.map((t) => t.date).reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// "312 transactions, 6 goals, last entry 4 Oct 2026"
  String get summary {
    final parts = <String>[
      _count(transactions.length, 'transaction'),
      _count(goals.length, 'goal'),
    ];
    final last = lastEntryDate;
    if (last != null) parts.add('last entry ${shortDate(last)}');
    return parts.join(', ');
  }

  static String _count(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
}

/// Thrown when a file is not a valid backup from this app. [message] is
/// written for the student.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// `student-budget-backup-2026-10-07.json`
String backupFileName(DateTime now) => 'student-budget-backup-${isoDate(now)}.json';

String _utc(DateTime value) => value.toUtc().toIso8601String();

/// Writes [data] as pretty-printed JSON.
String encodeBackup(BackupData data, {required DateTime exportedAt}) {
  final s = data.settings;
  final map = <String, Object?>{
    'app': 'Student Budget',
    'schemaVersion': backupSchemaVersion,
    'exportedAt': _utc(exportedAt),
    'settings': {
      'createdAt': _utc(s.createdAt),
      'budgetMonthStartDay': s.budgetMonthStartDay,
      'appLockEnabled': s.appLockEnabled,
      'hasCompletedOnboarding': s.hasCompletedOnboarding,
      'lastBackupAt': s.lastBackupAt == null ? null : _utc(s.lastBackupAt!),
      'backupReminderHiddenUntil': s.backupReminderHiddenUntil == null ? null : _utc(s.backupReminderHiddenUntil!),
    },
    'categoryGroups': [
      for (final g in data.groups)
        {
          'id': g.id,
          'createdAt': _utc(g.createdAt),
          'name': g.name,
          'icon': g.icon,
          'sortOrder': g.sortOrder,
          'kind': g.kind.name,
        },
    ],
    'categories': [
      for (final c in data.categories)
        {
          'id': c.id,
          'createdAt': _utc(c.createdAt),
          'name': c.name,
          'emoji': c.emoji,
          'groupId': c.groupId,
          'monthlyBudget': c.monthlyBudget,
          'sortOrder': c.sortOrder,
          'isArchived': c.isArchived,
        },
    ],
    'transactions': [
      for (final t in data.transactions)
        {
          'id': t.id,
          'createdAt': _utc(t.createdAt),
          'kind': t.kind.name,
          'amount': t.amount,
          'date': isoDate(t.date),
          'note': t.note,
          'categoryId': t.categoryId,
          'goalId': t.goalId,
        },
    ],
    'savingsGoals': [
      for (final g in data.goals)
        {
          'id': g.id,
          'createdAt': _utc(g.createdAt),
          'name': g.name,
          'emoji': g.emoji,
          'targetAmount': g.targetAmount,
          'targetDate': g.targetDate == null ? null : isoDate(g.targetDate!),
          'startingBalance': g.startingBalance,
          'sortOrder': g.sortOrder,
          'isArchived': g.isArchived,
        },
    ],
    'debts': [
      for (final d in data.debts)
        {
          'id': d.id,
          'createdAt': _utc(d.createdAt),
          'name': d.name,
          'lender': d.lender,
          'balanceOnStartDate': d.balanceOnStartDate,
          'startDate': isoDate(d.startDate),
          'annualInterestRatePercent': d.annualInterestRatePercent,
          'linkedCategoryId': d.linkedCategoryId,
          'latestStatementBalance': d.latestStatementBalance,
          'latestStatementDate': d.latestStatementDate == null ? null : isoDate(d.latestStatementDate!),
        },
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(map);
}

/// Reads and fully checks a backup file. Throws [BackupFormatException]
/// with a plain explanation when anything is wrong; nothing is changed.
BackupData decodeBackup(String text) {
  Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    throw const BackupFormatException("This file isn't a backup from $appName. Pick a file named like student-budget-backup-2026-10-07.json.");
  }
  if (decoded is! Map<String, Object?> || !decoded.containsKey('schemaVersion')) {
    throw const BackupFormatException("This file isn't a backup from $appName. Pick a file named like student-budget-backup-2026-10-07.json.");
  }
  final version = decoded['schemaVersion'];
  if (version is! int) {
    throw const BackupFormatException("This backup is damaged: its version number is missing.");
  }
  if (version > backupSchemaVersion) {
    throw const BackupFormatException('This backup was made by a newer version of $appName. Update the app, then try again.');
  }
  if (version < 1) {
    throw const BackupFormatException("This backup's version isn't supported.");
  }
  try {
    return _decodeV1(decoded);
  } on BackupFormatException {
    rethrow;
  } catch (_) {
    throw const BackupFormatException("This backup is damaged and can't be restored. Nothing was changed.");
  }
}

class _Reader {
  _Reader(this.map, this.where);
  final Map<String, Object?> map;
  final String where;

  Never fail(String field) => throw BackupFormatException("This backup is damaged ($where: $field). Nothing was changed.");

  String str(String key, {int? maxLength, bool allowEmpty = false}) {
    final v = map[key];
    if (v is! String || (!allowEmpty && v.trim().isEmpty)) fail(key);
    if (maxLength != null && v.length > maxLength) fail(key);
    return v;
  }

  String? optStr(String key) {
    final v = map[key];
    if (v == null) return null;
    if (v is! String) fail(key);
    return v;
  }

  int integer(String key, {int? min, int? max}) {
    final v = map[key];
    if (v is! int) fail(key);
    if (min != null && v < min) fail(key);
    if (max != null && v > max) fail(key);
    return v;
  }

  int? optInt(String key, {int? min, int? max}) => map[key] == null ? null : integer(key, min: min, max: max);

  double real(String key) {
    final v = map[key];
    if (v is! num || v.isNaN || v.isInfinite || v < 0 || v > 1000) fail(key);
    return v.toDouble();
  }

  bool boolean(String key) {
    final v = map[key];
    if (v is! bool) fail(key);
    return v;
  }

  DateTime timestamp(String key) {
    final v = map[key];
    if (v is! String) fail(key);
    final parsed = DateTime.tryParse(v);
    if (parsed == null) fail(key);
    return parsed.toUtc();
  }

  DateTime? optTimestamp(String key) => map[key] == null ? null : timestamp(key);

  DateTime date(String key) {
    final v = map[key];
    if (v is! String) fail(key);
    return parseIsoDate(v) ?? fail(key);
  }

  DateTime? optDate(String key) => map[key] == null ? null : date(key);

  T enumValue<T extends Enum>(String key, List<T> values) {
    final v = map[key];
    for (final e in values) {
      if (e.name == v) return e;
    }
    fail(key);
  }
}

List<Map<String, Object?>> _list(Map<String, Object?> root, String key) {
  final v = root[key];
  if (v is! List) throw BackupFormatException("This backup is damaged ($key is missing). Nothing was changed.");
  return [
    for (final item in v)
      if (item is Map<String, Object?>) item else throw BackupFormatException('This backup is damaged ($key). Nothing was changed.'),
  ];
}

BackupData _decodeV1(Map<String, Object?> root) {
  final settingsMap = root['settings'];
  if (settingsMap is! Map<String, Object?>) {
    throw const BackupFormatException('This backup is damaged (settings are missing). Nothing was changed.');
  }
  final sr = _Reader(settingsMap, 'settings');
  final settings = AppSettings(
    id: 1,
    createdAt: sr.timestamp('createdAt'),
    budgetMonthStartDay: sr.integer('budgetMonthStartDay', min: 1, max: 28),
    appLockEnabled: sr.boolean('appLockEnabled'),
    hasCompletedOnboarding: sr.boolean('hasCompletedOnboarding'),
    lastBackupAt: sr.optTimestamp('lastBackupAt'),
    backupReminderHiddenUntil: sr.optTimestamp('backupReminderHiddenUntil'),
  );

  final ids = <String>{};
  void uniqueId(String id, String where) {
    if (!ids.add(id)) throw BackupFormatException('This backup is damaged (the same id appears twice in $where). Nothing was changed.');
  }

  final groups = <CategoryGroup>[];
  for (final (i, m) in _list(root, 'categoryGroups').indexed) {
    final r = _Reader(m, 'group ${i + 1}');
    final g = CategoryGroup(
      id: r.str('id'),
      createdAt: r.timestamp('createdAt'),
      name: r.str('name', maxLength: Validation.maxNameLength),
      icon: r.str('icon'),
      sortOrder: r.integer('sortOrder'),
      kind: r.enumValue('kind', GroupKind.values),
    );
    uniqueId(g.id, 'groups');
    groups.add(g);
  }
  final groupIds = {for (final g in groups) g.id};

  final categories = <BudgetCategory>[];
  final names = <String>{};
  for (final (i, m) in _list(root, 'categories').indexed) {
    final r = _Reader(m, 'category ${i + 1}');
    final c = BudgetCategory(
      id: r.str('id'),
      createdAt: r.timestamp('createdAt'),
      name: r.str('name', maxLength: Validation.maxNameLength),
      emoji: r.str('emoji'),
      groupId: r.str('groupId'),
      monthlyBudget: r.integer('monthlyBudget', min: 0, max: maxAmountCents),
      sortOrder: r.integer('sortOrder'),
      isArchived: r.boolean('isArchived'),
    );
    if (!groupIds.contains(c.groupId)) r.fail('groupId');
    if (!names.add(c.name.trim().toLowerCase())) r.fail('name is used twice');
    uniqueId(c.id, 'categories');
    categories.add(c);
  }
  final categoryIds = {for (final c in categories) c.id};

  final goals = <SavingsGoal>[];
  for (final (i, m) in _list(root, 'savingsGoals').indexed) {
    final r = _Reader(m, 'goal ${i + 1}');
    final g = SavingsGoal(
      id: r.str('id'),
      createdAt: r.timestamp('createdAt'),
      name: r.str('name', maxLength: Validation.maxNameLength),
      emoji: r.str('emoji'),
      targetAmount: r.optInt('targetAmount', min: 1, max: maxAmountCents),
      targetDate: r.optDate('targetDate'),
      startingBalance: r.integer('startingBalance', min: 0, max: maxAmountCents),
      sortOrder: r.integer('sortOrder'),
      isArchived: r.boolean('isArchived'),
    );
    uniqueId(g.id, 'goals');
    goals.add(g);
  }
  final goalIds = {for (final g in goals) g.id};

  final transactions = <Txn>[];
  for (final (i, m) in _list(root, 'transactions').indexed) {
    final r = _Reader(m, 'transaction ${i + 1}');
    final t = Txn(
      id: r.str('id'),
      createdAt: r.timestamp('createdAt'),
      kind: r.enumValue('kind', TxnKind.values),
      amount: r.integer('amount', min: 1, max: maxAmountCents),
      date: r.date('date'),
      note: r.str('note', maxLength: Validation.maxNoteLength, allowEmpty: true),
      categoryId: r.optStr('categoryId'),
      goalId: r.optStr('goalId'),
    );
    if (t.categoryId != null && !categoryIds.contains(t.categoryId)) r.fail('categoryId');
    if (t.goalId != null && !goalIds.contains(t.goalId)) r.fail('goalId');
    switch (t.kind) {
      case TxnKind.income:
      case TxnKind.expense:
        if (t.categoryId == null) r.fail('category is missing');
        if (t.goalId != null) r.fail('goalId');
      case TxnKind.toSavings:
        if (t.goalId == null) r.fail('goal is missing');
        if (t.categoryId != null) r.fail('categoryId');
      case TxnKind.fromSavings:
        if (t.goalId == null) r.fail('goal is missing');
    }
    uniqueId(t.id, 'transactions');
    transactions.add(t);
  }

  final debts = <Debt>[];
  for (final (i, m) in _list(root, 'debts').indexed) {
    final r = _Reader(m, 'debt ${i + 1}');
    final d = Debt(
      id: r.str('id'),
      createdAt: r.timestamp('createdAt'),
      name: r.str('name', maxLength: Validation.maxNameLength),
      lender: r.optStr('lender'),
      balanceOnStartDate: r.integer('balanceOnStartDate', min: 0, max: maxAmountCents),
      startDate: r.date('startDate'),
      annualInterestRatePercent: r.real('annualInterestRatePercent'),
      linkedCategoryId: r.optStr('linkedCategoryId'),
      latestStatementBalance: r.optInt('latestStatementBalance', min: 0, max: maxAmountCents),
      latestStatementDate: r.optDate('latestStatementDate'),
    );
    if (d.linkedCategoryId != null && !categoryIds.contains(d.linkedCategoryId)) r.fail('linkedCategoryId');
    uniqueId(d.id, 'debts');
    debts.add(d);
  }

  return BackupData(
    settings: settings,
    groups: groups,
    categories: categories,
    transactions: transactions,
    goals: goals,
    debts: debts,
  );
}

/// Friendly names for the CSV "kind" column.
String kindLabel(TxnKind kind) => switch (kind) {
      TxnKind.income => 'Received',
      TxnKind.expense => 'Spent',
      TxnKind.toSavings => 'Saved',
      TxnKind.fromSavings => 'Took from savings',
    };

String _csvField(String value) {
  if (value.contains(RegExp('[",\n\r]')) || value.startsWith(RegExp(r'[=+\-@]'))) {
    // Quote, and stop spreadsheets reading the text as a formula.
    final safe = value.startsWith(RegExp(r'[=+\-@]')) ? "'$value" : value;
    return '"${safe.replaceAll('"', '""')}"';
  }
  return value;
}

/// Transactions dated in calendar [year], oldest first, as CSV with the
/// columns date, kind, category, group, goal, amount, note. Starts with a
/// byte-order mark so Excel reads the emoji and dashes correctly.
String transactionsCsv(BackupData data, int year) {
  final categories = {for (final c in data.categories) c.id: c};
  final groups = {for (final g in data.groups) g.id: g};
  final goals = {for (final g in data.goals) g.id: g};
  final rows = data.transactions.where((t) => t.date.year == year).toList()
    ..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
    });
  final out = StringBuffer('﻿date,kind,category,group,goal,amount,note\r\n');
  for (final t in rows) {
    final category = categories[t.categoryId];
    final group = category == null ? null : groups[category.groupId];
    out.write([
      isoDate(t.date),
      kindLabel(t.kind),
      _csvField(category?.name ?? ''),
      _csvField(group?.name ?? ''),
      _csvField(goals[t.goalId]?.name ?? ''),
      formatAmountForCsv(t.amount),
      _csvField(t.note),
    ].join(','));
    out.write('\r\n');
  }
  return out.toString();
}
