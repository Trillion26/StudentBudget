import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../data/app_data.dart';
import '../../data/budget_store.dart';
import '../../data/database.dart';
import '../../design/app_colors.dart';
import '../../design/haptics.dart';
import '../../design/theme.dart';
import '../../design/toast.dart';
import '../../design/widgets.dart';
import '../../logic/budget_calculator.dart';
import '../../logic/dates.dart';
import '../../logic/models.dart';
import '../../logic/money.dart';
import '../../logic/validation.dart';
import 'chips.dart';

/// Opens the Add sheet. Pass [editing] to edit an existing transaction, or
/// [kind] and [goalId] to pre-fill it (used by the goal cards).
Future<void> showAddSheet(BuildContext context, {TxnKind kind = TxnKind.expense, String? goalId, Txn? editing}) {
  return showCupertinoSheet<void>(
    context: context,
    scrollableBuilder: (context, controller) => AddSheet(
      scrollController: controller,
      initialKind: editing?.kind ?? kind,
      initialGoalId: editing?.goalId ?? goalId,
      editing: editing,
    ),
  );
}

const _kindLabels = ['Spent', 'Received', 'Saved', 'Took from savings'];

String actionLabel(TxnKind kind) => switch (kind) {
      TxnKind.expense => 'Add expense',
      TxnKind.income => 'Add income',
      TxnKind.toSavings => 'Add to savings',
      TxnKind.fromSavings => 'Take from savings',
    };

/// "Added R85,50 to Groceries"
String savedMessage(TxnKind kind, int amount, String name) => switch (kind) {
      TxnKind.expense => 'Added ${formatRand(amount)} to $name',
      TxnKind.income => 'Added ${formatRand(amount)} from $name',
      TxnKind.toSavings => 'Added ${formatRand(amount)} to $name',
      TxnKind.fromSavings => 'Took ${formatRand(amount)} from $name',
    };

class AddSheet extends StatefulWidget {
  const AddSheet({super.key, this.scrollController, required this.initialKind, this.initialGoalId, this.editing});

  final ScrollController? scrollController;
  final TxnKind initialKind;
  final String? initialGoalId;
  final Txn? editing;

  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  late TxnKind _kind = widget.initialKind;
  late final TextEditingController _amount = TextEditingController(
    text: widget.editing == null ? '' : formatAmountForField(widget.editing!.amount),
  );
  late final TextEditingController _note = TextEditingController(text: widget.editing?.note ?? '');
  late final FocusNode _amountFocus = FocusNode();
  late String? _categoryId = widget.editing?.categoryId;
  late String? _goalId = widget.initialGoalId;
  DateTime? _date;
  bool _showAllCategories = false;
  bool _saving = false;
  String? _saveError;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
    _date = widget.editing?.date;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  bool get _needsGoal => _kind == TxnKind.toSavings || _kind == TxnKind.fromSavings;
  bool get _needsCategory => _kind == TxnKind.income || _kind == TxnKind.expense;

  AmountParseResult get _parsed => parseAmount(_amount.text);

  bool get _canSave {
    if (_saving || !_parsed.isValid) return false;
    if (_needsCategory && _categoryId == null) return false;
    if (_needsGoal && _goalId == null) return false;
    return true;
  }

  void _setKind(TxnKind kind) {
    if (kind == _kind) return;
    setState(() {
      final wasIncome = _kind == TxnKind.income;
      final isIncome = kind == TxnKind.income;
      _kind = kind;
      _showAllCategories = false;
      // A category only carries over between expense and "took from savings".
      if (wasIncome != isIncome || kind == TxnKind.toSavings) _categoryId = null;
      if (!_needsGoal) _goalId = null;
    });
  }

  List<ChipItem> _categoryChips(AppData data, {required bool income}) {
    final active = income ? data.activeIncomeCategories : data.activeSpendingCategories;
    // Most used first; until there is history, the biggest budgets first.
    final list = data.byUsage(active, (c) => c.id, thenBy: (c) => c.monthlyBudget);
    final selected = _categoryId == null ? null : data.categoryById[_categoryId];
    if (selected != null && !list.any((c) => c.id == selected.id)) list.insert(0, selected);
    return [for (final c in list) ChipItem(id: c.id, emoji: c.emoji, label: c.name)];
  }

  List<ChipItem> _goalChips(AppData data) {
    final list = data.byUsage(data.activeGoals, (g) => g.id);
    final selected = _goalId == null ? null : data.goalById[_goalId];
    if (selected != null && !list.any((g) => g.id == selected.id)) list.insert(0, selected);
    return [for (final g in list) ChipItem(id: g.id, emoji: g.emoji, label: g.name)];
  }

  Future<void> _pickDate(BuildContext context, DateTime today) async {
    final c = AppColors.of(context);
    var picked = _date ?? today;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        color: c.card,
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Done', style: AppText.body.copyWith(color: c.ink, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            SizedBox(
              height: 216,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: DateTime(picked.year, picked.month, picked.day),
                minimumDate: DateTime(2020, 1, 1),
                maximumDate: () {
                  final latest = Validation.latestDate(today);
                  return DateTime(latest.year, latest.month, latest.day);
                }(),
                dateOrder: DatePickerDateOrder.dmy,
                onDateTimeChanged: (value) => picked = dateOnly(value),
              ),
            ),
          ],
        ),
      ),
    );
    setState(() => _date = picked);
  }

  String _dateLabel(DateTime date, DateTime today) {
    final diff = daysBetween(date, today);
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff == -1) return 'Tomorrow';
    return '${weekdayNames[date.weekday - 1].substring(0, 3)} ${shortDate(date)}';
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final store = StoreScope.read(context);
    final toast = ToastHost.of(context);
    final navigator = Navigator.of(context);
    final data = store.data;
    final today = store.today();
    final date = _date ?? today;
    final draft = TxnDraft(
      kind: _kind,
      amount: _parsed.cents!,
      date: date,
      note: _note.text,
      categoryId: _kind == TxnKind.toSavings ? null : _categoryId,
      goalId: _needsGoal ? _goalId : null,
    );
    final error = draft.validate(today);
    if (error != null) {
      setState(() => _saveError = error);
      return;
    }
    setState(() => _saving = true);

    // Work out the haptic before saving.
    final month = data.monthOf(date);
    var pushesOver = false;
    var reachesGoal = false;
    if (_kind == TxnKind.expense && _categoryId != null) {
      final category = data.categoryById[_categoryId]!;
      var spent = BudgetCalculator.spentByCategory(data.facts, month)[_categoryId] ?? 0;
      if (_isEditing && widget.editing!.kind == TxnKind.expense && widget.editing!.categoryId == _categoryId &&
          month.contains(widget.editing!.date)) {
        spent -= widget.editing!.amount;
      }
      final before = CategoryStatus(budget: category.monthlyBudget, spent: spent);
      final after = CategoryStatus(budget: category.monthlyBudget, spent: spent + draft.amount);
      pushesOver = !before.isOver && after.isOver;
    }
    if (_kind == TxnKind.toSavings && _goalId != null) {
      final goal = data.goalById[_goalId]!;
      final current = data.monthOf(today);
      final before = data.goalProgress(goal, current);
      reachesGoal = before.target != null && before.balance < before.target! && before.balance + draft.amount >= before.target!;
    }

    try {
      if (_isEditing) {
        final old = widget.editing!;
        await store.updateTransaction(old.id, draft);
        navigator.pop();
        toast.show('Changes saved', onUndo: () => store.restoreTransaction(old));
      } else {
        final row = await store.addTransaction(draft);
        navigator.pop();
        final name = store.data.describe(row);
        final target = _kind == TxnKind.fromSavings ? (store.data.goalById[row.goalId]?.name ?? name) : name;
        toast.show(savedMessage(_kind, draft.amount, target), onUndo: () => store.deleteTransaction(row.id));
      }
      if (reachesGoal) {
        await Haptics.success();
      } else if (pushesOver) {
        await Haptics.warning();
      } else {
        await Haptics.saved();
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _saveError = e is ArgumentError ? '${e.message}' : 'That didn\'t save. Try again.';
      });
    }
  }

  Future<void> _delete() async {
    final store = StoreScope.read(context);
    final toast = ToastHost.of(context);
    final navigator = Navigator.of(context);
    final deleted = await store.deleteTransaction(widget.editing!.id);
    navigator.pop();
    if (deleted != null) toast.show('Deleted', onUndo: () => store.restoreTransaction(deleted));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final data = store.data;
    final today = store.today();
    final c = AppColors.of(context);
    final amountText = _amount.text.trim();
    final amountError = amountText.isEmpty ? null : _parsed.error;

    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 10),
          child: Text(text, style: AppText.small.copyWith(color: c.inkSoft)),
        );

    final categoryPicker = <Widget>[];
    if (_kind == TxnKind.income || _kind == TxnKind.expense || _kind == TxnKind.fromSavings) {
      final income = _kind == TxnKind.income;
      final chips = _categoryChips(data, income: income);
      final optional = _kind == TxnKind.fromSavings;
      categoryPicker.add(label(optional ? 'What was it for? (optional)' : 'Category'));
      if (income || _showAllCategories || chips.length <= 12) {
        if (!income && _showAllCategories) {
          // Grouped by budget group so a category is easy to find.
          for (final g in data.spendingGroups) {
            final inGroup = data.categoriesIn(g.id);
            if (inGroup.isEmpty) continue;
            categoryPicker.add(Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Text('${g.icon} ${g.name}', style: AppText.small.copyWith(color: c.inkSoft)),
            ));
            categoryPicker.add(ChipGrid(
              items: [for (final cat in inGroup) ChipItem(id: cat.id, emoji: cat.emoji, label: cat.name)],
              selectedId: _categoryId,
              onSelected: (id) => setState(() => _categoryId = optional && _categoryId == id ? null : id),
            ));
          }
        } else {
          categoryPicker.add(ChipGrid(
            items: chips,
            selectedId: _categoryId,
            onSelected: (id) => setState(() => _categoryId = optional && _categoryId == id ? null : id),
          ));
        }
      } else {
        categoryPicker.add(ChipGrid(
          items: chips.take(12).toList(),
          selectedId: _categoryId,
          onSelected: (id) => setState(() => _categoryId = optional && _categoryId == id ? null : id),
        ));
      }
      if (!income && chips.length > 12) {
        categoryPicker.add(Align(
          alignment: Alignment.centerLeft,
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 8),
            minimumSize: const Size(44, 44),
            onPressed: () => setState(() => _showAllCategories = !_showAllCategories),
            child: Text(
              _showAllCategories ? 'Show most used' : 'All categories',
              style: AppText.body.copyWith(color: c.ink, decoration: TextDecoration.underline, decorationColor: c.highlight, decorationThickness: 2),
            ),
          ),
        ));
      }
    }

    final goalPicker = <Widget>[];
    if (_needsGoal) {
      goalPicker.add(label(_kind == TxnKind.toSavings ? 'Which goal?' : 'Which goal did it come from?'));
      final goals = _goalChips(data);
      if (goals.isEmpty) {
        goalPicker.add(Text('Add a goal on the Goals tab first.', style: AppText.bodyRegular.copyWith(color: c.inkSoft)));
      } else {
        goalPicker.add(ChipGrid(items: goals, selectedId: _goalId, onSelected: (id) => setState(() => _goalId = id)));
      }
    }

    final date = _date ?? today;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return CupertinoPageScaffold(
      backgroundColor: c.paper,
      resizeToAvoidBottomInset: false,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  CupertinoButton(
                    minimumSize: const Size(44, 44),
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: AppText.body.copyWith(color: c.ink)),
                  ),
                  Expanded(
                    child: Text(
                      _isEditing ? 'Edit entry' : 'Add',
                      textAlign: TextAlign.center,
                      style: AppText.body.copyWith(color: c.ink, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (_isEditing)
                    CupertinoButton(
                      minimumSize: const Size(44, 44),
                      onPressed: _delete,
                      child: Text('Delete', style: AppText.body.copyWith(color: c.overText)),
                    )
                  else
                    const SizedBox(width: 80),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: widget.scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  KindSegments<TxnKind>(
                    values: const [TxnKind.expense, TxnKind.income, TxnKind.toSavings, TxnKind.fromSavings],
                    labels: _kindLabels,
                    selected: _kind,
                    onChanged: _setKind,
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    label: 'Amount in rand',
                    textField: true,
                    child: CupertinoTextField(
                      key: const Key('amountField'),
                      controller: _amount,
                      focusNode: _amountFocus,
                      autofocus: !_isEditing,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]'))],
                      textInputAction: TextInputAction.done,
                      placeholder: '0',
                      prefix: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text('R', style: AppText.hero.copyWith(fontSize: 40, color: c.inkSoft)),
                      ),
                      style: AppText.hero.copyWith(fontSize: 40, color: c.ink),
                      placeholderStyle: AppText.hero.copyWith(fontSize: 40, color: c.line),
                      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: amountError != null ? c.overText : c.line, width: 1.5),
                      ),
                      cursorColor: c.ink,
                      onSubmitted: (_) => _save(),
                    ),
                  ),
                  if (amountError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(amountError, style: AppText.small.copyWith(color: c.overText)),
                    ),
                  ...goalPicker,
                  ...categoryPicker,
                  label('Note (optional)'),
                  CupertinoTextField(
                    key: const Key('noteField'),
                    controller: _note,
                    maxLength: Validation.maxNoteLength,
                    placeholder: _kind == TxnKind.expense ? 'e.g. Checkers, taxi to campus' : 'Add a short note',
                    style: AppText.bodyRegular.copyWith(color: c.ink),
                    placeholderStyle: AppText.bodyRegular.copyWith(color: c.inkSoft.withValues(alpha: 0.7)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.line),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  label('Date'),
                  Semantics(
                    button: true,
                    label: 'Date, ${_dateLabel(date, today)}. Tap to change.',
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _pickDate(context, today),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: c.line),
                        ),
                        child: Row(
                          children: [
                            Icon(CupertinoIcons.calendar, color: c.inkSoft, size: 20),
                            const SizedBox(width: 12),
                            Expanded(child: Text(_dateLabel(date, today), style: AppText.body.copyWith(color: c.ink))),
                            Text('Change', style: AppText.small.copyWith(color: c.inkSoft)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(color: c.paper, border: Border(top: BorderSide(color: c.line))),
              padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + (bottomInset > 0 ? bottomInset : MediaQuery.paddingOf(context).bottom)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_saveError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_saveError!, style: AppText.small.copyWith(color: c.overText)),
                    ),
                  PrimaryButton(
                    key: const Key('saveButton'),
                    label: _isEditing ? 'Save changes' : actionLabel(_kind),
                    onPressed: _canSave ? _save : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
