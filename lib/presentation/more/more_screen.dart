// lib/presentation/more/more_screen.dart
//
// iOS More tab — Settings-style list of secondary destinations.
// Mirrors the drawer destinations from ProviderDashboardScreen.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/referral_provider.dart';
import '../../data/providers/subscription_provider.dart';
import '../../data/providers/sync_provider.dart';
import '../auth/screens/login_screen.dart';
import '../dashboard/screens/provider_dashboard_screen.dart';
import '../emergency_access/screens/emergency_access_screen.dart';
import '../../core/api/api_client.dart';
import '../../data/repositories/organization_repository.dart';
import '../../data/repositories/staff_repository.dart';
import '../facilities/screens/facilities_list_screen.dart';
import '../organization/screens/organization_profile_screen.dart';
import '../providers/screens/provider_invitation_screen.dart';
import '../staff/screens/staff_management_screen.dart';
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
    final sub = context.watch<SubscriptionProvider>();
    final showEmergency = auth.canEmergencyAccess && sub.isProfessionalOrHigher == true;
    final isOrgAdmin = auth.isOrgAdmin;
    final showUpgradeNudge =
        !isOrgAdmin && sub.isProfessionalOrHigher == false;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('More'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            if (showUpgradeNudge)
              _UpgradeNudgeTile(
                onTap: () => _push(context, const SubscriptionDetailsScreen()),
              ),
            // Org admins land on the Overview tab (ProviderDashboardScreen);
            // the Clinical section is redundant for them.
            if (!isOrgAdmin)
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
                    onTap: () =>
                        _push(context, const ProviderDashboardScreen()),
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
            if (isOrgAdmin)
              CupertinoListSection.insetGrouped(
                header: Text('Admin',
                    style: TextStyle(
                        color: CupertinoColors.systemOrange
                            .resolveFrom(context))),
                children: [
                  CupertinoListTile(
                    leading: const Icon(CupertinoIcons.building_2_fill,
                        color: CupertinoColors.systemOrange),
                    title: const Text('Organization'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _push(
                      context,
                      OrganizationProfileScreen(
                        repository: OrganizationRepository(
                            apiClient: context.read<ApiClient>()),
                      ),
                    ),
                  ),
                  CupertinoListTile(
                    leading: const Icon(CupertinoIcons.house_fill,
                        color: CupertinoColors.systemOrange),
                    title: const Text('Facilities'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _push(context, const FacilitiesListScreen()),
                  ),
                  CupertinoListTile(
                    leading: const Icon(CupertinoIcons.group,
                        color: CupertinoColors.systemOrange),
                    title: const Text('Staff'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _push(
                      context,
                      StaffManagementScreen(
                        repository: StaffRepository(
                            apiClient: context.read<ApiClient>()),
                      ),
                    ),
                  ),
                  CupertinoListTile(
                    leading: const Icon(CupertinoIcons.mail,
                        color: CupertinoColors.systemOrange),
                    title: const Text('Invite Staff'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () =>
                        _push(context, const ProviderInvitationScreen()),
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
                if (isOrgAdmin)
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
                if (sub.isProfessionalOrHigher == true)
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

// ── Upgrade nudge ─────────────────────────────────────────────────────────────

class _UpgradeNudgeTile extends StatelessWidget {
  final VoidCallback onTap;
  const _UpgradeNudgeTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF0288D1)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: const Row(
            children: [
              Icon(CupertinoIcons.star_fill,
                  color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upgrade to Professional',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Unlock Emergency Access, Referrals & more',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_right,
                  color: Colors.white70, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
