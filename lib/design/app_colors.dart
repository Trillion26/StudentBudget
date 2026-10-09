import 'package:flutter/material.dart';

/// The app's colour tokens, in light and dark variants.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.paper,
    required this.card,
    required this.ink,
    required this.inkSoft,
    required this.line,
    required this.highlight,
    required this.over,
    required this.overText,
    required this.income,
    required this.savings,
    required this.onInk,
  });

  /// Screen background.
  final Color paper;

  /// Sheets, fields, chips.
  final Color card;

  /// Text, primary buttons, normal progress bars.
  final Color ink;

  /// Secondary text.
  final Color inkSoft;

  /// Dividers, borders.
  final Color line;

  /// Highlighter mark, + button.
  final Color highlight;

  /// Over-budget bars and warnings.
  final Color over;

  /// Over-budget text.
  final Color overText;

  /// Income amounts.
  final Color income;

  /// Savings progress.
  final Color savings;

  /// Text on top of an [ink] filled button.
  final Color onInk;

  /// Taken from the app icon: the forest-green lettering for ink, the cream
  /// background for paper, the euro coin's gold for the highlighter, and the
  /// piggy bank's green and peach spots for income and savings.
  static const light = AppColors(
    paper: Color(0xFFF5F3EC),
    card: Color(0xFFFFFDF8),
    ink: Color(0xFF2F553B),
    inkSoft: Color(0xFF626F5F),
    line: Color(0xFFE6E0D2),
    highlight: Color(0xFFF2C063),
    over: Color(0xFFF08A7E),
    overText: Color(0xFFB03A2E),
    income: Color(0xFF4F9856),
    savings: Color(0xFFF2A277),
    onInk: Color(0xFFFFFFFF),
  );

  static const dark = AppColors(
    paper: Color(0xFF1B201A),
    card: Color(0xFF252C24),
    ink: Color(0xFFF3EFE3),
    inkSoft: Color(0xFFB4BCAA),
    line: Color(0xFF3A4537),
    highlight: Color(0xFFE8B44E),
    over: Color(0xFFE0776B),
    overText: Color(0xFFFFD3CC),
    income: Color(0xFF7FC27F),
    savings: Color(0xFFF0A070),
    onInk: Color(0xFF1B201A),
  );

  /// Colours for the current theme.
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ?? (Theme.of(context).brightness == Brightness.dark ? dark : light);

  /// Income text needs more contrast than the bar colour on light paper.
  Color get incomeText => Color.lerp(income, ink, ink.computeLuminance() < 0.5 ? 0.45 : 0.0)!;

  @override
  AppColors copyWith({
    Color? paper,
    Color? card,
    Color? ink,
    Color? inkSoft,
    Color? line,
    Color? highlight,
    Color? over,
    Color? overText,
    Color? income,
    Color? savings,
    Color? onInk,
  }) {
    return AppColors(
      paper: paper ?? this.paper,
      card: card ?? this.card,
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      line: line ?? this.line,
      highlight: highlight ?? this.highlight,
      over: over ?? this.over,
      overText: overText ?? this.overText,
      income: income ?? this.income,
      savings: savings ?? this.savings,
      onInk: onInk ?? this.onInk,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      paper: Color.lerp(paper, other.paper, t)!,
      card: Color.lerp(card, other.card, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      line: Color.lerp(line, other.line, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      over: Color.lerp(over, other.over, t)!,
      overText: Color.lerp(overText, other.overText, t)!,
      income: Color.lerp(income, other.income, t)!,
      savings: Color.lerp(savings, other.savings, t)!,
      onInk: Color.lerp(onInk, other.onInk, t)!,
    );
  }
}
