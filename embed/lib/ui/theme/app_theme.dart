import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../logic/sensor_status.dart';

/// Palet FishFeed: petrol (warna air akuarium) dan amber (warna pakan),
/// datar tanpa gradasi.
abstract final class AppColors {
  static const ocean = Color(0xFF0E6E7E);
  static const oceanDeep = Color(0xFF0A4F5C);
  static const teal = Color(0xFF2B8A99);
  static const tealSoft = Color(0xFFE2F1F3);
  static const coral = Color(0xFFE8A33D);
  static const coralSoft = Color(0xFFFCF1DE);
  static const amberInk = Color(0xFF8A5A0E);
  static const sky = Color(0xFFE3EFF1);

  static const good = Color(0xFF2F9E6B);
  static const goodSoft = Color(0xFFE3F3EA);
  static const warning = Color(0xFFD99A1E);
  static const warningSoft = Color(0xFFFBF0D9);
  static const bad = Color(0xFFB4533C);
  static const badSoft = Color(0xFFF7E8E3);

  static const ink = Color(0xFF14212B);
  static const muted = Color(0xFF5D6B75);
  static const line = Color(0xFFE3E8EA);
  static const background = Color(0xFFF4F6F7);
  static const surface = Colors.white;

  static Color forSeverity(Severity severity) => switch (severity) {
    Severity.good => good,
    Severity.warning => warning,
    Severity.bad => bad,
    Severity.unknown => muted,
  };

  static Color softForSeverity(Severity severity) => switch (severity) {
    Severity.good => goodSoft,
    Severity.warning => warningSoft,
    Severity.bad => badSoft,
    Severity.unknown => line,
  };
}

abstract final class Gap {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class Radii {
  static const sm = 12.0;
  static const md = 18.0;
  static const lg = 26.0;
}

const _display = 'Poppins';
const _body = 'Inter';

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.ocean,
    primary: AppColors.ocean,
    onPrimary: Colors.white,
    secondary: AppColors.teal,
    tertiary: AppColors.coral,
    error: AppColors.bad,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
  ).copyWith(
    primaryContainer: AppColors.sky,
    outline: AppColors.line,
    outlineVariant: AppColors.line,
  );

  const text = TextTheme(
    headlineMedium: TextStyle(
      fontFamily: _display,
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      height: 1.2,
    ),
    headlineSmall: TextStyle(
      fontFamily: _display,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
      height: 1.25,
    ),
    titleLarge: TextStyle(
      fontFamily: _display,
      fontSize: 19,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    titleMedium: TextStyle(
      fontFamily: _display,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    titleSmall: TextStyle(
      fontFamily: _body,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    bodyLarge: TextStyle(
      fontFamily: _body,
      fontSize: 16,
      color: AppColors.ink,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontFamily: _body,
      fontSize: 14,
      color: AppColors.ink,
      height: 1.45,
    ),
    bodySmall: TextStyle(
      fontFamily: _body,
      fontSize: 12,
      color: AppColors.muted,
      height: 1.4,
    ),
    labelLarge: TextStyle(
      fontFamily: _body,
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
    labelMedium: TextStyle(
      fontFamily: _body,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    ),
    labelSmall: TextStyle(
      fontFamily: _body,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      color: AppColors.muted,
    ),
  );

  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Radii.sm + 2),
  );

  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm + 2),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: _body,
    textTheme: text,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: TextStyle(
        fontFamily: _display,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: rounded,
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: rounded,
        foregroundColor: AppColors.ocean,
        side: const BorderSide(color: AppColors.line, width: 1.5),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.ocean,
        textStyle: text.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(AppColors.line),
      enabledBorder: border(AppColors.line),
      focusedBorder: border(AppColors.ocean, 1.5),
      errorBorder: border(AppColors.bad),
      focusedErrorBorder: border(AppColors.bad, 1.5),
      prefixIconColor: AppColors.muted,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Colors.white : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? AppColors.teal : null,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.sky,
      side: const BorderSide(color: AppColors.line),
      labelStyle: text.labelMedium,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      space: 1,
      thickness: 1,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.muted,
      titleTextStyle: text.titleSmall,
      subtitleTextStyle: text.bodySmall,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.sky,
      height: 70,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelSmall?.copyWith(
          color:
              states.contains(WidgetState.selected)
                  ? AppColors.ocean
                  : AppColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color:
              states.contains(WidgetState.selected)
                  ? AppColors.ocean
                  : AppColors.muted,
        ),
      ),
    ),
  );
}
