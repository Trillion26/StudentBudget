import 'dart:math' as math;
import 'dart:typed_data';

import '../data/app_data.dart';
import '../data/database.dart';
import '../logic/budget_calculator.dart';
import '../logic/budget_month.dart';
import '../logic/dates.dart';
import '../logic/models.dart';
import '../logic/money.dart';
import 'xlsx.dart';

/// `student-budget-2026.xlsx`
String yearReportFileName(int year) => 'student-budget-$year.xlsx';

/// The year as an Excel workbook: a one-page dashboard like the Year view,
/// then the months, every transaction, and goals and debts. All figures use
/// the budget months labelled January to December of [year].
Uint8List buildYearReport(AppData data, int year, DateTime today) => _YearReport(data, year, today).build();

// The app's light colours (see AppColors.light).
const _ink = '0E4D6E';
const _inkSoft = '4A6F80';
const _line = 'D3E5E6';
const _paper = 'F1F7F6';
const _white = 'FFFFFF';
const _highlight = 'F5C343';
const _gold = 'E0A92A';
const _overText = 'B3261E';
const _overFill = 'FFE6E1';
const _incomeText = '1E7A55';
const _okFill = 'E1F4EA';
const _income = '2FAE6B';
const _savings = '4A90D9';

/// Slice colours for the spending groups, in group order.
const _groupColors = [
  '0E4D6E',
  '2FAE6B',
  'E0A92A',
  '4A90D9',
  'FF9C8A',
  '4A6F80',
  'F4A261',
  'B39DDB',
  '7FD1D8',
  'C9CCDA',
];

const _rand = '"R"#,##0;-"R"#,##0;"–"';
const _randCents = '"R"#,##0.00;-"R"#,##0.00';
const _percent = '0%';
const _date = 'd mmm yyyy';

const _base = CellStyle(color: _ink, fill: _white);
const _paperCell = CellStyle(fill: _paper);
final _title = _base.copyWith(bold: true, size: 18, color: _white, fill: _ink, indent: 1);
final _section = _base.copyWith(bold: true, size: 12);
final _header = _base.copyWith(bold: true, size: 9, color: _white, fill: _ink, align: HAlign.center);
final _headerLeft = _header.copyWith(align: HAlign.left, indent: 1);
final _cell = _base.copyWith(bottomBorder: _line);
final _cellText = _cell.copyWith(indent: 1);
final _cellSoft = _cell.copyWith(color: _inkSoft, size: 9);
final _cellRand = _cell.copyWith(numFmt: _rand, align: HAlign.right);

/// [base] coloured green above zero and red below. The colour is set on the
/// cell, not in the number format, because Quick Look on iPhone ignores
/// colours in number formats.
CellStyle _signed(int cents, [CellStyle? base]) => (base ?? _cellRand).copyWith(
  numFmt: _rand,
  align: HAlign.right,
  color: cents > 0 ? _incomeText : (cents < 0 ? _overText : _inkSoft),
);
final _cellPercent = _cellRand.copyWith(numFmt: _percent);
final _total = _cell.copyWith(bold: true, fill: _line);
final _note = _base.copyWith(italic: true, size: 8, color: _inkSoft);

double _r(int cents) => cents / 100;

String _whole(int cents) => formatRand(cents, wholeRand: true);

/// Days since 30 Dec 1899, which is how Excel stores dates.
int _excelDate(DateTime d) => DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(1899, 12, 30)).inDays;

String _kindLabel(TxnKind kind) => switch (kind) {
  TxnKind.income => 'Income',
  TxnKind.expense => 'Spent',
  TxnKind.toSavings => 'To savings',
  TxnKind.fromSavings => 'From savings',
};

class _YearReport {
  _YearReport(this.data, this.year, DateTime today)
    : today = dateOnly(today),
      months = [for (var m = 1; m <= 12; m++) BudgetMonth(year, m, data.startDay)] {
    current = data.monthOf(this.today);
    figures = [for (final m in months) BudgetCalculator.monthFigures(data.facts, m)];
    income = figures.fold(0, (a, f) => a + f.income);
    spent = figures.fold(0, (a, f) => a + f.spent);
    saved = figures.fold(0, (a, f) => a + f.saved);
    fromSavings = figures.fold(0, (a, f) => a + f.fromSavings);
    // Plans count the months that have started; a past or future year
    // counts all twelve.
    planMonths = current.year == year ? current.month : 12;
    for (final t in yearTxns) {
      if (t.kind != TxnKind.expense || t.categoryId == null) continue;
      final perMonth = byCategory.putIfAbsent(t.categoryId!, () => List.filled(12, 0));
      perMonth[data.monthOf(t.date).month - 1] += t.amount;
    }
  }

  final AppData data;
  final int year;
  final DateTime today;
  final List<BudgetMonth> months;
  late final BudgetMonth current;
  late final List<MonthFigures> figures;
  late final int income, spent, saved, fromSavings, planMonths;

  /// Spending per category id, January first.
  final Map<String, List<int>> byCategory = {};

  late final List<Txn> yearTxns = data.transactions
      .where((t) => !t.date.isBefore(months.first.start) && t.date.isBefore(months.last.endExclusive))
      .toList()
      .reversed
      .toList();

  int categorySpent(String id) => (byCategory[id] ?? const []).fold(0, (a, b) => a + b);
  int groupSpent(String groupId) =>
      data.categoriesIn(groupId, includeArchived: true).fold(0, (a, c) => a + categorySpent(c.id));

  String get planLabel => planMonths == 12 ? 'full year' : 'Jan–${shortMonthNames[planMonths - 1]}';

  final workbook = Workbook()..creator = 'Student Budget';

  Uint8List build() {
    final monthsSheet = _months();
    _dashboard(monthsSheet);
    _transactions();
    _goalsAndDebts();
    // The dashboard goes first.
    workbook.sheets.insert(0, workbook.sheets.removeAt(1));
    return workbook.encode(created: today);
  }

  // ───────────────────────── Dashboard ─────────────────────────

  void _dashboard(Sheet monthsSheet) {
    final s = workbook.addSheet('Dashboard', tabColor: _ink)..fitToWidth = true;
    s.columnWidth(0, 2);
    for (var c = 1; c <= 12; c++) {
      s.columnWidth(c, 12.5);
    }
    s.columnWidth(13, 2);

    // Title bar.
    s.merge(1, 1, 2, 8, 'STUDENT BUDGET DASHBOARD', _title);
    s.merge(1, 9, 2, 10, 'YEAR ▸', _title.copyWith(size: 10, color: _highlight, align: HAlign.right));
    s.merge(1, 11, 2, 12, year, _title.copyWith(color: _ink, fill: _highlight, align: HAlign.center, indent: 0));
    s.rowHeight(1, 18);
    s.rowHeight(2, 18);
    final startNote = data.startDay == 1 ? 'Months run from the 1st.' : 'Budget months start on day ${data.startDay}.';
    s.merge(
      3,
      1,
      3,
      12,
      'Exported ${shortDate(today)}. $startNote Plans count ${planMonths == 12 ? 'all 12 months' : 'the months so far ($planLabel)'}.',
      _note.copyWith(fill: _paper),
    );

    // Six headline tiles.
    final goalBalance = data.goals.fold(0, (a, g) => a + data.goalProgress(g, current).balance);
    final left = income - spent - saved;
    final plannedIncome = data.plannedIncome * planMonths;
    final plannedSpending = data.plannedSpending * planMonths;
    final rate = BudgetCalculator.savingsRate(saved: saved, income: income);
    final monthsWithData = math.max(1, planMonths);
    _tile(
      s,
      0,
      'INCOME',
      _r(income),
      'Plan ${_whole(plannedIncome)}',
      _versus(income - plannedIncome, higherIsGood: true),
    );
    _tile(
      s,
      1,
      'SPENDING',
      _r(spent),
      'Plan ${_whole(plannedSpending)}',
      _versus(spent - plannedSpending, higherIsGood: false),
    );
    _tile(s, 2, 'TO SAVINGS', _r(saved), 'About ${_whole(saved ~/ monthsWithData)} a month', (
      'Taken out: ${_whole(fromSavings)}',
      _inkSoft,
    ));
    _tile(
      s,
      3,
      'LEFT OVER',
      _r(left),
      'Plan ${_whole(plannedIncome - plannedSpending)}',
      _versus(left - (plannedIncome - plannedSpending), higherIsGood: true),
    );
    _tile(
      s,
      4,
      'IN SAVINGS NOW',
      _r(goalBalance),
      'Across ${data.activeGoals.length} goal${data.activeGoals.length == 1 ? '' : 's'}',
      ('Net this year: ${_whole(saved - fromSavings)}', _inkSoft),
    );
    _tile(s, 5, 'SAVINGS RATE', rate ?? '–', 'Saved out of income', (
      rate == null ? 'No income logged' : '',
      _inkSoft,
    ), numFmt: '0.0%');

    // Budget vs actual by group, with a bar chart beside it.
    var r = 11;
    s.merge(r, 1, r, 6, '●  Budget vs actual by group', _section);
    s.merge(r, 7, r, 12, '●  Budget vs actual (chart)', _section);
    r++;
    final tableTop = r;
    s.merge(r, 1, r, 2, 'Group', _headerLeft);
    s.set(r, 3, 'Budget', _header);
    s.set(r, 4, 'Actual', _header);
    s.set(r, 5, 'Difference', _header);
    s.set(r, 6, '% used', _header);
    final groups = data.spendingGroups;
    final firstGroupRow = r + 1;
    var totalBudget = 0, totalSpent = 0;
    for (final g in groups) {
      r++;
      final budget = data.groupBudget(g.id) * planMonths;
      final actual = groupSpent(g.id);
      totalBudget += budget;
      totalSpent += actual;
      _budgetRow(s, r, g.name, budget, actual);
    }
    final lastGroupRow = r;
    r++;
    s.merge(r, 1, r, 2, 'Total spending', _total.copyWith(indent: 1));
    s.set(r, 3, _r(totalBudget), _total.copyWith(numFmt: _rand, align: HAlign.right));
    s.set(r, 4, _r(totalSpent), _total.copyWith(numFmt: _rand, align: HAlign.right));
    s.set(r, 5, _r(totalBudget - totalSpent), _signed(totalBudget - totalSpent, _total));
    s.set(
      r,
      6,
      totalBudget > 0 ? totalSpent / totalBudget : '',
      _total.copyWith(numFmt: _percent, align: HAlign.right),
    );
    r++;
    s.merge(r, 1, r, 6, 'Budget = monthly budget × $planMonths. Green = under budget, red = over.', _note);
    s.style(tableTop, 7, r, 12, _base);
    if (groups.isNotEmpty) {
      s.charts.add(
        Chart(
          kind: ChartKind.bar,
          fromRow: tableTop,
          fromCol: 7,
          toRow: r + 1,
          toCol: 13,
          series: [
            ChartSeries(
              name: 'Budget',
              categories: ChartRange(s, firstGroupRow, 1, lastGroupRow, 1),
              values: ChartRange(s, firstGroupRow, 3, lastGroupRow, 3),
              color: _gold,
            ),
            ChartSeries(
              name: 'Actual',
              categories: ChartRange(s, firstGroupRow, 1, lastGroupRow, 1),
              values: ChartRange(s, firstGroupRow, 4, lastGroupRow, 4),
              color: _ink,
            ),
          ],
        ),
      );
    }

    // Where the money went, how income was used, top categories.
    r += 2;
    s.merge(r, 1, r, 4, '●  Where the money went', _section);
    s.merge(r, 5, r, 8, '●  How income was used', _section);
    s.merge(r, 9, r, 12, '●  Top 5 categories', _section);
    r++;
    final panelTop = r;
    const panelRows = 18;
    s.style(panelTop, 1, panelTop + panelRows - 1, 12, _base);
    if (groups.isNotEmpty) {
      s.charts.add(
        Chart(
          kind: ChartKind.doughnut,
          fromRow: panelTop,
          fromCol: 1,
          toRow: panelTop + panelRows,
          toCol: 5,
          legendPosition: 'r',
          series: [
            ChartSeries(
              name: 'Spent',
              categories: ChartRange(s, firstGroupRow, 1, lastGroupRow, 1),
              values: ChartRange(s, firstGroupRow, 4, lastGroupRow, 4),
              color: _ink,
              pointColors: [for (var i = 0; i < groups.length; i++) _groupColors[i % _groupColors.length]],
            ),
          ],
        ),
      );
    }

    // Income use: a small table under its doughnut feeds the chart.
    final useTop = panelTop + panelRows - 4;
    s.set(useTop, 7, 'Amount', _header);
    s.set(useTop, 8, 'Share', _header);
    s.merge(useTop, 5, useTop, 6, 'Went to', _headerLeft);
    final base = income > 0 ? income : 0;
    final uses = [('Spending', spent), ('To savings', saved), ('Left over', math.max(0, left))];
    for (var i = 0; i < uses.length; i++) {
      final row = useTop + 1 + i;
      s.merge(row, 5, row, 6, uses[i].$1, _cellText);
      s.set(row, 7, _r(uses[i].$2), _cellRand);
      s.set(row, 8, base > 0 ? uses[i].$2 / base : '', _cellPercent);
    }
    s.charts.add(
      Chart(
        kind: ChartKind.doughnut,
        fromRow: panelTop,
        fromCol: 5,
        toRow: useTop,
        toCol: 9,
        legendPosition: 'b',
        showPercent: true,
        series: [
          ChartSeries(
            name: 'Income',
            categories: ChartRange(s, useTop + 1, 5, useTop + 3, 5),
            values: ChartRange(s, useTop + 1, 7, useTop + 3, 7),
            color: _ink,
            pointColors: const [_gold, _ink, _income],
          ),
        ],
      ),
    );

    // Top 5 categories and quick facts.
    var q = panelTop;
    s.merge(q, 9, q, 10, 'Category', _headerLeft);
    s.set(q, 11, 'Group', _header);
    s.set(q, 12, 'Amount', _header);
    final top = data.categories.where((c) => categorySpent(c.id) > 0).toList()
      ..sort((a, b) => categorySpent(b.id) - categorySpent(a.id));
    if (top.isEmpty) {
      q++;
      s.merge(q, 9, q, 12, 'Nothing spent in $year yet.', _cellSoft.copyWith(indent: 1));
    }
    for (final c in top.take(5)) {
      q++;
      s.merge(q, 9, q, 10, c.name, _cellText);
      s.set(q, 11, data.groupById[c.groupId]?.name ?? '', _cellSoft.copyWith(align: HAlign.center, wrap: true));
      s.set(q, 12, _r(categorySpent(c.id)), _cellRand.copyWith(bold: true));
    }
    q += 2;
    s.merge(q, 9, q, 12, 'Quick facts', _section.copyWith(size: 10));
    final biggestGroup = groups.isEmpty
        ? null
        : (groups.toList()..sort((a, b) => groupSpent(b.id) - groupSpent(a.id))).first;
    final expenses = yearTxns.where((t) => t.kind == TxnKind.expense).toList()..sort((a, b) => b.amount - a.amount);
    final facts = <(String, Object)>[
      ('Income this year', _r(income)),
      ('Spent this year', _r(spent)),
      ('Put into savings', _r(saved)),
      ('Taken from savings', _r(fromSavings)),
      ('Average spent a month', _r(spent ~/ monthsWithData)),
      ('Biggest single expense', expenses.isEmpty ? '–' : _r(expenses.first.amount)),
      ('Entries logged', yearTxns.length),
      ('Biggest group', biggestGroup == null || groupSpent(biggestGroup.id) == 0 ? '–' : biggestGroup.name),
    ];
    for (final (label, value) in facts) {
      q++;
      s.merge(q, 9, q, 11, label, _cellSoft.copyWith(size: 9, indent: 1));
      s.set(
        q,
        12,
        value,
        (value is String ? _cell.copyWith(bold: true, align: HAlign.right, size: 9) : _cellRand).copyWith(
          numFmt: value is int ? '0' : _rand,
        ),
      );
    }
    r = math.max(panelTop + panelRows, q + 1);

    // Category tracker and the year line chart.
    r++;
    s.merge(r, 1, r, 6, '●  Category tracker', _section);
    s.merge(r, 7, r, 12, '●  $year at a glance', _section);
    r++;
    final trackerTop = r;
    s.merge(r, 1, r, 2, 'Category', _headerLeft);
    s.set(r, 3, 'Budget', _header);
    s.set(r, 4, 'Actual', _header);
    s.set(r, 5, 'Difference', _header);
    s.set(r, 6, 'Status', _header);
    final tracked = data.categories.where(
      (c) => !data.isIncomeCategory(c.id) && (categorySpent(c.id) > 0 || (!c.isArchived && c.monthlyBudget > 0)),
    );
    for (final c in tracked) {
      r++;
      final monthly = byCategory[c.id] ?? List.filled(12, 0);
      final budget = c.isArchived ? 0 : c.monthlyBudget;
      s.merge(r, 1, r, 2, c.name, _cellText);
      s.set(r, 3, _r(budget * planMonths), _cellRand);
      s.set(r, 4, _r(categorySpent(c.id)), _cellRand);
      s.set(r, 5, _r(budget * planMonths - categorySpent(c.id)), _signed(budget * planMonths - categorySpent(c.id)));
      final over = budget > 0 ? monthly.where((v) => v > budget).length : 0;
      final String status;
      if (budget == 0) {
        status = 'No budget';
      } else if (over == 0) {
        status = 'On budget';
      } else {
        status = 'Over in $over mo.';
      }
      s.set(
        r,
        6,
        status,
        _cell.copyWith(
          bold: true,
          size: 9,
          align: HAlign.center,
          color: over > 0 ? _overText : (budget == 0 ? _inkSoft : _incomeText),
          fill: over > 0 ? _overFill : (budget == 0 ? _white : _okFill),
        ),
      );
    }
    r++;
    s.merge(r, 1, r, 6, 'Status counts the months a category went over its monthly budget.', _note);
    final chartBottom = math.max(r + 1, trackerTop + 18);
    s.style(trackerTop, 7, chartBottom - 1, 12, _base);
    s.charts.add(
      Chart(
        kind: ChartKind.line,
        fromRow: trackerTop,
        fromCol: 7,
        toRow: chartBottom,
        toCol: 13,
        series: [
          for (final (col, name, color) in [(1, 'Income', _income), (2, 'Spent', _ink), (3, 'To savings', _savings)])
            ChartSeries(
              name: name,
              categories: ChartRange(monthsSheet, 3, 0, 14, 0),
              values: ChartRange(monthsSheet, 3, col, 14, col),
              color: color,
            ),
        ],
      ),
    );

    // Paper background around the cards.
    for (var row = 0; row <= chartBottom; row++) {
      for (var col = 0; col <= 13; col++) {
        if (!s.isStyled(row, col)) s.style(row, col, row, col, _paperCell);
      }
    }
  }

  void _tile(
    Sheet s,
    int index,
    String label,
    Object value,
    String line1,
    (String, String) line2, {
    String numFmt = _rand,
  }) {
    final c = 1 + index * 2;
    s.merge(5, c, 5, c + 1, label, _header);
    s.merge(6, c, 7, c + 1, value, _base.copyWith(bold: true, size: 18, align: HAlign.center, numFmt: numFmt));
    s.merge(8, c, 8, c + 1, line1, _base.copyWith(size: 8, color: _inkSoft, align: HAlign.center));
    s.merge(9, c, 9, c + 1, line2.$1, _base.copyWith(size: 8, bold: true, color: line2.$2, align: HAlign.center));
  }

  /// "▲ R1 200 above" or "▼ R300 below", green when that is good news.
  (String, String) _versus(int difference, {required bool higherIsGood}) {
    if (difference == 0) return ('On plan', _inkSoft);
    final above = difference > 0;
    final good = above == higherIsGood;
    return (
      '${above ? '▲' : '▼'} ${_whole(difference.abs())} ${above ? 'above' : 'below'}',
      good ? _incomeText : _overText,
    );
  }

  void _budgetRow(Sheet s, int r, String name, int budget, int actual) {
    s.merge(r, 1, r, 2, name, _cellText);
    s.set(r, 3, _r(budget), _cellRand);
    s.set(r, 4, _r(actual), _cellRand);
    s.set(r, 5, _r(budget - actual), _signed(budget - actual));
    final over = actual > budget && budget > 0;
    s.set(
      r,
      6,
      budget > 0 ? actual / budget : '',
      _cellPercent.copyWith(fill: over ? _overFill : _white, color: over ? _overText : _ink),
    );
  }

  // ───────────────────────── Months ─────────────────────────

  Sheet _months() {
    final s = workbook.addSheet('Months', tabColor: _gold);
    s.frozenRows = 3;
    s.columnWidth(0, 30);
    s.columnWidth(1, 16);
    for (var c = 2; c <= 16; c++) {
      s.columnWidth(c, 12);
    }
    s.merge(0, 0, 0, 6, 'Month by month · $year', _section.copyWith(size: 14));
    s.rowHeight(0, 24);

    final shifted = data.startDay != 1;
    final heads = [
      'Month',
      'Income',
      'Spent',
      'To savings',
      'From savings',
      'Left over',
      'Savings rate',
      if (shifted) 'Dates',
    ];
    for (var c = 0; c < heads.length; c++) {
      s.set(2, c, heads[c], c == 0 ? _headerLeft : _header);
    }
    for (var i = 0; i < 12; i++) {
      final f = figures[i];
      final r = 3 + i;
      s.set(r, 0, months[i].shortLabel, _cellText);
      s.set(r, 1, _r(f.income), _cellRand);
      s.set(r, 2, _r(f.spent), _cellRand);
      s.set(r, 3, _r(f.saved), _cellRand);
      s.set(r, 4, _r(f.fromSavings), _cellRand);
      s.set(r, 5, _r(f.income - f.spent - f.saved), _signed(f.income - f.spent - f.saved));
      s.set(r, 6, f.income > 0 ? f.saved / f.income : '', _cellPercent);
      if (shifted) s.set(r, 7, months[i].rangeLabel, _cellSoft);
    }
    final totalRow = 15;
    final money = _total.copyWith(numFmt: _rand, align: HAlign.right);
    s.set(totalRow, 0, 'Year', _total.copyWith(indent: 1));
    s.set(totalRow, 1, _r(income), money);
    s.set(totalRow, 2, _r(spent), money);
    s.set(totalRow, 3, _r(saved), money);
    s.set(totalRow, 4, _r(fromSavings), money);
    s.set(totalRow, 5, _r(income - spent - saved), _signed(income - spent - saved, money));
    s.set(totalRow, 6, income > 0 ? saved / income : '', money.copyWith(numFmt: _percent));
    if (shifted) s.set(totalRow, 7, '', _total);

    // Spending per category per month, grouped.
    var r = totalRow + 3;
    s.merge(r, 0, r, 6, 'Spending by category', _section);
    r++;
    final heads2 = ['Category', ...shortMonthNames, 'Year', 'Budget', 'Difference'];
    s.set(r, 0, heads2[0], _headerLeft);
    s.set(r, 1, 'Group', _header);
    for (var c = 1; c < heads2.length; c++) {
      s.set(r, c + 1, heads2[c], _header);
    }
    for (final g in data.spendingGroups) {
      final cats = data
          .categoriesIn(g.id, includeArchived: true)
          .where((c) => categorySpent(c.id) > 0 || (!c.isArchived && c.monthlyBudget > 0))
          .toList();
      if (cats.isEmpty) continue;
      r++;
      final groupStyle = _total.copyWith(fill: _paper);
      s.set(r, 0, g.name, groupStyle.copyWith(indent: 1));
      s.set(r, 1, '', groupStyle);
      for (var m = 0; m < 12; m++) {
        s.set(
          r,
          m + 2,
          _r(cats.fold(0, (a, c) => a + (byCategory[c.id]?[m] ?? 0))),
          groupStyle.copyWith(numFmt: _rand, align: HAlign.right),
        );
      }
      final groupBudget = data.groupBudget(g.id) * planMonths;
      s.set(r, 14, _r(groupSpent(g.id)), groupStyle.copyWith(numFmt: _rand, align: HAlign.right));
      s.set(r, 15, _r(groupBudget), groupStyle.copyWith(numFmt: _rand, align: HAlign.right));
      s.set(r, 16, _r(groupBudget - groupSpent(g.id)), _signed(groupBudget - groupSpent(g.id), groupStyle));
      for (final c in cats) {
        r++;
        final budget = (c.isArchived ? 0 : c.monthlyBudget) * planMonths;
        s.set(r, 0, c.name, _cellText.copyWith(indent: 2));
        s.set(r, 1, g.name, _cellSoft);
        for (var m = 0; m < 12; m++) {
          s.set(r, m + 2, _r(byCategory[c.id]?[m] ?? 0), _cellRand);
        }
        s.set(r, 14, _r(categorySpent(c.id)), _cellRand.copyWith(bold: true));
        s.set(r, 15, _r(budget), _cellRand);
        s.set(r, 16, _r(budget - categorySpent(c.id)), _signed(budget - categorySpent(c.id)));
      }
    }
    r++;
    s.merge(r, 0, r, 6, 'Budget = monthly budget × $planMonths ($planLabel).', _note);
    return s;
  }

  // ───────────────────────── Transactions ─────────────────────────

  void _transactions() {
    final s = workbook.addSheet('Transactions', tabColor: _income);
    s.frozenRows = 1;
    const widths = [13.0, 14.0, 13.0, 30.0, 22.0, 34.0, 14.0];
    const heads = ['Date', 'Budget month', 'Type', 'Category or goal', 'Group', 'Note', 'Amount'];
    for (var c = 0; c < heads.length; c++) {
      s.columnWidth(c, widths[c]);
      s.set(0, c, heads[c], c == 6 ? _header.copyWith(align: HAlign.right) : _headerLeft);
    }
    var r = 0;
    for (final t in yearTxns) {
      r++;
      final category = data.categoryById[t.categoryId];
      final group = category == null ? null : data.groupById[category.groupId];
      final isIn = t.kind == TxnKind.income;
      s.set(r, 0, _excelDate(t.date), _cell.copyWith(numFmt: _date, align: HAlign.left, indent: 1));
      s.set(r, 1, data.monthOf(t.date).label, _cellSoft);
      s.set(r, 2, _kindLabel(t.kind), _cell.copyWith(color: isIn ? _incomeText : _ink));
      s.set(r, 3, data.describe(t), _cell);
      s.set(r, 4, group?.name ?? (t.goalId != null ? 'Savings' : ''), _cellSoft);
      s.set(r, 5, t.note, _cellSoft);
      s.set(r, 6, _r(t.amount), _cellRand.copyWith(numFmt: _randCents, color: isIn ? _incomeText : _ink));
    }
    if (r == 0) {
      s.set(1, 0, 'No entries in $year.', _note);
    } else {
      s.autoFilter = 'A1:G${r + 1}';
    }
  }

  // ───────────────────────── Goals and debts ─────────────────────────

  void _goalsAndDebts() {
    final s = workbook.addSheet('Goals & debts', tabColor: _savings);
    const widths = [30.0, 15.0, 15.0, 15.0, 16.0, 16.0, 36.0];
    for (var c = 0; c < widths.length; c++) {
      s.columnWidth(c, widths[c]);
    }
    s.merge(0, 0, 0, 6, 'Savings goals', _section.copyWith(size: 14));
    s.rowHeight(0, 24);
    s.set(1, 0, 'Balances and status as of ${shortDate(today)}.', _note);
    final goalHeads = ['Goal', 'Balance', 'Target', 'Target date', 'Saved in $year', 'Needed a month', 'Status'];
    for (var c = 0; c < goalHeads.length; c++) {
      s.set(2, c, goalHeads[c], c == 0 || c == 6 ? _headerLeft : _header);
    }
    var r = 2;
    final goals = data.goals.where((g) => !g.isArchived || yearTxns.any((t) => t.goalId == g.id)).toList();
    for (final g in goals) {
      r++;
      final p = data.goalProgress(g, current);
      final net = yearTxns
          .where((t) => t.goalId == g.id)
          .fold(
            0,
            (a, t) =>
                a +
                (t.kind == TxnKind.toSavings
                    ? t.amount
                    : t.kind == TxnKind.fromSavings
                    ? -t.amount
                    : 0),
          );
      s.set(r, 0, '${g.name}${g.isArchived ? ' (archived)' : ''}', _cellText);
      s.set(r, 1, _r(p.balance), _cellRand.copyWith(bold: true));
      s.set(r, 2, p.target == null ? '–' : _r(p.target!), _cellRand);
      s.set(r, 3, p.targetDate == null ? '–' : monthYearLabel(p.targetDate!), _cell.copyWith(align: HAlign.right));
      s.set(r, 4, _r(net), _signed(net));
      s.set(r, 5, p.neededPerMonth == null ? '–' : _r(p.neededPerMonth!), _cellRand);
      final behind = p.state == GoalState.behind;
      s.set(
        r,
        6,
        p.statusLabel,
        _cellText.copyWith(
          color: behind
              ? _overText
              : (p.state == GoalState.reached || p.state == GoalState.onTrack ? _incomeText : _inkSoft),
        ),
      );
    }
    if (goals.isEmpty) s.set(++r, 0, 'No savings goals yet.', _note);

    r += 3;
    s.merge(r, 0, r, 6, 'Debts', _section.copyWith(size: 14));
    s.rowHeight(r, 24);
    r++;
    final debtHeads = [
      'Debt',
      'Lender',
      'Balance now',
      'Interest a year',
      'Repaid in $year',
      'Monthly repayment',
      'Paid off by',
    ];
    for (var c = 0; c < debtHeads.length; c++) {
      s.set(r, c, debtHeads[c], c == 0 || c == 1 || c == 6 ? _headerLeft : _header);
    }
    for (final d in data.debts) {
      r++;
      final e = data.debtEstimate(d, today);
      final repaid = d.linkedCategoryId == null ? 0 : categorySpent(d.linkedCategoryId!);
      s.set(r, 0, d.name, _cellText);
      s.set(r, 1, d.lender ?? '', _cellSoft.copyWith(indent: 1));
      s.set(r, 2, _r(e.balance), _cellRand.copyWith(bold: true));
      s.set(r, 3, d.annualInterestRatePercent / 100, _cellPercent.copyWith(numFmt: '0.0%'));
      s.set(r, 4, _r(repaid), _cellRand);
      s.set(r, 5, _r(e.monthlyRepayment), _cellRand);
      s.set(
        r,
        6,
        e.balance == 0
            ? 'Paid off'
            : (e.payoffMonth == null ? 'Log repayments to see' : monthYearLabel(e.payoffMonth!)),
        _cellText,
      );
    }
    if (data.debts.isEmpty) s.set(++r, 0, 'No debts. 🎉', _note);
  }
}
