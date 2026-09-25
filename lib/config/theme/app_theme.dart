/// App theme configuration
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Color Tokens
  static const _seedColor = Color(0xFF6200EA);
  static const _successColor = Color(0xFF4CAF50);
  static const _warningColor = Color(0xFFFFC107);
  static const _criticalColor = Color(0xFFFF9800);
  static const _errorColor = Color(0xFFF44336);

  // Light Theme
  static ThemeData get lightTheme {
    final base = ThemeData.light();
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.light,
      ).copyWith(surface: Colors.white),
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      scaffoldBackgroundColor: const Color(0xFFF7F8FC),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF23232B),
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shadowColor: Color(0x26000000),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      ).copyWith(surface: const Color(0xFF1A1B20)),
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      scaffoldBackgroundColor: const Color(0xFF101114),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1A1B20),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shadowColor: Color(0x66000000),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1B20),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF424242),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // Budget Status Colors
  static Color getBudgetStatusColor(double percentage) {
    if (percentage < 75) return _successColor;
    if (percentage < 90) return _warningColor;
    if (percentage < 100) return _criticalColor;
    return _errorColor;
  }

  static String getBudgetStatusLabel(double percentage) {
    if (percentage < 75) return 'On Track';
    if (percentage < 90) return 'Warning';
    if (percentage < 100) return 'Critical';
    return 'Exceeded';
  }
}
