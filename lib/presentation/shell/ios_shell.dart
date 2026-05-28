// lib/presentation/shell/ios_shell.dart
//
// iOS root — CupertinoApp + CupertinoTabScaffold with four tabs.
// Each tab has its own independent navigation stack via CupertinoTabView.
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../core/biometric/biometric_provider.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/intra_grant_provider.dart';
import '../access_grants/screens/access_grants_screen.dart';
import '../auth/screens/biometric_lock_screen.dart';
import '../auth/screens/login_screen.dart';
import '../more/more_screen.dart';
import '../patients/screens/patient_list_screen.dart';
import '../roster/screens/roster_screen.dart';
import '../sync/widgets/sync_banner.dart';
import 'org_admin_ios_shell.dart';

/// CupertinoApp root for iOS.
/// Four tabs: Patients · Roster · Access · More
class IOSShell extends StatelessWidget {
  const IOSShell({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Healthcare EMR',
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(
        primaryColor: AppColors.primary,
      ),
      home: const _IOSAuthWrapper(),
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
        if (!auth.isAuthenticated) return const LoginScreen();
        // Show biometric lock screen when the app is locked
        final isLocked = context.watch<BiometricProvider>().isLocked;
        if (isLocked) return const BiometricLockScreen();
        return const _IOSTabs();
      },
    );
  }
}

class _IOSTabs extends StatelessWidget {
  const _IOSTabs();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Column(
        children: [
          const SyncBanner(),
          Expanded(
            child: Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (auth.isOrgAdmin) return const OrgAdminIOSShell();
                return Consumer<IntraGrantProvider>(
                  builder: (context, intra, _) => CupertinoTabScaffold(
                    tabBar: CupertinoTabBar(
                      activeColor: AppColors.primary,
                      items: [
                        const BottomNavigationBarItem(
                          icon: Icon(CupertinoIcons.person_crop_circle),
                          label: 'Patients',
                        ),
                        const BottomNavigationBarItem(
                          icon: Icon(
                              CupertinoIcons.list_bullet_below_rectangle),
                          label: 'Roster',
                        ),
                        BottomNavigationBarItem(
                          icon: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(CupertinoIcons.lock_shield),
                              if (intra.pendingIncomingCount > 0)
                                Positioned(
                                  top: -4,
                                  right: -6,
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEF4444),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          label: 'Access',
                        ),
                        const BottomNavigationBarItem(
                          icon: Icon(CupertinoIcons.ellipsis_circle),
                          label: 'More',
                        ),
                      ],
                    ),
                    tabBuilder: (context, index) => CupertinoTabView(
                      builder: (_) => switch (index) {
                        0 => const PatientListScreen(),
                        1 => const RosterScreen(),
                        2 => const AccessGrantsScreen(),
                        _ => const MoreScreen(),
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

