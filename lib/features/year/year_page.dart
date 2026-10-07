import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';

import '../../app_scope.dart';
import '../../design/app_colors.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';
import '../../logic/budget_calculator.dart';
import '../../logic/dates.dart';
import '../../logic/money.dart';

/// Spending per month for a year, the groups × months table (like the
/// spreadsheet's Annual Summary) and the savings rate.
class YearPage extends StatefulWidget {
  const YearPage({super.key, required this.initialYear});

  final int initialYear;

  @override
  State<YearPage> createState() => _YearPageState();
}

class _YearPageState extends State<YearPage> {
  late int _year = widget.initialYear;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final data = store.data;
    final c = AppColors.of(context);
    final groupOfCategory = {for (final cat in data.categories) cat.id: cat.groupId};
    final summary = BudgetCalculator.yearSummary(
      year: _year,
      startDay: data.startDay,
      txns: data.facts,
      groupOfCategory: groupOfCategory,
      groupBudgets: {for (final g in data.spendingGroups) g.id: data.groupBudget(g.id)},
    );
    final thisYear = store.today().year;
    final rate = summary.savingsRate;

    return PageScaffold(
      title: 'The year',
      showBack: true,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                _yearArrow(context, CupertinoIcons.chevron_left, 'Previous year', _year > 2020 ? () => setState(() => _year--) : null),
                Expanded(
                  child: Text('$_year', textAlign: TextAlign.center, style: AppText.body.copyWith(color: c.ink, fontWeight: FontWeight.w800)),
                ),
                _yearArrow(context, CupertinoIcons.chevron_right, 'Next year', _year < thisYear + 1 ? () => setState(() => _year++) : null),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _figure(context, 'Spent', formatRand(summary.spent)),
                _figure(context, 'Came in', formatRand(summary.income)),
                _figure(context, 'Savings rate', rate == null ? '–' : '${(rate * 100).toStringAsFixed(rate * 100 < 10 ? 1 : 0)}%'),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              rate == null ? 'The savings rate shows once income is logged.' : 'Savings rate is what you saved out of what came in.',
              style: AppText.small.copyWith(color: c.inkSoft),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SectionTitle('Spending each month')),
        SliverToBoxAdapter(child: _SpendingChart(summary: summary)),
        const SliverToBoxAdapter(child: SectionTitle('By group')),
        SliverToBoxAdapter(child: _GroupTable(summary: summary)),
      ],
    );
  }

  Widget _figure(BuildContext context, String label, String value) {
    final c = AppColors.of(context);
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.small.copyWith(color: c.inkSoft)),
          Text(value, style: AppText.amountLarge.copyWith(color: c.ink)),
        ],
      ),
    );
  }

  Widget _yearArrow(BuildContext context, IconData icon, String label, VoidCallback? onPressed) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size(48, 48),
        onPressed: onPressed,
        child: Icon(icon, color: onPressed == null ? c.line : c.ink, size: 22),
      ),
    );
  }
}

class _SpendingChart extends StatelessWidget {
  const _SpendingChart({required this.summary});

  final YearSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final planned = summary.plannedSpendingPerMonth / 100;
    final maxSpent = summary.spentPerMonth.fold(0, math.max) / 100;
    final top = math.max(1.0, math.max(planned, maxSpent) * 1.15);
    final description = StringBuffer('Bar chart of spending per month in ${summary.year}. Planned spending is ${formatRand(summary.plannedSpendingPerMonth)} a month. ');
    for (var i = 0; i < 12; i++) {
      if (summary.spentPerMonth[i] > 0) description.write('${shortMonthNames[i]} ${formatRand(summary.spentPerMonth[i])}. ');
    }
    return Semantics(
      label: description.toString(),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: top,
                  minY: 0,
                  alignment: BarChartAlignment.spaceAround,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: _niceInterval(top),
                    getDrawingHorizontalLine: (_) => FlLine(color: c.line, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => c.ink,
                      getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                        '${shortMonthNames[group.x]}\n${formatRand((rod.toY * 100).round())}',
                        AppText.small.copyWith(color: c.onInk),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        interval: _niceInterval(top),
                        getTitlesWidget: (value, meta) => value == meta.max
                            ? const SizedBox.shrink()
                            : Text(_short(value), style: AppText.small.copyWith(color: c.inkSoft, fontSize: 11)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(shortMonthNames[value.toInt()].substring(0, 1),
                              style: AppText.small.copyWith(color: c.inkSoft, fontSize: 11)),
                        ),
                      ),
                    ),
                  ),
                  extraLinesData: ExtraLinesData(horizontalLines: [
                    if (planned > 0)
                      HorizontalLine(y: planned, color: c.highlight, strokeWidth: 3, dashArray: [6, 4]),
                  ]),
                  barGroups: [
                    for (var i = 0; i < 12; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: summary.spentPerMonth[i] / 100,
                          width: 14,
                          color: planned > 0 && summary.spentPerMonth[i] / 100 > planned ? c.over : c.ink,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _legend(context, c.ink, 'Spent'),
                  _legend(context, c.over, 'Over the plan'),
                  _legend(context, c.highlight, 'Planned spending (${formatRand(summary.plannedSpendingPerMonth)})'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static double _niceInterval(double top) {
    final raw = top / 4;
    final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    for (final step in [1, 2, 2.5, 5, 10]) {
      if (raw <= step * magnitude) return step * magnitude;
    }
    return 10 * magnitude;
  }

  static String _short(double rand) {
    if (rand >= 1000) {
      final k = rand / 1000;
      return 'R${k == k.roundToDouble() ? k.toStringAsFixed(0) : k.toStringAsFixed(1)}k';
    }
    return 'R${rand.toStringAsFixed(0)}';
  }

  Widget _legend(BuildContext context, Color color, String label) {
    final c = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: AppText.small.copyWith(color: c.inkSoft))),
      ],
    );
  }
}

/// Groups × months, with year total, annual budget and difference.
class _GroupTable extends StatelessWidget {
  const _GroupTable({required this.summary});

  final YearSummary summary;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final data = store.data;
    final c = AppColors.of(context);
    final rows = summary.groups.where((g) => g.total > 0 || g.annualBudget > 0).toList();
    final header = AppText.small.copyWith(color: c.inkSoft);
    final cell = AppText.small.copyWith(color: c.ink, fontFeatures: tabular);
    final bold = cell.copyWith(fontWeight: FontWeight.w800);

    Widget text(String value, TextStyle style, {TextAlign align = TextAlign.right}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Text(value, textAlign: align, style: style, softWrap: false),
        );

    String amount(int cents) => cents == 0 ? '–' : formatRand(cents, wholeRand: true);

    final totalPerMonth = summary.spentPerMonth;
    final totalBudget = rows.fold(0, (a, g) => a + g.annualBudget);
    final totalSpent = rows.fold(0, (a, g) => a + g.total);

    TableRow row(List<Widget> cells, {Color? background}) =>
        TableRow(decoration: BoxDecoration(color: background, border: Border(bottom: BorderSide(color: c.line))), children: cells);

    Widget difference(int value) {
      final over = value < 0;
      return text(
        over ? '${formatRand(-value, wholeRand: true)} over' : formatRand(value, wholeRand: true),
        cell.copyWith(color: over ? c.overText : c.ink, fontWeight: over ? FontWeight.w800 : FontWeight.w600),
      );
    }

    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text('Nothing spent in ${summary.year} yet.', style: AppText.bodyRegular.copyWith(color: c.inkSoft)),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          row([
            text('Group', header, align: TextAlign.left),
            for (final m in shortMonthNames) text(m, header),
            text('Year', header),
            text('Budget', header),
            text('Difference', header),
          ]),
          for (final g in rows)
            row([
              text('${data.groupById[g.groupId]?.icon ?? ''} ${data.groupById[g.groupId]?.name ?? ''}', cell, align: TextAlign.left),
              for (final v in g.monthly) text(amount(v), cell),
              text(amount(g.total), bold),
              text(amount(g.annualBudget), cell),
              difference(g.difference),
            ]),
          row([
            text('Total', bold, align: TextAlign.left),
            for (final v in totalPerMonth) text(amount(v), bold),
            text(amount(totalSpent), bold),
            text(amount(totalBudget), bold),
            difference(totalBudget - totalSpent),
          ], background: c.card),
        ],
      ),
    );
  }
}
