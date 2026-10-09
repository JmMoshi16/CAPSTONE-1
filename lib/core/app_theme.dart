import 'package:flutter/material.dart';
import 'tokens.dart';
import 'admin_theme.dart';

/// Material themes built from the design tokens. The customer app follows the system
/// light/dark setting; admin screens wrap themselves in [adminTheme].
class AppTheme {
  static ThemeData get light => _build(AppColors.light);
  static ThemeData get dark => _build(AppColors.dark);

  static ThemeData _build(AppColors c) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppPalette.forest,
      brightness: c.brightness,
    ).copyWith(
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.onPrimaryContainer,
      secondary: c.coffee,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      outline: c.border,
      outlineVariant: c.border,
      error: c.danger,
    );
    final text = AppType.textTheme(c.textPrimary, c.textSecondary);
    final shape = RoundedRectangleBorder(borderRadius: AppRadius.all(AppRadius.lg));
    const minSize = Size(AppSpace.touch, AppSpace.touch);

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      fontFamily: 'Roboto',
      colorScheme: scheme,
      scaffoldBackgroundColor: c.background,
      textTheme: text,
      extensions: [c],
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: c.textSecondary),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary, linearTrackColor: c.surfaceAlt),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
        backgroundColor: c.primary, foregroundColor: c.onPrimary, minimumSize: minSize,
        textStyle: text.labelLarge, shape: shape,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
      )),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: c.primary, foregroundColor: c.onPrimary, minimumSize: minSize, elevation: 0,
        textStyle: text.labelLarge, shape: shape,
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        foregroundColor: c.primary, minimumSize: minSize, textStyle: text.labelLarge, shape: shape,
        side: BorderSide(color: c.primary.withValues(alpha: 0.5), width: 1.5),
      )),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
        foregroundColor: c.primary, minimumSize: minSize, textStyle: text.labelLarge,
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: text.bodyMedium!.copyWith(color: c.textTertiary),
        labelStyle: text.bodyMedium!.copyWith(color: c.textSecondary),
        prefixIconColor: c.primary,
        suffixIconColor: c.textSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.md),
        border: _input(c.border),
        enabledBorder: _input(c.border),
        focusedBorder: _input(c.primary, 2),
        errorBorder: _input(c.danger),
        focusedErrorBorder: _input(c.danger, 2),
        errorStyle: text.bodySmall!.copyWith(color: c.danger),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.all(AppRadius.md)),
        contentTextStyle: text.bodyMedium!.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.all(AppRadius.xl)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium!.copyWith(color: c.textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl))),
      ),
      tabBarTheme: TabBarThemeData(labelStyle: text.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
    );
  }

  static OutlineInputBorder _input(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: AppRadius.all(AppRadius.md + 2),
        borderSide: BorderSide(color: color, width: width),
      );

  /// Always-dark theme for admin screens (GitHub-like palette, refined for contrast).
  static ThemeData get admin {
    final text = AppType.textTheme(AdminColors.textPrimary, AdminColors.textSecondary);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.dark(
        primary: AdminColors.accent,
        onPrimary: AdminColors.onAccent,
        surface: AdminColors.card,
        onSurface: AdminColors.textPrimary,
        onSurfaceVariant: AdminColors.textSecondary,
        outline: AdminColors.border,
        error: AdminColors.danger,
      ),
      scaffoldBackgroundColor: AdminColors.background,
      textTheme: text,
      extensions: const [AppColors.dark],
      dividerTheme: const DividerThemeData(color: AdminColors.border, thickness: 1, space: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: AdminColors.accent, foregroundColor: AdminColors.onAccent, elevation: 0,
        minimumSize: const Size(AppSpace.touch, AppSpace.touch), textStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.all(AppRadius.md)),
      )),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
        foregroundColor: AdminColors.accent, minimumSize: const Size(AppSpace.touch, AppSpace.touch),
      )),
      dialogTheme: DialogThemeData(
        backgroundColor: AdminColors.card,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.all(AppRadius.xl)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium!.copyWith(color: AdminColors.textSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.all(AppRadius.md)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AdminColors.accent),
    );
  }
}
