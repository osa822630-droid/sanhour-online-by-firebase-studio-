// lib/utils/app_theme.dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary
  static const primary        = Color(0xFF5E35B1);
  static const primaryLight   = Color(0xFF7C4DFF);
  static const primaryDark    = Color(0xFF320B86);

  // Accent
  static const accent         = Color(0xFF3949AB);
  static const gold           = Color(0xFFFFC107);

  // Semantic
  static const success        = Color(0xFF4CAF50);
  static const error          = Color(0xFFF44336);
  static const warning        = Color(0xFFFF9800);
  static const info           = Color(0xFF2196F3);

  // Neutral & Dark Surfaces
  static const surface        = Color(0xFFF8F7FF);
  static const surfaceDark    = Color(0xFF18162B);
  static const cardDark       = Color(0xFF23203A);
  static const inputDark      = Color(0xFF2D2948);
  static const textMuted      = Color(0xFF9E9E9E);

  // Category colors
  static const shopColor      = Color(0xFF5E35B1);
  static const serviceColor   = Color(0xFF00897B);
  static const offerColor     = Color(0xFFE53935);
  static const jobColor       = Color(0xFF1E88E5);
  static const dealerColor    = Color(0xFF6D4C41);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: AppColors.primary,
      brightness: Brightness.light,
      fontFamily: 'Tajawal',
      scaffoldBackgroundColor: AppColors.surface,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'Tajawal'),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Tajawal'),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        prefixIconColor: AppColors.primary,
        labelStyle: const TextStyle(color: AppColors.primary),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.primary),
      dividerTheme: DividerThemeData(color: Colors.grey[200], thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: AppColors.primary,
      brightness: Brightness.dark,
      fontFamily: 'Tajawal',
      scaffoldBackgroundColor: AppColors.surfaceDark,
      cardColor: AppColors.cardDark,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        fontFamily: 'Tajawal',
        bodyColor: Colors.grey[200],
        displayColor: Colors.white,
      ),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Tajawal'),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF211E3A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF423C68), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
        ),
        prefixIconColor: AppColors.primaryLight,
        labelStyle: const TextStyle(color: Color(0xFFD6BCFA)),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: AppColors.primaryLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.primaryLight),
      dividerTheme: DividerThemeData(color: Colors.grey[800], thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
