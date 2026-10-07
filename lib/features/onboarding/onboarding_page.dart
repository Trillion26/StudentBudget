import 'package:flutter/cupertino.dart';

import '../../app_scope.dart';
import '../../data/seed.dart';
import '../../design/app_colors.dart';
import '../../design/highlighter.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';
import '../../logic/money.dart';
import '../settings/settings_page.dart';
import 'income_setup_page.dart';

/// Three short, skippable screens on first launch.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == 2) {
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
                  child: Text('${_index + 1} of 3', style: AppText.small.copyWith(color: c.inkSoft)),
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
                children: const [_Welcome(), _Income(), _StartDay()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PrimaryButton(
                key: const Key('onboardingNext'),
                label: _index == 2 ? 'Start budgeting' : 'Next',
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
          child: Highlighter(child: Text('Student Budget', style: AppText.title.copyWith(color: c.ink, fontSize: 36))),
        ),
        const SizedBox(height: 20),
        Text(
          'Plan your month in rand and see how much you can spend each day.',
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
            'Tip: try to put ${formatRand(suggestedEmergencySavingCents)} a month into your Emergency fund. '
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
          'Most people use the 1st. If your allowance or pay arrives on the 25th, start your month on the 25th.',
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
