import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Dismissible, DismissDirection;

import '../../app_scope.dart';
import '../../data/app_data.dart';
import '../../data/database.dart';
import '../../design/app_colors.dart';
import '../../design/theme.dart';
import '../../design/toast.dart';
import '../../design/widgets.dart';
import '../../logic/budget_month.dart';
import '../../logic/dates.dart';
import '../../logic/models.dart';
import '../../logic/money.dart';
import '../add/add_sheet.dart';
import '../add/chips.dart';
import 'txn_row.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final TextEditingController _search = TextEditingController();
  TxnKind? _kind;
  String? _groupId;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Txn t, AppData data) {
    if (_kind != null && t.kind != _kind) return false;
    if (_groupId != null) {
      final category = data.categoryById[t.categoryId];
      if (category == null || category.groupId != _groupId) return false;
    }
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    final category = data.categoryById[t.categoryId]?.name.toLowerCase() ?? '';
    final goal = data.goalById[t.goalId]?.name.toLowerCase() ?? '';
    return t.note.toLowerCase().contains(query) || category.contains(query) || goal.contains(query);
  }

  Future<void> _pickGroup(BuildContext context, AppData data) async {
    final picked = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Show one group'),
        actions: [
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(context, ''), child: const Text('All groups')),
          for (final g in data.groups)
            CupertinoActionSheetAction(onPressed: () => Navigator.pop(context, g.id), child: Text('${g.icon} ${g.name}')),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ),
    );
    if (picked == null) return;
    setState(() => _groupId = picked.isEmpty ? null : picked);
  }

  Future<void> _delete(BuildContext context, Txn t) async {
    final store = StoreScope.read(context);
    final toast = ToastHost.of(context);
    final deleted = await store.deleteTransaction(t.id);
    if (deleted != null) {
      toast.show('Deleted ${formatRand(deleted.amount)} ${store.data.describe(deleted)}', onUndo: () => store.restoreTransaction(deleted));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final data = store.data;
    final selected = SelectedMonthScope.of(context);
    final today = store.today();
    final current = data.monthOf(today);
    final month = selected.resolve(current);
    final c = AppColors.of(context);

    final all = data.transactionsIn(month);
    final shown = all.where((t) => _matches(t, data)).toList();

    // Spending so far this month, oldest day first, for the running totals.
    final spentByDay = <DateTime, int>{};
    for (final t in all) {
      if (t.kind == TxnKind.expense) spentByDay[t.date] = (spentByDay[t.date] ?? 0) + t.amount;
    }
    final runningTotal = <DateTime, int>{};
    var running = 0;
    for (final d in spentByDay.keys.toList()..sort()) {
      running += spentByDay[d]!;
      runningTotal[d] = running;
    }

    final days = <DateTime, List<Txn>>{};
    for (final t in shown) {
      days.putIfAbsent(t.date, () => []).add(t);
    }
    final filtersOn = _kind != null || _groupId != null || _search.text.trim().isNotEmpty;

    return PageScaffold(
      title: 'History',
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: MonthSwitcher(
              month: month,
              latest: current.next,
              earliest: BudgetMonth(2020, 1, data.startDay),
              onChanged: (m) => selected.select(m, current),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: CupertinoSearchTextField(
              controller: _search,
              placeholder: 'Search notes and categories',
              style: AppText.bodyRegular.copyWith(color: c.ink),
              backgroundColor: c.card,
              borderRadius: BorderRadius.circular(12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                for (final (kind, label) in [
                  (null, 'All'),
                  (TxnKind.expense, 'Spent'),
                  (TxnKind.income, 'Received'),
                  (TxnKind.toSavings, 'Saved'),
                  (TxnKind.fromSavings, 'From savings'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: EmojiChip(
                      item: ChipItem(id: label, emoji: '', label: label),
                      selected: _kind == kind,
                      onTap: () => setState(() => _kind = kind),
                    ),
                  ),
                EmojiChip(
                  item: ChipItem(
                    id: 'group',
                    emoji: _groupId == null ? '' : data.groupById[_groupId]!.icon,
                    label: _groupId == null ? 'All groups ▾' : '${data.groupById[_groupId]!.name} ▾',
                  ),
                  selected: _groupId != null,
                  onTap: () => _pickGroup(context, data),
                ),
              ],
            ),
          ),
        ),
        if (shown.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
              child: Text(
                filtersOn ? 'Nothing matches. Try a different search or filter.' : 'Nothing logged in ${month.label} yet. Tap + to add what you spend or receive.',
                style: AppText.bodyRegular.copyWith(color: c.inkSoft),
              ),
            ),
          ),
        for (final entry in days.entries) ...[
          SliverToBoxAdapter(child: _DayHeader(date: entry.key, spent: spentByDay[entry.key] ?? 0, runningTotal: runningTotal[entry.key])),
          SliverList.separated(
            itemCount: entry.value.length,
            separatorBuilder: (_, _) => const RowDivider(),
            itemBuilder: (context, i) {
              final t = entry.value[i];
              return Dismissible(
                key: ValueKey(t.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: c.over,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: Text('Delete', style: AppText.body.copyWith(color: const Color(0xFF3A0A16), fontWeight: FontWeight.w800)),
                ),
                onDismissed: (_) => _delete(context, t),
                child: Semantics(
                  customSemanticsActions: {
                    const CustomSemanticsAction(label: 'Delete'): () => _delete(context, t),
                  },
                  child: TxnRow(txn: t, data: data, onTap: () => showAddSheet(context, editing: t)),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date, required this.spent, required this.runningTotal});

  final DateTime date;
  final int spent;
  final int? runningTotal;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Semantics(
        header: true,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 12,
          runSpacing: 2,
          children: [
            Text(longDayLabel(date), style: AppText.body.copyWith(color: c.ink, fontWeight: FontWeight.w800)),
            if (spent > 0)
              Text(
                'Spent ${formatRand(spent)} · ${formatRand(runningTotal ?? spent)} so far',
                style: AppText.small.copyWith(color: c.inkSoft, fontFeatures: tabular),
              ),
          ],
        ),
      ),
    );
  }
}
