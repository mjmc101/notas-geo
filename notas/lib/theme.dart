import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFF0F0F0D);
  static const Color surface = Color(0xFF1A1A18);
  static const Color accent = Color(0xFFC8F060);
  static const Color accentDark = Color(0xFF9BBF3A);
  static const Color textPrimary = Color(0xFFE8E8E0);
  static const Color textSecondary = Color(0xFF8A8A80);
  static const Color error = Color(0xFFFF5555);
  static const Color cardBorder = Color(0xFF2A2A28);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          surface: surface,
          primary: accent,
          secondary: accentDark,
          error: error,
          onSurface: textPrimary,
          onPrimary: background,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: accent),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: accent,
          foregroundColor: background,
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: cardBorder),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: surface,
          indicatorColor: Color(0x33C8F060),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(color: textSecondary, fontSize: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: accent, width: 1.5),
          ),
          labelStyle: const TextStyle(color: textSecondary),
          hintStyle: const TextStyle(color: textSecondary),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? accent : textSecondary,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? const Color(0x66C8F060)
                : surface,
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: textPrimary),
          bodyMedium: TextStyle(color: textPrimary),
          bodySmall: TextStyle(color: textSecondary),
          titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: surface,
          titleTextStyle: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          contentTextStyle: TextStyle(color: textSecondary),
        ),
        popupMenuTheme: const PopupMenuThemeData(color: surface),
        dividerTheme: const DividerThemeData(color: cardBorder),
        sliderTheme: const SliderThemeData(
          activeTrackColor: accent,
          inactiveTrackColor: cardBorder,
          thumbColor: accent,
          overlayColor: Color(0x33C8F060),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: background,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        dropdownMenuTheme: const DropdownMenuThemeData(
          menuStyle: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(surface),
          ),
        ),
      );
}
