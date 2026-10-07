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

/// Add or edit a debt.
class DebtEditPage extends StatefulWidget {
  const DebtEditPage({super.key, this.debt});

  final Debt? debt;

  @override
  State<DebtEditPage> createState() => _DebtEditPageState();
}

class _DebtEditPageState extends State<DebtEditPage> {
  late final TextEditingController _name = TextEditingController(text: widget.debt?.name ?? '');
  late final TextEditingController _lender = TextEditingController(text: widget.debt?.lender ?? '');
  late final TextEditingController _rate = TextEditingController(
    text: widget.debt == null || widget.debt!.annualInterestRatePercent == 0 ? '' : _formatRate(widget.debt!.annualInterestRatePercent),
  );
  late int _balance = widget.debt?.balanceOnStartDate ?? 0;
  late DateTime? _startDate = widget.debt?.startDate;
  late String? _categoryId = widget.debt?.linkedCategoryId;
  late int _statement = widget.debt?.latestStatementBalance ?? 0;
  late DateTime? _statementDate = widget.debt?.latestStatementDate;
  String? _nameError;
  String? _rateError;

  static String _formatRate(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString().replaceAll('.', ',');

  @override
  void dispose() {
    _name.dispose();
    _lender.dispose();
    _rate.dispose();
    super.dispose();
  }

  double? _parseRate() {
    final text = _rate.text.trim().replaceAll(',', '.').replaceAll('%', '');
    if (text.isEmpty) return 0;
    final v = double.tryParse(text);
    if (v == null || v < 0 || v > 100) return null;
    return v;
  }

  Future<DateTime?> _pickDate(DateTime initial, DateTime today) async {
    final c = AppColors.of(context);
    var picked = initial;
    final ok = await showCupertinoModalPopup<bool>(
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
              mode: CupertinoDatePickerMode.date,
              dateOrder: DatePickerDateOrder.dmy,
              initialDateTime: DateTime(initial.year, initial.month, initial.day),
              minimumDate: DateTime(2000, 1, 1),
              maximumDate: DateTime(today.year, today.month, today.day),
              onDateTimeChanged: (v) => picked = dateOnly(v),
            ),
          ),
        ]),
      ),
    );
    return ok == true ? picked : null;
  }

  Future<void> _save() async {
    final nameError = Validation.name(_name.text, thing: 'the debt');
    final rate = _parseRate();
    setState(() {
      _nameError = nameError;
      _rateError = rate == null ? 'Enter a rate from 0 to 100, like 7,5' : null;
    });
    if (nameError != null || rate == null) return;
    final store = StoreScope.read(context);
    await store.saveDebt(
      id: widget.debt?.id,
      name: _name.text,
      lender: _lender.text,
      balanceOnStartDate: _balance,
      startDate: _startDate ?? store.today(),
      annualInterestRatePercent: rate,
      linkedCategoryId: _categoryId,
      latestStatementBalance: _statement > 0 ? _statement : null,
      latestStatementDate: _statement > 0 ? (_statementDate ?? store.today()) : null,
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Delete ${widget.debt!.name}?'),
        content: const Text('Your repayments stay in History.'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await StoreScope.read(context).deleteDebt(widget.debt!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final data = store.data;
    final c = AppColors.of(context);
    final today = store.today();
    final category = _categoryId == null ? null : data.categoryById[_categoryId];

    Widget pickerBox(String text, {bool muted = false}) => NoteBox(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(children: [
            Expanded(child: Text(text, style: AppText.body.copyWith(color: muted ? c.inkSoft : c.ink))),
            Icon(CupertinoIcons.chevron_down, size: 16, color: c.inkSoft),
          ]),
        );

    return PageScaffold(
      title: widget.debt == null ? 'New debt' : 'Edit debt',
      showBack: true,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverList.list(children: [
            LabeledField(
              label: 'Name',
              error: _nameError,
              child: AppTextField(controller: _name, maxLength: Validation.maxNameLength, placeholder: 'e.g. Store card', semanticLabel: 'Debt name', hasError: _nameError != null),
            ),
            LabeledField(
              label: 'Lender (optional)',
              child: AppTextField(controller: _lender, maxLength: Validation.maxNameLength, placeholder: 'e.g. NSFAS, Edgars, my aunt', semanticLabel: 'Lender'),
            ),
            LabeledField(
              label: 'Balance on the start date',
              child: RandField(cents: _balance, width: double.infinity, textAlign: TextAlign.left, semanticLabel: 'Balance on the start date', onChanged: (v) => _balance = v),
            ),
            LabeledField(
              label: 'Start date',
              help: 'Repayments from this date on are counted.',
              child: Semantics(
                button: true,
                label: 'Start date ${shortDate(_startDate ?? today)}',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () async {
                    final picked = await _pickDate(_startDate ?? today, today);
                    if (picked != null) setState(() => _startDate = picked);
                  },
                  child: pickerBox(shortDate(_startDate ?? today)),
                ),
              ),
            ),
            LabeledField(
              label: 'Interest rate a year (%)',
              error: _rateError,
              child: AppTextField(
                controller: _rate,
                placeholder: '0',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                semanticLabel: 'Interest rate per year, percent',
                hasError: _rateError != null,
              ),
            ),
            LabeledField(
              label: 'Repayments are logged under',
              child: GestureDetector(
                onTap: () async {
                  final options = data.activeSpendingCategories;
                  final picked = await showCupertinoModalPopup<String>(
                    context: context,
                    builder: (context) => CupertinoActionSheet(
                      title: const Text('Which category do you use for repayments?'),
                      actions: [
                        CupertinoActionSheetAction(onPressed: () => Navigator.pop(context, ''), child: const Text('None')),
                        for (final cat in options)
                          CupertinoActionSheetAction(onPressed: () => Navigator.pop(context, cat.id), child: Text('${cat.emoji} ${cat.name}')),
                      ],
                      cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    ),
                  );
                  if (picked != null) setState(() => _categoryId = picked.isEmpty ? null : picked);
                },
                child: pickerBox(category == null ? 'Pick a category' : '${category.emoji} ${category.name}', muted: category == null),
              ),
            ),
            LabeledField(
              label: 'Latest statement balance (optional)',
              help: 'If you enter this, it replaces the estimate.',
              child: RandField(
                cents: _statement,
                width: double.infinity,
                textAlign: TextAlign.left,
                semanticLabel: 'Latest statement balance',
                onChanged: (v) => setState(() => _statement = v),
              ),
            ),
            if (_statement > 0)
              LabeledField(
                label: 'Statement date',
                child: GestureDetector(
                  onTap: () async {
                    final picked = await _pickDate(_statementDate ?? today, today);
                    if (picked != null) setState(() => _statementDate = picked);
                  },
                  child: pickerBox(shortDate(_statementDate ?? today)),
                ),
              ),
            PrimaryButton(label: widget.debt == null ? 'Add debt' : 'Save', onPressed: _save),
            if (widget.debt != null) ...[
              const SizedBox(height: 12),
              SecondaryButton(label: 'Delete debt', color: c.overText, onPressed: _delete),
            ],
          ]),
        ),
      ],
    );
  }
}
