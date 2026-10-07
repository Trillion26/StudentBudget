import 'package:flutter/widgets.dart';

import 'data/budget_store.dart';
import 'logic/budget_month.dart';

/// Gives every screen access to the [BudgetStore] and rebuilds dependents
/// when the data changes.
class StoreScope extends InheritedNotifier<BudgetStore> {
  const StoreScope({super.key, required BudgetStore store, required super.child}) : super(notifier: store);

  static BudgetStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// Access without listening for changes (for callbacks).
  static BudgetStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

/// The month shown on Overview and History, shared between them. Stored as
/// the label month so it survives changes to the budget month start day.
class SelectedMonth extends ValueNotifier<(int, int)?> {
  SelectedMonth() : super(null);

  /// The selected month, or the current budget month when none is chosen.
  BudgetMonth resolve(BudgetMonth current) {
    final v = value;
    if (v == null) return current;
    final m = BudgetMonth(v.$1, v.$2, current.startDay);
    // Never more than one month ahead.
    return m.isAfter(current.next) ? current.next : m;
  }

  void select(BudgetMonth month, BudgetMonth current) =>
      value = month == current ? null : (month.year, month.month);
}

class SelectedMonthScope extends InheritedNotifier<SelectedMonth> {
  const SelectedMonthScope({super.key, required SelectedMonth selected, required super.child}) : super(notifier: selected);

  static SelectedMonth of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SelectedMonthScope>()!.notifier!;
}
