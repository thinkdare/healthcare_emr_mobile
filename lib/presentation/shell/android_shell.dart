// lib/presentation/shell/android_shell.dart
//
// Android root — MaterialApp + auth wrapper.
// Clinical staff land on ProviderDashboardScreen (drawer nav).
// Org admins land on OrgAdminAndroidShell (bottom nav, no drawer).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../core/biometric/biometric_provider.dart';
import '../../data/providers/auth_provider.dart';
import '../auth/screens/biometric_lock_screen.dart';
import '../auth/screens/login_screen.dart';
import '../dashboard/screens/provider_dashboard_screen.dart';
import 'org_admin_android_shell.dart';

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
        if (!auth.isAuthenticated) return const LoginScreen();
        final isLocked = context.watch<BiometricProvider>().isLocked;
        if (isLocked) return const BiometricLockScreen();
        if (auth.isOrgAdmin) return const OrgAdminAndroidShell();
        return const ProviderDashboardScreen();
      },
    );
  }
}
