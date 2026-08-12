import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_spacing.dart';

/// Standard card container: surface color, subtle border, 16px radius.
/// Replaces ad hoc Card/Container(decoration:) usage across screens.
class AdaptiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  const AdaptiveCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    final card = Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: backgroundColor ?? tokens.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: borderColor ?? tokens.surfaceBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
              child: child,
            ),
          ),
        ),
      ),
    );
    return card;
  }
}
