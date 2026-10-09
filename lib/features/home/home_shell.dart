import 'package:flutter/cupertino.dart';

import '../../design/app_colors.dart';
import '../../design/theme.dart';
import '../add/add_sheet.dart';
import '../budget/budget_page.dart';
import '../goals/goals_page.dart';
import '../history/history_page.dart';
import '../overview/overview_page.dart';
import 'home_tabs.dart';

/// Height of the tab bar above the home indicator.
const double tabBarHeight = 60;

/// The four tabs with the yellow + button in the middle.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _navigators = List.generate(4, (_) => GlobalKey<NavigatorState>());

  static const _tabs = [
    (CupertinoIcons.house, CupertinoIcons.house_fill, 'Overview'),
    (CupertinoIcons.list_bullet, CupertinoIcons.list_bullet, 'History'),
    (CupertinoIcons.slider_horizontal_3, CupertinoIcons.slider_horizontal_3, 'Budget'),
    (CupertinoIcons.flag, CupertinoIcons.flag_fill, 'Goals'),
  ];

  void _select(int index) {
    if (index == _index) {
      _navigators[index].currentState?.popUntil((r) => r.isFirst);
    } else {
      setState(() => _index = index);
    }
  }

  Widget _page(int index) => switch (index) {
        0 => const OverviewPage(),
        1 => const HistoryPage(),
        2 => const BudgetPage(),
        _ => const GoalsPage(),
      };

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final media = MediaQuery.of(context);
    final bottomSafe = media.padding.bottom;
    return HomeTabs(
      select: _select,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _navigators[_index].currentState?.maybePop();
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: MediaQuery(
                // Pages leave room for the tab bar at the bottom.
                data: media.copyWith(padding: media.padding.copyWith(bottom: bottomSafe + tabBarHeight)),
                child: IndexedStack(
                  index: _index,
                  children: [
                    for (var i = 0; i < 4; i++)
                      CupertinoTabView(navigatorKey: _navigators[i], builder: (_) => _page(i)),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.only(bottom: bottomSafe),
                decoration: BoxDecoration(
                  color: c.paper.withValues(alpha: 0.97),
                  border: Border(top: BorderSide(color: c.line)),
                ),
                child: SizedBox(
                  height: tabBarHeight,
                  child: Row(
                    children: [
                      for (var i = 0; i < 2; i++) Expanded(child: _tab(context, i)),
                      const SizedBox(width: 84),
                      for (var i = 2; i < 4; i++) Expanded(child: _tab(context, i)),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: bottomSafe + tabBarHeight - 44,
              left: 0,
              right: 0,
              child: Center(child: _AddButton(onPressed: () => showAddSheet(context))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, int i) {
    final c = AppColors.of(context);
    final selected = i == _index;
    final (icon, activeIcon, label) = _tabs[i];
    final color = selected ? c.ink : c.inkSoft;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, tab ${i + 1} of 4',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _select(i),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? activeIcon : icon, color: color, size: 24),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: AppText.small.copyWith(fontSize: 11, color: color, fontWeight: selected ? FontWeight.w800 : FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 62 pt yellow + button, raised slightly above the tab bar.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      label: 'Add an entry',
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('addButton'),
        onTap: onPressed,
        child: Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: c.highlight,
            shape: BoxShape.circle,
            border: Border.all(color: c.paper, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Icon(CupertinoIcons.add, size: 32, color: AppColors.light.ink),
        ),
      ),
    );
  }
}
