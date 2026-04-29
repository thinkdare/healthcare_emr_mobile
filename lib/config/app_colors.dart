// lib/config/app_colors.dart
//
// Shared colour constants used by both MaterialApp (Android) and
// CupertinoApp (iOS). Import this instead of AppTheme for colours.
import 'package:flutter/material.dart' show Color;

class AppColors {
  static const Color primary   = Color(0xFF2563EB); // Brand blue
  static const Color secondary = Color(0xFF7C3AED); // Purple accent
  static const Color error     = Color(0xFFDC2626); // Semantic red
  static const Color success   = Color(0xFF16A34A); // Semantic green
  static const Color warning   = Color(0xFFF59E0B); // Semantic amber
  static const Color gray50    = Color(0xFFF9FAFB);
  static const Color gray100   = Color(0xFFF3F4F6);
  static const Color gray600   = Color(0xFF4B5563);
  static const Color gray900   = Color(0xFF111827);
}
