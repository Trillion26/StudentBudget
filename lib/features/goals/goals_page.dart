import 'package:flutter/cupertino.dart';

import '../../app_scope.dart';
import '../../data/database.dart';
import '../../design/app_colors.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';
import '../../logic/budget_calculator.dart';
import '../../logic/money.dart';
import '../../logic/models.dart';
import '../add/add_sheet.dart';
import 'goal_edit_page.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final data = store.data;
    final c = AppColors.of(context);
    final current = data.monthOf(store.today());
    final active = data.activeGoals;
    final archived = data.goals.where((g) => g.isArchived).toList();
    final total = active.fold(0, (a, g) => a + data.goalProgress(g, current).balance);

    void open(Widget page) => Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => page));

    return PageScaffold(
      title: 'Goals',
      trailing: Semantics(
        button: true,
        label: 'Add a goal',
        excludeSemantics: true,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          onPressed: () => open(const GoalEditPage()),
          child: Icon(CupertinoIcons.add, color: c.ink),
        ),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('${formatEuro(total)} saved altogether', style: AppText.body.copyWith(color: c.inkSoft)),
          ),
        ),
        SliverList.list(children: [
          for (final g in active) _GoalCard(goal: g, progress: data.goalProgress(g, current), onEdit: () => open(GoalEditPage(goal: g))),
        ]),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: SecondaryButton(label: 'Add a goal', onPressed: () => open(const GoalEditPage())),
          ),
        ),
        if (archived.isNotEmpty)
          SliverToBoxAdapter(
            child: LinkButton(
              label: _showArchived ? 'Hide archived goals' : 'Archived goals (${archived.length})',
              icon: _showArchived ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
              onPressed: () => setState(() => _showArchived = !_showArchived),
            ),
          ),
        if (_showArchived)
          SliverList.list(children: [
            for (final g in archived)
              ListRow(
                emoji: g.emoji,
                title: g.name,
                subtitle: Text('${formatEuro(data.goalProgress(g, current).balance)} in this goal', style: AppText.small.copyWith(color: c.inkSoft)),
                trailing: CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(44, 44),
                  onPressed: () => store.setGoalArchived(g.id, false),
                  child: Text('Bring back', style: AppText.small.copyWith(color: c.ink, fontWeight: FontWeight.w800)),
                ),
              ),
          ]),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.progress, required this.onEdit});

  final SavingsGoal goal;
  final GoalProgress progress;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final statusColor = switch (progress.state) {
      GoalState.reached => c.incomeText,
      GoalState.behind => c.overText,
      _ => c.inkSoft,
    };
    final target = progress.target;
    final plan = progress.planLabel;
    final semantics = StringBuffer('${goal.name}, ${formatEuro(progress.balance)} saved');
    if (target != null) semantics.write(' of ${formatEuro(target)}');
    semantics.write('. ${progress.statusLabel}.');
    if (plan != null) semantics.write(' $plan.');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: NoteBox(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: semantics.toString(),
              hint: 'Tap to edit',
              button: true,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onEdit,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      EmojiTile(goal.emoji, background: c.paper),
                      const SizedBox(width: 14),
                      Expanded(child: Text(goal.name, style: AppText.body.copyWith(color: c.ink, fontWeight: FontWeight.w800))),
                      Icon(CupertinoIcons.pencil, size: 18, color: c.inkSoft),
                    ]),
                    const SizedBox(height: 12),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: 8,
                      children: [
                        Text(formatEuro(progress.balance), style: AppText.amountLarge.copyWith(color: c.ink, fontSize: 26)),
                        if (target != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text('of ${formatEuro(target)}', style: AppText.body.copyWith(color: c.inkSoft)),
                          ),
                      ],
                    ),
                    if (progress.progress != null) ...[
                      const SizedBox(height: 10),
                      ProgressBar(value: progress.progress!, color: c.savings, height: 10),
                    ],
                    const SizedBox(height: 10),
                    Text(progress.statusLabel, style: AppText.small.copyWith(color: statusColor, fontWeight: FontWeight.w800)),
                    if (plan != null) ...[
                      const SizedBox(height: 2),
                      Text(plan, style: AppText.small.copyWith(color: c.inkSoft)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  minimumSize: const Size(44, 44),
                  onPressed: () => showAddSheet(context, kind: TxnKind.toSavings, goalId: goal.id),
                  child: Text('Add money', style: AppText.body.copyWith(color: c.ink, fontWeight: FontWeight.w800, decoration: TextDecoration.underline, decorationColor: c.highlight, decorationThickness: 2)),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(44, 44),
                  onPressed: progress.balance > 0 ? () => showAddSheet(context, kind: TxnKind.fromSavings, goalId: goal.id) : null,
                  child: Text('Take money out', style: AppText.body.copyWith(color: progress.balance > 0 ? c.ink : c.line)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
