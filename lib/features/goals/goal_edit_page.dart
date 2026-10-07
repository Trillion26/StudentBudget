import 'package:flutter/cupertino.dart';

import '../../app_scope.dart';
import '../../data/database.dart';
import '../../design/app_colors.dart';
import '../../design/form_fields.dart';
import '../../design/rand_field.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';
import '../../logic/dates.dart';
import '../../logic/validation.dart';

/// Shows a month picker and returns the last day of the picked month.
Future<DateTime?> pickMonth(BuildContext context, {required DateTime initial, required DateTime minimum, required DateTime maximum}) async {
  final c = AppColors.of(context);
  var picked = initial;
  final done = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (context) => Container(
      color: c.card,
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          CupertinoButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: AppText.body.copyWith(color: c.ink))),
          CupertinoButton(onPressed: () => Navigator.pop(context, true), child: Text('Done', style: AppText.body.copyWith(color: c.ink, fontWeight: FontWeight.w800))),
        ]),
        SizedBox(
          height: 216,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.monthYear,
            initialDateTime: DateTime(initial.year, initial.month, 1),
            minimumDate: DateTime(minimum.year, minimum.month, 1),
            maximumDate: DateTime(maximum.year, maximum.month, 1),
            onDateTimeChanged: (v) => picked = DateTime.utc(v.year, v.month + 1, 0),
          ),
        ),
      ]),
    ),
  );
  return done == true ? DateTime.utc(picked.year, picked.month + 1, 0) : null;
}

/// Add or edit a savings goal.
class GoalEditPage extends StatefulWidget {
  const GoalEditPage({super.key, this.goal});

  final SavingsGoal? goal;

  @override
  State<GoalEditPage> createState() => _GoalEditPageState();
}

class _GoalEditPageState extends State<GoalEditPage> {
  late final TextEditingController _name = TextEditingController(text: widget.goal?.name ?? '');
  late String _emoji = widget.goal?.emoji ?? '🐷';
  late int _target = widget.goal?.targetAmount ?? 0;
  late DateTime? _targetDate = widget.goal?.targetDate;
  late int _starting = widget.goal?.startingBalance ?? 0;
  String? _error;

  bool get _isNew => widget.goal == null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = Validation.name(_name.text, thing: 'the goal');
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    await StoreScope.read(context).saveGoal(
      id: widget.goal?.id,
      name: _name.text,
      emoji: _emoji,
      targetAmount: _target > 0 ? _target : null,
      targetDate: _target > 0 ? _targetDate : null,
      startingBalance: _starting,
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _toggleArchive() async {
    final store = StoreScope.read(context);
    final archive = !widget.goal!.isArchived;
    if (archive) {
      final ok = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('Archive ${widget.goal!.name}?'),
          content: const Text('It is hidden from Goals and the Add sheet. Its history stays, and you can bring it back any time.'),
          actions: [
            CupertinoDialogAction(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.pop(context, true), child: const Text('Archive')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await store.setGoalArchived(widget.goal!.id, archive);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final c = AppColors.of(context);
    final today = store.today();
    return PageScaffold(
      title: _isNew ? 'New goal' : 'Edit goal',
      showBack: true,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverList.list(children: [
            LabeledField(
              label: 'Name',
              error: _error,
              child: AppTextField(
                controller: _name,
                maxLength: Validation.maxNameLength,
                placeholder: 'e.g. New phone',
                semanticLabel: 'Goal name',
                hasError: _error != null,
                autofocus: _isNew,
                onChanged: (_) => setState(() => _error = null),
              ),
            ),
            LabeledField(label: 'Emoji', child: EmojiPicker(value: _emoji, onChanged: (e) => setState(() => _emoji = e))),
            LabeledField(
              label: 'Target (optional)',
              help: 'Leave empty if this is just a pot to save into.',
              child: RandField(cents: _target, width: double.infinity, textAlign: TextAlign.left, semanticLabel: 'Target amount',
                  onChanged: (v) => setState(() => _target = v)),
            ),
            if (_target > 0)
              LabeledField(
                label: 'Reach it by (optional)',
                child: Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await pickMonth(
                          context,
                          initial: _targetDate ?? DateTime.utc(today.year, today.month + 6),
                          minimum: today,
                          maximum: DateTime.utc(today.year + 30),
                        );
                        if (picked != null) setState(() => _targetDate = picked);
                      },
                      child: NoteBox(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        child: Text(
                          _targetDate == null ? 'Pick a month' : monthYearLabel(_targetDate!),
                          style: AppText.body.copyWith(color: _targetDate == null ? c.inkSoft : c.ink),
                        ),
                      ),
                    ),
                  ),
                  if (_targetDate != null)
                    CupertinoButton(
                      minimumSize: const Size(44, 44),
                      onPressed: () => setState(() => _targetDate = null),
                      child: Text('Clear', style: AppText.small.copyWith(color: c.ink)),
                    ),
                ]),
              ),
            LabeledField(
              label: 'Already saved',
              help: 'Money already in this goal before you started using the app.',
              child: RandField(cents: _starting, width: double.infinity, textAlign: TextAlign.left, semanticLabel: 'Starting balance',
                  onChanged: (v) => _starting = v),
            ),
            PrimaryButton(label: _isNew ? 'Add goal' : 'Save', onPressed: _save),
            if (!_isNew) ...[
              const SizedBox(height: 12),
              SecondaryButton(
                label: widget.goal!.isArchived ? 'Bring back' : 'Archive goal',
                color: widget.goal!.isArchived ? null : c.overText,
                onPressed: _toggleArchive,
              ),
            ],
          ]),
        ),
      ],
    );
  }
}
