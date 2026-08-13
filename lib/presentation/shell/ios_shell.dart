// lib/presentation/shell/ios_shell.dart
//
// iOS root — CupertinoApp + CupertinoTabScaffold with four tabs.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme, ThemeData;
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/app_color_scope.dart';
import '../../config/app_color_tokens.dart';
import '../../config/theme.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/theme_mode_provider.dart';
import '../access_grants/screens/access_grants_screen.dart';
import '../auth/screens/login_screen.dart';
import '../more/more_screen.dart';
import '../patients/screens/patient_list_screen.dart';
import '../roster/screens/roster_screen.dart';
import '../sync/widgets/sync_banner.dart';
import 'app_lock_gate.dart';
import 'widgets/device_integrity_banner.dart';

class IOSShell extends StatelessWidget {
  const IOSShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeModeProvider>(
      builder: (context, themeModeProvider, _) {
        return Builder(
          builder: (context) {
            final brightness = themeModeProvider.resolvedBrightness(context);
            final tokens =
                brightness == Brightness.dark ? AppColorTokens.dark : AppColorTokens.light;
            // Most screens reachable from this shell (Patient List, Roster,
            // Access Grants, Patient Detail, Staff Profile, …) are built from
            // Material widgets — Scaffold, Card, ListTile, TextField — even
            // though the outer chrome is Cupertino. CupertinoApp only bridges
            // `brightness` and `primaryColor` into Material's Theme.of(context);
            // everything else (scaffoldBackgroundColor, colorScheme.surface,
            // cardColor, fontFamily) falls back to stock Material 3 defaults,
            // so those screens rendered on a cool grey ground in Roboto rather
            // than the warm palette in Plus Jakarta Sans. Injecting the real
            // ThemeData below the CupertinoApp — via `builder`, so it wraps the
            // routed navigator content — is what actually delivers the
            // redesign to the iOS UI. Navigation and Cupertino chrome are
            // untouched.
            final ThemeData materialTheme = brightness == Brightness.dark
                ? AppTheme.darkTheme
                : AppTheme.lightTheme;
            return AppColorScope(
              tokens: tokens,
              child: CupertinoApp(
                title: 'Healthcare EMR',
                debugShowCheckedModeBanner: false,
                theme: CupertinoThemeData(
                  brightness: brightness,
                  primaryColor: tokens.accent,
                  scaffoldBackgroundColor: tokens.background,
                  textTheme: const CupertinoTextThemeData(
                    textStyle: TextStyle(fontFamily: 'Plus Jakarta Sans'),
                  ),
                ),
                builder: (context, child) =>
                    Theme(data: materialTheme, child: child ?? const SizedBox.shrink()),
                home: const AppLockGate(child: _IOSAuthWrapper()),
              ),
            );
          },
        );
      },
    );
  }
}

class _IOSAuthWrapper extends StatelessWidget {
  const _IOSAuthWrapper();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return const CupertinoPageScaffold(
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
        return auth.isAuthenticated
            ? const _IOSTabs()
            : const LoginScreen();
      },
    );
  }
}

class _IOSTabs extends StatelessWidget {
  const _IOSTabs();

  @override
  Widget build(BuildContext context) {
    final tokens = AppColors.of(context);
    return CupertinoPageScaffold(
      child: Column(
        children: [
          const DeviceIntegrityBanner(),
          const SyncBanner(),
          Expanded(
            child: CupertinoTabScaffold(
              tabBar: CupertinoTabBar(
                activeColor: tokens.accent,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.person_crop_circle),
                    label: 'Patients',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.list_bullet_below_rectangle),
                    label: 'Roster',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.lock_shield),
                    label: 'Access',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(CupertinoIcons.ellipsis_circle),
                    label: 'More',
                  ),
                ],
              ),
              tabBuilder: (context, index) {
                return CupertinoTabView(
                  builder: (_) => switch (index) {
                    0 => const PatientListScreen(),
                    1 => const RosterScreen(),
                    2 => const AccessGrantsScreen(),
                    _ => const MoreScreen(),
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
