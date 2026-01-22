import 'package:flutter/material.dart';
import 'glass_container.dart';

class PremiumCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? icon;
  final VoidCallback? onTap;
  final bool isGlass;
  final double? height;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;

  const PremiumCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.onTap,
    this.isGlass = false,
    this.height,
    this.width,
    this.padding,
    this.margin,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null || icon != null) ...[
          Row(
            children: [
              if (icon != null) ...[
                IconTheme(
                  data: IconThemeData(
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  child: icon!,
                ),
                const SizedBox(width: 12),
              ],
              if (title != null)
                Expanded(
                  child: Text(
                    title!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        child,
      ],
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: content,
      );
    }

    if (isGlass) {
      return GlassContainer(
        margin: margin,
        padding: padding ?? const EdgeInsets.all(24),
        child: content,
      );
    }

    return Container(
      height: height,
      width: width,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: content,
    );
  }
}
