import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get light => _baseTheme(Brightness.light);
  static ThemeData get dark => _baseTheme(Brightness.dark);

  static const premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF6366F1), // Indigo
      Color(0xFF8B5CF6), // Violet
      Color(0xFFEC4899), // Pink
    ],
  );

  static ThemeData _baseTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    const primary = Color(0xFF6366F1); // Indigo as primary
    const secondary = Color(0xFF0EA5E9); // Sky Blue
    const surface = Color(0xFFF8FAFC); // Slate 50
    // Richer, deeper dark background (Slate 950) for premium feel
    const surfaceDark = Color(0xFF020617);

    final baseScheme = ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      tertiary: const Color(0xFFEC4899), // Pink
    );

    final colorScheme = baseScheme.copyWith(
      surface: isDark ? surfaceDark : surface,
      // Explicitly define container colors for layering
      surfaceContainer: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFFFFFFF), // Slate 900
      surfaceContainerLow:
          isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      surfaceContainerHighest: isDark
          ? const Color(0xFF334155)
          : const Color(0xFFE2E8F0), // Slate 700 for inputs

      // White text for dark mode - full opacity for readability
      onSurface: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A),
      // Lighter gray for secondary text in dark mode (more visible)
      onSurfaceVariant:
          isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),

      // Improved outline visibility
      outline: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
      outlineVariant:
          isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),

      // Tertiary colors for additional text
      onTertiary: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF475569),
    );

    final textTheme = GoogleFonts.plusJakartaSansTextTheme().copyWith(
      displayLarge: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          letterSpacing: -1.0,
          color: colorScheme.onSurface),
      headlineLarge: GoogleFonts.outfit(
          fontWeight: FontWeight.bold, color: colorScheme.onSurface),
      headlineMedium: GoogleFonts.outfit(
          fontWeight: FontWeight.w600, color: colorScheme.onSurface),
      titleLarge: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w600, color: colorScheme.onSurface),
      bodyLarge: GoogleFonts.plusJakartaSans(
          height: 1.5, color: colorScheme.onSurface),
      bodyMedium: GoogleFonts.plusJakartaSans(
          height: 1.5, color: colorScheme.onSurface),
      labelLarge: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w600, color: colorScheme.onSurface),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        // Using surfaceContainer (Slate 900) for cards against Slate 950 background
        color: isDark
            ? colorScheme.surfaceContainer.withValues(alpha: 0.8)
            : colorScheme.surfaceContainer.withValues(alpha: 0.8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: colorScheme.outline.withValues(alpha: isDark ? 0.2 : 0.1),
            width: 1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // Lighter inputs on dark background
        fillColor: isDark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.2)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: isDark ? 0.2 : 0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : colorScheme.surfaceContainerHighest,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        iconTheme: IconThemeData(
          color: colorScheme.onSurfaceVariant,
          size: 18,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outline.withValues(alpha: 0.2),
        thickness: 1,
      ),
      iconTheme: IconThemeData(
        color: colorScheme.onSurface,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        modalBackgroundColor: colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
