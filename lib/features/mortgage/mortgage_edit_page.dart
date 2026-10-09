import 'package:flutter/cupertino.dart';

import '../../app_scope.dart';
import '../../data/database.dart';
import '../../data/seed.dart';
import '../../design/app_colors.dart';
import '../../design/euro_field.dart';
import '../../design/form_fields.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';
import '../../logic/dates.dart';
import '../../logic/models.dart';
import '../../logic/money.dart';
import '../../logic/mortgage_calculator.dart';
import '../../logic/validation.dart';
import '../add/chips.dart';
import '../goals/goal_edit_page.dart' show pickMonth;
import 'mortgage_page.dart';

/// Add or edit one mortgage part. When the fixed rate ends, the household
/// enters the new rate with the balance on that date.
class MortgageEditPage extends StatefulWidget {
  const MortgageEditPage({super.key, this.mortgage});

  final Mortgage? mortgage;

  @override
  State<MortgageEditPage> createState() => _MortgageEditPageState();
}

class _MortgageEditPageState extends State<MortgageEditPage> {
  late final Mortgage? _m = widget.mortgage;
  late final TextEditingController _name = TextEditingController(text: _m?.name ?? 'Mortgage');
  late final TextEditingController _lender = TextEditingController(text: _m?.lender ?? '');
  late final TextEditingController _rate = TextEditingController(
    text: _m == null ? '' : formatRate(_m.annualInterestRatePercent).replaceAll('%', ''),
  );
  late MortgageType _type = _m?.type ?? MortgageType.annuity;
  late int _balance = _m?.balance ?? 0;
  DateTime? _balanceDate;
  DateTime? _endDate;
  late DateTime? _fixedUntil = _m?.fixedRateUntil;
  String? _categoryId;
  String? _nameError;
  String? _rateError;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _balanceDate = _m?.balanceDate;
    _endDate = _m?.endDate;
    _categoryId = _m?.linkedCategoryId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // New parts are linked to the Mortgage category when it exists.
    if (_m == null && _categoryId == null) {
      final data = StoreScope.read(context).data;
      _categoryId = data.categories.where((c) => c.name == mortgageCategoryName && !c.isArchived).firstOrNull?.id;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _lender.dispose();
    _rate.dispose();
    super.dispose();
  }

  double? _parseRate() {
    final text = _rate.text.trim().replaceAll(',', '.').replaceAll('%', '');
    if (text.isEmpty) return null;
    final v = double.tryParse(text);
    if (v == null || v < 0 || v > 20) return null;
    return v;
  }

  Future<DateTime?> _pickDay(DateTime initial) async {
    final c = AppColors.of(context);
    var picked = initial;
    final ok = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (context) => Container(
        color: c.card,
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Cancel', style: AppText.body.copyWith(color: c.ink)),
                ),
                CupertinoButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    'Done',
                    style: AppText.body.copyWith(color: c.ink, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 216,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                dateOrder: DatePickerDateOrder.dmy,
                initialDateTime: DateTime(initial.year, initial.month, initial.day),
                minimumDate: DateTime(1990, 1, 1),
                maximumDate: DateTime(Validation.lastYear, 12, 31),
                onDateTimeChanged: (v) => picked = dateOnly(v),
              ),
            ),
          ],
        ),
      ),
    );
    return ok == true ? picked : null;
  }

  Future<void> _save() async {
    final store = StoreScope.read(context);
    final today = store.today();
    final nameError = Validation.name(_name.text, thing: 'the mortgage part');
    final rate = _parseRate();
    final balanceDate = _balanceDate ?? today;
    final endDate = _endDate;
    String? formError;
    if (_balance <= 0) {
      formError = 'Enter the balance still owed';
    } else if (endDate == null) {
      formError = 'Pick the month of the last payment';
    } else {
      formError = Validation.mortgage(balanceDate: balanceDate, endDate: endDate);
    }
    setState(() {
      _nameError = nameError;
      _rateError = rate == null ? 'Enter a rate from 0 to 20, like 4,1' : null;
      _formError = formError;
    });
    if (nameError != null || rate == null || formError != null) return;
    await store.saveMortgage(
      id: _m?.id,
      name: _name.text,
      lender: _lender.text,
      type: _type,
      balance: _balance,
      balanceDate: balanceDate,
      endDate: endDate!,
      annualInterestRatePercent: rate,
      fixedRateUntil: _fixedUntil,
      linkedCategoryId: _categoryId,
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Delete ${_m!.name}?'),
        content: const Text('Your payments stay in History.'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await StoreScope.read(context).deleteMortgage(_m!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final data = store.data;
    final c = AppColors.of(context);
    final today = store.today();
    final category = _categoryId == null ? null : data.categoryById[_categoryId];
    final balanceDate = _balanceDate ?? today;
    final rate = _parseRate();

    // A preview of the first payment after the balance date.
    String? preview;
    if (_balance > 0 &&
        _endDate != null &&
        rate != null &&
        Validation.mortgage(balanceDate: balanceDate, endDate: _endDate!) == null) {
      final schedule = MortgageCalculator.schedule(
        balance: _balance,
        balanceDate: balanceDate,
        endDate: _endDate!,
        annualRatePercent: rate,
        type: _type,
      );
      final first = schedule.first;
      preview =
          '${monthYearLabel(first.month)}: ${formatEuro(first.total)} '
          '(${formatEuro(first.interest)} interest, ${formatEuro(first.repayment)} repayment). '
          '${schedule.length} payments in all.';
    }

    Widget pickerBox(String text, {bool muted = false}) => NoteBox(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: AppText.body.copyWith(color: muted ? c.inkSoft : c.ink)),
          ),
          Icon(CupertinoIcons.chevron_down, size: 16, color: c.inkSoft),
        ],
      ),
    );

    return PageScaffold(
      title: _m == null ? 'New loan part' : 'Edit loan part',
      showBack: true,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverList.list(
            children: [
              LabeledField(
                label: 'Name',
                error: _nameError,
                child: AppTextField(
                  controller: _name,
                  maxLength: Validation.maxNameLength,
                  placeholder: 'e.g. Mortgage part 1',
                  semanticLabel: 'Name',
                  hasError: _nameError != null,
                ),
              ),
              LabeledField(
                label: 'Lender (optional)',
                child: AppTextField(
                  controller: _lender,
                  maxLength: Validation.maxNameLength,
                  placeholder: 'e.g. ING, Rabobank',
                  semanticLabel: 'Lender',
                ),
              ),
              LabeledField(
                label: 'Type',
                help: switch (_type) {
                  MortgageType.annuity =>
                    'The same payment every month; you repay more and pay less interest over time.',
                  MortgageType.linear => 'The same repayment every month; the payment goes down as the interest falls.',
                  MortgageType.interestOnly => 'You only pay interest; the loan is repaid at the end.',
                },
                child: KindSegments<MortgageType>(
                  values: MortgageType.values,
                  labels: [for (final t in MortgageType.values) mortgageTypeLabel(t)],
                  selected: _type,
                  onChanged: (t) => setState(() => _type = t),
                ),
              ),
              LabeledField(
                label: 'Still owed',
                child: EuroField(
                  cents: _balance,
                  width: double.infinity,
                  textAlign: TextAlign.left,
                  semanticLabel: 'Balance still owed',
                  onChanged: (v) => setState(() => _balance = v),
                ),
              ),
              LabeledField(
                label: 'On this date',
                help: 'For a new mortgage, the day it started. Otherwise the date of the balance on your latest statement.',
                child: Semantics(
                  button: true,
                  label: 'Balance date ${shortDate(balanceDate)}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () async {
                      final picked = await _pickDay(balanceDate);
                      if (picked != null) setState(() => _balanceDate = picked);
                    },
                    child: pickerBox(shortDate(balanceDate)),
                  ),
                ),
              ),
              LabeledField(
                label: 'Last payment',
                help: 'The month the mortgage ends, usually 30 years after it started.',
                child: GestureDetector(
                  onTap: () async {
                    final picked = await pickMonth(
                      context,
                      initial: _endDate ?? DateTime.utc(balanceDate.year + 30, balanceDate.month),
                      minimum: DateTime.utc(balanceDate.year, balanceDate.month + 1),
                      maximum: DateTime.utc(balanceDate.year + 50, 12),
                    );
                    if (picked != null) setState(() => _endDate = DateTime.utc(picked.year, picked.month));
                  },
                  child: pickerBox(
                    _endDate == null ? 'Pick a month' : monthYearLabel(_endDate!),
                    muted: _endDate == null,
                  ),
                ),
              ),
              LabeledField(
                label: 'Interest rate a year (%)',
                error: _rateError,
                child: AppTextField(
                  controller: _rate,
                  placeholder: 'e.g. 4,1',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  semanticLabel: 'Interest rate per year, percent',
                  hasError: _rateError != null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              LabeledField(
                label: 'Rate fixed until (optional)',
                help: 'The app reminds you a year before the fixed rate ends.',
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await pickMonth(
                            context,
                            initial: _fixedUntil ?? DateTime.utc(today.year + 10, today.month),
                            minimum: DateTime.utc(1990, 1),
                            maximum: DateTime.utc(today.year + 40, 12),
                          );
                          if (picked != null) setState(() => _fixedUntil = DateTime.utc(picked.year, picked.month));
                        },
                        child: pickerBox(
                          _fixedUntil == null ? 'Not set' : monthYearLabel(_fixedUntil!),
                          muted: _fixedUntil == null,
                        ),
                      ),
                    ),
                    if (_fixedUntil != null)
                      CupertinoButton(
                        minimumSize: const Size(44, 44),
                        onPressed: () => setState(() => _fixedUntil = null),
                        child: Text('Clear', style: AppText.body.copyWith(color: c.ink)),
                      ),
                  ],
                ),
              ),
              LabeledField(
                label: 'Payments are logged under',
                child: GestureDetector(
                  onTap: () async {
                    final options = data.activeSpendingCategories;
                    final picked = await showCupertinoModalPopup<String>(
                      context: context,
                      builder: (context) => CupertinoActionSheet(
                        title: const Text('Which category do you use for mortgage payments?'),
                        actions: [
                          CupertinoActionSheetAction(
                            onPressed: () => Navigator.pop(context, ''),
                            child: const Text('None'),
                          ),
                          for (final cat in options)
                            CupertinoActionSheetAction(
                              onPressed: () => Navigator.pop(context, cat.id),
                              child: Text('${cat.emoji} ${cat.name}'),
                            ),
                        ],
                        cancelButton: CupertinoActionSheetAction(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                    );
                    if (picked != null) setState(() => _categoryId = picked.isEmpty ? null : picked);
                  },
                  child: pickerBox(
                    category == null ? 'Pick a category' : '${category.emoji} ${category.name}',
                    muted: category == null,
                  ),
                ),
              ),
              if (preview != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: NoteBox(
                    child: Text('First payment $preview', style: AppText.small.copyWith(color: c.ink)),
                  ),
                ),
              if (_formError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_formError!, style: AppText.small.copyWith(color: c.overText)),
                ),
              PrimaryButton(label: _m == null ? 'Add loan part' : 'Save', onPressed: _save),
              if (_m != null) ...[
                const SizedBox(height: 12),
                SecondaryButton(label: 'Delete loan part', color: c.overText, onPressed: _delete),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
