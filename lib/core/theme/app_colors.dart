import 'package:flutter/material.dart';

/// MelodyFlow color palette.
///
/// Philosophy: minimal + clean. True black AMOLED, soft surface grays,
/// a single accent the user can customize. No gradients, no clutter.
class AppColors {
  AppColors._();

  // ---- Core neutrals ----
  static const Color amoledBlack   = Color(0xFF000000);
  static const Color nearBlack     = Color(0xFF0A0A0A);
  static const Color surfaceDark   = Color(0xFF141414);
  static const Color surfaceDark2  = Color(0xFF1E1E1E);
  static const Color dividerDark   = Color(0xFF2A2A2A);

  static const Color pureWhite     = Color(0xFFFFFFFF);
  static const Color offWhite      = Color(0xFFF7F7F7);
  static const Color surfaceLight  = Color(0xFFFFFFFF);
  static const Color surfaceLight2 = Color(0xFFF2F2F2);
  static const Color dividerLight  = Color(0xFFE5E5E5);

  // ---- Text ----
  static const Color textPrimaryDark   = Color(0xFFEDEDED);
  static const Color textSecondaryDark = Color(0xFF9A9A9A);
  static const Color textTertiaryDark  = Color(0xFF6A6A6A);

  static const Color textPrimaryLight   = Color(0xFF111111);
  static const Color textSecondaryLight = Color(0xFF555555);
  static const Color textTertiaryLight  = Color(0xFF8A8A8A);

  // ---- Accent presets (user-selectable) ----
  static const List<Color> accentPresets = [
    Color(0xFF1DB954), // Spotify green
    Color(0xFFFF375F), // Apple red
    Color(0xFF0A84FF), // iOS blue
    Color(0xFFBF5AF2), // purple
    Color(0xFFFF9F0A), // orange
    Color(0xFF64D2FF), // cyan
    Color(0xFFFFD60A), // yellow
    Color(0xFFFF6B6B), // coral
  ];

  static const Color defaultAccent = Color(0xFF1DB954);
}
