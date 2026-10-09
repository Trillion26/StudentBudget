import 'package:flutter/cupertino.dart';

import '../../app_scope.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';
import '../../design/app_colors.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';
import '../../logic/budget_calculator.dart';
import '../../logic/dates.dart';
import '../../logic/models.dart';
import '../../logic/money.dart';
import '../../logic/mortgage_calculator.dart';
import 'mortgage_edit_page.dart';

String mortgageTypeLabel(MortgageType type) => switch (type) {
  MortgageType.annuity => 'Annuity',
  MortgageType.linear => 'Linear',
  MortgageType.interestOnly => 'Interest-only',
};

/// "4,1%"
String formatRate(double percent) =>
    '${percent.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '').replaceAll('.', ',')}%';

/// Totals over all mortgage parts, seen on [today].
class MortgageTotals {
  MortgageTotals(AppData data, DateTime today)
    : statuses = {for (final m in data.mortgages) m.id: data.mortgageStatus(m, today)} {
    for (final s in statuses.values) {
      balance += s.balanceNow;
      interestThisMonth += s.thisMonth?.interest ?? 0;
      repaymentThisMonth += s.thisMonth?.repayment ?? 0;
      final year = s.inYear(today.year);
      interestThisYear += year.interest;
      repaymentThisYear += year.repayment;
      if (s.schedule.isNotEmpty && (lastPayment == null || s.schedule.last.month.isAfter(lastPayment!))) {
        lastPayment = s.schedule.last.month;
      }
    }
  }

  final Map<String, MortgageStatus> statuses;
  int balance = 0;
  int interestThisMonth = 0;
  int repaymentThisMonth = 0;
  int interestThisYear = 0;
  int repaymentThisYear = 0;
  DateTime? lastPayment;

  int get paymentThisMonth => interestThisMonth + repaymentThisMonth;
}

/// The mortgage: what is still owed, this month's payment split into
/// interest and repayment, and each loan part.
class MortgagePage extends StatelessWidget {
  const MortgagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final data = store.data;
    final c = AppColors.of(context);
    final today = store.today();
    void open(Widget page) => Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => page));

    if (data.mortgages.isEmpty) {
      return PageScaffold(
        title: 'Mortgage',
        showBack: true,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            sliver: SliverList.list(
              children: [
                Text(
                  'Add your mortgage to see what you still owe, how much of each payment is interest, '
                  'and the interest paid each year for your tax return.',
                  style: AppText.bodyRegular.copyWith(color: c.inkSoft),
                ),
                const SizedBox(height: 12),
                Text(
                  'Have a mortgage in several parts (leningdelen)? Add each part separately.',
                  style: AppText.bodyRegular.copyWith(color: c.inkSoft),
                ),
                const SizedBox(height: 24),
                PrimaryButton(label: 'Add your mortgage', onPressed: () => open(const MortgageEditPage())),
              ],
            ),
          ),
        ],
      );
    }

    final totals = MortgageTotals(data, today);
    final linkedIds = {for (final m in data.mortgages) ?m.linkedCategoryId};
    final month = data.monthOf(today);
    final spent = BudgetCalculator.spentByCategory(data.facts, month);
    final logged = linkedIds.fold(0, (a, id) => a + (spent[id] ?? 0));
    final linked = linkedIds.length == 1 ? data.categoryById[linkedIds.first] : null;

    return PageScaffold(
      title: 'Mortgage',
      showBack: true,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Still owed', style: AppText.small.copyWith(color: c.inkSoft)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatEuro(totals.balance, wholeEuros: true),
                    style: AppText.hero.copyWith(color: c.ink, fontSize: 40),
                  ),
                ),
                if (totals.lastPayment != null)
                  Text(
                    'Mortgage-free after ${monthYearLabel(totals.lastPayment!)}',
                    style: AppText.bodyRegular.copyWith(color: c.inkSoft),
                  ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SectionTitle('This month')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _line(context, 'Payment', formatEuro(totals.paymentThisMonth), bold: true),
                _line(context, 'Interest', formatEuro(totals.interestThisMonth)),
                _line(context, 'Repayment', formatEuro(totals.repaymentThisMonth)),
                if (linked != null) _line(context, 'Logged in ${linked.name}', formatEuro(logged)),
              ],
            ),
          ),
        ),
        if (linked != null && linked.monthlyBudget != totals.paymentThisMonth && totals.paymentThisMonth > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: SecondaryButton(
                label: 'Set the ${linked.name} budget to ${formatEuro(totals.paymentThisMonth)}',
                onPressed: () => store.setCategoryBudget(linked.id, totals.paymentThisMonth),
              ),
            ),
          ),
        SliverToBoxAdapter(child: SectionTitle('In ${today.year}')),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _line(context, 'Interest', formatEuro(totals.interestThisYear), bold: true),
                _line(context, 'Repayment', formatEuro(totals.repaymentThisYear)),
                const SizedBox(height: 4),
                Text(
                  'The interest is what you can deduct on your tax return (hypotheekrenteaftrek), if your mortgage qualifies.',
                  style: AppText.small.copyWith(color: c.inkSoft),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SectionTitle('Loan parts')),
        SliverList.separated(
          itemCount: data.mortgages.length,
          separatorBuilder: (_, _) => const RowDivider(indent: 20),
          itemBuilder: (context, i) {
            final m = data.mortgages[i];
            return _PartRow(
              mortgage: m,
              status: totals.statuses[m.id]!,
              today: today,
              onTap: () => open(MortgageEditPage(mortgage: m)),
            );
          },
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: SecondaryButton(label: 'Add a loan part', onPressed: () => open(const MortgageEditPage())),
          ),
        ),
      ],
    );
  }

  static Widget _line(BuildContext context, String label, String value, {bool bold = false}) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: _FullWidthWrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        children: [
          Text(label, style: AppText.bodyRegular.copyWith(color: c.inkSoft)),
          Text(
            value,
            style: AppText.amount.copyWith(color: c.ink, fontWeight: bold ? FontWeight.w800 : null),
          ),
        ],
      ),
    );
  }
}

class _PartRow extends StatelessWidget {
  const _PartRow({required this.mortgage, required this.status, required this.today, required this.onTap});

  final Mortgage mortgage;
  final MortgageStatus status;
  final DateTime today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final m = mortgage;
    final fixed = m.fixedRateUntil;
    final monthsToReset = fixed == null ? null : monthsBetween(today, fixed);
    final resetSoon = monthsToReset != null && monthsToReset <= 12;
    final lines = <(String, String)>[
      ('Still owed', formatEuro(status.balanceNow, wholeEuros: true)),
      ('Payment this month', status.thisMonth == null ? '–' : formatEuro(status.thisMonth!.total)),
      ('Rate', formatRate(m.annualInterestRatePercent)),
      if (fixed != null) ('Rate fixed until', monthYearLabel(fixed)),
      ('Last payment', monthYearLabel(m.endDate)),
    ];
    final title = m.lender == null ? m.name : '${m.name} · ${m.lender}';

    return Semantics(
      label: '$title, ${mortgageTypeLabel(m.type)}. ${lines.map((l) => '${l.$1} ${l.$2}').join('. ')}.',
      button: true,
      hint: 'Tap to edit',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppText.body.copyWith(color: c.ink, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Icon(CupertinoIcons.chevron_right, size: 18, color: c.inkSoft),
                ],
              ),
              Text(mortgageTypeLabel(m.type), style: AppText.small.copyWith(color: c.inkSoft)),
              const SizedBox(height: 8),
              for (final (label, value) in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: _FullWidthWrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    children: [
                      Text(label, style: AppText.bodyRegular.copyWith(color: c.inkSoft)),
                      Text(value, style: AppText.amount.copyWith(color: c.ink)),
                    ],
                  ),
                ),
              if (resetSoon)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: NoteBox(
                    color: c.highlight.withValues(alpha: 0.22),
                    child: Text(
                      monthsToReset <= 0
                          ? 'The fixed rate has ended. Enter the new rate and balance.'
                          : 'The fixed rate ends in $monthsToReset month${monthsToReset == 1 ? '' : 's'}. A good time to compare offers.',
                      style: AppText.small.copyWith(color: c.ink),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A label and a value at opposite ends of the row, wrapping onto two lines
/// when the text is large.
class _FullWidthWrap extends StatelessWidget {
  const _FullWidthWrap({required this.children, this.alignment = WrapAlignment.spaceBetween, this.spacing = 12});

  final List<Widget> children;
  final WrapAlignment alignment;
  final double spacing;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Wrap(alignment: alignment, spacing: spacing, children: children),
  );
}
