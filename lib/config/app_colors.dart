//
// Context-based accessor for the shared design tokens. Backed by
// AppColorScope so the same call — AppColors.of(context) — resolves
// correctly whether the caller is under MaterialApp (Android/web) or
// CupertinoApp (iOS), and reacts automatically to theme-mode changes.
import 'package:flutter/widgets.dart' show BuildContext;
import 'app_color_scope.dart';
import 'app_color_tokens.dart';

class AppColors {
  AppColors._();

  static AppColorTokens of(BuildContext context) => AppColorScope.of(context);
}
