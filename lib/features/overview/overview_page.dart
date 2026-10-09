import 'package:flutter/cupertino.dart';

import '../../app_scope.dart';
import '../../data/app_data.dart';
import '../../data/budget_store.dart';
import '../../design/app_colors.dart';
import '../../design/highlighter.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';
import '../../logic/budget_calculator.dart';
import '../../logic/budget_month.dart';
import '../../logic/models.dart';
import '../../logic/money.dart';
import '../../logic/validation.dart';
import '../add/add_sheet.dart';
import '../history/txn_row.dart';
import '../home/home_tabs.dart';
import '../onboarding/income_setup_page.dart';
import '../settings/backup_actions.dart';
import '../year/year_page.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final data = store.data;
    final selected = SelectedMonthScope.of(context);
    final today = store.today();
    final current = data.monthOf(today);
    final month = selected.resolve(current);
    final summary = data.summary(month, today);
    final c = AppColors.of(context);
    final noIncome = data.plannedIncome == 0 && !summary.figures.hasLoggedIncome;

    return CupertinoPageScaffold(
      backgroundColor: c.paper,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: MonthSwitcher(
                  month: month,
                  latest: data.monthOf(Validation.latestDate),
                  earliest: data.monthOf(Validation.earliestDate),
                  onChanged: (m) => selected.select(m, current),
                ),
              ),
            ),
            if (store.shouldShowBackupReminder) const SliverToBoxAdapter(child: _BackupBanner()),
            SliverToBoxAdapter(
              child: noIncome
                  ? const _EmptyState()
                  : _Headline(key: ValueKey(month), summary: summary, current: current, data: data),
            ),
            if (!noIncome) ...[
              SliverToBoxAdapter(child: _TotalsStrip(summary: summary)),
              SliverToBoxAdapter(child: _WhoStrip(data: data, month: month)),
              SliverToBoxAdapter(child: _WhereMoneyGoes(data: data, month: month)),
              SliverToBoxAdapter(child: _Latest(data: data, month: month)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: LinkButton(
                    label: 'See the year',
                    onPressed: () => Navigator.of(context).push(CupertinoPageRoute<void>(
                      builder: (_) => YearPage(initialYear: month.year),
                    )),
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 120)),
          ],
        ),
      ),
    );
  }
}

/// The daily allowance — the one number that matters.
class _Headline extends StatelessWidget {
  const _Headline({super.key, required this.summary, required this.current, required this.data});

  final MonthSummary summary;
  final BudgetMonth current;
  final AppData data;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final month = summary.month;
    final isCurrent = month == current;
    final isFuture = month.isAfter(current);
    final lead = AppText.body.copyWith(color: c.inkSoft, fontSize: 19);
    final follow = AppText.body.copyWith(color: c.ink, fontSize: 19);

    String before;
    String number;
    final after = <String>[];
    var warning = false;
    String semantics;

    if (isFuture) {
      before = 'Planned income for ${month.label}';
      number = formatEuro(summary.plannedIncome);
      after.add("You've planned ${formatEuro(data.plannedSpending)} of spending.");
      semantics = '$before: $number. ${after.first}';
    } else if (isCurrent) {
      if (summary.isOver) {
        warning = true;
        before = "This month you're over by";
        number = formatEuro(summary.overBy);
        semantics = "This month you're over by $number.";
      } else if (summary.daysLeft <= 1) {
        before = 'You can spend';
        number = formatEuro(summary.dailyAllowance ?? 0);
        after.add('today, the last day of this budget month');
        semantics = 'You can spend $number today, the last day of this budget month.';
      } else {
        before = 'You can spend';
        number = formatEuro(summary.dailyAllowance ?? 0);
        after.add('a day for the next ${summary.daysLeft} days');
        after.add('(${formatEuro(summary.moneyLeft)} left this month)');
        semantics = 'You can spend $number a day for the next ${summary.daysLeft} days. '
            '${formatEuro(summary.moneyLeft)} left this month.';
      }
    } else {
      if (summary.isOver) {
        warning = true;
        before = '${month.label} ended over by';
        number = formatEuro(summary.overBy);
        semantics = '$before $number.';
      } else {
        before = '${month.label} ended with';
        number = formatEuro(summary.moneyLeft);
        after.add('left over');
        semantics = '$before $number left over.';
      }
    }

    final hint = !isFuture && summary.usesPlannedIncome && isCurrent;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Semantics(
        container: true,
        label: semantics,
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(before, style: warning ? lead.copyWith(color: c.overText) : lead),
            const SizedBox(height: 6),
            Highlighter(
              color: warning ? c.over.withValues(alpha: 0.75) : null,
              child: Text(
                number,
                key: const Key('headlineNumber'),
                style: AppText.hero.copyWith(color: warning ? c.overText : c.ink),
              ),
            ),
            const SizedBox(height: 6),
            for (final line in after) Text(line, style: line.startsWith('(') ? lead : follow),
            if (hint)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Based on your planned income. Add money as it comes in to make this exact.',
                  style: AppText.small.copyWith(color: c.inkSoft),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TotalsStrip extends StatelessWidget {
  const _TotalsStrip({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final f = summary.figures;
    Widget cell(String label, int amount, Color color) => Semantics(
          label: '$label ${formatEuro(amount)}',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.small.copyWith(color: c.inkSoft)),
              const SizedBox(height: 2),
              Text(formatEuro(amount), style: AppText.amountLarge.copyWith(color: color)),
            ],
          ),
        );
    final cells = [
      cell('Came in', f.income, c.incomeText),
      cell('Spent', f.spent, c.ink),
      cell('Saved', f.saved, c.ink),
    ];
    final stacked = useStackedLayout(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: c.line))),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final cell in cells) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: cell)],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final cell in cells) Expanded(child: cell)],
              ),
      ),
    );
  }
}

/// Income and spending per partner this month. Hidden until an entry is
/// tagged with a partner.
class _WhoStrip extends StatelessWidget {
  const _WhoStrip({required this.data, required this.month});

  final AppData data;
  final BudgetMonth month;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final split = BudgetCalculator.byPerson(data.facts, month.start, month.endExclusive);
    final tagged = split.entries.any((e) => e.key != Person.joint && (e.value.income > 0 || e.value.spent > 0));
    if (!tagged) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in const [Person.partner1, Person.partner2, Person.joint])
            if (split[p]!.income > 0 || split[p]!.spent > 0)
              Semantics(
                label: '${data.personName(p)}: came in ${formatEuro(split[p]!.income)}, spent ${formatEuro(split[p]!.spent)}',
                excludeSemantics: true,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    children: [
                      Text(data.personName(p), style: AppText.body.copyWith(color: c.ink)),
                      Text.rich(
                        TextSpan(children: [
                          if (split[p]!.income > 0)
                            TextSpan(
                              text: '+${formatEuro(split[p]!.income, wholeEuros: true)}  ',
                              style: TextStyle(color: c.incomeText),
                            ),
                          TextSpan(text: '${formatEuro(split[p]!.spent, wholeEuros: true)} spent'),
                        ]),
                        style: AppText.amount.copyWith(color: c.ink),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Spending per group with progress bars; tap a group to see its categories.
class _WhereMoneyGoes extends StatefulWidget {
  const _WhereMoneyGoes({required this.data, required this.month});

  final AppData data;
  final BudgetMonth month;

  @override
  State<_WhereMoneyGoes> createState() => _WhereMoneyGoesState();
}

class _WhereMoneyGoesState extends State<_WhereMoneyGoes> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final spent = BudgetCalculator.spentByCategory(data.facts, widget.month);
    final rows = <(String, CategoryStatus)>[];
    for (final g in data.spendingGroups) {
      final categories = data.categoriesIn(g.id, includeArchived: true);
      var status = const CategoryStatus(budget: 0, spent: 0);
      for (final cat in categories) {
        status = status + CategoryStatus(budget: cat.isArchived ? 0 : cat.monthlyBudget, spent: spent[cat.id] ?? 0);
      }
      if (status.budget == 0 && status.spent == 0) continue;
      rows.add((g.id, status));
    }
    rows.sort((a, b) => b.$2.spent.compareTo(a.$2.spent));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Where your money is going'),
        for (final (i, (groupId, status)) in rows.indexed) ...[
          if (i > 0) const RowDivider(),
          _statusRow(
            context,
            emoji: data.groupById[groupId]!.icon,
            name: data.groupById[groupId]!.name,
            status: status,
            expanded: _expanded.contains(groupId),
            onTap: () => setState(() => _expanded.contains(groupId) ? _expanded.remove(groupId) : _expanded.add(groupId)),
          ),
          if (_expanded.contains(groupId))
            for (final cat in data.categoriesIn(groupId, includeArchived: true))
              if (cat.monthlyBudget > 0 && !cat.isArchived || (spent[cat.id] ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: _statusRow(
                    context,
                    emoji: cat.emoji,
                    name: cat.name,
                    status: CategoryStatus(budget: cat.isArchived ? 0 : cat.monthlyBudget, spent: spent[cat.id] ?? 0),
                  ),
                ),
        ],
      ],
    );
  }

  Widget _statusRow(
    BuildContext context, {
    required String emoji,
    required String name,
    required CategoryStatus status,
    bool? expanded,
    VoidCallback? onTap,
  }) {
    final c = AppColors.of(context);
    final warn = status.state == CategoryState.over || status.state == CategoryState.noBudget;
    final semantics = StringBuffer('$name, ${formatEuro(status.spent)} spent');
    switch (status.state) {
      case CategoryState.over:
        semantics.write(' of ${formatEuro(status.budget)}, ${formatEuro(status.spent - status.budget)} over budget');
      case CategoryState.noBudget:
      case CategoryState.empty:
        semantics.write(', no budget set');
      case CategoryState.within:
        semantics.write(' of ${formatEuro(status.budget)}, ${formatEuro(status.remaining)} left');
    }
    if (expanded != null) semantics.write(expanded ? '. Tap to hide categories' : '. Tap to show categories');
    return ListRow(
      emoji: emoji,
      title: name,
      subtitle: Text(
        status.label,
        style: AppText.small.copyWith(color: warn ? c.overText : c.inkSoft, fontWeight: warn ? FontWeight.w800 : FontWeight.w600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(formatEuro(status.spent), style: AppText.amount.copyWith(color: c.ink)),
          if (expanded != null) ...[
            const SizedBox(width: 6),
            Icon(expanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down, size: 16, color: c.inkSoft),
          ],
        ],
      ),
      below: ProgressBar(value: status.progress, color: warn ? c.over : c.ink),
      onTap: onTap,
      semanticLabel: semantics.toString(),
    );
  }
}

class _Latest extends StatelessWidget {
  const _Latest({required this.data, required this.month});

  final AppData data;
  final BudgetMonth month;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final txns = data.transactionsIn(month);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Latest'),
        if (txns.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Nothing logged in ${month.label} yet. Tap + to add what you spend or receive.',
              style: AppText.bodyRegular.copyWith(color: c.inkSoft),
            ),
          ),
        for (final (i, t) in txns.take(4).indexed) ...[
          if (i > 0) const RowDivider(),
          TxnRow(txn: t, data: data, onTap: () => showAddSheet(context, editing: t)),
        ],
        if (txns.isNotEmpty)
          LinkButton(
            label: 'See everything this month',
            onPressed: () => HomeTabs.maybeOf(context)?.select(HomeTabs.history),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Highlighter(child: Text('Start here', style: AppText.title.copyWith(color: c.ink))),
          const SizedBox(height: 12),
          Text(
            'Tell the app how much money comes in each month (salaries, child benefit, allowances). '
            "It will then work out how much you can spend each day.",
            style: AppText.bodyRegular.copyWith(color: c.ink),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Set my monthly income',
            onPressed: () => Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => const IncomeSetupPage())),
          ),
        ],
      ),
    );
  }
}

class _BackupBanner extends StatelessWidget {
  const _BackupBanner();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final BudgetStore store = StoreScope.read(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: NoteBox(
        color: c.highlight.withValues(alpha: 0.25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("It's been a while since your last backup.", style: AppText.body.copyWith(color: c.ink)),
            const SizedBox(height: 4),
            Text(
              'Your budget only lives on this phone. Save a backup so you don\'t lose it if the app needs reinstalling.',
              style: AppText.small.copyWith(color: c.inkSoft),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(44, 44),
                  color: c.ink,
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () => saveBackup(context),
                  child: Text('Save backup', style: AppText.small.copyWith(color: c.onInk, fontWeight: FontWeight.w800)),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(44, 44),
                  onPressed: store.hideBackupReminder,
                  child: Text('Not now', style: AppText.small.copyWith(color: c.ink)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
