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
        ? onSurface.withValues(alpha: 0.85) // Brighter in dark mode
        : onSurface.withValues(alpha: 0.6); // Standard in light mode
  }

  /// Returns a tertiary/hint text color visible in both modes
  Color get hintText {
    return brightness == Brightness.dark
        ? onSurface.withValues(alpha: 0.7) // More visible in dark mode
        : onSurface.withValues(alpha: 0.5); // Standard in light mode
  }

  /// Returns a disabled text color visible in both modes
  Color get disabledText {
    return brightness == Brightness.dark
        ? onSurface.withValues(alpha: 0.5) // Visible but muted in dark mode
        : onSurface.withValues(alpha: 0.38); // Standard in light mode
  }
}
