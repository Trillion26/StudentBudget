import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'data/budget_store.dart';
import 'design/app_colors.dart';
import 'design/theme.dart';
import 'design/toast.dart';
import 'features/home/home_shell.dart';
import 'features/lock/app_lock.dart';
import 'features/onboarding/onboarding_page.dart';

class StudentBudgetApp extends StatefulWidget {
  const StudentBudgetApp({super.key, required this.store});

  final BudgetStore store;

  @override
  State<StudentBudgetApp> createState() => _StudentBudgetAppState();
}

class _StudentBudgetAppState extends State<StudentBudgetApp> {
  final SelectedMonth _selectedMonth = SelectedMonth();
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (!widget.store.isReady) {
      widget.store.init().catchError((Object e) {
        if (mounted) setState(() => _error = e);
      });
    }
  }

  @override
  void dispose() {
    _selectedMonth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: widget.store,
      child: SelectedMonthScope(
        selected: _selectedMonth,
        child: MaterialApp(
          title: 'Student Budget',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: ThemeMode.system,
          builder: (context, child) => DefaultTextStyle(
            // A base text style for screens outside a page scaffold (sheets, toasts).
            style: AppText.body.copyWith(color: AppColors.of(context).ink, decoration: TextDecoration.none),
            child: ToastHost(child: AppLock(child: child!)),
          ),
          home: _Root(error: _error),
        ),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final c = AppColors.of(context);
    if (error != null) {
      return CupertinoPageScaffold(
        backgroundColor: c.paper,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              "Your budget couldn't be opened. Close the app completely and open it again.",
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: c.ink),
            ),
          ),
        ),
      );
    }
    if (!store.isReady) return ColoredBox(color: c.paper);
    if (!store.data.settings.hasCompletedOnboarding) return const OnboardingPage();
    return const HomeShell();
  }
}
