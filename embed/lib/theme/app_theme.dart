import 'package:flutter/material.dart';

import '../sensor_status.dart';

/// Palet warna aplikasi FishFeed. Mengusung nuansa air untuk menyesuaikan
/// dengan konteks akuarium.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color accent = Color(0xFF00ACC1);

  static const Color good = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
  static const Color bad = Color(0xFFC62828);
  static const Color neutral = Color(0xFF607D8B);

  static const Color background = Color(0xFFF4F6FA);
  static const Color surface = Colors.white;
}

/// Tema Material 3 untuk seluruh aplikasi.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: AppColors.surface,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// Memetakan tingkat keparahan sensor ke warna indikator.
  static Color colorForSeverity(Severity severity) {
    switch (severity) {
      case Severity.good:
        return AppColors.good;
      case Severity.warning:
        return AppColors.warning;
      case Severity.bad:
        return AppColors.bad;
      case Severity.unknown:
        return AppColors.neutral;
    }
  }
}
