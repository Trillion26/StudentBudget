import 'package:flutter/widgets.dart';

/// Lets screens switch tabs (e.g. "See everything this month" → History).
class HomeTabs extends InheritedWidget {
  const HomeTabs({super.key, required this.select, required super.child});

  final void Function(int index) select;

  static const overview = 0;
  static const history = 1;
  static const budget = 2;
  static const goals = 3;

  static HomeTabs? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<HomeTabs>();

  @override
  bool updateShouldNotify(HomeTabs oldWidget) => false;
}
