import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract class AppColors {
  static const navy = Color(0xFF0F2D5B);
  static const orange = Color(0xFFFF8A00);
  static const blue = Color(0xFF3B82F6);
  static const background = Color(0xFFF8FAFC);
  static const surfaceGray = Color(0xFFE5E7EB);

  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);

  static const navInactive = Color(0xFF6B7280);
}

abstract class AppSpacing {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;
}

abstract class AppRadius {
  static const double r4 = 4;
  static const double r8 = 8;
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r24 = 24;
}

abstract class AppShadows {
  static final soft = [
    BoxShadow(
      color: AppColors.navy.withValues(alpha: 0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  static final medium = [
    BoxShadow(
      color: AppColors.navy.withValues(alpha: 0.10),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}

class AppTheme {
  static const _font = 'Poppins';

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.blue).copyWith(
      primary: AppColors.blue,
      onPrimary: Colors.white,
      secondary: AppColors.orange,
      onSecondary: Colors.white,
      tertiary: AppColors.navy,
      error: AppColors.error,
      surface: Colors.white,
      onSurface: AppColors.navy,
      onSurfaceVariant: AppColors.navInactive,
      outline: AppColors.surfaceGray,
      outlineVariant: AppColors.surfaceGray,
    );

    final base = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      fontFamily: _font,
    );
    final t = base.textTheme.apply(
      bodyColor: AppColors.navy,
      displayColor: AppColors.navy,
      fontFamily: _font,
    );
    final text = t.copyWith(
      headlineLarge: t.headlineLarge?.copyWith(
        fontSize: 28,
        height: 36 / 28,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: t.headlineMedium?.copyWith(
        fontSize: 22,
        height: 32 / 22,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: t.headlineSmall?.copyWith(
        fontSize: 18,
        height: 28 / 18,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: t.titleLarge?.copyWith(
        fontSize: 18,
        height: 28 / 18,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: t.titleMedium?.copyWith(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: t.titleSmall?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: t.bodyLarge?.copyWith(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: t.bodyMedium?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: t.bodySmall?.copyWith(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w400,
        color: AppColors.navInactive,
      ),
      labelLarge: t.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: t.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelSmall: t.labelSmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.navInactive,
      ),
    );

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.r12),
      borderSide: BorderSide(color: c, width: w),
    );

    const buttonText = TextStyle(
      fontFamily: _font,
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.r12),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: _font,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineSmall,
        iconTheme: const IconThemeData(color: AppColors.navy),
        actionsIconTheme: const IconThemeData(color: AppColors.navy),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        shape: const Border(bottom: BorderSide(color: AppColors.surfaceGray)),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shadowColor: AppColors.navy.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r16),
          side: BorderSide(color: AppColors.surfaceGray.withValues(alpha: 0.6)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: AppColors.navy.withValues(alpha: 0.15),
        height: 68,
        indicatorColor: AppColors.blue.withValues(alpha: 0.12),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? AppColors.blue
                : AppColors.navInactive,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: _font,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.blue
                : AppColors.navInactive,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 14,
          color: AppColors.navInactive,
        ),
        labelStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 14,
          color: AppColors.navInactive,
        ),
        floatingLabelStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 14,
          color: AppColors.blue,
        ),
        prefixIconColor: AppColors.navInactive,
        suffixIconColor: AppColors.navInactive,
        border: border(AppColors.surfaceGray),
        enabledBorder: border(AppColors.surfaceGray),
        disabledBorder: border(AppColors.surfaceGray),
        focusedBorder: border(AppColors.blue, 2),
        errorBorder: border(AppColors.error),
        focusedErrorBorder: border(AppColors.error, 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          textStyle: buttonText,
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.blue,
          side: const BorderSide(color: AppColors.blue, width: 1.5),
          minimumSize: const Size.fromHeight(48),
          textStyle: buttonText,
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.blue,
          textStyle: buttonText,
          shape: buttonShape,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.blue,
        foregroundColor: Colors.white,
        elevation: 3,
        extendedTextStyle: buttonText,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r16),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r16),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: const TextStyle(
          fontFamily: _font,
          fontSize: 14,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r12),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r4),
        ),
        side: const BorderSide(color: AppColors.navInactive, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith<Color?>(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.blue
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith<Color?>(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.blue
              : AppColors.surfaceGray,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.blue,
        linearTrackColor: AppColors.surfaceGray,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.surfaceGray,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
