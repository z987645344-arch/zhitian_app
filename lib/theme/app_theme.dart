import 'package:flutter/material.dart';

abstract final class AppColors {
  static const onPrimary = Color(0xFF20292E);
  static const shadow = Color(0x33000000);
  static const background = Color(0xFF20292E);
  static const surface = Color(0xFF29343A);
  static const surfaceLow = Color(0xFF172025);
  static const surfaceContainer = Color(0xFF3A4541);
  static const surfaceHigh = Color(0xFF344047);
  static const text = Color(0xFFEFF2F3);
  static const textMuted = Color(0xFFB7C0C3);
  static const primary = Color(0xFFB3B7A4);
  static const primarySoft = Color(0xFFC6CAB9);
  static const primaryContainer = Color(0xFF3A4541);
  static const border = Color(0xFF4B565C);
  static const success = Color(0xFF9BBCAF);
  static const successContainer = Color(0xFF263831);
  static const warning = Color(0xFFD8B071);
  static const warningContainer = Color(0xFF3A3024);
  static const error = Color(0xFFDC9188);
  static const errorContainer = Color(0xFF3B2929);
}

abstract final class AppTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.text,
      onSecondary: AppColors.background,
      surface: AppColors.surface,
      error: AppColors.error,
      onError: AppColors.background,
    );
    final baseText = ThemeData.dark().textTheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Segoe UI',
      fontFamilyFallback: const ['Microsoft YaHei', 'sans-serif'],
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: baseText.apply(
        fontFamily: 'Segoe UI',
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primaryContainer,
        selectionHandleColor: AppColors.primary,
      ),
      dividerColor: AppColors.border,
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size(0, 44),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text,
          minimumSize: const Size(0, 44),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.textMuted),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.text
                : AppColors.textMuted,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.primaryContainer
                : AppColors.surface,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.border),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
          ),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: AppColors.surfaceLow,
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.control)),
        ),
        labelStyle: TextStyle(color: AppColors.text, fontSize: 12),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.primary,
        contentTextStyle: TextStyle(color: AppColors.onPrimary),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

abstract final class AppRadii {
  static const control = 10.0;
  static const card = 16.0;
  static const large = 24.0;
}

abstract final class AppSpace {
  static const small = 8.0;
  static const field = 16.0;
  static const page = 24.0;
  static const section = 32.0;
}
