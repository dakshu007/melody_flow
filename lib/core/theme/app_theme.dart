import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

enum AppThemeMode { light, dark, amoled, system }

class AppTheme {
  AppTheme._();

  static ThemeData light(Color accent) {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.surfaceLight,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
        surface: AppColors.surfaceLight,
        primary: accent,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimaryLight,
        displayColor: AppColors.textPrimaryLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surfaceLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),
      dividerColor: AppColors.dividerLight,
      iconTheme: const IconThemeData(color: AppColors.textPrimaryLight),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: AppColors.textPrimaryLight,
        unselectedItemColor: AppColors.textTertiaryLight,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  static ThemeData dark(Color accent) {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.nearBlack,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        surface: AppColors.nearBlack,
        primary: accent,
      ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimaryDark,
        displayColor: AppColors.textPrimaryDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.nearBlack,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      dividerColor: AppColors.dividerDark,
      iconTheme: const IconThemeData(color: AppColors.textPrimaryDark),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.nearBlack,
        selectedItemColor: AppColors.textPrimaryDark,
        unselectedItemColor: AppColors.textTertiaryDark,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
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
      dialogTheme: const DialogTheme(backgroundColor: AppColors.amoledBlack),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: AppColors.amoledBlack),
      colorScheme: dark.colorScheme.copyWith(
        surface: AppColors.amoledBlack,
        surfaceContainer: AppColors.amoledBlack,
        surfaceContainerLow: AppColors.amoledBlack,
        surfaceContainerHigh: AppColors.surfaceDark,
      ),
      appBarTheme: dark.appBarTheme.copyWith(backgroundColor: AppColors.amoledBlack),
      bottomNavigationBarTheme: dark.bottomNavigationBarTheme.copyWith(
        backgroundColor: AppColors.amoledBlack,
      ),
    );
  }
}
