import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

enum AppThemeMode { light, dark, amoled, system }

class AppTheme {
  AppTheme._();

  static ThemeData light(Color accent) {
    final base = ThemeData.light(useMaterial3: true);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      surface: AppColors.surfaceLight,
      primary: accent,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.surfaceLight,
      canvasColor: AppColors.surfaceLight,
      cardColor: AppColors.surfaceLight2,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimaryLight,
        displayColor: AppColors.textPrimaryLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      dividerColor: AppColors.dividerLight,
      dividerTheme: const DividerThemeData(color: AppColors.dividerLight),
      iconTheme: const IconThemeData(color: AppColors.textPrimaryLight),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: AppColors.textPrimaryLight,
        unselectedItemColor: AppColors.textTertiaryLight,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: AppColors.surfaceLight,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: AppColors.surfaceLight,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.textPrimaryLight,
        iconColor: AppColors.textSecondaryLight,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        thumbColor: accent,
        inactiveTrackColor: AppColors.dividerLight,
        overlayColor: accent.withValues(alpha: 0.1),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return AppColors.textTertiaryLight;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.5);
          }
          return AppColors.dividerLight;
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: accent,
        unselectedLabelColor: AppColors.textSecondaryLight,
        indicatorColor: accent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceLight2,
        selectedColor: accent,
        labelStyle: const TextStyle(color: AppColors.textPrimaryLight),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        side: BorderSide.none,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  static ThemeData dark(Color accent) {
    final base = ThemeData.dark(useMaterial3: true);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: AppColors.nearBlack,
      primary: accent,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.nearBlack,
      canvasColor: AppColors.nearBlack,
      cardColor: AppColors.surfaceDark,
      colorScheme: colorScheme,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimaryDark,
        displayColor: AppColors.textPrimaryDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.nearBlack,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      dividerColor: AppColors.dividerDark,
      dividerTheme: const DividerThemeData(color: AppColors.dividerDark),
      iconTheme: const IconThemeData(color: AppColors.textPrimaryDark),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.nearBlack,
        selectedItemColor: AppColors.textPrimaryDark,
        unselectedItemColor: AppColors.textTertiaryDark,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDark,
        surfaceTintColor: AppColors.surfaceDark,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        surfaceTintColor: AppColors.surfaceDark,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.textPrimaryDark,
        iconColor: AppColors.textSecondaryDark,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        thumbColor: accent,
        inactiveTrackColor: AppColors.dividerDark,
        overlayColor: accent.withValues(alpha: 0.1),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return AppColors.textTertiaryDark;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.5);
          }
          return AppColors.dividerDark;
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: accent,
        unselectedLabelColor: AppColors.textSecondaryDark,
        indicatorColor: accent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedColor: accent,
        labelStyle: const TextStyle(color: AppColors.textPrimaryDark),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        side: BorderSide.none,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  static ThemeData amoled(Color accent) {
    final dark = AppTheme.dark(accent);
    return dark.copyWith(
      scaffoldBackgroundColor: AppColors.amoledBlack,
      canvasColor: AppColors.amoledBlack,
      cardColor: AppColors.amoledBlack,
      dialogTheme: const DialogThemeData(
          backgroundColor: AppColors.amoledBlack,
          surfaceTintColor: AppColors.amoledBlack),
      bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.amoledBlack,
          surfaceTintColor: AppColors.amoledBlack),
      colorScheme: dark.colorScheme.copyWith(
        surface: AppColors.amoledBlack,
        surfaceContainer: AppColors.amoledBlack,
        surfaceContainerLow: AppColors.amoledBlack,
        surfaceContainerHigh: AppColors.surfaceDark,
      ),
      appBarTheme:
          dark.appBarTheme.copyWith(backgroundColor: AppColors.amoledBlack),
      bottomNavigationBarTheme: dark.bottomNavigationBarTheme.copyWith(
        backgroundColor: AppColors.amoledBlack,
      ),
    );
  }
}
