// lib/presentation/shell/android_shell.dart
//
// Android root — MaterialApp + existing drawer navigation. Also serves
// web (see the comment on the shell-selection line in main.dart).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_color_scope.dart';
import '../../config/app_color_tokens.dart';
import '../../config/theme.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/theme_mode_provider.dart';
import '../auth/screens/login_screen.dart';
import '../dashboard/screens/provider_dashboard_screen.dart';
import 'app_lock_gate.dart';

class AndroidShell extends StatelessWidget {
  const AndroidShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeModeProvider>(
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Healthcare EMR',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode.mode,
          builder: (context, child) {
            final tokens = Theme.of(context).brightness == Brightness.dark
                ? AppColorTokens.dark
                : AppColorTokens.light;
            return AppColorScope(tokens: tokens, child: child!);
          },
          home: const AppLockGate(child: _AuthWrapper()),
        );
      },
    );
  }
}

class _AuthWrapper extends StatelessWidget {
  const _AuthWrapper();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return auth.isAuthenticated
            ? const ProviderDashboardScreen()
            : const LoginScreen();
      },
    );
  }
}
