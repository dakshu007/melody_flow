import 'package:flutter/services.dart';

/// Centralized haptic feedback. Kept subtle and consistent across the app.
class Haptics {
  Haptics._();

  /// Light tap — for small UI interactions like toggles, favorites
  static Future<void> light() => HapticFeedback.lightImpact();

  /// Medium tap — for primary actions like play/pause
  static Future<void> medium() => HapticFeedback.mediumImpact();

  /// Heavy tap — for destructive or important actions (delete, confirmations)
  static Future<void> heavy() => HapticFeedback.heavyImpact();

  /// Subtle selection click — for skip, navigation
  static Future<void> selection() => HapticFeedback.selectionClick();
}
