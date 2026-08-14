import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_spacing.dart';

enum BadgeVariant { critical, warning, success, accent, neutral }

/// Small pill badge with a fixed semantic color mapping. Always renders an
/// icon alongside the label (never color alone) for accessibility — icon
/// defaults per variant but can be overridden.
class AdaptiveBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;
  final IconData? icon;

  const AdaptiveBadge({
    super.key,
    required this.label,
    required this.variant,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    final (background, foreground, defaultIcon) = switch (variant) {
      BadgeVariant.critical => (
        tokens.criticalTint,
        tokens.critical,
        Icons.warning_rounded,
      ),
      BadgeVariant.warning => (
        tokens.warningTint,
        tokens.warning,
        Icons.info_outline,
      ),
      BadgeVariant.success => (
        tokens.successTint,
        tokens.success,
        Icons.check_circle_outline,
      ),
      BadgeVariant.accent => (tokens.accentTint, tokens.accent, Icons.circle),
      BadgeVariant.neutral => (
        tokens.surfaceTint,
        tokens.textSecondary,
        Icons.circle,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? defaultIcon, size: 11, color: foreground),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
