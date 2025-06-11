import 'package:flutter/material.dart';

class AppColors {
  // iOS-inspired dark theme colors
  static const Color backgroundColor = Color(0xFF000000);  // Pure black
  static const Color surfaceColor = Color(0xFF1C1C1E);    // Dark gray surface
  static const Color secondaryColor = Color(0xFF2C2C2E);  // Secondary dark
  static const Color textPrimary = Color(0xFFFFFFFF);     // White text
  static const Color textSecondary = Color(0xFF8E8E93);   // Gray text
  static const Color borderColor = Color(0xFF38383A);     // Border gray
  
  // iOS system colors
  static const Color systemRed = Color(0xFFFF3B30);
  static const Color systemGreen = Color(0xFF34C759);
  static const Color systemBlue = Color(0xFF007AFF);
  static const Color systemOrange = Color(0xFFFF9500);
  
  // Legacy colors for backward compatibility
  static const Color primaryColor = surfaceColor;
  static const Color accentColor = systemBlue;
  static const Color errorColor = systemRed;
}

class AppTheme {
  static ThemeData getTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundColor,
      fontFamily: '-apple-system',      colorScheme: const ColorScheme.dark(
        primary: AppColors.systemBlue,
        secondary: AppColors.systemBlue,
        surface: AppColors.surfaceColor,
        error: AppColors.systemRed,
        onPrimary: AppColors.textPrimary,
        onSecondary: AppColors.textPrimary,
        onSurface: AppColors.textPrimary,
        onError: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.backgroundColor,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.systemBlue,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
