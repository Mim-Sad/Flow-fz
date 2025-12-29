import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData getTheme({
    required Color seedColor,
    required Brightness brightness,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'IRANSansX',
      colorScheme: colorScheme,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 32,
          fontFeatures: [FontFeature.enable('ss01')],
        ),
        displayMedium: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 28,
          fontFeatures: [FontFeature.enable('ss01')],
        ),
        displaySmall: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 24,
          fontFeatures: [FontFeature.enable('ss01')],
        ),
        headlineLarge: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 22,
          fontFeatures: [FontFeature.enable('ss01')],
        ),
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          fontFeatures: [FontFeature.enable('ss01')],
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          fontFeatures: [
            FontFeature.tabularFigures(),
            FontFeature.enable('ss01'),
          ],
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
          fontFeatures: [FontFeature.enable('ss01')],
        ),
        bodyLarge: TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 16,
          fontFeatures: [
            FontFeature.tabularFigures(),
            FontFeature.enable('ss01'),
          ],
        ),
        bodyMedium: TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 14,
          fontFeatures: [
            FontFeature.tabularFigures(),
            FontFeature.enable('ss01'),
          ],
        ),
        bodySmall: TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 12,
          fontFeatures: [FontFeature.enable('ss01')],
        ),
        labelLarge: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          fontFeatures: [FontFeature.enable('ss01')],
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'IRANSansX',
          fontWeight: FontWeight.w700,
          fontSize: 20,
          color: brightness == Brightness.light ? Colors.black : Colors.white,
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          foregroundColor: brightness == Brightness.light
              ? Colors.black
              : Colors.white,
          backgroundColor: colorScheme.surface,
          selectedBackgroundColor: colorScheme.primaryContainer,
          selectedForegroundColor: colorScheme.primary,
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: MenuItemButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
