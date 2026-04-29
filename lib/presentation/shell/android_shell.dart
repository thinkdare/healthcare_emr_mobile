// lib/presentation/shell/android_shell.dart
//
// Android root — MaterialApp + existing drawer navigation.
// Zero behaviour change from the original main.dart setup.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../data/providers/auth_provider.dart';
import '../auth/screens/login_screen.dart';
import '../dashboard/screens/provider_dashboard_screen.dart';

/// MaterialApp root for Android. Wraps the authenticated home in
/// [ProviderDashboardScreen], which contains the drawer and all navigation.
class AndroidShell extends StatelessWidget {
  const AndroidShell({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Healthcare EMR',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const _AuthWrapper(),
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
