import 'dart:ui' show FontFeature;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';

const String fontFamily = 'Nunito';

/// Tabular figures so amounts line up in columns.
const List<FontFeature> tabular = [FontFeature.tabularFigures()];

/// Text styles used across the app. Sizes are in logical points and scale
/// with the phone's text size setting.
class AppText {
  const AppText._();

  static const TextStyle hero = TextStyle(
    fontFamily: fontFamily,
    fontSize: 64,
    height: 1.05,
    fontWeight: FontWeight.w800,
    fontFeatures: tabular,
  );
  static const TextStyle title = TextStyle(fontFamily: fontFamily, fontSize: 28, height: 1.2, fontWeight: FontWeight.w800);
  static const TextStyle heading = TextStyle(fontFamily: fontFamily, fontSize: 20, height: 1.25, fontWeight: FontWeight.w800);
  static const TextStyle body = TextStyle(fontFamily: fontFamily, fontSize: 17, height: 1.3, fontWeight: FontWeight.w600);
  static const TextStyle bodyRegular = TextStyle(fontFamily: fontFamily, fontSize: 17, height: 1.35, fontWeight: FontWeight.w400);
  static const TextStyle small = TextStyle(fontFamily: fontFamily, fontSize: 14, height: 1.3, fontWeight: FontWeight.w600);
  static const TextStyle amount = TextStyle(fontFamily: fontFamily, fontSize: 17, height: 1.3, fontWeight: FontWeight.w700, fontFeatures: tabular);
  static const TextStyle amountLarge = TextStyle(fontFamily: fontFamily, fontSize: 22, height: 1.2, fontWeight: FontWeight.w800, fontFeatures: tabular);
}

/// Builds the Material theme (used for its extensions and a few Material
/// widgets) and the Cupertino theme that most screens use.
ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    fontFamily: fontFamily,
    platform: TargetPlatform.iOS,
    scaffoldBackgroundColor: c.paper,
    canvasColor: c.paper,
    dividerColor: c.line,
    splashFactory: NoSplash.splashFactory,
    highlightColor: c.line.withValues(alpha: 0.5),
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.ink,
      onPrimary: c.onInk,
      secondary: c.highlight,
      onSecondary: const Color(0xFF1B2766),
      error: c.overText,
      onError: c.card,
      surface: c.card,
      onSurface: c.ink,
    ),
    extensions: [c],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: c.ink, displayColor: c.ink, fontFamily: fontFamily),
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    textSelectionTheme: TextSelectionThemeData(cursorColor: c.ink, selectionColor: c.highlight.withValues(alpha: 0.6)),
    cupertinoOverrideTheme: buildCupertinoTheme(brightness),
  );
}

CupertinoThemeData buildCupertinoTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  return CupertinoThemeData(
    brightness: brightness,
    primaryColor: c.ink,
    primaryContrastingColor: c.onInk,
    scaffoldBackgroundColor: c.paper,
    barBackgroundColor: c.paper.withValues(alpha: 0.94),
    textTheme: CupertinoTextThemeData(
      primaryColor: c.ink,
      textStyle: AppText.body.copyWith(color: c.ink),
      actionTextStyle: AppText.body.copyWith(color: c.ink),
      navTitleTextStyle: AppText.body.copyWith(color: c.ink, fontWeight: FontWeight.w800),
      navLargeTitleTextStyle: AppText.title.copyWith(color: c.ink, fontSize: 34),
      tabLabelTextStyle: AppText.small.copyWith(fontSize: 11, color: c.inkSoft),
      pickerTextStyle: AppText.body.copyWith(color: c.ink, fontSize: 21),
      dateTimePickerTextStyle: AppText.body.copyWith(color: c.ink, fontSize: 21),
    ),
  );
}
