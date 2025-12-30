import 'package:flutter/material.dart';

extension ColorAlphaCompat on Color {
  Color withValues({double? alpha}) {
    final currentA = (a * 255).round();
    final newA = alpha == null
        ? currentA
        : ((alpha < 0 ? 0 : (alpha > 1 ? 1 : alpha)) * 255).round();
    final rInt = (r * 255).round();
    final gInt = (g * 255).round();
    final bInt = (b * 255).round();
    return Color.fromARGB(newA, rInt, gInt, bInt);
  }
}

/// Extension to get dark-mode-aware secondary text color
extension DarkModeAwareColor on ColorScheme {
  /// Returns a secondary text color that's visible in both light and dark modes
  /// Use this instead of onSurface.withValues(alpha: 0.5-0.7)
  Color get secondaryText {
    return brightness == Brightness.dark
        ? const Color(0xFFCBD5E1) // Slate 300 - very visible in dark mode
        : const Color(0xFF475569); // Slate 600 - good contrast in light mode
  }

  /// Returns a tertiary/hint text color visible in both modes
  Color get hintText {
    return brightness == Brightness.dark
        ? const Color(0xFF94A3B8) // Slate 400 - visible hint in dark mode
        : const Color(0xFF64748B); // Slate 500 - standard in light mode
  }

  /// Returns a disabled text color visible in both modes
  Color get disabledText {
    return brightness == Brightness.dark
        ? const Color(0xFF64748B) // Slate 500 - muted but visible
        : const Color(0xFF94A3B8); // Slate 400 - standard in light mode
  }
}
