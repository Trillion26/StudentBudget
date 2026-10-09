import 'package:flutter/cupertino.dart';

import '../../app_scope.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';
import '../../design/app_colors.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';
import '../../logic/dates.dart';
import '../../logic/debt_calculator.dart';
import '../../logic/money.dart';
import 'debt_edit_page.dart';

class DebtsPage extends StatelessWidget {
  const DebtsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final data = store.data;
    final c = AppColors.of(context);
    final today = store.today();
    void open(Widget page) => Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => page));

    return PageScaffold(
      title: 'Debts',
      showBack: true,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: NoteBox(
              color: c.highlight.withValues(alpha: 0.22),
              child: Text('Store cards charge high interest – pay these off first.', style: AppText.body.copyWith(color: c.ink)),
            ),
          ),
        ),
        if (data.debts.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text('No debts. Nice.', style: AppText.bodyRegular.copyWith(color: c.inkSoft)),
            ),
          ),
        SliverList.separated(
          itemCount: data.debts.length,
          separatorBuilder: (_, _) => const RowDivider(indent: 20),
          itemBuilder: (context, i) {
            final debt = data.debts[i];
            return _DebtRow(debt: debt, estimate: data.debtEstimate(debt, today), data: data, onTap: () => open(DebtEditPage(debt: debt)));
          },
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: SecondaryButton(label: 'Add a debt', onPressed: () => open(const DebtEditPage())),
          ),
        ),
      ],
    );
  }
}

class _DebtRow extends StatelessWidget {
  const _DebtRow({required this.debt, required this.estimate, required this.data, required this.onTap});

  final Debt debt;
  final DebtEstimate estimate;
  final AppData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final noBalance = debt.balanceOnStartDate == 0 && debt.latestStatementBalance == null;
    final category = debt.linkedCategoryId == null ? null : data.categoryById[debt.linkedCategoryId];
    final lines = <(String, String)>[];
    if (!noBalance) {
      lines.add((estimate.isFromStatement ? 'Balance (from statement)' : 'Estimated balance now', formatRand(estimate.balance)));
      lines.add(('Monthly repayment', estimate.monthlyRepayment == 0 ? 'None logged' : formatRand(estimate.monthlyRepayment)));
      lines.add(('Repaid this year', formatRand(estimate.repaidThisYear)));
      final payoff = estimate.isPaidOff
          ? 'Paid off'
          : estimate.payoffMonth == null
              ? 'Not paid off at this rate'
              : monthYearLabel(estimate.payoffMonth!);
      lines.add(('Paid off by', payoff));
    }
    final semantics = noBalance
        ? '${debt.name}. Add the balance to see an estimate.'
        : '${debt.name}. ${lines.map((l) => '${l.$1} ${l.$2}').join('. ')}.';

    return Semantics(
      label: semantics,
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
              Row(children: [
                Expanded(
                  child: Text(
                    debt.lender == null ? debt.name : '${debt.name} · ${debt.lender}',
                    style: AppText.body.copyWith(color: c.ink, fontWeight: FontWeight.w800),
                  ),
                ),
                Icon(CupertinoIcons.chevron_right, size: 18, color: c.inkSoft),
              ]),
              if (category != null)
                Text('Repayments: ${category.emoji} ${category.name}', style: AppText.small.copyWith(color: c.inkSoft)),
              const SizedBox(height: 8),
              if (noBalance)
                Text('Add the balance to see an estimate.', style: AppText.bodyRegular.copyWith(color: c.inkSoft))
              else
                for (final (label, value) in lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      children: [
                        Text(label, style: AppText.bodyRegular.copyWith(color: c.inkSoft)),
                        Text(
                          value,
                          style: AppText.amount.copyWith(
                            color: value == 'Not paid off at this rate' ? c.overText : c.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
