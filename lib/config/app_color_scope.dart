import 'package:flutter/widgets.dart';
import 'app_color_tokens.dart';

/// Provides [AppColorTokens] down the tree so the same semantic colors work
/// identically under MaterialApp (Android/web) and CupertinoApp (iOS) — see
/// AndroidShell/IOSShell, which each wrap their routed content in one of
/// these, resolved from the active brightness.
class AppColorScope extends InheritedWidget {
  final AppColorTokens tokens;

  const AppColorScope({super.key, required this.tokens, required super.child});

  static AppColorTokens of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppColorScope>();
    assert(
      scope != null,
      'AppColors.of() called with no AppColorScope ancestor.',
    );
    return scope!.tokens;
  }

  @override
  bool updateShouldNotify(AppColorScope oldWidget) =>
      tokens != oldWidget.tokens;
}
