import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_budget/app.dart';
import 'package:student_budget/data/budget_store.dart';

/// Wraps the app so tools can capture screenshots of it.
const Key screenshotKey = Key('screenshot');

/// Pumps the whole app with [store] on a phone-sized screen.
Future<void> pumpApp(
  WidgetTester tester,
  BudgetStore store, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
  await tester.pumpWidget(RepaintBoundary(key: screenshotKey, child: StudentBudgetApp(store: store)));
  await tester.pumpAndSettle();
}

/// Lets the 4-second toast timer finish so no timers are left pending.
Future<void> waitForToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}
