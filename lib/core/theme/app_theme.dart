import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_sizes.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles the Material [ThemeData] from Billfern design tokens.
///
/// Custom components style themselves from tokens directly; this theme exists
/// so that framework widgets (dialogs, snackbars, text fields, selection…)
/// never fall back to the default Material look.
abstract final class AppTheme {
  static const ColorScheme _colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.midnight,
    onPrimary: AppColors.textOnDark,
    primaryContainer: AppColors.lavender,
    onPrimaryContainer: AppColors.textPrimary,
    secondary: AppColors.yellow,
    onSecondary: AppColors.textOnAccent,
    secondaryContainer: AppColors.yellowSoft,
    onSecondaryContainer: AppColors.textPrimary,
    tertiary: AppColors.mint,
    onTertiary: AppColors.textOnAccent,
    tertiaryContainer: AppColors.mintSoft,
    onTertiaryContainer: AppColors.successStrong,
    error: AppColors.dangerStrong,
    onError: AppColors.textOnDark,
    errorContainer: AppColors.dangerSoft,
    onErrorContainer: AppColors.dangerStrong,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textMuted,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.cream,
    surfaceContainerHigh: AppColors.lavender,
    surfaceContainerHighest: AppColors.lavender,
    outline: AppColors.borderStrong,
    outlineVariant: AppColors.border,
    shadow: AppColors.midnight,
    scrim: AppColors.midnight,
    inverseSurface: AppColors.midnight,
    onInverseSurface: AppColors.textOnDark,
    inversePrimary: AppColors.yellow,
    surfaceTint: AppColors.transparent,
  );

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: _colorScheme,
    textTheme: AppTypography.textTheme,
    scaffoldBackgroundColor: AppColors.cream,
    canvasColor: AppColors.cream,
    splashFactory: InkRipple.splashFactory,
    splashColor: AppColors.border,
    highlightColor: AppColors.transparent,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: const CupertinoPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.transparent,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: AppTypography.titleLarge,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    iconTheme: const IconThemeData(
      color: AppColors.textPrimary,
      size: AppSizes.iconLg,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: AppSizes.hairline,
      space: AppSizes.hairline,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.midnight,
      contentTextStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.textOnDark,
      ),
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: AppColors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.borderStrong,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: AppColors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      titleTextStyle: AppTypography.titleLarge,
      contentTextStyle: AppTypography.bodyMedium,
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      hintStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.textSecondary,
      ),
      border: const OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: AppColors.midnight),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: AppColors.dangerStrong),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: AppColors.dangerStrong, width: 1.5),
      ),
      errorStyle: AppTypography.caption.copyWith(color: AppColors.dangerStrong),
      errorMaxLines: 2,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: AppColors.transparent,
      headerBackgroundColor: AppColors.midnight,
      headerForegroundColor: AppColors.textOnDark,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      dayStyle: AppTypography.bodyMedium,
      yearStyle: AppTypography.bodyMedium,
      weekdayStyle: AppTypography.labelMedium.copyWith(
        color: AppColors.textMuted,
      ),
      headerHeadlineStyle: AppTypography.headlineMedium.copyWith(
        color: AppColors.textOnDark,
      ),
      headerHelpStyle: AppTypography.labelMedium.copyWith(
        color: AppColors.textOnDarkMuted,
      ),
      dayForegroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.textOnDark
            : (states.contains(WidgetState.disabled)
                  ? AppColors.textSecondary
                  : AppColors.textPrimary),
      ),
      dayBackgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.midnight
            : AppColors.transparent,
      ),
      todayForegroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.textOnDark
            : AppColors.textPrimary,
      ),
      todayBackgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.midnight
            : AppColors.yellowSoft,
      ),
      todayBorder: const BorderSide(color: AppColors.yellow),
      cancelButtonStyle: TextButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        textStyle: AppTypography.labelLarge,
      ),
      confirmButtonStyle: TextButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        textStyle: AppTypography.labelLarge,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.midnight,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.midnight,
      selectionColor: AppColors.yellow,
      selectionHandleColor: AppColors.midnight,
    ),
    cupertinoOverrideTheme: const CupertinoThemeData(
      primaryColor: AppColors.midnight,
    ),
  );
}
