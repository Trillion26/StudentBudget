import 'package:flutter/cupertino.dart';

import '../../app_scope.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';
import '../../design/app_colors.dart';
import '../../design/euro_field.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';
import '../../logic/budget_calculator.dart';
import '../../logic/money.dart';
import '../debts/debts_page.dart';
import '../mortgage/mortgage_page.dart';
import '../settings/settings_page.dart';
import 'category_edit_page.dart';
import 'group_edit_page.dart';

/// "€ 1.432 this month · € 287.650 to go", or a prompt to add it.
String _mortgageSubtitle(AppData data, DateTime today) {
  if (data.mortgages.isEmpty) return 'Add your mortgage';
  final totals = MortgageTotals(data, today);
  return '${formatEuro(totals.paymentThisMonth, wholeEuros: true)} this month · '
      '${formatEuro(totals.balance, wholeEuros: true)} to go';
}

class BudgetPage extends StatelessWidget {
  const BudgetPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final data = store.data;
    final c = AppColors.of(context);
    final free = BudgetCalculator.planFree(plannedIncome: data.plannedIncome, plannedSpending: data.plannedSpending);

    void open(Widget page) => Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => page));

    Widget categoryRow(BudgetCategory cat) {
      final stacked = useStackedLayout(context);
      final field = EuroField(
        key: ValueKey('budget-${cat.id}'),
        cents: cat.monthlyBudget,
        width: stacked ? double.infinity : 120,
        semanticLabel: '${cat.name}, monthly ${data.isIncomeCategory(cat.id) ? 'income' : 'budget'}',
        onChanged: (cents) => store.setCategoryBudget(cat.id, cents),
      );
      final name = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => open(CategoryEditPage(category: cat)),
        child: Semantics(
          button: true,
          hint: 'Edit category',
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              EmojiTile(cat.emoji),
              const SizedBox(width: 16),
              Expanded(child: Text(cat.name, style: AppText.body.copyWith(color: c.ink))),
            ]),
          ),
        ),
      );
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: stacked
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [name, const SizedBox(height: 6), field])
            : Row(children: [Expanded(child: name), const SizedBox(width: 12), field]),
      );
    }

    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Semantics(
            container: true,
            child: free >= 0
                ? Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: "You've planned "),
                      TextSpan(text: formatEuro(data.plannedSpending), style: const TextStyle(fontWeight: FontWeight.w800)),
                      const TextSpan(text: ' of spending from '),
                      TextSpan(text: formatEuro(data.plannedIncome), style: const TextStyle(fontWeight: FontWeight.w800)),
                      const TextSpan(text: ' coming in. '),
                      TextSpan(
                        text: '${formatEuro(free)} is free for savings or extras.',
                        style: TextStyle(fontWeight: FontWeight.w800, backgroundColor: c.highlight.withValues(alpha: 0.45)),
                      ),
                    ]),
                    style: AppText.bodyRegular.copyWith(color: c.ink, fontSize: 18),
                  )
                : Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Your plan spends '),
                      TextSpan(text: formatEuro(-free), style: const TextStyle(fontWeight: FontWeight.w800)),
                      TextSpan(text: ' more than comes in (${formatEuro(data.plannedSpending)} planned, ${formatEuro(data.plannedIncome)} coming in). '),
                      const TextSpan(text: 'Lower some budgets or add income.'),
                    ]),
                    style: AppText.bodyRegular.copyWith(color: c.overText, fontSize: 18),
                  ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(children: [
            ListRow(emoji: '🏠', title: 'Mortgage', subtitle: Text(_mortgageSubtitle(data, store.today()), style: AppText.small.copyWith(color: c.inkSoft)),
                trailing: Icon(CupertinoIcons.chevron_right, color: c.inkSoft, size: 18), onTap: () => open(const MortgagePage())),
            const RowDivider(),
            ListRow(emoji: '💳', title: 'Loans', subtitle: Text('Student loan, car loan, credit cards', style: AppText.small.copyWith(color: c.inkSoft)),
                trailing: Icon(CupertinoIcons.chevron_right, color: c.inkSoft, size: 18), onTap: () => open(const DebtsPage())),
            const RowDivider(),
            ListRow(emoji: '⚙️', title: 'Settings', subtitle: Text('Month start, app lock, backups', style: AppText.small.copyWith(color: c.inkSoft)),
                trailing: Icon(CupertinoIcons.chevron_right, color: c.inkSoft, size: 18), onTap: () => open(const SettingsPage())),
          ]),
        ),
      ),
    ];

    for (final g in [...data.incomeGroups, ...data.spendingGroups]) {
      final categories = data.categoriesIn(g.id);
      final total = data.groupBudget(g.id);
      slivers.add(SliverToBoxAdapter(
        child: SectionTitle(
          g.kind.name == 'income' ? '${g.icon} Coming in' : '${g.icon} ${g.name}',
          trailing: CupertinoButton(
            padding: const EdgeInsets.only(left: 12),
            minimumSize: const Size(44, 44),
            onPressed: () => open(GroupEditPage(group: g)),
            child: Text('Edit', style: AppText.body.copyWith(color: c.ink, decoration: TextDecoration.underline, decorationColor: c.highlight, decorationThickness: 2)),
          ),
        ),
      ));
      slivers.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Text('${formatEuro(total)} a month', style: AppText.small.copyWith(color: c.inkSoft)),
        ),
      ));
      slivers.add(SliverList.separated(
        itemCount: categories.length,
        separatorBuilder: (_, _) => const RowDivider(),
        itemBuilder: (context, i) => categoryRow(categories[i]),
      ));
      slivers.add(SliverToBoxAdapter(
        child: LinkButton(
          label: 'Add a category',
          icon: CupertinoIcons.plus,
          onPressed: () => open(CategoryEditPage(groupId: g.id)),
        ),
      ));
    }
    slivers.add(SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: SecondaryButton(label: 'Add a group', onPressed: () => open(const GroupEditPage())),
      ),
    ));

    return PageScaffold(title: 'Budget', slivers: slivers);
  }
}
