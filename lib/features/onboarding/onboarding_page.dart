import 'package:flutter/cupertino.dart';

import '../../app_info.dart';
import '../../app_scope.dart';
import '../../data/seed.dart';
import '../../design/app_colors.dart';
import '../../design/highlighter.dart';
import '../../design/theme.dart';
import '../../design/form_fields.dart';
import '../../design/widgets.dart';
import '../../logic/money.dart';
import '../../logic/validation.dart';
import '../settings/settings_page.dart';
import 'income_setup_page.dart';

/// Four short, skippable screens on first launch.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pages = PageController();
  int _index = 0;
  static const _pageCount = 4;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _pageCount - 1) {
      _finish();
      return;
    }
    FocusScope.of(context).unfocus();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _pages.jumpToPage(_index + 1);
    } else {
      _pages.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    }
  }

  void _finish() => StoreScope.read(context).completeOnboarding();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return CupertinoPageScaffold(
      backgroundColor: c.paper,
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Text('${_index + 1} of $_pageCount', style: AppText.small.copyWith(color: c.inkSoft)),
                ),
                const Spacer(),
                CupertinoButton(
                  minimumSize: const Size(44, 44),
                  onPressed: _finish,
                  child: Text('Skip', style: AppText.body.copyWith(color: c.ink)),
                ),
              ],
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _index = i),
                children: const [_Welcome(), _Household(), _Income(), _StartDay()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PrimaryButton(
                key: const Key('onboardingNext'),
                label: _index == _pageCount - 1 ? 'Start budgeting' : 'Next',
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Highlighter(child: Text(appName, style: AppText.title.copyWith(color: c.ink, fontSize: 36))),
        ),
        const SizedBox(height: 20),
        Text(
          'Plan your household\'s month in euros and see how much you can spend each day.',
          style: AppText.body.copyWith(color: c.ink, fontSize: 20),
        ),
        const SizedBox(height: 16),
        Text(
          'Everything stays on this phone. No sign-in, no ads, nothing sent anywhere.',
          style: AppText.bodyRegular.copyWith(color: c.inkSoft),
        ),
      ],
    );
  }
}

/// The partners' first names. They label "who paid" on each entry, and
/// categories such as "Salary – Partner 1".
class _Household extends StatefulWidget {
  const _Household();

  @override
  State<_Household> createState() => _HouseholdState();
}

class _HouseholdState extends State<_Household> {
  late final TextEditingController _one;
  late final TextEditingController _two;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = StoreScope.read(context).data.settings;
    _one = TextEditingController(text: s.partner1Name == 'Partner 1' ? '' : s.partner1Name);
    _two = TextEditingController(text: s.partner2Name == 'Partner 2' ? '' : s.partner2Name);
  }

  @override
  void dispose() {
    _one.dispose();
    _two.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = StoreScope.read(context);
    final one = _one.text.trim().isEmpty ? 'Partner 1' : _one.text;
    final two = _two.text.trim().isEmpty ? 'Partner 2' : _two.text;
    try {
      await store.setPartnerNames(one, two);
      setState(() => _error = null);
    } on ArgumentError catch (e) {
      setState(() => _error = '${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Text('Who\'s in your household?', style: AppText.title.copyWith(color: c.ink)),
        const SizedBox(height: 8),
        Text(
          'Your first names, so you can mark who paid or earned something. '
          'Leave them empty to keep "Partner 1" and "Partner 2".',
          style: AppText.bodyRegular.copyWith(color: c.inkSoft),
        ),
        const SizedBox(height: 16),
        LabeledField(
          label: 'First partner',
          child: AppTextField(
            key: const Key('partner1Field'),
            controller: _one,
            maxLength: Validation.maxPersonNameLength,
            placeholder: 'Partner 1',
            semanticLabel: 'First partner\'s name',
            onChanged: (_) => _save(),
          ),
        ),
        LabeledField(
          label: 'Second partner',
          error: _error,
          child: AppTextField(
            key: const Key('partner2Field'),
            controller: _two,
            maxLength: Validation.maxPersonNameLength,
            placeholder: 'Partner 2',
            semanticLabel: 'Second partner\'s name',
            hasError: _error != null,
            onChanged: (_) => _save(),
          ),
        ),
      ],
    );
  }
}

class _Income extends StatelessWidget {
  const _Income();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Text('What comes in each month?', style: AppText.title.copyWith(color: c.ink)),
        const SizedBox(height: 8),
        Text(
          "Roughly is fine. You can change these any time on the Budget tab.",
          style: AppText.bodyRegular.copyWith(color: c.inkSoft),
        ),
        const SizedBox(height: 12),
        const IncomeFields(),
        const SizedBox(height: 16),
        NoteBox(
          color: c.highlight.withValues(alpha: 0.22),
          child: Text(
            'Tip: try to put ${formatEuro(suggestedEmergencySavingCents)} a month into your Emergency buffer. '
            'Tap + and choose Saved when you do.',
            style: AppText.small.copyWith(color: c.ink),
          ),
        ),
      ],
    );
  }
}

class _StartDay extends StatelessWidget {
  const _StartDay();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final c = AppColors.of(context);
    final day = store.data.settings.budgetMonthStartDay;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      children: [
        Text('When does your money month start?', style: AppText.title.copyWith(color: c.ink)),
        const SizedBox(height: 8),
        Text(
          'Most people use the 1st. If your salary arrives on the 25th, start your month on the 25th.',
          style: AppText.bodyRegular.copyWith(color: c.inkSoft),
        ),
        const SizedBox(height: 20),
        ListRow(
          padding: EdgeInsets.zero,
          emoji: '📅',
          title: 'The ${ordinal(day)} of each month',
          trailing: Text('Change', style: AppText.body.copyWith(color: c.ink, decoration: TextDecoration.underline, decorationColor: c.highlight, decorationThickness: 2)),
          onTap: () async {
            final picked = await pickStartDay(context, day);
            if (picked != null) await store.setBudgetMonthStartDay(picked);
          },
          semanticLabel: 'Budget month starts on the ${ordinal(day)}. Tap to change.',
        ),
      ],
    );
  }
}
