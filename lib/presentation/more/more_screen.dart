// lib/presentation/more/more_screen.dart
//
// iOS More tab — Settings-style list of secondary destinations.
// Mirrors the drawer destinations from ProviderDashboardScreen.
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/referral_provider.dart';
import '../../data/providers/sync_provider.dart';
import '../auth/screens/login_screen.dart';
import '../dashboard/screens/provider_dashboard_screen.dart';
import '../emergency_access/screens/emergency_access_screen.dart';
import '../profile/screens/staff_profile_screen.dart';
import '../reporting/screens/reporting_screen.dart';
import '../subscription/screens/subscription_details_screen.dart';
import '../referrals/screens/referrals_screen.dart';
import '../sync/screens/sync_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final sync = context.watch<SyncProvider>();
    final showEmergency = auth.canEmergencyAccess;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('More'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('Clinical'),
              children: [
                CupertinoListTile(
                  leading: const Icon(
                    CupertinoIcons.chart_bar_alt_fill,
                    color: AppColors.primary,
                  ),
                  title: const Text('Dashboard'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _push(context, const ProviderDashboardScreen()),
                ),
                if (showEmergency)
                  CupertinoListTile(
                    leading: const Icon(
                      CupertinoIcons.exclamationmark_circle,
                      color: AppColors.error,
                    ),
                    title: const Text('Emergency Access'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () =>
                        _push(context, const EmergencyAccessScreen()),
                  ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('Account'),
              children: [
                CupertinoListTile(
                  leading: const Icon(
                    CupertinoIcons.person_crop_square,
                    color: AppColors.primary,
                  ),
                  title: const Text('Staff Profile'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _push(context, const StaffProfileScreen()),
                ),
                CupertinoListTile(
                  leading: const Icon(
                    CupertinoIcons.chart_bar_square,
                    color: AppColors.primary,
                  ),
                  title: const Text('Reporting & Compliance'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _push(context, const ReportingScreen()),
                ),
                CupertinoListTile(
                  leading: const Icon(
                    CupertinoIcons.creditcard,
                    color: AppColors.primary,
                  ),
                  title: const Text('Subscription & Billing'),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () =>
                      _push(context, const SubscriptionDetailsScreen()),
                ),
                CupertinoListTile(
                  leading: const Icon(
                    CupertinoIcons.arrow_2_circlepath,
                    color: AppColors.primary,
                  ),
                  title: const Text('Sync Status'),
                  trailing: sync.hasPendingConflicts
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${sync.pendingConflicts}',
                                style: const TextStyle(
                                    color: CupertinoColors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const CupertinoListTileChevron(),
                          ],
                        )
                      : const CupertinoListTileChevron(),
                  onTap: () => _push(context, const SyncScreen()),
                ),
                Consumer<ReferralProvider>(
                  builder: (context, referrals, _) => CupertinoListTile(
                    leading: const Icon(
                      CupertinoIcons.arrow_right_arrow_left_circle,
                      color: AppColors.primary,
                    ),
                    title: const Text('Referrals'),
                    trailing: referrals.pendingActionCount > 0
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${referrals.pendingActionCount}',
                                  style: const TextStyle(
                                      color: CupertinoColors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const CupertinoListTileChevron(),
                            ],
                          )
                        : const CupertinoListTileChevron(),
                    onTap: () => _push(context, const ReferralsScreen()),
                  ),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              children: [
                CupertinoListTile(
                  leading: const Icon(
                    CupertinoIcons.square_arrow_left,
                    color: AppColors.error,
                  ),
                  title: const Text(
                    'Sign Out',
                    style: TextStyle(color: AppColors.error),
                  ),
                  onTap: () => _confirmSignOut(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context)
        .push(CupertinoPageRoute(builder: (_) => screen));
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          CupertinoPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }
}
