import 'package:flutter/material.dart';
import 'app_palette.dart';

/// Açık zeminli paletler. Koyu görünüm, sayfalar taşındıktan sonra eklenebilir.
class AppTheme {
  AppTheme._();
  static final _cache = <AppPalette, ThemeData>{};

  static ThemeData forPalette(
    AppPalette palette,
  ) => _cache.putIfAbsent(palette, () {
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: palette.primary,
      onPrimary: Colors.white,
      primaryContainer: Color.lerp(palette.primary, Colors.white, 0.86),
      onPrimaryContainer: palette.brandBackground,
      secondaryContainer: Color.lerp(palette.primary, Colors.white, 0.94),
      onSecondaryContainer: palette.brandBackground,
      surface: Color.lerp(palette.primary, const Color(0xFFFAFAF9), 0.98),
      surfaceContainerLow: Color.lerp(palette.primary, Colors.white, 0.96),
      surfaceContainerLowest: Colors.white,
      onSurface: const Color(0xFF102331),
      onSurfaceVariant: const Color(0xFF687482),
      outlineVariant: const Color(0xFFE3ECEA),
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      primaryColor: scheme.primary,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [
        BrandColors(
          background: palette.brandBackground,
          accent: palette.primary,
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: shape.copyWith(side: BorderSide(color: scheme.outlineVariant)),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: shape,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        backgroundColor: scheme.surface,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: shape,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
    );
  });
}
