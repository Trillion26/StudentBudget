import 'package:flutter/services.dart';

/// The three haptics the app uses.
class Haptics {
  const Haptics._();

  /// After saving an entry.
  static Future<void> saved() => HapticFeedback.lightImpact();

  /// When a goal is reached.
  static Future<void> success() => HapticFeedback.successNotification();

  /// When an entry pushes a category over budget.
  static Future<void> warning() => HapticFeedback.warningNotification();
}
