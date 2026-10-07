import 'package:flutter/material.dart';

/// The notebook colour tokens from the brief, in light and dark variants.
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

  static const light = AppColors(
    paper: Color(0xFFF5F6FA),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF1B2766),
    inkSoft: Color(0xFF5A6290),
    line: Color(0xFFDFE2EE),
    highlight: Color(0xFFFFE14D),
    over: Color(0xFFFF8FA3),
    overText: Color(0xFFB3163E),
    income: Color(0xFF5FCB9E),
    savings: Color(0xFF8FB4FF),
    onInk: Color(0xFFFFFFFF),
  );

  static const dark = AppColors(
    paper: Color(0xFF11152B),
    card: Color(0xFF1A2040),
    ink: Color(0xFFEEF0FA),
    inkSoft: Color(0xFFA3A9CC),
    line: Color(0xFF2C3360),
    highlight: Color(0xFFE9C93A),
    over: Color(0xFFE36A84),
    overText: Color(0xFFFFD3DC),
    income: Color(0xFF4FB98C),
    savings: Color(0xFF6F95E8),
    onInk: Color(0xFF11152B),
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
