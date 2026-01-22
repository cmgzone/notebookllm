import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PremiumButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;
  final bool isSecondary;
  final double? width;
  final EdgeInsetsGeometry padding;

  const PremiumButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.isSecondary = false,
    this.width,
    this.padding = const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Secondary button (Outlined/Glassy)
    if (isSecondary) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          padding: padding,
          minimumSize: width != null ? Size(width!, 0) : null,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: theme.colorScheme.outline),
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
      );
    }

    // Primary Button (Gradient)
    final borderRadius = BorderRadius.circular(16);

    return Container(
      width: width,
      decoration: BoxDecoration(
        gradient: onPressed != null ? AppTheme.premiumGradient : null,
        color: onPressed == null ? theme.disabledColor : null,
        borderRadius: borderRadius,
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: borderRadius,
          child: Padding(
            padding: padding,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
